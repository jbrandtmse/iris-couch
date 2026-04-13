/// <p>HTTP integration tests for IRISCouch per-database _security endpoints.</p>
/// <p>Tests PUT and GET /_security via live HTTP requests, verifying
/// endpoint routing, response format, open access behavior, and
/// server admin bypass.</p>
Class IRISCouch.Test.SecurityHttpTest Extends %UnitTest.TestCase
{

/// <p>Test database name used for HTTP security tests.</p>
Parameter TESTDB = "sectesthttpdb";

/// <p>Handle initvalue parameter from parent class.</p>
Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Quit $$$OK
}

/// <p>Set up a test database before each test.</p>
Method OnBeforeOneTest() As %Status
{
    If '##class(IRISCouch.Storage.Database).Exists(..#TESTDB) {
        Do ##class(IRISCouch.Storage.Database).Create(..#TESTDB)
    }
    Kill ^IRISCouch.Security(..#TESTDB)
    Quit $$$OK
}

/// <p>Clean up test database and security after each test.</p>
Method OnAfterOneTest() As %Status
{
    Kill ^IRISCouch.Security(..#TESTDB)
    If ##class(IRISCouch.Storage.Database).Exists(..#TESTDB) {
        Do ##class(IRISCouch.Storage.Database).Delete(..#TESTDB)
    }
    Quit $$$OK
}

/// <p>Test PUT /_security stores config and returns ok:true.</p>
/// <p>AC #1: PUT stores security config for a database.</p>
Method TestAPutSecurity()
{
    Set tReq = ..CreateRequest()
    Set tBody = "{""admins"":{""names"":[""admin1""],""roles"":[""db-admin""]},""members"":{""names"":[""user1""],""roles"":[""reader""]}}"
    Do tReq.EntityBody.Write(tBody)
    Set tSC = tReq.Put("/iris-couch/" _ ..#TESTDB _ "/_security")
    Do $$$AssertStatusOK(tSC, "PUT /_security request completed")
    Do $$$AssertEquals(tReq.HttpResponse.StatusCode, 200, "PUT /_security returns 200")
    Set tRespStr = tReq.HttpResponse.Data.Read()
    Set tResp = ##class(%DynamicObject).%FromJSON(tRespStr)
    Do $$$AssertTrue(tResp.ok, "PUT response has ok:true")
    ; Verify it was stored in the global
    Do $$$AssertTrue(##class(IRISCouch.Auth.Security).Exists(..#TESTDB), "Security config stored in global")
}

/// <p>Test GET /_security returns stored config, empty default, and 404 cases.</p>
/// <p>AC #2: GET returns current security object. AC #5: Empty default.</p>
Method TestBGetSecurity()
{
    ; Test empty default first
    Set tReq = ..CreateRequest()
    Set tSC = tReq.Get("/iris-couch/" _ ..#TESTDB _ "/_security")
    Do $$$AssertStatusOK(tSC, "GET empty /_security request completed")
    Do $$$AssertEquals(tReq.HttpResponse.StatusCode, 200, "GET empty returns 200")
    Set tRespStr = tReq.HttpResponse.Data.Read()
    Set tResp = ##class(%DynamicObject).%FromJSON(tRespStr)
    Do $$$AssertEquals(tResp.admins.names.%Size(), 0, "Empty admins.names")
    ; Now store security directly and GET
    Set tSecObj = {"admins":{"names":["admin1"],"roles":["db-admin"]},"members":{"names":["user1"],"roles":["reader"]}}
    Do ##class(IRISCouch.Auth.Security).Put(..#TESTDB, tSecObj)
    Set tReq2 = ..CreateRequest()
    Set tSC = tReq2.Get("/iris-couch/" _ ..#TESTDB _ "/_security")
    Do $$$AssertStatusOK(tSC, "GET stored /_security request completed")
    Do $$$AssertEquals(tReq2.HttpResponse.StatusCode, 200, "GET stored returns 200")
    Set tRespStr2 = tReq2.HttpResponse.Data.Read()
    Set tResp2 = ##class(%DynamicObject).%FromJSON(tRespStr2)
    Do $$$AssertEquals(tResp2.admins.names.%Get(0), "admin1", "Admin name matches")
    Do $$$AssertEquals(tResp2.members.names.%Get(0), "user1", "Member name matches")
}

/// <p>Test 404 on non-existent DB and server admin bypass.</p>
/// <p>AC #5, #7: Non-existent returns 404. Server admin bypasses restrictions.</p>
Method TestCErrorAndBypass()
{
    ; Non-existent DB returns 404
    Set tReq = ..CreateRequest()
    Set tSC = tReq.Get("/iris-couch/nonexistentdb999/_security")
    Do $$$AssertStatusOK(tSC, "GET non-existent DB request completed")
    Do $$$AssertEquals(tReq.HttpResponse.StatusCode, 404, "Non-existent DB returns 404")
    ; Server admin bypass: set strict security, _SYSTEM should still access
    Set tSecObj = {"admins":{"names":["admin1"],"roles":[]},"members":{"names":["user1"],"roles":[]}}
    Do ##class(IRISCouch.Auth.Security).Put(..#TESTDB, tSecObj)
    Set tReq2 = ..CreateRequest()
    Set tSC = tReq2.Get("/iris-couch/" _ ..#TESTDB)
    Do $$$AssertStatusOK(tSC, "GET /db as server admin request completed")
    Do $$$AssertEquals(tReq2.HttpResponse.StatusCode, 200, "Server admin bypasses member restrictions")
}

/// <p>Helper: Create an HTTP request with Basic auth credentials.</p>
ClassMethod CreateRequest() As %Net.HttpRequest
{
    Set tReq = ##class(%Net.HttpRequest).%New()
    Set tReq.Server = "localhost"
    Set tReq.Port = 52773
    Set tReq.Username = "_SYSTEM"
    Set tReq.Password = "SYS"
    Set tReq.ContentType = "application/json"
    Quit tReq
}

}
