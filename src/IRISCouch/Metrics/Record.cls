/// <p>Metrics recording API for IRISCouch.</p>
/// <p>Provides a single entry point for recording HTTP request metrics.
/// Checks the <code>METRICSENABLED</code> configuration toggle and delegates
/// to <class>IRISCouch.Metrics.Collector</class> for atomic global updates.</p>
/// <p>All methods are wrapped in Try/Catch to satisfy NFR-O3: metrics
/// failures must never propagate to callers.</p>
Class IRISCouch.Metrics.Record Extends %RegisteredObject
{

/// <p>Record all metrics for a completed HTTP request.</p>
/// <p>Checks <code>Config.Get("METRICSENABLED")</code> first — if "0",
/// returns immediately with zero overhead. Otherwise records request count,
/// status code, and latency histogram via <class>Collector</class>.</p>
/// @param pEndpoint The coarse endpoint category (e.g., "document", "database")
/// @param pMethod The HTTP method (e.g., "GET", "PUT")
/// @param pStatus The HTTP response status code (e.g., 200, 404)
/// @param pDurationMs The request duration in milliseconds
ClassMethod Record(pEndpoint As %String, pMethod As %String, pStatus As %Integer, pDurationMs As %Numeric)
{
    Try {
        ; Check if metrics are enabled
        If ##class(IRISCouch.Config).Get("METRICSENABLED") = "0" Quit
        ; Don't record metrics about the metrics endpoint itself
        If pEndpoint = "metrics" Quit
        ; Record all metric types
        Do ##class(IRISCouch.Metrics.Collector).IncrementRequest(pEndpoint, pMethod)
        Do ##class(IRISCouch.Metrics.Collector).IncrementStatus(pStatus)
        Do ##class(IRISCouch.Metrics.Collector).RecordLatency(pEndpoint, pDurationMs)
    }
    Catch ex {
        ; NFR-O3: never propagate metrics failures
    }
}

/// <p>Classify a request URL into a coarse endpoint category.</p>
/// <p>Maps raw URLs to bounded-cardinality categories to prevent
/// label explosion in Prometheus. Never includes document IDs or
/// database names in the returned category (NFR-O2).</p>
/// @param pUrl The raw request URL (e.g., "/iris-couch/testdb/_find")
/// @return The endpoint category string
ClassMethod ClassifyEndpoint(pUrl As %String) As %String
{
    Set tCategory = "unknown"
    Try {
        ; Strip the web app prefix (/iris-couch/) if present
        Set tPath = pUrl
        Set tWebApp = ##class(IRISCouch.Config).Get("WEBAPPPATH")
        If $Extract(tPath, 1, $Length(tWebApp)) = tWebApp {
            Set tPath = $Extract(tPath, $Length(tWebApp) + 1, *)
        }
        ; Ensure leading slash
        If $Extract(tPath, 1) '= "/" Set tPath = "/" _ tPath
        ; Normalize: remove trailing slash if not root
        If ($Length(tPath) > 1) && ($Extract(tPath, $Length(tPath)) = "/") {
            Set tPath = $Extract(tPath, 1, $Length(tPath) - 1)
        }
        ; Count segments (split by /)
        ; /path => 2 pieces ("", "path")
        Set tSegCount = $Length(tPath, "/") - 1
        Set tSeg1 = $Piece(tPath, "/", 2)
        Set tSeg2 = $Piece(tPath, "/", 3)
        Set tSeg3 = $Piece(tPath, "/", 4)
        ; --- Server-level endpoints ---
        If tPath = "/" Set tCategory = "server" Quit
        If tPath = "/_prometheus" Set tCategory = "metrics" Quit
        If tPath = "/_session" Set tCategory = "auth" Quit
        If tPath = "/_uuids" Set tCategory = "server" Quit
        If tPath = "/_all_dbs" Set tCategory = "server" Quit
        ; --- Database sub-resource endpoints ---
        ; tSeg1 = database name, tSeg2 = sub-resource
        If tSegCount >= 2 {
            ; Mango endpoints
            If (tSeg2 = "_find") || (tSeg2 = "_explain") || (tSeg2 = "_index") {
                Set tCategory = "mango" Quit
            }
            ; Changes feed
            If tSeg2 = "_changes" Set tCategory = "changes" Quit
            ; Bulk/all_docs document operations
            If (tSeg2 = "_bulk_docs") || (tSeg2 = "_bulk_get") || (tSeg2 = "_all_docs") {
                Set tCategory = "document" Quit
            }
            ; Replication endpoints
            If (tSeg2 = "_revs_diff") || (tSeg2 = "_local") {
                Set tCategory = "replication" Quit
            }
            ; Security
            If tSeg2 = "_security" Set tCategory = "security" Quit
            ; Database maintenance
            If (tSeg2 = "_compact") || (tSeg2 = "_revs_limit") || (tSeg2 = "_ensure_full_commit") {
                Set tCategory = "database" Quit
            }
        }
        ; --- Attachment: /{db}/{docid}/{attname} ---
        If tSegCount >= 3 {
            Set tCategory = "attachment" Quit
        }
        ; --- Document: /{db}/{docid} ---
        If tSegCount = 2 {
            Set tCategory = "document" Quit
        }
        ; --- Database: /{db} ---
        If tSegCount = 1 {
            Set tCategory = "database" Quit
        }
    }
    Catch ex {
        ; NFR-O3: never propagate — return "unknown" on any error
        Set tCategory = "unknown"
    }
    Quit tCategory
}

}
