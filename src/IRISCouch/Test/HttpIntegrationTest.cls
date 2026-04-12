/// <p>HTTP integration tests for IRISCouch REST API.</p>
/// <p>Uses <class>%Net.HttpRequest</class> to make live HTTP requests against
/// the running webapp at <code>/iris-couch/</code>. Validates end-to-end
/// request/response behavior including routing, serialization, and error handling.</p>
/// <p>These tests require a running IRIS instance with the IRISCouch webapp configured.</p>
Class IRISCouch.Test.HttpIntegrationTest Extends %UnitTest.TestCase
{

/// <p>Handle initvalue parameter from parent class.</p>
Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Quit $$$OK
}

/// <p>Make an HTTP request to the IRISCouch webapp and return the response.</p>
/// <p>This is a reusable helper that other test classes can invoke to make
/// HTTP requests and parse JSON responses. Handles authentication and
/// path prefix automatically.</p>
/// @param pMethod HTTP method (GET, PUT, POST, DELETE)
/// @param pPath Request path relative to webapp root (e.g., "/" or "/_uuids")
/// @param pStatusCode Output: HTTP status code from response
/// @param pBody Output: Parsed JSON response body as %DynamicObject
/// @return %Status indicating transport-level success/failure
ClassMethod MakeRequest(pMethod As %String, pPath As %String, Output pStatusCode As %Integer, Output pBody As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pStatusCode = 0
    Set pBody = ""
    Try {
        Set tReq = ##class(%Net.HttpRequest).%New()
        Set tReq.Server = "localhost"
        Set tReq.Port = 52773
        Set tReq.Username = "_SYSTEM"
        Set tReq.Password = "SYS"
        Set tReq.ContentType = "application/json"
        ; Build full path with webapp prefix
        Set tFullPath = "/iris-couch" _ pPath
        If pMethod = "GET" {
            Set tSC = tReq.Get(tFullPath)
        } ElseIf pMethod = "PUT" {
            Set tSC = tReq.Put(tFullPath)
        } ElseIf pMethod = "DELETE" {
            Set tSC = tReq.Delete(tFullPath)
        } ElseIf pMethod = "POST" {
            Set tSC = tReq.Post(tFullPath)
        } Else {
            Set tSC = $$$ERROR($$$GeneralError, "Unsupported HTTP method: " _ pMethod)
        }
        If $$$ISERR(tSC) Quit
        Set pStatusCode = tReq.HttpResponse.StatusCode
        Set tBodyStr = tReq.HttpResponse.Data.Read()
        If tBodyStr '= "" {
            Set pBody = ##class(%DynamicObject).%FromJSON(tBodyStr)
        }
        Quit
    }
    Catch ex {
        Set tSC = ex.AsStatus()
        Quit
    }
    Quit tSC
}

/// <p>Verify GET / returns 200 with CouchDB-compatible welcome response.</p>
/// <p>AC #4: HTTP request to GET /iris-couch/ returns status 200 and a
/// JSON body with "couchdb": "Welcome".</p>
Method TestWelcomeEndpoint()
{
    Set tSC = ..MakeRequest("GET", "/", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "GET / request completed successfully")
    Do $$$AssertEquals(tStatus, 200, "GET / returns HTTP 200")
    Do $$$AssertTrue($IsObject(tBody), "Response body is a JSON object")
    Do $$$AssertEquals(tBody.couchdb, "Welcome", "Response contains couchdb: Welcome")
    Do $$$AssertTrue(tBody.version '= "", "Response contains a version string")
    Do $$$AssertTrue($IsObject(tBody.vendor), "Response contains vendor object")
}

/// <p>Verify GET /_uuids returns 200 with a uuids array.</p>
/// <p>Validates the UUID generation endpoint returns properly formatted UUIDs.</p>
Method TestUUIDsEndpoint()
{
    Set tSC = ..MakeRequest("GET", "/_uuids", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "GET /_uuids request completed successfully")
    Do $$$AssertEquals(tStatus, 200, "GET /_uuids returns HTTP 200")
    Do $$$AssertTrue($IsObject(tBody), "Response body is a JSON object")
    Do $$$AssertTrue($IsObject(tBody.uuids), "Response contains uuids field")
    Do $$$AssertEquals(tBody.uuids.%Size(), 1, "Default count returns 1 UUID")
    ; Verify UUID format: 32 hex characters
    Set tUUID = tBody.uuids.%Get(0)
    Do $$$AssertEquals($Length(tUUID), 32, "UUID is 32 characters long")
}

/// <p>Verify GET /nonexistent returns 404 with not_found error.</p>
/// <p>Validates that unmatched routes return proper CouchDB-compatible error envelopes.</p>
Method TestNotFoundEndpoint()
{
    Set tSC = ..MakeRequest("GET", "/nonexistent", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "GET /nonexistent request completed successfully")
    Do $$$AssertEquals(tStatus, 404, "GET /nonexistent returns HTTP 404")
    Do $$$AssertTrue($IsObject(tBody), "Response body is a JSON object")
    Do $$$AssertEquals(tBody.error, "not_found", "Error slug is not_found")
}

/// <p>Verify parameterized route pattern does not break routing.</p>
/// <p>Confirms that a request to a database-like path (e.g., /testdb123)
/// returns 404 since no database handler exists yet, validating that
/// the :db capture pattern does not cause routing errors.</p>
Method TestParameterizedRoutePattern()
{
    Set tSC = ..MakeRequest("GET", "/testdb123", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "GET /testdb123 request completed successfully")
    Do $$$AssertEquals(tStatus, 404, "GET /testdb123 returns HTTP 404 (no db handler yet)")
    Do $$$AssertTrue($IsObject(tBody), "Response body is a JSON object")
    Do $$$AssertEquals(tBody.error, "not_found", "Error slug is not_found for unhandled db route")
}

}
