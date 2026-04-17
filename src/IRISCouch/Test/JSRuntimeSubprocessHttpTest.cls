/// <p>HTTP integration tests for the Subprocess JSRuntime backend (Story 12.2).</p>
/// <p>Exercises the full stack: design doc PUT → view query → map
/// execution → optional reduce → JSON response envelope. Each test
/// creates a fresh <code>testsubproc122</code> database, sets
/// <code>JSRUNTIME=Subprocess</code> and <code>JSRUNTIMESUBPROCESSPATH</code>
/// to the Windows Node path, and cleans up in <method>OnAfterOneTest</method>.</p>
/// <p>Tests that require a launchable JS interpreter will skip themselves
/// gracefully if <method>Subprocess.IsAvailable</method> returns 0 — this
/// allows CI without Node to still run the suite without false failures.
/// The pure-ObjectScript BuiltinReduce tests remain in
/// <class>IRISCouch.Test.BuiltinReduceTest</class> and never skip.</p>
Class IRISCouch.Test.JSRuntimeSubprocessHttpTest Extends %UnitTest.TestCase
{

Parameter TESTDB = "testsubproc122";

Parameter NODEPATH = "C:\Program Files\nodejs\node.exe";

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Quit $$$OK
}

/// Create a fresh DB and activate the Subprocess backend before each test.
Method OnBeforeOneTest() As %Status
{
    Do ..KillDB()
    Set tSC = ##class(IRISCouch.Storage.Database).Create(..#TESTDB)
    If $$$ISERR(tSC) Quit tSC
    Set ^IRISCouch.Config("JSRUNTIME") = "Subprocess"
    Set ^IRISCouch.Config("JSRUNTIMESUBPROCESSPATH") = ..#NODEPATH
    Quit $$$OK
}

/// Remove the DB and reset JSRUNTIME config after each test.
Method OnAfterOneTest() As %Status
{
    Do ..KillDB()
    Kill ^IRISCouch.Config("JSRUNTIME")
    Kill ^IRISCouch.Config("JSRUNTIMESUBPROCESSPATH")
    Kill ^IRISCouch.Config("JSRUNTIMESUBPROCESSENTRY")
    Quit $$$OK
}

ClassMethod KillDB() [ Internal ]
{
    Kill ^IRISCouch.DB(..#TESTDB)
    Kill ^IRISCouch.Docs(..#TESTDB)
    Kill ^IRISCouch.Tree(..#TESTDB)
    Kill ^IRISCouch.Changes(..#TESTDB)
    Kill ^IRISCouch.Seq(..#TESTDB)
}

/// <p>Return 1 if the Subprocess backend can launch on this CI runner.</p>
/// Tests that need a JS interpreter guard on this helper.
ClassMethod CanLaunchSubprocess() As %Boolean [ Internal ]
{
    Set tSandbox = ##class(IRISCouch.JSRuntime.Subprocess).%New()
    Quit tSandbox.IsAvailable()
}

/// AC #1: simple map view over three documents returns three rows sorted by key.
Method TestSubprocessMapSimpleView()
{
    If '..CanLaunchSubprocess() {
        Do $$$AssertTrue(1, "SKIP: no launchable Node interpreter on this runner")
        Quit
    }
    ; PUT docs
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/" _ ..#TESTDB _ "/doc1", .tStatus, .tBody, "{""name"":""alice"",""age"":30}")
    Do $$$AssertEquals(tStatus, 201, "PUT doc1")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/" _ ..#TESTDB _ "/doc2", .tStatus, .tBody, "{""name"":""bob"",""age"":25}")
    Do $$$AssertEquals(tStatus, 201, "PUT doc2")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/" _ ..#TESTDB _ "/doc3", .tStatus, .tBody, "{""name"":""carol"",""age"":35}")
    Do $$$AssertEquals(tStatus, 201, "PUT doc3")
    ; PUT design doc
    Set tDDoc = "{""views"":{""by_name"":{""map"":""function(doc){emit(doc.name,doc.age);}""}}}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/" _ ..#TESTDB _ "/_design/v", .tStatus, .tBody, tDDoc)
    Do $$$AssertEquals(tStatus, 201, "PUT design doc")
    ; GET view
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/" _ ..#TESTDB _ "/_design/v/_view/by_name", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "view GET transport")
    Do $$$AssertEquals(tStatus, 200, "view returns 200 under Subprocess backend")
    Do $$$AssertTrue($IsObject(tBody), "body is JSON object")
    Do $$$AssertEquals(tBody."total_rows", 3, "total_rows = 3")
    Do $$$AssertEquals(tBody.offset, 0, "offset = 0")
    Set tRows = tBody.rows
    Do $$$AssertEquals(tRows.%Size(), 3, "3 rows")
    Do $$$AssertEquals(tRows.%Get(0).key, "alice", "row[0].key = alice")
    Do $$$AssertEquals(tRows.%Get(0).value, 30, "row[0].value = 30")
    Do $$$AssertEquals(tRows.%Get(1).key, "bob", "row[1].key = bob")
    Do $$$AssertEquals(tRows.%Get(2).key, "carol", "row[2].key = carol")
}

/// AC #1: empty database — view returns zero rows.
Method TestSubprocessMapEmptyView()
{
    If '..CanLaunchSubprocess() {
        Do $$$AssertTrue(1, "SKIP: no Node interpreter")
        Quit
    }
    Set tDDoc = "{""views"":{""by_id"":{""map"":""function(doc){emit(doc._id,1);}""}}}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/" _ ..#TESTDB _ "/_design/empty", .tStatus, .tBody, tDDoc)
    Do $$$AssertEquals(tStatus, 201, "PUT ddoc")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/" _ ..#TESTDB _ "/_design/empty/_view/by_id", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "view returns 200 on empty DB")
    Do $$$AssertEquals(tBody."total_rows", 0, "total_rows = 0")
    Do $$$AssertEquals(tBody.rows.%Size(), 0, "rows is empty")
}

/// AC #2, AC #3: map + builtin _sum reduce.
Method TestSubprocessMapWithBuiltinSum()
{
    If '..CanLaunchSubprocess() {
        Do $$$AssertTrue(1, "SKIP: no Node interpreter")
        Quit
    }
    ; PUT three docs
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/" _ ..#TESTDB _ "/d1", .tStatus, .tBody, "{""type"":""x"",""value"":5}")
    Do $$$AssertEquals(tStatus, 201, "PUT d1")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/" _ ..#TESTDB _ "/d2", .tStatus, .tBody, "{""type"":""x"",""value"":10}")
    Do $$$AssertEquals(tStatus, 201, "PUT d2")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/" _ ..#TESTDB _ "/d3", .tStatus, .tBody, "{""type"":""x"",""value"":15}")
    Do $$$AssertEquals(tStatus, 201, "PUT d3")
    Set tDDoc = "{""views"":{""sum_v"":{""map"":""function(doc){emit(doc.type,doc.value);}"",""reduce"":""_sum""}}}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/" _ ..#TESTDB _ "/_design/sd", .tStatus, .tBody, tDDoc)
    Do $$$AssertEquals(tStatus, 201, "PUT ddoc with reduce")
    ; Query with default reduce=true
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/" _ ..#TESTDB _ "/_design/sd/_view/sum_v", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "reduce view returns 200")
    Do $$$AssertEquals(tBody.rows.%Size(), 1, "one reduced row")
    Do $$$AssertEquals(tBody.rows.%Get(0).value, 30, "_sum = 5+10+15 = 30")
}

/// AC #3: builtin _stats returns correct envelope shape.
Method TestSubprocessBuiltinStats()
{
    If '..CanLaunchSubprocess() {
        Do $$$AssertTrue(1, "SKIP: no Node interpreter")
        Quit
    }
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/" _ ..#TESTDB _ "/a", .tStatus, .tBody, "{""v"":1}")
    Do $$$AssertEquals(tStatus, 201, "PUT a")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/" _ ..#TESTDB _ "/b", .tStatus, .tBody, "{""v"":2}")
    Do $$$AssertEquals(tStatus, 201, "PUT b")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/" _ ..#TESTDB _ "/c", .tStatus, .tBody, "{""v"":3}")
    Do $$$AssertEquals(tStatus, 201, "PUT c")
    Set tDDoc = "{""views"":{""stats"":{""map"":""function(doc){emit(null,doc.v);}"",""reduce"":""_stats""}}}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/" _ ..#TESTDB _ "/_design/st", .tStatus, .tBody, tDDoc)
    Do $$$AssertEquals(tStatus, 201, "PUT ddoc")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/" _ ..#TESTDB _ "/_design/st/_view/stats", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "stats view returns 200")
    Do $$$AssertEquals(tBody.rows.%Size(), 1, "one reduced row")
    Set tVal = tBody.rows.%Get(0).value
    Do $$$AssertEquals(tVal.sum, 6, "sum = 6")
    Do $$$AssertEquals(tVal.count, 3, "count = 3")
    Do $$$AssertEquals(tVal.min, 1, "min = 1")
    Do $$$AssertEquals(tVal.max, 3, "max = 3")
    Do $$$AssertEquals(tVal.sumsqr, 14, "sumsqr = 1+4+9 = 14")
}

/// AC #2: user-JS reduce is executed via subprocess.
Method TestSubprocessMapWithCustomReduce()
{
    If '..CanLaunchSubprocess() {
        Do $$$AssertTrue(1, "SKIP: no Node interpreter")
        Quit
    }
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/" _ ..#TESTDB _ "/a", .tStatus, .tBody, "{""v"":1}")
    Do $$$AssertEquals(tStatus, 201, "PUT a")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/" _ ..#TESTDB _ "/b", .tStatus, .tBody, "{""v"":2}")
    Do $$$AssertEquals(tStatus, 201, "PUT b")
    Set tDDoc = "{""views"":{""c"":{""map"":""function(doc){emit(doc._id,doc.v);}"",""reduce"":""function(keys,values,rereduce){return values.length;}""}}}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/" _ ..#TESTDB _ "/_design/cr", .tStatus, .tBody, tDDoc)
    Do $$$AssertEquals(tStatus, 201, "PUT ddoc")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/" _ ..#TESTDB _ "/_design/cr/_view/c", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "custom reduce view 200")
    Do $$$AssertEquals(tBody.rows.%Get(0).value, 2, "values.length = 2 (user JS)")
}

/// AC #8: map function throws on doc #2 of 3 — assert result has 2 rows.
Method TestSubprocessMapErrorSkipsDoc()
{
    If '..CanLaunchSubprocess() {
        Do $$$AssertTrue(1, "SKIP: no Node interpreter")
        Quit
    }
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/" _ ..#TESTDB _ "/a", .tStatus, .tBody, "{""v"":1}")
    Do $$$AssertEquals(tStatus, 201, "PUT a")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/" _ ..#TESTDB _ "/b", .tStatus, .tBody, "{""v"":2}")
    Do $$$AssertEquals(tStatus, 201, "PUT b")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/" _ ..#TESTDB _ "/c", .tStatus, .tBody, "{""v"":3}")
    Do $$$AssertEquals(tStatus, 201, "PUT c")
    ; Map throws on doc with v=2
    Set tDDoc = "{""views"":{""throwy"":{""map"":""function(doc){if(doc.v===2)throw 'boom'; emit(doc._id,doc.v);}""}}}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/" _ ..#TESTDB _ "/_design/t", .tStatus, .tBody, tDDoc)
    Do $$$AssertEquals(tStatus, 201, "PUT ddoc")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/" _ ..#TESTDB _ "/_design/t/_view/throwy", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "throwy view returns 200 (errors swallowed)")
    ; Expect exactly 2 rows (doc with v=2 skipped)
    Do $$$AssertEquals(tBody."total_rows", 2, "total_rows = 2 (doc 'b' skipped)")
    Do $$$AssertEquals(tBody.rows.%Size(), 2, "2 rows returned")
}

/// AC #5, AC #7: with subprocess path set to /nonexistent the handler
/// falls back to 501 rather than crashing. The IsAvailable() check is
/// what saves us.
Method TestSubprocessFallsBackTo501WhenPathMissing()
{
    Set ^IRISCouch.Config("JSRUNTIMESUBPROCESSPATH") = "C:\this\path\does\not\exist\node.exe"
    Set tDDoc = "{""views"":{""v"":{""map"":""function(doc){}""}}}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/" _ ..#TESTDB _ "/_design/x", .tStatus, .tBody, tDDoc)
    Do $$$AssertEquals(tStatus, 201, "PUT ddoc succeeds (ddoc writes never use JSRuntime)")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/" _ ..#TESTDB _ "/_design/x/_view/v", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 501, "view returns 501 when subprocess unavailable")
    Do $$$AssertEquals(tBody.error, "not_implemented", "slug = not_implemented")
    Do $$$AssertTrue(tBody.reason [ "view execution", "reason names view execution subsystem")
}

/// AC #7 regression: with JSRUNTIME=Subprocess and a valid path, the
/// existing None-backend behaviour for missing design-docs is preserved
/// (404 not 501, 404 not 500).
Method TestSubprocessKeeps404ForMissingDesignDoc()
{
    If '..CanLaunchSubprocess() {
        Do $$$AssertTrue(1, "SKIP: no Node interpreter")
        Quit
    }
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/" _ ..#TESTDB _ "/_design/doesnotexist/_view/anything", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 404, "missing ddoc still 404 under Subprocess")
    Do $$$AssertEquals(tBody.error, "not_found", "404 slug preserved")
}

/// AC #6 (isolation): two sequential queries must not leak state.
/// Process-per-query means the second query starts a fresh sandbox.
Method TestSubprocessMultipleQueriesDoNotShareState()
{
    If '..CanLaunchSubprocess() {
        Do $$$AssertTrue(1, "SKIP: no Node interpreter")
        Quit
    }
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/" _ ..#TESTDB _ "/a", .tStatus, .tBody, "{""color"":""red""}")
    Do $$$AssertEquals(tStatus, 201, "PUT a")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/" _ ..#TESTDB _ "/b", .tStatus, .tBody, "{""color"":""blue""}")
    Do $$$AssertEquals(tStatus, 201, "PUT b")
    ; Two different views in two different design docs.
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/" _ ..#TESTDB _ "/_design/x", .tStatus, .tBody, "{""views"":{""v"":{""map"":""function(doc){emit('x',doc.color);}""}}}")
    Do $$$AssertEquals(tStatus, 201, "PUT design x")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/" _ ..#TESTDB _ "/_design/y", .tStatus, .tBody, "{""views"":{""v"":{""map"":""function(doc){emit('y',doc.color);}""}}}")
    Do $$$AssertEquals(tStatus, 201, "PUT design y")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/" _ ..#TESTDB _ "/_design/x/_view/v", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "view x 200")
    Do $$$AssertEquals(tBody.rows.%Get(0).key, "x", "view x emits key 'x'")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/" _ ..#TESTDB _ "/_design/y/_view/v", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "view y 200")
    Do $$$AssertEquals(tBody.rows.%Get(0).key, "y", "view y emits key 'y' (no state leak from view x)")
}

/// <p>Regression (Story 12.2 code-review 2026-04-17): a map function that
/// calls <code>log()</code> emits <code>["log", message]</code> lines on
/// stdout before the map result; <method>ExecuteMap</method> must drain
/// those lines so the actual emission array is parsed correctly.</p>
Method TestSubprocessMapWithLogCall()
{
    If '..CanLaunchSubprocess() {
        Do $$$AssertTrue(1, "SKIP: no Node interpreter")
        Quit
    }
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/" _ ..#TESTDB _ "/a", .tStatus, .tBody, "{""n"":1}")
    Do $$$AssertEquals(tStatus, 201, "PUT a")
    Set tDDoc = "{""views"":{""logv"":{""map"":""function(doc){log('hello from map'); emit(doc._id, doc.n);}""}}}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/" _ ..#TESTDB _ "/_design/lv", .tStatus, .tBody, tDDoc)
    Do $$$AssertEquals(tStatus, 201, "PUT ddoc with log()")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/" _ ..#TESTDB _ "/_design/lv/_view/logv", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "view with log() returns 200")
    Do $$$AssertEquals(tBody."total_rows", 1, "one row emitted despite log() preamble")
    Do $$$AssertEquals(tBody.rows.%Get(0).value, 1, "emission value = 1 (log() drain succeeded)")
}

/// <p>Regression (Story 12.2 code-review 2026-04-17): <code>?reduce=true</code>
/// on a view that has no reduce function returns <b>400</b>
/// <code>query_parse_error</code>, not a silent map-only response. Mirrors
/// CouchDB's behaviour for the same input.</p>
Method TestSubprocessReduceTrueOnMapOnlyReturns400()
{
    If '..CanLaunchSubprocess() {
        Do $$$AssertTrue(1, "SKIP: no Node interpreter")
        Quit
    }
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/" _ ..#TESTDB _ "/a", .tStatus, .tBody, "{""v"":1}")
    Do $$$AssertEquals(tStatus, 201, "PUT a")
    ; Map-only view (no reduce).
    Set tDDoc = "{""views"":{""maponly"":{""map"":""function(doc){emit(doc._id,doc.v);}""}}}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/" _ ..#TESTDB _ "/_design/mo", .tStatus, .tBody, tDDoc)
    Do $$$AssertEquals(tStatus, 201, "PUT ddoc")
    ; ?reduce=true on a map-only view -> 400 query_parse_error.
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/" _ ..#TESTDB _ "/_design/mo/_view/maponly?reduce=true", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 400, "reduce=true on map-only view returns 400")
    Do $$$AssertEquals(tBody.error, "query_parse_error", "slug is query_parse_error")
}

/// AC #7: HTTP response Content-Type is application/json for view responses.
Method TestSubprocessContentTypeIsJson()
{
    If '..CanLaunchSubprocess() {
        Do $$$AssertTrue(1, "SKIP: no Node interpreter")
        Quit
    }
    Set tDDoc = "{""views"":{""v"":{""map"":""function(doc){}""}}}"
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("PUT", "/" _ ..#TESTDB _ "/_design/ct", .tStatus, .tBody, tDDoc)
    Do $$$AssertEquals(tStatus, 201, "PUT ddoc")
    Set tSC = ##class(IRISCouch.Test.HttpIntegrationTest).MakeRequest("GET", "/" _ ..#TESTDB _ "/_design/ct/_view/v", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "view 200")
    ; MakeRequest parses JSON automatically, so a non-JSON response would
    ; have left tBody as a string. Confirming it's an object validates
    ; Content-Type was application/json.
    Do $$$AssertTrue($IsObject(tBody), "response body parsed as JSON object")
}

}
