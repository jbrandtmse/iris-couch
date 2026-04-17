/// <p>HTTP integration tests for <code>validate_doc_update</code> hooks under
/// the Subprocess JSRuntime backend (Story 12.3).</p>
/// <p>Every test:</p>
/// <ul>
/// <li>Creates a fresh <code>testvalhttp123</code> database</li>
/// <li>Sets <code>JSRUNTIME=Subprocess</code> (except AC #4 tests)</li>
/// <li>Skips gracefully if no launchable interpreter (CI without Node)</li>
/// <li>Cleans the DB and config in <method>OnAfterOneTest</method></li>
/// </ul>
Class IRISCouch.Test.JSRuntimeValidateHttpTest Extends %UnitTest.TestCase
{

Parameter TESTDB = "testvalhttp123";

Parameter NODEPATH = "C:\Program Files\nodejs\node.exe";

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Quit $$$OK
}

/// Create a fresh DB and activate the Subprocess backend before each test.
Method OnBeforeOneTest() As %Status
{
    Do ..KillDB()
    Set tSC = ##class(IRISCouch.Storage.Database).Create(..#TESTDB)
    If $$$ISERR(tSC) Quit tSC
    Set ^IRISCouch.Config("JSRUNTIME") = "Subprocess"
    Set ^IRISCouch.Config("JSRUNTIMESUBPROCESSPATH") = ..#NODEPATH
    Quit $$$OK
}

/// Remove the DB and reset JSRUNTIME config after each test.
Method OnAfterOneTest() As %Status
{
    Do ..KillDB()
    Kill ^IRISCouch.Config("JSRUNTIME")
    Kill ^IRISCouch.Config("JSRUNTIMESUBPROCESSPATH")
    Kill ^IRISCouch.Config("JSRUNTIMESUBPROCESSENTRY")
    Quit $$$OK
}

ClassMethod KillDB() [ Internal ]
{
    Kill ^IRISCouch.DB(..#TESTDB)
    Kill ^IRISCouch.Docs(..#TESTDB)
    Kill ^IRISCouch.Tree(..#TESTDB)
    Kill ^IRISCouch.Changes(..#TESTDB)
    Kill ^IRISCouch.Seq(..#TESTDB)
    Kill ^IRISCouch.Security(..#TESTDB)
}

ClassMethod CanLaunchSubprocess() As %Boolean [ Internal ]
{
    Set tSandbox = ##class(IRISCouch.JSRuntime.Subprocess).%New()
    Quit tSandbox.IsAvailable()
}

/// AC #2: validate that approves (returns normally) lets the write proceed.
Method TestValidateApprovesWrite()
{
    If '..CanLaunchSubprocess() {
        Do $$$AssertTrue(1, "SKIP: no launchable Node interpreter on this runner")
        Quit
    }
    Set tDDoc = "{""validate_doc_update"":""function(newDoc,oldDoc,userCtx,secObj){/* approve */}""}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/" _ ..#TESTDB _ "/_design/ok", .tStatus, .tBody, tDDoc)
    Do $$$AssertEquals(tStatus, 201, "PUT approving ddoc")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/" _ ..#TESTDB _ "/doc1", .tStatus, .tBody, "{""x"":1}")
    Do $$$AssertEquals(tStatus, 201, "PUT doc after approve validate")
    Do $$$AssertEquals(tBody.ok, 1, "ok=true on approve")
}

/// AC #1: throw({forbidden:"..."}) maps to HTTP 403.
Method TestValidateRejectsWithForbidden()
{
    If '..CanLaunchSubprocess() {
        Do $$$AssertTrue(1, "SKIP: no launchable Node interpreter")
        Quit
    }
    Set tDDoc = "{""validate_doc_update"":""function(newDoc,oldDoc,userCtx,secObj){throw({forbidden:'nope'});}""}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/" _ ..#TESTDB _ "/_design/forbid", .tStatus, .tBody, tDDoc)
    Do $$$AssertEquals(tStatus, 201, "PUT rejecting ddoc")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/" _ ..#TESTDB _ "/doc1", .tStatus, .tBody, "{""x"":1}")
    Do $$$AssertEquals(tStatus, 403, "Forbidden maps to 403")
    Do $$$AssertEquals(tBody.error, "forbidden", "error envelope = forbidden")
    Do $$$AssertEquals(tBody.reason, "nope", "reason propagates from thrown envelope")
}

/// AC #1: throw({unauthorized:"..."}) maps to HTTP 401.
Method TestValidateRejectsWithUnauthorized()
{
    If '..CanLaunchSubprocess() {
        Do $$$AssertTrue(1, "SKIP: no launchable Node interpreter")
        Quit
    }
    Set tDDoc = "{""validate_doc_update"":""function(newDoc,oldDoc,userCtx,secObj){throw({unauthorized:'login first'});}""}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/" _ ..#TESTDB _ "/_design/unauth", .tStatus, .tBody, tDDoc)
    Do $$$AssertEquals(tStatus, 201, "PUT unauthorized ddoc")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/" _ ..#TESTDB _ "/doc1", .tStatus, .tBody, "{""x"":1}")
    Do $$$AssertEquals(tStatus, 401, "Unauthorized maps to 401")
    Do $$$AssertEquals(tBody.error, "unauthorized", "error envelope = unauthorized")
    Do $$$AssertEquals(tBody.reason, "login first", "reason propagates")
}

/// AC #1: validate fires on SaveDeleted (tombstone write).
Method TestValidateRunsOnSaveDeleted()
{
    If '..CanLaunchSubprocess() {
        Do $$$AssertTrue(1, "SKIP: no launchable Node interpreter")
        Quit
    }
    ; Put approve ddoc first, then write a doc
    Set tDDoc = "{""validate_doc_update"":""function(newDoc,oldDoc,userCtx,secObj){/* approve writes */}""}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/" _ ..#TESTDB _ "/_design/ok", .tStatus, .tBody, tDDoc)
    Do $$$AssertEquals(tStatus, 201, "PUT approve ddoc")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/" _ ..#TESTDB _ "/doc1", .tStatus, .tBody, "{""x"":1}")
    Do $$$AssertEquals(tStatus, 201, "PUT doc1")
    Set tDocRev = tBody.rev
    ; Now replace the ddoc with one that rejects deletes
    Set tDDocRev = ##class(IRISCouch.Storage.RevTree).GetWinner(..#TESTDB, "_design/ok")
    Set tDDoc2 = "{""_id"":""_design/ok"",""_rev"":""" _ tDDocRev _ """,""validate_doc_update"":""function(newDoc,oldDoc,userCtx,secObj){if(newDoc._deleted)throw({forbidden:'no deletes'});}""}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/" _ ..#TESTDB _ "/_design/ok", .tStatus, .tBody, tDDoc2)
    Do $$$AssertEquals(tStatus, 201, "PUT reject-deletes ddoc")
    ; Attempt DELETE — must 403
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("DELETE", "/" _ ..#TESTDB _ "/doc1?rev=" _ tDocRev, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 403, "DELETE rejected by validate fires on tombstone path")
    Do $$$AssertEquals(tBody.error, "forbidden", "error = forbidden on SaveDeleted")
}

/// AC #7: validate fires on SaveWithHistory (replication path) — new_edits=false.
Method TestValidateRunsOnSaveWithHistory()
{
    If '..CanLaunchSubprocess() {
        Do $$$AssertTrue(1, "SKIP: no launchable Node interpreter")
        Quit
    }
    Set tDDoc = "{""validate_doc_update"":""function(newDoc,oldDoc,userCtx,secObj){throw({forbidden:'denied'});}""}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/" _ ..#TESTDB _ "/_design/reject", .tStatus, .tBody, tDDoc)
    Do $$$AssertEquals(tStatus, 201, "PUT reject ddoc")
    ; _bulk_docs with new_edits=false (replication shape)
    Set tBulk = "{""new_edits"":false,""docs"":[{""_id"":""replrep"",""_rev"":""1-deadbeef"",""_revisions"":{""start"":1,""ids"":[""deadbeef""]},""x"":42}]}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("POST", "/" _ ..#TESTDB _ "/_bulk_docs", .tStatus, .tBody, tBulk)
    ; new_edits=false silently drops rejections per CouchDB spec, so the
    ; response is 201 with an empty array. The real assertion: the doc must
    ; NOT land on disk (RevTree must not contain 1-deadbeef).
    Do $$$AssertEquals(tStatus, 201, "new_edits=false returns 201 even on rejection")
    Set tExists = ##class(IRISCouch.Storage.RevTree).RevExists(..#TESTDB, "replrep", "1-deadbeef")
    Do $$$AssertTrue('tExists, "validate_doc_update rejection blocks replication write (AC #7)")
}

/// AC #1: validate fires on SaveWithAttachments.
Method TestValidateRunsOnSaveWithAttachments()
{
    If '..CanLaunchSubprocess() {
        Do $$$AssertTrue(1, "SKIP: no launchable Node interpreter")
        Quit
    }
    Set tDDoc = "{""validate_doc_update"":""function(newDoc,oldDoc,userCtx,secObj){throw({forbidden:'no attachments'});}""}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/" _ ..#TESTDB _ "/_design/reject", .tStatus, .tBody, tDDoc)
    Do $$$AssertEquals(tStatus, 201, "PUT reject ddoc")
    ; PUT with inline attachment (hits SaveWithAttachments path)
    Set tBody = "{""x"":1,""_attachments"":{""readme.txt"":{""content_type"":""text/plain"",""data"":""aGVsbG8=""}}}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/" _ ..#TESTDB _ "/doc1", .tStatus, .tBody, tBody)
    Do $$$AssertEquals(tStatus, 403, "SaveWithAttachments path enforces validate")
    Do $$$AssertEquals(tBody.error, "forbidden", "error = forbidden on attachment write")
}

/// AC #6: multiple validate fns run fail-fast — first rejection wins.
Method TestMultipleValidatesFailFast()
{
    If '..CanLaunchSubprocess() {
        Do $$$AssertTrue(1, "SKIP: no launchable Node interpreter")
        Quit
    }
    ; Two ddocs. The second one would throw {forbidden:"LATE"} if reached;
    ; the first throws {forbidden:"FIRST"}. The response must carry FIRST.
    Set tFirst = "{""validate_doc_update"":""function(newDoc,oldDoc,userCtx,secObj){throw({forbidden:'FIRST'});}""}"
    Set tLater = "{""validate_doc_update"":""function(newDoc,oldDoc,userCtx,secObj){throw({forbidden:'LATE'});}""}"
    ; Storage.Document.ListLiveDocIds uses $Order alphabetically — so name
    ; the ddocs so the FIRST-throwing one sorts before the LATE one.
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/" _ ..#TESTDB _ "/_design/aaa", .tStatus, .tBody, tFirst)
    Do $$$AssertEquals(tStatus, 201, "PUT aaa (first)")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/" _ ..#TESTDB _ "/_design/zzz", .tStatus, .tBody, tLater)
    Do $$$AssertEquals(tStatus, 201, "PUT zzz (late)")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/" _ ..#TESTDB _ "/doc1", .tStatus, .tBody, "{""x"":1}")
    Do $$$AssertEquals(tStatus, 403, "Rejected")
    Do $$$AssertEquals(tBody.reason, "FIRST", "Fail-fast: first rejection wins")
}

/// AC #4: JSRUNTIME=None AND validate fn present → 501.
Method TestValidateReturns501WhenRuntimeIsNoneAndValidateIsPresent()
{
    If '..CanLaunchSubprocess() {
        Do $$$AssertTrue(1, "SKIP: no launchable Node interpreter")
        Quit
    }
    Set tDDoc = "{""validate_doc_update"":""function(newDoc,oldDoc,userCtx,secObj){/* approve */}""}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/" _ ..#TESTDB _ "/_design/ok", .tStatus, .tBody, tDDoc)
    Do $$$AssertEquals(tStatus, 201, "PUT ddoc under Subprocess")
    ; Now flip runtime to None. Under AC #4 this should block subsequent writes.
    Set ^IRISCouch.Config("JSRUNTIME") = "None"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/" _ ..#TESTDB _ "/doc1", .tStatus, .tBody, "{""x"":1}")
    Do $$$AssertEquals(tStatus, 501, "JSRUNTIME=None + validate present → 501")
    Do $$$AssertEquals(tBody.error, "not_implemented", "error = not_implemented")
    Do $$$AssertTrue(tBody.reason [ "JSRuntime backend", "reason references JSRuntime backend config")
    ; Restore for OnAfterOneTest cleanup
    Set ^IRISCouch.Config("JSRUNTIME") = "Subprocess"
}

/// AC #4 exemption: JSRUNTIME=None, no validate ddoc → writes still 201.
Method TestWritesWithoutValidateStillPassUnderNone()
{
    Set ^IRISCouch.Config("JSRUNTIME") = "None"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/" _ ..#TESTDB _ "/doc1", .tStatus, .tBody, "{""x"":1}")
    Do $$$AssertEquals(tStatus, 201, "No validate ddoc → writes pass under None (AC #4 exemption)")
    ; Restore
    Set ^IRISCouch.Config("JSRUNTIME") = "Subprocess"
}

}
