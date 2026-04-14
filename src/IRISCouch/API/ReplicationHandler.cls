/// <p>HTTP handler for local (non-replicating) document CRUD operations.</p>
/// <p>Handles <code>GET /{db}/_local/{id}</code> (retrieve local document),
/// <code>PUT /{db}/_local/{id}</code> (create/update local document),
/// and <code>DELETE /{db}/_local/{id}</code> (delete local document).</p>
/// <p>Local documents use a simple <code>0-N</code> revision scheme and are
/// stored separately from normal documents. They do not appear in views,
/// changes feeds, or <code>_all_docs</code>.</p>
/// <p>Delegates to <class>IRISCouch.Storage.Local</class> for all storage
/// operations (Pattern 3: Storage Encapsulation).</p>
Class IRISCouch.API.ReplicationHandler Extends %RegisteredObject
{

/// <p>Handle <code>GET /{db}/_local/{id}</code> — retrieve a local document.</p>
/// <p>Returns the local document body with <code>_id</code> and <code>_rev</code>
/// fields injected. Returns 404 if the database or document does not exist.</p>
/// @param pDB The database name from the URL path
/// @param pLocalId The local document identifier from the URL path
/// @return %Status
ClassMethod HandleLocalGet(pDB As %String, pLocalId As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        ; Validate database exists
        If '##class(IRISCouch.Storage.Database).Exists(pDB) {
            Do ##class(IRISCouch.Util.Error).Render(404, ##class(IRISCouch.Util.Error).#NOTFOUND, "Database does not exist.")
            Quit
        }
        ; Check if local document exists
        If '##class(IRISCouch.Storage.Local).Exists(pDB, pLocalId) {
            Do ##class(IRISCouch.Util.Error).Render(404, "not_found", "missing")
            Quit
        }
        ; Read body and rev
        Set tBody = ##class(IRISCouch.Storage.Local).Read(pDB, pLocalId)
        Set tRev = ##class(IRISCouch.Storage.Local).GetRev(pDB, pLocalId)
        ; Parse body, inject _id and _rev
        Set tDoc = ##class(%DynamicObject).%FromJSON(tBody)
        Do tDoc.%Set("_id", "_local/" _ pLocalId)
        Do tDoc.%Set("_rev", tRev)
        ; Return 200 OK
        Do ##class(IRISCouch.Util.Response).JSON(tDoc)
        Quit
    }
    Catch ex {
        Do ##class(IRISCouch.Util.Error).RenderInternal(##class(IRISCouch.Util.Error).#SERVERERROR, "local document: get error", ex)
        Quit
    }
    Quit $$$OK
}

/// <p>Handle <code>PUT /{db}/_local/{id}</code> — create or update a local document.</p>
/// <p>For new documents, <code>_rev</code> must be absent or empty.
/// For updates, <code>_rev</code> in the body or query parameter must match
/// the current revision. Returns 409 Conflict on revision mismatch.</p>
/// <p>Response: <code>{"ok":true,"id":"_local/{id}","rev":"0-N"}</code></p>
/// @param pDB The database name from the URL path
/// @param pLocalId The local document identifier from the URL path
/// @return %Status
ClassMethod HandleLocalPut(pDB As %String, pLocalId As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        ; Validate database exists
        If '##class(IRISCouch.Storage.Database).Exists(pDB) {
            Do ##class(IRISCouch.Util.Error).Render(404, ##class(IRISCouch.Util.Error).#NOTFOUND, "Database does not exist.")
            Quit
        }
        ; Read request body
        Set tContent = ""
        If $IsObject(%request.Content) {
            Set tContent = %request.Content.Read()
        }
        If tContent = "" {
            Do ##class(IRISCouch.Util.Error).Render(400, ##class(IRISCouch.Util.Error).#BADREQUEST, "Request body is empty or missing.")
            Quit
        }
        ; Parse JSON body
        Try {
            Set tBody = ##class(%DynamicObject).%FromJSON(tContent)
        } Catch tParseEx {
            Do ##class(IRISCouch.Util.Error).Render(400, ##class(IRISCouch.Util.Error).#BADREQUEST, "invalid UTF-8 JSON")
            Quit
        }
        ; Get current rev (empty if doc doesn't exist)
        Set tCurrentRev = ##class(IRISCouch.Storage.Local).GetRev(pDB, pLocalId)
        Set tDocExists = (tCurrentRev '= "")
        ; Get _rev from body or query parameter
        Set tClientRev = ""
        If tBody.%IsDefined("_rev") {
            Set tClientRev = tBody.%Get("_rev")
        }
        If (tClientRev = "") && ($Data(%request.Data("rev", 1))) {
            Set tClientRev = %request.Data("rev", 1)
        }
        ; Conflict detection
        If tDocExists {
            ; Existing document: _rev must match current rev
            If (tClientRev = "") || (tClientRev '= tCurrentRev) {
                Do ##class(IRISCouch.Util.Error).Render(409, ##class(IRISCouch.Util.Error).#CONFLICT, "Document update conflict.")
                Quit
            }
        } Else {
            ; New document: _rev must be absent or empty
            If tClientRev '= "" {
                Do ##class(IRISCouch.Util.Error).Render(409, ##class(IRISCouch.Util.Error).#CONFLICT, "Document update conflict.")
                Quit
            }
        }
        ; Strip _id and _rev from body before storing
        If tBody.%IsDefined("_id") Do tBody.%Remove("_id")
        If tBody.%IsDefined("_rev") Do tBody.%Remove("_rev")
        ; Compute new rev
        Set tNewRev = ##class(IRISCouch.Storage.Local).NextRev(tCurrentRev)
        ; Store local document
        Set tSC = ##class(IRISCouch.Storage.Local).Write(pDB, pLocalId, tBody.%ToJSON(), tNewRev)
        If $$$ISERR(tSC) {
            Do ##class(IRISCouch.Util.Error).RenderInternal(##class(IRISCouch.Util.Error).#SERVERERROR, "local document: write error")
            Quit
        }
        ; Return 201 Created
        Set tResp = {}
        Do tResp.%Set("ok", 1, "boolean")
        Do tResp.%Set("id", "_local/" _ pLocalId)
        Do tResp.%Set("rev", tNewRev)
        Do ##class(IRISCouch.Util.Response).JSONStatus(201, tResp)
        Quit
    }
    Catch ex {
        Do ##class(IRISCouch.Util.Error).RenderInternal(##class(IRISCouch.Util.Error).#SERVERERROR, "local document: put error", ex)
        Quit
    }
    Quit $$$OK
}

/// <p>Handle <code>POST /{db}/_revs_diff</code> — calculate revision differences.</p>
/// <p>Accepts a JSON object mapping document IDs to arrays of revision strings.
/// Returns only those documents that have missing revisions, along with
/// <code>possible_ancestors</code> (known leaf revisions) when the document
/// has an existing revision tree.</p>
/// <p>An empty request <code>{}</code> returns an empty object <code>{}</code>.
/// If all submitted revisions already exist locally, the response is also
/// <code>{}</code>.</p>
/// @param pDB The database name from the URL path
/// @return %Status
ClassMethod HandleRevsDiff(pDB As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        ; Validate database exists
        If '##class(IRISCouch.Storage.Database).Exists(pDB) {
            Do ##class(IRISCouch.Util.Error).Render(404, ##class(IRISCouch.Util.Error).#NOTFOUND, "Database does not exist.")
            Quit
        }
        ; Read request body
        Set tContent = ""
        If $IsObject(%request.Content) {
            Set tContent = %request.Content.Read()
        }
        If tContent = "" {
            ; Empty body treated as empty object
            Do ##class(IRISCouch.Util.Response).JSON({})
            Quit
        }
        ; Parse JSON body
        Try {
            Set tReqObj = ##class(%DynamicObject).%FromJSON(tContent)
        } Catch tParseEx {
            Do ##class(IRISCouch.Util.Error).Render(400, ##class(IRISCouch.Util.Error).#BADREQUEST, "invalid UTF-8 JSON")
            Quit
        }
        ; Build response — only include docIds with missing revisions
        Set tResponse = {}
        Set tIter = tReqObj.%GetIterator()
        While tIter.%GetNext(.tDocId, .tRevArray) {
            ; Skip if value is not an array
            If '$IsObject(tRevArray) Continue
            ; Collect missing revisions for this docId
            Set tMissing = []
            Set tRevIter = tRevArray.%GetIterator()
            While tRevIter.%GetNext(.tIdx, .tRev) {
                If '##class(IRISCouch.Storage.RevTree).RevExists(pDB, tDocId, tRev) {
                    Do tMissing.%Push(tRev)
                }
            }
            ; Only include docId in response if it has missing revisions
            If tMissing.%Size() > 0 {
                Set tDocResult = {}
                Do tDocResult.%Set("missing", tMissing)
                ; Include possible_ancestors if doc has a known revision tree
                Set tLeaves = ##class(IRISCouch.Storage.RevTree).GetLeafRevs(pDB, tDocId)
                If tLeaves.%Size() > 0 {
                    Do tDocResult.%Set("possible_ancestors", tLeaves)
                }
                Do tResponse.%Set(tDocId, tDocResult)
            }
        }
        ; Return 200 with response
        Do ##class(IRISCouch.Util.Response).JSON(tResponse)
        Quit
    }
    Catch ex {
        Do ##class(IRISCouch.Util.Error).RenderInternal(##class(IRISCouch.Util.Error).#SERVERERROR, "revs_diff: processing error", ex)
        Quit
    }
    Quit $$$OK
}

/// <p>Handle <code>DELETE /{db}/_local/{id}</code> — delete a local document.</p>
/// <p>Requires a matching <code>rev</code> query parameter or <code>_rev</code>
/// in the request body. Returns 404 if the document does not exist,
/// or 409 if the revision does not match.</p>
/// <p>Response: <code>{"ok":true,"id":"_local/{id}","rev":"0-N"}</code>
/// where N is the next revision number (matching CouchDB behavior).</p>
/// @param pDB The database name from the URL path
/// @param pLocalId The local document identifier from the URL path
/// @return %Status
ClassMethod HandleLocalDelete(pDB As %String, pLocalId As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        ; Validate database exists
        If '##class(IRISCouch.Storage.Database).Exists(pDB) {
            Do ##class(IRISCouch.Util.Error).Render(404, ##class(IRISCouch.Util.Error).#NOTFOUND, "Database does not exist.")
            Quit
        }
        ; Check if local document exists
        If '##class(IRISCouch.Storage.Local).Exists(pDB, pLocalId) {
            Do ##class(IRISCouch.Util.Error).Render(404, "not_found", "missing")
            Quit
        }
        ; Get rev from query parameter or body
        Set tClientRev = ""
        If $Data(%request.Data("rev", 1)) {
            Set tClientRev = %request.Data("rev", 1)
        }
        ; Try request body if no query param
        If (tClientRev = "") && $IsObject(%request.Content) {
            Set tBodyStr = %request.Content.Read()
            If tBodyStr '= "" {
                Try {
                    Set tBodyObj = ##class(%DynamicObject).%FromJSON(tBodyStr)
                    If tBodyObj.%IsDefined("_rev") {
                        Set tClientRev = tBodyObj.%Get("_rev")
                    }
                } Catch tParseEx {
                    ; Ignore parse errors for delete body
                }
            }
        }
        ; Validate rev matches current
        Set tCurrentRev = ##class(IRISCouch.Storage.Local).GetRev(pDB, pLocalId)
        If (tClientRev = "") || (tClientRev '= tCurrentRev) {
            Do ##class(IRISCouch.Util.Error).Render(409, ##class(IRISCouch.Util.Error).#CONFLICT, "Document update conflict.")
            Quit
        }
        ; Compute response rev (next rev, matching CouchDB behavior)
        Set tNextRev = ##class(IRISCouch.Storage.Local).NextRev(tCurrentRev)
        ; Delete the local document
        Set tSC = ##class(IRISCouch.Storage.Local).Delete(pDB, pLocalId)
        If $$$ISERR(tSC) {
            Do ##class(IRISCouch.Util.Error).RenderInternal(##class(IRISCouch.Util.Error).#SERVERERROR, "local document: delete error")
            Quit
        }
        ; Return 200 OK
        Set tResp = {}
        Do tResp.%Set("ok", 1, "boolean")
        Do tResp.%Set("id", "_local/" _ pLocalId)
        Do tResp.%Set("rev", tNextRev)
        Do ##class(IRISCouch.Util.Response).JSONStatus(200, tResp)
        Quit
    }
    Catch ex {
        Do ##class(IRISCouch.Util.Error).RenderInternal(##class(IRISCouch.Util.Error).#SERVERERROR, "local document: delete error", ex)
        Quit
    }
    Quit $$$OK
}

}
