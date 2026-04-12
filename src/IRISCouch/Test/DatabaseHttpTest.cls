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
    Kill ^IRISCouch.DB("alphadb")
    Kill ^IRISCouch.Seq("alphadb")
    Kill ^IRISCouch.DB("betadb")
    Kill ^IRISCouch.Seq("betadb")
    Kill ^IRISCouch.DB("gammadb")
    Kill ^IRISCouch.Seq("gammadb")
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

/// <p>AC #2: GET /_all_dbs returns 200 with empty array when no databases.</p>
Method TestAllDbsEmptyHttp()
{
    ; Clean all databases to ensure empty state
    Set tName = ""
    For {
        Set tName = $Order(^IRISCouch.DB(tName))
        Quit:tName=""
        Kill ^IRISCouch.DB(tName)
        Kill ^IRISCouch.Seq(tName)
    }
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/_all_dbs", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "GET /_all_dbs request completed successfully")
    Do $$$AssertEquals(tStatus, 200, "GET /_all_dbs returns HTTP 200")
    Do $$$AssertTrue($IsObject(tBody), "Response body is a JSON object")
    Do $$$AssertEquals(tBody.%Size(), 0, "Response body is empty array")
}

/// <p>AC #1: GET /_all_dbs returns 200 with sorted array of database names.</p>
Method TestAllDbsWithDatabasesHttp()
{
    ; Clean state
    Set tName = ""
    For {
        Set tName = $Order(^IRISCouch.DB(tName))
        Quit:tName=""
        Kill ^IRISCouch.DB(tName)
        Kill ^IRISCouch.Seq(tName)
    }
    ; Create databases in non-alphabetical order
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/gammadb", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 201, "PUT /gammadb returns 201")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/alphadb", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 201, "PUT /alphadb returns 201")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/betadb", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 201, "PUT /betadb returns 201")
    ; GET /_all_dbs
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/_all_dbs", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "GET /_all_dbs request completed successfully")
    Do $$$AssertEquals(tStatus, 200, "GET /_all_dbs returns HTTP 200")
    Do $$$AssertTrue($IsObject(tBody), "Response body is a JSON array")
    Do $$$AssertTrue(tBody.%Size() >= 3, "Response has at least 3 databases")
    Do $$$AssertEquals(tBody.%Get(0), "alphadb", "First database is alphadb (sorted)")
    Do $$$AssertEquals(tBody.%Get(1), "betadb", "Second database is betadb (sorted)")
    Do $$$AssertEquals(tBody.%Get(2), "gammadb", "Third database is gammadb (sorted)")
}

/// <p>AC #3: GET /{db} returns 200 with metadata fields for existing database.</p>
Method TestDatabaseInfoHttp()
{
    ; Ensure clean state and create database
    Kill ^IRISCouch.DB("testdbhttp")
    Kill ^IRISCouch.Seq("testdbhttp")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testdbhttp", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 201, "PUT /testdbhttp creates database")
    ; GET /testdbhttp
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/testdbhttp", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "GET /testdbhttp request completed successfully")
    Do $$$AssertEquals(tStatus, 200, "GET /testdbhttp returns HTTP 200")
    Do $$$AssertTrue($IsObject(tBody), "Response body is a JSON object")
    ; Verify all CouchDB metadata fields
    Do $$$AssertEquals(tBody."db_name", "testdbhttp", "db_name is testdbhttp")
    Do $$$AssertEquals(tBody."doc_count", 0, "doc_count is present")
    Do $$$AssertEquals(tBody."doc_del_count", 0, "doc_del_count is present")
    Do $$$AssertTrue(tBody.%IsDefined("update_seq"), "update_seq field exists")
    Do $$$AssertTrue(tBody.%IsDefined("purge_seq"), "purge_seq field exists")
    Do $$$AssertTrue(tBody.%IsDefined("compact_running"), "compact_running field exists")
    Do $$$AssertTrue(tBody.%IsDefined("disk_size"), "disk_size field exists")
    Do $$$AssertTrue(tBody.%IsDefined("data_size"), "data_size field exists")
    Do $$$AssertEquals(tBody."instance_start_time", "0", "instance_start_time is 0")
    Do $$$AssertEquals(tBody."disk_format_version", 1, "disk_format_version is 1")
    Do $$$AssertTrue(tBody.%IsDefined("committed_update_seq"), "committed_update_seq field exists")
}

/// <p>AC #4: GET /{db} returns 404 for non-existent database.</p>
Method TestDatabaseInfoNotFoundHttp()
{
    ; Ensure database does not exist
    Kill ^IRISCouch.DB("nonexistentdb")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/nonexistentdb", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "GET /nonexistentdb request completed successfully")
    Do $$$AssertEquals(tStatus, 404, "GET /nonexistentdb returns HTTP 404")
    Do $$$AssertTrue($IsObject(tBody), "Response body is a JSON object")
    Do $$$AssertEquals(tBody.error, "not_found", "Error slug is not_found")
}

}
