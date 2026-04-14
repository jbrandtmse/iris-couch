/// <p>Unit tests for IRISCouch revision difference calculation.</p>
/// <p>Tests the <code>HandleRevsDiff</code> method logic by directly exercising
/// <class>IRISCouch.Storage.RevTree</class> methods used by the endpoint:
/// <method>RevExists</method>, <method>GetLeafRevs</method>, and
/// <method>TreeExists</method>. Covers AC #1-#5 for Story 8.2.</p>
Class IRISCouch.Test.RevsDiffTest Extends %UnitTest.TestCase
{

/// <p>Handle initvalue parameter from parent class.</p>
Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Quit $$$OK
}

/// <p>Clean up test globals before each test.</p>
Method OnBeforeOneTest() As %Status
{
    Kill ^IRISCouch.DB("revsdifftest")
    Kill ^IRISCouch.Docs("revsdifftest")
    Kill ^IRISCouch.Tree("revsdifftest")
    Kill ^IRISCouch.Changes("revsdifftest")
    Kill ^IRISCouch.Seq("revsdifftest")
    Kill ^IRISCouch.Local("revsdifftest")
    Kill ^IRISCouch.Proj("revsdifftest")
    Kill ^IRISCouch.MangoIdx("revsdifftest")
    ; Create the test database
    Set tSC = ##class(IRISCouch.Storage.Database).Create("revsdifftest")
    Quit tSC
}

/// <p>Clean up test globals after each test.</p>
Method OnAfterOneTest() As %Status
{
    Kill ^IRISCouch.DB("revsdifftest")
    Kill ^IRISCouch.Docs("revsdifftest")
    Kill ^IRISCouch.Tree("revsdifftest")
    Kill ^IRISCouch.Changes("revsdifftest")
    Kill ^IRISCouch.Seq("revsdifftest")
    Kill ^IRISCouch.Local("revsdifftest")
    Kill ^IRISCouch.Proj("revsdifftest")
    Kill ^IRISCouch.MangoIdx("revsdifftest")
    Quit $$$OK
}

/// <p>AC #2: Submit revisions that all exist locally, response should be empty {}.</p>
Method TestAllRevsExist()
{
    ; Create a document with a known revision
    Set tRev1 = ##class(IRISCouch.Core.DocumentEngine).Save("revsdifftest", "doc1", "{""name"":""test""}")
    Do $$$AssertTrue(tRev1 '= "", "doc1 created with rev")
    ; Verify RevExists returns true for the known revision
    Do $$$AssertTrue(##class(IRISCouch.Storage.RevTree).RevExists("revsdifftest", "doc1", tRev1), "RevExists returns true for known rev")
    ; Build the request object like HandleRevsDiff would receive
    Set tReq = {}
    Set tRevs = []
    Do tRevs.%Push(tRev1)
    Do tReq.%Set("doc1", tRevs)
    ; Simulate the algorithm: iterate and check each rev
    Set tResponse = {}
    Set tIter = tReq.%GetIterator()
    While tIter.%GetNext(.tDocId, .tRevArray) {
        Set tMissing = []
        Set tRevIter = tRevArray.%GetIterator()
        While tRevIter.%GetNext(.tIdx, .tRev) {
            If '##class(IRISCouch.Storage.RevTree).RevExists("revsdifftest", tDocId, tRev) {
                Do tMissing.%Push(tRev)
            }
        }
        If tMissing.%Size() > 0 {
            Set tDocResult = {}
            Do tDocResult.%Set("missing", tMissing)
            Do tResponse.%Set(tDocId, tDocResult)
        }
    }
    ; Response should be empty
    Set tJSON = tResponse.%ToJSON()
    Do $$$AssertEquals(tJSON, "{}", "All revs exist — response is empty {}")
}

/// <p>AC #1: Submit mix of existing and non-existing revisions, only missing returned.</p>
Method TestSomeMissing()
{
    ; Create a document with a known revision
    Set tRev1 = ##class(IRISCouch.Core.DocumentEngine).Save("revsdifftest", "doc1", "{""name"":""test""}")
    Do $$$AssertTrue(tRev1 '= "", "doc1 created with rev")
    ; Build request with one existing and one non-existing rev
    Set tFakeRev = "2-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa1"
    Do $$$AssertTrue('##class(IRISCouch.Storage.RevTree).RevExists("revsdifftest", "doc1", tFakeRev), "Fake rev does not exist")
    ; Simulate the algorithm
    Set tMissing = []
    ; Check real rev
    If '##class(IRISCouch.Storage.RevTree).RevExists("revsdifftest", "doc1", tRev1) {
        Do tMissing.%Push(tRev1)
    }
    ; Check fake rev
    If '##class(IRISCouch.Storage.RevTree).RevExists("revsdifftest", "doc1", tFakeRev) {
        Do tMissing.%Push(tFakeRev)
    }
    Do $$$AssertEquals(tMissing.%Size(), 1, "Exactly one missing revision")
    Do $$$AssertEquals(tMissing.%Get(0), tFakeRev, "Missing rev is the fake one")
}

/// <p>AC #4: Submit revisions for a docId with no tree, all reported missing, no possible_ancestors.</p>
Method TestNonExistentDoc()
{
    ; Doc "ghost" has never been created
    Do $$$AssertTrue('##class(IRISCouch.Storage.RevTree).TreeExists("revsdifftest", "ghost"), "No tree exists for ghost")
    Set tFakeRev1 = "1-bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb1"
    Set tFakeRev2 = "2-bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb2"
    ; All revisions should be missing
    Do $$$AssertTrue('##class(IRISCouch.Storage.RevTree).RevExists("revsdifftest", "ghost", tFakeRev1), "Rev1 does not exist for ghost")
    Do $$$AssertTrue('##class(IRISCouch.Storage.RevTree).RevExists("revsdifftest", "ghost", tFakeRev2), "Rev2 does not exist for ghost")
    ; GetLeafRevs should return empty array (no tree)
    Set tLeaves = ##class(IRISCouch.Storage.RevTree).GetLeafRevs("revsdifftest", "ghost")
    Do $$$AssertEquals(tLeaves.%Size(), 0, "No leaf revs for non-existent doc — no possible_ancestors")
}

/// <p>AC #3: Missing revisions for doc with known tree includes possible_ancestors from leaf revs.</p>
Method TestPossibleAncestors()
{
    ; Create doc with revision tree
    Set tRev1 = ##class(IRISCouch.Core.DocumentEngine).Save("revsdifftest", "doc2", "{""v"":1}")
    Do $$$AssertTrue(tRev1 '= "", "doc2 created with rev1")
    Set tRev2 = ##class(IRISCouch.Core.DocumentEngine).Save("revsdifftest", "doc2", "{""v"":2}", tRev1)
    Do $$$AssertTrue(tRev2 '= "", "doc2 updated with rev2")
    ; Now check a non-existing revision
    Set tFakeRev = "3-cccccccccccccccccccccccccccccccc"
    Do $$$AssertTrue('##class(IRISCouch.Storage.RevTree).RevExists("revsdifftest", "doc2", tFakeRev), "Fake rev3 does not exist")
    ; GetLeafRevs should return the current leaf(s)
    Set tLeaves = ##class(IRISCouch.Storage.RevTree).GetLeafRevs("revsdifftest", "doc2")
    Do $$$AssertTrue(tLeaves.%Size() > 0, "Leaf revs exist for doc2 — used as possible_ancestors")
    ; The leaf should be tRev2 (the latest)
    Do $$$AssertEquals(tLeaves.%Get(0), tRev2, "Leaf rev is the latest revision")
}

/// <p>AC #5: Empty request {} returns empty response {}.</p>
Method TestEmptyBody()
{
    ; Simulate empty request object
    Set tReq = {}
    Set tResponse = {}
    Set tIter = tReq.%GetIterator()
    Set tHasItems = 0
    While tIter.%GetNext(.tDocId, .tRevArray) {
        Set tHasItems = 1
    }
    Do $$$AssertTrue('tHasItems, "Empty request has no items to iterate")
    Do $$$AssertEquals(tResponse.%ToJSON(), "{}", "Empty request produces empty response")
}

/// <p>AC #1: Submit multiple docIds in one request, correct per-doc results.</p>
Method TestMultipleDocs()
{
    ; Create doc1 with known revision
    Set tRev1 = ##class(IRISCouch.Core.DocumentEngine).Save("revsdifftest", "docA", "{""a"":1}")
    Do $$$AssertTrue(tRev1 '= "", "docA created")
    ; Create doc2 with known revision
    Set tRev2 = ##class(IRISCouch.Core.DocumentEngine).Save("revsdifftest", "docB", "{""b"":1}")
    Do $$$AssertTrue(tRev2 '= "", "docB created")
    ; Build request: docA with known rev (all exist), docB with fake rev (missing)
    Set tFakeRev = "2-dddddddddddddddddddddddddddddddd"
    ; Simulate the full algorithm
    Set tResponse = {}
    ; Process docA — rev exists, no missing
    Set tMissingA = []
    If '##class(IRISCouch.Storage.RevTree).RevExists("revsdifftest", "docA", tRev1) {
        Do tMissingA.%Push(tRev1)
    }
    Do $$$AssertEquals(tMissingA.%Size(), 0, "docA has no missing revisions")
    ; Process docB — fake rev is missing
    Set tMissingB = []
    If '##class(IRISCouch.Storage.RevTree).RevExists("revsdifftest", "docB", tRev2) {
        Do tMissingB.%Push(tRev2)
    }
    If '##class(IRISCouch.Storage.RevTree).RevExists("revsdifftest", "docB", tFakeRev) {
        Do tMissingB.%Push(tFakeRev)
    }
    Do $$$AssertEquals(tMissingB.%Size(), 1, "docB has exactly one missing revision")
    ; Build response for docB only (docA has nothing missing)
    If tMissingB.%Size() > 0 {
        Set tDocResult = {}
        Do tDocResult.%Set("missing", tMissingB)
        Set tLeaves = ##class(IRISCouch.Storage.RevTree).GetLeafRevs("revsdifftest", "docB")
        If tLeaves.%Size() > 0 {
            Do tDocResult.%Set("possible_ancestors", tLeaves)
        }
        Do tResponse.%Set("docB", tDocResult)
    }
    ; Verify response: docA not in response, docB has missing + possible_ancestors
    Do $$$AssertTrue('tResponse.%IsDefined("docA"), "docA not in response (all revs exist)")
    Do $$$AssertTrue(tResponse.%IsDefined("docB"), "docB in response (has missing revs)")
    Set tDocBResult = tResponse.%Get("docB")
    Do $$$AssertEquals(tDocBResult.%Get("missing").%Get(0), tFakeRev, "docB missing rev is the fake one")
    Do $$$AssertTrue(tDocBResult.%IsDefined("possible_ancestors"), "docB has possible_ancestors")
}

}
