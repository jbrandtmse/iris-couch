/// <p>HTTP handler for document CRUD operations.</p>
/// <p>Handles <code>POST /{db}</code> (create with server-generated ID),
/// <code>PUT /{db}/{docid}</code> (create with client-specified ID),
/// and <code>GET /{db}/{docid}</code> (retrieve document).
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
        ; POST always generates a server UUID — ignore any client _id
        Set tDocId = ##class(IRISCouch.Util.UUID).Generate()
        ; Remove metadata fields before storing
        If tBody.%IsDefined("_id") Do tBody.%Remove("_id")
        If tBody.%IsDefined("_rev") Do tBody.%Remove("_rev")
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

/// <p>Handle <code>PUT /{db}/{docid}</code> — create a document with client-specified ID.</p>
/// <p>For Story 3.1, only handles the <b>create</b> case where the document does not yet
/// exist and no <code>_rev</code> is provided. If the document already exists and no
/// <code>_rev</code> is provided, returns 409 Conflict.</p>
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
        ; Extract _rev from body or query param
        Set tRev = ""
        If tBody.%IsDefined("_rev") {
            Set tRev = tBody.%Get("_rev")
        }
        If (tRev = "") && ($Data(%request.Data("rev", 1))) {
            Set tRev = $Get(%request.Data("rev", 1))
        }
        ; Check conflict: document exists but no _rev provided
        If ##class(IRISCouch.Storage.Document).Exists(pDB, pDocId) && (tRev = "") {
            Do ##class(IRISCouch.Util.Error).Render(409, ##class(IRISCouch.Util.Error).#CONFLICT, "Document update conflict.")
            Quit
        }
        ; Remove metadata fields before storing
        If tBody.%IsDefined("_id") Do tBody.%Remove("_id")
        If tBody.%IsDefined("_rev") Do tBody.%Remove("_rev")
        ; Save document (for Story 3.1: create case only, parentRev is empty)
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

/// <p>Handle <code>GET /{db}/{docid}</code> — retrieve a document.</p>
/// <p>If the <code>rev</code> query parameter is specified, returns that specific
/// revision. Otherwise, returns the winning revision. Injects <code>_id</code>
/// and <code>_rev</code> into the response body.</p>
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

}
