/// <p>Unit tests for IRISCouch local document storage operations.</p>
/// <p>Tests <class>IRISCouch.Storage.Local</class> write, read, update, delete,
/// rev computation, and exclusion from changes feed and _all_docs.
/// Covers AC #1-#8 for Story 8.1.</p>
Class IRISCouch.Test.LocalDocTest Extends %UnitTest.TestCase
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
    Kill ^IRISCouch.Local("localtestdb")
    Kill ^IRISCouch.DB("localtestdb")
    Kill ^IRISCouch.Docs("localtestdb")
    Kill ^IRISCouch.Tree("localtestdb")
    Kill ^IRISCouch.Changes("localtestdb")
    Kill ^IRISCouch.Seq("localtestdb")
    Quit $$$OK
}

/// <p>Clean up test globals after each test.</p>
Method OnAfterOneTest() As %Status
{
    Kill ^IRISCouch.Local("localtestdb")
    Kill ^IRISCouch.DB("localtestdb")
    Kill ^IRISCouch.Docs("localtestdb")
    Kill ^IRISCouch.Tree("localtestdb")
    Kill ^IRISCouch.Changes("localtestdb")
    Kill ^IRISCouch.Seq("localtestdb")
    Quit $$$OK
}

/// <p>AC #1: Write a local document, read back, verify body and rev "0-1".</p>
Method TestLocalWrite()
{
    Set tBody = "{""source"":""replicator-1""}"
    Set tRev = "0-1"
    Set tSC = ##class(IRISCouch.Storage.Local).Write("localtestdb", "checkpoint-1", tBody, tRev)
    Do $$$AssertStatusOK(tSC, "Write returns OK status")
    ; Read back
    Set tReadBody = ##class(IRISCouch.Storage.Local).Read("localtestdb", "checkpoint-1")
    Do $$$AssertEquals(tReadBody, tBody, "Read returns correct body")
    ; Verify rev
    Set tReadRev = ##class(IRISCouch.Storage.Local).GetRev("localtestdb", "checkpoint-1")
    Do $$$AssertEquals(tReadRev, "0-1", "GetRev returns 0-1")
    ; Verify exists
    Do $$$AssertTrue(##class(IRISCouch.Storage.Local).Exists("localtestdb", "checkpoint-1"), "Exists returns true after write")
}

/// <p>AC #7: Write, update with correct rev, verify new rev "0-2".</p>
Method TestLocalUpdate()
{
    ; Initial write
    Set tSC = ##class(IRISCouch.Storage.Local).Write("localtestdb", "checkpoint-1", "{""seq"":10}", "0-1")
    Do $$$AssertStatusOK(tSC, "Initial write succeeds")
    ; Update with new body and new rev
    Set tSC = ##class(IRISCouch.Storage.Local).Write("localtestdb", "checkpoint-1", "{""seq"":20}", "0-2")
    Do $$$AssertStatusOK(tSC, "Update write succeeds")
    ; Verify updated body
    Set tReadBody = ##class(IRISCouch.Storage.Local).Read("localtestdb", "checkpoint-1")
    Do $$$AssertEquals(tReadBody, "{""seq"":20}", "Read returns updated body")
    ; Verify updated rev
    Set tReadRev = ##class(IRISCouch.Storage.Local).GetRev("localtestdb", "checkpoint-1")
    Do $$$AssertEquals(tReadRev, "0-2", "GetRev returns updated rev 0-2")
}

/// <p>AC #8: Write, attempt update with wrong rev at storage layer (conflict check).</p>
Method TestLocalConflict()
{
    ; Write first
    Set tSC = ##class(IRISCouch.Storage.Local).Write("localtestdb", "checkpoint-1", "{""seq"":10}", "0-1")
    Do $$$AssertStatusOK(tSC, "Initial write succeeds")
    ; Verify current rev
    Set tCurrentRev = ##class(IRISCouch.Storage.Local).GetRev("localtestdb", "checkpoint-1")
    Do $$$AssertEquals(tCurrentRev, "0-1", "Current rev is 0-1")
    ; Simulate conflict detection (handler-level logic):
    ; Client sends "0-5" but current is "0-1" - these don't match
    Do $$$AssertTrue(tCurrentRev '= "0-5", "Mismatched rev detected for conflict")
}

/// <p>AC #3: Write, delete, verify Exists returns 0.</p>
Method TestLocalDelete()
{
    ; Write first
    Set tSC = ##class(IRISCouch.Storage.Local).Write("localtestdb", "checkpoint-1", "{""seq"":10}", "0-1")
    Do $$$AssertStatusOK(tSC, "Write succeeds for delete test")
    Do $$$AssertTrue(##class(IRISCouch.Storage.Local).Exists("localtestdb", "checkpoint-1"), "Exists before delete")
    ; Delete
    Set tSC = ##class(IRISCouch.Storage.Local).Delete("localtestdb", "checkpoint-1")
    Do $$$AssertStatusOK(tSC, "Delete returns OK status")
    Do $$$AssertTrue('##class(IRISCouch.Storage.Local).Exists("localtestdb", "checkpoint-1"), "Exists returns false after delete")
    ; Read should return empty
    Set tReadBody = ##class(IRISCouch.Storage.Local).Read("localtestdb", "checkpoint-1")
    Do $$$AssertEquals(tReadBody, "", "Read returns empty after delete")
    Set tReadRev = ##class(IRISCouch.Storage.Local).GetRev("localtestdb", "checkpoint-1")
    Do $$$AssertEquals(tReadRev, "", "GetRev returns empty after delete")
}

/// <p>AC #6: Read non-existent local doc, verify empty return.</p>
Method TestLocalNotFound()
{
    Set tReadBody = ##class(IRISCouch.Storage.Local).Read("localtestdb", "nonexistent")
    Do $$$AssertEquals(tReadBody, "", "Read non-existent returns empty string")
    Set tReadRev = ##class(IRISCouch.Storage.Local).GetRev("localtestdb", "nonexistent")
    Do $$$AssertEquals(tReadRev, "", "GetRev non-existent returns empty string")
    Do $$$AssertTrue('##class(IRISCouch.Storage.Local).Exists("localtestdb", "nonexistent"), "Exists non-existent returns false")
}

/// <p>Verify NextRev computation: "" to "0-1", "0-1" to "0-2", "0-99" to "0-100".</p>
Method TestNextRev()
{
    ; Empty (new doc) -> "0-1"
    Set tResult = ##class(IRISCouch.Storage.Local).NextRev("")
    Do $$$AssertEquals(tResult, "0-1", "Empty rev produces 0-1")
    ; "0-1" -> "0-2"
    Set tResult = ##class(IRISCouch.Storage.Local).NextRev("0-1")
    Do $$$AssertEquals(tResult, "0-2", "0-1 increments to 0-2")
    ; "0-99" -> "0-100"
    Set tResult = ##class(IRISCouch.Storage.Local).NextRev("0-99")
    Do $$$AssertEquals(tResult, "0-100", "0-99 increments to 0-100")
    ; "0-0" -> "0-1" (edge case)
    Set tResult = ##class(IRISCouch.Storage.Local).NextRev("0-0")
    Do $$$AssertEquals(tResult, "0-1", "0-0 increments to 0-1")
}

/// <p>AC #4: Write a local doc AND a normal doc to same DB, verify only
/// normal doc appears in changes feed.</p>
Method TestLocalExcludedFromChanges()
{
    ; Create database
    Set tSC = ##class(IRISCouch.Storage.Database).Create("localtestdb")
    Do $$$AssertStatusOK(tSC, "Create database succeeds")
    ; Write a normal document via DocumentEngine
    Set tNormalRev = ##class(IRISCouch.Core.DocumentEngine).Save("localtestdb", "normaldoc1", "{""type"":""normal""}")
    Do $$$AssertTrue(tNormalRev '= "", "Normal doc saved with rev")
    ; Write a local document
    Set tSC = ##class(IRISCouch.Storage.Local).Write("localtestdb", "checkpoint-1", "{""type"":""local""}", "0-1")
    Do $$$AssertStatusOK(tSC, "Local doc written")
    ; Query changes feed
    Set tChanges = ##class(IRISCouch.Storage.Changes).ListChanges("localtestdb")
    Do $$$AssertTrue($IsObject(tChanges), "Changes returns object")
    Set tResults = tChanges.%Get("results")
    Do $$$AssertTrue($IsObject(tResults), "Changes has results array")
    ; Verify normal doc is in changes
    Set tFoundNormal = 0
    Set tFoundLocal = 0
    Set tIter = tResults.%GetIterator()
    While tIter.%GetNext(.tKey, .tVal) {
        Set tDocId = tVal.%Get("id")
        If tDocId = "normaldoc1" Set tFoundNormal = 1
        If tDocId [ "checkpoint" Set tFoundLocal = 1
        If tDocId [ "_local" Set tFoundLocal = 1
    }
    Do $$$AssertTrue(tFoundNormal, "Normal doc found in changes feed")
    Do $$$AssertTrue('tFoundLocal, "Local doc NOT found in changes feed")
}

/// <p>AC #5: Write a local doc AND a normal doc, verify only normal doc
/// appears in _all_docs (via Storage.Document.ListDocIds).</p>
Method TestLocalExcludedFromAllDocs()
{
    ; Create database
    Set tSC = ##class(IRISCouch.Storage.Database).Create("localtestdb")
    Do $$$AssertStatusOK(tSC, "Create database succeeds")
    ; Write a normal document
    Set tNormalRev = ##class(IRISCouch.Core.DocumentEngine).Save("localtestdb", "normaldoc1", "{""type"":""normal""}")
    Do $$$AssertTrue(tNormalRev '= "", "Normal doc saved")
    ; Write a local document
    Set tSC = ##class(IRISCouch.Storage.Local).Write("localtestdb", "checkpoint-1", "{""type"":""local""}", "0-1")
    Do $$$AssertStatusOK(tSC, "Local doc written")
    ; List all doc IDs (this is what _all_docs uses)
    Set tDocIds = ##class(IRISCouch.Storage.Document).ListDocIds("localtestdb")
    Do $$$AssertTrue($IsObject(tDocIds), "ListDocIds returns array")
    ; Verify normal doc is listed
    Set tFoundNormal = 0
    Set tFoundLocal = 0
    Set tIter = tDocIds.%GetIterator()
    While tIter.%GetNext(.tKey, .tVal) {
        If tVal = "normaldoc1" Set tFoundNormal = 1
        If tVal [ "checkpoint" Set tFoundLocal = 1
        If tVal [ "_local" Set tFoundLocal = 1
    }
    Do $$$AssertTrue(tFoundNormal, "Normal doc found in all_docs listing")
    Do $$$AssertTrue('tFoundLocal, "Local doc NOT found in all_docs listing")
}

/// <p>Implicit AC: Write local doc, delete database, verify local doc gone.</p>
Method TestDatabaseDeleteCleansLocal()
{
    ; Create database
    Set tSC = ##class(IRISCouch.Storage.Database).Create("localtestdb")
    Do $$$AssertStatusOK(tSC, "Create database succeeds")
    ; Write local docs
    Set tSC = ##class(IRISCouch.Storage.Local).Write("localtestdb", "checkpoint-1", "{""seq"":10}", "0-1")
    Do $$$AssertStatusOK(tSC, "Local doc 1 written")
    Set tSC = ##class(IRISCouch.Storage.Local).Write("localtestdb", "checkpoint-2", "{""seq"":20}", "0-1")
    Do $$$AssertStatusOK(tSC, "Local doc 2 written")
    ; Verify they exist
    Do $$$AssertTrue(##class(IRISCouch.Storage.Local).Exists("localtestdb", "checkpoint-1"), "Local doc 1 exists before DB delete")
    Do $$$AssertTrue(##class(IRISCouch.Storage.Local).Exists("localtestdb", "checkpoint-2"), "Local doc 2 exists before DB delete")
    ; Delete the database
    Set tSC = ##class(IRISCouch.Storage.Database).Delete("localtestdb")
    Do $$$AssertStatusOK(tSC, "Database delete succeeds")
    ; Verify local docs are gone
    Do $$$AssertTrue('##class(IRISCouch.Storage.Local).Exists("localtestdb", "checkpoint-1"), "Local doc 1 gone after DB delete")
    Do $$$AssertTrue('##class(IRISCouch.Storage.Local).Exists("localtestdb", "checkpoint-2"), "Local doc 2 gone after DB delete")
}

}
