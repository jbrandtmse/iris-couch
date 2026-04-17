/// <p>HTTP handler for CouchDB design-document view execution (Story 12.1).</p>
/// <p>Handles <code>GET /{db}/_design/{ddoc}/_view/{viewname}</code> and the
/// same path via <code>POST</code> (for large keys arrays). Under Story 12.1
/// the only active <class>IRISCouch.JSRuntime.Sandbox</class> backend is
/// <class>IRISCouch.JSRuntime.None</class>, so this handler always returns
/// 501 Not Implemented with a reason naming <em>view execution</em> and a
/// pointer to <code>documentation/js-runtime.md</code>.</p>
/// <p>The handler still performs the 404 pre-checks so clients get the
/// correct status when the database or design document does not exist,
/// matching CouchDB's observable 404-before-501 behaviour.</p>
/// <p>Story 12.2 will replace the 501 branch with actual map/reduce execution;
/// the handler shell, the 404 checks, and the sandbox lookup all remain.</p>
Class IRISCouch.API.ViewHandler Extends %RegisteredObject
{

/// <p>Handle <code>GET /{db}/_design/{ddoc}/_view/{view}</code>.</p>
/// <p>Flow:</p>
/// <ol>
/// <li>404 if the database does not exist.</li>
/// <li>404 if the design document <code>_design/&lt;ddoc&gt;</code> is missing
///     or has been deleted -- never fall into the JSRuntime path for a doc
///     that isn't there.</li>
/// <li>404 if the design document exists but has no <code>views.&lt;name&gt;</code>
///     entry matching the requested view -- matches CouchDB's behaviour of
///     returning 404 for unknown view names.</li>
/// <li>Resolve the JSRuntime sandbox via <class>IRISCouch.JSRuntime.Factory</class>.</li>
/// <li>If the sandbox is unavailable (None / stubs), render 501 with the
///     subsystem-specific reason. Under Story 12.1 this is the only reachable
///     branch; Stories 12.2/12.4 replace this with real execution.</li>
/// </ol>
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
        ; 5) If the sandbox cannot execute JS, render 501. Calling Execute*
        ;    against an unavailable sandbox would throw -- we short-circuit
        ;    via IsAvailable() so the reason string is predictable and we
        ;    do not rely on try/catch for control flow.
        If 'tSandbox.IsAvailable() {
            Set tSubsystem = "view execution"
            Set tReason = ##class(IRISCouch.Util.Error).BuildJSRuntimeNotImplementedReason(tSubsystem)
            Do ##class(IRISCouch.Audit.Emit).ViewAttempt(pDB, pDDocId, pViewName, 501)
            Do ##class(IRISCouch.Util.Error).Render501(tSubsystem, tReason)
            Quit
        }
        ; 6) Story 12.2 replaces this branch with real map/reduce execution.
        ;    Keep the structure: if an execute path lands here under Story
        ;    12.1, something is wrong -- fall back to an internal error
        ;    rather than leaking a blank response.
        Do ##class(IRISCouch.Audit.Emit).ViewAttempt(pDB, pDDocId, pViewName, 500)
        Do ##class(IRISCouch.Util.Error).RenderInternal(##class(IRISCouch.Util.Error).#SERVERERROR, "view execution reached the executor branch under Story 12.1 (unexpected)")
        Quit
    }
    Catch ex {
        Do ##class(IRISCouch.Util.Error).RenderInternal(##class(IRISCouch.Util.Error).#SERVERERROR, "view: handler error", ex)
        Quit
    }
    Quit $$$OK
}

}
