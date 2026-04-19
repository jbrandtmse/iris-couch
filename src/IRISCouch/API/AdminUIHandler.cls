/// <p>Static file server for the IRISCouch Admin UI (Story 11.5).</p>
/// <p>Serves the Angular SPA from the built <code>ui/dist/browser/</code> directory.
/// Handles MIME type mapping, cache headers for hashed assets, SPA fallback
/// routing, path traversal protection, and <code>IRISCouch_Admin</code>
/// role-based access control.</p>
/// <p>This handler is dispatched from <class>IRISCouch.API.Router</class>
/// via the <code>OnPreDispatch</code> intercept for any URL beginning with
/// <code>/_utils/</code>.</p>
Class IRISCouch.API.AdminUIHandler Extends %RegisteredObject
{

/// <p>Name of the IRIS role required to access the Admin UI.</p>
Parameter ADMINROLE = "IRISCouch_Admin";

/// <p>Serve a static file or SPA fallback for the given relative path.</p>
/// <p>Workflow:</p>
/// <ol>
/// <li>Check <code>IRISCouch_Admin</code> role — return 403 if missing</li>
/// <li>Sanitize the path — reject traversal attempts (400)</li>
/// <li>If file exists on disk, stream it with correct MIME type and cache headers</li>
/// <li>If file does not exist, serve <code>index.html</code> (SPA fallback)</li>
/// </ol>
/// @param pPath Relative path under the dist directory (e.g., "main-abc123.js" or "db/mydb/doc/doc1")
/// @return %Status
ClassMethod HandleRequest(pPath As %String = "index.html") As %Status
{
    Set tSC = $$$OK
    Try {
        ; --- Access control: require authenticated user with IRISCouch_Admin role (Story 13.4 Task 3) ---
        ; The default IRIS CSP service ships %Service_CSP carrying %All for DEFAULT_USER,
        ; so an anonymous browser could previously reach HandleRequest and pass the old
        ; $Roles-only HasAdminRole check. We must now verify that an actual authenticated
        ; identity is present BEFORE inspecting the role, and emit 401 (not 403) when
        ; no identity is present so the browser prompts for credentials.
        If '..IsAuthenticated() {
            Do %response.SetHeader("WWW-Authenticate", "Basic realm=""IRISCouch Admin""")
            Do ##class(IRISCouch.Util.Error).Render(401, "unauthorized", "Authentication required")
            Quit
        }
        If '..HasAdminRole() {
            Do ##class(IRISCouch.Util.Error).Render(403, "forbidden", "Admin UI requires IRISCouch_Admin role")
            Quit
        }

        ; Default empty path to index.html
        If pPath = "" Set pPath = "index.html"

        ; --- Path sanitization ---
        ; URL-decode the path
        Set tPath = $ZConvert(pPath, "I", "URL")

        ; Reject null bytes
        If tPath [ $Char(0) {
            Do ##class(IRISCouch.Util.Error).Render(400, "bad_request", "Invalid path")
            Quit
        }

        ; Reject path traversal
        If tPath [ ".." {
            Do ##class(IRISCouch.Util.Error).Render(400, "bad_request", "Invalid path")
            Quit
        }

        ; --- Resolve absolute file path ---
        Set tDistDir = ..GetDistDir()
        If tDistDir = "" {
            Do ##class(IRISCouch.Util.Error).Render(500, "server_error", "Admin UI dist directory not configured")
            Quit
        }

        ; Build absolute path and normalize
        Set tAbsPath = ##class(%File).NormalizeFilename(tPath, tDistDir)

        ; Security: verify resolved path is a child of the dist directory
        Set tNormDist = ##class(%File).NormalizeFilename(tDistDir)
        If $Extract(tAbsPath, 1, $Length(tNormDist)) '= tNormDist {
            Do ##class(IRISCouch.Util.Error).Render(400, "bad_request", "Invalid path")
            Quit
        }

        ; --- Serve file or SPA fallback ---
        If ##class(%File).Exists(tAbsPath) {
            Set tSC = ..StreamFile(tAbsPath)
            If $$$ISERR(tSC) {
                Do ##class(IRISCouch.Util.Error).RenderInternal("server_error", "Admin UI file read error", "")
                Quit
            }
        } Else {
            ; SPA fallback: serve index.html for any unrecognized path
            Set tIndexPath = ##class(%File).NormalizeFilename("index.html", tDistDir)
            If ##class(%File).Exists(tIndexPath) {
                Set tSC = ..StreamFile(tIndexPath)
                If $$$ISERR(tSC) {
                    Do ##class(IRISCouch.Util.Error).RenderInternal("server_error", "Admin UI file read error", "")
                    Quit
                }
            } Else {
                Do ##class(IRISCouch.Util.Error).Render(404, "not_found", "Admin UI not found - run ng build first")
            }
        }
    }
    Catch ex {
        Do ##class(IRISCouch.Util.Error).RenderInternal("server_error", "Admin UI handler error", ex)
    }
    Quit $$$OK
}

/// <p>Check if there is an authenticated IRIS user for this request (Story 13.4 Task 3).</p>
/// <p>The IRIS default-CSP service (<code>%Service_CSP.DEFAULT_USER</code>)
/// is configured with <code>UnknownUser</code> / <code>%All</code> when the
/// CSP webapp accepts anonymous access, so a pure <code>$Roles</code> check
/// or even a <code>$Username</code>-not-empty check silently admits anonymous
/// browsers (<code>$Username = "UnknownUser"</code> ships with <code>%All</code>).</p>
/// <p>The Router's <method>OnPreDispatch</method> extracts the real Basic /
/// Bearer / cookie identity into the process-private <code>%IRISCouchUser</code>
/// variable. If that variable is empty, no authentication was presented; fall
/// back to <code>$Username</code> only if it is a genuine IRIS login
/// (not one of the well-known placeholders <code>UnknownUser</code> /
/// <code>_PUBLIC</code>).</p>
/// @return %Boolean 1 if a real authenticated user is in context, 0 otherwise
ClassMethod IsAuthenticated() As %Boolean
{
    ; Primary signal: the Router's auth middleware populated %IRISCouchUser
    Set tAppUser = $Get(%IRISCouchUser, "")
    If tAppUser '= "" Quit 1
    ; Fallback: accept a genuine IRIS login (not an anonymous placeholder)
    Set tOsUser = $Username
    If tOsUser = "" Quit 0
    If tOsUser = "UnknownUser" Quit 0
    If tOsUser = "_PUBLIC" Quit 0
    Quit 1
}

/// <p>Check if the current user has the <code>IRISCouch_Admin</code> role.</p>
/// <p>Story 13.4 Task 3: this method assumes the caller has already verified
/// <method>IsAuthenticated</method>. The identity precheck lives there, not
/// here, because callers need to distinguish 401 (no identity) from 403
/// (authenticated but wrong role) and emit different envelopes.</p>
/// <p>Role source of truth: the Router's auth middleware populates
/// <code>%IRISCouchRoles</code> with the roles of the authenticated user
/// (looked up from <code>Security.Users</code> via
/// <method>IRISCouch.Auth.Basic.GetUserRoles</method>). Fall back to
/// <code>$Roles</code> only when <code>%IRISCouchRoles</code> is empty — i.e.,
/// when a genuine OS-level IRIS login was used without Basic auth.</p>
/// @return %Boolean 1 if user has admin role, 0 otherwise
ClassMethod HasAdminRole() As %Boolean
{
    ; Primary: check the app-level roles array populated by Router.OnPreDispatch.
    Set tAppRoles = $Get(%IRISCouchRoles)
    If $IsObject(tAppRoles) {
        Set tN = tAppRoles.%Size()
        Set tI = 0
        While tI < tN {
            Set tR = tAppRoles.%Get(tI)
            If (tR = ..#ADMINROLE) || (tR = "%All") Quit
            Set tI = tI + 1
        }
        If tI < tN Quit 1
    }
    ; Fallback: check IRIS $Roles for a genuine OS-level login. Only trust this
    ; path when %IRISCouchUser is non-empty (meaning the middleware confirmed an
    ; identity); otherwise $Roles = "%All" from the CSP DEFAULT_USER and is NOT
    ; a grant we can rely on.
    If $Get(%IRISCouchUser, "") '= "" {
        If $Find("," _ $Roles _ ",", "," _ ..#ADMINROLE _ ",") > 0 Quit 1
        If $Find("," _ $Roles _ ",", ",%All,") > 0 Quit 1
    }
    Quit 0
}

/// <p>Resolve the dist directory path for the Angular build output.</p>
/// <p>Resolution order:</p>
/// <ol>
/// <li>Config global override: <code>^IRISCouch.Config("UIDISTDIR")</code></li>
/// <li>Source tree relative to the dev directory</li>
/// </ol>
/// @return %String Absolute path to the dist directory, or empty if not found
ClassMethod GetDistDir() As %String
{
    ; Priority 1: Config global override
    Set tOverride = $Get(^IRISCouch.Config("UIDISTDIR"), "")
    If tOverride '= "" {
        If ##class(%File).DirectoryExists(tOverride) {
            Quit tOverride
        }
    }

    ; Priority 2: Development source tree path
    ; IRIS dev directory is typically <InstallDir>/dev/<namespace>/
    ; But the source tree is at <repo>/ui/dist/browser/
    ; Try common locations based on the class file location
    Set tInstallDir = $System.Util.InstallDirectory()

    ; Try the dev path (typical for IRIS development with source sync)
    Set tDevPath = ##class(%File).NormalizeFilename("dev/iris-couch/ui/dist/browser/", tInstallDir)
    If ##class(%File).DirectoryExists(tDevPath) {
        Quit tDevPath
    }

    ; Try lowercase namespace variant
    Set tDevPath2 = ##class(%File).NormalizeFilename("dev/iriscouch/ui/dist/browser/", tInstallDir)
    If ##class(%File).DirectoryExists(tDevPath2) {
        Quit tDevPath2
    }

    Quit ""
}

/// <p>Stream a file to the HTTP response with correct MIME type and cache headers.</p>
/// <p>Uses <class>%Stream.FileBinary</class> with <method>LinkToFile</method>
/// to avoid loading the entire file into memory. Reads in 32KB chunks.</p>
/// @param pAbsPath Absolute filesystem path to the file
/// @return %Status
ClassMethod StreamFile(pAbsPath As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        ; Determine MIME type from extension
        Set tFilename = ##class(%File).GetFilename(pAbsPath)
        Set tContentType = ..GetMimeType(tFilename)
        Set %response.ContentType = tContentType

        ; Set cache headers
        Do ..SetCacheHeaders(tFilename)

        ; Set HTTP status
        Set %response.Status = 200

        ; Stream the file
        Set tStream = ##class(%Stream.FileBinary).%New()
        Set tSC = tStream.LinkToFile(pAbsPath)
        If $$$ISERR(tSC) Quit

        While 'tStream.AtEnd {
            Set tChunk = tStream.Read(32768, .tSC)
            If $$$ISERR(tSC) Quit
            Write tChunk
        }
    }
    Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Map a filename extension to its MIME Content-Type.</p>
/// @param pFilename The filename (e.g., "main-abc123.js")
/// @return %String The Content-Type value
ClassMethod GetMimeType(pFilename As %String) As %String
{
    Set tExt = $ZConvert($Piece(pFilename, ".", *), "L")
    If tExt = "html" Quit "text/html; charset=utf-8"
    If tExt = "js" Quit "application/javascript; charset=utf-8"
    If tExt = "mjs" Quit "application/javascript; charset=utf-8"
    If tExt = "css" Quit "text/css; charset=utf-8"
    If tExt = "json" Quit "application/json; charset=utf-8"
    If tExt = "woff2" Quit "font/woff2"
    If tExt = "woff" Quit "font/woff"
    If tExt = "ttf" Quit "font/ttf"
    If tExt = "svg" Quit "image/svg+xml"
    If tExt = "png" Quit "image/png"
    If tExt = "jpg" Quit "image/jpeg"
    If tExt = "jpeg" Quit "image/jpeg"
    If tExt = "ico" Quit "image/x-icon"
    If tExt = "map" Quit "application/json"
    Quit "application/octet-stream"
}

/// <p>Set Cache-Control headers based on whether the filename contains a content hash.</p>
/// <p>Hashed assets (e.g., <code>main-I7CDCDFR.js</code>) get immutable caching.
/// Non-hashed files (e.g., <code>index.html</code>) get no-cache.</p>
/// @param pFilename The filename to check for hash pattern
ClassMethod SetCacheHeaders(pFilename As %String)
{
    If ..IsHashedAsset(pFilename) {
        Do %response.SetHeader("Cache-Control", "public, max-age=31536000, immutable")
    } Else {
        Do %response.SetHeader("Cache-Control", "no-cache")
    }
    Quit
}

/// <p>Check if a filename contains a content hash pattern.</p>
/// <p>Matches filenames like <code>main-I7CDCDFR.js</code> or
/// <code>styles-KO5L73LS.css</code> where a dash is followed by
/// 8+ alphanumeric characters before the file extension.</p>
/// @param pFilename The filename to check
/// @return %Boolean 1 if hashed, 0 otherwise
ClassMethod IsHashedAsset(pFilename As %String) As %Boolean
{
    ; Pattern: basename-HASH.ext where HASH is 8+ alphanumeric chars
    ; Strip the extension
    Set tBase = $Piece(pFilename, ".", 1, *-1)
    ; Find the last dash
    Set tLastDash = $Length(tBase) - $Length($Reverse($Piece($Reverse(tBase), "-", 1)))
    If tLastDash < 1 Quit 0
    ; Extract the hash part (everything after the last dash)
    Set tHash = $Piece(tBase, "-", *)
    ; Must be at least 8 characters and all alphanumeric
    If $Length(tHash) < 8 Quit 0
    ; Verify all characters are alphanumeric (a-z, A-Z, 0-9)
    Set tAllAlphaNum = 1
    For i = 1:1:$Length(tHash) {
        Set tChar = $Extract(tHash, i)
        If '((tChar?1A) || (tChar?1N)) {
            Set tAllAlphaNum = 0
            Quit
        }
    }
    Quit tAllAlphaNum
}

}
