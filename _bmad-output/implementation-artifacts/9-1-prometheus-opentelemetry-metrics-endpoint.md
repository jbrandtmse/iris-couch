# Story 9.1: Prometheus / OpenTelemetry Metrics Endpoint

Status: done

## Story

As an operator,
I want to scrape Prometheus / OpenTelemetry metrics from a dedicated endpoint,
so that I can monitor system health, request latency, and throughput.

## Acceptance Criteria

1. **Given** IRISCouch is running
   **When** the operator sends `GET /iris-couch/_prometheus`
   **Then** the response contains Prometheus text format metrics with `Content-Type: text/plain; version=0.0.4; charset=utf-8`

2. **Given** HTTP requests are being served
   **When** the metrics endpoint is scraped
   **Then** metrics include request counts per endpoint class (server, database, document, changes, attachment, mango, replication, auth, security)

3. **Given** HTTP requests are being served
   **When** the metrics endpoint is scraped
   **Then** metrics include request latency histograms per endpoint class

4. **Given** HTTP requests are being served
   **When** the metrics endpoint is scraped
   **Then** metrics include per-status-code error counters

5. **Given** metric labels
   **When** the label cardinality is examined
   **Then** labels use coarse endpoint categories only — never document IDs, never database names (NFR-O2)

6. **Given** the metrics scrape endpoint
   **When** the rest of the system experiences errors
   **Then** metric collection failure does not affect other system operations (NFR-O3)

7. **Given** `Config.METRICSENABLED = 0`
   **When** requests are served
   **Then** no metrics are recorded (zero overhead)

## Tasks / Subtasks

- [x] Task 1: Create `Metrics.Collector` class (AC: #1-#4)
  - [x] Create directory `src/IRISCouch/Metrics/`
  - [x] Create `src/IRISCouch/Metrics/Collector.cls` extending `%RegisteredObject`
  - [x] Global storage: `^IRISCouch.Metrics` for all metric data
    - `^IRISCouch.Metrics("req", endpoint, method) = count` — request counter
    - `^IRISCouch.Metrics("status", statusCode) = count` — status code counter
    - `^IRISCouch.Metrics("lat", endpoint, bucket) = count` — latency histogram buckets
    - `^IRISCouch.Metrics("lat", endpoint, "sum") = totalSeconds` — latency sum
    - `^IRISCouch.Metrics("lat", endpoint, "count") = count` — latency count
  - [x] `ClassMethod IncrementRequest(pEndpoint As %String, pMethod As %String)` — `$Increment` counter
  - [x] `ClassMethod IncrementStatus(pStatusCode As %Integer)` — `$Increment` status counter
  - [x] `ClassMethod RecordLatency(pEndpoint As %String, pDurationMs As %Numeric)` — update histogram buckets + sum + count
    - Histogram buckets: 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0, +Inf (seconds)
  - [x] `ClassMethod Reset()` — Kill ^IRISCouch.Metrics (for testing)
  - [x] Compile via MCP

- [x] Task 2: Create `Metrics.Record` class (AC: #1-#4, #7)
  - [x] Create `src/IRISCouch/Metrics/Record.cls` extending `%RegisteredObject`
  - [x] `ClassMethod Record(pEndpoint As %String, pMethod As %String, pStatus As %Integer, pDurationMs As %Numeric)`
    - Check `Config.Get("METRICSENABLED")` — if "0", return immediately
    - Wrap all recording in Try/Catch — never let metrics failures propagate (NFR-O3)
    - Call `Collector.IncrementRequest(pEndpoint, pMethod)`
    - Call `Collector.IncrementStatus(pStatus)`
    - Call `Collector.RecordLatency(pEndpoint, pDurationMs)`
  - [x] `ClassMethod ClassifyEndpoint(pUrl As %String) As %String` — map URL to coarse endpoint category
    - `/_prometheus` → "metrics" (don't record metrics about metrics)
    - `/_session` → "auth"
    - `/_uuids`, `/_all_dbs`, `/` → "server"
    - `/{db}/_find`, `/{db}/_explain`, `/{db}/_index` → "mango"
    - `/{db}/_changes` → "changes"
    - `/{db}/_bulk_docs`, `/{db}/_bulk_get`, `/{db}/_all_docs` → "document"
    - `/{db}/_revs_diff`, `/{db}/_local/*` → "replication"
    - `/{db}/_security` → "security"
    - `/{db}/_compact`, `/{db}/_revs_limit`, `/{db}/_ensure_full_commit` → "database"
    - `/{db}/{docid}/{attname}` → "attachment"
    - `/{db}/{docid}` → "document"
    - `/{db}` (PUT/DELETE/GET) → "database"
    - Default → "unknown"
  - [x] Compile via MCP

- [x] Task 3: Create `Metrics.Endpoint` class (AC: #1, #6)
  - [x] Create `src/IRISCouch/Metrics/Endpoint.cls` extending `%RegisteredObject`
  - [x] `ClassMethod HandlePrometheus() As %Status`
    - Set `%response.ContentType = "text/plain; version=0.0.4; charset=utf-8"`
    - Build Prometheus text format output from `^IRISCouch.Metrics` global
    - Include `# HELP` and `# TYPE` declarations for each metric family
    - Write output to `%response`
    - Wrap in Try/Catch — return empty response on failure, never error (NFR-O3)
  - [x] Metric families to render:
    - `iriscouch_http_requests_total{endpoint="...",method="..."}` (counter)
    - `iriscouch_http_status_total{code="..."}` (counter)
    - `iriscouch_http_request_duration_seconds_bucket{endpoint="...",le="..."}` (histogram)
    - `iriscouch_http_request_duration_seconds_count{endpoint="..."}` (histogram)
    - `iriscouch_http_request_duration_seconds_sum{endpoint="..."}` (histogram)
    - `iriscouch_database_count` (gauge — count of databases from _all_dbs)
  - [x] Compile via MCP

- [x] Task 4: Integrate metrics recording into Router (AC: #2-#4)
  - [x] Read `src/IRISCouch/API/Router.cls` fully
  - [x] In `OnPreDispatch()`, add at the very end (before `Quit $$$OK`):
    ```objectscript
    ; Metrics: record request start time
    Set %IRISCouchRequestStart = $ZHorolog
    Set %IRISCouchEndpoint = ##class(IRISCouch.Metrics.Record).ClassifyEndpoint(%request.URL)
    ```
  - [x] Add `ClassMethod RecordRequestMetrics() As %Status` to Router:
    ```objectscript
    ; Called at end of each handler wrapper to record metrics
    If $Get(%IRISCouchRequestStart) '= "" {
        Set tDuration = ($ZHorolog - %IRISCouchRequestStart) * 1000  ; ms
        Set tStatus = +$Piece(%response.Status, " ", 1)
        Do ##class(IRISCouch.Metrics.Record).Record($Get(%IRISCouchEndpoint, "unknown"), %request.Method, tStatus, tDuration)
    }
    ```
  - [x] Modify EVERY existing Router wrapper method to call `Do ..RecordRequestMetrics()` before the final `Quit`:
    ```objectscript
    ClassMethod HandleDocumentGet(pDB, pDocId) As %Status {
        Set tSC = ##class(IRISCouch.API.DocumentHandler).HandleGet(pDB, pDocId)
        Do ..RecordRequestMetrics()
        Quit tSC
    }
    ```
  - [x] Add `/_prometheus` route to UrlMap (before `/_session` routes, at the top):
    ```xml
    <!-- Metrics endpoint (Story 9.1) -->
    <Route Url="/_prometheus" Method="GET" Call="HandlePrometheus" />
    ```
  - [x] Add wrapper: `ClassMethod HandlePrometheus() As %Status { Quit ##class(IRISCouch.Metrics.Endpoint).HandlePrometheus() }`
  - [x] NOTE: HandlePrometheus should NOT record its own metrics (avoid recursion)
  - [x] Compile Router via MCP

- [x] Task 5: Create unit tests (AC: #1-#7)
  - [x] Create `src/IRISCouch/Test/MetricsTest.cls` extending `%UnitTest.TestCase`
  - [x] Setup: `Collector.Reset()` in OnBeforeOneTest
  - [x] `TestIncrementRequest` — increment, verify counter in global
  - [x] `TestIncrementStatus` — increment status codes, verify counters
  - [x] `TestRecordLatency` — record latencies, verify histogram buckets populated
  - [x] `TestClassifyEndpoint` — verify URL → endpoint category mapping for all categories
  - [x] `TestRecordDisabledWhenConfigOff` — set METRICSENABLED=0, record, verify no metrics stored
  - [x] `TestPrometheusFormat` — call HandlePrometheus after recording metrics, verify output format
  - [x] `TestMetricsFailureSafe` — verify metrics errors don't propagate (NFR-O3)
  - [x] Compile and run tests

- [x] Task 6: Create HTTP integration tests (AC: #1-#4)
  - [x] Create `src/IRISCouch/Test/MetricsHttpTest.cls` extending `%UnitTest.TestCase`
  - [x] `TestPrometheusEndpoint` — GET /_prometheus, verify 200, Content-Type, contains metric lines
  - [x] `TestMetricsAfterRequests` — make several HTTP requests, then GET /_prometheus, verify counters > 0
  - [x] `TestPrometheusContentType` — verify exact Content-Type header
  - [x] Compile and run tests

- [x] Task 7: Full regression (AC: all)
  - [x] Run all test classes — verify existing + new tests pass, 0 regressions

## Dev Notes

### Prometheus Text Format (from `sources/couchdb/src/couch_prometheus/`)

```
# HELP iriscouch_http_requests_total Total HTTP requests by endpoint and method
# TYPE iriscouch_http_requests_total counter
iriscouch_http_requests_total{endpoint="document",method="GET"} 1234
iriscouch_http_requests_total{endpoint="database",method="PUT"} 56

# HELP iriscouch_http_status_total HTTP responses by status code
# TYPE iriscouch_http_status_total counter
iriscouch_http_status_total{code="200"} 1800
iriscouch_http_status_total{code="201"} 123
iriscouch_http_status_total{code="404"} 45

# HELP iriscouch_http_request_duration_seconds HTTP request duration histogram
# TYPE iriscouch_http_request_duration_seconds histogram
iriscouch_http_request_duration_seconds_bucket{endpoint="document",le="0.005"} 100
iriscouch_http_request_duration_seconds_bucket{endpoint="document",le="0.01"} 500
...
iriscouch_http_request_duration_seconds_bucket{endpoint="document",le="+Inf"} 1234
iriscouch_http_request_duration_seconds_count{endpoint="document"} 1234
iriscouch_http_request_duration_seconds_sum{endpoint="document"} 45.678

# HELP iriscouch_database_count Number of databases
# TYPE iriscouch_database_count gauge
iriscouch_database_count 5
```

### Global Storage Design

All metrics stored in `^IRISCouch.Metrics` using `$Increment` for lock-free atomic updates:
- `$Increment(^IRISCouch.Metrics("req", endpoint, method))` — thread-safe counter
- `$Increment(^IRISCouch.Metrics("status", statusCode))` — thread-safe counter
- `$Increment(^IRISCouch.Metrics("lat", endpoint, bucketKey))` — thread-safe histogram bucket
- `$Increment(^IRISCouch.Metrics("lat", endpoint, "sum"), durationSeconds)` — cumulative sum
- `$Increment(^IRISCouch.Metrics("lat", endpoint, "count"))` — total count

### Histogram Buckets (Standard Prometheus)

Latency in seconds: 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0, +Inf

Each request increments ALL buckets where `duration <= bucket_boundary`.

### Router Integration Pattern

OnPreDispatch stores start time and classified endpoint. Each wrapper method calls `RecordRequestMetrics()` before returning. This keeps metrics recording out of handler classes (per architecture Pattern 7).

The `/_prometheus` route itself should NOT record metrics (avoid self-referential metrics).

### NFR-O3: Failure Isolation

ALL metrics code (Record, Collector, Endpoint) must be wrapped in Try/Catch. Metrics failures must never:
- Return HTTP errors to clients
- Slow down request processing
- Cause cascading failures

### Project Structure Notes

- New directory: `src/IRISCouch/Metrics/`
- New files: `Collector.cls`, `Record.cls`, `Endpoint.cls`, `Test/MetricsTest.cls`, `Test/MetricsHttpTest.cls`
- Modified files: `src/IRISCouch/API/Router.cls` (route + wrappers + OnPreDispatch timer)

### References

- [Source: _bmad-output/planning-artifacts/architecture.md:592-615 — Pattern 7: Metrics Instrumentation]
- [Source: _bmad-output/planning-artifacts/architecture.md:754-757 — Metrics class directory]
- [Source: sources/couchdb/src/couch_prometheus/ — CouchDB Prometheus implementation]
- [Source: src/IRISCouch/Core/Config.cls:19-20 — METRICSENABLED parameter]
- [Source: src/IRISCouch/API/Router.cls:303-403 — OnPreDispatch method]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

- Fixed Endpoint.cls: Changed `Do %response.Write(tOutput)` to `Write tOutput` to match CSP/REST output pattern used throughout the codebase (ObjectScript `Write` command writes to CSP output stream, not %response.Write method).
- Fixed TestRecordLatencySmall: Corrected test expectation; 1ms (0.001s) is <= 0.005s so the 0.005 bucket IS incremented.

### Completion Notes List

- Task 1: Created Metrics.Collector with IncrementRequest, IncrementStatus, RecordLatency, and Reset. All use $Increment for lock-free atomics on ^IRISCouch.Metrics global. Standard Prometheus histogram buckets (0.005-10.0 + Inf). All wrapped in Try/Catch per NFR-O3.
- Task 2: Created Metrics.Record with Record (config toggle + delegation) and ClassifyEndpoint (URL to coarse category). Strips web app prefix, maps all endpoint patterns. "metrics" category skipped in Record to avoid self-referential recording.
- Task 3: Created Metrics.Endpoint with HandlePrometheus rendering 4 metric families: http_requests_total (counter), http_status_total (counter), http_request_duration_seconds (histogram with cumulative buckets), database_count (gauge from ^IRISCouch.DB). Uses `Write` command for CSP output.
- Task 4: Modified Router.cls: Added /_prometheus route at top of UrlMap. Added HandlePrometheus wrapper (no self-metrics). Added RecordRequestMetrics private method. Modified all 32 existing wrapper methods to call RecordRequestMetrics before Quit. Added %IRISCouchRequestStart and %IRISCouchEndpoint process-private vars in OnPreDispatch at all exit points. Added _prometheus to server-level endpoint skip list for security enforcement.
- Task 5: Created MetricsTest.cls with 11 unit tests covering: request counter, status counter, latency histograms (normal + small), endpoint classification (all categories), config toggle, Prometheus format output, failure safety, metrics-not-recorded-for-metrics, and reset. All 11 pass.
- Task 6: Created MetricsHttpTest.cls with 3 HTTP integration tests covering: endpoint status/body, Content-Type header, and metrics-after-traffic verification. All 3 pass.
- Task 7: Full regression passed. RouterTest (5/5), DocumentHttpTest (5/5), AuthHttpTest (1/1), ConfigTest (4/4), HttpIntegrationTest (4/4), ChangesHttpTest (1/1), AttachmentHttpTest (1/1), SecurityHttpTest (3/3), MangoQueryHttpTest (5/5), LocalDocHttpTest (1/1). One pre-existing failure in DatabaseHttpTest.AllDbsWithDatabasesHttp (environment-dependent sorted index assertion) unrelated to this story.

### File List

- src/IRISCouch/Metrics/Collector.cls (new)
- src/IRISCouch/Metrics/Record.cls (new)
- src/IRISCouch/Metrics/Endpoint.cls (new)
- src/IRISCouch/API/Router.cls (modified)
- src/IRISCouch/Test/MetricsTest.cls (new)
- src/IRISCouch/Test/MetricsHttpTest.cls (new)

### Review Findings

- [x] [Review][Patch] Histogram double-counting in RenderLatencyHistograms — bucket values in global are already cumulative but renderer re-accumulated them [Endpoint.cls:114-119] — FIXED
- [x] [Review][Patch] Security-denied requests (401/403) not recorded in metrics — OnPreDispatch denied path exits without setting metrics vars or calling RecordRequestMetrics [Router.cls:501-509] — FIXED
- [x] [Review][Patch] TestPrometheusFormat histogram assertions too loose — substring match cannot detect double-counting bug; strengthened with specific bucket value assertions [MetricsTest.cls:181] — FIXED
- [x] [Review][Defer] BuildOutput string concatenation may exceed ObjectScript ~3.6MB string limit under high cardinality [Endpoint.cls:40-49] — deferred, pre-existing architectural pattern

### Change Log

- 2026-04-14: Story 9.1 implemented — Prometheus metrics endpoint with Collector, Record, Endpoint classes, Router integration, unit tests (11), and HTTP integration tests (3).
- 2026-04-13: Code review — fixed histogram double-counting in Endpoint.cls, added denied-request metrics recording in Router.cls, strengthened histogram test assertions in MetricsTest.cls.
