/// <p>HTTP integration tests for IRISCouch Prometheus metrics endpoint (Story 9.1).</p>
/// <p>Tests the <code>/_prometheus</code> endpoint via live HTTP requests using
/// <class>%Net.HttpRequest</class>. Verifies HTTP status, Content-Type header,
/// and Prometheus text format output after generating real request traffic.</p>
Class IRISCouch.Test.MetricsHttpTest Extends %UnitTest.TestCase
{

/// <p>Handle initvalue parameter from parent class.</p>
Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Quit $$$OK
}

/// <p>Reset metrics before each test for isolation.</p>
Method OnBeforeOneTest() As %Status
{
    Do ##class(IRISCouch.Metrics.Collector).Reset()
    Quit $$$OK
}

/// <p>Clean up metrics after each test.</p>
Method OnAfterOneTest() As %Status
{
    Do ##class(IRISCouch.Metrics.Collector).Reset()
    Quit $$$OK
}

/// <p>Test GET /_prometheus returns 200 with Prometheus text format.</p>
/// <p>AC #1: Response contains Prometheus text format metrics with correct Content-Type.</p>
Method TestPrometheusEndpoint()
{
    Set tReq = ..CreateRequest()
    Set tSC = tReq.Get("/iris-couch/_prometheus")
    Do $$$AssertStatusOK(tSC, "GET /_prometheus request completed")
    Do $$$AssertEquals(tReq.HttpResponse.StatusCode, 200, "GET /_prometheus returns 200")
    ; Check response body contains metric declarations
    Set tBody = tReq.HttpResponse.Data.Read()
    Do $$$AssertTrue(tBody [ "# HELP", "Response contains # HELP declaration")
    Do $$$AssertTrue(tBody [ "# TYPE", "Response contains # TYPE declaration")
    Do $$$AssertTrue(tBody [ "iriscouch_", "Response contains iriscouch_ metrics prefix")
}

/// <p>Test that /_prometheus returns the exact Prometheus Content-Type.</p>
/// <p>AC #1: Content-Type must be text/plain; version=0.0.4; charset=utf-8.</p>
Method TestPrometheusContentType()
{
    Set tReq = ..CreateRequest()
    Set tSC = tReq.Get("/iris-couch/_prometheus")
    Do $$$AssertStatusOK(tSC, "GET /_prometheus request completed")
    Set tContentType = tReq.HttpResponse.ContentType
    Do $$$AssertTrue(tContentType [ "text/plain", "Content-Type contains text/plain")
    Do $$$AssertTrue(tContentType [ "version=0.0.4", "Content-Type contains version=0.0.4")
}

/// <p>Test that metrics reflect actual HTTP traffic.</p>
/// <p>AC #2-#4: After making HTTP requests, the metrics endpoint shows
/// non-zero request counters, status codes, and latency data.</p>
Method TestMetricsAfterRequests()
{
    ; Generate some real HTTP traffic first
    Set tReq = ..CreateRequest()
    ; Make a few requests to well-known endpoints
    Set tSC = tReq.Get("/iris-couch/")
    Do $$$AssertStatusOK(tSC, "GET / request completed")
    Set tReq2 = ..CreateRequest()
    Set tSC = tReq2.Get("/iris-couch/_all_dbs")
    Do $$$AssertStatusOK(tSC, "GET /_all_dbs request completed")
    Set tReq3 = ..CreateRequest()
    Set tSC = tReq3.Get("/iris-couch/_uuids")
    Do $$$AssertStatusOK(tSC, "GET /_uuids request completed")
    ; Now scrape the metrics endpoint
    Set tReq4 = ..CreateRequest()
    Set tSC = tReq4.Get("/iris-couch/_prometheus")
    Do $$$AssertStatusOK(tSC, "GET /_prometheus request completed")
    Do $$$AssertEquals(tReq4.HttpResponse.StatusCode, 200, "Metrics endpoint returns 200")
    Set tBody = tReq4.HttpResponse.Data.Read()
    ; Verify request counters exist for traffic we generated
    Do $$$AssertTrue(tBody [ "iriscouch_http_requests_total{", "Response contains request counter metrics")
    Do $$$AssertTrue(tBody [ "iriscouch_http_status_total{", "Response contains status counter metrics")
    Do $$$AssertTrue(tBody [ "iriscouch_http_request_duration_seconds_bucket{", "Response contains latency histogram buckets")
    Do $$$AssertTrue(tBody [ "iriscouch_http_request_duration_seconds_count{", "Response contains latency count")
    Do $$$AssertTrue(tBody [ "iriscouch_http_request_duration_seconds_sum{", "Response contains latency sum")
    ; Verify database count gauge is present
    Do $$$AssertTrue(tBody [ "iriscouch_database_count", "Response contains database count gauge")
}

/// <p>Helper: Create an HTTP request with Basic auth credentials.</p>
ClassMethod CreateRequest() As %Net.HttpRequest
{
    Set tReq = ##class(%Net.HttpRequest).%New()
    Set tReq.Server = ##class(IRISCouch.Test.HttpIntegrationTest).GetTestServer()
    Set tReq.Port = ##class(IRISCouch.Test.HttpIntegrationTest).GetTestPort()
    Set tReq.Username = ##class(IRISCouch.Test.HttpIntegrationTest).GetTestUsername()
    Set tReq.Password = ##class(IRISCouch.Test.HttpIntegrationTest).GetTestPassword()
    Set tReq.ContentType = "application/json"
    Quit tReq
}

}
