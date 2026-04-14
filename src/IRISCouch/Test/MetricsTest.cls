/// <p>Unit tests for IRISCouch Metrics subsystem (Story 9.1).</p>
/// <p>Tests <class>IRISCouch.Metrics.Collector</class>,
/// <class>IRISCouch.Metrics.Record</class>, and
/// <class>IRISCouch.Metrics.Endpoint</class> for request counters,
/// status counters, latency histograms, endpoint classification,
/// config toggle, Prometheus text format, and failure isolation.</p>
Class IRISCouch.Test.MetricsTest Extends %UnitTest.TestCase
{

/// <p>Handle initvalue parameter from parent class.</p>
Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Quit $$$OK
}

/// <p>Reset all metrics before each test for isolation.</p>
Method OnBeforeOneTest() As %Status
{
    Do ##class(IRISCouch.Metrics.Collector).Reset()
    Quit $$$OK
}

/// <p>Clean up metrics and config overrides after each test.</p>
Method OnAfterOneTest() As %Status
{
    Do ##class(IRISCouch.Metrics.Collector).Reset()
    Kill ^IRISCouch.Config("METRICSENABLED")
    Quit $$$OK
}

/// <p>Test IncrementRequest atomically increments the request counter.</p>
/// <p>AC #2: Request counts per endpoint class are recorded.</p>
Method TestIncrementRequest()
{
    Do ##class(IRISCouch.Metrics.Collector).IncrementRequest("document", "GET")
    Do ##class(IRISCouch.Metrics.Collector).IncrementRequest("document", "GET")
    Do ##class(IRISCouch.Metrics.Collector).IncrementRequest("document", "PUT")
    Do ##class(IRISCouch.Metrics.Collector).IncrementRequest("database", "GET")
    ; Verify counters
    Do $$$AssertEquals($Get(^IRISCouch.Metrics("req", "document", "GET")), 2, "document GET count is 2")
    Do $$$AssertEquals($Get(^IRISCouch.Metrics("req", "document", "PUT")), 1, "document PUT count is 1")
    Do $$$AssertEquals($Get(^IRISCouch.Metrics("req", "database", "GET")), 1, "database GET count is 1")
}

/// <p>Test IncrementStatus atomically increments status code counters.</p>
/// <p>AC #4: Per-status-code error counters are recorded.</p>
Method TestIncrementStatus()
{
    Do ##class(IRISCouch.Metrics.Collector).IncrementStatus(200)
    Do ##class(IRISCouch.Metrics.Collector).IncrementStatus(200)
    Do ##class(IRISCouch.Metrics.Collector).IncrementStatus(404)
    Do ##class(IRISCouch.Metrics.Collector).IncrementStatus(500)
    ; Verify counters
    Do $$$AssertEquals($Get(^IRISCouch.Metrics("status", 200)), 2, "200 count is 2")
    Do $$$AssertEquals($Get(^IRISCouch.Metrics("status", 404)), 1, "404 count is 1")
    Do $$$AssertEquals($Get(^IRISCouch.Metrics("status", 500)), 1, "500 count is 1")
}

/// <p>Test RecordLatency updates histogram buckets, sum, and count.</p>
/// <p>AC #3: Latency histograms per endpoint class are recorded.</p>
Method TestRecordLatency()
{
    ; 50ms = 0.05s — should increment buckets 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0, +Inf
    Do ##class(IRISCouch.Metrics.Collector).RecordLatency("document", 50)
    ; Verify bucket increments — 0.05s exactly hits the 0.05 bucket
    Do $$$AssertEquals(+$Get(^IRISCouch.Metrics("lat", "document", 0.005), 0), 0, "0.005 bucket not incremented for 50ms")
    Do $$$AssertEquals(+$Get(^IRISCouch.Metrics("lat", "document", 0.01), 0), 0, "0.01 bucket not incremented for 50ms")
    Do $$$AssertEquals(+$Get(^IRISCouch.Metrics("lat", "document", 0.025), 0), 0, "0.025 bucket not incremented for 50ms")
    Do $$$AssertEquals(+$Get(^IRISCouch.Metrics("lat", "document", 0.05), 0), 1, "0.05 bucket incremented for 50ms")
    Do $$$AssertEquals(+$Get(^IRISCouch.Metrics("lat", "document", 0.1), 0), 1, "0.1 bucket incremented for 50ms")
    Do $$$AssertEquals(+$Get(^IRISCouch.Metrics("lat", "document", 0.25), 0), 1, "0.25 bucket incremented for 50ms")
    Do $$$AssertEquals(+$Get(^IRISCouch.Metrics("lat", "document", "+Inf"), 0), 1, "+Inf bucket always incremented")
    ; Verify sum and count
    Do $$$AssertEquals(+$Get(^IRISCouch.Metrics("lat", "document", "count"), 0), 1, "count is 1")
    Set tSum = +$Get(^IRISCouch.Metrics("lat", "document", "sum"), 0)
    Do $$$AssertTrue(tSum = 0.05, "sum is 0.05 seconds")
}

/// <p>Test RecordLatency with very small latency falls in smallest bucket.</p>
Method TestRecordLatencySmall()
{
    ; 1ms = 0.001s — 0.001 <= 0.005, so it DOES hit the 0.005 bucket and all above
    Do ##class(IRISCouch.Metrics.Collector).RecordLatency("server", 1)
    Do $$$AssertEquals(+$Get(^IRISCouch.Metrics("lat", "server", 0.005), 0), 1, "0.005 bucket hit for 1ms (0.001 <= 0.005)")
    Do $$$AssertEquals(+$Get(^IRISCouch.Metrics("lat", "server", 0.01), 0), 1, "0.01 bucket hit for 1ms")
    Do $$$AssertEquals(+$Get(^IRISCouch.Metrics("lat", "server", "+Inf"), 0), 1, "+Inf bucket always incremented for 1ms")
    Do $$$AssertEquals(+$Get(^IRISCouch.Metrics("lat", "server", "count"), 0), 1, "count is 1 for 1ms")
}

/// <p>Test ClassifyEndpoint maps URLs to coarse endpoint categories.</p>
/// <p>AC #5: Labels use coarse endpoint categories only (NFR-O2).</p>
Method TestClassifyEndpoint()
{
    ; Server-level
    Do $$$AssertEquals(##class(IRISCouch.Metrics.Record).ClassifyEndpoint("/iris-couch/"), "server", "/ maps to server")
    Do $$$AssertEquals(##class(IRISCouch.Metrics.Record).ClassifyEndpoint("/iris-couch/_uuids"), "server", "/_uuids maps to server")
    Do $$$AssertEquals(##class(IRISCouch.Metrics.Record).ClassifyEndpoint("/iris-couch/_all_dbs"), "server", "/_all_dbs maps to server")
    ; Auth
    Do $$$AssertEquals(##class(IRISCouch.Metrics.Record).ClassifyEndpoint("/iris-couch/_session"), "auth", "/_session maps to auth")
    ; Metrics
    Do $$$AssertEquals(##class(IRISCouch.Metrics.Record).ClassifyEndpoint("/iris-couch/_prometheus"), "metrics", "/_prometheus maps to metrics")
    ; Database
    Do $$$AssertEquals(##class(IRISCouch.Metrics.Record).ClassifyEndpoint("/iris-couch/testdb"), "database", "/testdb maps to database")
    ; Database maintenance
    Do $$$AssertEquals(##class(IRISCouch.Metrics.Record).ClassifyEndpoint("/iris-couch/testdb/_compact"), "database", "/_compact maps to database")
    Do $$$AssertEquals(##class(IRISCouch.Metrics.Record).ClassifyEndpoint("/iris-couch/testdb/_revs_limit"), "database", "/_revs_limit maps to database")
    Do $$$AssertEquals(##class(IRISCouch.Metrics.Record).ClassifyEndpoint("/iris-couch/testdb/_ensure_full_commit"), "database", "/_ensure_full_commit maps to database")
    ; Document
    Do $$$AssertEquals(##class(IRISCouch.Metrics.Record).ClassifyEndpoint("/iris-couch/testdb/doc123"), "document", "/testdb/doc123 maps to document")
    Do $$$AssertEquals(##class(IRISCouch.Metrics.Record).ClassifyEndpoint("/iris-couch/testdb/_bulk_docs"), "document", "/_bulk_docs maps to document")
    Do $$$AssertEquals(##class(IRISCouch.Metrics.Record).ClassifyEndpoint("/iris-couch/testdb/_bulk_get"), "document", "/_bulk_get maps to document")
    Do $$$AssertEquals(##class(IRISCouch.Metrics.Record).ClassifyEndpoint("/iris-couch/testdb/_all_docs"), "document", "/_all_docs maps to document")
    ; Changes
    Do $$$AssertEquals(##class(IRISCouch.Metrics.Record).ClassifyEndpoint("/iris-couch/testdb/_changes"), "changes", "/_changes maps to changes")
    ; Mango
    Do $$$AssertEquals(##class(IRISCouch.Metrics.Record).ClassifyEndpoint("/iris-couch/testdb/_find"), "mango", "/_find maps to mango")
    Do $$$AssertEquals(##class(IRISCouch.Metrics.Record).ClassifyEndpoint("/iris-couch/testdb/_explain"), "mango", "/_explain maps to mango")
    Do $$$AssertEquals(##class(IRISCouch.Metrics.Record).ClassifyEndpoint("/iris-couch/testdb/_index"), "mango", "/_index maps to mango")
    ; Replication
    Do $$$AssertEquals(##class(IRISCouch.Metrics.Record).ClassifyEndpoint("/iris-couch/testdb/_revs_diff"), "replication", "/_revs_diff maps to replication")
    Do $$$AssertEquals(##class(IRISCouch.Metrics.Record).ClassifyEndpoint("/iris-couch/testdb/_local/checkpoint1"), "replication", "/_local/* maps to replication")
    ; Security
    Do $$$AssertEquals(##class(IRISCouch.Metrics.Record).ClassifyEndpoint("/iris-couch/testdb/_security"), "security", "/_security maps to security")
    ; Attachment
    Do $$$AssertEquals(##class(IRISCouch.Metrics.Record).ClassifyEndpoint("/iris-couch/testdb/doc123/att.txt"), "attachment", "/testdb/doc/att maps to attachment")
}

/// <p>Test that Record does NOT store metrics when METRICSENABLED=0.</p>
/// <p>AC #7: No metrics recorded when disabled (zero overhead).</p>
Method TestRecordDisabledWhenConfigOff()
{
    ; Disable metrics
    Set ^IRISCouch.Config("METRICSENABLED") = "0"
    ; Record a request
    Do ##class(IRISCouch.Metrics.Record).Record("document", "GET", 200, 50)
    ; Verify nothing was stored
    Do $$$AssertTrue('$Data(^IRISCouch.Metrics("req", "document", "GET")), "No request counter when disabled")
    Do $$$AssertTrue('$Data(^IRISCouch.Metrics("status", 200)), "No status counter when disabled")
    Do $$$AssertTrue('$Data(^IRISCouch.Metrics("lat", "document")), "No latency data when disabled")
}

/// <p>Test that Record stores metrics when METRICSENABLED=1 (default).</p>
Method TestRecordEnabledByDefault()
{
    ; Ensure default (enabled)
    Kill ^IRISCouch.Config("METRICSENABLED")
    ; Record a request
    Do ##class(IRISCouch.Metrics.Record).Record("document", "GET", 200, 50)
    ; Verify metrics were stored
    Do $$$AssertEquals(+$Get(^IRISCouch.Metrics("req", "document", "GET")), 1, "Request counter incremented when enabled")
    Do $$$AssertEquals(+$Get(^IRISCouch.Metrics("status", 200)), 1, "Status counter incremented when enabled")
    Do $$$AssertEquals(+$Get(^IRISCouch.Metrics("lat", "document", "count")), 1, "Latency count incremented when enabled")
}

/// <p>Test that the Prometheus endpoint renders valid text format.</p>
/// <p>AC #1: Response contains Prometheus text format metrics.</p>
Method TestPrometheusFormat()
{
    ; Record some metrics
    Do ##class(IRISCouch.Metrics.Collector).IncrementRequest("document", "GET")
    Do ##class(IRISCouch.Metrics.Collector).IncrementRequest("document", "GET")
    Do ##class(IRISCouch.Metrics.Collector).IncrementStatus(200)
    Do ##class(IRISCouch.Metrics.Collector).IncrementStatus(200)
    Do ##class(IRISCouch.Metrics.Collector).RecordLatency("document", 50)
    ; Build the output
    Set tOutput = ##class(IRISCouch.Metrics.Endpoint).BuildOutput()
    ; Verify HELP and TYPE declarations
    Do $$$AssertTrue(tOutput [ "# HELP iriscouch_http_requests_total", "Output contains requests HELP line")
    Do $$$AssertTrue(tOutput [ "# TYPE iriscouch_http_requests_total counter", "Output contains requests TYPE line")
    Do $$$AssertTrue(tOutput [ "# HELP iriscouch_http_status_total", "Output contains status HELP line")
    Do $$$AssertTrue(tOutput [ "# TYPE iriscouch_http_status_total counter", "Output contains status TYPE line")
    Do $$$AssertTrue(tOutput [ "# HELP iriscouch_http_request_duration_seconds", "Output contains latency HELP line")
    Do $$$AssertTrue(tOutput [ "# TYPE iriscouch_http_request_duration_seconds histogram", "Output contains latency TYPE line")
    Do $$$AssertTrue(tOutput [ "# HELP iriscouch_database_count", "Output contains database count HELP line")
    Do $$$AssertTrue(tOutput [ "# TYPE iriscouch_database_count gauge", "Output contains database count TYPE line")
    ; Verify metric values
    Do $$$AssertTrue(tOutput [ "iriscouch_http_requests_total{endpoint=""document"",method=""GET""} 2", "Output contains document GET count")
    Do $$$AssertTrue(tOutput [ "iriscouch_http_status_total{code=""200""} 2", "Output contains 200 status count")
    ; Verify histogram bucket values are correct (not double-counted)
    ; 50ms = 0.05s: buckets 0.005-0.025 should be 0, bucket 0.05+ should be 1
    Do $$$AssertTrue(tOutput [ "iriscouch_http_request_duration_seconds_bucket{endpoint=""document"",le=""0.005""} 0", "0.005 bucket is 0 for 50ms request")
    Do $$$AssertTrue(tOutput [ "iriscouch_http_request_duration_seconds_bucket{endpoint=""document"",le=""0.05""} 1", "0.05 bucket is 1 for 50ms request")
    Do $$$AssertTrue(tOutput [ "iriscouch_http_request_duration_seconds_bucket{endpoint=""document"",le=""0.1""} 1", "0.1 bucket is 1 (cumulative, not double-counted)")
    Do $$$AssertTrue(tOutput [ "iriscouch_http_request_duration_seconds_bucket{endpoint=""document"",le=""+Inf""} 1", "+Inf bucket equals total count")
    Do $$$AssertTrue(tOutput [ "iriscouch_http_request_duration_seconds_count{endpoint=""document""} 1", "Output contains latency count")
    Do $$$AssertTrue(tOutput [ "iriscouch_http_request_duration_seconds_sum{endpoint=""document""}", "Output contains latency sum")
}

/// <p>Test that metrics collection failures are safely isolated.</p>
/// <p>AC #6: Metric collection failure does not affect other operations (NFR-O3).</p>
Method TestMetricsFailureSafe()
{
    ; Record.Record is entirely Try/Catch wrapped — calling with empty args should not error
    Do ##class(IRISCouch.Metrics.Record).Record("", "", 0, 0)
    ; If we reach this assertion, the method did not throw
    Do $$$AssertTrue(1, "Record with empty args does not throw")
    ; ClassifyEndpoint with garbage input should return "unknown"
    Set tCategory = ##class(IRISCouch.Metrics.Record).ClassifyEndpoint("")
    Do $$$AssertEquals(tCategory, "server", "Empty URL classifies safely")
    ; Endpoint BuildOutput with no metrics should not error
    Set tOutput = ##class(IRISCouch.Metrics.Endpoint).BuildOutput()
    Do $$$AssertTrue(tOutput '= "", "BuildOutput with no request metrics still produces HELP/TYPE headers")
}

/// <p>Test that Record skips metrics for the metrics endpoint itself.</p>
Method TestMetricsEndpointNotRecorded()
{
    ; Record with "metrics" endpoint category
    Do ##class(IRISCouch.Metrics.Record).Record("metrics", "GET", 200, 10)
    ; Verify nothing was stored
    Do $$$AssertTrue('$Data(^IRISCouch.Metrics("req", "metrics", "GET")), "metrics endpoint not recorded for requests")
    Do $$$AssertTrue('$Data(^IRISCouch.Metrics("status", 200)), "metrics endpoint not recorded for status")
}

/// <p>Test Reset clears all metrics data.</p>
Method TestReset()
{
    ; Record some data
    Do ##class(IRISCouch.Metrics.Collector).IncrementRequest("document", "GET")
    Do ##class(IRISCouch.Metrics.Collector).IncrementStatus(200)
    Do ##class(IRISCouch.Metrics.Collector).RecordLatency("document", 50)
    ; Verify data exists
    Do $$$AssertTrue($Data(^IRISCouch.Metrics), "Metrics data exists before reset")
    ; Reset
    Do ##class(IRISCouch.Metrics.Collector).Reset()
    ; Verify data is gone
    Do $$$AssertTrue('$Data(^IRISCouch.Metrics), "Metrics data cleared after reset")
}

}
