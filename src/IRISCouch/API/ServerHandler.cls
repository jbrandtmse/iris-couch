/// <p>Server-level request handler for IRISCouch.</p>
/// <p>Handles server identity and utility endpoints that are not
/// scoped to a specific database.</p>
Class IRISCouch.API.ServerHandler Extends %RegisteredObject
{

/// <p>Current IRISCouch version string.</p>
Parameter VERSION = "0.1.0";

/// <p>Handle <code>GET /</code> — CouchDB-compatible welcome response.</p>
/// <p>Returns a JSON object containing the welcome message, version string,
/// and vendor information. CouchDB clients (PouchDB, nano) check for the
/// <code>"couchdb": "Welcome"</code> field to verify server compatibility.</p>
/// @return %Status
ClassMethod HandleWelcome() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tResponse = ..BuildWelcomeResponse()
        Do ##class(IRISCouch.Util.Response).JSON(tResponse)
    }
    Catch ex {
        Do ##class(IRISCouch.Util.Error).Render(500, "server_error", "Internal Server Error")
    }
    Quit tSC
}

/// <p>Handle <code>GET /_uuids</code> — generate CouchDB-compatible UUIDs.</p>
/// <p>Reads the optional <code>count</code> query parameter (default 1).
/// Returns a JSON object with a <code>uuids</code> array containing the
/// requested number of 32-character lowercase hex UUIDs.</p>
/// <p>Returns 400 Bad Request if count is not a positive integer.</p>
/// @return %Status
ClassMethod HandleUUIDs() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tCount = %request.Get("count", 1)
        ; Validate count is a positive integer within allowed range
        If (tCount '= +tCount) || (tCount < 1) || (tCount > 1000) || (tCount \ 1 '= tCount) {
            Do ##class(IRISCouch.Util.Error).Render(400, "bad_request", "count must be a positive integer up to 1000")
            Quit
        }
        Set tUUIDs = ##class(IRISCouch.Util.UUID).GenerateN(tCount)
        Set tResponse = {}
        Set tResponse.uuids = tUUIDs
        Do ##class(IRISCouch.Util.Response).JSON(tResponse)
    }
    Catch ex {
        Do ##class(IRISCouch.Util.Error).Render(500, "server_error", "Internal Server Error")
    }
    Quit tSC
}

/// <p>Build the welcome response as a <class>%DynamicObject</class>.</p>
/// <p>Extracted for testability — unit tests can call this method to
/// verify JSON structure without requiring an HTTP context.</p>
/// @return %DynamicObject containing the welcome response
ClassMethod BuildWelcomeResponse() As %DynamicObject
{
    Set tResponse = {}
    Set tResponse.couchdb = "Welcome"
    Set tResponse.version = ..#VERSION
    Set tVendor = {}
    Set tVendor.name = "IRISCouch"
    Set tResponse.vendor = tVendor
    Quit tResponse
}

}
