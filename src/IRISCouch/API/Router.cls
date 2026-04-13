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
  <!-- Session authentication endpoints (Story 7.1) -->
  <Route Url="/_session" Method="POST" Call="HandleSessionPost" />
  <Route Url="/_session" Method="GET" Call="HandleSessionGet" />
  <Route Url="/_session" Method="DELETE" Call="HandleSessionDelete" />
  <!-- Server-level endpoints (Story 1.2, 1.3) -->
  <Route Url="/_uuids" Method="GET" Call="HandleUUIDs" />
  <Route Url="/_all_dbs" Method="GET" Call="HandleAllDbs" />
  <!-- Database sub-resource endpoints - MUST be BEFORE /:db routes (Story 2.3) -->
  <Route Url="/:db/_revs_limit" Method="GET" Call="HandleRevsLimitGet" />
  <Route Url="/:db/_revs_limit" Method="PUT" Call="HandleRevsLimitPut" />
  <Route Url="/:db/_compact" Method="POST" Call="HandleCompact" />
  <Route Url="/:db/_ensure_full_commit" Method="POST" Call="HandleEnsureFullCommit" />
  <!-- Mango query endpoints (Story 6.2) -->
  <Route Url="/:db/_find" Method="POST" Call="HandleMangoFind" />
  <Route Url="/:db/_explain" Method="POST" Call="HandleMangoExplain" />
  <!-- Mango index endpoints (Story 6.1) -->
  <Route Url="/:db/_index/:ddoc/:type/:name" Method="DELETE" Call="HandleMangoIndexDelete" />
  <Route Url="/:db/_index" Method="POST" Call="HandleMangoIndexCreate" />
  <Route Url="/:db/_index" Method="GET" Call="HandleMangoIndexList" />
  <Route Url="/:db/_all_docs" Method="GET" Call="HandleAllDocs" />
  <Route Url="/:db/_all_docs" Method="POST" Call="HandleAllDocsPost" />
  <Route Url="/:db/_bulk_docs" Method="POST" Call="HandleBulkDocs" />
  <Route Url="/:db/_bulk_get" Method="POST" Call="HandleBulkGet" />
  <Route Url="/:db/_changes" Method="GET" Call="HandleChangesGet" />
  <Route Url="/:db/_changes" Method="POST" Call="HandleChangesPost" />
  <!-- Database endpoints - MUST be after underscore-prefixed routes (Story 2.1, 2.2) -->
  <Route Url="/:db" Method="POST" Call="HandleDocumentPost" />
  <Route Url="/:db" Method="PUT" Call="HandleDatabaseCreate" />
  <Route Url="/:db" Method="DELETE" Call="HandleDatabaseDelete" />
  <Route Url="/:db" Method="GET" Call="HandleDatabaseInfo" />
  <!-- Attachment endpoints - 3-segment routes before 2-segment document routes (Story 5.1) -->
  <Route Url="/:db/:docid/:attname" Method="PUT" Call="HandleAttachmentPut" />
  <Route Url="/:db/:docid/:attname" Method="GET" Call="HandleAttachmentGet" />
  <Route Url="/:db/:docid/:attname" Method="DELETE" Call="HandleAttachmentDelete" />
  <!-- Document endpoints - MUST be after /:db routes (Story 3.1, 3.2) -->
  <Route Url="/:db/:docid" Method="PUT" Call="HandleDocumentPut" />
  <Route Url="/:db/:docid" Method="GET" Call="HandleDocumentGet" />
  <Route Url="/:db/:docid" Method="DELETE" Call="HandleDocumentDelete" />
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

/// <p>Dispatch GET /_all_dbs to DatabaseHandler.</p>
ClassMethod HandleAllDbs() As %Status
{
    Quit ##class(IRISCouch.API.DatabaseHandler).HandleAllDbs()
}

/// <p>Dispatch GET /:db to DatabaseHandler.</p>
ClassMethod HandleDatabaseInfo(pDB As %String) As %Status
{
    Quit ##class(IRISCouch.API.DatabaseHandler).HandleInfo(pDB)
}

/// <p>Dispatch GET /:db/_revs_limit to DatabaseHandler.</p>
ClassMethod HandleRevsLimitGet(pDB As %String) As %Status
{
    Quit ##class(IRISCouch.API.DatabaseHandler).HandleRevsLimitGet(pDB)
}

/// <p>Dispatch PUT /:db/_revs_limit to DatabaseHandler.</p>
ClassMethod HandleRevsLimitPut(pDB As %String) As %Status
{
    Quit ##class(IRISCouch.API.DatabaseHandler).HandleRevsLimitPut(pDB)
}

/// <p>Dispatch POST /:db/_compact to DatabaseHandler.</p>
ClassMethod HandleCompact(pDB As %String) As %Status
{
    Quit ##class(IRISCouch.API.DatabaseHandler).HandleCompact(pDB)
}

/// <p>Dispatch POST /:db/_ensure_full_commit to DatabaseHandler.</p>
ClassMethod HandleEnsureFullCommit(pDB As %String) As %Status
{
    Quit ##class(IRISCouch.API.DatabaseHandler).HandleEnsureFullCommit(pDB)
}

/// <p>Dispatch POST /:db to DocumentHandler (create document with server-generated ID).</p>
ClassMethod HandleDocumentPost(pDB As %String) As %Status
{
    Quit ##class(IRISCouch.API.DocumentHandler).HandlePost(pDB)
}

/// <p>Dispatch PUT /:db/:docid to DocumentHandler (create/update document with client ID).</p>
ClassMethod HandleDocumentPut(pDB As %String, pDocId As %String) As %Status
{
    Quit ##class(IRISCouch.API.DocumentHandler).HandlePut(pDB, pDocId)
}

/// <p>Dispatch GET /:db/:docid to DocumentHandler (retrieve document).</p>
ClassMethod HandleDocumentGet(pDB As %String, pDocId As %String) As %Status
{
    Quit ##class(IRISCouch.API.DocumentHandler).HandleGet(pDB, pDocId)
}

/// <p>Dispatch DELETE /:db/:docid to DocumentHandler (delete document).</p>
ClassMethod HandleDocumentDelete(pDB As %String, pDocId As %String) As %Status
{
    Quit ##class(IRISCouch.API.DocumentHandler).HandleDelete(pDB, pDocId)
}

/// <p>Dispatch POST /:db/_bulk_docs to BulkHandler.</p>
ClassMethod HandleBulkDocs(pDB As %String) As %Status
{
    Quit ##class(IRISCouch.API.BulkHandler).HandleBulkDocs(pDB)
}

/// <p>Dispatch POST /:db/_bulk_get to BulkHandler.</p>
ClassMethod HandleBulkGet(pDB As %String) As %Status
{
    Quit ##class(IRISCouch.API.BulkHandler).HandleBulkGet(pDB)
}

/// <p>Dispatch GET /:db/_all_docs to AllDocsHandler.</p>
ClassMethod HandleAllDocs(pDB As %String) As %Status
{
    Quit ##class(IRISCouch.API.AllDocsHandler).HandleAllDocs(pDB)
}

/// <p>Dispatch POST /:db/_all_docs to AllDocsHandler.</p>
ClassMethod HandleAllDocsPost(pDB As %String) As %Status
{
    Quit ##class(IRISCouch.API.AllDocsHandler).HandleAllDocsPost(pDB)
}

/// <p>Dispatch GET /:db/_changes to ChangesHandler.</p>
ClassMethod HandleChangesGet(pDB As %String) As %Status
{
    Quit ##class(IRISCouch.API.ChangesHandler).HandleChanges(pDB)
}

/// <p>Dispatch POST /:db/_changes to ChangesHandler.</p>
ClassMethod HandleChangesPost(pDB As %String) As %Status
{
    Quit ##class(IRISCouch.API.ChangesHandler).HandleChanges(pDB)
}

/// <p>Dispatch PUT /:db/:docid/:attname to AttachmentHandler (upload attachment).</p>
ClassMethod HandleAttachmentPut(pDB As %String, pDocId As %String, pAttName As %String) As %Status
{
    Quit ##class(IRISCouch.API.AttachmentHandler).HandlePut(pDB, pDocId, pAttName)
}

/// <p>Dispatch GET /:db/:docid/:attname to AttachmentHandler (download attachment).</p>
ClassMethod HandleAttachmentGet(pDB As %String, pDocId As %String, pAttName As %String) As %Status
{
    Quit ##class(IRISCouch.API.AttachmentHandler).HandleGet(pDB, pDocId, pAttName)
}

/// <p>Dispatch DELETE /:db/:docid/:attname to AttachmentHandler (delete attachment).</p>
ClassMethod HandleAttachmentDelete(pDB As %String, pDocId As %String, pAttName As %String) As %Status
{
    Quit ##class(IRISCouch.API.AttachmentHandler).HandleDelete(pDB, pDocId, pAttName)
}

/// <p>Dispatch POST /:db/_find to MangoHandler (execute Mango query).</p>
ClassMethod HandleMangoFind(pDB As %String) As %Status
{
    Quit ##class(IRISCouch.API.MangoHandler).HandleFind(pDB)
}

/// <p>Dispatch POST /:db/_explain to MangoHandler (explain Mango query plan).</p>
ClassMethod HandleMangoExplain(pDB As %String) As %Status
{
    Quit ##class(IRISCouch.API.MangoHandler).HandleExplain(pDB)
}

/// <p>Dispatch POST /:db/_index to MangoHandler (create Mango index).</p>
ClassMethod HandleMangoIndexCreate(pDB As %String) As %Status
{
    Quit ##class(IRISCouch.API.MangoHandler).HandleCreateIndex(pDB)
}

/// <p>Dispatch GET /:db/_index to MangoHandler (list Mango indexes).</p>
ClassMethod HandleMangoIndexList(pDB As %String) As %Status
{
    Quit ##class(IRISCouch.API.MangoHandler).HandleListIndexes(pDB)
}

/// <p>Dispatch DELETE /:db/_index/:ddoc/:type/:name to MangoHandler (delete Mango index).</p>
ClassMethod HandleMangoIndexDelete(pDB As %String, pDDoc As %String, pType As %String, pName As %String) As %Status
{
    Quit ##class(IRISCouch.API.MangoHandler).HandleDeleteIndex(pDB, pDDoc, pType, pName)
}

/// <p>Dispatch POST /_session to AuthHandler (login).</p>
ClassMethod HandleSessionPost() As %Status
{
    Quit ##class(IRISCouch.API.AuthHandler).HandleSessionPost()
}

/// <p>Dispatch GET /_session to AuthHandler (session info).</p>
ClassMethod HandleSessionGet() As %Status
{
    Quit ##class(IRISCouch.API.AuthHandler).HandleSessionGet()
}

/// <p>Dispatch DELETE /_session to AuthHandler (logout).</p>
ClassMethod HandleSessionDelete() As %Status
{
    Quit ##class(IRISCouch.API.AuthHandler).HandleSessionDelete()
}

/// <p>Authentication middleware — establishes user context on every request.</p>
/// <p>Checks for <code>AuthSession</code> cookie or <code>Authorization: Basic</code>
/// header and sets process-private <code>%IRISCouchUser</code>,
/// <code>%IRISCouchRoles</code>, and <code>%IRISCouchAuthMethod</code> variables.
/// If no auth present, sets anonymous context (empty user, empty roles).</p>
/// <p>Always returns <code>$$$OK</code> with <code>pContinue=1</code> — auth is
/// established but not enforced at this layer (enforcement is Story 7.4).</p>
/// @param pUrl The request URL
/// @param pMethod The HTTP method
/// @param pContinue Output: set to 1 to continue dispatch
/// @return %Status
ClassMethod OnPreDispatch(pUrl As %String, pMethod As %String, ByRef pContinue As %Boolean) As %Status
{
    Set pContinue = 1
    Set %IRISCouchUser = ""
    Set %IRISCouchRoles = []
    Set %IRISCouchAuthMethod = ""
    Try {
        ; Check for AuthSession cookie first
        Set tCookieHeader = %request.GetCgiEnv("HTTP_COOKIE", "")
        If tCookieHeader '= "" {
            Set tCookieValue = ..ExtractAuthSessionCookie(tCookieHeader)
            If tCookieValue '= "" {
                Set tValid = ##class(IRISCouch.Auth.Session).ValidateCookie(tCookieValue, .tUsername)
                If tValid {
                    Set %IRISCouchUser = tUsername
                    Set %IRISCouchRoles = ##class(IRISCouch.Auth.Basic).GetUserRoles(tUsername)
                    Set %IRISCouchAuthMethod = "cookie"
                    Quit
                }
            }
        }
        ; Check for Authorization: Basic header
        Set tAuthHeader = %request.GetCgiEnv("HTTP_AUTHORIZATION", "")
        If tAuthHeader '= "" {
            Set tOK = ##class(IRISCouch.Auth.Basic).Authenticate(tAuthHeader, .tUsername, .tRoles)
            If tOK {
                Set %IRISCouchUser = tUsername
                Set %IRISCouchRoles = tRoles
                Set %IRISCouchAuthMethod = "default"
                Quit
            }
        }
        ; No valid auth — anonymous context (already set above)
        Quit
    }
    Catch ex {
        ; On error, remain anonymous — don't block the request
        Quit
    }
    Quit $$$OK
}

/// <p>Extract the AuthSession cookie value from the Cookie header string.</p>
/// <p>Parses the raw <code>Cookie</code> header to find the <code>AuthSession</code>
/// key and returns its value.</p>
/// @param pCookieHeader The raw Cookie header value
/// @return The AuthSession cookie value, or empty string if not found
ClassMethod ExtractAuthSessionCookie(pCookieHeader As %String) As %String [ Private ]
{
    ; Cookie header format: "key1=val1; key2=val2; ..."
    Set tFound = ""
    For i = 1:1:$Length(pCookieHeader, ";") {
        Set tPair = $ZStrip($Piece(pCookieHeader, ";", i), "<>W")
        Set tKey = $ZStrip($Piece(tPair, "=", 1), "<>W")
        Set tVal = $ZStrip($Piece(tPair, "=", 2, *), "<>W")
        If tKey = "AuthSession" {
            Set tFound = tVal
            Quit
        }
    }
    Quit tFound
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
