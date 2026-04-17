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
  <!-- Metrics endpoint (Story 9.1) -->
  <Route Url="/_prometheus" Method="GET" Call="HandlePrometheus" />
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
  <!-- Replication endpoints (Story 8.2) -->
  <Route Url="/:db/_revs_diff" Method="POST" Call="HandleRevsDiff" />
  <!-- Per-database security configuration (Story 7.4) -->
  <Route Url="/:db/_security" Method="GET" Call="HandleSecurityGet" />
  <Route Url="/:db/_security" Method="PUT" Call="HandleSecurityPut" />
  <!-- Local document endpoints (Story 8.1) -->
  <Route Url="/:db/_local/:localid" Method="PUT" Call="HandleLocalPut" />
  <Route Url="/:db/_local/:localid" Method="GET" Call="HandleLocalGet" />
  <Route Url="/:db/_local/:localid" Method="DELETE" Call="HandleLocalDelete" />
  <!-- Database endpoints - MUST be after underscore-prefixed routes (Story 2.1, 2.2) -->
  <Route Url="/:db" Method="POST" Call="HandleDocumentPost" />
  <Route Url="/:db" Method="PUT" Call="HandleDatabaseCreate" />
  <Route Url="/:db" Method="DELETE" Call="HandleDatabaseDelete" />
  <Route Url="/:db" Method="GET" Call="HandleDatabaseInfo" />
  <!-- Design document endpoints - MUST be BEFORE attachment routes so /:db/_design/:name
       routes to the document handler, not to the attachment handler with docid="_design"
       (Story 11.3 Task 0 — fixes deferred-work backend bug from Story 11.1) -->
  <Route Url="/:db/_design/:ddocid" Method="PUT" Call="HandleDesignDocPut" />
  <Route Url="/:db/_design/:ddocid" Method="GET" Call="HandleDesignDocGet" />
  <Route Url="/:db/_design/:ddocid" Method="DELETE" Call="HandleDesignDocDelete" />
  <!-- Design-document view execution (Story 12.1). MUST be registered BEFORE
       the /_design/:ddocid/:attname attachment routes below, or the attachment
       route will swallow requests with docid="_design" and attname="<view>".
       Story 12.1 returns 501 for every request (JSRuntime=None); Stories
       12.2/12.4 plug real execution into the same handler. -->
  <Route Url="/:db/_design/:ddocid/_view/:viewname" Method="GET" Call="HandleView" />
  <Route Url="/:db/_design/:ddocid/_view/:viewname" Method="POST" Call="HandleView" />
  <!-- Design document attachments — explicit 4-segment routes ahead of the generic
       :docid/:attname route so the design-doc id (composite "_design/<name>") is
       reassembled correctly before dispatch (Story 11.3 Task 0) -->
  <Route Url="/:db/_design/:ddocid/:attname" Method="PUT" Call="HandleDesignDocAttachmentPut" />
  <Route Url="/:db/_design/:ddocid/:attname" Method="GET" Call="HandleDesignDocAttachmentGet" />
  <Route Url="/:db/_design/:ddocid/:attname" Method="DELETE" Call="HandleDesignDocAttachmentDelete" />
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

/// <p>Dispatch GET /_prometheus to Metrics.Endpoint (Story 9.1).</p>
/// <p>Does NOT record its own metrics to avoid self-referential recursion.</p>
ClassMethod HandlePrometheus() As %Status
{
    Quit ##class(IRISCouch.Metrics.Endpoint).HandlePrometheus()
}

/// <p>Dispatch GET / to ServerHandler.</p>
ClassMethod HandleWelcome() As %Status
{
    Set tSC = ##class(IRISCouch.API.ServerHandler).HandleWelcome()
    Do ..RecordRequestMetrics()
    Quit tSC
}

/// <p>Dispatch GET /_uuids to ServerHandler.</p>
ClassMethod HandleUUIDs() As %Status
{
    Set tSC = ##class(IRISCouch.API.ServerHandler).HandleUUIDs()
    Do ..RecordRequestMetrics()
    Quit tSC
}

/// <p>Dispatch PUT /:db to DatabaseHandler.</p>
ClassMethod HandleDatabaseCreate(pDB As %String) As %Status
{
    Set tSC = ##class(IRISCouch.API.DatabaseHandler).HandleCreate(pDB)
    Do ..RecordRequestMetrics()
    Quit tSC
}

/// <p>Dispatch DELETE /:db to DatabaseHandler.</p>
ClassMethod HandleDatabaseDelete(pDB As %String) As %Status
{
    Set tSC = ##class(IRISCouch.API.DatabaseHandler).HandleDelete(pDB)
    Do ..RecordRequestMetrics()
    Quit tSC
}

/// <p>Dispatch GET /_all_dbs to DatabaseHandler.</p>
ClassMethod HandleAllDbs() As %Status
{
    Set tSC = ##class(IRISCouch.API.DatabaseHandler).HandleAllDbs()
    Do ..RecordRequestMetrics()
    Quit tSC
}

/// <p>Dispatch GET /:db to DatabaseHandler.</p>
ClassMethod HandleDatabaseInfo(pDB As %String) As %Status
{
    Set tSC = ##class(IRISCouch.API.DatabaseHandler).HandleInfo(pDB)
    Do ..RecordRequestMetrics()
    Quit tSC
}

/// <p>Dispatch GET /:db/_revs_limit to DatabaseHandler.</p>
ClassMethod HandleRevsLimitGet(pDB As %String) As %Status
{
    Set tSC = ##class(IRISCouch.API.DatabaseHandler).HandleRevsLimitGet(pDB)
    Do ..RecordRequestMetrics()
    Quit tSC
}

/// <p>Dispatch PUT /:db/_revs_limit to DatabaseHandler.</p>
ClassMethod HandleRevsLimitPut(pDB As %String) As %Status
{
    Set tSC = ##class(IRISCouch.API.DatabaseHandler).HandleRevsLimitPut(pDB)
    Do ..RecordRequestMetrics()
    Quit tSC
}

/// <p>Dispatch POST /:db/_compact to DatabaseHandler.</p>
ClassMethod HandleCompact(pDB As %String) As %Status
{
    Set tSC = ##class(IRISCouch.API.DatabaseHandler).HandleCompact(pDB)
    Do ..RecordRequestMetrics()
    Quit tSC
}

/// <p>Dispatch POST /:db/_ensure_full_commit to DatabaseHandler.</p>
ClassMethod HandleEnsureFullCommit(pDB As %String) As %Status
{
    Set tSC = ##class(IRISCouch.API.DatabaseHandler).HandleEnsureFullCommit(pDB)
    Do ..RecordRequestMetrics()
    Quit tSC
}

/// <p>Dispatch POST /:db to DocumentHandler (create document with server-generated ID).</p>
ClassMethod HandleDocumentPost(pDB As %String) As %Status
{
    Set tSC = ##class(IRISCouch.API.DocumentHandler).HandlePost(pDB)
    Do ..RecordRequestMetrics()
    Quit tSC
}

/// <p>Dispatch PUT /:db/:docid to DocumentHandler (create/update document with client ID).</p>
ClassMethod HandleDocumentPut(pDB As %String, pDocId As %String) As %Status
{
    Set tSC = ##class(IRISCouch.API.DocumentHandler).HandlePut(pDB, pDocId)
    Do ..RecordRequestMetrics()
    Quit tSC
}

/// <p>Dispatch PUT /:db/_design/:ddocid to DocumentHandler (Story 11.3 Task 0).</p>
/// <p>Reassembles the composite ID "_design/<name>" before delegating, so the
/// document handler stores the document with the correct full ID instead of
/// the route-fragment "_design".</p>
ClassMethod HandleDesignDocPut(pDB As %String, pDDocId As %String) As %Status
{
    Set tSC = ##class(IRISCouch.API.DocumentHandler).HandlePut(pDB, "_design/" _ pDDocId)
    Do ..RecordRequestMetrics()
    Quit tSC
}

/// <p>Dispatch GET /:db/_design/:ddocid to DocumentHandler (Story 11.3 Task 0).</p>
ClassMethod HandleDesignDocGet(pDB As %String, pDDocId As %String) As %Status
{
    Set tSC = ##class(IRISCouch.API.DocumentHandler).HandleGet(pDB, "_design/" _ pDDocId)
    Do ..RecordRequestMetrics()
    Quit tSC
}

/// <p>Dispatch DELETE /:db/_design/:ddocid to DocumentHandler (Story 11.3 Task 0).</p>
ClassMethod HandleDesignDocDelete(pDB As %String, pDDocId As %String) As %Status
{
    Set tSC = ##class(IRISCouch.API.DocumentHandler).HandleDelete(pDB, "_design/" _ pDDocId)
    Do ..RecordRequestMetrics()
    Quit tSC
}

/// <p>Dispatch GET/POST /:db/_design/:ddocid/_view/:viewname to ViewHandler (Story 12.1).</p>
/// <p>Reassembles the composite id "_design/&lt;ddoc&gt;" before delegating so
/// the view handler and underlying Storage.Document lookups see the full
/// id CouchDB clients expect. Under Story 12.1 every call returns 501 because
/// <class>IRISCouch.JSRuntime.None</class> is the default backend; Stories
/// 12.2/12.4 replace the 501 branch with real execution without changing the
/// wire contract of this wrapper.</p>
ClassMethod HandleView(pDB As %String, pDDocId As %String, pViewName As %String) As %Status
{
    Set tSC = ##class(IRISCouch.API.ViewHandler).HandleView(pDB, "_design/" _ pDDocId, pViewName)
    Do ..RecordRequestMetrics()
    Quit tSC
}

/// <p>Dispatch PUT /:db/_design/:ddocid/:attname to AttachmentHandler (Story 11.3 Task 0).</p>
ClassMethod HandleDesignDocAttachmentPut(pDB As %String, pDDocId As %String, pAttName As %String) As %Status
{
    Set tSC = ##class(IRISCouch.API.AttachmentHandler).HandlePut(pDB, "_design/" _ pDDocId, pAttName)
    Do ..RecordRequestMetrics()
    Quit tSC
}

/// <p>Dispatch GET /:db/_design/:ddocid/:attname to AttachmentHandler (Story 11.3 Task 0).</p>
ClassMethod HandleDesignDocAttachmentGet(pDB As %String, pDDocId As %String, pAttName As %String) As %Status
{
    Set tSC = ##class(IRISCouch.API.AttachmentHandler).HandleGet(pDB, "_design/" _ pDDocId, pAttName)
    Do ..RecordRequestMetrics()
    Quit tSC
}

/// <p>Dispatch DELETE /:db/_design/:ddocid/:attname to AttachmentHandler (Story 11.3 Task 0).</p>
ClassMethod HandleDesignDocAttachmentDelete(pDB As %String, pDDocId As %String, pAttName As %String) As %Status
{
    Set tSC = ##class(IRISCouch.API.AttachmentHandler).HandleDelete(pDB, "_design/" _ pDDocId, pAttName)
    Do ..RecordRequestMetrics()
    Quit tSC
}

/// <p>Dispatch GET /:db/:docid to DocumentHandler (retrieve document).</p>
ClassMethod HandleDocumentGet(pDB As %String, pDocId As %String) As %Status
{
    Set tSC = ##class(IRISCouch.API.DocumentHandler).HandleGet(pDB, pDocId)
    Do ..RecordRequestMetrics()
    Quit tSC
}

/// <p>Dispatch DELETE /:db/:docid to DocumentHandler (delete document).</p>
ClassMethod HandleDocumentDelete(pDB As %String, pDocId As %String) As %Status
{
    Set tSC = ##class(IRISCouch.API.DocumentHandler).HandleDelete(pDB, pDocId)
    Do ..RecordRequestMetrics()
    Quit tSC
}

/// <p>Dispatch POST /:db/_bulk_docs to BulkHandler.</p>
ClassMethod HandleBulkDocs(pDB As %String) As %Status
{
    Set tSC = ##class(IRISCouch.API.BulkHandler).HandleBulkDocs(pDB)
    Do ..RecordRequestMetrics()
    Quit tSC
}

/// <p>Dispatch POST /:db/_bulk_get to BulkHandler.</p>
ClassMethod HandleBulkGet(pDB As %String) As %Status
{
    Set tSC = ##class(IRISCouch.API.BulkHandler).HandleBulkGet(pDB)
    Do ..RecordRequestMetrics()
    Quit tSC
}

/// <p>Dispatch GET /:db/_all_docs to AllDocsHandler.</p>
ClassMethod HandleAllDocs(pDB As %String) As %Status
{
    Set tSC = ##class(IRISCouch.API.AllDocsHandler).HandleAllDocs(pDB)
    Do ..RecordRequestMetrics()
    Quit tSC
}

/// <p>Dispatch POST /:db/_all_docs to AllDocsHandler.</p>
ClassMethod HandleAllDocsPost(pDB As %String) As %Status
{
    Set tSC = ##class(IRISCouch.API.AllDocsHandler).HandleAllDocsPost(pDB)
    Do ..RecordRequestMetrics()
    Quit tSC
}

/// <p>Dispatch GET /:db/_changes to ChangesHandler.</p>
ClassMethod HandleChangesGet(pDB As %String) As %Status
{
    Set tSC = ##class(IRISCouch.API.ChangesHandler).HandleChanges(pDB)
    Do ..RecordRequestMetrics()
    Quit tSC
}

/// <p>Dispatch POST /:db/_changes to ChangesHandler.</p>
ClassMethod HandleChangesPost(pDB As %String) As %Status
{
    Set tSC = ##class(IRISCouch.API.ChangesHandler).HandleChanges(pDB)
    Do ..RecordRequestMetrics()
    Quit tSC
}

/// <p>Dispatch PUT /:db/:docid/:attname to AttachmentHandler (upload attachment).</p>
ClassMethod HandleAttachmentPut(pDB As %String, pDocId As %String, pAttName As %String) As %Status
{
    Set tSC = ##class(IRISCouch.API.AttachmentHandler).HandlePut(pDB, pDocId, pAttName)
    Do ..RecordRequestMetrics()
    Quit tSC
}

/// <p>Dispatch GET /:db/:docid/:attname to AttachmentHandler (download attachment).</p>
ClassMethod HandleAttachmentGet(pDB As %String, pDocId As %String, pAttName As %String) As %Status
{
    Set tSC = ##class(IRISCouch.API.AttachmentHandler).HandleGet(pDB, pDocId, pAttName)
    Do ..RecordRequestMetrics()
    Quit tSC
}

/// <p>Dispatch DELETE /:db/:docid/:attname to AttachmentHandler (delete attachment).</p>
ClassMethod HandleAttachmentDelete(pDB As %String, pDocId As %String, pAttName As %String) As %Status
{
    Set tSC = ##class(IRISCouch.API.AttachmentHandler).HandleDelete(pDB, pDocId, pAttName)
    Do ..RecordRequestMetrics()
    Quit tSC
}

/// <p>Dispatch POST /:db/_find to MangoHandler (execute Mango query).</p>
ClassMethod HandleMangoFind(pDB As %String) As %Status
{
    Set tSC = ##class(IRISCouch.API.MangoHandler).HandleFind(pDB)
    Do ..RecordRequestMetrics()
    Quit tSC
}

/// <p>Dispatch POST /:db/_explain to MangoHandler (explain Mango query plan).</p>
ClassMethod HandleMangoExplain(pDB As %String) As %Status
{
    Set tSC = ##class(IRISCouch.API.MangoHandler).HandleExplain(pDB)
    Do ..RecordRequestMetrics()
    Quit tSC
}

/// <p>Dispatch POST /:db/_index to MangoHandler (create Mango index).</p>
ClassMethod HandleMangoIndexCreate(pDB As %String) As %Status
{
    Set tSC = ##class(IRISCouch.API.MangoHandler).HandleCreateIndex(pDB)
    Do ..RecordRequestMetrics()
    Quit tSC
}

/// <p>Dispatch GET /:db/_index to MangoHandler (list Mango indexes).</p>
ClassMethod HandleMangoIndexList(pDB As %String) As %Status
{
    Set tSC = ##class(IRISCouch.API.MangoHandler).HandleListIndexes(pDB)
    Do ..RecordRequestMetrics()
    Quit tSC
}

/// <p>Dispatch DELETE /:db/_index/:ddoc/:type/:name to MangoHandler (delete Mango index).</p>
ClassMethod HandleMangoIndexDelete(pDB As %String, pDDoc As %String, pType As %String, pName As %String) As %Status
{
    Set tSC = ##class(IRISCouch.API.MangoHandler).HandleDeleteIndex(pDB, pDDoc, pType, pName)
    Do ..RecordRequestMetrics()
    Quit tSC
}

/// <p>Dispatch POST /_session to AuthHandler (login).</p>
ClassMethod HandleSessionPost() As %Status
{
    Set tSC = ##class(IRISCouch.API.AuthHandler).HandleSessionPost()
    Do ..RecordRequestMetrics()
    Quit tSC
}

/// <p>Dispatch GET /_session to AuthHandler (session info).</p>
ClassMethod HandleSessionGet() As %Status
{
    Set tSC = ##class(IRISCouch.API.AuthHandler).HandleSessionGet()
    Do ..RecordRequestMetrics()
    Quit tSC
}

/// <p>Dispatch DELETE /_session to AuthHandler (logout).</p>
ClassMethod HandleSessionDelete() As %Status
{
    Set tSC = ##class(IRISCouch.API.AuthHandler).HandleSessionDelete()
    Do ..RecordRequestMetrics()
    Quit tSC
}

/// <p>Dispatch GET /:db/_security to SecurityHandler.</p>
ClassMethod HandleSecurityGet(pDB As %String) As %Status
{
    Set tSC = ##class(IRISCouch.API.SecurityHandler).HandleGet(pDB)
    Do ..RecordRequestMetrics()
    Quit tSC
}

/// <p>Dispatch PUT /:db/_security to SecurityHandler.</p>
ClassMethod HandleSecurityPut(pDB As %String) As %Status
{
    Set tSC = ##class(IRISCouch.API.SecurityHandler).HandlePut(pDB)
    Do ..RecordRequestMetrics()
    Quit tSC
}

/// <p>Dispatch GET /:db/_local/:localid to ReplicationHandler.</p>
ClassMethod HandleLocalGet(pDB As %String, pLocalId As %String) As %Status
{
    Set tSC = ##class(IRISCouch.API.ReplicationHandler).HandleLocalGet(pDB, pLocalId)
    Do ..RecordRequestMetrics()
    Quit tSC
}

/// <p>Dispatch PUT /:db/_local/:localid to ReplicationHandler.</p>
ClassMethod HandleLocalPut(pDB As %String, pLocalId As %String) As %Status
{
    Set tSC = ##class(IRISCouch.API.ReplicationHandler).HandleLocalPut(pDB, pLocalId)
    Do ..RecordRequestMetrics()
    Quit tSC
}

/// <p>Dispatch DELETE /:db/_local/:localid to ReplicationHandler.</p>
ClassMethod HandleLocalDelete(pDB As %String, pLocalId As %String) As %Status
{
    Set tSC = ##class(IRISCouch.API.ReplicationHandler).HandleLocalDelete(pDB, pLocalId)
    Do ..RecordRequestMetrics()
    Quit tSC
}

/// <p>Dispatch POST /:db/_revs_diff to ReplicationHandler.</p>
ClassMethod HandleRevsDiff(pDB As %String) As %Status
{
    Set tSC = ##class(IRISCouch.API.ReplicationHandler).HandleRevsDiff(pDB)
    Do ..RecordRequestMetrics()
    Quit tSC
}

/// <p>Record metrics for the current request (Story 9.1).</p>
/// <p>Called at the end of each handler wrapper to record request count,
/// status code, and latency. Uses process-private variables set by
/// <method>OnPreDispatch</method> for start time and endpoint category.</p>
/// <p>Wrapped in Try/Catch per NFR-O3: metrics failures never propagate.</p>
ClassMethod RecordRequestMetrics() [ Private ]
{
    Try {
        If $Get(%IRISCouchRequestStart) '= "" {
            Set tDuration = ($ZHorolog - %IRISCouchRequestStart) * 1000
            Set tStatus = +$Piece(%response.Status, " ", 1)
            Do ##class(IRISCouch.Metrics.Record).Record($Get(%IRISCouchEndpoint, "unknown"), %request.Method, tStatus, tDuration)
        }
    }
    Catch ex {
        ; NFR-O3: never propagate metrics failures
    }
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
        ; Priority 1: Check for AuthSession cookie
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
        ; Priority 2: Check for Authorization: Bearer (JWT) header
        Set tAuthHeader = %request.GetCgiEnv("HTTP_AUTHORIZATION", "")
        If (tAuthHeader '= "") && ($ZConvert($Piece(tAuthHeader, " ", 1), "U") = "BEARER") {
            Set tOK = ##class(IRISCouch.Auth.JWT).Validate(tAuthHeader, .tUsername, .tRoles)
            If tOK {
                Set %IRISCouchUser = tUsername
                Set %IRISCouchRoles = tRoles
                Set %IRISCouchAuthMethod = "jwt"
                Quit
            }
        }
        ; Priority 3: Check for X-Auth-CouchDB-UserName proxy auth header
        Set tProxyUser = %request.GetCgiEnv("HTTP_X_AUTH_COUCHDB_USERNAME", "")
        If tProxyUser '= "" {
            Set tOK = ##class(IRISCouch.Auth.Proxy).Authenticate(.tUsername, .tRoles)
            If tOK {
                Set %IRISCouchUser = tUsername
                Set %IRISCouchRoles = tRoles
                Set %IRISCouchAuthMethod = "proxy"
                Quit
            }
        }
        ; Priority 4: Check for Authorization: Basic header
        If (tAuthHeader '= "") && ($ZConvert($Piece(tAuthHeader, " ", 1), "U") = "BASIC") {
            Set tOK = ##class(IRISCouch.Auth.Basic).Authenticate(tAuthHeader, .tUsername, .tRoles)
            If tOK {
                Set %IRISCouchUser = tUsername
                Set %IRISCouchRoles = tRoles
                Set %IRISCouchAuthMethod = "default"
                ; Audit successful Basic auth (Story 9.2)
                Do ##class(IRISCouch.Audit.Emit).AuthSuccess(tUsername, "basic")
                Quit
            } Else {
                ; Audit failed Basic auth (Story 9.2)
                Do ##class(IRISCouch.Audit.Emit).AuthFailure($Get(tUsername, ""), "basic", "Invalid credentials")
            }
        }
        ; No valid auth — anonymous context (already set above)
        Quit
    }
    Catch ex {
        ; On error, remain anonymous — don't block the request
        Quit
    }
    ; --- Admin UI dispatch (Story 11.5) ---
    ; Intercept /_utils/ URLs before UrlMap dispatch since the SPA has
    ; multi-segment deep-link paths that UrlMap single-segment :param cannot match.
    ; Extract the full path from pUrl and dispatch to AdminUIHandler.
    If ($Extract(pUrl, 1, 7) = "/_utils") {
        Set pContinue = 0
        ; Extract the relative path after /_utils/
        Set tUtilsPath = $Extract(pUrl, 8, *)
        ; Strip leading slash
        If $Extract(tUtilsPath, 1) = "/" Set tUtilsPath = $Extract(tUtilsPath, 2, *)
        ; Default to index.html
        If tUtilsPath = "" Set tUtilsPath = "index.html"
        ; Metrics: record request start time
        Set %IRISCouchRequestStart = $ZHorolog
        Set %IRISCouchEndpoint = "admin_ui"
        Do ##class(IRISCouch.API.AdminUIHandler).HandleRequest(tUtilsPath)
        Do ..RecordRequestMetrics()
        Quit $$$OK
    }
    ; --- Per-database security enforcement (Story 7.4) ---
    ; Must execute AFTER auth context is established but BEFORE dispatch
    ; Parse database name from URL (pUrl is relative: /{db}/... or /_session etc.)
    Set tPathSegment = $Piece(pUrl, "/", 2)
    ; Skip enforcement for server-level endpoints
    If (tPathSegment = "") || (tPathSegment = "_session") || (tPathSegment = "_uuids") || (tPathSegment = "_all_dbs") || (tPathSegment = "_prometheus") {
        ; Metrics: record request start time (Story 9.1)
        Set %IRISCouchRequestStart = $ZHorolog
        Set %IRISCouchEndpoint = ##class(IRISCouch.Metrics.Record).ClassifyEndpoint(%request.URL)
        Quit $$$OK
    }
    ; Skip enforcement for root URL
    If pUrl = "/" {
        ; Metrics: record request start time (Story 9.1)
        Set %IRISCouchRequestStart = $ZHorolog
        Set %IRISCouchEndpoint = ##class(IRISCouch.Metrics.Record).ClassifyEndpoint(%request.URL)
        Quit $$$OK
    }
    ; Only enforce on database-level URLs (skip if first segment starts with _ and is a known server endpoint)
    ; Database names can start with _ (e.g., _users, _replicator) so we only skip known server endpoints
    ; At this point tPathSegment is the database name
    Set tDB = tPathSegment
    ; Only enforce if the database has a security config
    If ##class(IRISCouch.Auth.Security).Exists(tDB) {
        ; Determine if this is an admin operation
        Set tIsAdminOp = 0
        ; PUT /_security is an admin operation
        If ($Piece(pUrl, "/", 3) = "_security") && (pMethod = "PUT") {
            Set tIsAdminOp = 1
        }
        ; Design document writes are admin operations
        If ($Piece(pUrl, "/", 3) = "_design") && ((pMethod = "PUT") || (pMethod = "DELETE")) {
            Set tIsAdminOp = 1
        }
        ; Check access
        Set tAllowed = ##class(IRISCouch.Auth.Security).CheckAccess(tDB, %IRISCouchUser, %IRISCouchRoles, tIsAdminOp)
        If 'tAllowed {
            Set pContinue = 0
            ; Anonymous users get 401, authenticated users get 403
            If %IRISCouchUser = "" {
                Do ##class(IRISCouch.Util.Error).Render(401, "unauthorized", "Authentication required for this database")
            } Else {
                Do ##class(IRISCouch.Util.Error).Render(403, "forbidden", "You are not allowed to access this db.")
            }
            ; Metrics: record denied request (Story 9.1)
            Try {
                Set tDeniedStart = $ZHorolog
                Set tDeniedEndpoint = ##class(IRISCouch.Metrics.Record).ClassifyEndpoint(%request.URL)
                Set tDeniedStatus = +$Piece(%response.Status, " ", 1)
                Set tDeniedDuration = ($ZHorolog - tDeniedStart) * 1000
                Do ##class(IRISCouch.Metrics.Record).Record(tDeniedEndpoint, %request.Method, tDeniedStatus, tDeniedDuration)
            }
            Catch ex {
                ; NFR-O3: never propagate metrics failures
            }
            Quit $$$OK
        }
    }
    ; Metrics: record request start time (Story 9.1)
    Set %IRISCouchRequestStart = $ZHorolog
    Set %IRISCouchEndpoint = ##class(IRISCouch.Metrics.Record).ClassifyEndpoint(%request.URL)
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
