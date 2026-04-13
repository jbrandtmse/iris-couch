/// <p>Unit tests for MangoExecutor, MangoFields, and MangoSort.</p>
/// <p>Tests query execution, field projection, sorting, pagination,
/// bookmarks, and execution stats.</p>
Class IRISCouch.Test.MangoQueryTest Extends %UnitTest.TestCase
{

/// <p>Handle initvalue parameter from parent class.</p>
Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Quit $$$OK
}

/// <p>Create test database and seed documents before each test.</p>
Method OnBeforeOneTest() As %Status
{
    Kill ^IRISCouch.DB("testquerydb")
    Kill ^IRISCouch.Docs("testquerydb")
    Kill ^IRISCouch.Tree("testquerydb")
    Kill ^IRISCouch.Changes("testquerydb")
    Kill ^IRISCouch.Seq("testquerydb")
    Set tSC = ##class(IRISCouch.Storage.Database).Create("testquerydb")
    Do ##class(IRISCouch.Projection.Winners).DeleteAll("testquerydb")
    Do ##class(IRISCouch.Projection.MangoIndex).DeleteAll("testquerydb")
    Do ##class(IRISCouch.Projection.MangoIndexDef).DeleteAll("testquerydb")
    ; Seed test documents via Winners (direct insertion for testing)
    Do ##class(IRISCouch.Projection.Winners).Upsert("testquerydb", "doc1", "1-abc", "{""_id"":""doc1"",""_rev"":""1-abc"",""type"":""order"",""total"":100,""status"":""active""}")
    Do ##class(IRISCouch.Projection.Winners).Upsert("testquerydb", "doc2", "1-def", "{""_id"":""doc2"",""_rev"":""1-def"",""type"":""order"",""total"":200,""status"":""pending""}")
    Do ##class(IRISCouch.Projection.Winners).Upsert("testquerydb", "doc3", "1-ghi", "{""_id"":""doc3"",""_rev"":""1-ghi"",""type"":""invoice"",""total"":300,""status"":""active""}")
    Do ##class(IRISCouch.Projection.Winners).Upsert("testquerydb", "doc4", "1-jkl", "{""_id"":""doc4"",""_rev"":""1-jkl"",""type"":""order"",""total"":50,""status"":""closed""}")
    Do ##class(IRISCouch.Projection.Winners).Upsert("testquerydb", "doc5", "1-mno", "{""_id"":""doc5"",""_rev"":""1-mno"",""type"":""invoice"",""total"":150,""status"":""active""}")
    Quit $$$OK
}

/// <p>Clean up after each test.</p>
Method OnAfterOneTest() As %Status
{
    Do ##class(IRISCouch.Projection.Winners).DeleteAll("testquerydb")
    Do ##class(IRISCouch.Projection.MangoIndex).DeleteAll("testquerydb")
    Do ##class(IRISCouch.Projection.MangoIndexDef).DeleteAll("testquerydb")
    Kill ^IRISCouch.DB("testquerydb")
    Kill ^IRISCouch.Docs("testquerydb")
    Kill ^IRISCouch.Tree("testquerydb")
    Kill ^IRISCouch.Changes("testquerydb")
    Kill ^IRISCouch.Seq("testquerydb")
    Quit $$$OK
}

/// <p>Test basic find returns matching docs.</p>
Method TestBasicFind()
{
    Set tSelector = {"type":{"$eq":"order"}}
    Set tOpts = {"limit":25}
    Set tResult = ##class(IRISCouch.Query.MangoExecutor).Execute("testquerydb", tSelector, tOpts)
    Set tDocs = tResult.%Get("docs")
    Do $$$AssertTrue($IsObject(tDocs), "Result has docs array")
    Do $$$AssertEquals(tDocs.%Size(), 3, "3 order docs returned")
}

/// <p>Test find with field projection only returns requested fields.</p>
Method TestFindWithFieldProjection()
{
    Set tSelector = {"type":{"$eq":"order"}}
    Set tOpts = {"fields":["_id","total"]}
    Set tResult = ##class(IRISCouch.Query.MangoExecutor).Execute("testquerydb", tSelector, tOpts)
    Set tDocs = tResult.%Get("docs")
    Do $$$AssertTrue(tDocs.%Size() > 0, "Has docs")
    Set tFirst = tDocs.%Get(0)
    Do $$$AssertTrue(tFirst.%IsDefined("_id"), "Projected doc has _id")
    Do $$$AssertTrue(tFirst.%IsDefined("total"), "Projected doc has total")
    Do $$$AssertTrue('tFirst.%IsDefined("status"), "Projected doc lacks status")
}

/// <p>Test find with sort returns results in correct order.</p>
Method TestFindWithSort()
{
    Set tSelector = {"type":{"$eq":"order"}}
    Set tOpts = {"sort":[{"total":"asc"}]}
    Set tResult = ##class(IRISCouch.Query.MangoExecutor).Execute("testquerydb", tSelector, tOpts)
    Set tDocs = tResult.%Get("docs")
    Do $$$AssertTrue(tDocs.%Size() >= 2, "Has multiple docs")
    ; First doc should have smallest total (50)
    Set tFirst = tDocs.%Get(0)
    Set tSecond = tDocs.%Get(1)
    Do $$$AssertTrue(tFirst.%Get("total") <= tSecond.%Get("total"), "Docs sorted by total ascending")
}

/// <p>Test skip and limit pagination.</p>
Method TestFindWithLimitSkip()
{
    Set tSelector = {}
    Set tOpts = {"limit":2,"skip":1}
    Set tResult = ##class(IRISCouch.Query.MangoExecutor).Execute("testquerydb", tSelector, tOpts)
    Set tDocs = tResult.%Get("docs")
    Do $$$AssertEquals(tDocs.%Size(), 2, "Limit 2 returns exactly 2 docs")
}

/// <p>Test bookmark pagination across two requests.</p>
Method TestBookmarkPagination()
{
    ; First request: limit 2
    Set tSelector = {}
    Set tOpts = {"limit":2}
    Set tResult1 = ##class(IRISCouch.Query.MangoExecutor).Execute("testquerydb", tSelector, tOpts)
    Set tDocs1 = tResult1.%Get("docs")
    Do $$$AssertEquals(tDocs1.%Size(), 2, "First page has 2 docs")
    Set tBookmark = tResult1.%Get("bookmark")
    Do $$$AssertTrue(tBookmark '= "nil", "Bookmark is not nil when more docs exist")
    ; Second request with bookmark
    Set tOpts2 = {"limit":2,"bookmark":(tBookmark)}
    Set tResult2 = ##class(IRISCouch.Query.MangoExecutor).Execute("testquerydb", tSelector, tOpts2)
    Set tDocs2 = tResult2.%Get("docs")
    Do $$$AssertTrue(tDocs2.%Size() > 0, "Second page has docs")
    ; Verify no overlap
    Set tId1 = tDocs1.%Get(0).%Get("_id")
    Set tId2 = tDocs1.%Get(1).%Get("_id")
    Set tId3 = tDocs2.%Get(0).%Get("_id")
    Do $$$AssertTrue((tId3 '= tId1) && (tId3 '= tId2), "Second page does not overlap with first")
}

/// <p>Test execution stats are returned when requested.</p>
Method TestExecutionStats()
{
    Set tSelector = {"type":{"$eq":"order"}}
    Set tOpts = {"execution_stats":true}
    Set tResult = ##class(IRISCouch.Query.MangoExecutor).Execute("testquerydb", tSelector, tOpts)
    Set tStats = tResult.%Get("execution_stats")
    Do $$$AssertTrue($IsObject(tStats), "execution_stats is present")
    Do $$$AssertTrue(tStats.%IsDefined("total_docs_examined"), "Has total_docs_examined")
    Do $$$AssertTrue(tStats.%IsDefined("results_returned"), "Has results_returned")
    Do $$$AssertTrue(tStats.%IsDefined("execution_time_ms"), "Has execution_time_ms")
    Do $$$AssertTrue(tStats.%Get("results_returned") > 0, "Results returned > 0")
}

/// <p>Test full scan returns correct results without index.</p>
Method TestFullScanCorrectResults()
{
    ; Query a field with no index — falls back to full scan
    Set tSelector = {"status":{"$eq":"active"}}
    Set tOpts = {}
    Set tResult = ##class(IRISCouch.Query.MangoExecutor).Execute("testquerydb", tSelector, tOpts)
    Set tDocs = tResult.%Get("docs")
    Do $$$AssertEquals(tDocs.%Size(), 3, "Full scan returns 3 active docs")
    ; Check warning
    Do $$$AssertTrue(tResult.%IsDefined("warning"), "Warning present for full scan")
}

/// <p>Test empty selector returns all documents.</p>
Method TestEmptySelectorReturnsAll()
{
    Set tSelector = {}
    Set tOpts = {}
    Set tResult = ##class(IRISCouch.Query.MangoExecutor).Execute("testquerydb", tSelector, tOpts)
    Set tDocs = tResult.%Get("docs")
    Do $$$AssertEquals(tDocs.%Size(), 5, "Empty selector returns all 5 docs")
}

/// <p>Test field projection with dot-notation.</p>
Method TestFieldProjectionDotNotation()
{
    ; Add a doc with nested field
    Do ##class(IRISCouch.Projection.Winners).Upsert("testquerydb", "doc6", "1-pqr", "{""_id"":""doc6"",""address"":{""city"":""NYC"",""zip"":""10001""}}")
    Set tDoc = ##class(%DynamicObject).%FromJSON("{""_id"":""doc6"",""address"":{""city"":""NYC"",""zip"":""10001""}}")
    Set tFields = ["address.city"]
    Set tProjected = ##class(IRISCouch.Query.MangoFields).Project(tDoc, tFields)
    Do $$$AssertTrue($IsObject(tProjected), "Projected result is object")
    Do $$$AssertTrue(tProjected.%IsDefined("address"), "Has address key")
    Set tAddr = tProjected.%Get("address")
    Do $$$AssertEquals(tAddr.%Get("city"), "NYC", "Nested city extracted")
    Do $$$AssertTrue('tAddr.%IsDefined("zip"), "Non-projected nested field excluded")
}

/// <p>Test sort validation rejects mixed directions.</p>
Method TestSortValidation()
{
    Set tSort = [{"a":"asc"},{"b":"desc"}]
    Set tSC = ##class(IRISCouch.Query.MangoSort).Validate(tSort)
    Do $$$AssertStatusNotOK(tSC, "Mixed sort directions rejected")
}

}
