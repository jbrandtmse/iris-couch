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
