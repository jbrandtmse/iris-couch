/// <p>HTTP integration tests for IRISCouch longpoll changes feed.</p>
/// <p>Tests <code>GET /{db}/_changes?feed=longpoll</code> via live HTTP requests.
/// Covers AC #2, #5 (immediate return and timeout scenarios).</p>
Class IRISCouch.Test.LongpollHttpTest Extends %UnitTest.TestCase
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
    Kill ^IRISCouch.DB("testlongpollhttpdb")
    Kill ^IRISCouch.Docs("testlongpollhttpdb")
    Kill ^IRISCouch.Tree("testlongpollhttpdb")
    Kill ^IRISCouch.Changes("testlongpollhttpdb")
    Kill ^IRISCouch.Seq("testlongpollhttpdb")
    ; Clean up event resources
    Set tEvt = ##class(%SYSTEM.Event).Delete("^IRISCouch.LPChanges(""testlongpollhttpdb"")")
    ; Create test database
    Set tSC = ##class(IRISCouch.Storage.Database).Create("testlongpollhttpdb")
    Quit tSC
}

/// <p>Delete test database and kill all globals after each test.</p>
Method OnAfterOneTest() As %Status
{
    Kill ^IRISCouch.DB("testlongpollhttpdb")
    Kill ^IRISCouch.Docs("testlongpollhttpdb")
    Kill ^IRISCouch.Tree("testlongpollhttpdb")
    Kill ^IRISCouch.Changes("testlongpollhttpdb")
    Kill ^IRISCouch.Seq("testlongpollhttpdb")
    Set tEvt = ##class(%SYSTEM.Event).Delete("^IRISCouch.LPChanges(""testlongpollhttpdb"")")
    Quit $$$OK
}

/// <p>AC #5: Longpoll with existing changes returns immediately.</p>
/// <p>Creates 2 docs, then sends <code>feed=longpoll&amp;since=0</code> — should
/// return immediately because changes already exist after since=0.</p>
Method TestLongpollImmediateReturnHttp()
{
    ; Create 2 docs via HTTP
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testlongpollhttpdb/doc1", .tStatus, .tBody, "{""name"":""Alice""}")
    Do $$$AssertEquals(tStatus, 201, "Created doc1")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testlongpollhttpdb/doc2", .tStatus, .tBody, "{""name"":""Bob""}")
    Do $$$AssertEquals(tStatus, 201, "Created doc2")
    ; GET _changes?feed=longpoll&since=0 — should return immediately
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/testlongpollhttpdb/_changes?feed=longpoll&since=0", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "GET /_changes?feed=longpoll&since=0 completed")
    Do $$$AssertEquals(tStatus, 200, "Returns 200")
    Do $$$AssertTrue($IsObject(tBody), "Response is JSON object")
    Do $$$AssertTrue($IsObject(tBody.results), "results is present")
    Do $$$AssertEquals(tBody.results.%Size(), 2, "2 results returned immediately")
    ; Verify response format matches normal feed
    Set tEntry0 = tBody.results.%Get(0)
    Do $$$AssertTrue(tEntry0.seq > 0, "Entry has seq")
    Do $$$AssertTrue(tEntry0.id '= "", "Entry has id")
    Do $$$AssertTrue($IsObject(tEntry0.changes), "Entry has changes array")
    Do $$$AssertTrue(tEntry0.changes.%Get(0).rev '= "", "Change has rev")
    Do $$$AssertTrue(tBody."last_seq" > 0, "last_seq is present")
    Do $$$AssertEquals(tBody.pending, 0, "pending is 0")
}

/// <p>AC #3: Longpoll with no new changes times out and returns empty results.</p>
/// <p>Uses <code>since=999</code> (far beyond any existing seq) and
/// <code>timeout=1000</code> (1 second) to test timeout behavior.</p>
Method TestLongpollTimeoutHttp()
{
    ; GET _changes?feed=longpoll&since=999&timeout=1000 — should timeout
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/testlongpollhttpdb/_changes?feed=longpoll&since=999&timeout=1000", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "GET longpoll timeout request completed")
    Do $$$AssertEquals(tStatus, 200, "Returns 200 on timeout")
    Do $$$AssertTrue($IsObject(tBody), "Response is JSON object")
    Do $$$AssertEquals(tBody.results.%Size(), 0, "Empty results on timeout")
    Do $$$AssertTrue(tBody."last_seq" '= "", "last_seq is present")
    Do $$$AssertEquals(tBody.pending, 0, "pending is 0 on timeout")
}

/// <p>Regression: feed=normal still works as before.</p>
Method TestFeedNormalStillWorks()
{
    ; Create a doc
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testlongpollhttpdb/regdoc", .tStatus, .tBody, "{""v"":1}")
    Do $$$AssertEquals(tStatus, 201, "Created regdoc")
    ; GET _changes?feed=normal
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/testlongpollhttpdb/_changes?feed=normal", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "GET /_changes?feed=normal completed")
    Do $$$AssertEquals(tStatus, 200, "Returns 200")
    Do $$$AssertEquals(tBody.results.%Size(), 1, "1 result returned")
}

/// <p>Unsupported feed modes still return 400.</p>
Method TestUnsupportedFeedMode()
{
    ; GET _changes?feed=continuous should return 400
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/testlongpollhttpdb/_changes?feed=continuous", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "GET /_changes?feed=continuous completed")
    Do $$$AssertEquals(tStatus, 400, "Returns 400 for unsupported feed=continuous")
    ; GET _changes?feed=eventsource should also return 400
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/testlongpollhttpdb/_changes?feed=eventsource", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "GET /_changes?feed=eventsource completed")
    Do $$$AssertEquals(tStatus, 400, "Returns 400 for unsupported feed=eventsource")
}

}
