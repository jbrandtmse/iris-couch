/// <p>Unit tests for Epic 4 deferred cleanup — new Storage methods.</p>
/// <p>Tests <method>Storage.Changes.RecordChange</method>,
/// <method>Storage.Changes.EventResourceName</method>,
/// <method>Storage.Database.IncrementDocCount</method>,
/// <method>Storage.Database.IncrementDelCount</method>,
/// <method>Storage.Database.SetUpdateSeq</method>, and
/// <method>Storage.Document.RevisionExists</method>.</p>
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
    Kill ^IRISCouch.Atts("teststoragecleanup")
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
    Kill ^IRISCouch.Atts("teststoragecleanup")
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

/// <p>Test RevisionExists checks specific revision existence.</p>
Method TestRevisionExists()
{
    ; Write a doc via Storage.Document
    Set tSC = ##class(IRISCouch.Storage.Document).Write("teststoragecleanup", "doc1", "1-abc", "{""hello"":""world""}")
    Do $$$AssertStatusOK(tSC, "Document written successfully")
    ; RevisionExists should return true for the written revision
    Set tExists = ##class(IRISCouch.Storage.Document).RevisionExists("teststoragecleanup", "doc1", "1-abc")
    Do $$$AssertTrue(tExists, "RevisionExists returns true for existing revision")
    ; Should return false for non-existent revision
    Set tNotExists = ##class(IRISCouch.Storage.Document).RevisionExists("teststoragecleanup", "doc1", "2-xyz")
    Do $$$AssertTrue('tNotExists, "RevisionExists returns false for non-existent revision")
    ; Should return false for non-existent doc
    Set tNoDoc = ##class(IRISCouch.Storage.Document).RevisionExists("teststoragecleanup", "nodoc", "1-abc")
    Do $$$AssertTrue('tNoDoc, "RevisionExists returns false for non-existent document")
}

/// <p>Test Delete() explicitly deletes the underlying stream object (no orphaned OIDs).</p>
Method TestDeleteCleansUpStreamOID()
{
    Kill ^IRISCouch.Atts("teststoragecleanup")
    ; Store an attachment
    Set tStream = ##class(%Stream.GlobalBinary).%New()
    Do tStream.Write("stream cleanup test data")
    Do tStream.Rewind()
    Set tSC = ##class(IRISCouch.Storage.Attachment).Store("teststoragecleanup", "doc1", "1-abc", "cleanup.txt", "text/plain", tStream, 1, .tDigest, .tLen)
    Do $$$AssertStatusOK(tSC, "Attachment stored successfully")
    ; Get the stream OID before delete
    Set tOID = $Get(^IRISCouch.Atts("teststoragecleanup", "doc1", "1-abc", "cleanup.txt", "stream"))
    Do $$$AssertTrue(tOID '= "", "Stream OID exists after store")
    ; Verify stream can be opened via OID
    Set tCheck = ##class(%Stream.GlobalBinary).%Open(tOID)
    Do $$$AssertTrue($IsObject(tCheck), "Stream object can be opened before delete")
    Do $$$AssertTrue(tCheck.Size > 0, "Stream has data before delete")
    Set tCheck = ""
    ; Delete the attachment
    Set tSC = ##class(IRISCouch.Storage.Attachment).Delete("teststoragecleanup", "doc1", "1-abc", "cleanup.txt")
    Do $$$AssertStatusOK(tSC, "Attachment deleted successfully")
    ; Verify stream data was cleared (stream opens but has no data)
    Set tCheckAfter = ##class(%Stream.GlobalBinary).%Open(tOID)
    If $IsObject(tCheckAfter) {
        Do $$$AssertEquals(tCheckAfter.Size, 0, "Stream data cleared after delete (size = 0)")
    } Else {
        Do $$$AssertTrue(1, "Stream no longer opens after delete")
    }
    ; Verify global node is gone
    Do $$$AssertTrue('$Data(^IRISCouch.Atts("teststoragecleanup", "doc1", "1-abc", "cleanup.txt")), "Attachment global node removed")
}

/// <p>Test FindRevWithAttachment compares generations numerically not lexicographically.</p>
Method TestFindRevWithAttachmentNumericSort()
{
    Kill ^IRISCouch.Atts("teststoragecleanup")
    ; Create attachment on rev "2-abc"
    Set tStream1 = ##class(%Stream.GlobalBinary).%New()
    Do tStream1.Write("data at rev 2")
    Do tStream1.Rewind()
    Set tSC = ##class(IRISCouch.Storage.Attachment).Store("teststoragecleanup", "sortdoc", "2-abc", "file.txt", "text/plain", tStream1, 2, .tD1, .tL1)
    Do $$$AssertStatusOK(tSC, "Attachment stored at rev 2-abc")
    ; Create attachment on rev "10-xyz"
    Set tStream2 = ##class(%Stream.GlobalBinary).%New()
    Do tStream2.Write("data at rev 10")
    Do tStream2.Rewind()
    Set tSC = ##class(IRISCouch.Storage.Attachment).Store("teststoragecleanup", "sortdoc", "10-xyz", "file.txt", "text/plain", tStream2, 10, .tD2, .tL2)
    Do $$$AssertStatusOK(tSC, "Attachment stored at rev 10-xyz")
    ; FindRevWithAttachment should return "10-xyz" (gen 10 > gen 2), not "2-abc"
    ; Lexicographic sort would return "2-abc" because "2" > "1" in string comparison
    Set tFound = ##class(IRISCouch.Storage.Attachment).FindRevWithAttachment("teststoragecleanup", "sortdoc", "file.txt")
    Do $$$AssertEquals(tFound, "10-xyz", "FindRevWithAttachment returns rev with highest numeric generation (10 > 2)")
}

/// <p>Test RevisionExists returns true for existing, false for missing — same as former DocumentExists.</p>
Method TestRevisionExistsRenameCompat()
{
    Set tSC = ##class(IRISCouch.Storage.Document).Write("teststoragecleanup", "renamedoc", "1-abc", "{""renamed"":true}")
    Do $$$AssertStatusOK(tSC, "Document written")
    ; New name works
    Do $$$AssertTrue(##class(IRISCouch.Storage.Document).RevisionExists("teststoragecleanup", "renamedoc", "1-abc"), "RevisionExists finds existing revision")
    Do $$$AssertTrue('##class(IRISCouch.Storage.Document).RevisionExists("teststoragecleanup", "renamedoc", "99-zzz"), "RevisionExists false for missing rev")
}

/// <p>Test Delete on non-existent attachment does not error.</p>
Method TestDeleteNonExistentAttachment()
{
    Kill ^IRISCouch.Atts("teststoragecleanup")
    Set tSC = ##class(IRISCouch.Storage.Attachment).Delete("teststoragecleanup", "nodoc", "1-x", "nofile.txt")
    Do $$$AssertStatusOK(tSC, "Delete non-existent attachment returns OK (no-op)")
}

/// <p>Test FindRevWithAttachment returns empty for non-existent attachment.</p>
Method TestFindRevWithAttachmentNotFound()
{
    Kill ^IRISCouch.Atts("teststoragecleanup")
    Set tFound = ##class(IRISCouch.Storage.Attachment).FindRevWithAttachment("teststoragecleanup", "nodoc", "nofile.txt")
    Do $$$AssertEquals(tFound, "", "FindRevWithAttachment returns empty for non-existent attachment")
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
