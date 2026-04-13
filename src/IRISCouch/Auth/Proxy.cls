/// <p>Proxy authentication handler for IRISCouch.</p>
/// <p>Validates proxy auth headers from trusted reverse proxies per the
/// CouchDB proxy authentication protocol. Reads <code>X-Auth-CouchDB-UserName</code>,
/// <code>X-Auth-CouchDB-Roles</code>, and <code>X-Auth-CouchDB-Token</code> headers.
/// The token is an HMAC-SHA1 of the username using a shared secret.</p>
Class IRISCouch.Auth.Proxy Extends %RegisteredObject
{

/// <p>Authenticate a request using proxy auth headers.</p>
/// <p>Reads the <code>X-Auth-CouchDB-UserName</code>, <code>X-Auth-CouchDB-Roles</code>,
/// and <code>X-Auth-CouchDB-Token</code> headers from the current request.
/// Validates the token as <code>HMAC-SHA1(username, secret)</code> using
/// timing-safe comparison.</p>
/// @param pUsername Output: The authenticated username from the header
/// @param pRoles Output: A %DynamicArray of role name strings parsed from comma-separated header
/// @return 1 if proxy auth succeeded, 0 if failed or disabled
ClassMethod Authenticate(Output pUsername As %String, Output pRoles As %DynamicArray) As %Boolean
{
    Set tResult = 0
    Set pUsername = ""
    Set pRoles = []
    Try {
        ; Check if proxy auth is enabled
        If '..IsEnabled() Quit
        ; Read headers from %request
        Set tUsername = %request.GetCgiEnv("HTTP_X_AUTH_COUCHDB_USERNAME", "")
        If tUsername = "" Quit
        Set tRolesHeader = %request.GetCgiEnv("HTTP_X_AUTH_COUCHDB_ROLES", "")
        Set tTokenHeader = %request.GetCgiEnv("HTTP_X_AUTH_COUCHDB_TOKEN", "")
        ; Get the shared secret
        Set tSecret = ##class(IRISCouch.Config).Get("PROXYAUTHSECRET")
        If tSecret = "" Quit
        ; Compute expected HMAC-SHA1 token over the username (160 = SHA-1 bit size)
        Set tExpectedHMAC = $System.Encryption.HMACSHA(160, tUsername, tSecret)
        ; Convert expected HMAC to hex string for comparison
        Set tExpectedHex = ##class(IRISCouch.Auth.Session).BytesToHex(tExpectedHMAC)
        ; Token from header should be hex-encoded HMAC
        Set tProvidedHex = $ZConvert(tTokenHeader, "L")
        ; Timing-safe comparison
        If '##class(IRISCouch.Auth.Session).ConstantTimeEquals(tProvidedHex, tExpectedHex) Quit
        ; Authentication succeeded - set username
        Set pUsername = tUsername
        ; Parse comma-separated roles into %DynamicArray
        Set tRolesArray = []
        If tRolesHeader '= "" {
            For i = 1:1:$Length(tRolesHeader, ",") {
                Set tRole = $ZStrip($Piece(tRolesHeader, ",", i), "<>W")
                If tRole '= "" Do tRolesArray.%Push(tRole)
            }
        }
        Set pRoles = tRolesArray
        Set tResult = 1
        Quit
    }
    Catch ex {
        Set tResult = 0
        Quit
    }
    Quit tResult
}

/// <p>Check whether proxy authentication is enabled.</p>
/// <p>Proxy auth requires <code>PROXYAUTHSECRET</code> to be configured
/// (non-empty) in <class>Config</class>.</p>
/// @return 1 if enabled, 0 if disabled
ClassMethod IsEnabled() As %Boolean
{
    Set tSecret = ##class(IRISCouch.Config).Get("PROXYAUTHSECRET")
    Quit (tSecret '= "")
}

}
