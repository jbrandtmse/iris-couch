/// <p>Prometheus text format metrics endpoint for IRISCouch.</p>
/// <p>Reads accumulated metrics from <code>^IRISCouch.Metrics</code> and renders
/// them in Prometheus exposition text format (version 0.0.4) with proper
/// <code># HELP</code> and <code># TYPE</code> declarations.</p>
/// <p>Wrapped entirely in Try/Catch per NFR-O3: returns empty response
/// on any failure, never errors.</p>
Class IRISCouch.Metrics.Endpoint Extends %RegisteredObject
{

/// <p>Handle GET /_prometheus request.</p>
/// <p>Sets the Content-Type to Prometheus text format, builds the metrics
/// output from the <code>^IRISCouch.Metrics</code> global, and writes it
/// to the HTTP response.</p>
/// @return %Status — always $$$OK
ClassMethod HandlePrometheus() As %Status
{
    Set tSC = $$$OK
    Try {
        Set %response.ContentType = "text/plain; version=0.0.4; charset=utf-8"
        Set tOutput = ..BuildOutput()
        Write tOutput
    }
    Catch ex {
        ; NFR-O3: on failure, return empty response — never error
        Try {
            Set %response.ContentType = "text/plain; version=0.0.4; charset=utf-8"
            Write ""
        }
        Catch ex2 {
            ; Absolute last resort — do nothing
        }
    }
    Quit tSC
}

/// <p>Build the complete Prometheus text format output string.</p>
/// @return The formatted metrics text
ClassMethod BuildOutput() As %String
{
    Set tOut = ""
    ; Request counters
    Set tOut = tOut _ ..RenderRequestCounters()
    ; Status code counters
    Set tOut = tOut _ ..RenderStatusCounters()
    ; Latency histograms
    Set tOut = tOut _ ..RenderLatencyHistograms()
    ; Database count gauge
    Set tOut = tOut _ ..RenderDatabaseCount()
    Quit tOut
}

/// <p>Render iriscouch_http_requests_total counter metrics.</p>
/// @return Prometheus text format lines for request counters
ClassMethod RenderRequestCounters() As %String
{
    Set tOut = ""
    Try {
        Set tOut = "# HELP iriscouch_http_requests_total Total HTTP requests by endpoint and method" _ $Char(10)
        Set tOut = tOut _ "# TYPE iriscouch_http_requests_total counter" _ $Char(10)
        Set tEndpoint = ""
        For {
            Set tEndpoint = $Order(^IRISCouch.Metrics("req", tEndpoint))
            Quit:tEndpoint=""
            Set tMethod = ""
            For {
                Set tMethod = $Order(^IRISCouch.Metrics("req", tEndpoint, tMethod), 1, tCount)
                Quit:tMethod=""
                Set tOut = tOut _ "iriscouch_http_requests_total{endpoint=""" _ tEndpoint _ """,method=""" _ tMethod _ """} " _ +tCount _ $Char(10)
            }
        }
    }
    Catch ex {
        ; NFR-O3: return what we have so far
    }
    Quit tOut
}

/// <p>Render iriscouch_http_status_total counter metrics.</p>
/// @return Prometheus text format lines for status code counters
ClassMethod RenderStatusCounters() As %String
{
    Set tOut = ""
    Try {
        Set tOut = "# HELP iriscouch_http_status_total HTTP responses by status code" _ $Char(10)
        Set tOut = tOut _ "# TYPE iriscouch_http_status_total counter" _ $Char(10)
        Set tCode = ""
        For {
            Set tCode = $Order(^IRISCouch.Metrics("status", tCode), 1, tCount)
            Quit:tCode=""
            Set tOut = tOut _ "iriscouch_http_status_total{code=""" _ tCode _ """} " _ +tCount _ $Char(10)
        }
    }
    Catch ex {
        ; NFR-O3: return what we have so far
    }
    Quit tOut
}

/// <p>Render iriscouch_http_request_duration_seconds histogram metrics.</p>
/// <p>For each endpoint, renders all bucket lines, then _count and _sum.</p>
/// @return Prometheus text format lines for latency histograms
ClassMethod RenderLatencyHistograms() As %String
{
    Set tOut = ""
    Try {
        Set tOut = "# HELP iriscouch_http_request_duration_seconds HTTP request duration histogram" _ $Char(10)
        Set tOut = tOut _ "# TYPE iriscouch_http_request_duration_seconds histogram" _ $Char(10)
        Set tBuckets = ##class(IRISCouch.Metrics.Collector).#BUCKETS
        Set tEndpoint = ""
        For {
            Set tEndpoint = $Order(^IRISCouch.Metrics("lat", tEndpoint))
            Quit:tEndpoint=""
            ; Render each bucket — values are already cumulative in the global
            ; (RecordLatency increments ALL buckets where duration <= boundary)
            For i = 1:1:$Length(tBuckets, ",") {
                Set tBucket = +$Piece(tBuckets, ",", i)
                Set tBucketCount = +$Get(^IRISCouch.Metrics("lat", tEndpoint, tBucket), 0)
                Set tOut = tOut _ "iriscouch_http_request_duration_seconds_bucket{endpoint=""" _ tEndpoint _ """,le=""" _ tBucket _ """} " _ tBucketCount _ $Char(10)
            }
            ; +Inf bucket — equals total count since every request increments +Inf
            Set tTotalCount = +$Get(^IRISCouch.Metrics("lat", tEndpoint, "count"), 0)
            Set tOut = tOut _ "iriscouch_http_request_duration_seconds_bucket{endpoint=""" _ tEndpoint _ """,le=""+Inf""} " _ tTotalCount _ $Char(10)
            ; _count and _sum
            Set tSum = +$Get(^IRISCouch.Metrics("lat", tEndpoint, "sum"), 0)
            Set tOut = tOut _ "iriscouch_http_request_duration_seconds_count{endpoint=""" _ tEndpoint _ """} " _ tTotalCount _ $Char(10)
            Set tOut = tOut _ "iriscouch_http_request_duration_seconds_sum{endpoint=""" _ tEndpoint _ """} " _ tSum _ $Char(10)
        }
    }
    Catch ex {
        ; NFR-O3: return what we have so far
    }
    Quit tOut
}

/// <p>Render iriscouch_database_count gauge metric.</p>
/// <p>Counts databases by iterating <code>^IRISCouch.DB</code>.</p>
/// @return Prometheus text format lines for database count gauge
ClassMethod RenderDatabaseCount() As %String
{
    Set tOut = ""
    Try {
        Set tOut = "# HELP iriscouch_database_count Number of databases" _ $Char(10)
        Set tOut = tOut _ "# TYPE iriscouch_database_count gauge" _ $Char(10)
        Set tCount = 0
        Set tName = ""
        For {
            Set tName = $Order(^IRISCouch.DB(tName))
            Quit:tName=""
            Set tCount = tCount + 1
        }
        Set tOut = tOut _ "iriscouch_database_count " _ tCount _ $Char(10)
    }
    Catch ex {
        ; NFR-O3: return what we have so far
    }
    Quit tOut
}

}
