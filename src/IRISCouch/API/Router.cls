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
  <Route Url="/_uuids" Method="GET" Call="IRISCouch.API.ServerHandler:HandleUUIDs" />
  <Route Url="/" Method="GET" Call="IRISCouch.API.ServerHandler:HandleWelcome" />
</Routes>
}

/// <p>Handle requests that do not match any route in the UrlMap.</p>
/// <p>Returns a CouchDB-compatible 404 JSON error envelope.</p>
ClassMethod Page(skipheader As %Boolean = 1) As %Status
{
    Set tSC = $$$OK
    Try {
        Do ##class(IRISCouch.Util.Error).Render(404, "not_found", "missing")
    }
    Catch ex {
        Do ##class(IRISCouch.Util.Error).RenderInternal("server_error", "router: error rendering 404 response", ex)
    }
    Quit tSC
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
