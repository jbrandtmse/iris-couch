/// <p>HTTP integration tests for Mango index management endpoints.</p>
/// <p>Tests POST, GET, DELETE /{db}/_index via live HTTP requests.</p>
Class IRISCouch.Test.MangoIndexHttpTest Extends %UnitTest.TestCase
{

/// <p>Handle initvalue parameter from parent class.</p>
Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Quit $$$OK
}

/// <p>Create test database via HTTP before each test.</p>
Method OnBeforeOneTest() As %Status
{
    ; Delete if exists, then create
    Do ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("DELETE", "/testmangoidx", .tSC2, .tBody2)
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testmangoidx", .tStatus, .tBody)
    Quit $$$OK
}

/// <p>Clean up test database after each test.</p>
Method OnAfterOneTest() As %Status
{
    Do ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("DELETE", "/testmangoidx", .tStatus, .tBody)
    Quit $$$OK
}

/// <p>Test POST /{db}/_index creates an index and returns 200.</p>
Method TestPostIndex()
{
    Set tReqBody = "{""index"":{""fields"":[""type"",""date""]},""name"":""idx-type-date"",""ddoc"":""my-indexes""}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("POST", "/testmangoidx/_index", .tStatus, .tBody, tReqBody)
    Do $$$AssertStatusOK(tSC, "POST /_index request completed")
    Do $$$AssertEquals(tStatus, 200, "POST /_index returns 200")
    Do $$$AssertTrue($IsObject(tBody), "Response is JSON object")
    Do $$$AssertEquals(tBody.result, "created", "Result is created")
    Do $$$AssertEquals(tBody.id, "_design/my-indexes", "Design doc ID correct")
    Do $$$AssertEquals(tBody.name, "idx-type-date", "Index name correct")
}

/// <p>Test POST /{db}/_index with same definition returns "exists".</p>
Method TestPostIndexIdempotent()
{
    Set tReqBody = "{""index"":{""fields"":[""type""]},""name"":""idx1"",""ddoc"":""my-idx""}"
    Do ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("POST", "/testmangoidx/_index", .tStatus, .tBody, tReqBody)
    Do $$$AssertEquals(tBody.result, "created", "First create returns created")
    ; Post same definition again
    Do ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("POST", "/testmangoidx/_index", .tStatus2, .tBody2, tReqBody)
    Do $$$AssertEquals(tStatus2, 200, "Second POST returns 200")
    Do $$$AssertEquals(tBody2.result, "exists", "Second POST returns exists")
}

/// <p>Test GET /{db}/_index returns _all_docs plus user indexes.</p>
Method TestGetIndexes()
{
    ; Create an index first
    Set tReqBody = "{""index"":{""fields"":[""type""]},""name"":""idx1"",""ddoc"":""my-idx""}"
    Do ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("POST", "/testmangoidx/_index", .tS, .tB, tReqBody)
    ; List indexes
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/testmangoidx/_index", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "GET /_index request completed")
    Do $$$AssertEquals(tStatus, 200, "GET /_index returns 200")
    Do $$$AssertTrue($IsObject(tBody), "Response is JSON object")
    Do $$$AssertTrue(tBody."total_rows" >= 2, "At least 2 indexes (including _all_docs)")
    ; Check first index is _all_docs
    Set tFirst = tBody.indexes.%Get(0)
    Do $$$AssertEquals(tFirst.name, "_all_docs", "First index is _all_docs")
    Do $$$AssertEquals(tFirst.type, "special", "First index type is special")
}

/// <p>Test DELETE /{db}/_index/{ddoc}/json/{name} returns 200.</p>
Method TestDeleteIndex()
{
    ; Create an index first
    Set tReqBody = "{""index"":{""fields"":[""type""]},""name"":""idx1"",""ddoc"":""my-idx""}"
    Do ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("POST", "/testmangoidx/_index", .tS, .tB, tReqBody)
    ; Delete it
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("DELETE", "/testmangoidx/_index/my-idx/json/idx1", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "DELETE /_index request completed")
    Do $$$AssertEquals(tStatus, 200, "DELETE /_index returns 200")
    Do $$$AssertTrue(tBody.ok = 1, "Response has ok:true")
    ; Verify it's gone from list
    Do ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/testmangoidx/_index", .tListStatus, .tListBody)
    Do $$$AssertEquals(tListBody."total_rows", 1, "Only _all_docs remains after delete")
}

/// <p>Test DELETE non-existent index returns 404.</p>
Method TestDeleteIndexNotFound()
{
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("DELETE", "/testmangoidx/_index/nope/json/nope", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "DELETE request completed")
    Do $$$AssertEquals(tStatus, 404, "DELETE non-existent returns 404")
}

/// <p>Test validation errors return 400.</p>
Method TestPostIndexValidationErrors()
{
    ; Missing index field
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("POST", "/testmangoidx/_index", .tStatus, .tBody, "{}")
    Do $$$AssertEquals(tStatus, 400, "Missing index field returns 400")
    ; Empty fields array
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("POST", "/testmangoidx/_index", .tStatus2, .tBody2, "{""index"":{""fields"":[]}}")
    Do $$$AssertEquals(tStatus2, 400, "Empty fields returns 400")
    ; Unknown key
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("POST", "/testmangoidx/_index", .tStatus3, .tBody3, "{""index"":{""fields"":[""x""]},""bogus"":1}")
    Do $$$AssertEquals(tStatus3, 400, "Unknown key returns 400")
    ; Invalid type
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("POST", "/testmangoidx/_index", .tStatus4, .tBody4, "{""index"":{""fields"":[""x""]},""type"":""text""}")
    Do $$$AssertEquals(tStatus4, 400, "Invalid type returns 400")
}

/// <p>Test index backfill: create docs first, then create index, verify MangoIndex rows populated.</p>
Method TestIndexBackfillOnCreate()
{
    ; Create some documents
    Do ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testmangoidx/doc1", .tS, .tB, "{""type"":""order"",""total"":10}")
    Do ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testmangoidx/doc2", .tS2, .tB2, "{""type"":""invoice"",""total"":20}")
    ; Now create an index on type field
    Set tReqBody = "{""index"":{""fields"":[""type""]},""name"":""idx-type"",""ddoc"":""backfill-test""}"
    Do ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("POST", "/testmangoidx/_index", .tStatus, .tBody, tReqBody)
    Do $$$AssertEquals(tBody.result, "created", "Index created")
    ; Verify MangoIndex rows exist for both docs
    &sql(SELECT COUNT(*) INTO :tCount FROM IRISCouch_Projection.MangoIndex WHERE DbName = 'testmangoidx' AND IndexName = 'idx-type')
    Do $$$AssertTrue(tCount >= 2, "MangoIndex rows backfilled for existing documents")
}

/// <p>Test projection updated when writing a document after index creation.</p>
Method TestProjectionUpdatedOnDocWrite()
{
    ; Create an index first
    Set tReqBody = "{""index"":{""fields"":[""type""]},""name"":""idx-w"",""ddoc"":""write-test""}"
    Do ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("POST", "/testmangoidx/_index", .tS, .tB, tReqBody)
    ; Now write a document
    Do ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testmangoidx/wdoc1", .tStatus, .tBody, "{""type"":""order""}")
    Do $$$AssertEquals(tStatus, 201, "Document created")
    ; Verify MangoIndex row exists
    &sql(SELECT COUNT(*) INTO :tCount FROM IRISCouch_Projection.MangoIndex WHERE DbName = 'testmangoidx' AND DocId = 'wdoc1' AND IndexName = 'idx-w')
    Do $$$AssertTrue(tCount > 0, "MangoIndex row created on document write")
    ; Verify Winners row exists
    Set tWinBody = ##class(IRISCouch.Projection.Winners).GetBody("testmangoidx", "wdoc1")
    Do $$$AssertTrue(tWinBody '= "", "Winners row populated")
}

/// <p>Test projection cleaned on document delete.</p>
Method TestProjectionCleanedOnDocDelete()
{
    ; Create index and document
    Set tReqBody = "{""index"":{""fields"":[""type""]},""name"":""idx-d"",""ddoc"":""del-test""}"
    Do ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("POST", "/testmangoidx/_index", .tS, .tB, tReqBody)
    Do ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testmangoidx/ddoc1", .tStatus, .tBody, "{""type"":""order""}")
    Set tRev = tBody.rev
    Do $$$AssertTrue(tRev '= "", "Got rev from PUT")
    ; Delete the document
    Set tDelPath = "/testmangoidx/ddoc1?rev=" _ tRev
    Do ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("DELETE", tDelPath, .tDelStatus, .tDelBody)
    Do $$$AssertEquals(tDelStatus, 200, "Document deleted")
    ; Verify MangoIndex rows removed
    &sql(SELECT COUNT(*) INTO :tCount FROM IRISCouch_Projection.MangoIndex WHERE DbName = 'testmangoidx' AND DocId = 'ddoc1')
    Do $$$AssertEquals(tCount, 0, "MangoIndex rows removed after doc delete")
}

}
