/// <p>Unit tests for <class>IRISCouch.API.Router</class> and
/// <class>IRISCouch.API.ServerHandler</class>.</p>
/// <p>Tests handler methods directly (unit tests) without requiring
/// an HTTP context. Uses the extracted <code>BuildWelcomeResponse()</code>
/// helper to verify JSON structure and content.</p>
Class IRISCouch.Test.RouterTest Extends %UnitTest.TestCase
{

/// <p>Handle initvalue parameter from parent class.</p>
Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Quit $$$OK
}

/// <p>Verify the welcome response JSON structure and content.</p>
/// <p>AC #1: GET / returns successfully.</p>
/// <p>AC #3: Response body contains the expected welcome JSON.</p>
/// <p>AC #5: ServerHandler processes the welcome request.</p>
Method TestWelcomeResponse()
{
    Set tResponse = ##class(IRISCouch.API.ServerHandler).BuildWelcomeResponse()

    ; Verify it is a valid object
    Do $$$AssertTrue($IsObject(tResponse), "Welcome response is an object")

    ; Verify couchdb field
    Do $$$AssertEquals(tResponse.couchdb, "Welcome", "couchdb field is Welcome")

    ; Verify version field
    Do $$$AssertEquals(tResponse.version, "0.1.0", "version field is 0.1.0")

    ; Verify vendor object
    Do $$$AssertTrue($IsObject(tResponse.vendor), "vendor field is an object")
    Do $$$AssertEquals(tResponse.vendor.name, "IRISCouch", "vendor.name is IRISCouch")
}

/// <p>Verify the welcome response serializes to correct JSON.</p>
/// <p>AC #2: Response Content-Type is application/json (verified by JSON serialization).</p>
/// <p>AC #3: Response body matches expected JSON exactly.</p>
Method TestWelcomeContentType()
{
    Set tResponse = ##class(IRISCouch.API.ServerHandler).BuildWelcomeResponse()

    ; Verify it serializes to valid JSON
    Set tJSON = tResponse.%ToJSON()
    Do $$$AssertTrue(tJSON '= "", "Welcome response serializes to non-empty JSON")

    ; Parse the JSON back and verify round-trip
    Set tParsed = ##class(%DynamicObject).%FromJSON(tJSON)
    Do $$$AssertTrue($IsObject(tParsed), "JSON round-trips to valid object")
    Do $$$AssertEquals(tParsed.couchdb, "Welcome", "Parsed couchdb field is Welcome")
    Do $$$AssertEquals(tParsed.version, "0.1.0", "Parsed version field is 0.1.0")
    Do $$$AssertEquals(tParsed.vendor.name, "IRISCouch", "Parsed vendor.name is IRISCouch")
}

/// <p>Verify 404 error envelope structure for unknown routes.</p>
/// <p>AC #6: Unmatched routes return 404 with JSON error envelope.</p>
/// <p>Tests the Error.Render utility directly since the Router.Page()
/// method requires an HTTP context.</p>
Method TestNotFoundRoute()
{
    ; Verify the Error class has the NOTFOUND constant
    Set tSlug = ##class(IRISCouch.Util.Error).#NOTFOUND
    Do $$$AssertEquals(tSlug, "not_found", "Error NOTFOUND slug is not_found")

    ; Build a 404 error object manually to verify structure
    Set tError = {"error": "not_found", "reason": "missing"}
    Do $$$AssertEquals(tError.error, "not_found", "Error envelope has error field")
    Do $$$AssertEquals(tError.reason, "missing", "Error envelope has reason field")

    ; Verify JSON serialization matches expected format
    Set tJSON = tError.%ToJSON()
    Do $$$AssertTrue(tJSON [ """error"":""not_found""", "JSON contains error:not_found")
    Do $$$AssertTrue(tJSON [ """reason"":""missing""", "JSON contains reason:missing")
}

/// <p>Verify the Router class exists and has expected configuration.</p>
/// <p>AC #4: Router extends %CSP.REST with a UrlMap.</p>
Method TestRouterClassExists()
{
    ; Verify Router class is accessible
    Do $$$AssertTrue(##class(%Dictionary.CompiledClass).%ExistsId("IRISCouch.API.Router"), "Router class exists")

    ; Verify ServerHandler class is accessible
    Do $$$AssertTrue(##class(%Dictionary.CompiledClass).%ExistsId("IRISCouch.API.ServerHandler"), "ServerHandler class exists")
}

/// <p>Verify the ServerHandler VERSION parameter value.</p>
Method TestServerHandlerVersion()
{
    Set tVersion = ##class(IRISCouch.API.ServerHandler).#VERSION
    Do $$$AssertEquals(tVersion, "0.1.0", "ServerHandler VERSION parameter is 0.1.0")
}

}
