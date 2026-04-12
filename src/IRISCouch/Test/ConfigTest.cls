/// <p>Unit tests for <class>IRISCouch.Config</class>.</p>
/// <p>Validates configuration retrieval, global overrides, and the
/// complete set of configuration parameters.</p>
Class IRISCouch.Test.ConfigTest Extends %UnitTest.TestCase
{

/// <p>Handle initvalue parameter from parent class.</p>
Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Quit $$$OK
}

/// <p>Clean up test data before each test.</p>
Method OnBeforeOneTest() As %Status
{
    Kill ^IRISCouch.Config
    Quit $$$OK
}

/// <p>Clean up test data after each test.</p>
Method OnAfterOneTest() As %Status
{
    Kill ^IRISCouch.Config
    Quit $$$OK
}

/// <p>Verify default parameter values are returned when no global override exists.</p>
/// <p>AC #3: Config.Get("JSRUNTIME") returns "None" as the default.</p>
/// <p>AC #5: When no global override exists, class parameter default is returned.</p>
Method TestGetDefault()
{
    Do $$$AssertEquals(##class(IRISCouch.Config).Get("JSRUNTIME"), "None", "JSRUNTIME default is None")
    Do $$$AssertEquals(##class(IRISCouch.Config).Get("JSRUNTIMESUBPROCESSPATH"), "", "JSRUNTIMESUBPROCESSPATH default is empty")
    Do $$$AssertEquals(##class(IRISCouch.Config).Get("JSRUNTIMETIMEOUT"), 5000, "JSRUNTIMETIMEOUT default is 5000")
    Do $$$AssertEquals(##class(IRISCouch.Config).Get("METRICSENABLED"), 1, "METRICSENABLED default is 1")
    Do $$$AssertEquals(##class(IRISCouch.Config).Get("REVSLIMITDEFAULT"), 1000, "REVSLIMITDEFAULT default is 1000")
    Do $$$AssertEquals(##class(IRISCouch.Config).Get("WEBAPPPATH"), "/iris-couch/", "WEBAPPPATH default is /iris-couch/")
}

/// <p>Verify global overrides take precedence over class parameter defaults.</p>
/// <p>AC #4: Global override takes precedence over class parameter default.</p>
Method TestGlobalOverride()
{
    ; Set global override
    Set ^IRISCouch.Config("JSRUNTIME") = "Subprocess"
    Do $$$AssertEquals(##class(IRISCouch.Config).Get("JSRUNTIME"), "Subprocess", "Global override returns Subprocess")

    ; Verify non-overridden keys still return defaults
    Do $$$AssertEquals(##class(IRISCouch.Config).Get("METRICSENABLED"), 1, "Non-overridden key returns default")

    ; Override another key
    Set ^IRISCouch.Config("WEBAPPPATH") = "/custom-path/"
    Do $$$AssertEquals(##class(IRISCouch.Config).Get("WEBAPPPATH"), "/custom-path/", "WEBAPPPATH override works")
}

/// <p>Verify GetAll returns all config keys with current effective values.</p>
/// <p>AC #2: Config class is available with default parameter values.</p>
Method TestGetAllKeys()
{
    Set tAll = ##class(IRISCouch.Config).GetAll()

    Do $$$AssertTrue($IsObject(tAll), "GetAll returns an object")
    Do $$$AssertEquals(tAll.JSRUNTIME, "None", "GetAll includes JSRUNTIME")
    Do $$$AssertEquals(tAll.JSRUNTIMESUBPROCESSPATH, "", "GetAll includes JSRUNTIMESUBPROCESSPATH")
    Do $$$AssertEquals(tAll.JSRUNTIMETIMEOUT, 5000, "GetAll includes JSRUNTIMETIMEOUT")
    Do $$$AssertEquals(tAll.METRICSENABLED, 1, "GetAll includes METRICSENABLED")
    Do $$$AssertEquals(tAll.REVSLIMITDEFAULT, 1000, "GetAll includes REVSLIMITDEFAULT")
    Do $$$AssertEquals(tAll.WEBAPPPATH, "/iris-couch/", "GetAll includes WEBAPPPATH")

    ; Verify overrides are reflected in GetAll
    Set ^IRISCouch.Config("JSRUNTIME") = "Python"
    Set tAll2 = ##class(IRISCouch.Config).GetAll()
    Do $$$AssertEquals(tAll2.JSRUNTIME, "Python", "GetAll reflects global override")
}

/// <p>Verify Set writes to global and Get reads it back.</p>
Method TestSetAndGet()
{
    Set tSC = ##class(IRISCouch.Config).Set("JSRUNTIME", "Subprocess")
    Do $$$AssertStatusOK(tSC, "Set returns OK status")
    Do $$$AssertEquals(##class(IRISCouch.Config).Get("JSRUNTIME"), "Subprocess", "Get reads back value set by Set")

    ; Set a numeric value
    Set tSC = ##class(IRISCouch.Config).Set("JSRUNTIMETIMEOUT", 10000)
    Do $$$AssertStatusOK(tSC, "Set numeric value returns OK")
    Do $$$AssertEquals(##class(IRISCouch.Config).Get("JSRUNTIMETIMEOUT"), 10000, "Get reads back numeric value")
}

}
