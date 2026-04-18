/// <p>HTTP handler for CouchDB design-document view execution (Story 12.1
/// scaffold, Story 12.2 wiring).</p>
/// <p>Handles <code>GET /{db}/_design/{ddoc}/_view/{viewname}</code> and
/// the same path via <code>POST</code> (for large keys arrays). When the
/// active <class>IRISCouch.JSRuntime.Sandbox</class> backend reports
/// <method>IsAvailable</method>=1, the handler delegates to
/// <class>IRISCouch.View.QueryEngine</class> for real execution; when the
/// sandbox is unavailable (None / unresolved path), the handler renders
/// 501 with the canonical reason.</p>
/// <p>The 404 pre-checks from Story 12.1 remain unchanged so clients get
/// the correct status when the database, design document, or named view
/// is missing.</p>
Class IRISCouch.API.ViewHandler Extends %RegisteredObject
{

/// <p>Handle <code>GET /{db}/_design/{ddoc}/_view/{view}</code>.</p>
/// @param pDB The database name from the URL path
/// @param pDDocId The composite document id <code>_design/&lt;name&gt;</code>
///                (already reassembled by the Router wrapper method)
/// @param pViewName The view name from the URL path
/// @return %Status
ClassMethod HandleView(pDB As %String, pDDocId As %String, pViewName As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        ; 1) Database must exist
        If '##class(IRISCouch.Storage.Database).Exists(pDB) {
            Do ##class(IRISCouch.Audit.Emit).ViewAttempt(pDB, pDDocId, pViewName, 404)
            Do ##class(IRISCouch.Util.Error).Render(404, ##class(IRISCouch.Util.Error).#NOTFOUND, "Database does not exist.")
            Quit
        }
        ; 2) Design doc must exist and have a live (non-tombstone) winning rev
        If '##class(IRISCouch.Storage.Document).Exists(pDB, pDDocId) {
            Do ##class(IRISCouch.Audit.Emit).ViewAttempt(pDB, pDDocId, pViewName, 404)
            Do ##class(IRISCouch.Util.Error).Render(404, ##class(IRISCouch.Util.Error).#NOTFOUND, "missing")
            Quit
        }
        Set tWinner = ##class(IRISCouch.Storage.RevTree).GetWinner(pDB, pDDocId)
        If tWinner = "" {
            Do ##class(IRISCouch.Audit.Emit).ViewAttempt(pDB, pDDocId, pViewName, 404)
            Do ##class(IRISCouch.Util.Error).Render(404, ##class(IRISCouch.Util.Error).#NOTFOUND, "missing")
            Quit
        }
        If ##class(IRISCouch.Storage.RevTree).IsDeleted(pDB, pDDocId, tWinner) {
            Do ##class(IRISCouch.Audit.Emit).ViewAttempt(pDB, pDDocId, pViewName, 404)
            Do ##class(IRISCouch.Util.Error).Render(404, ##class(IRISCouch.Util.Error).#NOTFOUND, "missing")
            Quit
        }
        ; 3) Parse the design doc and confirm the view name exists.
        Set tDDocBody = ##class(IRISCouch.Storage.Document).Read(pDB, pDDocId, tWinner)
        If tDDocBody = "" {
            Do ##class(IRISCouch.Audit.Emit).ViewAttempt(pDB, pDDocId, pViewName, 404)
            Do ##class(IRISCouch.Util.Error).Render(404, ##class(IRISCouch.Util.Error).#NOTFOUND, "missing")
            Quit
        }
        Set tDDocObj = {}
        Try {
            Set tDDocObj = ##class(%DynamicObject).%FromJSON(tDDocBody)
        } Catch ex {
            Do ##class(IRISCouch.Audit.Emit).ViewAttempt(pDB, pDDocId, pViewName, 500)
            Do ##class(IRISCouch.Util.Error).RenderInternal(##class(IRISCouch.Util.Error).#SERVERERROR, "design doc is not valid JSON", ex)
            Quit
        }
        Set tViews = tDDocObj.%Get("views")
        If '$IsObject(tViews) || '(tViews.%IsDefined(pViewName)) {
            Do ##class(IRISCouch.Audit.Emit).ViewAttempt(pDB, pDDocId, pViewName, 404)
            Do ##class(IRISCouch.Util.Error).Render(404, ##class(IRISCouch.Util.Error).#NOTFOUND, "missing_named_view")
            Quit
        }
        ; 4) Resolve the active sandbox.
        Set tSandbox = ##class(IRISCouch.JSRuntime.Factory).GetSandbox()
        ; 5) If the sandbox cannot execute JS, render 501. IsAvailable()
        ;    short-circuits before any Execute* call so the reason string
        ;    is predictable and we don't rely on try/catch for control flow.
        ;    When the configured backend is Subprocess but the interpreter
        ;    or entry-point script is missing we emit a diagnostic reason
        ;    rather than the canonical "backend is set to None" text -- the
        ;    operator needs to know WHICH knob to flip.
        If 'tSandbox.IsAvailable() {
            Set tSubsystem = "view execution"
            Set tConfiguredBackend = ##class(IRISCouch.Config).Get("JSRUNTIME")
            If tConfiguredBackend = "Subprocess" {
                Set tReason = "JSRuntime=Subprocess is configured but the interpreter or couchjs-entry.js script is not accessible; view execution is blocked. Verify JSRUNTIMESUBPROCESSPATH points at a real interpreter and that the entry-point script exists. See documentation/js-runtime.md."
            } ElseIf tConfiguredBackend = "Python" {
                Set tReason = "JSRuntime=Python is configured but the Python backend is not yet implemented (Story 12.4); view execution is blocked. See documentation/js-runtime.md."
            } Else {
                Set tReason = ##class(IRISCouch.Util.Error).BuildJSRuntimeNotImplementedReason(tSubsystem)
            }
            Do ##class(IRISCouch.Audit.Emit).ViewAttempt(pDB, pDDocId, pViewName, 501)
            Do ##class(IRISCouch.Util.Error).Render501(tSubsystem, tReason)
            Quit
        }
        ; 5b) Story 12.5: ETag / 304 short-circuit. Compute the current ETag
        ;     from the view's last-updated seq + definition hash; if the
        ;     client's If-None-Match matches, return 304 with no body.
        Set tCurrentEtag = ..ComputeEtag(pDB, pDDocId, pViewName, tDDocObj)
        Set tIfNoneMatch = ""
        Try { Set tIfNoneMatch = %request.GetCgiEnv("HTTP_IF_NONE_MATCH") } Catch { Set tIfNoneMatch = "" }
        If (tCurrentEtag '= "") && (tIfNoneMatch '= "") && (tIfNoneMatch = tCurrentEtag) {
            Do ##class(IRISCouch.Audit.Emit).ViewAttempt(pDB, pDDocId, pViewName, 304)
            Do %response.SetHeader("ETag", tCurrentEtag)
            Do %response.SetHeader("Cache-Control", "must-revalidate")
            Set %response.Status = "304 Not Modified"
            Quit
        }
        ; 6) Story 12.2: delegate to the QueryEngine for real map/reduce.
        Set tParams = ..ExtractQueryParams()
        Set tStartTicks = $ZHorolog
        Set tRespRendered = 0
        Try {
            Set tResp = ##class(IRISCouch.View.QueryEngine).Query(pDB, pDDocId, pViewName, tParams, tSandbox)
        } Catch exQE {
            Set tDuration = ($ZHorolog - tStartTicks) * 1000
            ; Map known exception codes to their proper HTTP status. CouchDB
            ; distinguishes client-caused query errors (400) and missing
            ; resources (404) from execution failures (500). QueryEngine
            ; throws %Exception.General with Code set to "query_parse_error"
            ; or "not_found" for cases that should surface as 4xx rather
            ; than 500.
            Set tRespRendered = 1
            Set tExCode = ""
            Try { Set tExCode = exQE.Code } Catch { Set tExCode = "" }
            If tExCode = "query_parse_error" {
                Do ##class(IRISCouch.Audit.Emit).ViewAttempt(pDB, pDDocId, pViewName, 400)
                Do ##class(IRISCouch.Util.Error).Render(400, "query_parse_error", exQE.Data)
            } ElseIf tExCode = "not_found" {
                Do ##class(IRISCouch.Audit.Emit).ViewAttempt(pDB, pDDocId, pViewName, 404)
                Do ##class(IRISCouch.Util.Error).Render(404, ##class(IRISCouch.Util.Error).#NOTFOUND, exQE.Data)
            } Else {
                Do ##class(IRISCouch.Audit.Emit).ViewAttempt(pDB, pDDocId, pViewName, 500)
                Do ##class(IRISCouch.Audit.Emit).ViewError(pDB, pDDocId, pViewName, exQE.DisplayString())
                ; Surface subprocess errors as 500 with a safe reason. Do not
                ; leak subprocess stderr into the client response (NFR-S8).
                Do ##class(IRISCouch.Util.Error).RenderInternal(##class(IRISCouch.Util.Error).#SERVERERROR, "view execution error", exQE)
            }
        }
        ; Only emit the success envelope if the inner Try did not already
        ; render an error response. Argumentless Quit inside the Catch block
        ; only exits the Catch, not the enclosing method, so we guard here.
        If 'tRespRendered {
            Set tDuration = ($ZHorolog - tStartTicks) * 1000
            Set tRowCount = 0
            If $IsObject(tResp), tResp.%IsDefined("rows") {
                Set tRowsArr = tResp.%Get("rows")
                If $IsObject(tRowsArr) Set tRowCount = tRowsArr.%Size()
            }
            Do ##class(IRISCouch.Audit.Emit).ViewAttempt(pDB, pDDocId, pViewName, 200)
            Do ##class(IRISCouch.Audit.Emit).ViewExecute(pDB, pDDocId, pViewName, tRowCount, tDuration)
            ; Story 12.5: emit ETag + last-update-seq headers so clients can
            ; conditional-GET on the next request. The ETag may have moved
            ; during the Rebuild path (cold cache) -- recompute to reflect
            ; the post-query state.
            Set tPostEtag = ..ComputeEtag(pDB, pDDocId, pViewName, tDDocObj)
            Do %response.SetHeader("ETag", tPostEtag)
            Do %response.SetHeader("Cache-Control", "must-revalidate")
            Do %response.SetHeader("X-CouchDB-Last-Update-Seq", ##class(IRISCouch.Storage.ViewIndex).GetLastUpdatedSeq(pDB, pDDocId, pViewName))
            Do ##class(IRISCouch.Util.Response).JSON(tResp)
        }
        Quit
    }
    Catch ex {
        Do ##class(IRISCouch.Util.Error).RenderInternal(##class(IRISCouch.Util.Error).#SERVERERROR, "view: handler error", ex)
        Quit
    }
    Quit $$$OK
}

/// <p>Compute the weak ETag for a view in its current state (Story 12.5).</p>
/// <p>Shape: <code>W/"&lt;seq&gt;-&lt;hash-first-12&gt;"</code>. Both components
/// come from <class>IRISCouch.Storage.ViewIndex</class>. On a cold cache
/// (first query after install or after an invalidation), the cached hash
/// is empty -- we fall back to the live-computed hash so the ETag is still
/// meaningful. Returns an empty string if the view definition cannot be
/// read (caller suppresses the header).</p>
/// @param pDB Database name
/// @param pDDocId Composite design doc id
/// @param pViewName View name
/// @param pDDocObj Parsed design-doc body (already loaded upstream)
/// @return %String The W/"..." ETag, or empty on failure
ClassMethod ComputeEtag(pDB As %String, pDDocId As %String, pViewName As %String, pDDocObj As %DynamicObject) As %String [ Internal ]
{
    Set tEtag = ""
    Try {
        Set tSeq = ##class(IRISCouch.Storage.ViewIndex).GetLastUpdatedSeq(pDB, pDDocId, pViewName)
        Set tHash = ##class(IRISCouch.Storage.ViewIndex).GetViewDefinitionHash(pDB, pDDocId, pViewName)
        If tHash = "" {
            ; Cold cache -- compute live from the design doc.
            Set tViews = pDDocObj.%Get("views")
            If $IsObject(tViews) && tViews.%IsDefined(pViewName) {
                Set tViewDef = tViews.%Get(pViewName)
                Set tMap = tViewDef.%Get("map")
                Set tReduce = $Select(tViewDef.%IsDefined("reduce"): tViewDef.%Get("reduce"), 1: "")
                Set tHash = ##class(IRISCouch.Storage.ViewIndex).ViewDefinitionHash(tMap, tReduce)
            }
        }
        If tHash = "" Quit
        Set tEtag = "W/""" _ tSeq _ "-" _ $Extract(tHash, 1, 12) _ """"
    }
    Catch ex {
        Set tEtag = ""
    }
    Quit tEtag
}

/// <p>Extract the query parameters supported by Story 12.2 into a
/// <class>%DynamicObject</class>.</p>
/// <p>Only <code>reduce</code> and <code>include_docs</code> are honoured
/// for MVP scope. Additional params (<code>group</code>,
/// <code>group_level</code>, <code>startkey</code>, <code>endkey</code>,
/// <code>limit</code>, <code>skip</code>) are silently ignored and
/// deferred to a follow-up story.</p>
ClassMethod ExtractQueryParams() As %DynamicObject [ Internal ]
{
    Set tParams = {}
    If $Data(%request.Data("reduce", 1)) {
        Do tParams.%Set("reduce", $Get(%request.Data("reduce", 1)))
    }
    If $Data(%request.Data("include_docs", 1)) {
        Do tParams.%Set("include_docs", $Get(%request.Data("include_docs", 1)))
    }
    Quit tParams
}

}
