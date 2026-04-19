/// <p>HTTP handler for bulk document operations.</p>
/// <p>Handles <code>POST /{db}/_bulk_docs</code> (create/update multiple documents)
/// and <code>POST /{db}/_bulk_get</code> (retrieve multiple documents by ID).
/// Extracted from <class>IRISCouch.API.DocumentHandler</class> for separation of concerns.</p>
Class IRISCouch.API.BulkHandler Extends %RegisteredObject
{

/// <p>Handle <code>POST /{db}/_bulk_docs</code> — create or update multiple documents in a single request.</p>
/// <p>Each document is processed independently through <method>DocumentEngine.Save</method>.
/// A conflict in one document does NOT fail the entire batch. The response array
/// has one entry per input document, in the same order.</p>
/// @param pDB The database name from the URL path
/// @return %Status
ClassMethod HandleBulkDocs(pDB As %String) As %Status
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
        ; Check for new_edits=false — replication mode
        If tBody.%IsDefined("new_edits") {
            If (tBody.%Get("new_edits") = "false") || (tBody.%Get("new_edits") = 0) {
                ; Extract docs array
                If 'tBody.%IsDefined("docs") || (tBody.%GetTypeOf("docs") '= "array") {
                    Do ##class(IRISCouch.Util.Error).Render(400, ##class(IRISCouch.Util.Error).#BADREQUEST, "Request body must contain a ""docs"" array.")
                    Quit
                }
                Set tDocs = tBody.%Get("docs")
                Set tI = 0
                Set tValidationError = 0
                While tI < tDocs.%Size() {
                    Set tDoc = tDocs.%Get(tI)
                    Set tI = tI + 1
                    ; _id is required for new_edits=false
                    Set tDocId = ""
                    If tDoc.%IsDefined("_id") {
                        Set tDocId = tDoc.%Get("_id")
                    }
                    If tDocId = "" {
                        Do ##class(IRISCouch.Util.Error).Render(400, ##class(IRISCouch.Util.Error).#BADREQUEST, "Document must have an _id for new_edits=false.")
                        Set tValidationError = 1
                        Quit
                    }
                    ; _rev is required
                    Set tRev = ""
                    If tDoc.%IsDefined("_rev") {
                        Set tRev = tDoc.%Get("_rev")
                    }
                    If tRev = "" {
                        Do ##class(IRISCouch.Util.Error).Render(400, ##class(IRISCouch.Util.Error).#BADREQUEST, "Document must have a _rev for new_edits=false.")
                        Set tValidationError = 1
                        Quit
                    }
                    ; Extract _revisions (optional but typical)
                    Set tRevisions = ""
                    If tDoc.%IsDefined("_revisions") {
                        Set tRevisions = tDoc.%Get("_revisions")
                    }
                    ; Extract _deleted flag
                    Set tDeleted = 0
                    If tDoc.%IsDefined("_deleted") {
                        If (tDoc.%Get("_deleted") = "true") || (tDoc.%Get("_deleted") = 1) {
                            Set tDeleted = 1
                        }
                    }
                    ; Remove metadata fields from body before storing
                    If tDoc.%IsDefined("_id") Do tDoc.%Remove("_id")
                    If tDoc.%IsDefined("_rev") Do tDoc.%Remove("_rev")
                    If tDoc.%IsDefined("_revisions") Do tDoc.%Remove("_revisions")
                    If tDoc.%IsDefined("_deleted") Do tDoc.%Remove("_deleted")
                    If tDoc.%IsDefined("_attachments") Do tDoc.%Remove("_attachments")
                    ; Call SaveWithHistory
                    Set tSC2 = ##class(IRISCouch.Core.DocumentEngine).SaveWithHistory(pDB, tDocId, tDoc.%ToJSON(), tRev, tRevisions, tDeleted)
                    ; Errors are silently ignored per CouchDB spec for new_edits=false
                }
                ; Only return 201 if no validation error occurred
                If 'tValidationError {
                    ; Return 201 with empty array per CouchDB spec
                    Do ##class(IRISCouch.Util.Response).JSONStatus(201, [])
                }
                Quit
            }
        }
        ; Extract docs array
        If 'tBody.%IsDefined("docs") || (tBody.%GetTypeOf("docs") '= "array") {
            Do ##class(IRISCouch.Util.Error).Render(400, ##class(IRISCouch.Util.Error).#BADREQUEST, "Request body must contain a ""docs"" array.")
            Quit
        }
        Set tDocs = tBody.%Get("docs")
        Set tResults = []
        Set tI = 0
        While tI < tDocs.%Size() {
            Set tDoc = tDocs.%Get(tI)
            Set tI = tI + 1
            ; Extract _id or generate UUID
            Set tDocId = ""
            If tDoc.%IsDefined("_id") {
                Set tDocId = tDoc.%Get("_id")
            }
            If tDocId = "" {
                Set tDocId = ##class(IRISCouch.Util.UUID).Generate()
            }
            ; Extract _rev
            Set tRev = ""
            If tDoc.%IsDefined("_rev") {
                Set tRev = tDoc.%Get("_rev")
            }
            ; Validate underscore fields
            Set tValErr = ##class(IRISCouch.API.DocumentHandler).ValidateFields(tDoc)
            If tValErr '= "" {
                Do tResults.%Push(..BuildErrorEntry(tDocId, "bad_request", "Bad special document member: " _ tValErr))
                Continue
            }
            ; Check for _deleted:true
            Set tDeleted = 0
            If tDoc.%IsDefined("_deleted") {
                If (tDoc.%Get("_deleted") = "true") || (tDoc.%Get("_deleted") = 1) {
                    Set tDeleted = 1
                }
            }
            If tDeleted {
                ; Need a valid _rev to delete
                If tRev = "" {
                    Do tResults.%Push(..BuildErrorEntry(tDocId, "conflict", "Document update conflict."))
                    Continue
                }
                ; Verify doc exists and rev matches winner
                If '##class(IRISCouch.Storage.Document).Exists(pDB, tDocId) {
                    Do tResults.%Push(..BuildErrorEntry(tDocId, "not_found", "missing"))
                    Continue
                }
                Set tCurrentWinner = ##class(IRISCouch.Storage.RevTree).GetWinner(pDB, tDocId)
                If tRev '= tCurrentWinner {
                    Do tResults.%Push(..BuildErrorEntry(tDocId, "conflict", "Document update conflict."))
                    Continue
                }
                Set tValidateError = ""
                Set tNewRev = ##class(IRISCouch.Core.DocumentEngine).SaveDeleted(pDB, tDocId, tRev, .tValidateError)
                If tNewRev = "" {
                    If tValidateError '= "" {
                        Do tResults.%Push(..BuildValidateErrorEntry(tDocId, tValidateError))
                    } Else {
                        Do tResults.%Push(..BuildErrorEntry(tDocId, "conflict", "Document update conflict."))
                    }
                    Continue
                }
                Set tEntry = {}
                Do tEntry.%Set("ok", 1, "boolean")
                Do tEntry.%Set("id", tDocId)
                Do tEntry.%Set("rev", tNewRev)
                Do tResults.%Push(tEntry)
                Continue
            }
            ; Optimistic concurrency: if doc exists
            If ##class(IRISCouch.Storage.Document).Exists(pDB, tDocId) {
                If tRev = "" {
                    ; Doc exists but no _rev provided — conflict
                    Do tResults.%Push(..BuildErrorEntry(tDocId, "conflict", "Document update conflict."))
                    Continue
                }
                ; Verify _rev matches current winner
                Set tCurrentWinner = ##class(IRISCouch.Storage.RevTree).GetWinner(pDB, tDocId)
                If tRev '= tCurrentWinner {
                    Do tResults.%Push(..BuildErrorEntry(tDocId, "conflict", "Document update conflict."))
                    Continue
                }
            }
            ; Remove metadata fields before saving
            If tDoc.%IsDefined("_id") Do tDoc.%Remove("_id")
            If tDoc.%IsDefined("_rev") Do tDoc.%Remove("_rev")
            If tDoc.%IsDefined("_deleted") Do tDoc.%Remove("_deleted")
            ; Save document
            Set tValidateError = ""
            Set tIndexError = ""
            Set tNewRev = ##class(IRISCouch.Core.DocumentEngine).Save(pDB, tDocId, tDoc.%ToJSON(), tRev, .tValidateError, .tIndexError)
            If tNewRev = "" {
                If tValidateError '= "" {
                    Do tResults.%Push(..BuildValidateErrorEntry(tDocId, tValidateError))
                } ElseIf $IsObject(tIndexError) && (tIndexError.%Get("classification") = "timeout") {
                    ; Story 13.4 Task 4: surface per-doc timeout classification.
                    Set tReason = tIndexError.%Get("reason")
                    If tReason = "" Set tReason = "subprocess exceeded timeout"
                    Do tResults.%Push(..BuildErrorEntry(tDocId, "timeout", tReason))
                } Else {
                    Do tResults.%Push(..BuildErrorEntry(tDocId, "conflict", "Document update conflict."))
                }
                Continue
            }
            Set tEntry = {}
            Do tEntry.%Set("ok", 1, "boolean")
            Do tEntry.%Set("id", tDocId)
            Do tEntry.%Set("rev", tNewRev)
            Do tResults.%Push(tEntry)
        }
        ; Return 201 with results array
        Do ##class(IRISCouch.Util.Response).JSONStatus(201, tResults)
        Quit
    }
    Catch ex {
        Do ##class(IRISCouch.Util.Error).RenderInternal(##class(IRISCouch.Util.Error).#SERVERERROR, "document: bulk_docs error", ex)
        Quit
    }
    Quit $$$OK
}

/// <p>Handle <code>POST /{db}/_bulk_get</code> — retrieve multiple documents by ID in a single request.</p>
/// <p>Returns a results array with each document or an error entry for missing documents.
/// Supports <code>?revs=true</code> to include revision history and
/// <code>?attachments=true</code> to include inline base64 attachment data.</p>
/// @param pDB The database name from the URL path
/// @return %Status
ClassMethod HandleBulkGet(pDB As %String) As %Status
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
        ; Extract docs array
        If 'tBody.%IsDefined("docs") || (tBody.%GetTypeOf("docs") '= "array") {
            Do ##class(IRISCouch.Util.Error).Render(400, ##class(IRISCouch.Util.Error).#BADREQUEST, "Request body must contain a ""docs"" array.")
            Quit
        }
        Set tDocs = tBody.%Get("docs")
        ; Check for revs=true query parameter
        Set tRevsFlag = 0
        If $Get(%request.Data("revs", 1)) = "true" {
            Set tRevsFlag = 1
        }
        ; Check for attachments=true query parameter
        Set tAttachmentsFlag = ($Get(%request.Data("attachments", 1)) = "true")
        Set tResults = []
        Set tI = 0
        While tI < tDocs.%Size() {
            Set tDocReq = tDocs.%Get(tI)
            Set tI = tI + 1
            ; Extract id (required)
            Set tDocId = ""
            If tDocReq.%IsDefined("id") {
                Set tDocId = tDocReq.%Get("id")
            }
            If tDocId = "" {
                Continue
            }
            ; Extract rev (optional — specific revision)
            Set tRev = ""
            If tDocReq.%IsDefined("rev") {
                Set tRev = tDocReq.%Get("rev")
            }
            ; If no rev, get the winning revision
            If tRev = "" {
                Set tRev = ##class(IRISCouch.Storage.RevTree).GetWinner(pDB, tDocId)
            }
            ; Check if the revision is deleted
            Set tIsDeleted = 0
            If tRev '= "" {
                Set tIsDeleted = ##class(IRISCouch.Storage.RevTree).IsDeleted(pDB, tDocId, tRev)
            }
            ; Read document body
            Set tBodyStr = ""
            If (tRev '= "") && ('tIsDeleted) {
                Set tBodyStr = ##class(IRISCouch.Storage.Document).Read(pDB, tDocId, tRev)
            }
            Set tResultEntry = {}
            Do tResultEntry.%Set("id", tDocId)
            If tBodyStr '= "" {
                ; Document found — build ok entry
                Set tDocObj = {}
                Do tDocObj.%Set("_id", tDocId)
                Do tDocObj.%Set("_rev", tRev)
                ; If revs=true, add _revisions
                If tRevsFlag {
                    Set tRevisions = ##class(IRISCouch.Storage.RevTree).GetRevisions(pDB, tDocId, tRev)
                    Do tDocObj.%Set("_revisions", tRevisions)
                }
                ; Add _attachments if document has any
                Set tAttMeta = ##class(IRISCouch.Storage.Attachment).GetMetadata(pDB, tDocId, tRev)
                If $IsObject(tAttMeta) {
                    If tAttachmentsFlag {
                        ; Inline mode: replace stub:true with base64 data for each attachment
                        ; Collect attachment names first to avoid mutating during iteration
                        Set tAttNames = ""
                        Set tAttIter = tAttMeta.%GetIterator()
                        While tAttIter.%GetNext(.tAttName, .tAttStub) {
                            Set tAttNames = tAttNames _ $ListBuild(tAttName)
                        }
                        ; Now iterate the collected names and replace stubs with inline data
                        Set tAttIdx = 0
                        While $ListNext(tAttNames, tAttIdx, tAttName) {
                            Set tAttStub = tAttMeta.%Get(tAttName)
                            Set tAttSC = ##class(IRISCouch.Storage.Attachment).Get(pDB, tDocId, tAttName, .tStream, .tCType, .tLen, .tDigest, tRev)
                            If $$$ISOK(tAttSC) && $IsObject(tStream) {
                                ; Build inline attachment entry
                                Set tInline = {}
                                Do tInline.%Set("content_type", tAttStub.%Get("content_type"))
                                Do tInline.%Set("length", +tAttStub.%Get("length"), "number")
                                Do tInline.%Set("digest", tAttStub.%Get("digest"))
                                Do tInline.%Set("revpos", +tAttStub.%Get("revpos"), "number")
                                ; Read entire stream and base64 encode in one pass
                                ; Single Read() avoids multi-chunk padding issues (~2.7MB max)
                                Do tStream.Rewind()
                                Set tBinary = tStream.Read(3600000)
                                Set tBase64 = $System.Encryption.Base64Encode(tBinary)
                                Do tInline.%Set("data", tBase64)
                                ; Replace stub entry with inline entry (no stub:true)
                                Do tAttMeta.%Set(tAttName, tInline)
                            }
                        }
                    }
                    ; Include _attachments (stubs or inline depending on flag)
                    Do tDocObj.%Set("_attachments", tAttMeta)
                }
                ; Copy stored fields
                Set tStoredObj = ##class(%DynamicObject).%FromJSON(tBodyStr)
                Set tIter = tStoredObj.%GetIterator()
                While tIter.%GetNext(.tKey, .tValue) {
                    Do tDocObj.%Set(tKey, tValue)
                }
                Set tDocsArr = []
                Set tOkEntry = {}
                Do tOkEntry.%Set("ok", tDocObj)
                Do tDocsArr.%Push(tOkEntry)
                Do tResultEntry.%Set("docs", tDocsArr)
            } Else {
                ; Document not found — build error entry
                Set tErrObj = {}
                Do tErrObj.%Set("id", tDocId)
                If tRev '= "" {
                    Do tErrObj.%Set("rev", tRev)
                } Else {
                    Do tErrObj.%Set("rev", "undefined")
                }
                Do tErrObj.%Set("error", "not_found")
                Do tErrObj.%Set("reason", "missing")
                Set tDocsArr = []
                Set tErrWrapper = {}
                Do tErrWrapper.%Set("error", tErrObj)
                Do tDocsArr.%Push(tErrWrapper)
                Do tResultEntry.%Set("docs", tDocsArr)
            }
            Do tResults.%Push(tResultEntry)
        }
        ; Return 200 with wrapper
        Set tWrapper = {}
        Do tWrapper.%Set("results", tResults)
        Do ##class(IRISCouch.Util.Response).JSON(tWrapper)
        Quit
    }
    Catch ex {
        Do ##class(IRISCouch.Util.Error).RenderInternal(##class(IRISCouch.Util.Error).#SERVERERROR, "document: bulk_get error", ex)
        Quit
    }
    Quit $$$OK
}

/// <p>Build an error entry for bulk docs response.</p>
/// <p>Constructs a <class>%DynamicObject</class> with <code>id</code>, <code>error</code>,
/// and <code>reason</code> fields. Used by <method>HandleBulkDocs</method> to avoid
/// repetitive error-entry construction across multiple error paths.</p>
/// @param pDocId The document identifier
/// @param pError The error slug (e.g., "conflict", "not_found", "bad_request")
/// @param pReason The human-readable reason string
/// @return %DynamicObject The error entry
ClassMethod BuildErrorEntry(pDocId As %String, pError As %String, pReason As %String) As %DynamicObject
{
    Set tEntry = {}
    Do tEntry.%Set("id", pDocId)
    Do tEntry.%Set("error", pError)
    Do tEntry.%Set("reason", pReason)
    Quit tEntry
}

/// <p>Build a validate-error entry for bulk docs response (Story 12.3).</p>
/// <p>Maps the prefixed validate error to CouchDB's per-doc result envelope
/// — <code>{id, error:"forbidden"|"unauthorized"|"not_implemented"|"validate_error", reason}</code>
/// — so callers of <code>_bulk_docs</code> see the same shape as a single
/// PUT would return, just inline in the results array.</p>
/// @param pDocId The document identifier
/// @param pValidateError The engine's prefixed error string (e.g.
///        <code>ERROR #5001: forbidden: nope</code>)
/// @return %DynamicObject The error entry
ClassMethod BuildValidateErrorEntry(pDocId As %String, pValidateError As %String) As %DynamicObject
{
    ; Peel the IRIS ERROR #NNNN: framing
    Set tMsg = pValidateError
    Set tColon = $Find(tMsg, ": ")
    If tColon > 0 {
        Set tTail = $Extract(tMsg, tColon, *)
        If tTail '= "" Set tMsg = tTail
    }
    If $Extract(tMsg, 1, 11) = "forbidden: " {
        Quit ..BuildErrorEntry(pDocId, "forbidden", $Extract(tMsg, 12, *))
    }
    If $Extract(tMsg, 1, 14) = "unauthorized: " {
        Quit ..BuildErrorEntry(pDocId, "unauthorized", $Extract(tMsg, 15, *))
    }
    If $Extract(tMsg, 1, 17) = "not_implemented: " {
        Quit ..BuildErrorEntry(pDocId, "not_implemented", $Extract(tMsg, 18, *))
    }
    Quit ..BuildErrorEntry(pDocId, "validate_error", tMsg)
}

}
