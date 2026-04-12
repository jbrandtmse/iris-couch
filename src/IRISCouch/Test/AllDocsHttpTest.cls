/// <p>HTTP integration tests for IRISCouch _all_docs and local_seq endpoints.</p>
/// <p>Tests <code>GET /{db}/_all_docs</code>, <code>POST /{db}/_all_docs</code>,
/// and <code>GET /{db}/{docid}?local_seq=true</code> via live HTTP requests.
/// Covers AC #1, #2, #3, #4, #5, #6.</p>
Class IRISCouch.Test.AllDocsHttpTest Extends %UnitTest.TestCase
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
    Kill ^IRISCouch.DB("testalldocshttp")
    Kill ^IRISCouch.Docs("testalldocshttp")
    Kill ^IRISCouch.Tree("testalldocshttp")
    Kill ^IRISCouch.Changes("testalldocshttp")
    Kill ^IRISCouch.Seq("testalldocshttp")
    ; Create test database
    Set tSC = ##class(IRISCouch.Storage.Database).Create("testalldocshttp")
    Quit tSC
}

/// <p>Delete test database and kill all globals after each test.</p>
Method OnAfterOneTest() As %Status
{
    Kill ^IRISCouch.DB("testalldocshttp")
    Kill ^IRISCouch.Docs("testalldocshttp")
    Kill ^IRISCouch.Tree("testalldocshttp")
    Kill ^IRISCouch.Changes("testalldocshttp")
    Kill ^IRISCouch.Seq("testalldocshttp")
    Quit $$$OK
}

/// <p>AC #1: GET /_all_docs returns 200 with total_rows, offset, rows sorted by id.</p>
Method TestAllDocsGetHttp()
{
    ; Create 2 docs
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testalldocshttp/beta", .tStatus, .tBody, "{""name"":""Beta""}")
    Do $$$AssertEquals(tStatus, 201, "Created doc beta")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testalldocshttp/alpha", .tStatus, .tBody, "{""name"":""Alpha""}")
    Do $$$AssertEquals(tStatus, 201, "Created doc alpha")
    ; GET _all_docs
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/testalldocshttp/_all_docs", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "GET /_all_docs request completed")
    Do $$$AssertEquals(tStatus, 200, "GET /_all_docs returns 200")
    Do $$$AssertTrue($IsObject(tBody), "Response is JSON object")
    Do $$$AssertEquals(tBody."total_rows", 2, "total_rows is 2")
    Do $$$AssertEquals(tBody.offset, 0, "offset is 0")
    Do $$$AssertTrue($IsObject(tBody.rows), "rows is present")
    Do $$$AssertEquals(tBody.rows.%Size(), 2, "2 rows returned")
    ; Verify sorted by id ascending
    Set tRow0 = tBody.rows.%Get(0)
    Set tRow1 = tBody.rows.%Get(1)
    Do $$$AssertEquals(tRow0.id, "alpha", "First row is alpha")
    Do $$$AssertEquals(tRow1.id, "beta", "Second row is beta")
    ; Verify row structure: id, key, value.rev
    Do $$$AssertEquals(tRow0.key, "alpha", "key equals id")
    Do $$$AssertTrue(tRow0.value.rev '= "", "value has rev")
}

/// <p>AC #2: GET /_all_docs?limit=1&skip=1 returns correct row.</p>
Method TestAllDocsLimitSkipHttp()
{
    ; Create 3 docs
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testalldocshttp/aaa", .tStatus, .tBody, "{""v"":1}")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testalldocshttp/bbb", .tStatus, .tBody, "{""v"":2}")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testalldocshttp/ccc", .tStatus, .tBody, "{""v"":3}")
    ; GET with limit=1&skip=1
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/testalldocshttp/_all_docs?limit=1&skip=1", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "GET with limit/skip completed")
    Do $$$AssertEquals(tStatus, 200, "Returns 200")
    Do $$$AssertEquals(tBody.rows.%Size(), 1, "1 row returned")
    Do $$$AssertEquals(tBody.rows.%Get(0).id, "bbb", "Skipped aaa, returned bbb")
    Do $$$AssertEquals(tBody."total_rows", 3, "total_rows still 3")
}

/// <p>AC #4: GET /_all_docs?include_docs=true returns full doc body.</p>
Method TestAllDocsIncludeDocsHttp()
{
    ; Create doc with known body
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testalldocshttp/mydoc", .tStatus, .tBody, "{""color"":""blue""}")
    Do $$$AssertEquals(tStatus, 201, "Created doc")
    ; GET with include_docs
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/testalldocshttp/_all_docs?include_docs=true", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "GET with include_docs completed")
    Do $$$AssertEquals(tStatus, 200, "Returns 200")
    Set tRow = tBody.rows.%Get(0)
    Do $$$AssertTrue($IsObject(tRow.doc), "Row has doc field")
    Do $$$AssertEquals(tRow.doc."_id", "mydoc", "doc has _id")
    Do $$$AssertTrue(tRow.doc."_rev" '= "", "doc has _rev")
    Do $$$AssertEquals(tRow.doc.color, "blue", "doc has body field color")
}

/// <p>AC #5: POST /_all_docs with keys returns matching rows and error for missing.</p>
Method TestAllDocsPostKeysHttp()
{
    ; Create 2 docs
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testalldocshttp/doc1", .tStatus, .tBody, "{""x"":1}")
    Do $$$AssertEquals(tStatus, 201, "Created doc1")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testalldocshttp/doc2", .tStatus, .tBody, "{""x"":2}")
    Do $$$AssertEquals(tStatus, 201, "Created doc2")
    ; POST with keys including a nonexistent doc
    Set tReqBody = "{""keys"":[""doc1"",""nonexistent""]}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("POST", "/testalldocshttp/_all_docs", .tStatus, .tBody, tReqBody)
    Do $$$AssertStatusOK(tSC, "POST /_all_docs completed")
    Do $$$AssertEquals(tStatus, 200, "Returns 200")
    Do $$$AssertEquals(tBody.rows.%Size(), 2, "2 rows returned")
    ; First row: found doc
    Set tRow0 = tBody.rows.%Get(0)
    Do $$$AssertEquals(tRow0.id, "doc1", "First row is doc1")
    Do $$$AssertTrue(tRow0.value.rev '= "", "doc1 has rev")
    ; Second row: not found
    Set tRow1 = tBody.rows.%Get(1)
    Do $$$AssertEquals(tRow1.key, "nonexistent", "Second row key is nonexistent")
    Do $$$AssertEquals(tRow1.error, "not_found", "Second row has error not_found")
}

/// <p>AC #3: GET /_all_docs?startkey=...&endkey=... returns key range.</p>
Method TestAllDocsKeyRangeHttp()
{
    ; Create 3 docs
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testalldocshttp/aaa", .tStatus, .tBody, "{""v"":1}")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testalldocshttp/bbb", .tStatus, .tBody, "{""v"":2}")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testalldocshttp/ccc", .tStatus, .tBody, "{""v"":3}")
    ; GET with key range — note: quotes are part of CouchDB convention but HTTP test sends them as-is
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/testalldocshttp/_all_docs?startkey=""aaa""&endkey=""bbb""", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "GET with key range completed")
    Do $$$AssertEquals(tStatus, 200, "Returns 200")
    Do $$$AssertEquals(tBody.rows.%Size(), 2, "2 rows in range aaa-bbb")
    Do $$$AssertEquals(tBody.rows.%Get(0).id, "aaa", "First row is aaa")
    Do $$$AssertEquals(tBody.rows.%Get(1).id, "bbb", "Second row is bbb")
}

/// <p>AC #6: GET /{db}/{docid}?local_seq=true returns _local_seq field.</p>
Method TestLocalSeqHttp()
{
    ; Create a document
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testalldocshttp/seqdoc", .tStatus, .tBody, "{""data"":""test""}")
    Do $$$AssertEquals(tStatus, 201, "Created doc seqdoc")
    ; GET with local_seq=true
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/testalldocshttp/seqdoc?local_seq=true", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "GET with local_seq completed")
    Do $$$AssertEquals(tStatus, 200, "Returns 200")
    Do $$$AssertEquals(tBody."_id", "seqdoc", "Response has _id")
    Do $$$AssertTrue(tBody."_local_seq" '= "", "Response has _local_seq field")
    ; _local_seq should be a sequence number (string representation)
    Do $$$AssertTrue(+tBody."_local_seq" > 0, "_local_seq is a positive number")
}

}
