/// <p>HTTP handler for per-database <code>_security</code> endpoints.</p>
/// <p>Handles <code>GET /{db}/_security</code> and <code>PUT /{db}/_security</code>
/// requests per CouchDB API specification. The _security object is a non-versioned
/// configuration (not a regular document).</p>
Class IRISCouch.API.SecurityHandler Extends %RegisteredObject
{

/// <p>Handle <code>GET /{db}/_security</code> — retrieve security configuration.</p>
/// <p>Returns the current security object for the database. If no security
/// has been configured, returns an empty security object with empty arrays
/// (per CouchDB behavior).</p>
/// @param pDB The database name from the URL path
/// @return %Status
ClassMethod HandleGet(pDB As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        ; Verify database exists
        If '##class(IRISCouch.Storage.Database).Exists(pDB) {
            Do ##class(IRISCouch.Util.Error).Render(404, "not_found", "Database does not exist.")
            Quit
        }
        ; Get security object (returns empty structure if not set)
        Set tSecObj = ##class(IRISCouch.Auth.Security).Get(pDB)
        Do ##class(IRISCouch.Util.Response).JSON(tSecObj)
        Quit
    }
    Catch ex {
        Do ##class(IRISCouch.Util.Error).RenderInternal("server_error", "security: get error", ex)
        Quit
    }
    Quit $$$OK
}

/// <p>Handle <code>PUT /{db}/_security</code> — set security configuration.</p>
/// <p>Reads the request body, validates the security object structure,
/// and stores it for the database. Returns <code>{"ok":true}</code> on success.</p>
/// @param pDB The database name from the URL path
/// @return %Status
ClassMethod HandlePut(pDB As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        ; Verify database exists
        If '##class(IRISCouch.Storage.Database).Exists(pDB) {
            Do ##class(IRISCouch.Util.Error).Render(404, "not_found", "Database does not exist.")
            Quit
        }
        ; Read and parse request body
        Set tBody = ""
        If $IsObject(%request.Content) {
            Set tRaw = %request.Content.Read()
            If tRaw '= "" {
                Set tBody = ##class(%DynamicObject).%FromJSON(tRaw)
            }
        }
        If '$IsObject(tBody) {
            Do ##class(IRISCouch.Util.Error).Render(400, "bad_request", "Request body must be a JSON object")
            Quit
        }
        ; Store security configuration
        Set tSC = ##class(IRISCouch.Auth.Security).Put(pDB, tBody)
        If $$$ISERR(tSC) {
            Do ##class(IRISCouch.Util.Error).Render(400, "bad_request", $System.Status.GetErrorText(tSC))
            Quit
        }
        ; Return {"ok":true}
        Set tResponse = {}
        Do tResponse.%Set("ok", 1, "boolean")
        Do ##class(IRISCouch.Util.Response).JSON(tResponse)
        Quit
    }
    Catch ex {
        Do ##class(IRISCouch.Util.Error).RenderInternal("server_error", "security: put error", ex)
        Quit
    }
    Quit $$$OK
}

}
