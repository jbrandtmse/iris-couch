/// <p>HTTP integration tests for IRISCouch _changes endpoint.</p>
/// <p>Tests <code>GET /{db}/_changes</code> and <code>POST /{db}/_changes</code>
/// via live HTTP requests. Covers AC #1, #2, #3, #4, #5, #6, #7.</p>
Class IRISCouch.Test.ChangesHttpTest Extends %UnitTest.TestCase
{

/// <p>Handle initvalue parameter from parent class.</p>
Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Quit $$$OK
}

/// <p>Create a test database before each test.</p>
Method OnBeforeOneTest() As %Status
{
    ; Clean up any previous state
    Kill ^IRISCouch.DB("testchangeshttpdb")
    Kill ^IRISCouch.Docs("testchangeshttpdb")
    Kill ^IRISCouch.Tree("testchangeshttpdb")
    Kill ^IRISCouch.Changes("testchangeshttpdb")
    Kill ^IRISCouch.Seq("testchangeshttpdb")
    ; Create test database
    Set tSC = ##class(IRISCouch.Storage.Database).Create("testchangeshttpdb")
    Quit tSC
}

/// <p>Delete test database and kill all globals after each test.</p>
Method OnAfterOneTest() As %Status
{
    Kill ^IRISCouch.DB("testchangeshttpdb")
    Kill ^IRISCouch.Docs("testchangeshttpdb")
    Kill ^IRISCouch.Tree("testchangeshttpdb")
    Kill ^IRISCouch.Changes("testchangeshttpdb")
    Kill ^IRISCouch.Seq("testchangeshttpdb")
    Quit $$$OK
}

/// <p>AC #1: GET /_changes returns 200 with results array, last_seq, pending.</p>
Method TestChangesGetHttp()
{
    ; Create 2 docs via HTTP
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testchangeshttpdb/doc1", .tStatus, .tBody, "{""name"":""Alice""}")
    Do $$$AssertEquals(tStatus, 201, "Created doc1")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testchangeshttpdb/doc2", .tStatus, .tBody, "{""name"":""Bob""}")
    Do $$$AssertEquals(tStatus, 201, "Created doc2")
    ; GET _changes
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/testchangeshttpdb/_changes", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "GET /_changes request completed")
    Do $$$AssertEquals(tStatus, 200, "GET /_changes returns 200")
    Do $$$AssertTrue($IsObject(tBody), "Response is JSON object")
    Do $$$AssertTrue($IsObject(tBody.results), "results is present")
    Do $$$AssertEquals(tBody.results.%Size(), 2, "2 results returned")
    ; Verify each entry has seq, id, changes
    Set tEntry0 = tBody.results.%Get(0)
    Do $$$AssertTrue(tEntry0.seq > 0, "Entry has seq")
    Do $$$AssertTrue(tEntry0.id '= "", "Entry has id")
    Do $$$AssertTrue($IsObject(tEntry0.changes), "Entry has changes array")
    Do $$$AssertTrue(tEntry0.changes.%Get(0).rev '= "", "Change has rev")
    ; Verify last_seq and pending
    Do $$$AssertTrue(tBody."last_seq" > 0, "last_seq is present")
    Do $$$AssertEquals(tBody.pending, 0, "pending is 0")
}

/// <p>AC #2: GET /_changes?since=1 returns only changes after seq 1.</p>
Method TestChangesSinceHttp()
{
    ; Create 3 docs
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testchangeshttpdb/doc1", .tStatus, .tBody, "{""v"":1}")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testchangeshttpdb/doc2", .tStatus, .tBody, "{""v"":2}")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testchangeshttpdb/doc3", .tStatus, .tBody, "{""v"":3}")
    ; GET _changes?since=1
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/testchangeshttpdb/_changes?since=1", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "GET /_changes?since=1 completed")
    Do $$$AssertEquals(tStatus, 200, "Returns 200")
    Do $$$AssertEquals(tBody.results.%Size(), 2, "2 results returned (seq > 1)")
}

/// <p>AC #3: GET /_changes?limit=1 returns 1 result with correct pending.</p>
Method TestChangesLimitHttp()
{
    ; Create 3 docs
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testchangeshttpdb/doc1", .tStatus, .tBody, "{""v"":1}")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testchangeshttpdb/doc2", .tStatus, .tBody, "{""v"":2}")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testchangeshttpdb/doc3", .tStatus, .tBody, "{""v"":3}")
    ; GET _changes?limit=1
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/testchangeshttpdb/_changes?limit=1", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "GET /_changes?limit=1 completed")
    Do $$$AssertEquals(tStatus, 200, "Returns 200")
    Do $$$AssertEquals(tBody.results.%Size(), 1, "1 result returned")
    Do $$$AssertEquals(tBody.pending, 2, "pending is 2")
}

/// <p>AC #4: GET /_changes?include_docs=true returns doc field with full body.</p>
Method TestChangesIncludeDocsHttp()
{
    ; Create doc with known body
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testchangeshttpdb/mydoc", .tStatus, .tBody, "{""name"":""Alice""}")
    Do $$$AssertEquals(tStatus, 201, "Created doc mydoc")
    ; GET _changes?include_docs=true
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/testchangeshttpdb/_changes?include_docs=true", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "GET /_changes?include_docs=true completed")
    Do $$$AssertEquals(tStatus, 200, "Returns 200")
    Set tEntry = tBody.results.%Get(0)
    Do $$$AssertTrue($IsObject(tEntry.doc), "Entry has doc field")
    Do $$$AssertEquals(tEntry.doc."_id", "mydoc", "doc has _id")
    Do $$$AssertTrue(tEntry.doc."_rev" '= "", "doc has _rev")
    Do $$$AssertEquals(tEntry.doc.name, "Alice", "doc has body field name")
}

/// <p>AC #5: GET /_changes?style=all_docs returns all leaf revisions for conflicted doc.</p>
Method TestChangesStyleAllDocsHttp()
{
    ; Create a document
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testchangeshttpdb/conflicted", .tStatus, .tBody, "{""v"":1}")
    Do $$$AssertEquals(tStatus, 201, "Created doc conflicted")
    Set tRev1 = tBody.rev
    ; Create a conflict by adding a branch via engine
    Set tSC2 = ##class(IRISCouch.Storage.RevTree).AddBranch("testchangeshttpdb", "conflicted", tRev1, "2-conflictbranch")
    Do $$$AssertStatusOK(tSC2, "Added conflict branch")
    ; Write the branch doc body
    Set tSC3 = ##class(IRISCouch.Storage.Document).Write("testchangeshttpdb", "conflicted", "2-conflictbranch", "{""v"":""conflict""}")
    Do $$$AssertStatusOK(tSC3, "Wrote conflict body")
    ; GET _changes?style=all_docs
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/testchangeshttpdb/_changes?style=all_docs", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "GET /_changes?style=all_docs completed")
    Do $$$AssertEquals(tStatus, 200, "Returns 200")
    ; Find the conflicted doc entry — it should have 2 leaf revisions in changes
    Set tFound = 0
    Set tI = 0
    While tI < tBody.results.%Size() {
        Set tEntry = tBody.results.%Get(tI)
        Set tI = tI + 1
        If tEntry.id = "conflicted" {
            If tEntry.changes.%Size() = 2 {
                Set tFound = 1
            }
        }
    }
    Do $$$AssertTrue(tFound, "Conflicted doc has 2 leaf revisions in changes array")
}

/// <p>AC #7: POST /_changes with body returns same results as GET.</p>
Method TestChangesPostHttp()
{
    ; Create 2 docs
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testchangeshttpdb/doc1", .tStatus, .tBody, "{""v"":1}")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testchangeshttpdb/doc2", .tStatus, .tBody, "{""v"":2}")
    ; POST _changes with body
    Set tReqBody = "{""since"":0,""limit"":1}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("POST", "/testchangeshttpdb/_changes", .tStatus, .tBody, tReqBody)
    Do $$$AssertStatusOK(tSC, "POST /_changes completed")
    Do $$$AssertEquals(tStatus, 200, "Returns 200")
    Do $$$AssertEquals(tBody.results.%Size(), 1, "1 result returned with limit=1")
}

/// <p>AC #1: Verify deleted doc in changes has deleted:true.</p>
Method TestChangesDeletedHttp()
{
    ; Create a document
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testchangeshttpdb/deldoc", .tStatus, .tBody, "{""data"":""test""}")
    Do $$$AssertEquals(tStatus, 201, "Created doc deldoc")
    Set tRev = tBody.rev
    ; Delete the document
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("DELETE", "/testchangeshttpdb/deldoc?rev=" _ tRev, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "Deleted doc deldoc")
    ; GET _changes
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/testchangeshttpdb/_changes", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "GET /_changes completed")
    Do $$$AssertEquals(tStatus, 200, "Returns 200")
    ; Find the delete entry
    Set tFoundDeleted = 0
    Set tI = 0
    While tI < tBody.results.%Size() {
        Set tEntry = tBody.results.%Get(tI)
        Set tI = tI + 1
        If (tEntry.id = "deldoc") && (tEntry.deleted = 1) {
            Set tFoundDeleted = 1
        }
    }
    Do $$$AssertTrue(tFoundDeleted, "Delete entry has deleted:true")
}

/// <p>AC #6: GET /_changes?descending=true returns reverse order.</p>
Method TestChangesDescendingHttp()
{
    ; Create 3 docs
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testchangeshttpdb/doc1", .tStatus, .tBody, "{""v"":1}")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testchangeshttpdb/doc2", .tStatus, .tBody, "{""v"":2}")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testchangeshttpdb/doc3", .tStatus, .tBody, "{""v"":3}")
    ; GET _changes?descending=true
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/testchangeshttpdb/_changes?descending=true", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "GET /_changes?descending=true completed")
    Do $$$AssertEquals(tStatus, 200, "Returns 200")
    Do $$$AssertEquals(tBody.results.%Size(), 3, "3 results returned")
    ; Verify highest seq first
    Set tSeq0 = tBody.results.%Get(0).seq
    Set tSeq1 = tBody.results.%Get(1).seq
    Set tSeq2 = tBody.results.%Get(2).seq
    Do $$$AssertTrue(tSeq0 > tSeq1, "First seq > second seq (descending)")
    Do $$$AssertTrue(tSeq1 > tSeq2, "Second seq > third seq (descending)")
}

}
