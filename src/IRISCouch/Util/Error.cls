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
