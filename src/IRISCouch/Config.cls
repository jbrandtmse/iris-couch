/// <p>Configuration management for IRISCouch.</p>
/// <p>Provides centralized access to all configuration parameters.
/// Global overrides in <code>^IRISCouch.Config</code> take precedence
/// over class parameter defaults.</p>
/// <p>This is the ONLY class allowed to directly read <code>^IRISCouch.Config</code>.
/// All other classes must call <code>Config.Get()</code>.</p>
///
/// <h3>IRISCouch Global Inventory (Story 9.3)</h3>
/// <p>All IRISCouch state resides in <code>^IRISCouch.*</code> globals within the
/// namespace. No cross-namespace globals are used.</p>
/// <table>
/// <tr><th>Global</th><th>Storage Class</th><th>Purpose</th></tr>
/// <tr><td><code>^IRISCouch.Docs</code></td><td>Storage.Document</td><td>Document bodies (JSON)</td></tr>
/// <tr><td><code>^IRISCouch.Tree</code></td><td>Storage.RevTree</td><td>Revision trees (R/L/W/D nodes)</td></tr>
/// <tr><td><code>^IRISCouch.Changes</code></td><td>Storage.Changes</td><td>Changes feed entries</td></tr>
/// <tr><td><code>^IRISCouch.Seq</code></td><td>Storage.Changes</td><td>Sequence counters</td></tr>
/// <tr><td><code>^IRISCouch.DB</code></td><td>Storage.Database</td><td>Database metadata</td></tr>
/// <tr><td><code>^IRISCouch.Atts</code></td><td>Storage.Attachment</td><td>Attachment streams and metadata</td></tr>
/// <tr><td><code>^IRISCouch.Local</code></td><td>Storage.Local</td><td>Local documents / replication checkpoints</td></tr>
/// <tr><td><code>^IRISCouch.Config</code></td><td>Core.Config</td><td>Configuration overrides</td></tr>
/// <tr><td><code>^IRISCouch.Security</code></td><td>Auth.Security</td><td>Per-database security config</td></tr>
/// <tr><td><code>^IRISCouch.Metrics</code></td><td>Metrics.Collector</td><td>Prometheus metrics accumulators</td></tr>
/// <tr><td><code>^IRISCouch.Jobs</code></td><td>Replication.Manager</td><td>Background replication job state</td></tr>
/// </table>
///
/// <h3>IRIS Mirroring and HA Coverage</h3>
/// <p>All <code>^IRISCouch.*</code> globals are automatically:</p>
/// <ul>
/// <li><b>Journaled</b>: Every write is journaled for crash recovery via journal replay</li>
/// <li><b>Mirrored</b>: If IRIS mirroring is configured, globals replicate to mirror members</li>
/// <li><b>Backed up</b>: Standard IRIS database backup covers all globals in the database</li>
/// </ul>
/// <p>No additional configuration is needed for operational resilience.
/// IRISCouch inherits IRIS platform capabilities automatically.</p>
///
/// <h3>Backup Procedure</h3>
/// <p>Use standard IRIS database backup (online or freeze-based) to back up
/// the IRISCOUCH database. All <code>^IRISCouch.*</code> globals are included.
/// No special pre/post backup steps are required.</p>
///
/// <h3>Journal Replay Behavior</h3>
/// <p>All document writes use <code>TSTART</code>/<code>TCOMMIT</code> for atomicity.
/// On crash recovery, IRIS journal replay ensures either the entire write completed
/// or was rolled back entirely. Partial state is impossible for transactional writes.</p>
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

/// <p>Expected JWT issuer (<code>iss</code> claim). Empty string disables JWT auth.</p>
Parameter JWTISSUER = "";

/// <p>Shared secret for HMAC-based JWT validation (HS256). Empty string disables JWT auth.</p>
Parameter JWTSECRET = "";

/// <p>JWT claim name containing the user roles array.</p>
Parameter JWTROLESCLAIM = "roles";

/// <p>Shared secret for proxy authentication HMAC validation. Empty string disables proxy auth.</p>
Parameter PROXYAUTHSECRET = "";

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
    Set tResult.JWTISSUER = ..Get("JWTISSUER")
    Set tJwtSecret = ..Get("JWTSECRET")
    If tJwtSecret '= "" {
        Set tResult.JWTSECRET = "[REDACTED]"
    } Else {
        Set tResult.JWTSECRET = ""
    }
    Set tResult.JWTROLESCLAIM = ..Get("JWTROLESCLAIM")
    Set tProxySecret = ..Get("PROXYAUTHSECRET")
    If tProxySecret '= "" {
        Set tResult.PROXYAUTHSECRET = "[REDACTED]"
    } Else {
        Set tResult.PROXYAUTHSECRET = ""
    }
    Quit tResult
}

}
