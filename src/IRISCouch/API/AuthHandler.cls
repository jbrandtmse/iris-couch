/// <p>Session authentication endpoint handler for IRISCouch.</p>
/// <p>Implements the CouchDB-compatible <code>/_session</code> API for
/// cookie-based authentication: login (POST), session info (GET),
/// and logout (DELETE).</p>
Class IRISCouch.API.AuthHandler Extends %RegisteredObject
{

/// <p>Handle <code>POST /_session</code> — authenticate and create session cookie.</p>
/// <p>Reads JSON body with <code>name</code> and <code>password</code> fields,
/// validates credentials via <code>Security.Users.CheckPassword()</code> in
/// <code>%SYS</code> namespace (without switching process context), and on
/// success returns an HMAC-signed <code>AuthSession</code> cookie.</p>
/// @return %Status
ClassMethod HandleSessionPost() As %Status
{
    Set tSC = $$$OK
    Try {
        ; Read and parse request body
        Set tBody = ""
        If $IsObject(%request.Content) {
            Set tBody = %request.Content.Read()
        }
        If tBody = "" {
            Do ##class(IRISCouch.Util.Error).Render(400, "bad_request", "Request body is required.")
            Quit
        }
        Set tJSON = ##class(%DynamicObject).%FromJSON(tBody)
        Set tName = tJSON.name
        Set tPassword = tJSON.password
        If (tName = "") || (tPassword = "") {
            Do ##class(IRISCouch.Util.Error).Render(400, "bad_request", "Name and password are required.")
            Quit
        }
        ; Validate credentials against IRIS user directory (NFR-S1)
        ; Use Security.Users.CheckPassword instead of $System.Security.Login
        ; to avoid switching process security context (which breaks non-admin users)
        Set tOrigNS = $Namespace
        Set $Namespace = "%SYS"
        Set tUserExists = ##class(Security.Users).Exists(tName, .tUserObj)
        If tUserExists {
            Set tLoginOK = ##class(Security.Users).CheckPassword(.tUserObj, tPassword)
        } Else {
            Set tLoginOK = 0
        }
        Set $Namespace = tOrigNS
        If 'tLoginOK {
            Do ##class(IRISCouch.Util.Error).Render(401, "unauthorized", "Name or password is incorrect.")
            Quit
        }
        ; Create AuthSession cookie
        Set tCookieValue = ##class(IRISCouch.Auth.Session).CreateCookie(tName)
        Set tTimeout = ##class(IRISCouch.Config).Get("AUTHTIMEOUT")
        ; Set the cookie header
        Set tCookieHeader = "AuthSession=" _ tCookieValue _ "; Version=1; Max-Age=" _ tTimeout _ "; Path=/iris-couch; HttpOnly"
        Do %response.SetHeader("Set-Cookie", tCookieHeader)
        ; Get user roles for the response
        Set tRoles = ##class(IRISCouch.Auth.Basic).GetUserRoles(tName)
        ; Build success response
        Set tResponse = {}
        Do tResponse.%Set("ok", 1, "boolean")
        Set tResponse.name = tName
        Set tResponse.roles = tRoles
        Do ##class(IRISCouch.Util.Response).JSON(tResponse)
        Quit
    }
    Catch ex {
        ; Restore namespace on error
        If $Get(tOrigNS) '= "" Set $Namespace = tOrigNS
        Do ##class(IRISCouch.Util.Error).RenderInternal("server_error", "session: login error", ex)
        Quit
    }
    Quit $$$OK
}

/// <p>Handle <code>GET /_session</code> — return current session information.</p>
/// <p>If the request has a valid <code>AuthSession</code> cookie or Basic auth,
/// returns the authenticated user context. Otherwise returns an anonymous
/// context with <code>name: null</code>.</p>
/// @return %Status
ClassMethod HandleSessionGet() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tUsername = $Get(%IRISCouchUser, "")
        Set tRoles = $Get(%IRISCouchRoles, "")
        Set tAuthMethod = $Get(%IRISCouchAuthMethod, "")
        Set tResponse = {}
        Do tResponse.%Set("ok", 1, "boolean")
        Set tUserCtx = {}
        Set tInfo = {}
        If tUsername '= "" {
            ; Authenticated user
            Set tUserCtx.name = tUsername
            If '$IsObject(tRoles) {
                Set tRoles = []
            }
            Set tUserCtx.roles = tRoles
            Set tInfo.authenticated = tAuthMethod
        } Else {
            ; Unauthenticated (anonymous)
            Do tUserCtx.%Set("name", "", "null")
            Set tUserCtx.roles = []
        }
        Set tResponse.userCtx = tUserCtx
        Set tResponse.info = tInfo
        Do ##class(IRISCouch.Util.Response).JSON(tResponse)
        Quit
    }
    Catch ex {
        Do ##class(IRISCouch.Util.Error).RenderInternal("server_error", "session: info error", ex)
        Quit
    }
    Quit $$$OK
}

/// <p>Handle <code>DELETE /_session</code> — log out and expire the session cookie.</p>
/// <p>Sets the <code>AuthSession</code> cookie with <code>Max-Age=0</code> to
/// instruct the client to discard it. Returns <code>{"ok":true}</code>.</p>
/// @return %Status
ClassMethod HandleSessionDelete() As %Status
{
    Set tSC = $$$OK
    Try {
        ; Set expired cookie to clear it
        Set tCookieHeader = "AuthSession=; Max-Age=0; Path=/iris-couch; HttpOnly"
        Do %response.SetHeader("Set-Cookie", tCookieHeader)
        ; Build response
        Set tResponse = {}
        Do tResponse.%Set("ok", 1, "boolean")
        Do ##class(IRISCouch.Util.Response).JSON(tResponse)
        Quit
    }
    Catch ex {
        Do ##class(IRISCouch.Util.Error).RenderInternal("server_error", "session: logout error", ex)
        Quit
    }
    Quit $$$OK
}

}
