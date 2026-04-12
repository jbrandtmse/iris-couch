/// <p>Unit tests for IRISCouch changes feed functionality.</p>
/// <p>Tests <class>IRISCouch.Storage.Changes</class> methods at the storage/engine level.
/// Covers AC #1, #2, #3, #4, #5, #6.</p>
Class IRISCouch.Test.ChangesTest Extends %UnitTest.TestCase
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
    Kill ^IRISCouch.DB("testchangesdb")
    Kill ^IRISCouch.Docs("testchangesdb")
    Kill ^IRISCouch.Tree("testchangesdb")
    Kill ^IRISCouch.Changes("testchangesdb")
    Kill ^IRISCouch.Seq("testchangesdb")
    ; Create fresh test database
    Set tSC = ##class(IRISCouch.Storage.Database).Create("testchangesdb")
    Quit tSC
}

/// <p>Kill all test database globals after each test.</p>
Method OnAfterOneTest() As %Status
{
    Kill ^IRISCouch.DB("testchangesdb")
    Kill ^IRISCouch.Docs("testchangesdb")
    Kill ^IRISCouch.Tree("testchangesdb")
    Kill ^IRISCouch.Changes("testchangesdb")
    Kill ^IRISCouch.Seq("testchangesdb")
    Quit $$$OK
}

/// <p>AC #1: Create 3 docs, verify all 3 appear in changes with monotonically increasing seq.</p>
Method TestBasicChangesFeed()
{
    ; Create 3 documents
    Set tRev1 = ##class(IRISCouch.Core.DocumentEngine).Save("testchangesdb", "doc1", "{""name"":""Alice""}")
    Do $$$AssertTrue(tRev1 '= "", "Created doc1")
    Set tRev2 = ##class(IRISCouch.Core.DocumentEngine).Save("testchangesdb", "doc2", "{""name"":""Bob""}")
    Do $$$AssertTrue(tRev2 '= "", "Created doc2")
    Set tRev3 = ##class(IRISCouch.Core.DocumentEngine).Save("testchangesdb", "doc3", "{""name"":""Charlie""}")
    Do $$$AssertTrue(tRev3 '= "", "Created doc3")
    ; Get changes
    Set tResult = ##class(IRISCouch.Storage.Changes).ListChanges("testchangesdb")
    Do $$$AssertTrue($IsObject(tResult), "ListChanges returns object")
    Set tResults = tResult.%Get("results")
    Do $$$AssertEquals(tResults.%Size(), 3, "3 results returned")
    ; Verify monotonically increasing seq
    Set tPrevSeq = 0
    Set tI = 0
    While tI < tResults.%Size() {
        Set tEntry = tResults.%Get(tI)
        Set tI = tI + 1
        Set tSeq = tEntry.%Get("seq")
        Do $$$AssertTrue(tSeq > tPrevSeq, "Seq " _ tSeq _ " > prev " _ tPrevSeq)
        Set tPrevSeq = tSeq
    }
    ; Verify correct doc IDs
    Do $$$AssertEquals(tResults.%Get(0).%Get("id"), "doc1", "First change is doc1")
    Do $$$AssertEquals(tResults.%Get(1).%Get("id"), "doc2", "Second change is doc2")
    Do $$$AssertEquals(tResults.%Get(2).%Get("id"), "doc3", "Third change is doc3")
    ; Verify pending is 0
    Do $$$AssertEquals(tResult.%Get("pending"), 0, "pending is 0")
}

/// <p>AC #2: Create 3 docs, call ListChanges with pSince=1, verify only 2 results.</p>
Method TestChangesSince()
{
    ; Create 3 documents
    Set tRev1 = ##class(IRISCouch.Core.DocumentEngine).Save("testchangesdb", "doc1", "{""v"":1}")
    Set tRev2 = ##class(IRISCouch.Core.DocumentEngine).Save("testchangesdb", "doc2", "{""v"":2}")
    Set tRev3 = ##class(IRISCouch.Core.DocumentEngine).Save("testchangesdb", "doc3", "{""v"":3}")
    ; Get changes since=1
    Set tResult = ##class(IRISCouch.Storage.Changes).ListChanges("testchangesdb", 1)
    Set tResults = tResult.%Get("results")
    Do $$$AssertEquals(tResults.%Size(), 2, "2 results returned (seq > 1)")
    Do $$$AssertEquals(tResults.%Get(0).%Get("id"), "doc2", "First result is doc2")
    Do $$$AssertEquals(tResults.%Get(1).%Get("id"), "doc3", "Second result is doc3")
}

/// <p>AC #3: Create 5 docs, call ListChanges with pLimit=2, verify 2 results and pending=3.</p>
Method TestChangesLimit()
{
    ; Create 5 documents
    For tI = 1:1:5 {
        Set tRev = ##class(IRISCouch.Core.DocumentEngine).Save("testchangesdb", "doc" _ tI, "{""idx"":" _ tI _ "}")
        Do $$$AssertTrue(tRev '= "", "Created doc" _ tI)
    }
    ; Get changes with limit=2
    Set tResult = ##class(IRISCouch.Storage.Changes).ListChanges("testchangesdb", 0, 2)
    Set tResults = tResult.%Get("results")
    Do $$$AssertEquals(tResults.%Size(), 2, "2 results returned with limit=2")
    Do $$$AssertEquals(tResult.%Get("pending"), 3, "pending is 3")
}

/// <p>AC #1: Create doc, delete it, verify the delete appears in changes with tombstone revision.</p>
Method TestChangesIncludesDeleted()
{
    ; Create a document
    Set tRev1 = ##class(IRISCouch.Core.DocumentEngine).Save("testchangesdb", "deleteme", "{""status"":""alive""}")
    Do $$$AssertTrue(tRev1 '= "", "Created doc deleteme")
    ; Delete it
    Set tDelRev = ##class(IRISCouch.Core.DocumentEngine).SaveDeleted("testchangesdb", "deleteme", tRev1)
    Do $$$AssertTrue(tDelRev '= "", "Deleted doc deleteme")
    ; Get changes — should show both the create and the delete
    Set tResult = ##class(IRISCouch.Storage.Changes).ListChanges("testchangesdb")
    Set tResults = tResult.%Get("results")
    Do $$$AssertEquals(tResults.%Size(), 2, "2 results (create + delete)")
    ; Second entry should be the delete with the tombstone rev
    Set tDeleteEntry = tResults.%Get(1)
    Do $$$AssertEquals(tDeleteEntry.%Get("id"), "deleteme", "Delete entry is for deleteme")
    Set tDeleteRev = tDeleteEntry.%Get("changes").%Get(0).%Get("rev")
    Do $$$AssertEquals(tDeleteRev, tDelRev, "Delete entry has tombstone revision")
}

/// <p>AC #1: Create 3 docs, call GetLastSeq, verify returns 3.</p>
Method TestChangesGetLastSeq()
{
    ; Create 3 documents
    Set tRev1 = ##class(IRISCouch.Core.DocumentEngine).Save("testchangesdb", "doc1", "{""v"":1}")
    Set tRev2 = ##class(IRISCouch.Core.DocumentEngine).Save("testchangesdb", "doc2", "{""v"":2}")
    Set tRev3 = ##class(IRISCouch.Core.DocumentEngine).Save("testchangesdb", "doc3", "{""v"":3}")
    ; GetLastSeq should return 3
    Set tLastSeq = ##class(IRISCouch.Storage.Changes).GetLastSeq("testchangesdb")
    Do $$$AssertEquals(tLastSeq, 3, "GetLastSeq returns 3 after 3 docs")
}

/// <p>AC #6: Create 3 docs, call ListChanges with descending, verify reverse order.</p>
Method TestChangesDescending()
{
    ; Create 3 documents
    Set tRev1 = ##class(IRISCouch.Core.DocumentEngine).Save("testchangesdb", "doc1", "{""v"":1}")
    Set tRev2 = ##class(IRISCouch.Core.DocumentEngine).Save("testchangesdb", "doc2", "{""v"":2}")
    Set tRev3 = ##class(IRISCouch.Core.DocumentEngine).Save("testchangesdb", "doc3", "{""v"":3}")
    ; Get changes descending
    Set tResult = ##class(IRISCouch.Storage.Changes).ListChanges("testchangesdb", 0, 0, 1)
    Set tResults = tResult.%Get("results")
    Do $$$AssertEquals(tResults.%Size(), 3, "3 results returned descending")
    ; Verify reverse order (highest seq first)
    Do $$$AssertEquals(tResults.%Get(0).%Get("id"), "doc3", "First result is doc3 (descending)")
    Do $$$AssertEquals(tResults.%Get(1).%Get("id"), "doc2", "Second result is doc2 (descending)")
    Do $$$AssertEquals(tResults.%Get(2).%Get("id"), "doc1", "Third result is doc1 (descending)")
}

/// <p>Verify CountSince returns correct count.</p>
Method TestCountSince()
{
    ; Create 3 documents
    Set tRev1 = ##class(IRISCouch.Core.DocumentEngine).Save("testchangesdb", "doc1", "{""v"":1}")
    Set tRev2 = ##class(IRISCouch.Core.DocumentEngine).Save("testchangesdb", "doc2", "{""v"":2}")
    Set tRev3 = ##class(IRISCouch.Core.DocumentEngine).Save("testchangesdb", "doc3", "{""v"":3}")
    ; CountSince(0) should be 3
    Do $$$AssertEquals(##class(IRISCouch.Storage.Changes).CountSince("testchangesdb", 0), 3, "CountSince(0) = 3")
    ; CountSince(1) should be 2
    Do $$$AssertEquals(##class(IRISCouch.Storage.Changes).CountSince("testchangesdb", 1), 2, "CountSince(1) = 2")
    ; CountSince(3) should be 0
    Do $$$AssertEquals(##class(IRISCouch.Storage.Changes).CountSince("testchangesdb", 3), 0, "CountSince(3) = 0")
}

/// <p>Verify ReadEntry returns correct data for existing and non-existing entries.</p>
Method TestReadEntry()
{
    ; Create a document
    Set tRev1 = ##class(IRISCouch.Core.DocumentEngine).Save("testchangesdb", "mydoc", "{""data"":""test""}")
    Do $$$AssertTrue(tRev1 '= "", "Created mydoc")
    ; ReadEntry for seq 1 should return the entry
    Set tEntry = ##class(IRISCouch.Storage.Changes).ReadEntry("testchangesdb", 1)
    Do $$$AssertTrue(tEntry '= "", "ReadEntry(1) returns data")
    Do $$$AssertEquals($ListGet(tEntry, 1), "mydoc", "Entry docId is mydoc")
    Do $$$AssertEquals($ListGet(tEntry, 2), tRev1, "Entry rev matches")
    ; ReadEntry for seq 999 should return ""
    Set tMissing = ##class(IRISCouch.Storage.Changes).ReadEntry("testchangesdb", 999)
    Do $$$AssertEquals(tMissing, "", "ReadEntry(999) returns empty for non-existent")
}

}
