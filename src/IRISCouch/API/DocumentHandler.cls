/// <p>HTTP handler for document CRUD operations.</p>
/// <p>Handles <code>POST /{db}</code> (create with server-generated ID),
/// <code>PUT /{db}/{docid}</code> (create/update with client-specified ID),
/// <code>GET /{db}/{docid}</code> (retrieve document),
/// and <code>DELETE /{db}/{docid}</code> (delete document with tombstone).
/// Delegates to <class>IRISCouch.Core.DocumentEngine</class> for writes
/// and <class>IRISCouch.Storage.Document</class> for reads.</p>
Class IRISCouch.API.DocumentHandler Extends %RegisteredObject
{

/// <p>Handle <code>POST /{db}</code> — create a document with server-generated ID.</p>
/// <p>Reads the JSON body, generates a UUID for the document ID, strips any
/// client-provided <code>_id</code> (POST always uses server-generated ID),
/// and delegates to <method>DocumentEngine.Save</method>.</p>
/// @param pDB The database name from the URL path
/// @return %Status
ClassMethod HandlePost(pDB As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        ; Check database exists
        If '##class(IRISCouch.Storage.Database).Exists(pDB) {
            Do ##class(IRISCouch.Util.Error).Render(404, ##class(IRISCouch.Util.Error).#NOTFOUND, "Database does not exist.")
            Quit
        }
        ; Read JSON body
        Set tContent = ""
        If $IsObject(%request.Content) {
            Set tContent = %request.Content.Read()
        }
        If tContent = "" {
            Do ##class(IRISCouch.Util.Error).Render(400, ##class(IRISCouch.Util.Error).#BADREQUEST, "Request body is empty or missing.")
            Quit
        }
        ; Parse body
        Try {
            Set tBody = ##class(%DynamicObject).%FromJSON(tContent)
        } Catch tParseEx {
            Do ##class(IRISCouch.Util.Error).Render(400, ##class(IRISCouch.Util.Error).#BADREQUEST, "invalid UTF-8 JSON")
            Return $$$OK
        }
        ; Validate underscore fields
        Set tValErr = ..ValidateFields(tBody)
        If tValErr '= "" {
            Do ##class(IRISCouch.Util.Error).Render(400, ##class(IRISCouch.Util.Error).#DOCVALIDATION, "Bad special document member: " _ tValErr)
            Quit
        }
        ; POST always generates a server UUID — ignore any client _id
        Set tDocId = ##class(IRISCouch.Util.UUID).Generate()
        ; Check for inline _attachments with data fields
        Set tHasInlineAtts = 0
        Set tAttachments = ""
        If tBody.%IsDefined("_attachments") {
            Set tAttachments = tBody.%Get("_attachments")
            If $IsObject(tAttachments) {
                Set tAttIter = tAttachments.%GetIterator()
                While tAttIter.%GetNext(.tAttKey, .tAttVal) {
                    If $IsObject(tAttVal) && (tAttVal.%Get("data") '= "") {
                        Set tHasInlineAtts = 1
                        Quit
                    }
                }
            }
        }
        ; Remove metadata fields before storing
        If tBody.%IsDefined("_id") Do tBody.%Remove("_id")
        If tBody.%IsDefined("_rev") Do tBody.%Remove("_rev")
        If tBody.%IsDefined("_deleted") Do tBody.%Remove("_deleted")
        If tBody.%IsDefined("_attachments") Do tBody.%Remove("_attachments")
        ; Save document — with or without inline attachments
        Set tValidateError = ""
        Set tIndexError = ""
        If tHasInlineAtts && $IsObject(tAttachments) {
            Set tNewRev = ##class(IRISCouch.Core.DocumentEngine).SaveWithAttachments(pDB, tDocId, tBody.%ToJSON(), "", tAttachments, .tValidateError)
        } Else {
            Set tNewRev = ##class(IRISCouch.Core.DocumentEngine).Save(pDB, tDocId, tBody.%ToJSON(), "", .tValidateError, .tIndexError)
        }
        If tNewRev = "" {
            If tValidateError '= "" {
                Do ..RenderValidate(tValidateError)
                Quit
            }
            If $IsObject(tIndexError) {
                Do ..RenderIndexError(tIndexError)
                Quit
            }
            Do ##class(IRISCouch.Util.Error).RenderInternal(##class(IRISCouch.Util.Error).#SERVERERROR, "document: save error")
            Quit
        }
        ; Return 201 Created
        Set tResp = {}
        Do tResp.%Set("ok", 1, "boolean")
        Do tResp.%Set("id", tDocId)
        Do tResp.%Set("rev", tNewRev)
        Do ##class(IRISCouch.Util.Response).JSONStatus(201, tResp)
        Quit
    }
    Catch ex {
        Do ##class(IRISCouch.Util.Error).RenderInternal(##class(IRISCouch.Util.Error).#SERVERERROR, "document: post error", ex)
        Quit
    }
    Quit $$$OK
}

/// <p>Handle <code>PUT /{db}/{docid}</code> — create or update a document with client-specified ID.</p>
/// <p>Supports document creation (no <code>_rev</code>), updates with optimistic
/// concurrency checking (<code>_rev</code> must match current winner), and deletion
/// via <code>_deleted:true</code> in the body.</p>
/// @param pDB The database name from the URL path
/// @param pDocId The document identifier from the URL path
/// @return %Status
ClassMethod HandlePut(pDB As %String, pDocId As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        ; Check database exists
        If '##class(IRISCouch.Storage.Database).Exists(pDB) {
            Do ##class(IRISCouch.Util.Error).Render(404, ##class(IRISCouch.Util.Error).#NOTFOUND, "Database does not exist.")
            Quit
        }
        ; Story 13.4 Task 8e: reject underscore-prefix doc IDs except reserved
        ; namespaces. Matches Apache CouchDB behaviour — `_design/...` and
        ; `_local/...` are the only reserved IDs beginning with underscore;
        ; everything else in that namespace is reserved for future system
        ; endpoints. Note: `_design/<name>` and `_local/<name>` arrive via the
        ; dedicated HandleDesignDocPut / HandleLocalPut wrappers which reassemble
        ; the composite id — any underscore-prefix id seen here is NOT one of
        ; those legitimate composites, so we can reject the whole space.
        If $Extract(pDocId, 1) = "_" {
            If ($Extract(pDocId, 1, 8) '= "_design/") && ($Extract(pDocId, 1, 7) '= "_local/") {
                Do ##class(IRISCouch.Util.Error).Render(400, ##class(IRISCouch.Util.Error).#BADREQUEST, "Only reserved document IDs begin with underscore (_design/... or _local/...)")
                Quit
            }
        }
        ; Detect multipart/related Content-Type
        Set tContentType = %request.ContentType
        Set tIsMultipart = 0
        If $Find($ZConvert(tContentType, "L"), "multipart/related") > 0 {
            Set tIsMultipart = 1
        }
        If tIsMultipart {
            ; Parse multipart/related request using %request.MimeData
            ; %CSP automatically parses multipart bodies into MimeData, keyed by
            ; CONTENTn (no filename) or FILEn (with filename from Content-Disposition).
            ; Find the JSON document part (first CONTENT key)
            Set tJsonStream = ""
            Set tAttachments = {}
            Set tMimeKey = ""
            For {
                Set tMimeKey = $Order(%request.MimeData(tMimeKey))
                Quit:tMimeKey=""
                Set tMimeCount = $Order(%request.MimeData(tMimeKey, ""), -1)
                For tMI = 1:1:tMimeCount {
                    Set tMStream = %request.MimeData(tMimeKey, tMI)
                    If '$IsObject(tMStream) Continue
                    Do tMStream.Rewind()
                    If '$IsObject(tJsonStream) {
                        ; First part = JSON document body
                        Set tJsonStream = tMStream
                    } Else {
                        ; Subsequent parts = binary attachments
                        Set tPartType = tMStream.ContentType
                        If tPartType = "" Set tPartType = "application/octet-stream"
                        Set tFilename = tMStream.FileName
                        If tFilename = "" Set tFilename = "attachment_" _ tMI
                        ; Pass stream directly — no base64 encode/decode round-trip
                        Do tMStream.Rewind()
                        Set tAttEntry = {}
                        Do tAttEntry.%Set("content_type", tPartType)
                        Do tAttEntry.%Set("_stream", tMStream)
                        Do tAttachments.%Set(tFilename, tAttEntry)
                    }
                }
            }
            If '$IsObject(tJsonStream) {
                Do ##class(IRISCouch.Util.Error).Render(400, ##class(IRISCouch.Util.Error).#BADREQUEST, "Multipart message must contain at least one part")
                Quit
            }
            ; Parse JSON from first part
            Do tJsonStream.Rewind()
            Set tJsonContent = tJsonStream.Read()
            Try {
                Set tBody = ##class(%DynamicObject).%FromJSON(tJsonContent)
            } Catch tParseEx {
                Do ##class(IRISCouch.Util.Error).Render(400, ##class(IRISCouch.Util.Error).#BADREQUEST, "invalid UTF-8 JSON in first MIME part")
                Return $$$OK
            }
            ; Merge "follows":true and stub entries from JSON _attachments
            If tBody.%IsDefined("_attachments") {
                Set tDocAtts = tBody.%Get("_attachments")
                If $IsObject(tDocAtts) {
                    Set tDocAttIter = tDocAtts.%GetIterator()
                    While tDocAttIter.%GetNext(.tFollowName, .tFollowObj) {
                        If '$IsObject(tFollowObj) Continue
                        If (tFollowObj.%Get("stub") = 1) || (tFollowObj.%Get("stub") = "true") {
                            Do tAttachments.%Set(tFollowName, tFollowObj)
                        }
                    }
                }
            }
            ; Now proceed with the standard inline attachment path
            ; Validate underscore fields
            Set tValErr = ..ValidateFields(tBody)
            If tValErr '= "" {
                Do ##class(IRISCouch.Util.Error).Render(400, ##class(IRISCouch.Util.Error).#DOCVALIDATION, "Bad special document member: " _ tValErr)
                Quit
            }
            ; Extract _rev from body or query param
            Set tRev = ""
            If tBody.%IsDefined("_rev") {
                Set tRev = tBody.%Get("_rev")
            }
            If (tRev = "") && ($Data(%request.Data("rev", 1))) {
                Set tRev = $Get(%request.Data("rev", 1))
            }
            ; Optimistic concurrency check
            If ##class(IRISCouch.Storage.Document).Exists(pDB, pDocId) {
                If tRev = "" {
                    Do ##class(IRISCouch.Util.Error).Render(409, ##class(IRISCouch.Util.Error).#CONFLICT, "Document update conflict.")
                    Quit
                }
                Set tCurrentWinner = ##class(IRISCouch.Storage.RevTree).GetWinner(pDB, pDocId)
                If tRev '= tCurrentWinner {
                    Do ##class(IRISCouch.Util.Error).Render(409, ##class(IRISCouch.Util.Error).#CONFLICT, "Document update conflict.")
                    Quit
                }
            }
            ; Remove metadata fields
            If tBody.%IsDefined("_id") Do tBody.%Remove("_id")
            If tBody.%IsDefined("_rev") Do tBody.%Remove("_rev")
            If tBody.%IsDefined("_deleted") Do tBody.%Remove("_deleted")
            If tBody.%IsDefined("_attachments") Do tBody.%Remove("_attachments")
            ; Save with attachments
            Set tValidateError = ""
            Set tNewRev = ##class(IRISCouch.Core.DocumentEngine).SaveWithAttachments(pDB, pDocId, tBody.%ToJSON(), tRev, tAttachments, .tValidateError)
            If tNewRev = "" {
                If tValidateError '= "" {
                    Do ..RenderValidate(tValidateError)
                    Quit
                }
                Do ##class(IRISCouch.Util.Error).RenderInternal(##class(IRISCouch.Util.Error).#SERVERERROR, "document: multipart save error")
                Quit
            }
            ; Return 201 Created
            Set tResp = {}
            Do tResp.%Set("ok", 1, "boolean")
            Do tResp.%Set("id", pDocId)
            Do tResp.%Set("rev", tNewRev)
            Do ##class(IRISCouch.Util.Response).JSONStatus(201, tResp)
            Quit
        }
        ; Read JSON body
        Set tContent = ""
        If $IsObject(%request.Content) {
            Set tContent = %request.Content.Read()
        }
        If tContent = "" {
            Do ##class(IRISCouch.Util.Error).Render(400, ##class(IRISCouch.Util.Error).#BADREQUEST, "Request body is empty or missing.")
            Quit
        }
        ; Parse body
        Try {
            Set tBody = ##class(%DynamicObject).%FromJSON(tContent)
        } Catch tParseEx {
            Do ##class(IRISCouch.Util.Error).Render(400, ##class(IRISCouch.Util.Error).#BADREQUEST, "invalid UTF-8 JSON")
            Return $$$OK
        }
        ; Validate underscore fields
        Set tValErr = ..ValidateFields(tBody)
        If tValErr '= "" {
            Do ##class(IRISCouch.Util.Error).Render(400, ##class(IRISCouch.Util.Error).#DOCVALIDATION, "Bad special document member: " _ tValErr)
            Quit
        }
        ; Extract _rev from body or query param
        Set tRev = ""
        If tBody.%IsDefined("_rev") {
            Set tRev = tBody.%Get("_rev")
        }
        If (tRev = "") && ($Data(%request.Data("rev", 1))) {
            Set tRev = $Get(%request.Data("rev", 1))
        }
        ; Optimistic concurrency check for updates
        If ##class(IRISCouch.Storage.Document).Exists(pDB, pDocId) {
            If tRev = "" {
                ; Doc exists but no _rev provided — 409
                Do ##class(IRISCouch.Util.Error).Render(409, ##class(IRISCouch.Util.Error).#CONFLICT, "Document update conflict.")
                Quit
            }
            ; Verify _rev matches current winner
            Set tCurrentWinner = ##class(IRISCouch.Storage.RevTree).GetWinner(pDB, pDocId)
            If tRev '= tCurrentWinner {
                Do ##class(IRISCouch.Util.Error).Render(409, ##class(IRISCouch.Util.Error).#CONFLICT, "Document update conflict.")
                Quit
            }
        }
        ; Check for _deleted:true — delegate to delete path
        Set tDeleted = 0
        If tBody.%IsDefined("_deleted") {
            If tBody.%Get("_deleted") = "true" || (tBody.%Get("_deleted") = 1) {
                Set tDeleted = 1
            }
        }
        If tDeleted {
            ; Delete via PUT requires existing doc with valid _rev
            If tRev = "" {
                Do ##class(IRISCouch.Util.Error).Render(404, ##class(IRISCouch.Util.Error).#NOTFOUND, "missing")
                Quit
            }
            ; Delete via PUT with _deleted:true
            Set tValidateError = ""
            Set tNewRev = ##class(IRISCouch.Core.DocumentEngine).SaveDeleted(pDB, pDocId, tRev, .tValidateError)
            If tNewRev = "" {
                If tValidateError '= "" {
                    Do ..RenderValidate(tValidateError)
                    Quit
                }
                Do ##class(IRISCouch.Util.Error).RenderInternal(##class(IRISCouch.Util.Error).#SERVERERROR, "document: delete via put error")
                Quit
            }
            ; Return 200 OK for deletion
            Set tResp = {}
            Do tResp.%Set("ok", 1, "boolean")
            Do tResp.%Set("id", pDocId)
            Do tResp.%Set("rev", tNewRev)
            Do ##class(IRISCouch.Util.Response).JSON(tResp)
            Quit
        }
        ; Check for inline _attachments with data fields
        Set tHasInlineAtts = 0
        Set tAttachments = ""
        If tBody.%IsDefined("_attachments") {
            Set tAttachments = tBody.%Get("_attachments")
            If $IsObject(tAttachments) {
                ; Check if any attachment has "data" field (new inline attachment)
                Set tAttIter = tAttachments.%GetIterator()
                While tAttIter.%GetNext(.tAttKey, .tAttVal) {
                    If $IsObject(tAttVal) && (tAttVal.%Get("data") '= "") {
                        Set tHasInlineAtts = 1
                        Quit
                    }
                }
            }
        }
        ; Remove metadata fields before storing
        If tBody.%IsDefined("_id") Do tBody.%Remove("_id")
        If tBody.%IsDefined("_rev") Do tBody.%Remove("_rev")
        If tBody.%IsDefined("_deleted") Do tBody.%Remove("_deleted")
        If tBody.%IsDefined("_attachments") Do tBody.%Remove("_attachments")
        ; Save document — with or without inline attachments
        Set tValidateError = ""
        Set tIndexError = ""
        If tHasInlineAtts && $IsObject(tAttachments) {
            Set tNewRev = ##class(IRISCouch.Core.DocumentEngine).SaveWithAttachments(pDB, pDocId, tBody.%ToJSON(), tRev, tAttachments, .tValidateError)
        } Else {
            Set tNewRev = ##class(IRISCouch.Core.DocumentEngine).Save(pDB, pDocId, tBody.%ToJSON(), tRev, .tValidateError, .tIndexError)
        }
        If tNewRev = "" {
            If tValidateError '= "" {
                Do ..RenderValidate(tValidateError)
                Quit
            }
            If $IsObject(tIndexError) {
                Do ..RenderIndexError(tIndexError)
                Quit
            }
            Do ##class(IRISCouch.Util.Error).RenderInternal(##class(IRISCouch.Util.Error).#SERVERERROR, "document: save error")
            Quit
        }
        ; Return 201 Created
        Set tResp = {}
        Do tResp.%Set("ok", 1, "boolean")
        Do tResp.%Set("id", pDocId)
        Do tResp.%Set("rev", tNewRev)
        Do ##class(IRISCouch.Util.Response).JSONStatus(201, tResp)
        Quit
    }
    Catch ex {
        Do ##class(IRISCouch.Util.Error).RenderInternal(##class(IRISCouch.Util.Error).#SERVERERROR, "document: put error", ex)
        Quit
    }
    Quit $$$OK
}

/// <p>Handle <code>DELETE /{db}/{docid}</code> — delete a document producing a tombstone.</p>
/// <p>Requires the <code>rev</code> query parameter matching the current winning revision.
/// Creates a tombstone revision via <method>DocumentEngine.SaveDeleted</method>.</p>
/// @param pDB The database name from the URL path
/// @param pDocId The document identifier from the URL path
/// @return %Status
ClassMethod HandleDelete(pDB As %String, pDocId As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        ; Check database exists
        If '##class(IRISCouch.Storage.Database).Exists(pDB) {
            Do ##class(IRISCouch.Util.Error).Render(404, ##class(IRISCouch.Util.Error).#NOTFOUND, "Database does not exist.")
            Quit
        }
        ; Check document exists
        If '##class(IRISCouch.Storage.Document).Exists(pDB, pDocId) {
            Do ##class(IRISCouch.Util.Error).Render(404, ##class(IRISCouch.Util.Error).#NOTFOUND, "missing")
            Quit
        }
        ; Get rev from query param — required for DELETE
        Set tRev = ""
        If $Data(%request.Data("rev", 1)) {
            Set tRev = $Get(%request.Data("rev", 1))
        }
        If tRev = "" {
            Do ##class(IRISCouch.Util.Error).Render(409, ##class(IRISCouch.Util.Error).#CONFLICT, "Document update conflict.")
            Quit
        }
        ; Verify rev matches current winner
        Set tCurrentWinner = ##class(IRISCouch.Storage.RevTree).GetWinner(pDB, pDocId)
        If tRev '= tCurrentWinner {
            Do ##class(IRISCouch.Util.Error).Render(409, ##class(IRISCouch.Util.Error).#CONFLICT, "Document update conflict.")
            Quit
        }
        ; Create tombstone
        Set tValidateError = ""
        Set tNewRev = ##class(IRISCouch.Core.DocumentEngine).SaveDeleted(pDB, pDocId, tRev, .tValidateError)
        If tNewRev = "" {
            If tValidateError '= "" {
                Do ..RenderValidate(tValidateError)
                Quit
            }
            Do ##class(IRISCouch.Util.Error).RenderInternal(##class(IRISCouch.Util.Error).#SERVERERROR, "document: delete error")
            Quit
        }
        ; Return 200 OK
        Set tResp = {}
        Do tResp.%Set("ok", 1, "boolean")
        Do tResp.%Set("id", pDocId)
        Do tResp.%Set("rev", tNewRev)
        Do ##class(IRISCouch.Util.Response).JSON(tResp)
        Quit
    }
    Catch ex {
        Do ##class(IRISCouch.Util.Error).RenderInternal(##class(IRISCouch.Util.Error).#SERVERERROR, "document: delete error", ex)
        Quit
    }
    Quit $$$OK
}

/// <p>Handle <code>GET /{db}/{docid}</code> — retrieve a document.</p>
/// <p>If the <code>rev</code> query parameter is specified, returns that specific
/// revision. Otherwise, returns the winning revision. Injects <code>_id</code>
/// and <code>_rev</code> into the response body. Returns 404 for deleted documents.</p>
/// @param pDB The database name from the URL path
/// @param pDocId The document identifier from the URL path
/// @return %Status
ClassMethod HandleGet(pDB As %String, pDocId As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        ; Check database exists
        If '##class(IRISCouch.Storage.Database).Exists(pDB) {
            Do ##class(IRISCouch.Util.Error).Render(404, ##class(IRISCouch.Util.Error).#NOTFOUND, "Database does not exist.")
            Quit
        }
        ; Check for open_revs parameter — changes entire response format
        Set tOpenRevs = ""
        If $Data(%request.Data("open_revs", 1)) {
            Set tOpenRevs = $Get(%request.Data("open_revs", 1))
        }
        If tOpenRevs '= "" {
            ; Verify document exists (any revision) before processing open_revs
            If '##class(IRISCouch.Storage.Document).Exists(pDB, pDocId) {
                Do ##class(IRISCouch.Util.Error).Render(404, ##class(IRISCouch.Util.Error).#NOTFOUND, "missing")
                Quit
            }
            ; Handle open_revs: return array of leaf or specified revisions
            Set tResultArr = []
            If tOpenRevs = "all" {
                Set tRevArray = ##class(IRISCouch.Storage.RevTree).GetLeafRevs(pDB, pDocId)
            } Else {
                Try {
                    Set tRevArray = ##class(%DynamicArray).%FromJSON(tOpenRevs)
                } Catch tParseEx {
                    Do ##class(IRISCouch.Util.Error).Render(400, ##class(IRISCouch.Util.Error).#BADREQUEST, "invalid open_revs value")
                    Return $$$OK
                }
            }
            ; Check if multipart/mixed response is requested
            Set tAccept = %request.GetCgiEnv("HTTP_ACCEPT")
            Set tWantMultipart = ($Find($ZConvert(tAccept, "L"), "multipart/mixed") > 0)
            If tWantMultipart {
                ; Generate multipart/mixed MIME response
                ; Use hex encoding to avoid MIME-special characters (+, /, =) that base64 produces
                Set tBoundary = "iriscouch_" _ $ZConvert(##class(%xsd.hexBinary).LogicalToXSD($System.Encryption.GenCryptRand(16)), "L")
                Set %response.ContentType = "multipart/mixed; boundary=" _ tBoundary
                Set %response.Status = "200 OK"
                Set tCRLF = $Char(13,10)
                Set tI = 0
                While tI < tRevArray.%Size() {
                    Set tLeafRev = tRevArray.%Get(tI)
                    Set tLeafBody = ##class(IRISCouch.Storage.Document).Read(pDB, pDocId, tLeafRev)
                    If tLeafBody '= "" {
                        Set tLeafObj = ##class(%DynamicObject).%FromJSON(tLeafBody)
                        Set tDocObj = {}
                        Do tDocObj.%Set("_id", pDocId)
                        Do tDocObj.%Set("_rev", tLeafRev)
                        Set tDocIter = tLeafObj.%GetIterator()
                        While tDocIter.%GetNext(.tDocKey, .tDocVal) {
                            Do tDocObj.%Set(tDocKey, tDocVal)
                        }
                        ; Get attachment metadata for this revision
                        Set tAttMeta = ##class(IRISCouch.Storage.Attachment).GetMetadata(pDB, pDocId, tLeafRev)
                        If $IsObject(tAttMeta) && (tAttMeta.%Size() > 0) {
                            ; In multipart mode, use "follows":true instead of "stub":true
                            Set tFollowsMeta = {}
                            Set tAttIter2 = tAttMeta.%GetIterator()
                            While tAttIter2.%GetNext(.tAN, .tAV) {
                                Set tFollowStub = {}
                                Do tFollowStub.%Set("content_type", tAV.%Get("content_type"))
                                Do tFollowStub.%Set("length", tAV.%Get("length"), "number")
                                Do tFollowStub.%Set("digest", tAV.%Get("digest"))
                                Do tFollowStub.%Set("revpos", tAV.%Get("revpos"), "number")
                                Do tFollowStub.%Set("follows", 1, "boolean")
                                Do tFollowsMeta.%Set(tAN, tFollowStub)
                            }
                            Do tDocObj.%Set("_attachments", tFollowsMeta)
                        }
                        ; Write JSON part
                        Write "--" _ tBoundary _ tCRLF
                        Write "Content-Type: application/json" _ tCRLF
                        Write tCRLF
                        Write tDocObj.%ToJSON() _ tCRLF
                        ; Write binary attachment parts
                        If $IsObject(tAttMeta) && (tAttMeta.%Size() > 0) {
                            Set tAttIter3 = tAttMeta.%GetIterator()
                            While tAttIter3.%GetNext(.tAttName, .tAttStub) {
                                Set tGetSC = ##class(IRISCouch.Storage.Attachment).Get(pDB, pDocId, tAttName, .tStream, .tCT, .tLen, .tDig, tLeafRev)
                                If $$$ISOK(tGetSC) && $IsObject(tStream) {
                                    Write "--" _ tBoundary _ tCRLF
                                    Write "Content-Type: " _ tCT _ tCRLF
                                    Write "Content-Disposition: attachment; filename=""" _ tAttName _ """" _ tCRLF
                                    Write tCRLF
                                    Do tStream.Rewind()
                                    While 'tStream.AtEnd {
                                        Write tStream.Read(32000)
                                    }
                                    Write tCRLF
                                }
                            }
                        }
                    } Else {
                        ; Missing revision — write JSON error part
                        Write "--" _ tBoundary _ tCRLF
                        Write "Content-Type: application/json" _ tCRLF
                        Write tCRLF
                        Set tMissObj = {"missing":""} Do tMissObj.%Set("missing", tLeafRev)
                        Write tMissObj.%ToJSON() _ tCRLF
                    }
                    Set tI = tI + 1
                }
                ; Write closing boundary
                Write "--" _ tBoundary _ "--" _ tCRLF
                Quit
            }
            ; Standard JSON array response for open_revs
            Set tI = 0
            While tI < tRevArray.%Size() {
                Set tLeafRev = tRevArray.%Get(tI)
                Set tLeafBody = ##class(IRISCouch.Storage.Document).Read(pDB, pDocId, tLeafRev)
                If tLeafBody '= "" {
                    Set tLeafObj = ##class(%DynamicObject).%FromJSON(tLeafBody)
                    Set tDocObj = {}
                    Do tDocObj.%Set("_id", pDocId)
                    Do tDocObj.%Set("_rev", tLeafRev)
                    Set tDocIter = tLeafObj.%GetIterator()
                    While tDocIter.%GetNext(.tDocKey, .tDocVal) {
                        Do tDocObj.%Set(tDocKey, tDocVal)
                    }
                    ; Add _attachments stubs for this revision
                    Set tAttMeta = ##class(IRISCouch.Storage.Attachment).GetMetadata(pDB, pDocId, tLeafRev)
                    If $IsObject(tAttMeta) && (tAttMeta.%Size() > 0) {
                        ; Check ?attachments=true — include base64 data in open_revs response
                        If $Get(%request.Data("attachments", 1)) = "true" {
                            Set tAttIter = tAttMeta.%GetIterator()
                            While tAttIter.%GetNext(.tAttName, .tAttStub) {
                                Set tGetSC = ##class(IRISCouch.Storage.Attachment).Get(pDB, pDocId, tAttName, .tStream, .tCT, .tLen, .tDig, tLeafRev)
                                If $$$ISOK(tGetSC) && $IsObject(tStream) {
                                    Do tStream.Rewind()
                                    Set tBinary = ""
                                    While 'tStream.AtEnd { Set tBinary = tBinary _ tStream.Read(32000) }
                                    Set tB64 = $System.Encryption.Base64Encode(tBinary)
                                    Do tAttStub.%Set("data", tB64)
                                    Do tAttStub.%Remove("stub")
                                }
                            }
                        }
                        Do tDocObj.%Set("_attachments", tAttMeta)
                    }
                    Set tEntry = {}
                    Do tEntry.%Set("ok", tDocObj)
                    Do tResultArr.%Push(tEntry)
                } Else {
                    Set tEntry = {}
                    Do tEntry.%Set("missing", tLeafRev)
                    Do tResultArr.%Push(tEntry)
                }
                Set tI = tI + 1
            }
            Do ##class(IRISCouch.Util.Response).JSON(tResultArr)
            Quit
        }
        ; Check for specific rev query parameter
        Set tRev = ""
        If $Data(%request.Data("rev", 1)) {
            Set tRev = $Get(%request.Data("rev", 1))
        }
        ; If no specific rev, get the winning revision
        If tRev = "" {
            Set tRev = ##class(IRISCouch.Storage.RevTree).GetWinner(pDB, pDocId)
            If tRev = "" {
                Do ##class(IRISCouch.Util.Error).Render(404, ##class(IRISCouch.Util.Error).#NOTFOUND, "missing")
                Quit
            }
        }
        ; Check if the revision is deleted (tombstone) — use RevTree.IsDeleted for encapsulation
        If ##class(IRISCouch.Storage.RevTree).IsDeleted(pDB, pDocId, tRev) {
            Do ##class(IRISCouch.Util.Error).Render(404, ##class(IRISCouch.Util.Error).#NOTFOUND, "deleted")
            Quit
        }
        ; Read document body
        Set tBodyStr = ##class(IRISCouch.Storage.Document).Read(pDB, pDocId, tRev)
        If tBodyStr = "" {
            Do ##class(IRISCouch.Util.Error).Render(404, ##class(IRISCouch.Util.Error).#NOTFOUND, "missing")
            Quit
        }
        ; Build response: inject _id and _rev first for CouchDB field ordering
        Set tStoredObj = ##class(%DynamicObject).%FromJSON(tBodyStr)
        Set tRespObj = {}
        Do tRespObj.%Set("_id", pDocId)
        Do tRespObj.%Set("_rev", tRev)
        ; Copy all stored fields into response
        Set tIter = tStoredObj.%GetIterator()
        While tIter.%GetNext(.tKey, .tValue) {
            Do tRespObj.%Set(tKey, tValue)
        }
        ; Add _attachments based on query parameters
        Set tAttMeta = ##class(IRISCouch.Storage.Attachment).GetMetadata(pDB, pDocId, tRev)
        If $IsObject(tAttMeta) && (tAttMeta.%Size() > 0) {
            ; Check ?attachments=true — include base64 data
            If $Get(%request.Data("attachments", 1)) = "true" {
                Set tAttIter = tAttMeta.%GetIterator()
                While tAttIter.%GetNext(.tAttName, .tAttStub) {
                    Set tGetSC = ##class(IRISCouch.Storage.Attachment).Get(pDB, pDocId, tAttName, .tStream, .tCT, .tLen, .tDig, tRev)
                    If $$$ISOK(tGetSC) && $IsObject(tStream) {
                        Do tStream.Rewind()
                        Set tBinary = ""
                        While 'tStream.AtEnd { Set tBinary = tBinary _ tStream.Read(32000) }
                        Set tB64 = $System.Encryption.Base64Encode(tBinary)
                        Do tAttStub.%Set("data", tB64)
                        Do tAttStub.%Remove("stub")
                    }
                }
            }
            ; Check ?atts_since=["rev1","rev2"] — conditional inclusion
            ElseIf $Data(%request.Data("atts_since", 1)) {
                Set tAttsSinceParam = $Get(%request.Data("atts_since", 1))
                Try {
                    Set tAttsSince = ##class(%DynamicArray).%FromJSON(tAttsSinceParam)
                } Catch tParseEx {
                    Do ##class(IRISCouch.Util.Error).Render(400, ##class(IRISCouch.Util.Error).#BADREQUEST, "invalid JSON in atts_since parameter")
                    Return $$$OK
                }
                If $IsObject(tAttsSince) {
                    ; Find max generation across all atts_since revisions
                    Set tMaxGen = 0
                    For tASI = 0:1:(tAttsSince.%Size()-1) {
                        Set tSinceRev = tAttsSince.%Get(tASI)
                        Set tGen = +$Piece(tSinceRev, "-", 1)
                        If tGen > tMaxGen Set tMaxGen = tGen
                    }
                    ; For each attachment: if revpos > maxGen, include data; else stub
                    Set tAttIter = tAttMeta.%GetIterator()
                    While tAttIter.%GetNext(.tAttName, .tAttStub) {
                        Set tRevPos = +tAttStub.%Get("revpos")
                        If tRevPos > tMaxGen {
                            Set tGetSC = ##class(IRISCouch.Storage.Attachment).Get(pDB, pDocId, tAttName, .tStream, .tCT, .tLen, .tDig, tRev)
                            If $$$ISOK(tGetSC) && $IsObject(tStream) {
                                Do tStream.Rewind()
                                Set tBinary = ""
                                While 'tStream.AtEnd { Set tBinary = tBinary _ tStream.Read(32000) }
                                Set tB64 = $System.Encryption.Base64Encode(tBinary)
                                Do tAttStub.%Set("data", tB64)
                                Do tAttStub.%Remove("stub")
                            }
                        }
                    }
                }
            }
            Do tRespObj.%Set("_attachments", tAttMeta)
        }
        ; Add _conflicts if requested
        If $Get(%request.Data("conflicts", 1)) = "true" {
            Set tConflicts = ##class(IRISCouch.Storage.RevTree).GetConflicts(pDB, pDocId)
            Do tRespObj.%Set("_conflicts", tConflicts)
        }
        ; Add _deleted_conflicts if requested (Story 11.4)
        If $Get(%request.Data("deleted_conflicts", 1)) = "true" {
            Set tDeletedConflicts = ##class(IRISCouch.Storage.RevTree).GetDeletedConflicts(pDB, pDocId)
            Do tRespObj.%Set("_deleted_conflicts", tDeletedConflicts)
        }
        ; Add _revisions if requested
        If $Get(%request.Data("revs", 1)) = "true" {
            Set tRevisions = ##class(IRISCouch.Storage.RevTree).GetRevisions(pDB, pDocId, tRev)
            Do tRespObj.%Set("_revisions", tRevisions)
        }
        ; Add _revs_info if requested
        If $Get(%request.Data("revs_info", 1)) = "true" {
            Set tRevsInfo = ##class(IRISCouch.Storage.RevTree).GetRevsInfo(pDB, pDocId, tRev)
            Do tRespObj.%Set("_revs_info", tRevsInfo)
        }
        ; Add _local_seq if requested
        If $Get(%request.Data("local_seq", 1)) = "true" {
            Set tLocalSeq = ##class(IRISCouch.Storage.Changes).GetDocSeq(pDB, pDocId)
            If tLocalSeq '= "" {
                Do tRespObj.%Set("_local_seq", tLocalSeq)
            }
        }
        ; Return 200 OK
        Do ##class(IRISCouch.Util.Response).JSON(tRespObj)
        Quit
    }
    Catch ex {
        Do ##class(IRISCouch.Util.Error).RenderInternal(##class(IRISCouch.Util.Error).#SERVERERROR, "document: get error", ex)
        Quit
    }
    Quit $$$OK
}

/// <p>Render a validate_doc_update rejection, dispatching 401 / 403 / 501 / 500
/// based on the error-prefix emitted by
/// <method>IRISCouch.Core.DocumentEngine.RunValidateHook</method> (Story 12.3).</p>
/// <p>Separates the "AC #4 501" path (runtime=None but validate fn present)
/// from the normal sandbox rejection paths so the handler keeps the envelope
/// crisp. The raw <var>pValidateError</var> is the string returned by
/// <code>$System.Status.GetErrorText</code> — already prefixed with the
/// ObjectScript <code>ERROR #NNNN:</code> framing.</p>
/// @param pValidateError The validate-error text from DocumentEngine
ClassMethod RenderValidate(pValidateError As %String)
{
    ; Peel the IRIS ERROR framing once so the Util.Error helpers get a clean
    ; "forbidden:..." / "unauthorized:..." / "not_implemented:..." string.
    Set tMsg = pValidateError
    Set tColon = $Find(tMsg, ": ")
    If tColon > 0 {
        Set tTail = $Extract(tMsg, tColon, *)
        If tTail '= "" Set tMsg = tTail
    }
    If $Extract(tMsg, 1, 17) = "not_implemented: " {
        ; AC #4 path: runtime=None AND validate ddoc present.
        Do ##class(IRISCouch.Util.Error).RenderValidate501()
        Quit
    }
    ; All other shapes (forbidden / unauthorized / validate_error) go through
    ; the shared validate-error envelope helper.
    Do ##class(IRISCouch.Util.Error).RenderValidateError(tMsg)
    Quit
}

/// <p>Render a timeout/index-error envelope per the pIndexError object
/// produced by <method>IRISCouch.Core.DocumentEngine.Save</method>
/// (Story 13.4 Task 4).</p>
/// <p>Emits <code>{"error":"timeout","reason":"&lt;...&gt;"}</code> with HTTP
/// 500 for <code>classification == "timeout"</code>. The status is 500 (not
/// 504) because the caller's HTTP transaction completed normally — the
/// JS-side map function was what ran long. CouchDB's wire contract uses 500
/// for server-internal aborts of this shape.</p>
/// @param pIndexError The %DynamicObject populated by Save's pIndexError output
ClassMethod RenderIndexError(pIndexError As %DynamicObject)
{
    Set tClass = ""
    Set tReason = "view index update failed"
    If $IsObject(pIndexError) {
        Set tClass = pIndexError.%Get("classification")
        Set tRawReason = pIndexError.%Get("reason")
        If tRawReason '= "" Set tReason = tRawReason
    }
    If tClass = "timeout" {
        Set %response.Status = 500
        Set %response.ContentType = "application/json"
        Set tObj = {}
        Do tObj.%Set("error", "timeout")
        Do tObj.%Set("reason", tReason)
        Write tObj.%ToJSON()
        Quit
    }
    ; Fallback — unclassified index error folds to server_error
    Do ##class(IRISCouch.Util.Error).RenderInternal(##class(IRISCouch.Util.Error).#SERVERERROR, "document: view index update failed")
    Quit
}

/// <p>Validate that a document body contains no disallowed underscore-prefixed fields.</p>
/// <p>CouchDB reserves fields starting with underscore. Only <code>_id</code>,
/// <code>_rev</code>, <code>_deleted</code>, <code>_revisions</code>, and
/// <code>_attachments</code> are allowed at the top level.</p>
/// @param pBody The parsed JSON body as %DynamicObject
/// @return %String Empty string if valid, or the bad field name (e.g., "_foo") if invalid
ClassMethod ValidateFields(pBody As %DynamicObject) As %String
{
    Set tResult = ""
    Set tIter = pBody.%GetIterator()
    While tIter.%GetNext(.tKey, .tValue) {
        If $Extract(tKey, 1) = "_" {
            If (tKey '= "_id") && (tKey '= "_rev") && (tKey '= "_deleted") && (tKey '= "_revisions") && (tKey '= "_attachments") {
                Set tResult = tKey
                Quit
            }
        }
    }
    Quit tResult
}

}
