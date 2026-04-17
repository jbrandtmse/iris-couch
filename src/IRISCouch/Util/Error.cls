/// <p>Centralized error response rendering for IRISCouch.</p>
/// <p>This is the single entry point for all error responses.
/// Handlers must NEVER construct error JSON inline.</p>
/// <p>For 500 errors (NFR-S8): the reason sent to client must be generic.
/// Full stack traces go to IRIS logs only via <method>RenderInternal</method>.</p>
Class IRISCouch.Util.Error Extends %RegisteredObject
{

/// <p>Error slug: Resource not found</p>
Parameter NOTFOUND = "not_found";

/// <p>Error slug: Document revision conflict</p>
Parameter CONFLICT = "conflict";

/// <p>Error slug: Authentication required</p>
Parameter UNAUTHORIZED = "unauthorized";

/// <p>Error slug: Insufficient permissions</p>
Parameter FORBIDDEN = "forbidden";

/// <p>Error slug: Malformed request</p>
Parameter BADREQUEST = "bad_request";

/// <p>Error slug: Document validation failure</p>
Parameter DOCVALIDATION = "doc_validation";

/// <p>Error slug: Resource already exists</p>
Parameter FILEEXISTS = "file_exists";

/// <p>Error slug: Feature not implemented</p>
Parameter NOTIMPLEMENTED = "not_implemented";

/// <p>Error slug: HTTP method not allowed</p>
Parameter METHODNOTALLOWED = "method_not_allowed";

/// <p>Error slug: Invalid content type</p>
Parameter BADCONTENTTYPE = "bad_content_type";

/// <p>Error slug: Precondition failed</p>
Parameter PRECONDITIONFAILED = "precondition_failed";

/// <p>Error slug: Projection backpressure limit reached</p>
Parameter PROJECTIONBACKPRESSURE = "projection_backpressure";

/// <p>Error slug: Illegal database name</p>
Parameter ILLEGALDATABASENAME = "illegal_database_name";

/// <p>Error slug: Internal server error</p>
Parameter SERVERERROR = "server_error";

/// <p>Render a CouchDB-compatible error JSON response.</p>
/// <p>Sets the HTTP status code, content type, and writes a JSON body
/// with <code>error</code> and <code>reason</code> fields.</p>
/// @param pStatus HTTP status code (e.g., 404, 409, 500)
/// @param pSlug Error slug identifier (e.g., "not_found")
/// @param pReason Human-readable reason string
ClassMethod Render(pStatus As %Integer, pSlug As %String, pReason As %String)
{
    Set %response.Status = pStatus
    Set %response.ContentType = "application/json"
    Set tObj = {"error": (pSlug), "reason": (pReason)}
    Write tObj.%ToJSON()
    Quit
}

/// <p>Render an internal server error with safe client output (NFR-S8).</p>
/// <p>Logs the full exception detail to the IRIS console log but sends
/// only a generic reason string to the HTTP client. This prevents
/// stack trace leakage while preserving diagnostic information.</p>
/// @param pSlug Error slug identifier (e.g., "server_error")
/// @param pReason Generic reason string sent to the client
/// @param pException Optional exception object for detailed logging
ClassMethod RenderInternal(pSlug As %String, pReason As %String, pException As %Exception.AbstractException = "")
{
    ; Log full exception detail to IRIS system log
    If $IsObject(pException) {
        Do ##class(%SYS.System).WriteToConsoleLog("IRISCouch error: "_pException.DisplayString(), 0, 1)
    }
    ; Structured log — internal error (Story 9.3, NFR-O5)
    Set tLogData = {"reason":(pReason),"slug":(pSlug)}
    If $IsObject(pException) {
        Do tLogData.%Set("exception", pException.DisplayString())
    }
    Do ##class(IRISCouch.Util.Log).Error("system", "Internal error", tLogData)
    ; Send generic reason to client (NFR-S8)
    Do ..Render(500, pSlug, pReason)
    Quit
}

/// <p>Render the Story 12.3 AC #4 "validate present but runtime is None" 501.</p>
/// <p>Story 12.1's "migration-friendly no-op" semantics let a database stage
/// design docs that declare <code>validate_doc_update</code> while no JS
/// runtime is installed. Story 12.3 tightens the rule: once a validate is
/// actually present and <em>would</em> fire on the write, the write is blocked
/// with 501 instead of silently committing. Writes against databases with no
/// validate-defining ddoc continue to pass under <code>JSRUNTIME=None</code>
/// (the <em>exemption</em> path in AC #4).</p>
/// <p>The reason literal is codified by AC #4 and tested verbatim.</p>
ClassMethod RenderValidate501()
{
    Do ..Render501("validate_doc_update hooks", "validate_doc_update hooks require a JSRuntime backend; set ^IRISCouch.Config(""JSRUNTIME"") to Subprocess or Python. See documentation/js-runtime.md.")
    Quit
}

/// <p>Render a <code>validate_doc_update</code> rejection per the prefix in
/// <var>pValidateErrorMessage</var> (Story 12.3).</p>
/// <p>The prefix conventions are set by
/// <method>IRISCouch.JSRuntime.Subprocess.ExecuteValidateDocUpdate</method> and
/// must stay in sync:</p>
/// <ul>
/// <li><code>"forbidden: &lt;reason&gt;"</code> → HTTP 403 with the canonical
///     CouchDB envelope <code>{"error":"forbidden","reason":"&lt;reason&gt;"}</code></li>
/// <li><code>"unauthorized: &lt;reason&gt;"</code> → HTTP 401 with
///     <code>{"error":"unauthorized","reason":"&lt;reason&gt;"}</code></li>
/// <li>Anything else → HTTP 500 via <method>RenderInternal</method> with the
///     raw message logged (never leaked to the client)</li>
/// </ul>
/// <p>See <code>sources/couchdb/share/server/validate.js</code> for the
/// upstream mapping.</p>
/// @param pValidateErrorMessage The full error text returned by the JSRuntime
ClassMethod RenderValidateError(pValidateErrorMessage As %String)
{
    ; Callers are expected to pass an already-peeled message (i.e., without
    ; the locale-specific "ERROR #5001: " / "خطأ #5001: " prefix that
    ; $System.Status.GetErrorText prepends). The shared peel helper lives on
    ; each caller's side so we don't re-peel into our own payload.
    Set tMsg = pValidateErrorMessage
    If $Extract(tMsg, 1, 11) = "forbidden: " {
        Set tReason = $Extract(tMsg, 12, *)
        If tReason = "" Set tReason = "rejected by validate_doc_update"
        Do ..Render(403, ..#FORBIDDEN, tReason)
        Quit
    }
    If $Extract(tMsg, 1, 14) = "unauthorized: " {
        Set tReason = $Extract(tMsg, 15, *)
        If tReason = "" Set tReason = "authentication required by validate_doc_update"
        Do ..Render(401, ..#UNAUTHORIZED, tReason)
        Quit
    }
    ; Other shapes (runtime error, missing ddoc, compilation error) fold to 500
    Do ..RenderInternal(..#SERVERERROR, "validate_doc_update failure: " _ tMsg)
    Quit
}

/// <p>Render a 501 Not Implemented response for a blocked JSRuntime subsystem.</p>
/// <p>Centralises the JSRuntime 501 envelope used by
/// <class>IRISCouch.API.ViewHandler</class>,
/// <class>IRISCouch.API.ChangesHandler</class>, and
/// <class>IRISCouch.Core.DocumentEngine</class>. Sets HTTP status 501,
/// Content-Type <code>application/json</code>, and writes a body of the form
/// <code>{"error":"not_implemented","reason":"&lt;pReason&gt;"}</code>.</p>
/// <p>Callers pass the subsystem label (e.g., <code>view execution</code>) for
/// symmetry with the exception thrown by <class>IRISCouch.JSRuntime.None</class>.
/// The <var>pSubsystem</var> parameter is recorded in structured logs and can
/// be used by callers to grep for blocked subsystems.</p>
/// @param pSubsystem Subsystem label for logging (e.g., <code>view execution</code>)
/// @param pReason Full reason string rendered as the response body's <code>reason</code> field
ClassMethod Render501(pSubsystem As %String, pReason As %String)
{
    ; Emit a structured log line so operators can grep for blocked subsystems.
    Set tLogData = {"subsystem":(pSubsystem),"reason":(pReason)}
    Do ##class(IRISCouch.Util.Log).Info("jsruntime", "501 Not Implemented", tLogData)
    Do ..Render(501, ..#NOTIMPLEMENTED, pReason)
    Quit
}

/// <p>Build the canonical JSRuntime 501 reason string for a blocked subsystem.</p>
/// <p>Single source of truth for the <code>reason</code> field in every 501
/// response emitted when <code>JSRUNTIME=None</code> (or a stub backend) blocks
/// a JS-dependent subsystem. The exact literal body is codified by Story 12.1
/// AC #2 for <em>view execution</em> and extended by AC #4 for every other
/// blocked subsystem. Centralising the template prevents drift between
/// <class>IRISCouch.JSRuntime.None</class> (which throws this reason),
/// <class>IRISCouch.API.ViewHandler</class>, and
/// <class>IRISCouch.API.ChangesHandler</class> (which render it).</p>
/// <p>Template (AC #2 literal):</p>
/// <pre>
/// JSRuntime backend is set to None. Set ^IRISCouch.Config("JSRUNTIME") to
/// "Subprocess" or "Python" to enable &lt;subsystem&gt;. See
/// documentation/js-runtime.md.
/// </pre>
/// @param pSubsystem Subsystem label (e.g., <code>view execution</code>,
///        <code>custom filter functions</code>, <code>validate_doc_update hooks</code>,
///        <code>reduce function</code>)
/// @return The fully-assembled reason string
ClassMethod BuildJSRuntimeNotImplementedReason(pSubsystem As %String) As %String
{
    Quit "JSRuntime backend is set to None. Set ^IRISCouch.Config(""JSRUNTIME"") to ""Subprocess"" or ""Python"" to enable " _ pSubsystem _ ". See documentation/js-runtime.md."
}

/// <p>Render a 405 Method Not Allowed response with Allow header.</p>
/// <p>Sets the <code>Allow</code> HTTP header to indicate which methods
/// are supported for the requested resource.</p>
/// @param pAllowedMethods Comma-separated list of allowed HTTP methods (e.g., "GET, HEAD")
ClassMethod Render405(pAllowedMethods As %String)
{
    Do %response.SetHeader("Allow", pAllowedMethods)
    Do ..Render(405, ..#METHODNOTALLOWED, "Only "_pAllowedMethods_" allowed")
    Quit
}

/// <p>Map an HTTP status code to its default error slug.</p>
/// <p>Returns the most appropriate error slug for the given HTTP status code.
/// Useful when only the status code is known and a slug must be derived.</p>
/// @param pStatusCode HTTP status code (e.g., 404, 409, 500)
/// @return Default error slug string for the given status code
ClassMethod GetSlugForStatus(pStatusCode As %Integer) As %String
{
    If pStatusCode = 400 Quit ..#BADREQUEST
    If pStatusCode = 401 Quit ..#UNAUTHORIZED
    If pStatusCode = 403 Quit ..#FORBIDDEN
    If pStatusCode = 404 Quit ..#NOTFOUND
    If pStatusCode = 405 Quit ..#METHODNOTALLOWED
    If pStatusCode = 409 Quit ..#CONFLICT
    If pStatusCode = 412 Quit ..#PRECONDITIONFAILED
    If pStatusCode = 415 Quit ..#BADCONTENTTYPE
    If pStatusCode = 500 Quit ..#SERVERERROR
    If pStatusCode = 501 Quit ..#NOTIMPLEMENTED
    If pStatusCode = 503 Quit ..#PROJECTIONBACKPRESSURE
    ; Default to server_error for unknown status codes
    Quit ..#SERVERERROR
}

}
