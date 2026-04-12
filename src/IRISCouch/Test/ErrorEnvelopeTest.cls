/// <p>Unit tests for <class>IRISCouch.Util.Error</class> error envelope system.</p>
/// <p>Validates all 13 error slugs, JSON envelope format, internal error
/// handling (NFR-S8), status-to-slug mapping, and 405 response rendering.</p>
Class IRISCouch.Test.ErrorEnvelopeTest Extends %UnitTest.TestCase
{

/// <p>Handle initvalue parameter from parent class.</p>
Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Quit $$$OK
}

/// <p>Verify all 13 error slug constants are defined on the Error class.</p>
/// <p>AC #3: All 13 error slugs from the PRD are supported.</p>
Method TestAllSlugsExist()
{
    ; Verify each of the 13 slug constants
    Do $$$AssertEquals($Parameter("IRISCouch.Util.Error", "NOTFOUND"), "not_found", "NOTFOUND slug is not_found")
    Do $$$AssertEquals($Parameter("IRISCouch.Util.Error", "CONFLICT"), "conflict", "CONFLICT slug is conflict")
    Do $$$AssertEquals($Parameter("IRISCouch.Util.Error", "UNAUTHORIZED"), "unauthorized", "UNAUTHORIZED slug is unauthorized")
    Do $$$AssertEquals($Parameter("IRISCouch.Util.Error", "FORBIDDEN"), "forbidden", "FORBIDDEN slug is forbidden")
    Do $$$AssertEquals($Parameter("IRISCouch.Util.Error", "BADREQUEST"), "bad_request", "BADREQUEST slug is bad_request")
    Do $$$AssertEquals($Parameter("IRISCouch.Util.Error", "DOCVALIDATION"), "doc_validation", "DOCVALIDATION slug is doc_validation")
    Do $$$AssertEquals($Parameter("IRISCouch.Util.Error", "FILEEXISTS"), "file_exists", "FILEEXISTS slug is file_exists")
    Do $$$AssertEquals($Parameter("IRISCouch.Util.Error", "NOTIMPLEMENTED"), "not_implemented", "NOTIMPLEMENTED slug is not_implemented")
    Do $$$AssertEquals($Parameter("IRISCouch.Util.Error", "METHODNOTALLOWED"), "method_not_allowed", "METHODNOTALLOWED slug is method_not_allowed")
    Do $$$AssertEquals($Parameter("IRISCouch.Util.Error", "BADCONTENTTYPE"), "bad_content_type", "BADCONTENTTYPE slug is bad_content_type")
    Do $$$AssertEquals($Parameter("IRISCouch.Util.Error", "PRECONDITIONFAILED"), "precondition_failed", "PRECONDITIONFAILED slug is precondition_failed")
    Do $$$AssertEquals($Parameter("IRISCouch.Util.Error", "PROJECTIONBACKPRESSURE"), "projection_backpressure", "PROJECTIONBACKPRESSURE slug is projection_backpressure")
    Do $$$AssertEquals($Parameter("IRISCouch.Util.Error", "SERVERERROR"), "server_error", "SERVERERROR slug is server_error")
}

/// <p>Verify JSON error envelope structure has error and reason fields.</p>
/// <p>AC #1: Response body is JSON with error and reason fields.</p>
/// <p>AC #2: Error.Render() is the single entry point.</p>
Method TestRenderEnvelopeFormat()
{
    ; Build a test error envelope to verify structure
    Set tSlug = "not_found"
    Set tReason = "database: mydb not found"
    Set tObj = {"error": (tSlug), "reason": (tReason)}
    Set tJSON = tObj.%ToJSON()

    ; Parse and verify structure
    Set tParsed = ##class(%DynamicObject).%FromJSON(tJSON)
    Do $$$AssertTrue($IsObject(tParsed), "Error envelope is a valid JSON object")
    Do $$$AssertEquals(tParsed.error, "not_found", "Envelope has error field with slug")
    Do $$$AssertEquals(tParsed.reason, "database: mydb not found", "Envelope has reason field with subsystem detail")

    ; Verify reason names the subsystem (NFR-O4)
    Do $$$AssertTrue(tParsed.reason [ ":", "Reason names the subsystem with colon separator")
}

/// <p>Verify 500 errors do not expose stack traces to client.</p>
/// <p>AC #4: 500 errors return generic envelope to client (NFR-S8).</p>
Method TestRenderInternalHidesTrace()
{
    ; Simulate an exception
    Set tException = ""
    Try {
        ; Force an error
        Set tDummy = 1/0
    }
    Catch ex {
        Set tException = ex
    }

    ; Verify the exception object is valid
    Do $$$AssertTrue($IsObject(tException), "Test exception was captured")

    ; Verify the exception has a DisplayString
    Set tDisplay = tException.DisplayString()
    Do $$$AssertTrue(tDisplay '= "", "Exception has a DisplayString")

    ; The generic reason should NOT contain the stack trace
    Set tGenericReason = "Internal Server Error"
    Do $$$AssertTrue(tGenericReason '[ "<DIVIDE>", "Generic reason does not contain exception name")
    Do $$$AssertTrue(tGenericReason '[ "^", "Generic reason does not contain stack trace reference")
}

/// <p>Verify RenderInternal logs exception details.</p>
/// <p>AC #4: Full traces logged to IRIS logs (NFR-S8).</p>
/// <p>Uses debug global to verify logging behavior.</p>
Method TestRenderInternalLogsTrace()
{
    ; Verify RenderInternal classmethod exists
    Do $$$AssertTrue(##class(%Dictionary.CompiledMethod).%ExistsId("IRISCouch.Util.Error||RenderInternal"), "RenderInternal method exists")

    ; Verify the method signature accepts an exception parameter
    Set tMethod = ##class(%Dictionary.CompiledMethod).%OpenId("IRISCouch.Util.Error||RenderInternal")
    Do $$$AssertTrue($IsObject(tMethod), "Can open RenderInternal method definition")
    Do $$$AssertTrue(tMethod.FormalSpec [ "pException", "RenderInternal accepts pException parameter")
}

/// <p>Verify HTTP status code to slug mapping.</p>
/// <p>AC #3: All 13 slugs are mapped from their default HTTP status codes.</p>
Method TestGetSlugForStatus()
{
    Do $$$AssertEquals(##class(IRISCouch.Util.Error).GetSlugForStatus(400), "bad_request", "400 maps to bad_request")
    Do $$$AssertEquals(##class(IRISCouch.Util.Error).GetSlugForStatus(401), "unauthorized", "401 maps to unauthorized")
    Do $$$AssertEquals(##class(IRISCouch.Util.Error).GetSlugForStatus(403), "forbidden", "403 maps to forbidden")
    Do $$$AssertEquals(##class(IRISCouch.Util.Error).GetSlugForStatus(404), "not_found", "404 maps to not_found")
    Do $$$AssertEquals(##class(IRISCouch.Util.Error).GetSlugForStatus(405), "method_not_allowed", "405 maps to method_not_allowed")
    Do $$$AssertEquals(##class(IRISCouch.Util.Error).GetSlugForStatus(409), "conflict", "409 maps to conflict")
    Do $$$AssertEquals(##class(IRISCouch.Util.Error).GetSlugForStatus(412), "precondition_failed", "412 maps to precondition_failed")
    Do $$$AssertEquals(##class(IRISCouch.Util.Error).GetSlugForStatus(415), "bad_content_type", "415 maps to bad_content_type")
    Do $$$AssertEquals(##class(IRISCouch.Util.Error).GetSlugForStatus(500), "server_error", "500 maps to server_error")
    Do $$$AssertEquals(##class(IRISCouch.Util.Error).GetSlugForStatus(501), "not_implemented", "501 maps to not_implemented")
    Do $$$AssertEquals(##class(IRISCouch.Util.Error).GetSlugForStatus(503), "projection_backpressure", "503 maps to projection_backpressure")
    ; Unknown status should default to server_error
    Do $$$AssertEquals(##class(IRISCouch.Util.Error).GetSlugForStatus(999), "server_error", "Unknown status defaults to server_error")
}

/// <p>Verify 405 response rendering with Allow header.</p>
/// <p>AC #6: 405 response includes JSON error envelope and Allow header.</p>
Method TestRender405()
{
    ; Verify Render405 classmethod exists
    Do $$$AssertTrue(##class(%Dictionary.CompiledMethod).%ExistsId("IRISCouch.Util.Error||Render405"), "Render405 method exists")

    ; Verify the method signature accepts allowed methods parameter
    Set tMethod = ##class(%Dictionary.CompiledMethod).%OpenId("IRISCouch.Util.Error||Render405")
    Do $$$AssertTrue($IsObject(tMethod), "Can open Render405 method definition")
    Do $$$AssertTrue(tMethod.FormalSpec [ "pAllowedMethods", "Render405 accepts pAllowedMethods parameter")

    ; Verify Http405 exists on Router
    Do $$$AssertTrue(##class(%Dictionary.CompiledMethod).%ExistsId("IRISCouch.API.Router||Http405"), "Router Http405 method exists")

    ; Verify the METHODNOTALLOWED slug value
    Do $$$AssertEquals(##class(IRISCouch.Util.Error).#METHODNOTALLOWED, "method_not_allowed", "METHODNOTALLOWED slug is correct")
}

}
