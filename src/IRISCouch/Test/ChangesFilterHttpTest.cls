/// <p>HTTP integration tests for IRISCouch changes feed filter functionality.</p>
/// <p>Tests <code>_doc_ids</code>, <code>_design</code>, <code>_selector</code>
/// built-in filters, and unknown filter rejection via live HTTP requests.
/// Covers AC #1, #2, #3, #4, #5.</p>
Class IRISCouch.Test.ChangesFilterHttpTest Extends %UnitTest.TestCase
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
    Kill ^IRISCouch.DB("testfilterhttpdb")
    Kill ^IRISCouch.Docs("testfilterhttpdb")
    Kill ^IRISCouch.Tree("testfilterhttpdb")
    Kill ^IRISCouch.Changes("testfilterhttpdb")
    Kill ^IRISCouch.Seq("testfilterhttpdb")
    Set tSC = ##class(IRISCouch.Storage.Database).Create("testfilterhttpdb")
    Quit tSC
}

/// <p>Kill all test database globals after each test.</p>
Method OnAfterOneTest() As %Status
{
    Kill ^IRISCouch.DB("testfilterhttpdb")
    Kill ^IRISCouch.Docs("testfilterhttpdb")
    Kill ^IRISCouch.Tree("testfilterhttpdb")
    Kill ^IRISCouch.Changes("testfilterhttpdb")
    Kill ^IRISCouch.Seq("testfilterhttpdb")
    Quit $$$OK
}

/// <p>AC #1: POST /_changes?filter=_doc_ids with body {"doc_ids":["doc1","doc3"]}
/// returns only changes for those documents.</p>
Method TestDocIdsFilterHttp()
{
    ; Create 3 docs
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testfilterhttpdb/doc1", .tStatus, .tBody, "{""name"":""Alice""}")
    Do $$$AssertEquals(tStatus, 201, "Created doc1")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testfilterhttpdb/doc2", .tStatus, .tBody, "{""name"":""Bob""}")
    Do $$$AssertEquals(tStatus, 201, "Created doc2")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testfilterhttpdb/doc3", .tStatus, .tBody, "{""name"":""Charlie""}")
    Do $$$AssertEquals(tStatus, 201, "Created doc3")
    ; POST _changes with _doc_ids filter
    Set tReqBody = "{""doc_ids"":[""doc1"",""doc3""]}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("POST", "/testfilterhttpdb/_changes?filter=_doc_ids", .tStatus, .tBody, tReqBody)
    Do $$$AssertStatusOK(tSC, "POST /_changes?filter=_doc_ids completed")
    Do $$$AssertEquals(tStatus, 200, "Returns 200")
    Do $$$AssertEquals(tBody.results.%Size(), 2, "2 results returned")
    ; Verify the correct IDs are returned
    Set tFound1 = 0
    Set tFound3 = 0
    Set tI = 0
    While tI < tBody.results.%Size() {
        Set tEntry = tBody.results.%Get(tI)
        Set tI = tI + 1
        If tEntry.id = "doc1" Set tFound1 = 1
        If tEntry.id = "doc3" Set tFound3 = 1
    }
    Do $$$AssertTrue(tFound1, "doc1 in results")
    Do $$$AssertTrue(tFound3, "doc3 in results")
}

/// <p>AC #3: GET /_changes?filter=_design returns only design documents.</p>
/// <p>Design docs are created via DocumentEngine since the REST router does not
/// yet support slashes in document IDs (design doc routes are a future epic).</p>
Method TestDesignFilterHttp()
{
    ; Create design doc via engine (REST router can't handle slash in _design/test)
    Set tDesignRev = ##class(IRISCouch.Core.DocumentEngine).Save("testfilterhttpdb", "_design/test", "{""views"":{}}")
    Do $$$AssertTrue(tDesignRev '= "", "Created _design/test via engine")
    ; Create normal doc via HTTP
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testfilterhttpdb/normal-doc", .tStatus, .tBody, "{""data"":""test""}")
    Do $$$AssertEquals(tStatus, 201, "Created normal-doc")
    ; GET _changes with _design filter
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/testfilterhttpdb/_changes?filter=_design", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "GET /_changes?filter=_design completed")
    Do $$$AssertEquals(tStatus, 200, "Returns 200")
    Do $$$AssertEquals(tBody.results.%Size(), 1, "1 result returned")
    Do $$$AssertEquals(tBody.results.%Get(0).id, "_design/test", "Result is _design/test")
}

/// <p>AC #2: POST /_changes?filter=_selector with body {"selector":{"type":"order"}}
/// returns only matching documents.</p>
Method TestSelectorFilterHttp()
{
    ; Create docs with different types
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testfilterhttpdb/order1", .tStatus, .tBody, "{""type"":""order"",""amount"":50}")
    Do $$$AssertEquals(tStatus, 201, "Created order1")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testfilterhttpdb/user1", .tStatus, .tBody, "{""type"":""user"",""name"":""Alice""}")
    Do $$$AssertEquals(tStatus, 201, "Created user1")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testfilterhttpdb/order2", .tStatus, .tBody, "{""type"":""order"",""amount"":75}")
    Do $$$AssertEquals(tStatus, 201, "Created order2")
    ; POST _changes with _selector filter
    Set tReqBody = "{""selector"":{""type"":""order""}}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("POST", "/testfilterhttpdb/_changes?filter=_selector", .tStatus, .tBody, tReqBody)
    Do $$$AssertStatusOK(tSC, "POST /_changes?filter=_selector completed")
    Do $$$AssertEquals(tStatus, 200, "Returns 200")
    Do $$$AssertEquals(tBody.results.%Size(), 2, "2 order results returned")
    ; Verify both are order docs
    Set tI = 0
    While tI < tBody.results.%Size() {
        Set tEntry = tBody.results.%Get(tI)
        Set tI = tI + 1
        Do $$$AssertTrue((tEntry.id = "order1") || (tEntry.id = "order2"), "Result " _ tEntry.id _ " is an order doc")
    }
}

/// <p>AC #4: GET /_changes?filter=my_custom_filter returns 404.</p>
Method TestUnknownFilterHttp()
{
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/testfilterhttpdb/_changes?filter=my_custom_filter", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "GET /_changes?filter=my_custom_filter completed")
    Do $$$AssertEquals(tStatus, 404, "Returns 404 for unknown filter")
    Do $$$AssertEquals(tBody.error, "not_found", "Error is not_found")
    Do $$$AssertEquals(tBody.reason, "missing", "Reason is missing")
}

/// <p>AC #1: GET /_changes?filter=_doc_ids&amp;doc_ids=["doc1"] works via query string.</p>
Method TestDocIdsFilterQueryStringHttp()
{
    ; Create 2 docs
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testfilterhttpdb/doc1", .tStatus, .tBody, "{""v"":1}")
    Do $$$AssertEquals(tStatus, 201, "Created doc1")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testfilterhttpdb/doc2", .tStatus, .tBody, "{""v"":2}")
    Do $$$AssertEquals(tStatus, 201, "Created doc2")
    ; GET _changes with doc_ids in query string
    Set tPath = "/testfilterhttpdb/_changes?filter=_doc_ids&doc_ids=[""doc1""]"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", tPath, .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "GET /_changes?filter=_doc_ids&doc_ids=[doc1] completed")
    Do $$$AssertEquals(tStatus, 200, "Returns 200")
    Do $$$AssertEquals(tBody.results.%Size(), 1, "1 result returned")
    Do $$$AssertEquals(tBody.results.%Get(0).id, "doc1", "Result is doc1")
}

/// <p>AC #5: Longpoll with filter returns only filtered results.</p>
Method TestLongpollWithFilterHttp()
{
    ; Create 2 docs with different data
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testfilterhttpdb/doc1", .tStatus, .tBody, "{""type"":""A""}")
    Do $$$AssertEquals(tStatus, 201, "Created doc1")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testfilterhttpdb/doc2", .tStatus, .tBody, "{""type"":""B""}")
    Do $$$AssertEquals(tStatus, 201, "Created doc2")
    ; GET _changes with longpoll + _doc_ids filter, since=0 so changes exist immediately
    Set tReqBody = "{""doc_ids"":[""doc1""]}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("POST", "/testfilterhttpdb/_changes?feed=longpoll&since=0&filter=_doc_ids", .tStatus, .tBody, tReqBody)
    Do $$$AssertStatusOK(tSC, "Longpoll with filter completed")
    Do $$$AssertEquals(tStatus, 200, "Returns 200")
    Do $$$AssertEquals(tBody.results.%Size(), 1, "1 result returned (filtered)")
    Do $$$AssertEquals(tBody.results.%Get(0).id, "doc1", "Only doc1 in results")
}

}
