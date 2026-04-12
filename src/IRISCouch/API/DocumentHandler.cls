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
            Quit
        }
        ; Validate underscore fields
        Set tValErr = ..ValidateFields(tBody)
        If tValErr '= "" {
            Do ##class(IRISCouch.Util.Error).Render(400, ##class(IRISCouch.Util.Error).#DOCVALIDATION, "Bad special document member: " _ tValErr)
            Quit
        }
        ; POST always generates a server UUID — ignore any client _id
        Set tDocId = ##class(IRISCouch.Util.UUID).Generate()
        ; Remove metadata fields before storing
        If tBody.%IsDefined("_id") Do tBody.%Remove("_id")
        If tBody.%IsDefined("_rev") Do tBody.%Remove("_rev")
        If tBody.%IsDefined("_deleted") Do tBody.%Remove("_deleted")
        ; Save document
        Set tNewRev = ##class(IRISCouch.Core.DocumentEngine).Save(pDB, tDocId, tBody.%ToJSON())
        If tNewRev = "" {
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
            Quit
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
            Set tNewRev = ##class(IRISCouch.Core.DocumentEngine).SaveDeleted(pDB, pDocId, tRev)
            If tNewRev = "" {
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
        ; Remove metadata fields before storing
        If tBody.%IsDefined("_id") Do tBody.%Remove("_id")
        If tBody.%IsDefined("_rev") Do tBody.%Remove("_rev")
        If tBody.%IsDefined("_deleted") Do tBody.%Remove("_deleted")
        ; Save document
        Set tNewRev = ##class(IRISCouch.Core.DocumentEngine).Save(pDB, pDocId, tBody.%ToJSON(), tRev)
        If tNewRev = "" {
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
        Set tNewRev = ##class(IRISCouch.Core.DocumentEngine).SaveDeleted(pDB, pDocId, tRev)
        If tNewRev = "" {
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
                    Quit
                }
            }
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
        ; Add _conflicts if requested
        If $Get(%request.Data("conflicts", 1)) = "true" {
            Set tConflicts = ##class(IRISCouch.Storage.RevTree).GetConflicts(pDB, pDocId)
            Do tRespObj.%Set("_conflicts", tConflicts)
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
            Set tLocalSeq = ""
            Set tSeq = ""
            For {
                Set tSeq = $Order(^IRISCouch.Changes(pDB, tSeq), -1)
                Quit:tSeq=""
                Set tEntry = ^IRISCouch.Changes(pDB, tSeq)
                If $ListGet(tEntry, 1) = pDocId {
                    Set tLocalSeq = tSeq
                    Quit
                }
            }
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
            Quit
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
            Set tValErr = ..ValidateFields(tDoc)
            If tValErr '= "" {
                Set tEntry = {}
                Do tEntry.%Set("id", tDocId)
                Do tEntry.%Set("error", "bad_request")
                Do tEntry.%Set("reason", "Bad special document member: " _ tValErr)
                Do tResults.%Push(tEntry)
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
                    Set tEntry = {}
                    Do tEntry.%Set("id", tDocId)
                    Do tEntry.%Set("error", "conflict")
                    Do tEntry.%Set("reason", "Document update conflict.")
                    Do tResults.%Push(tEntry)
                    Continue
                }
                ; Verify doc exists and rev matches winner
                If '##class(IRISCouch.Storage.Document).Exists(pDB, tDocId) {
                    Set tEntry = {}
                    Do tEntry.%Set("id", tDocId)
                    Do tEntry.%Set("error", "not_found")
                    Do tEntry.%Set("reason", "missing")
                    Do tResults.%Push(tEntry)
                    Continue
                }
                Set tCurrentWinner = ##class(IRISCouch.Storage.RevTree).GetWinner(pDB, tDocId)
                If tRev '= tCurrentWinner {
                    Set tEntry = {}
                    Do tEntry.%Set("id", tDocId)
                    Do tEntry.%Set("error", "conflict")
                    Do tEntry.%Set("reason", "Document update conflict.")
                    Do tResults.%Push(tEntry)
                    Continue
                }
                Set tNewRev = ##class(IRISCouch.Core.DocumentEngine).SaveDeleted(pDB, tDocId, tRev)
                If tNewRev = "" {
                    Set tEntry = {}
                    Do tEntry.%Set("id", tDocId)
                    Do tEntry.%Set("error", "conflict")
                    Do tEntry.%Set("reason", "Document update conflict.")
                    Do tResults.%Push(tEntry)
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
                    Set tEntry = {}
                    Do tEntry.%Set("id", tDocId)
                    Do tEntry.%Set("error", "conflict")
                    Do tEntry.%Set("reason", "Document update conflict.")
                    Do tResults.%Push(tEntry)
                    Continue
                }
                ; Verify _rev matches current winner
                Set tCurrentWinner = ##class(IRISCouch.Storage.RevTree).GetWinner(pDB, tDocId)
                If tRev '= tCurrentWinner {
                    Set tEntry = {}
                    Do tEntry.%Set("id", tDocId)
                    Do tEntry.%Set("error", "conflict")
                    Do tEntry.%Set("reason", "Document update conflict.")
                    Do tResults.%Push(tEntry)
                    Continue
                }
            }
            ; Remove metadata fields before saving
            If tDoc.%IsDefined("_id") Do tDoc.%Remove("_id")
            If tDoc.%IsDefined("_rev") Do tDoc.%Remove("_rev")
            If tDoc.%IsDefined("_deleted") Do tDoc.%Remove("_deleted")
            ; Save document
            Set tNewRev = ##class(IRISCouch.Core.DocumentEngine).Save(pDB, tDocId, tDoc.%ToJSON(), tRev)
            If tNewRev = "" {
                Set tEntry = {}
                Do tEntry.%Set("id", tDocId)
                Do tEntry.%Set("error", "conflict")
                Do tEntry.%Set("reason", "Document update conflict.")
                Do tResults.%Push(tEntry)
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
/// Supports <code>?revs=true</code> to include revision history.</p>
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
            Quit
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

/// <p>Handle <code>GET /{db}/_all_docs</code> — list all documents with pagination and key-range filtering.</p>
/// <p>Returns rows sorted by document ID ascending. Supports <code>limit</code>, <code>skip</code>,
/// <code>startkey</code>, <code>endkey</code>, <code>inclusive_end</code>, <code>descending</code>,
/// and <code>include_docs</code> query parameters.</p>
/// @param pDB The database name from the URL path
/// @return %Status
ClassMethod HandleAllDocs(pDB As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        ; Check database exists
        If '##class(IRISCouch.Storage.Database).Exists(pDB) {
            Do ##class(IRISCouch.Util.Error).Render(404, ##class(IRISCouch.Util.Error).#NOTFOUND, "Database does not exist.")
            Quit
        }
        ; Parse query parameters
        Set tLimit = $Get(%request.Data("limit", 1))
        Set tSkip = +$Get(%request.Data("skip", 1))
        Set tStartKey = $Get(%request.Data("startkey", 1))
        Set tEndKey = $Get(%request.Data("endkey", 1))
        Set tIncludeDocs = ($Get(%request.Data("include_docs", 1)) = "true")
        Set tDescending = ($Get(%request.Data("descending", 1)) = "true")
        Set tInclusiveEnd = 1
        If $Data(%request.Data("inclusive_end", 1)) {
            Set tInclusiveEnd = ($Get(%request.Data("inclusive_end", 1)) '= "false")
        }
        ; Strip surrounding quotes from startkey/endkey (CouchDB JSON-encodes them)
        If ($Extract(tStartKey, 1) = """") {
            Set tStartKey = $Extract(tStartKey, 2, $Length(tStartKey) - 1)
        }
        If ($Extract(tEndKey, 1) = """") {
            Set tEndKey = $Extract(tEndKey, 2, $Length(tEndKey) - 1)
        }
        ; Get total_rows (all non-deleted docs, unaffected by filters)
        Set tTotalRows = ##class(IRISCouch.Storage.Document).CountNonDeleted(pDB)
        ; Handle descending: swap start/end keys for $Order direction
        Set tDirection = 1
        If tDescending {
            Set tDirection = -1
            ; Swap startkey and endkey for descending
            Set tTemp = tStartKey
            Set tStartKey = tEndKey
            Set tEndKey = tTemp
        }
        ; Build rows
        Set tRows = []
        Set tSkipped = 0
        Set tCount = 0
        ; Determine starting point for $Order
        If tStartKey '= "" {
            ; Start just before startkey so $Order returns startkey first
            If tDirection = 1 {
                Set tDocId = $Order(^IRISCouch.Docs(pDB, tStartKey), 1)
                ; Check if startkey itself exists
                If $Data(^IRISCouch.Docs(pDB, tStartKey)) {
                    Set tDocId = tStartKey
                }
            } Else {
                Set tDocId = $Order(^IRISCouch.Docs(pDB, tStartKey), -1)
                If $Data(^IRISCouch.Docs(pDB, tStartKey)) {
                    Set tDocId = tStartKey
                }
            }
        } Else {
            Set tDocId = $Order(^IRISCouch.Docs(pDB, ""), tDirection)
        }
        ; Iterate through documents
        For {
            Quit:tDocId=""
            ; Apply endkey filtering
            If tEndKey '= "" {
                If tDirection = 1 {
                    If tInclusiveEnd {
                        Quit:(tDocId]tEndKey)
                    } Else {
                        Quit:(tDocId]]tEndKey)!(tDocId=tEndKey)
                    }
                } Else {
                    If tInclusiveEnd {
                        Quit:(tEndKey]tDocId)
                    } Else {
                        Quit:(tEndKey]]tDocId)!(tDocId=tEndKey)
                    }
                }
            }
            ; Get winning rev, skip deleted
            Set tWinRev = ##class(IRISCouch.Storage.RevTree).GetWinner(pDB, tDocId)
            If tWinRev = "" {
                Set tDocId = $Order(^IRISCouch.Docs(pDB, tDocId), tDirection)
                Continue
            }
            If ##class(IRISCouch.Storage.RevTree).IsDeleted(pDB, tDocId, tWinRev) {
                Set tDocId = $Order(^IRISCouch.Docs(pDB, tDocId), tDirection)
                Continue
            }
            ; Apply skip
            If tSkipped < tSkip {
                Set tSkipped = tSkipped + 1
                Set tDocId = $Order(^IRISCouch.Docs(pDB, tDocId), tDirection)
                Continue
            }
            ; Apply limit
            If (tLimit '= "") && (tCount >= +tLimit) {
                Quit
            }
            ; Build row
            Set tRow = {}
            Do tRow.%Set("id", tDocId)
            Do tRow.%Set("key", tDocId)
            Set tValue = {}
            Do tValue.%Set("rev", tWinRev)
            Do tRow.%Set("value", tValue)
            ; Include full document body if requested
            If tIncludeDocs {
                Set tBodyStr = ##class(IRISCouch.Storage.Document).Read(pDB, tDocId, tWinRev)
                If tBodyStr '= "" {
                    Set tDocObj = ##class(%DynamicObject).%FromJSON(tBodyStr)
                    ; Inject _id and _rev
                    Set tFullDoc = {}
                    Do tFullDoc.%Set("_id", tDocId)
                    Do tFullDoc.%Set("_rev", tWinRev)
                    Set tDocIter = tDocObj.%GetIterator()
                    While tDocIter.%GetNext(.tDKey, .tDVal) {
                        Do tFullDoc.%Set(tDKey, tDVal)
                    }
                    Do tRow.%Set("doc", tFullDoc)
                }
            }
            Do tRows.%Push(tRow)
            Set tCount = tCount + 1
            Set tDocId = $Order(^IRISCouch.Docs(pDB, tDocId), tDirection)
        }
        ; Build response
        Set tResp = {}
        Do tResp.%Set("total_rows", tTotalRows, "number")
        Do tResp.%Set("offset", tSkip, "number")
        Do tResp.%Set("rows", tRows)
        Do ##class(IRISCouch.Util.Response).JSON(tResp)
        Quit
    }
    Catch ex {
        Do ##class(IRISCouch.Util.Error).RenderInternal(##class(IRISCouch.Util.Error).#SERVERERROR, "document: all_docs error", ex)
        Quit
    }
    Quit $$$OK
}

/// <p>Handle <code>POST /{db}/_all_docs</code> — retrieve documents by specific keys.</p>
/// <p>Accepts a JSON body with a <code>keys</code> array. Returns rows in the same
/// order as the keys array. Missing or deleted documents get an error row.</p>
/// @param pDB The database name from the URL path
/// @return %Status
ClassMethod HandleAllDocsPost(pDB As %String) As %Status
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
            Quit
        }
        ; Extract keys array
        If 'tBody.%IsDefined("keys") || (tBody.%GetTypeOf("keys") '= "array") {
            Do ##class(IRISCouch.Util.Error).Render(400, ##class(IRISCouch.Util.Error).#BADREQUEST, "Request body must contain a ""keys"" array.")
            Quit
        }
        Set tKeys = tBody.%Get("keys")
        ; Parse include_docs from query params
        Set tIncludeDocs = ($Get(%request.Data("include_docs", 1)) = "true")
        ; Get total_rows
        Set tTotalRows = ##class(IRISCouch.Storage.Document).CountNonDeleted(pDB)
        ; Build rows in order of keys array
        Set tRows = []
        Set tI = 0
        While tI < tKeys.%Size() {
            Set tDocId = tKeys.%Get(tI)
            Set tI = tI + 1
            ; Look up the document
            Set tWinRev = ##class(IRISCouch.Storage.RevTree).GetWinner(pDB, tDocId)
            If (tWinRev = "") || (##class(IRISCouch.Storage.RevTree).IsDeleted(pDB, tDocId, tWinRev)) {
                ; Not found or deleted — error row
                Set tRow = {}
                Do tRow.%Set("key", tDocId)
                Do tRow.%Set("error", "not_found")
                Do tRows.%Push(tRow)
                Continue
            }
            ; Found — normal row
            Set tRow = {}
            Do tRow.%Set("id", tDocId)
            Do tRow.%Set("key", tDocId)
            Set tValue = {}
            Do tValue.%Set("rev", tWinRev)
            Do tRow.%Set("value", tValue)
            ; Include full document body if requested
            If tIncludeDocs {
                Set tBodyStr = ##class(IRISCouch.Storage.Document).Read(pDB, tDocId, tWinRev)
                If tBodyStr '= "" {
                    Set tDocObj = ##class(%DynamicObject).%FromJSON(tBodyStr)
                    Set tFullDoc = {}
                    Do tFullDoc.%Set("_id", tDocId)
                    Do tFullDoc.%Set("_rev", tWinRev)
                    Set tDocIter = tDocObj.%GetIterator()
                    While tDocIter.%GetNext(.tDKey, .tDVal) {
                        Do tFullDoc.%Set(tDKey, tDVal)
                    }
                    Do tRow.%Set("doc", tFullDoc)
                }
            }
            Do tRows.%Push(tRow)
        }
        ; Build response
        Set tResp = {}
        Do tResp.%Set("total_rows", tTotalRows, "number")
        Do tResp.%Set("offset", 0, "number")
        Do tResp.%Set("rows", tRows)
        Do ##class(IRISCouch.Util.Response).JSON(tResp)
        Quit
    }
    Catch ex {
        Do ##class(IRISCouch.Util.Error).RenderInternal(##class(IRISCouch.Util.Error).#SERVERERROR, "document: all_docs_post error", ex)
        Quit
    }
    Quit $$$OK
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
