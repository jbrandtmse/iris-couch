/// <p>HTTP tests for 405 Method Not Allowed responses on server-level system
/// endpoints (Story 13.4 Task 5 / AC #5).</p>
/// <p>Covers the MED bug discovered during the Epic 1-3 acceptance pass and
/// worsened by the Story 13.4 creation probe: <code>PUT /_all_dbs</code>
/// previously fell through to <code>PUT /:db</code> and silently created a
/// phantom database named <code>_all_dbs</code>. The fix adds explicit
/// method-guard routes to <class>IRISCouch.API.Router</class>'s UrlMap
/// BEFORE the <code>:db</code> catch-all routes so %CSP.REST emits 405
/// rather than dispatching to the database handler.</p>
/// <p>The <method>TestPhantomDatabasePrevention</method> test is the key
/// regression guard: verify <code>PUT /_all_dbs</code> → 405 AND a
/// subsequent <code>GET /_all_dbs</code> does NOT contain <code>_all_dbs</code>.</p>
Class IRISCouch.Test.MethodNotAllowedTest Extends %UnitTest.TestCase
{

/// <p>Handle initvalue parameter from parent class.</p>
Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Quit $$$OK
}

/// <p>Cleanup: ensure no residual phantom DB from a failed prior test run.</p>
Method OnBeforeOneTest() As %Status
{
    Do ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("DELETE", "/_all_dbs", .tS, .tB)
    Quit $$$OK
}

/// <p>Make an HTTP request and capture status + Allow header.</p>
ClassMethod RequestWithAllow(pMethod As %String, pPath As %String, Output pStatus As %Integer, Output pAllow As %String, Output pBody As %DynamicObject) As %Status [ Internal ]
{
    Set pAllow = ""
    Set pBody = ""
    Set tReq = ##class(%Net.HttpRequest).%New()
    Set tReq.Server = ##class(IRISCouch.Test.HttpIntegrationTest).GetTestServer()
    Set tReq.Port = ##class(IRISCouch.Test.HttpIntegrationTest).GetTestPort()
    Set tReq.Username = ##class(IRISCouch.Test.HttpIntegrationTest).GetTestUsername()
    Set tReq.Password = ##class(IRISCouch.Test.HttpIntegrationTest).GetTestPassword()
    Set tReq.ContentType = "application/json"
    Set tFullPath = "/iris-couch" _ pPath
    If pMethod = "GET" {
        Set tSC = tReq.Get(tFullPath)
    } ElseIf pMethod = "PUT" {
        Set tSC = tReq.Put(tFullPath)
    } ElseIf pMethod = "POST" {
        Set tSC = tReq.Post(tFullPath)
    } ElseIf pMethod = "DELETE" {
        Set tSC = tReq.Delete(tFullPath)
    } Else {
        Set tSC = $$$ERROR($$$GeneralError, "Unsupported method")
    }
    If $$$ISERR(tSC) Quit tSC
    Set pStatus = tReq.HttpResponse.StatusCode
    Set pAllow = tReq.HttpResponse.GetHeader("Allow")
    Set tBodyStr = tReq.HttpResponse.Data.Read()
    If tBodyStr '= "" {
        Set tFirstChar = $Extract($ZStrip(tBodyStr, "<W"), 1)
        If (tFirstChar = "{") || (tFirstChar = "[") {
            Set pBody = ##class(%DynamicAbstractObject).%FromJSON(tBodyStr)
        }
    }
    Quit $$$OK
}

/// <p>AC #5 (a): POST /_uuids → 405 with Allow: GET.</p>
Method TestPostUuidsReturns405()
{
    Set tSC = ..RequestWithAllow("POST", "/_uuids", .tStatus, .tAllow, .tBody)
    Do $$$AssertStatusOK(tSC, "POST /_uuids request completed")
    Do $$$AssertEquals(tStatus, 405, "POST /_uuids returns 405")
    Do $$$AssertEquals(tAllow, "GET", "Allow header lists only GET")
    Do $$$AssertTrue($IsObject(tBody), "Body is JSON")
    Do $$$AssertEquals(tBody.error, "method_not_allowed", "error slug method_not_allowed")
}

/// <p>AC #5 (b) — the phantom-DB regression test.</p>
/// <p>PUT /_all_dbs must return 405, AND a subsequent GET /_all_dbs must NOT
/// include "_all_dbs" in the returned array. Without the method-guard route,
/// the PUT fell through to <code>PUT /:db</code> and silently created a DB.</p>
Method TestPhantomDatabasePrevention()
{
    Set tSC = ..RequestWithAllow("PUT", "/_all_dbs", .tStatus, .tAllow, .tBody)
    Do $$$AssertEquals(tStatus, 405, "PUT /_all_dbs returns 405")
    Do $$$AssertEquals(tAllow, "GET", "Allow header is GET")
    ; Regression check: no phantom database
    Set tSC2 = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/_all_dbs", .tS2, .tB2)
    Do $$$AssertEquals(tS2, 200, "GET /_all_dbs returns 200")
    Do $$$AssertTrue($IsObject(tB2), "Response is a JSON array")
    ; Iterate the array looking for "_all_dbs" — must not be present.
    Set tFound = 0
    If $IsObject(tB2) {
        Set tI = 0
        While tI < tB2.%Size() {
            If tB2.%Get(tI) = "_all_dbs" Set tFound = 1 Quit
            Set tI = tI + 1
        }
    }
    Do $$$AssertEquals(tFound, 0, "GET /_all_dbs does NOT contain phantom _all_dbs")
}

/// <p>AC #5 (d): POST /_prometheus → 405 with Allow: GET.</p>
Method TestPostPrometheusReturns405()
{
    Set tSC = ..RequestWithAllow("POST", "/_prometheus", .tStatus, .tAllow, .tBody)
    Do $$$AssertEquals(tStatus, 405, "POST /_prometheus returns 405")
    Do $$$AssertEquals(tAllow, "GET", "Allow header is GET")
}

/// <p>AC #5 (c): DELETE /_session still works (Story 7.1 logout).</p>
/// <p>Guard against over-tightening — the 405 sweep must not regress legit methods.</p>
Method TestLegitimateSessionRoutesStillWork()
{
    ; DELETE /_session — logout, should be 200/202 (not 405)
    Set tSC = ..RequestWithAllow("DELETE", "/_session", .tStatus, .tAllow, .tBody)
    Do $$$AssertNotEquals(tStatus, 405, "DELETE /_session must NOT be 405")
    ; Typical success is 200; some impls return 204. Must be <300.
    Do $$$AssertTrue((tStatus >= 200) && (tStatus < 300), "DELETE /_session returned success code (" _ tStatus _ ")")
}

/// <p>Regression guard: PUT /_session must 405 (legitimate methods are GET/POST/DELETE).</p>
Method TestPutSessionReturns405()
{
    Set tSC = ..RequestWithAllow("PUT", "/_session", .tStatus, .tAllow, .tBody)
    Do $$$AssertEquals(tStatus, 405, "PUT /_session returns 405")
    Do $$$AssertTrue(tAllow [ "GET", "Allow header contains GET")
    Do $$$AssertTrue(tAllow [ "POST", "Allow header contains POST")
    Do $$$AssertTrue(tAllow [ "DELETE", "Allow header contains DELETE")
}

}
