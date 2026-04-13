/// <p>Unit tests for IRISCouch longpoll changes feed functionality.</p>
/// <p>Tests <code>$System.Event</code> signaling from <class>IRISCouch.Core.DocumentEngine</class>
/// and longpoll behavior at the storage/engine level. Covers AC #1, #2, #3, #5.</p>
Class IRISCouch.Test.LongpollTest Extends %UnitTest.TestCase
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
    Kill ^IRISCouch.DB("testlongpolldb")
    Kill ^IRISCouch.Docs("testlongpolldb")
    Kill ^IRISCouch.Tree("testlongpolldb")
    Kill ^IRISCouch.Changes("testlongpolldb")
    Kill ^IRISCouch.Seq("testlongpolldb")
    ; Clean up any lingering event resources
    Try { Set tDel = ##class(%SYSTEM.Event).Delete("^IRISCouch.LPChanges(""testlongpolldb"")") } Catch tEx { }
    ; Create fresh test database
    Set tSC = ##class(IRISCouch.Storage.Database).Create("testlongpolldb")
    Quit tSC
}

/// <p>Kill all test database globals after each test.</p>
Method OnAfterOneTest() As %Status
{
    Kill ^IRISCouch.DB("testlongpolldb")
    Kill ^IRISCouch.Docs("testlongpolldb")
    Kill ^IRISCouch.Tree("testlongpolldb")
    Kill ^IRISCouch.Changes("testlongpolldb")
    Kill ^IRISCouch.Seq("testlongpolldb")
    ; Clean up event resources
    Try { Set tDel = ##class(%SYSTEM.Event).Delete("^IRISCouch.LPChanges(""testlongpolldb"")") } Catch tEx { }
    Quit $$$OK
}

/// <p>AC #2: Verify that DocumentEngine.Save() fires a $System.Event signal after write.</p>
/// <p>Creates the event resource first, then saves a doc, then checks for a signal.</p>
Method TestEventSignalOnSave()
{
    ; Create event resource so we can listen for the signal
    Set tEvt = ##class(%SYSTEM.Event).Create("^IRISCouch.LPChanges(""testlongpolldb"")")
    ; Save a document — this should fire the event signal
    Set tRev = ##class(IRISCouch.Core.DocumentEngine).Save("testlongpolldb", "doc1", "{""name"":""Alice""}")
    Do $$$AssertTrue(tRev '= "", "Created doc1 successfully")
    ; Check for the event signal with zero timeout (immediate check)
    Set tResult = ##class(%SYSTEM.Event).WaitMsg("^IRISCouch.LPChanges(""testlongpolldb"")", 0)
    ; WaitMsg returns $lb(msgcount, message) - first element is count of pending messages
    ; A signal means the list is returned (not timeout)
    ; On timeout with no signal, returns $lb(0, "")
    Do $$$AssertTrue($ListGet(tResult, 1) '= 0, "Event signal received after Save()")
}

/// <p>AC #2: Verify that DocumentEngine.SaveDeleted() fires a $System.Event signal.</p>
Method TestEventSignalOnDelete()
{
    ; Create a document first
    Set tRev = ##class(IRISCouch.Core.DocumentEngine).Save("testlongpolldb", "deldoc", "{""data"":""test""}")
    Do $$$AssertTrue(tRev '= "", "Created deldoc")
    ; Create event resource and consume any pending signal from Save
    Set tEvt = ##class(%SYSTEM.Event).Create("^IRISCouch.LPChanges(""testlongpolldb"")")
    Set tDrain = ##class(%SYSTEM.Event).WaitMsg("^IRISCouch.LPChanges(""testlongpolldb"")", 0)
    ; Delete the document — this should fire a new event signal
    Set tDelRev = ##class(IRISCouch.Core.DocumentEngine).SaveDeleted("testlongpolldb", "deldoc", tRev)
    Do $$$AssertTrue(tDelRev '= "", "Deleted deldoc successfully")
    ; Check for the event signal
    Set tResult = ##class(%SYSTEM.Event).WaitMsg("^IRISCouch.LPChanges(""testlongpolldb"")", 0)
    Do $$$AssertTrue($ListGet(tResult, 1) '= 0, "Event signal received after SaveDeleted()")
}

/// <p>AC #5: Verify immediate return when changes exist after since value.</p>
/// <p>Creates 2 docs (changes exist after since=0), checks GetLastSeq > since.</p>
Method TestLongpollImmediateReturn()
{
    ; Create 2 documents
    Set tRev1 = ##class(IRISCouch.Core.DocumentEngine).Save("testlongpolldb", "doc1", "{""v"":1}")
    Do $$$AssertTrue(tRev1 '= "", "Created doc1")
    Set tRev2 = ##class(IRISCouch.Core.DocumentEngine).Save("testlongpolldb", "doc2", "{""v"":2}")
    Do $$$AssertTrue(tRev2 '= "", "Created doc2")
    ; Check that lastSeq > since=0 (should return immediately, no blocking)
    Set tLastSeq = ##class(IRISCouch.Storage.Changes).GetLastSeq("testlongpolldb")
    Do $$$AssertTrue(tLastSeq > 0, "LastSeq > 0 — changes exist after since=0")
    Do $$$AssertEquals(tLastSeq, 2, "LastSeq is 2 after 2 docs")
    ; Verify that ListChanges returns the 2 docs
    Set tChanges = ##class(IRISCouch.Storage.Changes).ListChanges("testlongpolldb", 0)
    Do $$$AssertEquals(tChanges.%Get("results").%Size(), 2, "2 changes returned immediately")
}

/// <p>AC #3: Verify timeout behavior — WaitMsg returns timeout indicator when no signal.</p>
Method TestLongpollTimeout()
{
    ; Create the event resource
    Set tEvt = ##class(%SYSTEM.Event).Create("^IRISCouch.LPChanges(""testlongpolldb"")")
    ; Wait with a very short timeout (1 second) — no signal expected
    Set tResult = ##class(%SYSTEM.Event).WaitMsg("^IRISCouch.LPChanges(""testlongpolldb"")", 1)
    ; On timeout, WaitMsg returns $lb(0, "")
    Do $$$AssertEquals($ListGet(tResult, 1), 0, "WaitMsg timed out (no signal)")
    ; Verify that empty results would be returned (no changes)
    Set tLastSeq = ##class(IRISCouch.Storage.Changes).GetLastSeq("testlongpolldb")
    Do $$$AssertEquals(tLastSeq, 0, "No changes exist — empty results for timeout")
}

/// <p>Verify $System.Event.Create is idempotent — can be called multiple times.</p>
Method TestEventCreate()
{
    ; Call Create multiple times — should not error
    Set tEvt = ##class(%SYSTEM.Event).Create("^IRISCouch.LPChanges(""testlongpolldb"")")
    Set tEvt = ##class(%SYSTEM.Event).Create("^IRISCouch.LPChanges(""testlongpolldb"")")
    Set tEvt = ##class(%SYSTEM.Event).Create("^IRISCouch.LPChanges(""testlongpolldb"")")
    ; Verify the event still works after multiple creates
    Set tEvt = ##class(%SYSTEM.Event).Signal("^IRISCouch.LPChanges(""testlongpolldb"")")
    Set tResult = ##class(%SYSTEM.Event).WaitMsg("^IRISCouch.LPChanges(""testlongpolldb"")", 0)
    Do $$$AssertTrue($ListGet(tResult, 1) '= 0, "Event works after multiple Create calls")
}

}
