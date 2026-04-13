/// <p>Configuration management for IRISCouch.</p>
/// <p>Provides centralized access to all configuration parameters.
/// Global overrides in <code>^IRISCouch.Config</code> take precedence
/// over class parameter defaults.</p>
/// <p>This is the ONLY class allowed to directly read <code>^IRISCouch.Config</code>.
/// All other classes must call <code>Config.Get()</code>.</p>
Class IRISCouch.Config Extends %RegisteredObject
{

/// <p>JavaScript runtime backend. Valid values: "None", "Subprocess", "Python"</p>
Parameter JSRUNTIME = "None";

/// <p>Path to the JavaScript subprocess executable</p>
Parameter JSRUNTIMESUBPROCESSPATH = "";

/// <p>Timeout in milliseconds for JavaScript runtime execution</p>
Parameter JSRUNTIMETIMEOUT = 5000;

/// <p>Whether metrics collection is enabled (1=yes, 0=no)</p>
Parameter METRICSENABLED = 1;

/// <p>Default limit for revision history queries</p>
Parameter REVSLIMITDEFAULT = 1000;

/// <p>Web application mount path</p>
Parameter WEBAPPPATH = "/iris-couch/";

/// <p>Per-instance secret for HMAC cookie signing (NFR-S3).</p>
/// <p>If empty, auto-generated on first use by Auth.Session.GetSecret().</p>
Parameter AUTHSECRET = "";

/// <p>Session cookie timeout in seconds. CouchDB default is 600.</p>
Parameter AUTHTIMEOUT = 600;

/// <p>Retrieve a configuration value by key.</p>
/// <p>Checks <code>^IRISCouch.Config(pKey)</code> first for a global override.
/// If no override exists, returns the class parameter default.</p>
/// @param pKey The configuration key name (must match a class parameter name)
/// @return The effective configuration value
ClassMethod Get(pKey As %String) As %String
{
    Set tVal = ""
    If $Data(^IRISCouch.Config(pKey), tVal) {
        Quit tVal
    }
    Quit ..GetDefault(pKey)
}

/// <p>Read the class parameter default value for a given key.</p>
/// @param pKey The configuration key name
/// @return The default value from the class parameter
ClassMethod GetDefault(pKey As %String) As %String [ Private ]
{
    Quit $Parameter($ClassName(), pKey)
}

/// <p>Set a configuration override in the <code>^IRISCouch.Config</code> global.</p>
/// @param pKey The configuration key name
/// @param pValue The value to set
/// @return %Status indicating success or failure
ClassMethod Set(pKey As %String, pValue As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Set ^IRISCouch.Config(pKey) = pValue
    }
    Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Return all configuration keys with their current effective values.</p>
/// <p>Returns a <class>%DynamicObject</class> where each property is a config key
/// mapped to its effective value (global override or class parameter default).</p>
/// @return %DynamicObject with all configuration key-value pairs
ClassMethod GetAll() As %DynamicObject
{
    Set tResult = {}
    Set tResult.JSRUNTIME = ..Get("JSRUNTIME")
    Set tResult.JSRUNTIMESUBPROCESSPATH = ..Get("JSRUNTIMESUBPROCESSPATH")
    Set tResult.JSRUNTIMETIMEOUT = ..Get("JSRUNTIMETIMEOUT")
    Set tResult.METRICSENABLED = ..Get("METRICSENABLED")
    Set tResult.REVSLIMITDEFAULT = ..Get("REVSLIMITDEFAULT")
    Set tResult.WEBAPPPATH = ..Get("WEBAPPPATH")
    Set tAuthSecret = ..Get("AUTHSECRET")
    If tAuthSecret '= "" {
        Set tResult.AUTHSECRET = "[REDACTED]"
    } Else {
        Set tResult.AUTHSECRET = ""
    }
    Set tResult.AUTHTIMEOUT = ..Get("AUTHTIMEOUT")
    Quit tResult
}

}
