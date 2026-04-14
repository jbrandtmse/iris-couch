/// <p>HTTP integration tests for IRISCouch session authentication.</p>
/// <p>Tests the <code>/_session</code> endpoints via live HTTP requests using
/// <class>%Net.HttpRequest</class> directly for cookie management.
/// Covers login, session info, logout, Basic auth, cookie tampering,
/// and unauthenticated fallback.</p>
Class IRISCouch.Test.AuthHttpTest Extends %UnitTest.TestCase
{

/// <p>Handle initvalue parameter from parent class.</p>
Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Quit $$$OK
}

/// <p>Clean up auth config after each test.</p>
Method OnAfterOneTest() As %Status
{
    Quit $$$OK
}

/// <p>Test POST /_session with valid credentials returns 200 with Set-Cookie.</p>
/// <p>AC #1: Login with valid credentials returns ok:true, name, roles, and AuthSession cookie.</p>
Method TestSessionPostSuccess()
{
    Set tReq = ..CreateRequest()
    Do tReq.EntityBody.Write("{""name"":""_SYSTEM"",""password"":""SYS""}")
    Set tSC = tReq.Post("/iris-couch/_session")
    Do $$$AssertStatusOK(tSC, "POST /_session request completed")
    Do $$$AssertEquals(tReq.HttpResponse.StatusCode, 200, "POST /_session returns 200")
    ; Parse response body
    Set tBodyStr = tReq.HttpResponse.Data.Read()
    Set tBody = ##class(%DynamicObject).%FromJSON(tBodyStr)
    Do $$$AssertTrue(tBody.ok, "Response has ok:true")
    Do $$$AssertEquals(tBody.name, "_SYSTEM", "Response has correct name")
    Do $$$AssertTrue($IsObject(tBody.roles), "Response has roles array")
    ; Check Set-Cookie header
    Set tCookie = tReq.HttpResponse.GetHeader("SET-COOKIE")
    Do $$$AssertTrue(tCookie [ "AuthSession=", "Set-Cookie contains AuthSession")
}

/// <p>Test POST /_session with wrong password returns 401.</p>
/// <p>AC #1: Login with wrong credentials returns unauthorized error.</p>
Method TestSessionPostBadPassword()
{
    Set tReq = ..CreateRequest()
    Do tReq.EntityBody.Write("{""name"":""_SYSTEM"",""password"":""WRONGPASSWORD""}")
    Set tSC = tReq.Post("/iris-couch/_session")
    Do $$$AssertStatusOK(tSC, "POST /_session bad password request completed")
    Do $$$AssertEquals(tReq.HttpResponse.StatusCode, 401, "POST /_session with bad password returns 401")
    Set tBodyStr = tReq.HttpResponse.Data.Read()
    Set tBody = ##class(%DynamicObject).%FromJSON(tBodyStr)
    Do $$$AssertEquals(tBody.error, "unauthorized", "Error slug is unauthorized")
}

/// <p>Test GET /_session with valid cookie returns authenticated context.</p>
/// <p>AC #2: Session info with valid cookie returns userCtx with name and roles.</p>
Method TestSessionGetAuthenticated()
{
    ; First login to get cookie
    Set tCookieValue = ..LoginAndGetCookie()
    Do $$$AssertTrue(tCookieValue '= "", "Login returned a cookie value")
    ; Now GET /_session with the cookie
    Set tReq = ..CreateRequestNoCreds()
    Do tReq.SetHeader("Cookie", "AuthSession=" _ tCookieValue)
    Set tSC = tReq.Get("/iris-couch/_session")
    Do $$$AssertStatusOK(tSC, "GET /_session with cookie request completed")
    Do $$$AssertEquals(tReq.HttpResponse.StatusCode, 200, "GET /_session with cookie returns 200")
    Set tBodyStr = tReq.HttpResponse.Data.Read()
    Set tBody = ##class(%DynamicObject).%FromJSON(tBodyStr)
    Do $$$AssertTrue(tBody.ok, "Response has ok:true")
    Do $$$AssertEquals(tBody.userCtx.name, "_SYSTEM", "userCtx.name is _SYSTEM")
    Do $$$AssertTrue($IsObject(tBody.userCtx.roles), "userCtx.roles is an array")
    Do $$$AssertEquals(tBody.info.authenticated, "cookie", "info.authenticated is cookie")
}

/// <p>Test GET /_session with no credentials returns unauthenticated context.</p>
/// <p>AC #10: Unauthenticated GET returns name:null and empty roles.</p>
Method TestSessionGetUnauthenticated()
{
    Set tReq = ..CreateRequestNoCreds()
    Set tSC = tReq.Get("/iris-couch/_session")
    Do $$$AssertStatusOK(tSC, "GET /_session unauthenticated request completed")
    Do $$$AssertEquals(tReq.HttpResponse.StatusCode, 200, "GET /_session unauthenticated returns 200")
    Set tBodyStr = tReq.HttpResponse.Data.Read()
    Set tBody = ##class(%DynamicObject).%FromJSON(tBodyStr)
    Do $$$AssertTrue(tBody.ok, "Response has ok:true")
    ; name should be JSON null
    Do $$$AssertTrue(tBody.userCtx.name = "", "userCtx.name is null/empty for unauthenticated")
    Do $$$AssertTrue(tBody.userCtx.%GetTypeOf("name") = "null", "userCtx.name is JSON null type")
    Do $$$AssertEquals(tBody.userCtx.roles.%Size(), 0, "userCtx.roles is empty for unauthenticated")
}

/// <p>Test DELETE /_session returns 200 with expired cookie.</p>
/// <p>AC #3: Logout invalidates the cookie via Max-Age=0.</p>
Method TestSessionDelete()
{
    ; Login first
    Set tCookieValue = ..LoginAndGetCookie()
    Do $$$AssertTrue(tCookieValue '= "", "Login returned a cookie value")
    ; Delete session
    Set tReq = ..CreateRequestNoCreds()
    Do tReq.SetHeader("Cookie", "AuthSession=" _ tCookieValue)
    Set tSC = tReq.Delete("/iris-couch/_session")
    Do $$$AssertStatusOK(tSC, "DELETE /_session request completed")
    Do $$$AssertEquals(tReq.HttpResponse.StatusCode, 200, "DELETE /_session returns 200")
    Set tBodyStr = tReq.HttpResponse.Data.Read()
    Set tBody = ##class(%DynamicObject).%FromJSON(tBodyStr)
    Do $$$AssertTrue(tBody.ok, "Response has ok:true")
    ; Check that Set-Cookie header expires the cookie
    Set tSetCookie = tReq.HttpResponse.GetHeader("SET-COOKIE")
    Do $$$AssertTrue(tSetCookie [ "Max-Age=0", "Set-Cookie expires the cookie with Max-Age=0")
}

/// <p>Test Basic auth on existing endpoint returns authenticated response.</p>
/// <p>AC #4: HTTP Basic auth authenticates against the IRIS user directory.</p>
Method TestBasicAuthOnExistingEndpoint()
{
    Set tReq = ..CreateRequest()
    Set tSC = tReq.Get("/iris-couch/")
    Do $$$AssertStatusOK(tSC, "GET / with Basic auth request completed")
    Do $$$AssertEquals(tReq.HttpResponse.StatusCode, 200, "GET / with Basic auth returns 200")
    Set tBodyStr = tReq.HttpResponse.Data.Read()
    Set tBody = ##class(%DynamicObject).%FromJSON(tBodyStr)
    Do $$$AssertEquals(tBody.couchdb, "Welcome", "Welcome endpoint works with Basic auth")
}

/// <p>Test tampered cookie via HTTP returns anonymous context.</p>
/// <p>AC #5: Tampered AuthSession cookie fails HMAC verification.</p>
Method TestTamperedCookieViaHttp()
{
    ; Login to get a valid cookie
    Set tCookieValue = ..LoginAndGetCookie()
    Do $$$AssertTrue(tCookieValue '= "", "Login returned a cookie value")
    ; Tamper with the cookie value
    Set tDecoded = $System.Encryption.Base64Decode(tCookieValue)
    Set tLen = $Length(tDecoded)
    Set tLastChar = $Extract(tDecoded, tLen)
    If tLastChar = "x" {
        Set tTampered = $Extract(tDecoded, 1, tLen - 1) _ "y"
    } Else {
        Set tTampered = $Extract(tDecoded, 1, tLen - 1) _ "x"
    }
    Set tTamperedCookie = $System.Encryption.Base64Encode(tTampered)
    Set tTamperedCookie = $Translate(tTamperedCookie, $Char(13, 10), "")
    ; GET /_session with tampered cookie should return anonymous context
    Set tReq = ..CreateRequestNoCreds()
    Do tReq.SetHeader("Cookie", "AuthSession=" _ tTamperedCookie)
    Set tSC = tReq.Get("/iris-couch/_session")
    Do $$$AssertStatusOK(tSC, "GET /_session with tampered cookie request completed")
    Do $$$AssertEquals(tReq.HttpResponse.StatusCode, 200, "GET /_session with tampered cookie returns 200")
    Set tBodyStr = tReq.HttpResponse.Data.Read()
    Set tBody = ##class(%DynamicObject).%FromJSON(tBodyStr)
    Do $$$AssertTrue(tBody.userCtx.%GetTypeOf("name") = "null", "Tampered cookie results in anonymous context (name is null)")
    Do $$$AssertEquals(tBody.userCtx.roles.%Size(), 0, "Tampered cookie results in empty roles")
}

/// <p>Test non-admin user authentication round-trip (AC #7).</p>
/// <p>Creates a user via the <code>_users</code> API, verifies Basic auth returns 200,
/// verifies session login returns 200 with cookie, and verifies cookie auth returns
/// authenticated context. Cleans up after itself.</p>
Method TestNonAdminUserAuth()
{
    Set tTestUser = "hotfix_test_user"
    Set tTestPass = "hotfix_pass_42"
    Try {
        ; Clean up any leftover test user from previous runs
        Do ..CleanupTestUser(tTestUser)
        ; Ensure _users database exists
        Set tReq = ..CreateRequest()
        Set tSC = tReq.Put("/iris-couch/_users")
        ; Create user via _users API
        Set tReq = ..CreateRequest()
        Set tUserBody = {}
        Set tUserBody."_id" = "org.couchdb.user:" _ tTestUser
        Set tUserBody.type = "user"
        Set tUserBody.name = tTestUser
        Set tUserBody.password = tTestPass
        Set tUserBody.roles = ["reader"]
        Do tReq.EntityBody.Write(tUserBody.%ToJSON())
        Set tSC = tReq.Put("/iris-couch/_users/org.couchdb.user:" _ tTestUser)
        Do $$$AssertStatusOK(tSC, "PUT _users doc request completed")
        Do $$$AssertTrue((tReq.HttpResponse.StatusCode = 201) || (tReq.HttpResponse.StatusCode = 200), "User doc created successfully")
        ; Verify Basic auth with non-admin user
        Set tReq2 = ##class(%Net.HttpRequest).%New()
        Set tReq2.Server = "localhost"
        Set tReq2.Port = 52773
        Set tReq2.Username = tTestUser
        Set tReq2.Password = tTestPass
        Set tReq2.ContentType = "application/json"
        Set tSC = tReq2.Get("/iris-couch/")
        Do $$$AssertStatusOK(tSC, "GET / with non-admin Basic auth request completed")
        Do $$$AssertEquals(tReq2.HttpResponse.StatusCode, 200, "Non-admin Basic auth returns 200")
        ; Verify session login with non-admin user
        Set tReq3 = ..CreateRequestNoCreds()
        Do tReq3.EntityBody.Write("{""name"":""" _ tTestUser _ """,""password"":""" _ tTestPass _ """}")
        Set tSC = tReq3.Post("/iris-couch/_session")
        Do $$$AssertStatusOK(tSC, "POST /_session with non-admin request completed")
        Do $$$AssertEquals(tReq3.HttpResponse.StatusCode, 200, "Non-admin session login returns 200")
        ; Parse session login response
        Set tBodyStr = tReq3.HttpResponse.Data.Read()
        Set tBody = ##class(%DynamicObject).%FromJSON(tBodyStr)
        Do $$$AssertTrue(tBody.ok, "Session login response has ok:true")
        Do $$$AssertEquals(tBody.name, tTestUser, "Session login response has correct name")
        ; Extract cookie from Set-Cookie header
        Set tSetCookie = tReq3.HttpResponse.GetHeader("SET-COOKIE")
        Do $$$AssertTrue(tSetCookie [ "AuthSession=", "Set-Cookie contains AuthSession")
        Set tCookiePart = $Piece(tSetCookie, ";", 1)
        Set tCookieVal = $Piece(tCookiePart, "=", 2, *)
        ; Verify cookie auth with non-admin user
        Set tReq4 = ..CreateRequestNoCreds()
        Do tReq4.SetHeader("Cookie", "AuthSession=" _ tCookieVal)
        Set tSC = tReq4.Get("/iris-couch/_session")
        Do $$$AssertStatusOK(tSC, "GET /_session with non-admin cookie request completed")
        Do $$$AssertEquals(tReq4.HttpResponse.StatusCode, 200, "Non-admin cookie auth returns 200")
        Set tBodyStr2 = tReq4.HttpResponse.Data.Read()
        Set tBody2 = ##class(%DynamicObject).%FromJSON(tBodyStr2)
        Do $$$AssertEquals(tBody2.userCtx.name, tTestUser, "Cookie auth returns correct non-admin username")
        Do $$$AssertEquals(tBody2.info.authenticated, "cookie", "Cookie auth method is cookie")
        ; Verify user has infrastructure roles
        Set tHasDBRole = 0
        Set tRoles = tBody2.userCtx.roles
        For tI = 0:1:(tRoles.%Size() - 1) {
            If tRoles.%Get(tI) = "%DB_IRISCOUCH" Set tHasDBRole = 1
        }
        Do $$$AssertTrue(tHasDBRole, "Non-admin user has %DB_IRISCOUCH role")
        Quit
    }
    Catch ex {
        Do $$$AssertTrue(0, "TestNonAdminUserAuth exception: " _ ex.DisplayString())
        Quit
    }
    ; Cleanup: delete test user doc and IRIS user
    Do ..CleanupTestUser(tTestUser)
}

/// <p>Helper: Clean up a test user created during non-admin auth testing.</p>
/// <p>Deletes and recreates the <code>_users</code> database to clear tombstones,
/// then deletes the IRIS user if it exists.</p>
ClassMethod CleanupTestUser(pUsername As %String)
{
    Try {
        ; Delete and recreate _users database to clear tombstones
        Set tReq = ..CreateRequest()
        Set tSC = tReq.Delete("/iris-couch/_users")
        Set tReq2 = ..CreateRequest()
        Set tSC = tReq2.Put("/iris-couch/_users")
        ; Delete IRIS user directly
        Set tOrigNS = $Namespace
        Set $Namespace = "%SYS"
        Set tExists = ""
        Do ##class(Security.Users).Exists(pUsername, .tExists)
        If tExists '= "" {
            Do ##class(Security.Users).Delete(pUsername)
        }
        Set $Namespace = tOrigNS
        Quit
    }
    Catch ex {
        If $Get(tOrigNS) '= "" Set $Namespace = tOrigNS
        Quit
    }
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

/// <p>Helper: Create an HTTP request with no credentials.</p>
ClassMethod CreateRequestNoCreds() As %Net.HttpRequest
{
    Set tReq = ##class(%Net.HttpRequest).%New()
    Set tReq.Server = "localhost"
    Set tReq.Port = 52773
    Set tReq.ContentType = "application/json"
    Quit tReq
}

/// <p>Helper: Login via POST /_session and extract the cookie value.</p>
ClassMethod LoginAndGetCookie() As %String
{
    Set tResult = ""
    Try {
        Set tReq = ..CreateRequestNoCreds()
        Do tReq.EntityBody.Write("{""name"":""_SYSTEM"",""password"":""SYS""}")
        Set tSC = tReq.Post("/iris-couch/_session")
        If $$$ISERR(tSC) Quit
        If tReq.HttpResponse.StatusCode '= 200 Quit
        ; Extract AuthSession value from Set-Cookie header
        Set tSetCookie = tReq.HttpResponse.GetHeader("SET-COOKIE")
        If tSetCookie = "" Quit
        ; Parse "AuthSession=<value>; ..."
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
