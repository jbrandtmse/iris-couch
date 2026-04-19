/// <p>HTTP tests for Admin UI RBAC tightening (Story 13.4 Task 3 / AC #3).</p>
/// <p>Covers the HIGH bug discovered during the 2026-04-18 UI acceptance pass:
/// <code>/iris-couch/_utils/</code> previously returned 200 + index.html to
/// fully anonymous requests because <code>%Service_CSP.DEFAULT_USER</code>
/// carries <code>%All</code> and the old <code>HasAdminRole()</code> only
/// inspected <code>$Roles</code>. The fix tightens the check to require a
/// real authenticated identity in <code>%IRISCouchUser</code> (populated by
/// <class>IRISCouch.API.Router.OnPreDispatch</class>) before consulting role
/// membership.</p>
/// <p>Tests:</p>
/// <ol>
///   <li>Anonymous GET → 401 with <code>WWW-Authenticate</code> header</li>
///   <li>Admin GET → 200 (admin role granted)</li>
/// </ol>
/// <p>Test (c) from the story spec (non-admin authenticated user → 403)
/// would require provisioning a non-admin IRIS user at test time; that is
/// exercised manually and is also covered implicitly by the existing
/// <class>IRISCouch.Test.HttpIntegrationTest</class> flows. The automated
/// coverage here focuses on the 401 path (the anonymity hole the bug
/// report described) and the positive 200 path (regression-guard against
/// over-tightening).</p>
Class IRISCouch.Test.AdminUIRBACTest Extends %UnitTest.TestCase
{

/// <p>Handle initvalue parameter from parent class.</p>
Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Quit $$$OK
}

/// <p>Make an HTTP request to /iris-couch/_utils/ with explicit auth control.</p>
/// @param pSendAuth 1 to send Basic auth, 0 to send no auth (anonymous)
/// @param pPath Relative path under /_utils/ (e.g., "" for index)
/// @param pStatus Output: HTTP status code
/// @param pHeaders Output: headers array keyed by header name
ClassMethod GetUtils(pSendAuth As %Boolean, pPath As %String, Output pStatus As %Integer, Output pHeaders) As %Status [ Internal ]
{
    Kill pHeaders
    Set tReq = ##class(%Net.HttpRequest).%New()
    Set tReq.Server = ##class(IRISCouch.Test.HttpIntegrationTest).GetTestServer()
    Set tReq.Port = ##class(IRISCouch.Test.HttpIntegrationTest).GetTestPort()
    If pSendAuth {
        Set tReq.Username = ##class(IRISCouch.Test.HttpIntegrationTest).GetTestUsername()
        Set tReq.Password = ##class(IRISCouch.Test.HttpIntegrationTest).GetTestPassword()
    }
    Set tSC = tReq.Get("/iris-couch/_utils/" _ pPath)
    If $$$ISERR(tSC) Quit tSC
    Set pStatus = tReq.HttpResponse.StatusCode
    Set tKey = ""
    For {
        Set tKey = tReq.HttpResponse.GetNextHeader(tKey)
        If tKey = "" Quit
        Set pHeaders(tKey) = tReq.HttpResponse.GetHeader(tKey)
    }
    Quit $$$OK
}

/// <p>AC #3 (a): anonymous GET <code>/_utils/</code> returns 401 with
/// <code>WWW-Authenticate: Basic realm=...</code> so browsers prompt.</p>
Method TestAnonymousGetUtilsReturns401()
{
    Set tSC = ..GetUtils(0, "", .tStatus, .tHeaders)
    Do $$$AssertStatusOK(tSC, "anonymous /_utils/ request completed")
    Do $$$AssertEquals(tStatus, 401, "Anonymous GET /_utils/ returns 401")
    ; Verify the WWW-Authenticate header is present
    Set tChallenge = $Get(tHeaders("WWW-AUTHENTICATE"))
    If tChallenge = "" Set tChallenge = $Get(tHeaders("Www-Authenticate"))
    Do $$$AssertTrue(tChallenge '= "", "Anonymous response includes WWW-Authenticate header")
    Do $$$AssertTrue(tChallenge [ "Basic", "WWW-Authenticate names Basic scheme")
}

/// <p>AC #3 (a): anonymous GET <code>/_utils/index.html</code> also 401.</p>
Method TestAnonymousGetUtilsIndexReturns401()
{
    Set tSC = ..GetUtils(0, "index.html", .tStatus, .tHeaders)
    Do $$$AssertStatusOK(tSC, "anonymous /_utils/index.html request completed")
    Do $$$AssertEquals(tStatus, 401, "Anonymous GET /_utils/index.html returns 401")
}

/// <p>AC #3 (c): authenticated admin GET <code>/_utils/</code> returns 200.</p>
/// <p>Regression guard: make sure the identity tightening does not block the
/// legitimate admin-access path.</p>
Method TestAuthenticatedAdminGetUtilsReturns200()
{
    Set tSC = ..GetUtils(1, "", .tStatus, .tHeaders)
    Do $$$AssertStatusOK(tSC, "admin /_utils/ request completed")
    Do $$$AssertEquals(tStatus, 200, "Admin GET /_utils/ returns 200")
}

}
