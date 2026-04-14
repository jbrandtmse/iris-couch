/// <p>HTTP integration tests for IRISCouch JWT and Proxy authentication.</p>
/// <p>Tests bearer token authentication, proxy auth headers, and auth priority
/// ordering via live HTTP requests against the <code>/_session</code> endpoint.
/// Verifies that <code>info.authenticated</code> correctly reflects the auth method.</p>
Class IRISCouch.Test.JWTHttpTest Extends %UnitTest.TestCase
{

/// <p>Handle initvalue parameter from parent class.</p>
Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Quit $$$OK
}

/// <p>Set up JWT and proxy config before each test.</p>
Method OnBeforeOneTest() As %Status
{
    Do ##class(IRISCouch.Config).Set("JWTSECRET", "http-test-jwt-secret")
    Do ##class(IRISCouch.Config).Set("JWTISSUER", "http-test-issuer")
    Do ##class(IRISCouch.Config).Set("JWTROLESCLAIM", "roles")
    Do ##class(IRISCouch.Config).Set("PROXYAUTHSECRET", "http-test-proxy-secret")
    Quit $$$OK
}

/// <p>Clean up JWT and proxy config after each test.</p>
Method OnAfterOneTest() As %Status
{
    Kill ^IRISCouch.Config("JWTSECRET")
    Kill ^IRISCouch.Config("JWTISSUER")
    Kill ^IRISCouch.Config("JWTROLESCLAIM")
    Kill ^IRISCouch.Config("PROXYAUTHSECRET")
    Quit $$$OK
}

/// <p>Test Bearer auth via HTTP: valid JWT on GET /_session shows jwt auth.</p>
/// <p>AC #1, #8: Valid Bearer token authenticates and session info reports jwt method.</p>
Method TestBearerAuthSuccess()
{
    Set tRoles = ["admin", "reader"]
    Set tJWT = ##class(IRISCouch.Test.JWTTest).BuildTestJWT("jwtuser", "http-test-issuer", ##class(IRISCouch.Auth.JWT).UnixTimestamp() + 3600, tRoles, "http-test-jwt-secret")
    Set tReq = ..CreateRequestNoCreds()
    Do tReq.SetHeader("Authorization", "Bearer " _ tJWT)
    Set tSC = tReq.Get("/iris-couch/_session")
    Do $$$AssertStatusOK(tSC, "GET /_session with Bearer token request completed")
    Do $$$AssertEquals(tReq.HttpResponse.StatusCode, 200, "GET /_session with Bearer returns 200")
    Set tBodyStr = tReq.HttpResponse.Data.Read()
    Set tBody = ##class(%DynamicObject).%FromJSON(tBodyStr)
    Do $$$AssertTrue(tBody.ok, "Response has ok:true")
    Do $$$AssertEquals(tBody.userCtx.name, "jwtuser", "userCtx.name is jwtuser")
    Do $$$AssertTrue($IsObject(tBody.userCtx.roles), "userCtx.roles is an array")
    Do $$$AssertEquals(tBody.userCtx.roles.%Size(), 2, "Two roles present")
    Do $$$AssertEquals(tBody.info.authenticated, "jwt", "info.authenticated is jwt")
}

/// <p>Test Bearer auth via HTTP: expired JWT falls through to anonymous.</p>
/// <p>AC #2: Expired JWT results in anonymous context (no 401, just unauthenticated).</p>
Method TestBearerAuthExpired()
{
    Set tJWT = ##class(IRISCouch.Test.JWTTest).BuildTestJWT("jwtuser", "http-test-issuer", ##class(IRISCouch.Auth.JWT).UnixTimestamp() - 3600, "", "http-test-jwt-secret")
    Set tReq = ..CreateRequestNoCreds()
    Do tReq.SetHeader("Authorization", "Bearer " _ tJWT)
    Set tSC = tReq.Get("/iris-couch/_session")
    Do $$$AssertStatusOK(tSC, "GET /_session with expired Bearer request completed")
    Do $$$AssertEquals(tReq.HttpResponse.StatusCode, 200, "Expired JWT returns 200 (anonymous context)")
    Set tBodyStr = tReq.HttpResponse.Data.Read()
    Set tBody = ##class(%DynamicObject).%FromJSON(tBodyStr)
    Do $$$AssertTrue(tBody.userCtx.%GetTypeOf("name") = "null", "Expired JWT results in null name (anonymous)")
}

/// <p>Test proxy auth via HTTP: valid proxy headers on GET /_session shows proxy auth.</p>
/// <p>AC #3, #8: Valid proxy headers authenticate and session info reports proxy method.</p>
Method TestProxyAuthSuccess()
{
    ; Compute HMAC-SHA1 token (160 = SHA-1 bit size)
    Set tHMAC = $System.Encryption.HMACSHA(160, "proxyuser", "http-test-proxy-secret")
    Set tToken = ##class(IRISCouch.Auth.Session).BytesToHex(tHMAC)
    Set tReq = ..CreateRequestNoCreds()
    Do tReq.SetHeader("X-Auth-CouchDB-UserName", "proxyuser")
    Do tReq.SetHeader("X-Auth-CouchDB-Roles", "db_admin,reader")
    Do tReq.SetHeader("X-Auth-CouchDB-Token", tToken)
    Set tSC = tReq.Get("/iris-couch/_session")
    Do $$$AssertStatusOK(tSC, "GET /_session with proxy headers request completed")
    Do $$$AssertEquals(tReq.HttpResponse.StatusCode, 200, "GET /_session with proxy headers returns 200")
    Set tBodyStr = tReq.HttpResponse.Data.Read()
    Set tBody = ##class(%DynamicObject).%FromJSON(tBodyStr)
    Do $$$AssertTrue(tBody.ok, "Response has ok:true")
    Do $$$AssertEquals(tBody.userCtx.name, "proxyuser", "userCtx.name is proxyuser")
    Do $$$AssertEquals(tBody.userCtx.roles.%Size(), 2, "Two roles present")
    Do $$$AssertEquals(tBody.userCtx.roles.%Get(0), "db_admin", "First role is db_admin")
    Do $$$AssertEquals(tBody.userCtx.roles.%Get(1), "reader", "Second role is reader")
    Do $$$AssertEquals(tBody.info.authenticated, "proxy", "info.authenticated is proxy")
}

/// <p>Test proxy auth via HTTP: bad token falls through to anonymous.</p>
/// <p>AC #4: Wrong proxy token results in anonymous context.</p>
Method TestProxyAuthBadToken()
{
    Set tReq = ..CreateRequestNoCreds()
    Do tReq.SetHeader("X-Auth-CouchDB-UserName", "proxyuser")
    Do tReq.SetHeader("X-Auth-CouchDB-Roles", "admin")
    Do tReq.SetHeader("X-Auth-CouchDB-Token", "deadbeef01234567890abcdef0123456789abcde")
    Set tSC = tReq.Get("/iris-couch/_session")
    Do $$$AssertStatusOK(tSC, "GET /_session with bad proxy token request completed")
    Do $$$AssertEquals(tReq.HttpResponse.StatusCode, 200, "Bad proxy token returns 200 (anonymous)")
    Set tBodyStr = tReq.HttpResponse.Data.Read()
    Set tBody = ##class(%DynamicObject).%FromJSON(tBodyStr)
    Do $$$AssertTrue(tBody.userCtx.%GetTypeOf("name") = "null", "Bad proxy token results in null name (anonymous)")
}

/// <p>Test auth priority: cookie beats Bearer token.</p>
/// <p>AC #5: When both cookie and Bearer are present, cookie wins.</p>
Method TestAuthPriorityOrder()
{
    ; First login to get a cookie
    Set tCookieValue = ..LoginAndGetCookie()
    Do $$$AssertTrue(tCookieValue '= "", "Login returned a cookie value")
    ; Also create a valid JWT
    Set tJWT = ##class(IRISCouch.Test.JWTTest).BuildTestJWT("jwtuser", "http-test-issuer", ##class(IRISCouch.Auth.JWT).UnixTimestamp() + 3600, "", "http-test-jwt-secret")
    ; Send request with BOTH cookie and Bearer token
    Set tReq = ..CreateRequestNoCreds()
    Do tReq.SetHeader("Cookie", "AuthSession=" _ tCookieValue)
    Do tReq.SetHeader("Authorization", "Bearer " _ tJWT)
    Set tSC = tReq.Get("/iris-couch/_session")
    Do $$$AssertStatusOK(tSC, "GET /_session with cookie+Bearer request completed")
    Do $$$AssertEquals(tReq.HttpResponse.StatusCode, 200, "Returns 200")
    Set tBodyStr = tReq.HttpResponse.Data.Read()
    Set tBody = ##class(%DynamicObject).%FromJSON(tBodyStr)
    ; Cookie should win over Bearer
    Do $$$AssertEquals(tBody.info.authenticated, "cookie", "Cookie takes priority over Bearer (auth method is cookie)")
    Set tExpectedUser = ##class(IRISCouch.Test.HttpIntegrationTest).GetTestUsername()
    Do $$$AssertEquals(tBody.userCtx.name, tExpectedUser, "Cookie user wins over JWT user")
}

/// <p>Helper: Create an HTTP request with no credentials.</p>
ClassMethod CreateRequestNoCreds() As %Net.HttpRequest
{
    Set tReq = ##class(%Net.HttpRequest).%New()
    Set tReq.Server = ##class(IRISCouch.Test.HttpIntegrationTest).GetTestServer()
    Set tReq.Port = ##class(IRISCouch.Test.HttpIntegrationTest).GetTestPort()
    Set tReq.ContentType = "application/json"
    Quit tReq
}

/// <p>Helper: Login via POST /_session and extract the cookie value.</p>
ClassMethod LoginAndGetCookie() As %String
{
    Set tResult = ""
    Try {
        Set tReq = ##class(%Net.HttpRequest).%New()
        Set tReq.Server = ##class(IRISCouch.Test.HttpIntegrationTest).GetTestServer()
        Set tReq.Port = ##class(IRISCouch.Test.HttpIntegrationTest).GetTestPort()
        Set tReq.ContentType = "application/json"
        Set tUser = ##class(IRISCouch.Test.HttpIntegrationTest).GetTestUsername()
        Set tPass = ##class(IRISCouch.Test.HttpIntegrationTest).GetTestPassword()
        Do tReq.EntityBody.Write("{""name"":""" _ tUser _ """,""password"":""" _ tPass _ """}")
        Set tSC = tReq.Post("/iris-couch/_session")
        If $$$ISERR(tSC) Quit
        If tReq.HttpResponse.StatusCode '= 200 Quit
        Set tSetCookie = tReq.HttpResponse.GetHeader("SET-COOKIE")
        If tSetCookie = "" Quit
        Set tCookiePart = $Piece(tSetCookie, ";", 1)
        Set tResult = $Piece(tCookiePart, "=", 2, *)
        Quit
    }
    Catch ex {
        Set tResult = ""
        Quit
    }
    Quit tResult
}

}
