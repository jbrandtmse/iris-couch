/// <p>Unit tests for MangoPlanner index selection engine.</p>
/// <p>Tests index ranking, full-scan fallback, use_index honoring,
/// partial index exclusion, and sort compatibility.</p>
Class IRISCouch.Test.MangoPlannerTest Extends %UnitTest.TestCase
{

/// <p>Handle initvalue parameter from parent class.</p>
Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Quit $$$OK
}

/// <p>Create test database and clean projection data before each test.</p>
Method OnBeforeOneTest() As %Status
{
    Kill ^IRISCouch.DB("testplannerdb")
    Set tSC = ##class(IRISCouch.Storage.Database).Create("testplannerdb")
    Do ##class(IRISCouch.Projection.MangoIndex).DeleteAll("testplannerdb")
    Do ##class(IRISCouch.Projection.MangoIndexDef).DeleteAll("testplannerdb")
    Quit $$$OK
}

/// <p>Clean up after each test.</p>
Method OnAfterOneTest() As %Status
{
    Do ##class(IRISCouch.Projection.MangoIndex).DeleteAll("testplannerdb")
    Do ##class(IRISCouch.Projection.MangoIndexDef).DeleteAll("testplannerdb")
    Kill ^IRISCouch.DB("testplannerdb")
    Quit $$$OK
}

/// <p>Test that the best index is chosen when 2 indexes exist.</p>
Method TestChooseBestIndex()
{
    ; Create 2 indexes: one on type, one on type+date
    Do ##class(IRISCouch.Projection.MangoIndexDef).Create("testplannerdb", "_design/idx1", "idx-type", "json", "[{""type"":""asc""}]", "")
    Do ##class(IRISCouch.Projection.MangoIndexDef).Create("testplannerdb", "_design/idx2", "idx-type-date", "json", "[{""type"":""asc""},{""date"":""asc""}]", "")
    ; Query on type only — idx-type should be preferred (fewer columns)
    Set tSelector = {"type":{"$eq":"order"}}
    Set tPlan = ##class(IRISCouch.Query.MangoPlanner).ChooseIndex("testplannerdb", tSelector, "")
    Set tIndex = tPlan.%Get("index")
    Do $$$AssertEquals(tIndex.%Get("name"), "idx-type", "Fewer-column index selected when both cover the field")
}

/// <p>Test full scan fallback when no index covers the queried field.</p>
Method TestFullScanFallback()
{
    ; Create index on type, but query on status
    Do ##class(IRISCouch.Projection.MangoIndexDef).Create("testplannerdb", "_design/idx1", "idx-type", "json", "[{""type"":""asc""}]", "")
    Set tSelector = {"status":{"$eq":"active"}}
    Set tPlan = ##class(IRISCouch.Query.MangoPlanner).ChooseIndex("testplannerdb", tSelector, "")
    Set tIndex = tPlan.%Get("index")
    Do $$$AssertEquals(tIndex.%Get("name"), "_all_docs", "Falls back to _all_docs when no index covers field")
    Do $$$AssertTrue(tPlan.%Get("warning") '= "", "Warning included for full scan")
}

/// <p>Test use_index is honored.</p>
Method TestUseIndexHonored()
{
    Do ##class(IRISCouch.Projection.MangoIndexDef).Create("testplannerdb", "_design/idx1", "idx-type", "json", "[{""type"":""asc""}]", "")
    Do ##class(IRISCouch.Projection.MangoIndexDef).Create("testplannerdb", "_design/idx2", "idx-date", "json", "[{""date"":""asc""}]", "")
    Set tSelector = {"type":{"$eq":"order"},"date":{"$gt":"2024-01-01"}}
    Set tNorm = ##class(IRISCouch.Query.MangoSelector).Normalize(tSelector)
    Set tPlan = ##class(IRISCouch.Query.MangoPlanner).ChooseIndex("testplannerdb", tNorm, "", "_design/idx2")
    Set tIndex = tPlan.%Get("index")
    ; When use_index points to idx2, it should select that or _all_docs if incompatible
    ; idx2 has field "date" which is in selector, so it should be usable
    Do $$$AssertEquals(tIndex.%Get("ddoc"), "_design/idx2", "Specified use_index ddoc honored")
}

/// <p>Test use_index incompatible returns _all_docs fallback.</p>
Method TestUseIndexIncompatible()
{
    ; Create index on type, but use_index on a non-existent design doc
    Do ##class(IRISCouch.Projection.MangoIndexDef).Create("testplannerdb", "_design/idx1", "idx-type", "json", "[{""type"":""asc""}]", "")
    Set tSelector = {"status":{"$eq":"active"}}
    Set tPlan = ##class(IRISCouch.Query.MangoPlanner).ChooseIndex("testplannerdb", tSelector, "", "_design/nonexistent")
    Set tIndex = tPlan.%Get("index")
    Do $$$AssertEquals(tIndex.%Get("name"), "_all_docs", "Incompatible use_index falls back to _all_docs")
}

/// <p>Test partial filter index is excluded from auto-selection.</p>
Method TestPartialIndexExcluded()
{
    Do ##class(IRISCouch.Projection.MangoIndexDef).Create("testplannerdb", "_design/pf1", "pf-idx", "json", "[{""type"":""asc""}]", "{""status"":""active""}")
    Set tSelector = {"type":{"$eq":"order"}}
    Set tPlan = ##class(IRISCouch.Query.MangoPlanner).ChooseIndex("testplannerdb", tSelector, "")
    Set tIndex = tPlan.%Get("index")
    Do $$$AssertEquals(tIndex.%Get("name"), "_all_docs", "Partial filter index not auto-selected")
}

/// <p>Test sort compatibility: index on [a,b], sort on [a] is compatible.</p>
Method TestSortCompatibility()
{
    Do ##class(IRISCouch.Projection.MangoIndexDef).Create("testplannerdb", "_design/idx1", "idx-ab", "json", "[{""a"":""asc""},{""b"":""asc""}]", "")
    Set tSelector = {"a":{"$eq":"x"},"b":{"$gt":0}}
    Set tNorm = ##class(IRISCouch.Query.MangoSelector).Normalize(tSelector)
    Set tSort = [{"a":"asc"}]
    Set tPlan = ##class(IRISCouch.Query.MangoPlanner).ChooseIndex("testplannerdb", tNorm, tSort)
    Set tIndex = tPlan.%Get("index")
    Do $$$AssertEquals(tIndex.%Get("name"), "idx-ab", "Sort on prefix of index columns is compatible")
}

/// <p>Test ranking by prefix difference: more overlap ranks higher.</p>
Method TestRankingByPrefixDifference()
{
    ; idx1 covers both fields in selector, idx2 covers only one
    Do ##class(IRISCouch.Projection.MangoIndexDef).Create("testplannerdb", "_design/idx1", "idx-ab", "json", "[{""a"":""asc""},{""b"":""asc""}]", "")
    Do ##class(IRISCouch.Projection.MangoIndexDef).Create("testplannerdb", "_design/idx2", "idx-a", "json", "[{""a"":""asc""}]", "")
    Set tSelector = {"a":{"$eq":"x"},"b":{"$gt":0}}
    Set tNorm = ##class(IRISCouch.Query.MangoSelector).Normalize(tSelector)
    Set tPlan = ##class(IRISCouch.Query.MangoPlanner).ChooseIndex("testplannerdb", tNorm, "")
    Set tIndex = tPlan.%Get("index")
    Do $$$AssertEquals(tIndex.%Get("name"), "idx-ab", "Index covering more selector fields ranks higher")
}

/// <p>Test ranking by column count when prefix difference is tied.</p>
Method TestRankingByColumnCount()
{
    ; Both cover field "a", but idx1 has fewer columns
    Do ##class(IRISCouch.Projection.MangoIndexDef).Create("testplannerdb", "_design/idx1", "idx-a", "json", "[{""a"":""asc""}]", "")
    Do ##class(IRISCouch.Projection.MangoIndexDef).Create("testplannerdb", "_design/idx2", "idx-ac", "json", "[{""a"":""asc""},{""c"":""asc""}]", "")
    Set tSelector = {"a":{"$eq":"x"}}
    Set tPlan = ##class(IRISCouch.Query.MangoPlanner).ChooseIndex("testplannerdb", tSelector, "")
    Set tIndex = tPlan.%Get("index")
    Do $$$AssertEquals(tIndex.%Get("name"), "idx-a", "Fewer columns wins when prefix difference is tied")
}

}
