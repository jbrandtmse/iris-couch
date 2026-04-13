/// <p>HTTP integration tests for Mango _find and _explain endpoints.</p>
/// <p>Tests POST /{db}/_find and POST /{db}/_explain via live HTTP requests
/// against the running webapp. Validates routing, response format, field projection,
/// sorting, pagination, bookmarks, execution stats, and zero staleness.</p>
Class IRISCouch.Test.MangoQueryHttpTest Extends %UnitTest.TestCase
{

/// <p>Handle initvalue parameter from parent class.</p>
Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Quit $$$OK
}

/// <p>Create test database and seed documents once for all tests.</p>
Method OnBeforeAllTests() As %Status
{
    ; Create database via HTTP
    Do ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testmfdb", .tStatus, .tBody)
    ; Seed documents via HTTP POST
    Do ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("POST", "/testmfdb", .tS, .tB, "{""_id"":""doc1"",""type"":""order"",""total"":100,""status"":""active""}")
    Do ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("POST", "/testmfdb", .tS, .tB, "{""_id"":""doc2"",""type"":""order"",""total"":200,""status"":""pending""}")
    Do ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("POST", "/testmfdb", .tS, .tB, "{""_id"":""doc3"",""type"":""invoice"",""total"":300,""status"":""active""}")
    Do ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("POST", "/testmfdb", .tS, .tB, "{""_id"":""doc4"",""type"":""order"",""total"":50,""status"":""closed""}")
    Do ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("POST", "/testmfdb", .tS, .tB, "{""_id"":""doc5"",""type"":""invoice"",""total"":150,""status"":""active""}")
    Quit $$$OK
}

/// <p>Clean up after all tests.</p>
Method OnAfterAllTests() As %Status
{
    Do ##class(IRISCouch.Projection.Winners).DeleteAll("testmfdb")
    Do ##class(IRISCouch.Projection.MangoIndex).DeleteAll("testmfdb")
    Do ##class(IRISCouch.Projection.MangoIndexDef).DeleteAll("testmfdb")
    Do ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("DELETE", "/testmfdb", .tS, .tB)
    Quit $$$OK
}

/// <p>Test POST /{db}/_find returns 200 with docs array.</p>
Method TestPostFind()
{
    Set tReqBody = "{""selector"":{""type"":""order""}}"
    Do ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("POST", "/testmfdb/_find", .tStatus, .tBody, tReqBody)
    Do $$$AssertEquals(tStatus, 200, "POST _find returns 200")
    Do $$$AssertTrue($IsObject(tBody), "Response is JSON object")
    Do $$$AssertTrue($IsObject(tBody.%Get("docs")), "Response has docs array")
    Set tDocs = tBody.%Get("docs")
    Do $$$AssertEquals(tDocs.%Size(), 3, "3 order documents returned")
}

/// <p>Test POST /{db}/_find with index.</p>
Method TestPostFindWithIndex()
{
    ; Create an index
    Set tIdxBody = "{""index"":{""fields"":[""type""]},""ddoc"":""my-idx"",""name"":""idx-type""}"
    Do ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("POST", "/testmfdb/_index", .tS, .tB, tIdxBody)
    ; Query using the index
    Set tReqBody = "{""selector"":{""type"":""order""},""use_index"":""_design/my-idx""}"
    Do ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("POST", "/testmfdb/_find", .tStatus, .tBody, tReqBody)
    Do $$$AssertEquals(tStatus, 200, "POST _find with index returns 200")
    Set tDocs = tBody.%Get("docs")
    Do $$$AssertTrue(tDocs.%Size() > 0, "Docs returned when using index")
}

/// <p>Test POST /{db}/_find full scan shows warning.</p>
Method TestPostFindFullScan()
{
    Set tReqBody = "{""selector"":{""status"":""active""}}"
    Do ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("POST", "/testmfdb/_find", .tStatus, .tBody, tReqBody)
    Do $$$AssertEquals(tStatus, 200, "POST _find full scan returns 200")
    Do $$$AssertTrue(tBody.%IsDefined("warning"), "Warning field present for full scan")
}

/// <p>Test POST /{db}/_find with field projection.</p>
Method TestPostFindFieldProjection()
{
    Set tReqBody = "{""selector"":{""type"":""order""},""fields"":[""_id"",""total""]}"
    Do ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("POST", "/testmfdb/_find", .tStatus, .tBody, tReqBody)
    Do $$$AssertEquals(tStatus, 200, "Field projection returns 200")
    Set tDocs = tBody.%Get("docs")
    Do $$$AssertTrue(tDocs.%Size() > 0, "Has docs")
    Set tFirst = tDocs.%Get(0)
    Do $$$AssertTrue(tFirst.%IsDefined("_id"), "Has _id")
    Do $$$AssertTrue(tFirst.%IsDefined("total"), "Has total")
    Do $$$AssertTrue('tFirst.%IsDefined("status"), "No status field")
}

/// <p>Test POST /{db}/_find with sort and limit.</p>
Method TestPostFindSortAndLimit()
{
    Set tReqBody = "{""selector"":{""type"":""order""},""sort"":[{""total"":""asc""}],""limit"":2}"
    Do ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("POST", "/testmfdb/_find", .tStatus, .tBody, tReqBody)
    Do $$$AssertEquals(tStatus, 200, "Sort and limit returns 200")
    Set tDocs = tBody.%Get("docs")
    Do $$$AssertEquals(tDocs.%Size(), 2, "Limit 2 returns 2 docs")
    Set tFirst = tDocs.%Get(0)
    Set tSecond = tDocs.%Get(1)
    Do $$$AssertTrue(tFirst.%Get("total") <= tSecond.%Get("total"), "Docs sorted ascending by total")
}

/// <p>Test bookmark-based pagination across 2 requests.</p>
Method TestPostFindBookmark()
{
    Set tReqBody = "{""selector"":{},""limit"":2}"
    Do ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("POST", "/testmfdb/_find", .tStatus, .tBody, tReqBody)
    Do $$$AssertEquals(tStatus, 200, "First page returns 200")
    Set tDocs1 = tBody.%Get("docs")
    Do $$$AssertEquals(tDocs1.%Size(), 2, "First page has 2 docs")
    Set tBookmark = tBody.%Get("bookmark")
    Do $$$AssertTrue((tBookmark '= "") && (tBookmark '= "nil"), "Bookmark present")
    ; Second page using bookmark
    Set tReqBody2 = "{""selector"":{},""limit"":2,""bookmark"":""" _ tBookmark _ """}"
    Do ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("POST", "/testmfdb/_find", .tStatus2, .tBody2, tReqBody2)
    Do $$$AssertEquals(tStatus2, 200, "Second page returns 200")
    Set tDocs2 = tBody2.%Get("docs")
    Do $$$AssertTrue(tDocs2.%Size() > 0, "Second page has docs")
}

/// <p>Test execution_stats in response when requested.</p>
Method TestPostFindExecutionStats()
{
    Set tReqBody = "{""selector"":{""type"":""order""},""execution_stats"":true}"
    Do ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("POST", "/testmfdb/_find", .tStatus, .tBody, tReqBody)
    Do $$$AssertEquals(tStatus, 200, "Execution stats returns 200")
    Set tStats = tBody.%Get("execution_stats")
    Do $$$AssertTrue($IsObject(tStats), "execution_stats present")
    Do $$$AssertTrue(tStats.%IsDefined("total_docs_examined"), "Has total_docs_examined")
    Do $$$AssertTrue(tStats.%IsDefined("results_returned"), "Has results_returned")
    Do $$$AssertTrue(tStats.%IsDefined("execution_time_ms"), "Has execution_time_ms")
}

/// <p>Test POST /{db}/_find missing selector returns 400.</p>
Method TestPostFindMissingSelector()
{
    Set tReqBody = "{""limit"":10}"
    Do ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("POST", "/testmfdb/_find", .tStatus, .tBody, tReqBody)
    Do $$$AssertEquals(tStatus, 400, "Missing selector returns 400")
    Do $$$AssertEquals(tBody.%Get("error"), "bad_request", "Error slug is bad_request")
}

/// <p>Test POST /{db}/_explain returns query plan.</p>
Method TestPostExplain()
{
    Set tReqBody = "{""selector"":{""type"":""order""}}"
    Do ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("POST", "/testmfdb/_explain", .tStatus, .tBody, tReqBody)
    Do $$$AssertEquals(tStatus, 200, "POST _explain returns 200")
    Do $$$AssertTrue(tBody.%IsDefined("dbname"), "Response has dbname")
    Do $$$AssertTrue(tBody.%IsDefined("index"), "Response has index")
    Do $$$AssertTrue(tBody.%IsDefined("selector"), "Response has selector")
}

/// <p>Test POST /{db}/_explain shows index candidates.</p>
Method TestPostExplainShowsCandidates()
{
    ; Create an index (may already exist from earlier test)
    Set tIdxBody = "{""index"":{""fields"":[""type""]},""ddoc"":""explain-idx"",""name"":""idx-type""}"
    Do ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("POST", "/testmfdb/_index", .tS, .tB, tIdxBody)
    Set tReqBody = "{""selector"":{""type"":""order""}}"
    Do ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("POST", "/testmfdb/_explain", .tStatus, .tBody, tReqBody)
    Do $$$AssertEquals(tStatus, 200, "Explain with index returns 200")
    Set tCandidates = tBody.%Get("index_candidates")
    Do $$$AssertTrue($IsObject(tCandidates), "index_candidates present")
    Do $$$AssertTrue(tCandidates.%Size() >= 2, "At least 2 candidates (user index + _all_docs)")
}

/// <p>Test zero staleness: write doc then immediately find it.</p>
Method TestZeroStaleness()
{
    Set tUniqueType = "zerostaleness" _ $Random(99999)
    Set tDocBody = "{""_id"":""zstest"",""type"":""" _ tUniqueType _ """}"
    Do ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("POST", "/testmfdb", .tCreateStatus, .tCreateBody, tDocBody)
    Do $$$AssertEquals(tCreateStatus, 201, "Document created")
    ; Immediately query for it
    Set tFindBody = "{""selector"":{""type"":""" _ tUniqueType _ """}}"
    Do ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("POST", "/testmfdb/_find", .tFindStatus, .tFindBody2, tFindBody)
    Do $$$AssertEquals(tFindStatus, 200, "Find returns 200")
    Set tDocs = tFindBody2.%Get("docs")
    Do $$$AssertTrue($IsObject(tDocs) && (tDocs.%Size() > 0), "Newly written doc found immediately (zero staleness)")
}

}
