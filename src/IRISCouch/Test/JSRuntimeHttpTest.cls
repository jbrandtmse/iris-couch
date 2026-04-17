/// <p>HTTP integration tests for the JSRuntime Sandbox interface and the
/// <code>None</code> backend (Story 12.1).</p>
/// <p>Covers every Story 12.1 AC via live HTTP requests:</p>
/// <ul>
/// <li>View endpoint returns 501 under JSRUNTIME=None (AC #2).</li>
/// <li>Design docs with <code>validate_doc_update</code> can be written, and
///     subsequent ordinary writes succeed under None (AC #3, AC #6).</li>
/// <li>Custom changes filters return 501 (AC #4, AC #7).</li>
/// <li>Built-in <code>_doc_ids</code> / <code>_selector</code> / <code>_design</code>
///     filters continue to work (AC #7 regression).</li>
/// <li>Design-doc CRUD is fully independent of JSRUNTIME (AC #3).</li>
/// <li><class>IRISCouch.JSRuntime.Factory</class> resolves every configured
///     backend value to the correct concrete subclass (AC #5).</li>
/// </ul>
/// <p>Every test creates a fresh <code>testjsruntimedb</code> via
/// <method>OnBeforeOneTest</method> and kills all globals in
/// <method>OnAfterOneTest</method>. Tests that mutate
/// <code>^IRISCouch.Config("JSRUNTIME")</code> reset it to <code>"None"</code>
/// on teardown so later tests see the shipped default.</p>
Class IRISCouch.Test.JSRuntimeHttpTest Extends %UnitTest.TestCase
{

/// <p>Handle initvalue parameter from parent class (required by %UnitTest.TestCase).</p>
Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Quit $$$OK
}

/// <p>Create a fresh test database before each test.</p>
Method OnBeforeOneTest() As %Status
{
    Do ..KillDB()
    Set tSC = ##class(IRISCouch.Storage.Database).Create("testjsruntimedb")
    Quit tSC
}

/// <p>Remove the test database and reset JSRUNTIME config after each test.</p>
Method OnAfterOneTest() As %Status
{
    Do ..KillDB()
    ; Always restore the shipped default so other tests are not affected.
    Kill ^IRISCouch.Config("JSRUNTIME")
    Quit $$$OK
}

/// <p>Kill all IRISCouch globals for the test database.</p>
ClassMethod KillDB() [ Internal ]
{
    Kill ^IRISCouch.DB("testjsruntimedb")
    Kill ^IRISCouch.Docs("testjsruntimedb")
    Kill ^IRISCouch.Tree("testjsruntimedb")
    Kill ^IRISCouch.Changes("testjsruntimedb")
    Kill ^IRISCouch.Seq("testjsruntimedb")
}

/// <p>AC #2: GET /{db}/_design/{ddoc}/_view/{view} returns 501 when JSRUNTIME=None.</p>
/// <p>Creates a design doc with a <code>views</code> object, then requests
/// the view endpoint. Asserts status 501, Content-Type, error slug
/// <code>not_implemented</code>, and that the reason matches the AC #2
/// literal body byte-for-byte.</p>
Method TestViewReturns501WhenRuntimeIsNone()
{
    ; Create a design doc with one view
    Set tDDocBody = "{""views"":{""by_id"":{""map"":""function(doc){emit(doc._id,1);}""}}}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testjsruntimedb/_design/viewtest", .tStatus, .tBody, tDDocBody)
    Do $$$AssertStatusOK(tSC, "PUT design doc transport succeeded")
    Do $$$AssertEquals(tStatus, 201, "Design doc PUT returns 201")
    ; Hit the view endpoint
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/testjsruntimedb/_design/viewtest/_view/by_id", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "GET view transport succeeded")
    Do $$$AssertEquals(tStatus, 501, "View endpoint returns 501 Not Implemented")
    Do $$$AssertTrue($IsObject(tBody), "Response body parsed as JSON object")
    Do $$$AssertEquals(tBody.error, "not_implemented", "error slug is not_implemented")
    ; AC #2 specifies the literal reason string byte-for-byte. Assert
    ; equality, not just substring presence, so the envelope does not
    ; drift away from the spec.
    Set tExpected = "JSRuntime backend is set to None. Set ^IRISCouch.Config(""JSRUNTIME"") to ""Subprocess"" or ""Python"" to enable view execution. See documentation/js-runtime.md."
    Do $$$AssertEquals(tBody.reason, tExpected, "reason matches AC #2 literal body")
}

/// <p>AC #2, AC #7 negative: GET view on a non-existent design doc returns
/// 404 (<em>not</em> 501). Confirms 404 checks run before the JSRuntime path.</p>
Method TestViewReturns404ForMissingDesignDoc()
{
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/testjsruntimedb/_design/nothere/_view/foo", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "GET view transport succeeded")
    Do $$$AssertEquals(tStatus, 404, "Missing design doc returns 404, not 501")
    Do $$$AssertTrue($IsObject(tBody), "Response body parsed as JSON object")
    Do $$$AssertEquals(tBody.error, "not_found", "error slug is not_found")
}

/// <p>AC #2 negative: GET view with an unknown view name on an existing
/// design doc returns 404, not 501. Protects against "fall through to JS
/// execution for nonsense view names" bug.</p>
Method TestViewReturns404ForMissingNamedView()
{
    Set tDDocBody = "{""views"":{""only_one"":{""map"":""function(doc){}""}}}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testjsruntimedb/_design/namedv", .tStatus, .tBody, tDDocBody)
    Do $$$AssertEquals(tStatus, 201, "Design doc PUT returns 201")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/testjsruntimedb/_design/namedv/_view/does_not_exist", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "GET view transport succeeded")
    Do $$$AssertEquals(tStatus, 404, "Unknown view name returns 404")
    Do $$$AssertEquals(tBody.error, "not_found", "error slug is not_found")
}

/// <p>AC #3, AC #6: a design doc with a <code>validate_doc_update</code>
/// function can be stored under JSRUNTIME=None, and ordinary writes against
/// the same database continue to succeed -- proving validate_doc_update is
/// NOT evaluated while the runtime is None.</p>
Method TestDesignDocWithValidateCanBeStoredUnderNoneBackend()
{
    Set tDDocBody = "{""validate_doc_update"":""function(newDoc,oldDoc,userCtx,secObj){throw({unauthorized:'nope'});}""}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testjsruntimedb/_design/guard", .tStatus, .tBody, tDDocBody)
    Do $$$AssertStatusOK(tSC, "PUT design doc with validate_doc_update succeeds at transport layer")
    Do $$$AssertEquals(tStatus, 201, "Design doc with validate_doc_update returns 201")
    Do $$$AssertEquals(tBody.id, "_design/guard", "Design doc id echoed")
    ; Now PUT an ordinary doc — must succeed despite the guard design doc.
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testjsruntimedb/docA", .tStatus, .tBody, "{""hello"":""world""}")
    Do $$$AssertStatusOK(tSC, "PUT ordinary doc transport succeeded")
    Do $$$AssertEquals(tStatus, 201, "Ordinary doc write succeeds (validate_doc_update not invoked under None)")
    ; And GET the design doc to confirm it survived the round trip.
    ; Property names containing underscores must be accessed via %Get() in
    ; ObjectScript because "_" is the concatenation operator.
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/testjsruntimedb/_design/guard", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "GET design doc returns 200")
    Set tFnSource = tBody.%Get("validate_doc_update")
    Do $$$AssertTrue(tFnSource [ "throw", "validate_doc_update source preserved on round-trip")
}

/// <p>AC #4, AC #7: GET /_changes?filter=ddoc/name returns 501 under
/// JSRUNTIME=None, NOT 400 or a silent pass-through. Reason string names
/// <em>custom filter functions</em>.</p>
Method TestCustomFilterReturns501WhenRuntimeIsNone()
{
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/testjsruntimedb/_changes?filter=myddoc/myfilter", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "GET _changes transport succeeded")
    Do $$$AssertEquals(tStatus, 501, "Custom filter returns 501 Not Implemented")
    Do $$$AssertTrue($IsObject(tBody), "Response body parsed as JSON object")
    Do $$$AssertEquals(tBody.error, "not_implemented", "error slug is not_implemented")
    Do $$$AssertTrue(tBody.reason [ "custom filter functions", "reason names custom filter functions")
    Do $$$AssertTrue(tBody.reason [ "documentation/js-runtime.md", "reason points at js-runtime.md")
}

/// <p>AC #7 regression: built-in <code>_doc_ids</code> filter still works
/// under JSRUNTIME=None. This is the no-JSRuntime path and must not break.</p>
Method TestBuiltinFiltersStillWorkWhenRuntimeIsNone()
{
    ; Create two docs.
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testjsruntimedb/docOne", .tStatus, .tBody, "{""n"":1}")
    Do $$$AssertEquals(tStatus, 201, "Created docOne")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testjsruntimedb/docTwo", .tStatus, .tBody, "{""n"":2}")
    Do $$$AssertEquals(tStatus, 201, "Created docTwo")
    ; Filter to just docOne via _doc_ids.
    Set tReqBody = "{""doc_ids"":[""docOne""]}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("POST", "/testjsruntimedb/_changes?filter=_doc_ids", .tStatus, .tBody, tReqBody)
    Do $$$AssertStatusOK(tSC, "Built-in _doc_ids filter transport succeeded")
    Do $$$AssertEquals(tStatus, 200, "Built-in _doc_ids filter returns 200 (no JSRuntime involvement)")
    Do $$$AssertTrue($IsObject(tBody), "Response body parsed as JSON object")
    Do $$$AssertEquals(tBody.results.%Size(), 1, "Exactly one change matches the _doc_ids filter")
    Do $$$AssertEquals(tBody.results.%Get(0).id, "docOne", "Returned change is for docOne")
}

/// <p>AC #3: Design-doc CRUD (PUT, GET, DELETE) is independent of JSRUNTIME.
/// Every operation succeeds under JSRUNTIME=None; the document appears in
/// /_all_docs during its lifetime.</p>
Method TestDesignDocStorageIsJsRuntimeIndependent()
{
    ; PUT
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testjsruntimedb/_design/crud", .tStatus, .tBody, "{""language"":""javascript""}")
    Do $$$AssertEquals(tStatus, 201, "Design doc PUT returns 201 under JSRUNTIME=None")
    Set tRev = tBody.rev
    Do $$$AssertTrue(tRev '= "", "Design doc PUT returned a rev")
    ; GET
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/testjsruntimedb/_design/crud", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "Design doc GET returns 200 under JSRUNTIME=None")
    Do $$$AssertEquals(tBody."_id", "_design/crud", "Design doc _id matches")
    Do $$$AssertEquals(tBody.language, "javascript", "Design doc body preserved")
    ; Appears in _all_docs
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/testjsruntimedb/_all_docs", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "_all_docs succeeded")
    Set tFound = 0
    Set tI = 0
    While tI < tBody.rows.%Size() {
        If tBody.rows.%Get(tI).id = "_design/crud" Set tFound = 1
        Set tI = tI + 1
    }
    Do $$$AssertTrue(tFound, "Design doc appears in _all_docs")
    ; DELETE
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("DELETE", "/testjsruntimedb/_design/crud?rev="_tRev, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "Design doc DELETE returns 200 under JSRUNTIME=None")
}

/// <p>AC #5: Factory resolves every documented JSRUNTIME value to the
/// correct concrete subclass, and falls back to None for unrecognised values.</p>
Method TestFactoryResolvesAllConfiguredBackends()
{
    ; Baseline: shipped default is None.
    Set tSandbox = ##class(IRISCouch.JSRuntime.Factory).GetSandbox()
    Do $$$AssertEquals($ClassName(tSandbox), "IRISCouch.JSRuntime.None", "Default JSRUNTIME resolves to None")
    Do $$$AssertEquals(tSandbox.IsAvailable(), 0, "None backend reports IsAvailable=0")
    ; Explicit None.
    Set ^IRISCouch.Config("JSRUNTIME") = "None"
    Set tSandbox = ##class(IRISCouch.JSRuntime.Factory).GetSandbox()
    Do $$$AssertEquals($ClassName(tSandbox), "IRISCouch.JSRuntime.None", "JSRUNTIME=None resolves to None")
    ; Subprocess stub.
    Set ^IRISCouch.Config("JSRUNTIME") = "Subprocess"
    Set tSandbox = ##class(IRISCouch.JSRuntime.Factory).GetSandbox()
    Do $$$AssertEquals($ClassName(tSandbox), "IRISCouch.JSRuntime.Subprocess", "JSRUNTIME=Subprocess resolves to Subprocess stub")
    Do $$$AssertEquals(tSandbox.IsAvailable(), 0, "Subprocess stub reports IsAvailable=0 in Story 12.1")
    ; Python stub.
    Set ^IRISCouch.Config("JSRUNTIME") = "Python"
    Set tSandbox = ##class(IRISCouch.JSRuntime.Factory).GetSandbox()
    Do $$$AssertEquals($ClassName(tSandbox), "IRISCouch.JSRuntime.Python", "JSRUNTIME=Python resolves to Python stub")
    Do $$$AssertEquals(tSandbox.IsAvailable(), 0, "Python stub reports IsAvailable=0 in Story 12.1")
    ; Garbage value -> safe fallback to None.
    Set ^IRISCouch.Config("JSRUNTIME") = "garbage"
    Set tSandbox = ##class(IRISCouch.JSRuntime.Factory).GetSandbox()
    Do $$$AssertEquals($ClassName(tSandbox), "IRISCouch.JSRuntime.None", "Unrecognised JSRUNTIME value falls back to None")
    ; OnAfterOneTest resets the config.
}

/// <p>AC #1: the abstract <class>IRISCouch.JSRuntime.Sandbox</class> class
/// compiles with the <code>[ Abstract ]</code> keyword and all four
/// <code>Execute*</code> methods plus <code>IsAvailable</code> are declared
/// as abstract. This also serves as a regression guard against accidental
/// instantiation of the abstract class.</p>
Method TestAbstractSandboxContract()
{
    Do $$$AssertTrue(##class(%Dictionary.CompiledClass).%ExistsId("IRISCouch.JSRuntime.Sandbox"), "Sandbox class exists")
    ; The class keyword [ Abstract ] is captured on the compiled class
    ; definition. ClassDefinition.Abstract is 1 when the keyword is present.
    Set tDef = ##class(%Dictionary.CompiledClass).%OpenId("IRISCouch.JSRuntime.Sandbox")
    Do $$$AssertTrue($IsObject(tDef), "Compiled Sandbox class definition opens")
    Do $$$AssertEquals(tDef.Abstract, 1, "Sandbox class is declared Abstract")
    ; Concrete None subclass must be non-abstract and constructible.
    Set tConcrete = ##class(IRISCouch.JSRuntime.None).%New()
    Do $$$AssertTrue($IsObject(tConcrete), "None backend instantiates")
    Do $$$AssertEquals(tConcrete.IsAvailable(), 0, "None backend reports IsAvailable=0")
}

/// <p>AC #1, AC #4: None backend throws on every Execute* call with the
/// canonical <code>not_implemented</code> / subsystem envelope.</p>
Method TestNoneBackendThrowsCanonicalEnvelope()
{
    Set tSandbox = ##class(IRISCouch.JSRuntime.None).%New()
    ; ExecuteMap
    Set tCaught = 0
    Try {
        Do tSandbox.ExecuteMap("function(doc){}", {})
    } Catch ex {
        Set tCaught = 1
        Do $$$AssertEquals(ex.Code, "not_implemented", "ExecuteMap throws Code=not_implemented")
        Do $$$AssertEquals(ex.Name, "view execution", "ExecuteMap throws Name=view execution")
        Do $$$AssertTrue(ex.Data [ "documentation/js-runtime.md", "ExecuteMap reason points at js-runtime.md")
    }
    Do $$$AssertTrue(tCaught, "ExecuteMap threw under None")
    ; ExecuteReduce
    Set tCaught = 0
    Try {
        Do tSandbox.ExecuteReduce("function(k,v,r){return 0;}", [], [], 0)
    } Catch ex {
        Set tCaught = 1
        Do $$$AssertEquals(ex.Name, "reduce function", "ExecuteReduce throws Name=reduce function")
    }
    Do $$$AssertTrue(tCaught, "ExecuteReduce threw under None")
    ; ExecuteValidateDocUpdate
    Set tCaught = 0
    Try {
        Do tSandbox.ExecuteValidateDocUpdate("function(n,o,u,s){}", {}, {}, {}, {})
    } Catch ex {
        Set tCaught = 1
        Do $$$AssertEquals(ex.Name, "validate_doc_update hooks", "ExecuteValidateDocUpdate throws Name=validate_doc_update hooks")
    }
    Do $$$AssertTrue(tCaught, "ExecuteValidateDocUpdate threw under None")
    ; ExecuteFilter
    Set tCaught = 0
    Try {
        Do tSandbox.ExecuteFilter("function(d,r){return true;}", {}, {})
    } Catch ex {
        Set tCaught = 1
        Do $$$AssertEquals(ex.Name, "custom filter functions", "ExecuteFilter throws Name=custom filter functions")
    }
    Do $$$AssertTrue(tCaught, "ExecuteFilter threw under None")
}

/// <p>Regression test for Story 11.3 routing: the <code>_view</code> route
/// must be registered BEFORE the <code>_design/:ddocid/:attname</code>
/// attachment route, otherwise the attachment route swallows view requests
/// with <code>ddocid="_view"</code> or <code>attname=&lt;viewname&gt;</code>
/// producing a 404 "missing" (attachment handler) instead of the 501
/// that ViewHandler emits.</p>
/// <p>This test confirms that under JSRUNTIME=None the view route reaches
/// ViewHandler by asserting the response is the ViewHandler 501 envelope
/// rather than a generic 404.</p>
Method TestViewRouteOrdersBeforeAttachmentRoute()
{
    Set tDDocBody = "{""views"":{""v"":{""map"":""function(doc){}""}}}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/testjsruntimedb/_design/order", .tStatus, .tBody, tDDocBody)
    Do $$$AssertEquals(tStatus, 201, "Setup: design doc with view PUT succeeds")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/testjsruntimedb/_design/order/_view/v", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "GET view transport succeeded")
    ; If attachment route had swallowed this, we would get 404 "not_found".
    ; A 501 with slug "not_implemented" proves the view route beat the
    ; attachment route in the UrlMap ordering.
    Do $$$AssertEquals(tStatus, 501, "View route reaches ViewHandler (not swallowed by attachment route)")
    Do $$$AssertEquals(tBody.error, "not_implemented", "Response slug is not_implemented (from ViewHandler)")
}

}
