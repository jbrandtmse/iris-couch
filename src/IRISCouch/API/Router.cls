/// <p>HTTP REST router for IRISCouch.</p>
/// <p>This is the single HTTP entry point for all IRISCouch API requests.
/// It dispatches to per-subsystem Handler classes via the UrlMap XData block.</p>
/// <p>Extends <class>%CSP.REST</class> with stateless, JSON-first defaults.</p>
Class IRISCouch.API.Router Extends %CSP.REST
{

/// <p>Disable CSP session management for stateless REST operation.</p>
Parameter UseSession = 0;

/// <p>Default content type for all responses.</p>
Parameter CONTENTTYPE = "application/json";

/// <p>URL map defining all routes dispatched to handler classes.</p>
XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
  <!-- Server-level endpoints (Story 1.2, 1.3) -->
  <Route Url="/_uuids" Method="GET" Call="HandleUUIDs" />
  <!-- Database endpoints - MUST be after underscore-prefixed routes (Story 2.1) -->
  <Route Url="/:db" Method="PUT" Call="HandleDatabaseCreate" />
  <Route Url="/:db" Method="DELETE" Call="HandleDatabaseDelete" />
  <!-- Welcome endpoint (catch-all for GET /) -->
  <Route Url="/" Method="GET" Call="HandleWelcome" />
</Routes>
}

/// <p>Dispatch GET / to ServerHandler.</p>
ClassMethod HandleWelcome() As %Status
{
    Quit ##class(IRISCouch.API.ServerHandler).HandleWelcome()
}

/// <p>Dispatch GET /_uuids to ServerHandler.</p>
ClassMethod HandleUUIDs() As %Status
{
    Quit ##class(IRISCouch.API.ServerHandler).HandleUUIDs()
}

/// <p>Dispatch PUT /:db to DatabaseHandler.</p>
ClassMethod HandleDatabaseCreate(pDB As %String) As %Status
{
    Quit ##class(IRISCouch.API.DatabaseHandler).HandleCreate(pDB)
}

/// <p>Dispatch DELETE /:db to DatabaseHandler.</p>
ClassMethod HandleDatabaseDelete(pDB As %String) As %Status
{
    Quit ##class(IRISCouch.API.DatabaseHandler).HandleDelete(pDB)
}

/// <p>Override to return CouchDB-compatible JSON error envelopes for HTTP errors.</p>
/// <p>Called by %CSP.REST when no route matches (404) or other HTTP status errors.</p>
ClassMethod ReportHttpStatusCode(pHttpStatus, pSC As %Status = {$$$OK}) As %Status
{
    If pHttpStatus [ "404" {
        Do ##class(IRISCouch.Util.Error).Render(404, "not_found", "missing")
    } ElseIf pHttpStatus [ "405" {
        Do ##class(IRISCouch.Util.Error).Render(405, "method_not_allowed", "method_not_allowed")
    } Else {
        Do ##class(IRISCouch.Util.Error).Render($Piece(pHttpStatus, " ", 1), "server_error", pHttpStatus)
    }
    Quit $$$OK
}

/// <p>Handle HTTP 405 Method Not Allowed responses.</p>
/// <p>Overrides the <class>%CSP.REST</class> default to return a
/// CouchDB-compatible JSON error envelope with the <code>Allow</code>
/// header listing the valid HTTP methods for the route.</p>
/// @param pSupportedVerbs Comma-separated list of allowed HTTP methods
ClassMethod Http405(pSupportedVerbs As %String) As %Status
{
    Do ##class(IRISCouch.Util.Error).Render405(pSupportedVerbs)
    Quit $$$OK
}

}
