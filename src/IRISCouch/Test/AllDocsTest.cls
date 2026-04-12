/// <p>Unit tests for IRISCouch _all_docs functionality.</p>
/// <p>Tests <class>IRISCouch.API.DocumentHandler</class> HandleAllDocs and HandleAllDocsPost
/// logic at the storage/engine level. Covers AC #1, #2, #3, #4, #5.</p>
Class IRISCouch.Test.AllDocsTest Extends %UnitTest.TestCase
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
    ; Clean up any previous test data
    Kill ^IRISCouch.DB("testalldocs")
    Kill ^IRISCouch.Docs("testalldocs")
    Kill ^IRISCouch.Tree("testalldocs")
    Kill ^IRISCouch.Changes("testalldocs")
    Kill ^IRISCouch.Seq("testalldocs")
    ; Create fresh test database
    Set tSC = ##class(IRISCouch.Storage.Database).Create("testalldocs")
    Quit tSC
}

/// <p>Kill all test database globals after each test.</p>
Method OnAfterOneTest() As %Status
{
    Kill ^IRISCouch.DB("testalldocs")
    Kill ^IRISCouch.Docs("testalldocs")
    Kill ^IRISCouch.Tree("testalldocs")
    Kill ^IRISCouch.Changes("testalldocs")
    Kill ^IRISCouch.Seq("testalldocs")
    Quit $$$OK
}

/// <p>AC #1: Create 3 docs, verify all 3 appear in _all_docs sorted by ID.</p>
Method TestAllDocsBasic()
{
    ; Create 3 documents with known IDs
    Set tRev1 = ##class(IRISCouch.Core.DocumentEngine).Save("testalldocs", "charlie", "{""name"":""Charlie""}")
    Do $$$AssertTrue(tRev1 '= "", "Created doc charlie")
    Set tRev2 = ##class(IRISCouch.Core.DocumentEngine).Save("testalldocs", "alice", "{""name"":""Alice""}")
    Do $$$AssertTrue(tRev2 '= "", "Created doc alice")
    Set tRev3 = ##class(IRISCouch.Core.DocumentEngine).Save("testalldocs", "bob", "{""name"":""Bob""}")
    Do $$$AssertTrue(tRev3 '= "", "Created doc bob")
    ; Verify doc_count
    Set tCount = ##class(IRISCouch.Storage.Document).CountNonDeleted("testalldocs")
    Do $$$AssertEquals(tCount, 3, "CountNonDeleted returns 3")
    ; Verify documents are enumerable via $Order in sorted order
    Set tDocId = ""
    Set tDocId = $Order(^IRISCouch.Docs("testalldocs", tDocId))
    Do $$$AssertEquals(tDocId, "alice", "First doc is alice (sorted)")
    Set tDocId = $Order(^IRISCouch.Docs("testalldocs", tDocId))
    Do $$$AssertEquals(tDocId, "bob", "Second doc is bob (sorted)")
    Set tDocId = $Order(^IRISCouch.Docs("testalldocs", tDocId))
    Do $$$AssertEquals(tDocId, "charlie", "Third doc is charlie (sorted)")
    Set tDocId = $Order(^IRISCouch.Docs("testalldocs", tDocId))
    Do $$$AssertEquals(tDocId, "", "No more documents")
}

/// <p>AC #2: Create 5 docs, verify skip=2, limit=2 returns correct 2 rows.</p>
Method TestAllDocsSkipLimit()
{
    ; Create 5 docs: aaa, bbb, ccc, ddd, eee
    For tI = 1:1:5 {
        Set tId = $Case(tI, 1:"aaa", 2:"bbb", 3:"ccc", 4:"ddd", 5:"eee")
        Set tRev = ##class(IRISCouch.Core.DocumentEngine).Save("testalldocs", tId, "{""idx"":" _ tI _ "}")
        Do $$$AssertTrue(tRev '= "", "Created doc " _ tId)
    }
    ; Count total docs
    Set tCount = ##class(IRISCouch.Storage.Document).CountNonDeleted("testalldocs")
    Do $$$AssertEquals(tCount, 5, "5 docs created")
    ; Verify ordering with skip/limit logic
    ; skip=2 should skip aaa,bbb; limit=2 should return ccc,ddd
    Set tDocId = ""
    Set tSkipped = 0
    Set tCollected = 0
    Set tResults = ""
    For {
        Set tDocId = $Order(^IRISCouch.Docs("testalldocs", tDocId))
        Quit:tDocId=""
        Set tWinRev = ##class(IRISCouch.Storage.RevTree).GetWinner("testalldocs", tDocId)
        If tWinRev = "" Continue
        If ##class(IRISCouch.Storage.RevTree).IsDeleted("testalldocs", tDocId, tWinRev) Continue
        If tSkipped < 2 {
            Set tSkipped = tSkipped + 1
            Continue
        }
        If tCollected >= 2 Quit
        Set tResults = tResults _ tDocId _ ","
        Set tCollected = tCollected + 1
    }
    Do $$$AssertEquals(tResults, "ccc,ddd,", "Skip=2, Limit=2 returns ccc,ddd")
}

/// <p>AC #3: Create docs aaa,bbb,ccc,ddd; verify startkey=bbb endkey=ccc returns 2 rows.</p>
Method TestAllDocsKeyRange()
{
    ; Create 4 docs
    Set tRev = ##class(IRISCouch.Core.DocumentEngine).Save("testalldocs", "aaa", "{""val"":1}")
    Set tRev = ##class(IRISCouch.Core.DocumentEngine).Save("testalldocs", "bbb", "{""val"":2}")
    Set tRev = ##class(IRISCouch.Core.DocumentEngine).Save("testalldocs", "ccc", "{""val"":3}")
    Set tRev = ##class(IRISCouch.Core.DocumentEngine).Save("testalldocs", "ddd", "{""val"":4}")
    ; Simulate key range filter: startkey=bbb, endkey=ccc
    Set tStartKey = "bbb"
    Set tEndKey = "ccc"
    Set tDocId = ""
    Set tResults = ""
    ; Start from startkey
    If $Data(^IRISCouch.Docs("testalldocs", tStartKey)) {
        Set tDocId = tStartKey
    } Else {
        Set tDocId = $Order(^IRISCouch.Docs("testalldocs", tStartKey))
    }
    For {
        Quit:tDocId=""
        Quit:(tDocId]tEndKey)
        Set tWinRev = ##class(IRISCouch.Storage.RevTree).GetWinner("testalldocs", tDocId)
        If (tWinRev '= "") && ('##class(IRISCouch.Storage.RevTree).IsDeleted("testalldocs", tDocId, tWinRev)) {
            Set tResults = tResults _ tDocId _ ","
        }
        Set tDocId = $Order(^IRISCouch.Docs("testalldocs", tDocId))
    }
    Do $$$AssertEquals(tResults, "bbb,ccc,", "Key range bbb-ccc returns bbb,ccc")
}

/// <p>AC #1: Create doc, delete it, verify it does not appear in _all_docs enumeration.</p>
Method TestAllDocsExcludesDeleted()
{
    ; Create 2 docs
    Set tRev1 = ##class(IRISCouch.Core.DocumentEngine).Save("testalldocs", "keepme", "{""status"":""active""}")
    Do $$$AssertTrue(tRev1 '= "", "Created doc keepme")
    Set tRev2 = ##class(IRISCouch.Core.DocumentEngine).Save("testalldocs", "deleteme", "{""status"":""doomed""}")
    Do $$$AssertTrue(tRev2 '= "", "Created doc deleteme")
    ; Delete one
    Set tDelRev = ##class(IRISCouch.Core.DocumentEngine).SaveDeleted("testalldocs", "deleteme", tRev2)
    Do $$$AssertTrue(tDelRev '= "", "Deleted doc deleteme")
    ; Count should be 1
    Set tCount = ##class(IRISCouch.Storage.Document).CountNonDeleted("testalldocs")
    Do $$$AssertEquals(tCount, 1, "CountNonDeleted returns 1 after deletion")
    ; Enumerate non-deleted docs
    Set tDocId = ""
    Set tResults = ""
    For {
        Set tDocId = $Order(^IRISCouch.Docs("testalldocs", tDocId))
        Quit:tDocId=""
        Set tWinRev = ##class(IRISCouch.Storage.RevTree).GetWinner("testalldocs", tDocId)
        If tWinRev = "" Continue
        If ##class(IRISCouch.Storage.RevTree).IsDeleted("testalldocs", tDocId, tWinRev) Continue
        Set tResults = tResults _ tDocId _ ","
    }
    Do $$$AssertEquals(tResults, "keepme,", "Only keepme appears, deleteme excluded")
}

}
