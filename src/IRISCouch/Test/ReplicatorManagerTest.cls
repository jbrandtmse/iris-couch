/// <p>Unit tests for IRISCouch _replicator database and replication job management.</p>
/// <p>Tests Manager class methods for document lifecycle, system field injection,
/// cancellation signaling, state updates, and stats population (AC #1-#6).</p>
Class IRISCouch.Test.ReplicatorManagerTest Extends %UnitTest.TestCase
{

/// <p>Handle initvalue parameter from parent class.</p>
Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Quit $$$OK
}

/// <p>Clean up test databases and job globals before each test.</p>
Method OnBeforeOneTest() As %Status
{
    Do ..CleanDB("_replicator")
    Do ..CleanDB("replmgrsrc")
    Do ..CleanDB("replmgrtgt")
    Kill ^IRISCouch.Jobs
    ; Create _replicator database
    Set tSC = ##class(IRISCouch.Storage.Database).Create("_replicator")
    If $$$ISERR(tSC) Quit tSC
    ; Create source and target databases
    Set tSC = ##class(IRISCouch.Storage.Database).Create("replmgrsrc")
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ##class(IRISCouch.Storage.Database).Create("replmgrtgt")
    Quit tSC
}

/// <p>Clean up test databases and job globals after each test.</p>
Method OnAfterOneTest() As %Status
{
    Do ..CleanDB("_replicator")
    Do ..CleanDB("replmgrsrc")
    Do ..CleanDB("replmgrtgt")
    Kill ^IRISCouch.Jobs
    Quit $$$OK
}

/// <p>Clean all globals for a test database.</p>
Method CleanDB(pDB As %String)
{
    Kill ^IRISCouch.DB(pDB)
    Kill ^IRISCouch.Docs(pDB)
    Kill ^IRISCouch.Tree(pDB)
    Kill ^IRISCouch.Changes(pDB)
    Kill ^IRISCouch.Seq(pDB)
    Kill ^IRISCouch.Local(pDB)
    Kill ^IRISCouch.Atts(pDB)
    Kill ^IRISCouch.Proj(pDB)
    Kill ^IRISCouch.MangoIdx(pDB)
    Kill ^IRISCouch.MangoIdxD(pDB)
}

/// <p>AC #1: Verify IsReplicatorDB correctly identifies _replicator database.</p>
Method TestIsReplicatorDB()
{
    Do $$$AssertTrue(##class(IRISCouch.Replication.Manager).IsReplicatorDB("_replicator"), "_replicator returns true")
    Do $$$AssertTrue('##class(IRISCouch.Replication.Manager).IsReplicatorDB("mydb"), "mydb returns false")
    Do $$$AssertTrue('##class(IRISCouch.Replication.Manager).IsReplicatorDB("_users"), "_users returns false")
    Do $$$AssertTrue('##class(IRISCouch.Replication.Manager).IsReplicatorDB(""), "empty string returns false")
    Do $$$AssertTrue('##class(IRISCouch.Replication.Manager).IsReplicatorDB("_replicators"), "_replicators returns false")
}

/// <p>AC #1: Verify OnReplicatorDocSave injects system fields.</p>
Method TestOnReplicatorDocSave()
{
    Set tBody = {}
    Do tBody.%Set("source", "replmgrsrc")
    Do tBody.%Set("target", "replmgrtgt")
    ; Set authenticated user
    Set %IRISCouchUser = "testadmin"
    ; Call the hook
    Set tResult = ##class(IRISCouch.Replication.Manager).OnReplicatorDocSave("_replicator", "rep-doc-1", tBody)
    ; Verify system fields injected
    Do $$$AssertTrue($IsObject(tResult), "Result is an object")
    Do $$$AssertTrue(tResult.%Get("_replication_id") '= "", "_replication_id injected")
    Do $$$AssertEquals(tResult.%Get("owner"), "testadmin", "owner set to authenticated user")
    Do $$$AssertEquals(tResult.%Get("_replication_state"), "triggered", "_replication_state set to triggered")
    Do $$$AssertTrue(tResult.%Get("_replication_state_time") '= "", "_replication_state_time set")
    ; Verify stats initialized
    Set tStats = tResult.%Get("_replication_stats")
    Do $$$AssertTrue($IsObject(tStats), "_replication_stats is an object")
    Do $$$AssertEquals(+tStats.%Get("docs_read"), 0, "docs_read initialized to 0")
    Do $$$AssertEquals(+tStats.%Get("docs_written"), 0, "docs_written initialized to 0")
    Do $$$AssertEquals(+tStats.%Get("doc_write_failures"), 0, "doc_write_failures initialized to 0")
    Do $$$AssertEquals(+tStats.%Get("missing_checked"), 0, "missing_checked initialized to 0")
    Do $$$AssertEquals(+tStats.%Get("missing_found"), 0, "missing_found initialized to 0")
    ; Clean up
    Kill %IRISCouchUser
}

/// <p>AC #1: Verify owner defaults to _admin when no user is authenticated.</p>
Method TestOnReplicatorDocSaveDefaultOwner()
{
    Set tBody = {}
    Do tBody.%Set("source", "replmgrsrc")
    Do tBody.%Set("target", "replmgrtgt")
    ; Clear any authenticated user
    Kill %IRISCouchUser
    ; Call the hook
    Set tResult = ##class(IRISCouch.Replication.Manager).OnReplicatorDocSave("_replicator", "rep-doc-2", tBody)
    Do $$$AssertEquals(tResult.%Get("owner"), "_admin", "owner defaults to _admin")
}

/// <p>AC #1: Verify OnReplicatorDocSave skips docs without source/target.</p>
Method TestOnReplicatorDocSaveSkipsInvalid()
{
    ; Missing source
    Set tBody1 = {}
    Do tBody1.%Set("target", "replmgrtgt")
    Set tResult1 = ##class(IRISCouch.Replication.Manager).OnReplicatorDocSave("_replicator", "invalid-1", tBody1)
    Do $$$AssertTrue(tResult1.%Get("_replication_id") = "", "No _replication_id for missing source")
    ; Missing target
    Set tBody2 = {}
    Do tBody2.%Set("source", "replmgrsrc")
    Set tResult2 = ##class(IRISCouch.Replication.Manager).OnReplicatorDocSave("_replicator", "invalid-2", tBody2)
    Do $$$AssertTrue(tResult2.%Get("_replication_id") = "", "No _replication_id for missing target")
}

/// <p>AC #1: Verify _replication_id is deterministic.</p>
Method TestReplicationIdDeterministic()
{
    Set tBody1 = {}
    Do tBody1.%Set("source", "replmgrsrc")
    Do tBody1.%Set("target", "replmgrtgt")
    Set tResult1 = ##class(IRISCouch.Replication.Manager).OnReplicatorDocSave("_replicator", "det-1", tBody1)
    Set tBody2 = {}
    Do tBody2.%Set("source", "replmgrsrc")
    Do tBody2.%Set("target", "replmgrtgt")
    Set tResult2 = ##class(IRISCouch.Replication.Manager).OnReplicatorDocSave("_replicator", "det-2", tBody2)
    Do $$$AssertEquals(tResult1.%Get("_replication_id"), tResult2.%Get("_replication_id"), "Same source/target produces same _replication_id")
}

/// <p>AC #4: Verify OnReplicatorDocDelete sets cancellation signal.</p>
Method TestOnReplicatorDocDelete()
{
    ; First, create a replicator doc so there is state to cancel
    Set tBody = {}
    Do tBody.%Set("source", "replmgrsrc")
    Do tBody.%Set("target", "replmgrtgt")
    ; Inject system fields
    Set tModified = ##class(IRISCouch.Replication.Manager).OnReplicatorDocSave("_replicator", "cancel-doc", tBody)
    Set tRepId = tModified.%Get("_replication_id")
    ; Save the doc via DocumentEngine so Winners projection has the body
    Set tRev = ##class(IRISCouch.Core.DocumentEngine).Save("_replicator", "cancel-doc", tModified.%ToJSON())
    Do $$$AssertTrue(tRev '= "", "Replicator doc saved")
    ; Set a fake job entry to simulate running job
    Set ^IRISCouch.Jobs(tRepId) = 12345
    ; Call OnReplicatorDocDelete
    Do ##class(IRISCouch.Replication.Manager).OnReplicatorDocDelete("_replicator", "cancel-doc")
    ; Verify cancellation signal set
    Do $$$AssertEquals($Get(^IRISCouch.Jobs(tRepId, "cancel")), 1, "Cancellation signal set")
}

/// <p>AC #5: Verify exponential backoff computation.</p>
Method TestComputeBackoff()
{
    Do $$$AssertEquals(##class(IRISCouch.Replication.Manager).ComputeBackoff(1), 1, "Attempt 1: 1 second")
    Do $$$AssertEquals(##class(IRISCouch.Replication.Manager).ComputeBackoff(2), 2, "Attempt 2: 2 seconds")
    Do $$$AssertEquals(##class(IRISCouch.Replication.Manager).ComputeBackoff(3), 4, "Attempt 3: 4 seconds")
    Do $$$AssertEquals(##class(IRISCouch.Replication.Manager).ComputeBackoff(4), 8, "Attempt 4: 8 seconds")
    Do $$$AssertEquals(##class(IRISCouch.Replication.Manager).ComputeBackoff(5), 16, "Attempt 5: 16 seconds")
    Do $$$AssertEquals(##class(IRISCouch.Replication.Manager).ComputeBackoff(6), 32, "Attempt 6: 32 seconds")
    Do $$$AssertEquals(##class(IRISCouch.Replication.Manager).ComputeBackoff(7), 60, "Attempt 7: 60 seconds (max)")
    Do $$$AssertEquals(##class(IRISCouch.Replication.Manager).ComputeBackoff(10), 60, "Attempt 10: still 60s max")
}

/// <p>AC #2: Verify UpdateReplicatorDoc writes state changes back correctly.</p>
Method TestUpdateReplicatorDoc()
{
    ; Create a replicator doc first
    Set tBody = {}
    Do tBody.%Set("source", "replmgrsrc")
    Do tBody.%Set("target", "replmgrtgt")
    Do tBody.%Set("_replication_state", "triggered")
    Set tRev = ##class(IRISCouch.Core.DocumentEngine).Save("_replicator", "state-doc", tBody.%ToJSON())
    Do $$$AssertTrue(tRev '= "", "State doc saved")
    ; Now update state to "completed" with stats
    Set tStats = {}
    Do tStats.%Set("docs_read", 5, "number")
    Do tStats.%Set("docs_written", 3, "number")
    Do tStats.%Set("doc_write_failures", 0, "number")
    Do tStats.%Set("missing_checked", 5, "number")
    Do tStats.%Set("missing_found", 3, "number")
    Do ##class(IRISCouch.Replication.Manager).UpdateReplicatorDoc("_replicator", "state-doc", "completed", tStats)
    ; Read back and verify
    Set tWinnerRev = ##class(IRISCouch.Storage.RevTree).GetWinner("_replicator", "state-doc")
    Do $$$AssertTrue(tWinnerRev '= "", "Winner rev exists after update")
    Do $$$AssertTrue(tWinnerRev '= tRev, "Revision advanced after update")
    Set tUpdatedBody = ##class(IRISCouch.Storage.Document).Read("_replicator", "state-doc", tWinnerRev)
    Do $$$AssertTrue(tUpdatedBody '= "", "Updated body readable")
    Set tUpdatedDoc = ##class(%DynamicObject).%FromJSON(tUpdatedBody)
    Do $$$AssertEquals(tUpdatedDoc.%Get("_replication_state"), "completed", "State updated to completed")
    Do $$$AssertTrue(tUpdatedDoc.%Get("_replication_state_time") '= "", "State time updated")
    Set tUpdatedStats = tUpdatedDoc.%Get("_replication_stats")
    Do $$$AssertTrue($IsObject(tUpdatedStats), "Stats object present")
    Do $$$AssertEquals(+tUpdatedStats.%Get("docs_read"), 5, "Stats docs_read correct")
    Do $$$AssertEquals(+tUpdatedStats.%Get("docs_written"), 3, "Stats docs_written correct")
}

/// <p>AC #5: Verify error state update with error details.</p>
Method TestErrorState()
{
    ; Create a replicator doc pointing to non-existent source
    Set tBody = {}
    Do tBody.%Set("source", "nonexistdb")
    Do tBody.%Set("target", "replmgrtgt")
    Do tBody.%Set("_replication_state", "triggered")
    Set tRev = ##class(IRISCouch.Core.DocumentEngine).Save("_replicator", "err-doc", tBody.%ToJSON())
    Do $$$AssertTrue(tRev '= "", "Error test doc saved")
    ; Simulate error update
    Set tErrStats = {}
    Do tErrStats.%Set("docs_read", 0, "number")
    Do tErrStats.%Set("docs_written", 0, "number")
    Do tErrStats.%Set("doc_write_failures", 0, "number")
    Do tErrStats.%Set("error", "Source database does not exist: nonexistdb")
    Do ##class(IRISCouch.Replication.Manager).UpdateReplicatorDoc("_replicator", "err-doc", "error", tErrStats)
    ; Read back and verify error state
    Set tWinnerRev = ##class(IRISCouch.Storage.RevTree).GetWinner("_replicator", "err-doc")
    Set tUpdatedBody = ##class(IRISCouch.Storage.Document).Read("_replicator", "err-doc", tWinnerRev)
    Set tUpdatedDoc = ##class(%DynamicObject).%FromJSON(tUpdatedBody)
    Do $$$AssertEquals(tUpdatedDoc.%Get("_replication_state"), "error", "State is error")
    Set tUpdatedStats = tUpdatedDoc.%Get("_replication_stats")
    Do $$$AssertTrue($IsObject(tUpdatedStats), "Error stats present")
    Do $$$AssertTrue(tUpdatedStats.%Get("error") '= "", "Error message present in stats")
}

/// <p>AC #2: Verify stats are populated after replication via Replicate().</p>
Method TestStatsPopulated()
{
    ; Create documents in source
    Set tRev1 = ##class(IRISCouch.Core.DocumentEngine).Save("replmgrsrc", "sdoc1", "{""name"":""Alice""}")
    Do $$$AssertTrue(tRev1 '= "", "Source doc1 created")
    Set tRev2 = ##class(IRISCouch.Core.DocumentEngine).Save("replmgrsrc", "sdoc2", "{""name"":""Bob""}")
    Do $$$AssertTrue(tRev2 '= "", "Source doc2 created")
    Set tRev3 = ##class(IRISCouch.Core.DocumentEngine).Save("replmgrsrc", "sdoc3", "{""name"":""Charlie""}")
    Do $$$AssertTrue(tRev3 '= "", "Source doc3 created")
    ; Replicate with stats output
    Set tSC = ##class(IRISCouch.Replication.Replicator).Replicate("replmgrsrc", "replmgrtgt", "", .tStats)
    Do $$$AssertStatusOK(tSC, "Replication succeeds")
    ; Verify stats populated
    Do $$$AssertTrue($IsObject(tStats), "Stats object returned")
    Do $$$AssertEquals(+tStats.%Get("docs_read"), 3, "docs_read = 3")
    Do $$$AssertEquals(+tStats.%Get("docs_written"), 3, "docs_written = 3")
    Do $$$AssertEquals(+tStats.%Get("doc_write_failures"), 0, "doc_write_failures = 0")
    Do $$$AssertTrue(+tStats.%Get("missing_checked") >= 3, "missing_checked >= 3")
    Do $$$AssertEquals(+tStats.%Get("missing_found"), 3, "missing_found = 3")
}

/// <p>AC #2: Verify stats for empty replication (no changes).</p>
Method TestStatsEmptyReplication()
{
    ; No documents in source — replicate empty databases
    Set tSC = ##class(IRISCouch.Replication.Replicator).Replicate("replmgrsrc", "replmgrtgt", "", .tStats)
    Do $$$AssertStatusOK(tSC, "Empty replication succeeds")
    Do $$$AssertTrue($IsObject(tStats), "Stats object returned for empty replication")
    Do $$$AssertEquals(+tStats.%Get("docs_read"), 0, "docs_read = 0 for empty")
    Do $$$AssertEquals(+tStats.%Get("docs_written"), 0, "docs_written = 0 for empty")
}

/// <p>AC #1: Verify DocumentEngine.Save triggers _replicator hook and injects fields.</p>
Method TestDocEngineReplicatorHook()
{
    ; Save a replicator doc via DocumentEngine (which should trigger the hook)
    Set tBody = {}
    Do tBody.%Set("source", "replmgrsrc")
    Do tBody.%Set("target", "replmgrtgt")
    Set tRev = ##class(IRISCouch.Core.DocumentEngine).Save("_replicator", "hook-doc", tBody.%ToJSON())
    Do $$$AssertTrue(tRev '= "", "Replicator doc saved via DocumentEngine")
    ; Read the stored body (should have system fields injected)
    Set tStoredBody = ##class(IRISCouch.Storage.Document).Read("_replicator", "hook-doc", tRev)
    Do $$$AssertTrue(tStoredBody '= "", "Stored body readable")
    Set tStoredDoc = ##class(%DynamicObject).%FromJSON(tStoredBody)
    Do $$$AssertTrue(tStoredDoc.%Get("_replication_id") '= "", "DocumentEngine hook injected _replication_id")
    Do $$$AssertEquals(tStoredDoc.%Get("_replication_state"), "triggered", "DocumentEngine hook set state to triggered")
    Do $$$AssertTrue(tStoredDoc.%Get("_replication_state_time") '= "", "DocumentEngine hook set state time")
    Do $$$AssertTrue($IsObject(tStoredDoc.%Get("_replication_stats")), "DocumentEngine hook initialized stats")
}

/// <p>AC #1: Verify recursion prevention flag works during state updates.</p>
Method TestRecursionPrevention()
{
    ; Save initial doc
    Set tBody = {}
    Do tBody.%Set("source", "replmgrsrc")
    Do tBody.%Set("target", "replmgrtgt")
    Do tBody.%Set("_replication_state", "triggered")
    Set tRev = ##class(IRISCouch.Core.DocumentEngine).Save("_replicator", "recurse-doc", tBody.%ToJSON())
    Do $$$AssertTrue(tRev '= "", "Recursion test doc saved")
    ; UpdateReplicatorDoc uses %IRISCouchReplicatorUpdate flag to prevent re-triggering
    Do ##class(IRISCouch.Replication.Manager).UpdateReplicatorDoc("_replicator", "recurse-doc", "completed", "")
    ; Verify the flag is cleared after call
    Do $$$AssertTrue($Get(%IRISCouchReplicatorUpdate, 0) = 0, "Recursion flag cleared after update")
    ; Verify state was updated without re-triggering hooks
    Set tWinnerRev = ##class(IRISCouch.Storage.RevTree).GetWinner("_replicator", "recurse-doc")
    Set tUpdatedBody = ##class(IRISCouch.Storage.Document).Read("_replicator", "recurse-doc", tWinnerRev)
    Set tUpdatedDoc = ##class(%DynamicObject).%FromJSON(tUpdatedBody)
    Do $$$AssertEquals(tUpdatedDoc.%Get("_replication_state"), "completed", "State updated to completed")
}

/// <p>AC #1: Verify StopJob sets cancellation global.</p>
Method TestStopJob()
{
    Set tRepId = "test-rep-id-001"
    Set ^IRISCouch.Jobs(tRepId) = 99999
    Do $$$AssertTrue($Get(^IRISCouch.Jobs(tRepId, "cancel"), 0) = 0, "Cancel flag not set initially")
    Do ##class(IRISCouch.Replication.Manager).StopJob(tRepId)
    Do $$$AssertEquals($Get(^IRISCouch.Jobs(tRepId, "cancel")), 1, "Cancel flag set after StopJob")
}

/// <p>AC #1: Verify BuildOptionsFromBody extracts correct fields.</p>
Method TestBuildOptionsFromBody()
{
    Set tBody = {}
    Do tBody.%Set("source", "src")
    Do tBody.%Set("target", "tgt")
    Do tBody.%Set("continuous", 1, "boolean")
    Do tBody.%Set("create_target", 1, "boolean")
    Do tBody.%Set("filter", "myfilter")
    Do tBody.%Set("extra_field", "ignored")
    Set tOpts = ##class(IRISCouch.Replication.Manager).BuildOptionsFromBody(tBody)
    Do $$$AssertTrue($IsObject(tOpts), "Options object returned")
    Do $$$AssertTrue(tOpts.%Get("continuous") = 1, "continuous extracted")
    Do $$$AssertTrue(tOpts.%Get("create_target") = 1, "create_target extracted")
    Do $$$AssertEquals(tOpts.%Get("filter"), "myfilter", "filter extracted")
    Do $$$AssertTrue('tOpts.%IsDefined("source"), "source not in options")
    Do $$$AssertTrue('tOpts.%IsDefined("extra_field"), "extra_field not in options")
}

/// <p>AC #1: Verify design documents are skipped by OnReplicatorDocSave.</p>
Method TestSkipDesignDocs()
{
    Set tBody = {}
    Do tBody.%Set("source", "replmgrsrc")
    Do tBody.%Set("target", "replmgrtgt")
    Set tResult = ##class(IRISCouch.Replication.Manager).OnReplicatorDocSave("_replicator", "_design/mydesign", tBody)
    Do $$$AssertTrue(tResult.%Get("_replication_id") = "", "Design docs do not get _replication_id")
    Do $$$AssertTrue(tResult.%Get("_replication_state") = "", "Design docs do not get state")
}

/// <p>AC #2: Verify BuildStatsObject creates proper structure.</p>
Method TestBuildStatsObject()
{
    ; Test with populated stats
    Set tInputStats = {}
    Do tInputStats.%Set("docs_read", 10, "number")
    Do tInputStats.%Set("docs_written", 8, "number")
    Do tInputStats.%Set("doc_write_failures", 2, "number")
    Do tInputStats.%Set("missing_checked", 12, "number")
    Do tInputStats.%Set("missing_found", 10, "number")
    Set tResult = ##class(IRISCouch.Replication.Manager).BuildStatsObject(tInputStats)
    Do $$$AssertEquals(+tResult.%Get("docs_read"), 10, "docs_read correct")
    Do $$$AssertEquals(+tResult.%Get("docs_written"), 8, "docs_written correct")
    Do $$$AssertEquals(+tResult.%Get("doc_write_failures"), 2, "doc_write_failures correct")
    Do $$$AssertEquals(+tResult.%Get("missing_checked"), 12, "missing_checked correct")
    Do $$$AssertEquals(+tResult.%Get("missing_found"), 10, "missing_found correct")
    ; Test with empty/no stats
    Set tResult2 = ##class(IRISCouch.Replication.Manager).BuildStatsObject("")
    Do $$$AssertEquals(+tResult2.%Get("docs_read"), 0, "Empty stats: docs_read = 0")
    Do $$$AssertEquals(+tResult2.%Get("docs_written"), 0, "Empty stats: docs_written = 0")
}

}
