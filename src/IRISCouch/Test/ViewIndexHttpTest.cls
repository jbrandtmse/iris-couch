/// <p>HTTP integration tests for Story 12.5 — incremental view indexing,
/// ETag caching, and timeout enforcement.</p>
/// <p>Requires:</p>
/// <ul>
/// <li><code>JSRUNTIME=Subprocess</code></li>
/// <li><code>JSRUNTIMESUBPROCESSPATH</code> pointing at Node v22+</li>
/// <li><code>JSRUNTIMESUBPROCESSENTRY</code> pointing at
///     <code>documentation/couchjs/couchjs-entry.js</code></li>
/// </ul>
/// <p>Each test sets up its own database; the <method>OnAfterOneTest</method>
/// hook cleans up globally. If the sandbox is unavailable (interpreter path
/// unset), tests self-skip with an <code>$$$AssertTrue(1, "skipped")</code>.</p>
Class IRISCouch.Test.ViewIndexHttpTest Extends %UnitTest.TestCase
{

Parameter TESTDB = "viewidxhttp";

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Do ..KillDB()
    Quit ##class(IRISCouch.Storage.Database).Create(..#TESTDB)
}

Method OnAfterOneTest() As %Status
{
    Do ..KillDB()
    Quit $$$OK
}

ClassMethod KillDB() [ Internal ]
{
    Kill ^IRISCouch.DB(..#TESTDB)
    Kill ^IRISCouch.Docs(..#TESTDB)
    Kill ^IRISCouch.Tree(..#TESTDB)
    Kill ^IRISCouch.Changes(..#TESTDB)
    Kill ^IRISCouch.Seq(..#TESTDB)
    Kill ^IRISCouch.ViewIndex(..#TESTDB)
    Kill ^IRISCouch.ViewIndexById(..#TESTDB)
    Kill ^IRISCouch.ViewIndexMeta(..#TESTDB)
    Kill ^IRISCouch.ViewIndexCounter(..#TESTDB)
}

/// <p>Skip a test if the Subprocess sandbox is not configured.</p>
Method SkipIfNoSandbox() As %Boolean [ Internal ]
{
    Set tSandbox = ##class(IRISCouch.JSRuntime.Factory).GetSandbox()
    If 'tSandbox.IsAvailable() {
        Do $$$AssertTrue(1, "skipped: JSRUNTIME sandbox unavailable")
        Quit 1
    }
    Quit 0
}

/// <p>GET /{db}/_design/x/_view/y returns 200 with ETag header when sandbox
/// is configured; the body includes the rows produced by incremental
/// indexing on write (not a query-time map execution).</p>
Method TestIncrementalIndexOnWrite()
{
    If ..SkipIfNoSandbox() Quit
    Set tDDoc = "{""views"":{""byid"":{""map"":""function(doc){emit(doc._id,1);}""}}}"
    Set tDDocRev = ##class(IRISCouch.Core.DocumentEngine).Save(..#TESTDB, "_design/x", tDDoc)
    Do $$$AssertTrue(tDDocRev '= "", "design doc saved")
    For tI = 1:1:3 {
        Set tDR = ##class(IRISCouch.Core.DocumentEngine).Save(..#TESTDB, "d" _ tI, "{""n"":" _ tI _ "}")
        Do $$$AssertTrue(tDR '= "", "doc " _ tI _ " saved")
    }
    Set tSC = ..HttpGetView("/" _ ..#TESTDB _ "/_design/x/_view/byid", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "transport OK")
    Do $$$AssertEquals(tStatus, 200, "200 OK on first view query")
    Do $$$AssertTrue($IsObject(tBody), "body is an object: " _ $Select($IsObject(tBody): tBody.%ToJSON(), 1: tBody))
    Do $$$AssertEquals(+tBody.%Get("total_rows"), 3, "3 rows returned (got " _ tBody.%Get("total_rows") _ ")")
    Do $$$AssertTrue($Get(tHeaders("ETAG")) '= "", "ETag header set")
}

/// <p>Delete a doc -> its rows disappear from the view result.</p>
Method TestIncrementalIndexOnDelete()
{
    If ..SkipIfNoSandbox() Quit
    Set tDDoc = "{""views"":{""byid"":{""map"":""function(doc){emit(doc._id,1);}""}}}"
    Set tDDocRev = ##class(IRISCouch.Core.DocumentEngine).Save(..#TESTDB, "_design/x", tDDoc)
    Do $$$AssertTrue(tDDocRev '= "", "ddoc saved")
    Set tRev1 = ##class(IRISCouch.Core.DocumentEngine).Save(..#TESTDB, "d1", "{}")
    Do $$$AssertTrue(tRev1 '= "", "d1 saved")
    Set tRev2 = ##class(IRISCouch.Core.DocumentEngine).Save(..#TESTDB, "d2", "{}")
    Do $$$AssertTrue(tRev2 '= "", "d2 saved")
    Set tDeletedRev = ##class(IRISCouch.Core.DocumentEngine).SaveDeleted(..#TESTDB, "d1", tRev1)
    Do $$$AssertTrue(tDeletedRev '= "", "d1 deleted")
    Set tSC = ..HttpGetView("/" _ ..#TESTDB _ "/_design/x/_view/byid", .tStatus, .tBody, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "200 OK")
    Do $$$AssertTrue($IsObject(tBody), "body is object")
    Do $$$AssertEquals(+tBody.%Get("total_rows"), 1, "Only live doc remains")
    Do $$$AssertEquals(tBody.%Get("rows").%Get(0).%Get("id"), "d2", "d2 is the survivor")
}

/// <p>Same view, no intervening writes, second GET with If-None-Match
/// matches -> 304 Not Modified.</p>
Method TestETag304OnUnchanged()
{
    If ..SkipIfNoSandbox() Quit
    Set tDDoc = "{""views"":{""byid"":{""map"":""function(doc){emit(doc._id,1);}""}}}"
    Do ##class(IRISCouch.Core.DocumentEngine).Save(..#TESTDB, "_design/x", tDDoc)
    Do ##class(IRISCouch.Core.DocumentEngine).Save(..#TESTDB, "d1", "{}")
    Set tSC = ..HttpGetView("/" _ ..#TESTDB _ "/_design/x/_view/byid", .tS1, .tB1, .tH1)
    Set tEtag = $Get(tH1("ETAG"))
    Do $$$AssertTrue(tEtag '= "", "First call returns ETag")
    ; Second call with If-None-Match
    Set tSC = ..HttpGetViewWithIfNoneMatch("/" _ ..#TESTDB _ "/_design/x/_view/byid", tEtag, .tS2, .tB2, .tH2)
    Do $$$AssertEquals(tS2, 304, "304 Not Modified on matching ETag")
}

/// <p>Write a new doc -> the cached ETag no longer matches -> 200 with
/// a new ETag is returned.</p>
Method TestETagInvalidationOnWrite()
{
    If ..SkipIfNoSandbox() Quit
    Set tDDoc = "{""views"":{""byid"":{""map"":""function(doc){emit(doc._id,1);}""}}}"
    Do ##class(IRISCouch.Core.DocumentEngine).Save(..#TESTDB, "_design/x", tDDoc)
    Do ##class(IRISCouch.Core.DocumentEngine).Save(..#TESTDB, "d1", "{}")
    Set tSC = ..HttpGetView("/" _ ..#TESTDB _ "/_design/x/_view/byid", .tS1, .tB1, .tH1)
    Set tOldEtag = $Get(tH1("ETAG"))
    ; Intervening write
    Do ##class(IRISCouch.Core.DocumentEngine).Save(..#TESTDB, "d2", "{}")
    Set tSC = ..HttpGetViewWithIfNoneMatch("/" _ ..#TESTDB _ "/_design/x/_view/byid", tOldEtag, .tS2, .tB2, .tH2)
    Do $$$AssertEquals(tS2, 200, "200 on changed view")
    Set tNewEtag = $Get(tH2("ETAG"))
    Do $$$AssertNotEquals(tNewEtag, tOldEtag, "ETag advanced")
}

/// <p>Changing a view's map source drops the cached index; next query
/// rebuilds and reflects the new map output.</p>
Method TestViewDefinitionChangeDropsIndex()
{
    If ..SkipIfNoSandbox() Quit
    Set tV1 = "{""views"":{""byid"":{""map"":""function(doc){emit(doc._id,1);}""}}}"
    Set tDDocRev1 = ##class(IRISCouch.Core.DocumentEngine).Save(..#TESTDB, "_design/x", tV1)
    Do ##class(IRISCouch.Core.DocumentEngine).Save(..#TESTDB, "d1", "{""n"":42}")
    Do ..HttpGetView("/" _ ..#TESTDB _ "/_design/x/_view/byid", .tS1, .tB1, .tH1)
    Do $$$AssertEquals(tB1.%Get("total_rows"), 1, "v1 emits 1 row")
    Do $$$AssertEquals(tB1.%Get("rows").%Get(0).value, 1, "v1 value is 1")
    ; Update view: emit a different value
    Set tV2 = "{""views"":{""byid"":{""map"":""function(doc){emit(doc._id,doc.n);}""}}}"
    Do ##class(IRISCouch.Core.DocumentEngine).Save(..#TESTDB, "_design/x", tV2, tDDocRev1)
    Do ..HttpGetView("/" _ ..#TESTDB _ "/_design/x/_view/byid", .tS2, .tB2, .tH2)
    Do $$$AssertEquals(tB2.%Get("total_rows"), 1, "v2 emits 1 row")
    Do $$$AssertEquals(tB2.%Get("rows").%Get(0).value, 42, "v2 value is doc.n (42)")
}

/// <p>After 3 queries against the index, each call finishes in single-digit
/// ms (far below the 80+ ms subprocess cold-start cost). Indirect proof
/// that the incremental view index replaced per-query map execution. The
/// subprocess pool is still a shim under Story 12.5 (Story 12.5b tracks
/// true long-lived pooling) — this test measures <b>warm-index</b>
/// latency, not a pooled subprocess. Renamed 2026-04-18 (Story 13.0
/// cleanup) from <code>TestPooledSubprocessReducesLatency</code> to
/// reflect what is actually being measured.</p>
Method TestWarmIndexReducesLatency()
{
    If ..SkipIfNoSandbox() Quit
    Set tDDoc = "{""views"":{""byid"":{""map"":""function(doc){emit(doc._id,1);}""}}}"
    Do ##class(IRISCouch.Core.DocumentEngine).Save(..#TESTDB, "_design/x", tDDoc)
    For tI = 1:1:5 {
        Do ##class(IRISCouch.Core.DocumentEngine).Save(..#TESTDB, "d" _ tI, "{}")
    }
    ; Warm-up pass (triggers cold-cache Rebuild)
    Do ..HttpGetView("/" _ ..#TESTDB _ "/_design/x/_view/byid", .tS0, .tB0, .tH0)
    ; Timed warm pass. Warm query is O(N) over the index globals, no
    ; subprocess call -- should clock in at single-digit-to-tens-ms even
    ; with the HTTP round-trip. Cold baseline (Story 12.2) was ~1.3s/10docs
    ; so anything below 500 ms demonstrates the index is being used.
    Set tStart = $ZHorolog
    Do ..HttpGetView("/" _ ..#TESTDB _ "/_design/x/_view/byid", .tS1, .tB1, .tH1)
    Set tElapsedMs = ($ZHorolog - tStart) * 1000
    Do $$$AssertEquals(tS1, 200, "200 OK (got " _ tS1 _ ")")
    Do $$$AssertTrue(tElapsedMs < 500, "Warm query < 500 ms (was " _ tElapsedMs _ " ms) — index-driven, not per-doc map")
}

/// <p>AC #4: a runaway <code>while(true){}</code> map function forces a
/// timeout. The design-doc save succeeds (it only stores the source), but
/// the subsequent data-doc save rolls back with a
/// <code>jsruntime_timeout</code> error because the map-during-write step
/// cannot complete in <code>JSRUNTIMETIMEOUT</code> ms.</p>
Method TestRunawayMapFunctionTimesOut()
{
    If ..SkipIfNoSandbox() Quit
    ; Use a short timeout for the test so we do not hang the suite.
    Set tPriorTimeout = ##class(IRISCouch.Config).Get("JSRUNTIMETIMEOUT")
    Do ##class(IRISCouch.Config).Set("JSRUNTIMETIMEOUT", 1000)
    ; Runaway map -- blocks in a tight sync loop. couchjs-entry.js's
    ; setTimeout cannot fire while the loop owns the event loop, so we
    ; rely on the wall-clock backstop in Pipe.Flush to surface the timeout.
    Set tDDoc = "{""views"":{""rogue"":{""map"":""function(doc){while(true){}}""}}}"
    Do ##class(IRISCouch.Core.DocumentEngine).Save(..#TESTDB, "_design/rogue", tDDoc)
    ; Writing a data doc triggers ViewIndexUpdater -> map function -> hang.
    ; The write must fail (TROLLBACK) rather than hang the IRIS process.
    Set tBeforeMs = $ZHorolog
    Set tValidateError = ""
    Set tIndexError = ""
    Set tRev = ##class(IRISCouch.Core.DocumentEngine).Save(..#TESTDB, "victim", "{}", "", .tValidateError, .tIndexError)
    Set tElapsedMs = ($ZHorolog - tBeforeMs) * 1000
    ; Restore timeout for other tests.
    Do ##class(IRISCouch.Config).Set("JSRUNTIMETIMEOUT", tPriorTimeout)
    Do $$$AssertEquals(tRev, "", "Save rolls back on runaway map")
    ; Wall-clock cap: should take just over timeout + 500 ms overhead.
    Do $$$AssertTrue(tElapsedMs < 10000, "Save failed within 10s (was " _ tElapsedMs _ " ms)")
    ; Story 13.4 Task 4: pIndexError Output channel must surface the timeout
    ; classification so DocumentHandler can emit {"error":"timeout",...}.
    Do $$$AssertTrue($IsObject(tIndexError), "pIndexError populated on timeout failure")
    Do $$$AssertEquals(tIndexError.%Get("classification"), "timeout", "pIndexError.classification is 'timeout'")
    Do $$$AssertTrue(tIndexError.%Get("reason") '= "", "pIndexError.reason non-empty")
}

/// <p>Make an HTTP GET to a view endpoint and capture status + body + headers.</p>
ClassMethod HttpGetView(pPath As %String, Output pStatus As %Integer, Output pBody As %DynamicObject, Output pHeaders) As %Status [ Internal ]
{
    Kill pHeaders
    Set tReq = ##class(%Net.HttpRequest).%New()
    Set tReq.Server = ##class(IRISCouch.Test.HttpIntegrationTest).GetTestServer()
    Set tReq.Port = ##class(IRISCouch.Test.HttpIntegrationTest).GetTestPort()
    Set tReq.Username = ##class(IRISCouch.Test.HttpIntegrationTest).GetTestUsername()
    Set tReq.Password = ##class(IRISCouch.Test.HttpIntegrationTest).GetTestPassword()
    Set tSC = tReq.Get("/iris-couch" _ pPath)
    If $$$ISERR(tSC) Quit tSC
    Set pStatus = tReq.HttpResponse.StatusCode
    Set tBodyStr = tReq.HttpResponse.Data.Read()
    If tBodyStr '= "" {
        Set tFirstChar = $Extract($ZStrip(tBodyStr, "<W"), 1)
        If (tFirstChar = "{") || (tFirstChar = "[") {
            Set pBody = ##class(%DynamicAbstractObject).%FromJSON(tBodyStr)
        } Else {
            Set pBody = $ZStrip(tBodyStr, "<>W")
        }
    }
    ; Copy response headers into caller-accessible array.
    Set tKey = ""
    For {
        Set tKey = tReq.HttpResponse.GetNextHeader(tKey)
        If tKey = "" Quit
        Set pHeaders(tKey) = tReq.HttpResponse.GetHeader(tKey)
    }
    Quit $$$OK
}

/// <p>Same as HttpGetView but adds an If-None-Match header.</p>
ClassMethod HttpGetViewWithIfNoneMatch(pPath As %String, pEtag As %String, Output pStatus As %Integer, Output pBody As %DynamicObject, Output pHeaders) As %Status [ Internal ]
{
    Kill pHeaders
    Set tReq = ##class(%Net.HttpRequest).%New()
    Set tReq.Server = ##class(IRISCouch.Test.HttpIntegrationTest).GetTestServer()
    Set tReq.Port = ##class(IRISCouch.Test.HttpIntegrationTest).GetTestPort()
    Set tReq.Username = ##class(IRISCouch.Test.HttpIntegrationTest).GetTestUsername()
    Set tReq.Password = ##class(IRISCouch.Test.HttpIntegrationTest).GetTestPassword()
    Do tReq.SetHeader("If-None-Match", pEtag)
    Set tSC = tReq.Get("/iris-couch" _ pPath)
    If $$$ISERR(tSC) Quit tSC
    Set pStatus = tReq.HttpResponse.StatusCode
    Set tBodyStr = tReq.HttpResponse.Data.Read()
    Set pBody = ""
    If tBodyStr '= "" {
        Set tFirstChar = $Extract($ZStrip(tBodyStr, "<W"), 1)
        If (tFirstChar = "{") || (tFirstChar = "[") {
            Set pBody = ##class(%DynamicAbstractObject).%FromJSON(tBodyStr)
        }
    }
    Set tKey = ""
    For {
        Set tKey = tReq.HttpResponse.GetNextHeader(tKey)
        If tKey = "" Quit
        Set pHeaders(tKey) = tReq.HttpResponse.GetHeader(tKey)
    }
    Quit $$$OK
}

}
