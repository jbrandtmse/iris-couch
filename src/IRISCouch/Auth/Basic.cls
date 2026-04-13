/// <p>HTTP Basic authentication handler for IRISCouch.</p>
/// <p>Parses the <code>Authorization: Basic</code> header, validates credentials
/// against the IRIS user directory (NFR-S1: no shadow credential store),
/// and retrieves user roles.</p>
Class IRISCouch.Auth.Basic Extends %RegisteredObject
{

/// <p>Authenticate a request using the HTTP Basic Authorization header.</p>
/// <p>Parses the Base64-encoded <code>username:password</code> from the header,
/// validates credentials via <code>$System.Security.Login()</code>, and retrieves
/// user roles on success.</p>
/// @param pAuthHeader The full Authorization header value (e.g., "Basic dXNlcjpwYXNz")
/// @param pUsername Output: The authenticated username if valid
/// @param pRoles Output: A %DynamicArray of role name strings
/// @return 1 if authentication succeeded, 0 if failed
ClassMethod Authenticate(pAuthHeader As %String, Output pUsername As %String, Output pRoles As %DynamicArray) As %Boolean
{
    Set tResult = 0
    Set pUsername = ""
    Set pRoles = []
    Try {
        ; Parse "Basic <base64>" header
        Set tScheme = $Piece(pAuthHeader, " ", 1)
        Set tEncoded = $Piece(pAuthHeader, " ", 2)
        If $ZConvert(tScheme, "U") '= "BASIC" Quit
        If tEncoded = "" Quit
        ; Decode Base64 credentials
        Set tDecoded = $System.Encryption.Base64Decode(tEncoded)
        If tDecoded = "" Quit
        ; Extract username:password
        Set tUser = $Piece(tDecoded, ":", 1)
        Set tPass = $Piece(tDecoded, ":", 2, *)
        If (tUser = "") || (tPass = "") Quit
        ; Validate against IRIS user directory (NFR-S1)
        Set tLoginOK = $System.Security.Login(tUser, tPass)
        If 'tLoginOK Quit
        ; Authentication succeeded
        Set pUsername = tUser
        Set pRoles = ..GetUserRoles(tUser)
        Set tResult = 1
        Quit
    }
    Catch ex {
        Set tResult = 0
        Quit
    }
    Quit tResult
}

/// <p>Retrieve the roles for a given IRIS user.</p>
/// <p>Switches to <code>%SYS</code> namespace to access <code>Security.Users</code>,
/// then restores the original namespace. Returns roles as a
/// <class>%DynamicArray</class> of role name strings.</p>
/// @param pUsername The IRIS username
/// @return %DynamicArray of role name strings
ClassMethod GetUserRoles(pUsername As %String) As %DynamicArray
{
    Set tRoles = []
    Try {
        ; Switch to %SYS to access Security.Users
        Set tOrigNS = $Namespace
        Set $Namespace = "%SYS"
        Set tSC = ##class(Security.Users).Get(pUsername, .tProps)
        Set $Namespace = tOrigNS
        If $$$ISERR(tSC) Quit
        ; Parse comma-separated roles list
        Set tRoleStr = tProps("Roles")
        If tRoleStr = "" Quit
        For i = 1:1:$Length(tRoleStr, ",") {
            Set tRole = $ZStrip($Piece(tRoleStr, ",", i), "<>W")
            If tRole '= "" {
                Do tRoles.%Push(tRole)
            }
        }
        Quit
    }
    Catch ex {
        ; Restore namespace on error
        If $Get(tOrigNS) '= "" Set $Namespace = tOrigNS
        Quit
    }
    Quit tRoles
}

}
