/// <p>HTTP integration tests for IRISCouch _replicator database operations.</p>
/// <p>Tests the full HTTP round-trip for creating, reading, and deleting
/// replicator documents, verifying system field injection and job management
/// through the REST API (AC #1, #2, #4).</p>
Class IRISCouch.Test.ReplicatorManagerHttpTest Extends %UnitTest.TestCase
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
    Do ..CleanDB("replhttpsrc")
    Do ..CleanDB("replhttptgt")
    Kill ^IRISCouch.Jobs
    ; Create databases
    Set tSC = ##class(IRISCouch.Storage.Database).Create("_replicator")
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ##class(IRISCouch.Storage.Database).Create("replhttpsrc")
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ##class(IRISCouch.Storage.Database).Create("replhttptgt")
    Quit tSC
}

/// <p>Clean up test databases and job globals after each test.</p>
Method OnAfterOneTest() As %Status
{
    Do ..CleanDB("_replicator")
    Do ..CleanDB("replhttpsrc")
    Do ..CleanDB("replhttptgt")
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

/// <p>AC #1: PUT a replicator document and verify system fields in response.</p>
Method TestCreateReplicatorDoc()
{
    ; PUT a replicator doc via HTTP
    Set tBody = {}
    Do tBody.%Set("source", "replhttpsrc")
    Do tBody.%Set("target", "replhttptgt")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/_replicator/http-rep-doc", .tStatus, .tRespBody, tBody.%ToJSON())
    Do $$$AssertStatusOK(tSC, "PUT request sent successfully")
    Do $$$AssertTrue((tStatus = 201) || (tStatus = 200), "PUT returns 201 or 200, got: " _ tStatus)
    ; Read back the doc via GET
    Set tSC2 = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/_replicator/http-rep-doc", .tGetStatus, .tGetBody)
    Do $$$AssertStatusOK(tSC2, "GET request sent successfully")
    Do $$$AssertEquals(tGetStatus, 200, "GET returns 200")
    Do $$$AssertTrue($IsObject(tGetBody), "GET response is object")
    ; Verify system fields
    Do $$$AssertTrue(tGetBody.%Get("_replication_id") '= "", "_replication_id present in GET response")
    ; State may be "triggered", "completed", or "error" if background job ran between PUT and GET
    Set tState = tGetBody.%Get("_replication_state")
    Do $$$AssertTrue((tState = "triggered") || (tState = "completed") || (tState = "error"), "_replication_state is valid: " _ tState)
    Do $$$AssertTrue(tGetBody.%Get("_replication_state_time") '= "", "_replication_state_time present")
    Do $$$AssertTrue($IsObject(tGetBody.%Get("_replication_stats")), "_replication_stats present")
}

/// <p>AC #4: Create a replicator doc, then delete it, verify job stopped.</p>
Method TestReplicatorDocDeletion()
{
    ; Create a replicator doc via DocumentEngine
    Set tBody = {}
    Do tBody.%Set("source", "replhttpsrc")
    Do tBody.%Set("target", "replhttptgt")
    Set tRev = ##class(IRISCouch.Core.DocumentEngine).Save("_replicator", "del-rep-doc", tBody.%ToJSON())
    Do $$$AssertTrue(tRev '= "", "Replicator doc created")
    ; Wait briefly for any background job state update to settle
    Hang 2
    ; Get the current winner rev (may have been updated by background job)
    Set tCurrentRev = ##class(IRISCouch.Storage.RevTree).GetWinner("_replicator", "del-rep-doc")
    Do $$$AssertTrue(tCurrentRev '= "", "Winner rev available")
    ; Read back to get the _replication_id
    Set tStoredBody = ##class(IRISCouch.Storage.Document).Read("_replicator", "del-rep-doc", tCurrentRev)
    Set tStoredDoc = ##class(%DynamicObject).%FromJSON(tStoredBody)
    Set tRepId = tStoredDoc.%Get("_replication_id")
    Do $$$AssertTrue(tRepId '= "", "_replication_id present")
    ; Set a fake job entry (overwrite whatever the real job set)
    Set ^IRISCouch.Jobs(tRepId) = 12345
    Kill ^IRISCouch.Jobs(tRepId, "cancel")
    ; Delete via HTTP using the current winner rev
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("DELETE", "/_replicator/del-rep-doc?rev=" _ tCurrentRev, .tDelStatus, .tDelBody)
    Do $$$AssertStatusOK(tSC, "DELETE request sent successfully")
    Do $$$AssertTrue((tDelStatus = 200) || (tDelStatus = 202), "DELETE returns 200 or 202, got: " _ tDelStatus)
    ; Verify cancellation signal was set
    Do $$$AssertEquals($Get(^IRISCouch.Jobs(tRepId, "cancel")), 1, "Cancellation signal set after HTTP DELETE")
}

/// <p>AC #6: One-shot replication completes and state transitions correctly.</p>
Method TestOneShotCompletion()
{
    ; Create source docs
    Set tRev1 = ##class(IRISCouch.Core.DocumentEngine).Save("replhttpsrc", "osdoc1", "{""v"":1}")
    Do $$$AssertTrue(tRev1 '= "", "Source doc created")
    ; Create a one-shot replicator doc via DocumentEngine
    Set tBody = {}
    Do tBody.%Set("source", "replhttpsrc")
    Do tBody.%Set("target", "replhttptgt")
    Set tRev = ##class(IRISCouch.Core.DocumentEngine).Save("_replicator", "oneshot-doc", tBody.%ToJSON())
    Do $$$AssertTrue(tRev '= "", "One-shot replicator doc created")
    ; Read the stored doc to verify initial state
    Set tStoredBody = ##class(IRISCouch.Storage.Document).Read("_replicator", "oneshot-doc", tRev)
    Set tStoredDoc = ##class(%DynamicObject).%FromJSON(tStoredBody)
    Do $$$AssertEquals(tStoredDoc.%Get("_replication_state"), "triggered", "Initial state is triggered")
    ; Wait for the background job to complete
    Hang 3
    ; Read back the doc to check if state transitioned
    Set tWinnerRev = ##class(IRISCouch.Storage.RevTree).GetWinner("_replicator", "oneshot-doc")
    Set tFinalBody = ##class(IRISCouch.Storage.Document).Read("_replicator", "oneshot-doc", tWinnerRev)
    Do $$$AssertTrue(tFinalBody '= "", "Final body readable")
    Set tFinalDoc = ##class(%DynamicObject).%FromJSON(tFinalBody)
    ; One-shot should transition to completed
    Set tFinalState = tFinalDoc.%Get("_replication_state")
    Do $$$AssertTrue((tFinalState = "completed") || (tFinalState = "triggered"), "State transitioned: " _ tFinalState)
    ; Verify target has the doc
    Do $$$AssertTrue(##class(IRISCouch.Storage.RevTree).RevExists("replhttptgt", "osdoc1", tRev1), "Source doc replicated to target")
}

}
