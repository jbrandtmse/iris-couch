/// <p>Globals-based metrics accumulator for IRISCouch.</p>
/// <p>Provides lock-free, atomic metric recording using <code>$Increment</code>
/// on the <code>^IRISCouch.Metrics</code> global. All methods are class methods
/// and are safe to call from any process without locking.</p>
/// <p>Global storage layout:</p>
/// <ul>
///   <li><code>^IRISCouch.Metrics("req", endpoint, method)</code> — request counter</li>
///   <li><code>^IRISCouch.Metrics("status", statusCode)</code> — status code counter</li>
///   <li><code>^IRISCouch.Metrics("lat", endpoint, bucket)</code> — latency histogram bucket</li>
///   <li><code>^IRISCouch.Metrics("lat", endpoint, "sum")</code> — latency sum (seconds)</li>
///   <li><code>^IRISCouch.Metrics("lat", endpoint, "count")</code> — latency count</li>
/// </ul>
Class IRISCouch.Metrics.Collector Extends %RegisteredObject
{

/// <p>Standard Prometheus histogram bucket boundaries in seconds.</p>
/// <p>Each request increments ALL buckets where duration &lt;= bucket boundary,
/// plus the +Inf bucket always.</p>
Parameter BUCKETS = "0.005,0.01,0.025,0.05,0.1,0.25,0.5,1.0,2.5,5.0,10.0";

/// <p>Atomically increment the request counter for an endpoint and HTTP method.</p>
/// @param pEndpoint The coarse endpoint category (e.g., "document", "database")
/// @param pMethod The HTTP method (e.g., "GET", "PUT")
ClassMethod IncrementRequest(pEndpoint As %String, pMethod As %String)
{
    Try {
        Set tVal = $Increment(^IRISCouch.Metrics("req", pEndpoint, pMethod))
    }
    Catch ex {
        ; NFR-O3: never propagate metrics failures
    }
}

/// <p>Atomically increment the status code counter.</p>
/// @param pStatusCode The HTTP status code (e.g., 200, 404)
ClassMethod IncrementStatus(pStatusCode As %Integer)
{
    Try {
        Set tVal = $Increment(^IRISCouch.Metrics("status", pStatusCode))
    }
    Catch ex {
        ; NFR-O3: never propagate metrics failures
    }
}

/// <p>Record a request latency in the histogram.</p>
/// <p>Converts duration from milliseconds to seconds, then increments all
/// histogram buckets where the duration is &lt;= the bucket boundary.
/// Also updates the cumulative sum and count for the endpoint.</p>
/// @param pEndpoint The coarse endpoint category
/// @param pDurationMs The request duration in milliseconds
ClassMethod RecordLatency(pEndpoint As %String, pDurationMs As %Numeric)
{
    Try {
        Set tDurationSec = pDurationMs / 1000
        ; Increment all buckets where duration <= bucket boundary
        Set tBuckets = ..#BUCKETS
        For i = 1:1:$Length(tBuckets, ",") {
            Set tBucket = +$Piece(tBuckets, ",", i)
            If tDurationSec <= tBucket {
                Set tVal = $Increment(^IRISCouch.Metrics("lat", pEndpoint, tBucket))
            }
        }
        ; Always increment +Inf bucket
        Set tVal = $Increment(^IRISCouch.Metrics("lat", pEndpoint, "+Inf"))
        ; Cumulative sum (in seconds)
        Set tVal = $Increment(^IRISCouch.Metrics("lat", pEndpoint, "sum"), tDurationSec)
        ; Total count
        Set tVal = $Increment(^IRISCouch.Metrics("lat", pEndpoint, "count"))
    }
    Catch ex {
        ; NFR-O3: never propagate metrics failures
    }
}

/// <p>Reset all metrics data. Used for testing only.</p>
ClassMethod Reset()
{
    Try {
        Kill ^IRISCouch.Metrics
    }
    Catch ex {
        ; NFR-O3: never propagate metrics failures
    }
}

}
