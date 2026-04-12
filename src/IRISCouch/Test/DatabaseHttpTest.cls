/// <p>HTTP integration tests for IRISCouch database endpoints.</p>
/// <p>Tests <code>PUT /{db}</code> and <code>DELETE /{db}</code> via live
/// HTTP requests. Validates end-to-end behavior including routing,
/// error responses, and name validation. Covers AC #1, #2, #3, #4, #5.</p>
Class IRISCouch.Test.DatabaseHttpTest Extends %UnitTest.TestCase
{

/// <p>Handle initvalue parameter from parent class.</p>
Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Quit $$$OK
}

/// <p>Clean up test database globals after each test.</p>
Method OnAfterOneTest() As %Status
{
    ; Clean up any test databases created during tests
    Kill ^IRISCouch.DB("testdbhttp")
    Kill ^IRISCouch.Docs("testdbhttp")
    Kill ^IRISCouch.Tree("testdbhttp")
    Kill ^IRISCouch.Changes("testdbhttp")
    Kill ^IRISCouch.Seq("testdbhttp")
    Quit $$$OK
}

/// <p>AC #1: PUT /testdbhttp creates database, returns 201 with ok:true.</p>
Method TestCreateDatabaseHttp()
{
    ; Ensure clean state
    Kill ^IRISCouch.DB("testdbhttp")
    Kill ^IRISCouch.Seq("testdbhttp")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testdbhttp", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "PUT /testdbhttp request completed successfully")
    Do $$$AssertEquals(tStatus, 201, "PUT /testdbhttp returns HTTP 201")
    Do $$$AssertTrue($IsObject(tBody), "Response body is a JSON object")
    Do $$$AssertTrue(tBody.ok, "Response body contains ok: true")
}

/// <p>AC #2: Second PUT returns 412 with file_exists error.</p>
Method TestCreateDatabaseAlreadyExistsHttp()
{
    ; Ensure clean state and create first
    Kill ^IRISCouch.DB("testdbhttp")
    Kill ^IRISCouch.Seq("testdbhttp")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testdbhttp", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 201, "First PUT returns 201")
    ; Second PUT should return 412
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testdbhttp", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "Second PUT request completed successfully")
    Do $$$AssertEquals(tStatus, 412, "Second PUT returns HTTP 412")
    Do $$$AssertTrue($IsObject(tBody), "Response body is a JSON object")
    Do $$$AssertEquals(tBody.error, "file_exists", "Error slug is file_exists")
}

/// <p>AC #3: DELETE /testdbhttp returns 200 with ok:true.</p>
Method TestDeleteDatabaseHttp()
{
    ; Ensure clean state and create first
    Kill ^IRISCouch.DB("testdbhttp")
    Kill ^IRISCouch.Seq("testdbhttp")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testdbhttp", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 201, "PUT creates database for delete test")
    ; Now delete
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("DELETE", "/testdbhttp", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "DELETE /testdbhttp request completed successfully")
    Do $$$AssertEquals(tStatus, 200, "DELETE /testdbhttp returns HTTP 200")
    Do $$$AssertTrue($IsObject(tBody), "Response body is a JSON object")
    Do $$$AssertTrue(tBody.ok, "Response body contains ok: true")
}

/// <p>AC #4: DELETE non-existent returns 404 with not_found error.</p>
Method TestDeleteDatabaseNotFoundHttp()
{
    ; Ensure database does not exist
    Kill ^IRISCouch.DB("testdbhttp")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("DELETE", "/testdbhttp", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "DELETE non-existent request completed successfully")
    Do $$$AssertEquals(tStatus, 404, "DELETE non-existent returns HTTP 404")
    Do $$$AssertTrue($IsObject(tBody), "Response body is a JSON object")
    Do $$$AssertEquals(tBody.error, "not_found", "Error slug is not_found")
}

/// <p>AC #5: PUT with invalid name returns 400 with illegal_database_name.</p>
Method TestInvalidDatabaseNameHttp()
{
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/UPPERCASE", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "PUT /UPPERCASE request completed successfully")
    Do $$$AssertEquals(tStatus, 400, "PUT /UPPERCASE returns HTTP 400")
    Do $$$AssertTrue($IsObject(tBody), "Response body is a JSON object")
    Do $$$AssertEquals(tBody.error, "illegal_database_name", "Error slug is illegal_database_name")
}

}
