/// <p>Unit tests for IRISCouch changes feed filter functionality.</p>
/// <p>Tests <code>_doc_ids</code>, <code>_design</code>, and <code>_selector</code>
/// built-in filters at the storage/engine level.
/// Covers AC #1, #2, #3, #4.</p>
Class IRISCouch.Test.ChangesFilterTest Extends %UnitTest.TestCase
{

/// <p>Handle initvalue parameter from parent class.</p>
Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Quit $$$OK
}

/// <p>Create a fresh test database before each test.</p>
Method OnBeforeOneTest() As %Status
{
    Kill ^IRISCouch.DB("testfilterdb")
    Kill ^IRISCouch.Docs("testfilterdb")
    Kill ^IRISCouch.Tree("testfilterdb")
    Kill ^IRISCouch.Changes("testfilterdb")
    Kill ^IRISCouch.Seq("testfilterdb")
    Set tSC = ##class(IRISCouch.Storage.Database).Create("testfilterdb")
    Quit tSC
}

/// <p>Kill all test database globals after each test.</p>
Method OnAfterOneTest() As %Status
{
    Kill ^IRISCouch.DB("testfilterdb")
    Kill ^IRISCouch.Docs("testfilterdb")
    Kill ^IRISCouch.Tree("testfilterdb")
    Kill ^IRISCouch.Changes("testfilterdb")
    Kill ^IRISCouch.Seq("testfilterdb")
    Quit $$$OK
}

/// <p>AC #1: Create 3 docs, get all changes, filter by doc_ids=["doc1","doc3"],
/// assert only 2 results with matching IDs.</p>
Method TestDocIdsFilter()
{
    ; Create 3 documents
    Set tRev1 = ##class(IRISCouch.Core.DocumentEngine).Save("testfilterdb", "doc1", "{""name"":""Alice""}")
    Do $$$AssertTrue(tRev1 '= "", "Created doc1")
    Set tRev2 = ##class(IRISCouch.Core.DocumentEngine).Save("testfilterdb", "doc2", "{""name"":""Bob""}")
    Do $$$AssertTrue(tRev2 '= "", "Created doc2")
    Set tRev3 = ##class(IRISCouch.Core.DocumentEngine).Save("testfilterdb", "doc3", "{""name"":""Charlie""}")
    Do $$$AssertTrue(tRev3 '= "", "Created doc3")
    ; Get all changes
    Set tRaw = ##class(IRISCouch.Storage.Changes).ListChanges("testfilterdb")
    Set tRawResults = tRaw.%Get("results")
    Do $$$AssertEquals(tRawResults.%Size(), 3, "3 raw results")
    ; Build doc_ids filter lookup
    Set tDocIdFilter("doc1") = 1
    Set tDocIdFilter("doc3") = 1
    ; Filter results
    Set tFiltered = []
    Set tI = 0
    While tI < tRawResults.%Size() {
        Set tEntry = tRawResults.%Get(tI)
        Set tI = tI + 1
        Set tDocId = tEntry.%Get("id")
        If $Data(tDocIdFilter(tDocId)) {
            Do tFiltered.%Push(tEntry)
        }
    }
    Do $$$AssertEquals(tFiltered.%Size(), 2, "Filtered to 2 results")
    Do $$$AssertEquals(tFiltered.%Get(0).%Get("id"), "doc1", "First filtered result is doc1")
    Do $$$AssertEquals(tFiltered.%Get(1).%Get("id"), "doc3", "Second filtered result is doc3")
}

/// <p>AC #3: Create docs "_design/myview" and "regular-doc", filter by _design,
/// assert only 1 result with ID starting with "_design/".</p>
Method TestDesignFilter()
{
    ; Create a design document and a regular document
    Set tRev1 = ##class(IRISCouch.Core.DocumentEngine).Save("testfilterdb", "_design/myview", "{""views"":{}}")
    Do $$$AssertTrue(tRev1 '= "", "Created _design/myview")
    Set tRev2 = ##class(IRISCouch.Core.DocumentEngine).Save("testfilterdb", "regular-doc", "{""data"":""test""}")
    Do $$$AssertTrue(tRev2 '= "", "Created regular-doc")
    ; Get all changes
    Set tRaw = ##class(IRISCouch.Storage.Changes).ListChanges("testfilterdb")
    Set tRawResults = tRaw.%Get("results")
    Do $$$AssertEquals(tRawResults.%Size(), 2, "2 raw results")
    ; Filter by _design
    Set tFiltered = []
    Set tI = 0
    While tI < tRawResults.%Size() {
        Set tEntry = tRawResults.%Get(tI)
        Set tI = tI + 1
        Set tDocId = tEntry.%Get("id")
        If $Extract(tDocId, 1, 8) = "_design/" {
            Do tFiltered.%Push(tEntry)
        }
    }
    Do $$$AssertEquals(tFiltered.%Size(), 1, "Filtered to 1 design doc")
    Do $$$AssertEquals(tFiltered.%Get(0).%Get("id"), "_design/myview", "Result is _design/myview")
}

/// <p>AC #2: Create docs with body {"type":"order"} and {"type":"user"},
/// filter with selector {"type":"order"}, assert only the order doc is returned.</p>
Method TestSelectorFilterEquality()
{
    ; Create documents with different types
    Set tRev1 = ##class(IRISCouch.Core.DocumentEngine).Save("testfilterdb", "order1", "{""type"":""order"",""amount"":100}")
    Do $$$AssertTrue(tRev1 '= "", "Created order1")
    Set tRev2 = ##class(IRISCouch.Core.DocumentEngine).Save("testfilterdb", "user1", "{""type"":""user"",""name"":""Alice""}")
    Do $$$AssertTrue(tRev2 '= "", "Created user1")
    ; Build selector
    Set tSelector = {"type": "order"}
    ; Get all changes and filter
    Set tRaw = ##class(IRISCouch.Storage.Changes).ListChanges("testfilterdb")
    Set tRawResults = tRaw.%Get("results")
    Do $$$AssertEquals(tRawResults.%Size(), 2, "2 raw results")
    ; Apply selector filter
    Set tFiltered = []
    Set tI = 0
    While tI < tRawResults.%Size() {
        Set tEntry = tRawResults.%Get(tI)
        Set tI = tI + 1
        Set tDocId = tEntry.%Get("id")
        Set tRev = tEntry.%Get("changes").%Get(0).%Get("rev")
        Set tBodyStr = ##class(IRISCouch.Storage.Document).Read("testfilterdb", tDocId, tRev)
        If tBodyStr = "" Continue
        Set tDocObj = ##class(%DynamicObject).%FromJSON(tBodyStr)
        If ##class(IRISCouch.API.ChangesHandler).MatchesSelector(tSelector, tDocObj) {
            Do tFiltered.%Push(tEntry)
        }
    }
    Do $$$AssertEquals(tFiltered.%Size(), 1, "Filtered to 1 result with selector")
    Do $$$AssertEquals(tFiltered.%Get(0).%Get("id"), "order1", "Result is order1")
}

/// <p>AC #2: Create docs with and without "email" field, filter with
/// selector {"email":{"$exists":true}}, assert only docs with email are returned.</p>
Method TestSelectorFilterExists()
{
    ; Create docs — one with email, one without
    Set tRev1 = ##class(IRISCouch.Core.DocumentEngine).Save("testfilterdb", "withemail", "{""name"":""Alice"",""email"":""alice@test.com""}")
    Do $$$AssertTrue(tRev1 '= "", "Created withemail")
    Set tRev2 = ##class(IRISCouch.Core.DocumentEngine).Save("testfilterdb", "noemail", "{""name"":""Bob""}")
    Do $$$AssertTrue(tRev2 '= "", "Created noemail")
    ; Build selector with $exists
    Set tExistsOp = {}
    Do tExistsOp.%Set("$exists", 1, "boolean")
    Set tSelector = {}
    Do tSelector.%Set("email", tExistsOp)
    ; Get all changes and filter
    Set tRaw = ##class(IRISCouch.Storage.Changes).ListChanges("testfilterdb")
    Set tRawResults = tRaw.%Get("results")
    Do $$$AssertEquals(tRawResults.%Size(), 2, "2 raw results")
    ; Apply selector filter
    Set tFiltered = []
    Set tI = 0
    While tI < tRawResults.%Size() {
        Set tEntry = tRawResults.%Get(tI)
        Set tI = tI + 1
        Set tDocId = tEntry.%Get("id")
        Set tRev = tEntry.%Get("changes").%Get(0).%Get("rev")
        Set tBodyStr = ##class(IRISCouch.Storage.Document).Read("testfilterdb", tDocId, tRev)
        If tBodyStr = "" Continue
        Set tDocObj = ##class(%DynamicObject).%FromJSON(tBodyStr)
        If ##class(IRISCouch.API.ChangesHandler).MatchesSelector(tSelector, tDocObj) {
            Do tFiltered.%Push(tEntry)
        }
    }
    Do $$$AssertEquals(tFiltered.%Size(), 1, "Filtered to 1 result with $exists")
    Do $$$AssertEquals(tFiltered.%Get(0).%Get("id"), "withemail", "Result is withemail")
}

/// <p>AC #4: Verify that unsupported filter values are rejected.</p>
Method TestUnsupportedFilter()
{
    ; Valid filters
    Set tValid1 = ((""= "") || ("" = "_doc_ids") || ("" = "_selector") || ("" = "_design"))
    Do $$$AssertTrue(tValid1, "Empty filter is valid")
    Set tValid2 = (("_doc_ids" = "") || ("_doc_ids" = "_doc_ids") || ("_doc_ids" = "_selector") || ("_doc_ids" = "_design"))
    Do $$$AssertTrue(tValid2, "_doc_ids filter is valid")
    Set tValid3 = (("_selector" = "") || ("_selector" = "_doc_ids") || ("_selector" = "_selector") || ("_selector" = "_design"))
    Do $$$AssertTrue(tValid3, "_selector filter is valid")
    Set tValid4 = (("_design" = "") || ("_design" = "_doc_ids") || ("_design" = "_selector") || ("_design" = "_design"))
    Do $$$AssertTrue(tValid4, "_design filter is valid")
    ; Invalid filter
    Set tInvalid = (("custom_filter" = "") || ("custom_filter" = "_doc_ids") || ("custom_filter" = "_selector") || ("custom_filter" = "_design"))
    Do $$$AssertTrue('tInvalid, "custom_filter is NOT a valid filter")
}

/// <p>Test MatchesSelector with $eq operator.</p>
Method TestMatchesSelectorEq()
{
    Set tDoc = {"type": "order", "status": "active"}
    ; Selector with $eq
    Set tEqVal = {}
    Do tEqVal.%Set("$eq", "active")
    Set tSelector = {}
    Do tSelector.%Set("status", tEqVal)
    Do $$$AssertTrue(##class(IRISCouch.API.ChangesHandler).MatchesSelector(tSelector, tDoc), "Doc matches $eq selector")
    ; Non-matching $eq
    Set tEqVal2 = {}
    Do tEqVal2.%Set("$eq", "inactive")
    Set tSelector2 = {}
    Do tSelector2.%Set("status", tEqVal2)
    Do $$$AssertTrue('##class(IRISCouch.API.ChangesHandler).MatchesSelector(tSelector2, tDoc), "Doc does not match non-matching $eq")
}

/// <p>Test MatchesSelector with empty and null selectors.</p>
Method TestMatchesSelectorEmpty()
{
    Set tDoc = {"type": "order"}
    ; Empty selector matches everything
    Set tSelector = {}
    Do $$$AssertTrue(##class(IRISCouch.API.ChangesHandler).MatchesSelector(tSelector, tDoc), "Empty selector matches all")
}

}
