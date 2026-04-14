/// <p>Unit tests for IRISCouch replication checkpoint management.</p>
/// <p>Tests checkpoint read/write, common ancestry detection, and
/// checkpoint document building (AC #4).</p>
Class IRISCouch.Test.CheckpointTest Extends %UnitTest.TestCase
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
    Kill ^IRISCouch.DB("ckpttest")
    Kill ^IRISCouch.Docs("ckpttest")
    Kill ^IRISCouch.Tree("ckpttest")
    Kill ^IRISCouch.Changes("ckpttest")
    Kill ^IRISCouch.Seq("ckpttest")
    Kill ^IRISCouch.Local("ckpttest")
    Kill ^IRISCouch.Proj("ckpttest")
    Kill ^IRISCouch.MangoIdx("ckpttest")
    Set tSC = ##class(IRISCouch.Storage.Database).Create("ckpttest")
    Quit tSC
}

/// <p>Clean up test globals after each test.</p>
Method OnAfterOneTest() As %Status
{
    Kill ^IRISCouch.DB("ckpttest")
    Kill ^IRISCouch.Docs("ckpttest")
    Kill ^IRISCouch.Tree("ckpttest")
    Kill ^IRISCouch.Changes("ckpttest")
    Kill ^IRISCouch.Seq("ckpttest")
    Kill ^IRISCouch.Local("ckpttest")
    Kill ^IRISCouch.Proj("ckpttest")
    Kill ^IRISCouch.MangoIdx("ckpttest")
    Quit $$$OK
}

/// <p>AC #4: Write a checkpoint then read it back, verify content.</p>
Method TestReadWriteLocal()
{
    Set tRepId = "testreplicationid123"
    Set tSessionId = "session-abc-123"
    Set tHistory = []
    Set tEntry = {}
    Do tEntry.%Set("session_id", tSessionId)
    Do tEntry.%Set("recorded_seq", 10, "number")
    Do tHistory.%Push(tEntry)
    ; Build and write checkpoint
    Set tCheckpoint = ##class(IRISCouch.Replication.Checkpoint).BuildCheckpointDoc(tRepId, tSessionId, 10, tHistory)
    Set tSC = ##class(IRISCouch.Replication.Checkpoint).Write("ckpttest", tRepId, tCheckpoint, 1)
    Do $$$AssertStatusOK(tSC, "Checkpoint write succeeds")
    ; Read it back
    Set tRead = ##class(IRISCouch.Replication.Checkpoint).Read("ckpttest", tRepId, 1)
    Do $$$AssertTrue($IsObject(tRead), "Checkpoint read returns object")
    Do $$$AssertEquals(tRead.%Get("session_id"), tSessionId, "Session ID matches")
    Do $$$AssertEquals(+tRead.%Get("source_last_seq"), 10, "source_last_seq matches")
    Do $$$AssertEquals(+tRead.%Get("replication_id_version"), 3, "replication_id_version is 3")
    ; Verify history
    Set tReadHistory = tRead.%Get("history")
    Do $$$AssertTrue($IsObject(tReadHistory), "History is present")
    Do $$$AssertEquals(tReadHistory.%Size(), 1, "History has 1 entry")
    Do $$$AssertEquals(tReadHistory.%Get(0).%Get("session_id"), tSessionId, "History session_id matches")
}

/// <p>AC #4: Matching session_id at top level returns source_last_seq.</p>
Method TestFindCommonAncestryMatch()
{
    Set tSessionId = "session-match-001"
    Set tSourceCkpt = {}
    Do tSourceCkpt.%Set("session_id", tSessionId)
    Do tSourceCkpt.%Set("source_last_seq", 25, "number")
    Do tSourceCkpt.%Set("history", [])
    Set tTargetCkpt = {}
    Do tTargetCkpt.%Set("session_id", tSessionId)
    Do tTargetCkpt.%Set("source_last_seq", 25, "number")
    Do tTargetCkpt.%Set("history", [])
    Set tResult = ##class(IRISCouch.Replication.Checkpoint).FindCommonAncestry(tSourceCkpt, tTargetCkpt)
    Do $$$AssertEquals(+tResult, 25, "Matching top-level session returns source_last_seq 25")
}

/// <p>AC #4: Common session found in history arrays returns recorded_seq.</p>
Method TestFindCommonAncestryHistory()
{
    Set tCommonSession = "session-shared-002"
    ; Source: different top-level session, but shared history entry
    Set tSourceCkpt = {}
    Do tSourceCkpt.%Set("session_id", "session-source-new")
    Do tSourceCkpt.%Set("source_last_seq", 50, "number")
    Set tSourceHist = []
    Set tSH1 = {}
    Do tSH1.%Set("session_id", "session-source-new")
    Do tSH1.%Set("recorded_seq", 50, "number")
    Do tSourceHist.%Push(tSH1)
    Set tSH2 = {}
    Do tSH2.%Set("session_id", tCommonSession)
    Do tSH2.%Set("recorded_seq", 20, "number")
    Do tSourceHist.%Push(tSH2)
    Do tSourceCkpt.%Set("history", tSourceHist)
    ; Target: different top-level session, but shared history entry
    Set tTargetCkpt = {}
    Do tTargetCkpt.%Set("session_id", "session-target-new")
    Do tTargetCkpt.%Set("source_last_seq", 30, "number")
    Set tTargetHist = []
    Set tTH1 = {}
    Do tTH1.%Set("session_id", "session-target-new")
    Do tTH1.%Set("recorded_seq", 30, "number")
    Do tTargetHist.%Push(tTH1)
    Set tTH2 = {}
    Do tTH2.%Set("session_id", tCommonSession)
    Do tTH2.%Set("recorded_seq", 20, "number")
    Do tTargetHist.%Push(tTH2)
    Do tTargetCkpt.%Set("history", tTargetHist)
    Set tResult = ##class(IRISCouch.Replication.Checkpoint).FindCommonAncestry(tSourceCkpt, tTargetCkpt)
    Do $$$AssertEquals(+tResult, 20, "Common history session returns recorded_seq 20")
}

/// <p>AC #4: No common ancestry returns "0" for full replication.</p>
Method TestFindCommonAncestryNone()
{
    Set tSourceCkpt = {}
    Do tSourceCkpt.%Set("session_id", "session-A")
    Do tSourceCkpt.%Set("source_last_seq", 15, "number")
    Set tSourceHist = []
    Set tSH1 = {}
    Do tSH1.%Set("session_id", "session-A")
    Do tSH1.%Set("recorded_seq", 15, "number")
    Do tSourceHist.%Push(tSH1)
    Do tSourceCkpt.%Set("history", tSourceHist)
    Set tTargetCkpt = {}
    Do tTargetCkpt.%Set("session_id", "session-B")
    Do tTargetCkpt.%Set("source_last_seq", 10, "number")
    Set tTargetHist = []
    Set tTH1 = {}
    Do tTH1.%Set("session_id", "session-B")
    Do tTH1.%Set("recorded_seq", 10, "number")
    Do tTargetHist.%Push(tTH1)
    Do tTargetCkpt.%Set("history", tTargetHist)
    Set tResult = ##class(IRISCouch.Replication.Checkpoint).FindCommonAncestry(tSourceCkpt, tTargetCkpt)
    Do $$$AssertEquals(tResult, "0", "No common ancestry returns 0 (full replication)")
}

/// <p>AC #4: Missing checkpoints (empty strings) return "0".</p>
Method TestFindCommonAncestryMissing()
{
    ; Both empty
    Set tResult1 = ##class(IRISCouch.Replication.Checkpoint).FindCommonAncestry("", "")
    Do $$$AssertEquals(tResult1, "0", "Both empty checkpoints return 0")
    ; Source empty
    Set tTargetCkpt = {}
    Do tTargetCkpt.%Set("session_id", "session-1")
    Do tTargetCkpt.%Set("source_last_seq", 5, "number")
    Set tResult2 = ##class(IRISCouch.Replication.Checkpoint).FindCommonAncestry("", tTargetCkpt)
    Do $$$AssertEquals(tResult2, "0", "Empty source checkpoint returns 0")
}

/// <p>Verify BuildCheckpointDoc creates proper structure.</p>
Method TestBuildCheckpointDoc()
{
    Set tRepId = "rep-doc-test-id"
    Set tSessionId = "session-build-001"
    Set tHistory = []
    Set tDoc = ##class(IRISCouch.Replication.Checkpoint).BuildCheckpointDoc(tRepId, tSessionId, 42, tHistory)
    Do $$$AssertTrue($IsObject(tDoc), "BuildCheckpointDoc returns object")
    Do $$$AssertEquals(tDoc.%Get("_id"), "_local/rep-doc-test-id", "_id is _local/{repId}")
    Do $$$AssertEquals(+tDoc.%Get("replication_id_version"), 3, "replication_id_version is 3")
    Do $$$AssertEquals(tDoc.%Get("session_id"), tSessionId, "session_id matches")
    Do $$$AssertEquals(+tDoc.%Get("source_last_seq"), 42, "source_last_seq is 42")
    Do $$$AssertTrue($IsObject(tDoc.%Get("history")), "history is present")
}

/// <p>AC #4: Read non-existent checkpoint returns empty string.</p>
Method TestReadNonExistent()
{
    Set tResult = ##class(IRISCouch.Replication.Checkpoint).Read("ckpttest", "nonexistent-rep-id", 1)
    Do $$$AssertTrue('$IsObject(tResult), "Non-existent checkpoint returns empty string")
}

}
