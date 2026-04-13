/// <p>Unit tests for Epic 4 deferred cleanup — new Storage methods.</p>
/// <p>Tests <method>Storage.Changes.RecordChange</method>,
/// <method>Storage.Changes.EventResourceName</method>,
/// <method>Storage.Database.IncrementDocCount</method>,
/// <method>Storage.Database.IncrementDelCount</method>,
/// <method>Storage.Database.SetUpdateSeq</method>, and
/// <method>Storage.Document.DocumentExists</method>.</p>
Class IRISCouch.Test.StorageCleanupTest Extends %UnitTest.TestCase
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
    Kill ^IRISCouch.DB("teststoragecleanup")
    Kill ^IRISCouch.Docs("teststoragecleanup")
    Kill ^IRISCouch.Tree("teststoragecleanup")
    Kill ^IRISCouch.Changes("teststoragecleanup")
    Kill ^IRISCouch.Seq("teststoragecleanup")
    Set tSC = ##class(IRISCouch.Storage.Database).Create("teststoragecleanup")
    Quit tSC
}

/// <p>Kill all test database globals after each test.</p>
Method OnAfterOneTest() As %Status
{
    Kill ^IRISCouch.DB("teststoragecleanup")
    Kill ^IRISCouch.Docs("teststoragecleanup")
    Kill ^IRISCouch.Tree("teststoragecleanup")
    Kill ^IRISCouch.Changes("teststoragecleanup")
    Kill ^IRISCouch.Seq("teststoragecleanup")
    Quit $$$OK
}

/// <p>Test RecordChange increments seq and writes change entry.</p>
Method TestRecordChangeSeqAndEntry()
{
    ; Record first change
    Set tSeq1 = ##class(IRISCouch.Storage.Changes).RecordChange("teststoragecleanup", "doc1", "1-abc")
    Do $$$AssertTrue(tSeq1 > 0, "First RecordChange returns positive seq")
    ; Verify the change entry was written
    Set tEntry = ##class(IRISCouch.Storage.Changes).ReadEntry("teststoragecleanup", tSeq1)
    Do $$$AssertTrue(tEntry '= "", "Change entry exists")
    Do $$$AssertEquals($ListGet(tEntry, 1), "doc1", "Change entry has correct docId")
    Do $$$AssertEquals($ListGet(tEntry, 2), "1-abc", "Change entry has correct rev")
    ; Record second change — seq should increment
    Set tSeq2 = ##class(IRISCouch.Storage.Changes).RecordChange("teststoragecleanup", "doc2", "1-def")
    Do $$$AssertTrue(tSeq2 > tSeq1, "Second seq is greater than first")
    ; Verify last seq matches
    Set tLastSeq = ##class(IRISCouch.Storage.Changes).GetLastSeq("teststoragecleanup")
    Do $$$AssertEquals(tLastSeq, tSeq2, "GetLastSeq matches last RecordChange seq")
}

/// <p>Test EventResourceName returns correct format.</p>
Method TestEventResourceNameFormat()
{
    Set tName = ##class(IRISCouch.Storage.Changes).EventResourceName("mydb")
    Do $$$AssertEquals(tName, "^IRISCouch.LPChanges(""mydb"")", "EventResourceName returns correct format")
    ; Test with special characters in db name
    Set tName2 = ##class(IRISCouch.Storage.Changes).EventResourceName("test-db")
    Do $$$AssertEquals(tName2, "^IRISCouch.LPChanges(""test-db"")", "EventResourceName handles hyphens")
}

/// <p>Test IncrementDocCount increments and decrements correctly.</p>
Method TestIncrementDocCount()
{
    ; Initial doc_count should be 0
    Set tInfo = ##class(IRISCouch.Storage.Database).GetInfo("teststoragecleanup")
    Do $$$AssertEquals(tInfo.%Get("doc_count"), 0, "Initial doc_count is 0")
    ; Increment by 1 (default)
    Do ##class(IRISCouch.Storage.Database).IncrementDocCount("teststoragecleanup")
    Set tInfo = ##class(IRISCouch.Storage.Database).GetInfo("teststoragecleanup")
    Do $$$AssertEquals(tInfo.%Get("doc_count"), 1, "doc_count after increment is 1")
    ; Decrement by 1
    Do ##class(IRISCouch.Storage.Database).IncrementDocCount("teststoragecleanup", -1)
    Set tInfo = ##class(IRISCouch.Storage.Database).GetInfo("teststoragecleanup")
    Do $$$AssertEquals(tInfo.%Get("doc_count"), 0, "doc_count after decrement is 0")
}

/// <p>Test IncrementDelCount increments deleted document count.</p>
Method TestIncrementDelCount()
{
    Set tInfo = ##class(IRISCouch.Storage.Database).GetInfo("teststoragecleanup")
    Do $$$AssertEquals(tInfo.%Get("doc_del_count"), 0, "Initial doc_del_count is 0")
    Do ##class(IRISCouch.Storage.Database).IncrementDelCount("teststoragecleanup")
    Set tInfo = ##class(IRISCouch.Storage.Database).GetInfo("teststoragecleanup")
    Do $$$AssertEquals(tInfo.%Get("doc_del_count"), 1, "doc_del_count after increment is 1")
}

/// <p>Test SetUpdateSeq sets the update_seq correctly.</p>
Method TestSetUpdateSeq()
{
    Do ##class(IRISCouch.Storage.Database).SetUpdateSeq("teststoragecleanup", 42)
    Set tInfo = ##class(IRISCouch.Storage.Database).GetInfo("teststoragecleanup")
    Do $$$AssertEquals(tInfo.%Get("update_seq"), 42, "update_seq set to 42")
}

/// <p>Test DocumentExists checks specific revision existence.</p>
Method TestDocumentExists()
{
    ; Write a doc via Storage.Document
    Set tSC = ##class(IRISCouch.Storage.Document).Write("teststoragecleanup", "doc1", "1-abc", "{""hello"":""world""}")
    Do $$$AssertStatusOK(tSC, "Document written successfully")
    ; DocumentExists should return true for the written revision
    Set tExists = ##class(IRISCouch.Storage.Document).DocumentExists("teststoragecleanup", "doc1", "1-abc")
    Do $$$AssertTrue(tExists, "DocumentExists returns true for existing revision")
    ; Should return false for non-existent revision
    Set tNotExists = ##class(IRISCouch.Storage.Document).DocumentExists("teststoragecleanup", "doc1", "2-xyz")
    Do $$$AssertTrue('tNotExists, "DocumentExists returns false for non-existent revision")
    ; Should return false for non-existent doc
    Set tNoDoc = ##class(IRISCouch.Storage.Document).DocumentExists("teststoragecleanup", "nodoc", "1-abc")
    Do $$$AssertTrue('tNoDoc, "DocumentExists returns false for non-existent document")
}

/// <p>Test end-to-end: DocumentEngine.Save uses Storage methods correctly.</p>
Method TestSaveUsesStorageMethods()
{
    ; Save a document through DocumentEngine
    Set tRev = ##class(IRISCouch.Core.DocumentEngine).Save("teststoragecleanup", "intdoc1", "{""test"":true}")
    Do $$$AssertTrue(tRev '= "", "DocumentEngine.Save returns a revision")
    ; Verify the change was recorded via Storage.Changes
    Set tLastSeq = ##class(IRISCouch.Storage.Changes).GetLastSeq("teststoragecleanup")
    Do $$$AssertTrue(tLastSeq > 0, "Sequence incremented after save")
    Set tEntry = ##class(IRISCouch.Storage.Changes).ReadEntry("teststoragecleanup", tLastSeq)
    Do $$$AssertEquals($ListGet(tEntry, 1), "intdoc1", "Change entry has correct docId")
    ; Verify doc_count was incremented
    Set tInfo = ##class(IRISCouch.Storage.Database).GetInfo("teststoragecleanup")
    Do $$$AssertEquals(tInfo.%Get("doc_count"), 1, "doc_count is 1 after first save")
    Do $$$AssertEquals(tInfo.%Get("update_seq"), tLastSeq, "update_seq matches last seq")
}

}
