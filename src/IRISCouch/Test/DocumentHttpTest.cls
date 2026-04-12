/// <p>HTTP integration tests for IRISCouch document endpoints.</p>
/// <p>Tests <code>POST /{db}</code>, <code>PUT /{db}/{docid}</code>,
/// and <code>GET /{db}/{docid}</code> via live HTTP requests.
/// Covers AC #1, #2, #3, #4.</p>
Class IRISCouch.Test.DocumentHttpTest Extends %UnitTest.TestCase
{

/// <p>Handle initvalue parameter from parent class.</p>
Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Quit $$$OK
}

/// <p>Create a test database before each test.</p>
Method OnBeforeOneTest() As %Status
{
    ; Clean up any previous state
    Kill ^IRISCouch.DB("testdochttp")
    Kill ^IRISCouch.Docs("testdochttp")
    Kill ^IRISCouch.Tree("testdochttp")
    Kill ^IRISCouch.Changes("testdochttp")
    Kill ^IRISCouch.Seq("testdochttp")
    ; Create test database
    Set tSC = ##class(IRISCouch.Storage.Database).Create("testdochttp")
    Quit tSC
}

/// <p>Delete test database and kill all globals after each test.</p>
Method OnAfterOneTest() As %Status
{
    Kill ^IRISCouch.DB("testdochttp")
    Kill ^IRISCouch.Docs("testdochttp")
    Kill ^IRISCouch.Tree("testdochttp")
    Kill ^IRISCouch.Changes("testdochttp")
    Kill ^IRISCouch.Seq("testdochttp")
    Quit $$$OK
}

/// <p>AC #1: POST /{db} with JSON body returns 201, response has ok/id/rev, GET by id returns 200.</p>
Method TestPostDocument()
{
    Set tReqBody = "{""name"":""Alice"",""age"":30}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("POST", "/testdochttp", .tStatus, .tBody, tReqBody)
    Do $$$AssertStatusOK(tSC, "POST /testdochttp request completed")
    Do $$$AssertEquals(tStatus, 201, "POST /testdochttp returns HTTP 201")
    Do $$$AssertTrue($IsObject(tBody), "Response is a JSON object")
    Do $$$AssertTrue(tBody.ok, "Response has ok: true")
    Do $$$AssertTrue(tBody.id '= "", "Response has non-empty id")
    Do $$$AssertTrue(tBody.rev '= "", "Response has non-empty rev")
    ; Verify starts with 1-
    Do $$$AssertEquals($Piece(tBody.rev, "-", 1), 1, "Rev starts with generation 1")
    ; GET the created document
    Set tDocId = tBody.id
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/testdochttp/" _ tDocId, .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "GET created doc request completed")
    Do $$$AssertEquals(tStatus, 200, "GET created doc returns HTTP 200")
}

/// <p>AC #2: PUT /{db}/mydoc with JSON body (no _rev) returns 201, response has ok/id/rev.</p>
Method TestPutNewDocument()
{
    Set tReqBody = "{""title"":""Hello World""}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testdochttp/mydoc", .tStatus, .tBody, tReqBody)
    Do $$$AssertStatusOK(tSC, "PUT /testdochttp/mydoc request completed")
    Do $$$AssertEquals(tStatus, 201, "PUT /testdochttp/mydoc returns HTTP 201")
    Do $$$AssertTrue($IsObject(tBody), "Response is a JSON object")
    Do $$$AssertTrue(tBody.ok, "Response has ok: true")
    Do $$$AssertEquals(tBody.id, "mydoc", "Response id is mydoc")
    Do $$$AssertTrue(tBody.rev '= "", "Response has non-empty rev")
    Do $$$AssertEquals($Piece(tBody.rev, "-", 1), 1, "Rev starts with generation 1")
}

/// <p>AC #3: Create doc, then GET returns 200 with _id, _rev, and body fields.</p>
Method TestGetDocument()
{
    ; Create doc first
    Set tReqBody = "{""color"":""blue"",""count"":42}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testdochttp/getdoc", .tStatus, .tBody, tReqBody)
    Do $$$AssertEquals(tStatus, 201, "PUT creates document")
    Set tCreatedRev = tBody.rev
    ; GET the document
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/testdochttp/getdoc", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "GET /testdochttp/getdoc request completed")
    Do $$$AssertEquals(tStatus, 200, "GET /testdochttp/getdoc returns HTTP 200")
    Do $$$AssertTrue($IsObject(tBody), "Response is a JSON object")
    Do $$$AssertEquals(tBody."_id", "getdoc", "Response has _id field")
    Do $$$AssertEquals(tBody."_rev", tCreatedRev, "Response has _rev matching created rev")
    Do $$$AssertEquals(tBody.color, "blue", "Response has body field color")
    Do $$$AssertEquals(tBody.count, 42, "Response has body field count")
}

/// <p>AC #4: Create doc, GET with specific rev returns 200.</p>
Method TestGetDocumentSpecificRev()
{
    ; Create doc
    Set tReqBody = "{""item"":""pen""}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testdochttp/revdoc", .tStatus, .tBody, tReqBody)
    Do $$$AssertEquals(tStatus, 201, "PUT creates document")
    Set tRev = tBody.rev
    ; GET with ?rev= parameter
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/testdochttp/revdoc?rev=" _ tRev, .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "GET with ?rev= request completed")
    Do $$$AssertEquals(tStatus, 200, "GET with ?rev= returns HTTP 200")
    Do $$$AssertEquals(tBody."_rev", tRev, "Response _rev matches requested rev")
}

/// <p>AC #3: GET non-existent document returns 404 not_found.</p>
Method TestGetDocumentNotFound()
{
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/testdochttp/nonexistent", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "GET nonexistent doc request completed")
    Do $$$AssertEquals(tStatus, 404, "GET nonexistent doc returns HTTP 404")
    Do $$$AssertTrue($IsObject(tBody), "Response is a JSON object")
    Do $$$AssertEquals(tBody.error, "not_found", "Error slug is not_found")
}

/// <p>AC #4: GET with non-existent rev returns 404.</p>
Method TestGetDocumentMissingRev()
{
    ; Create doc first
    Set tReqBody = "{""x"":1}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testdochttp/revmiss", .tStatus, .tBody, tReqBody)
    Do $$$AssertEquals(tStatus, 201, "PUT creates document")
    ; GET with bad rev
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/testdochttp/revmiss?rev=99-bad", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "GET with bad rev request completed")
    Do $$$AssertEquals(tStatus, 404, "GET with bad rev returns HTTP 404")
    Do $$$AssertEquals(tBody.error, "not_found", "Error slug is not_found")
}

/// <p>AC #1: POST to non-existent database returns 404.</p>
Method TestPostDocumentNoDb()
{
    ; Ensure nonexistent db doesn't exist
    Kill ^IRISCouch.DB("nonexistentdb")
    Set tReqBody = "{""x"":1}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("POST", "/nonexistentdb", .tStatus, .tBody, tReqBody)
    Do $$$AssertStatusOK(tSC, "POST to nonexistent db request completed")
    Do $$$AssertEquals(tStatus, 404, "POST to nonexistent db returns HTTP 404")
    Do $$$AssertEquals(tBody.error, "not_found", "Error slug is not_found")
}

}
