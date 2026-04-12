/// <p>Centralized error response rendering for IRISCouch.</p>
/// <p>This is the single entry point for all error responses.
/// Handlers must NEVER construct error JSON inline.</p>
/// <p>For 500 errors (NFR-S8): the reason sent to client must be generic.
/// Full stack traces go to IRIS logs only via <code>$System.Status.DisplayError()</code>.</p>
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

}
