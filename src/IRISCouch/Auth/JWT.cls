/// <p>JWT Bearer token authentication handler for IRISCouch.</p>
/// <p>Validates HS256 JWT tokens from <code>Authorization: Bearer</code> headers.
/// Extracts username from <code>sub</code> claim and roles from a configurable
/// claim name (default <code>roles</code>). Validates signature, expiration,
/// and issuer against configuration in <code>Config.cls</code>.</p>
Class IRISCouch.Auth.JWT Extends %RegisteredObject
{

/// <p>Validate a JWT bearer token and extract user identity.</p>
/// <p>Parses the <code>Authorization: Bearer &lt;token&gt;</code> header,
/// splits the JWT into header/payload/signature, verifies HS256 HMAC
/// signature, checks expiration and issuer claims, and extracts
/// username and roles.</p>
/// @param pAuthHeader The full Authorization header value (e.g., "Bearer eyJ...")
/// @param pUsername Output: The authenticated username from the sub claim
/// @param pRoles Output: A %DynamicArray of role name strings
/// @return 1 if token is valid and all checks pass, 0 otherwise
ClassMethod Validate(pAuthHeader As %String, Output pUsername As %String, Output pRoles As %DynamicArray) As %Boolean
{
    Set tResult = 0
    Set pUsername = ""
    Set pRoles = []
    Try {
        ; Check that JWT auth is enabled
        If '..IsEnabled() Quit
        ; Extract token from "Bearer <token>" header
        Set tScheme = $Piece(pAuthHeader, " ", 1)
        If $ZConvert(tScheme, "U") '= "BEARER" Quit
        Set tToken = $Piece(pAuthHeader, " ", 2)
        If tToken = "" Quit
        ; Split JWT into 3 parts: header.payload.signature
        Set tHeaderB64 = $Piece(tToken, ".", 1)
        Set tPayloadB64 = $Piece(tToken, ".", 2)
        Set tSignatureB64 = $Piece(tToken, ".", 3)
        If (tHeaderB64 = "") || (tPayloadB64 = "") || (tSignatureB64 = "") Quit
        ; Ensure no extra parts (must be exactly 3 segments)
        If $Length(tToken, ".") '= 3 Quit
        ; Decode and validate header
        Set tHeaderJSON = ..Base64URLDecode(tHeaderB64)
        If tHeaderJSON = "" Quit
        Set tHeader = ##class(%DynamicObject).%FromJSON(tHeaderJSON)
        ; Verify algorithm is HS256
        If tHeader.alg '= "HS256" Quit
        ; Decode payload
        Set tPayloadJSON = ..Base64URLDecode(tPayloadB64)
        If tPayloadJSON = "" Quit
        Set tPayload = ##class(%DynamicObject).%FromJSON(tPayloadJSON)
        ; Verify signature: HMAC-SHA256 over "header.payload"
        Set tSecret = ##class(IRISCouch.Config).Get("JWTSECRET")
        Set tMessage = tHeaderB64 _ "." _ tPayloadB64
        Set tExpectedSig = $System.Encryption.HMACSHA(256, tMessage, tSecret)
        ; Decode the provided signature from Base64URL
        Set tProvidedSig = ..Base64URLDecodeRaw(tSignatureB64)
        If tProvidedSig = "" Quit
        ; Timing-safe comparison of signature bytes
        If '##class(IRISCouch.Auth.Session).ConstantTimeEquals(tProvidedSig, tExpectedSig) Quit
        ; Check exp claim - must be present and in the future (with clock-skew tolerance).
        ; Story 13.4 Task 8b: allow configurable clock skew (default 60s) so slightly
        ; desynced clock peers don't bounce every otherwise-valid token.
        Set tExp = tPayload.exp
        If tExp = "" Quit
        Set tNow = ..UnixTimestamp()
        Set tSkew = +$Get(^IRISCouch.Config("JWTCLOCKSKEWSECS"), 60)
        If tExp '> (tNow - tSkew) Quit
        ; Optional nbf (not-before) claim — also tolerate clock skew.
        Set tNbf = tPayload.nbf
        If tNbf '= "" {
            If tNbf > (tNow + tSkew) Quit
        }
        ; Check iss claim - must match configured issuer
        Set tExpectedIss = ##class(IRISCouch.Config).Get("JWTISSUER")
        Set tActualIss = tPayload.iss
        If tActualIss '= tExpectedIss Quit
        ; Extract sub claim (username) - required
        Set tSub = tPayload.sub
        If tSub = "" Quit
        ; Extract roles from configurable claim name
        Set tRolesClaimName = ##class(IRISCouch.Config).Get("JWTROLESCLAIM")
        If tRolesClaimName = "" Set tRolesClaimName = "roles"
        Set tRolesValue = tPayload.%Get(tRolesClaimName)
        Set tRolesArray = []
        If $IsObject(tRolesValue) {
            ; It is a JSON array - iterate and push each role
            Set tIter = tRolesValue.%GetIterator()
            While tIter.%GetNext(.tKey, .tVal) {
                Do tRolesArray.%Push(tVal)
            }
        } ElseIf tRolesValue '= "" {
            ; Comma-separated string of roles
            For i = 1:1:$Length(tRolesValue, ",") {
                Set tRole = $ZStrip($Piece(tRolesValue, ",", i), "<>W")
                If tRole '= "" Do tRolesArray.%Push(tRole)
            }
        }
        ; All checks passed
        Set pUsername = tSub
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

/// <p>Decode a Base64URL-encoded string to its original UTF-8 content.</p>
/// <p>Replaces URL-safe characters (<code>-</code> with <code>+</code>,
/// <code>_</code> with <code>/</code>), adds padding as needed, then
/// calls <code>$System.Encryption.Base64Decode()</code>.</p>
/// @param pInput The Base64URL-encoded string
/// @return The decoded string, or empty string on error
ClassMethod Base64URLDecode(pInput As %String) As %String
{
    Set tResult = ""
    Try {
        If pInput = "" Quit
        ; Replace URL-safe characters with standard Base64
        Set tB64 = $Translate(pInput, "-_", "+/")
        ; Add padding
        Set tMod = $Length(tB64) # 4
        If tMod = 2 {
            Set tB64 = tB64 _ "=="
        } ElseIf tMod = 3 {
            Set tB64 = tB64 _ "="
        }
        Set tResult = $System.Encryption.Base64Decode(tB64)
        Quit
    }
    Catch ex {
        Set tResult = ""
        Quit
    }
    Quit tResult
}

/// <p>Decode a Base64URL-encoded string to raw binary bytes.</p>
/// <p>Same as <method>Base64URLDecode</method> but intended for binary data
/// like HMAC signatures where the result may contain non-printable bytes.</p>
/// @param pInput The Base64URL-encoded string
/// @return The decoded binary bytes, or empty string on error
ClassMethod Base64URLDecodeRaw(pInput As %String) As %String
{
    Quit ..Base64URLDecode(pInput)
}

/// <p>Check whether JWT authentication is enabled.</p>
/// <p>JWT auth requires both <code>JWTISSUER</code> and <code>JWTSECRET</code>
/// to be configured (non-empty) in <class>Config</class>.</p>
/// @return 1 if enabled, 0 if disabled
ClassMethod IsEnabled() As %Boolean
{
    Set tIssuer = ##class(IRISCouch.Config).Get("JWTISSUER")
    Set tSecret = ##class(IRISCouch.Config).Get("JWTSECRET")
    Quit (tIssuer '= "") && (tSecret '= "")
}

/// <p>Get the current Unix timestamp (seconds since 1970-01-01 00:00:00 UTC).</p>
/// <p>Converts IRIS <code>$Horolog</code> to Unix epoch. The IRIS epoch is
/// 1840-12-31, so the offset from IRIS day 0 to Unix epoch (1970-01-01)
/// is 47117 days.</p>
/// @return Integer Unix timestamp
ClassMethod UnixTimestamp() As %Integer
{
    Quit ($Piece($Horolog, ",", 1) - 47117) * 86400 + $Piece($Horolog, ",", 2)
}

/// <p>Base64URL-encode a binary string.</p>
/// <p>Standard Base64 encodes the input, then replaces <code>+</code> with
/// <code>-</code>, <code>/</code> with <code>_</code>, and strips padding
/// <code>=</code> characters. Also strips any linebreaks IRIS may insert.</p>
/// @param pInput The binary string to encode
/// @return The Base64URL-encoded string
ClassMethod Base64URLEncode(pInput As %String) As %String
{
    Set tB64 = $System.Encryption.Base64Encode(pInput)
    ; Strip linebreaks IRIS may insert
    Set tB64 = $Translate(tB64, $Char(13, 10), "")
    ; Replace standard Base64 chars with URL-safe variants
    Set tB64 = $Translate(tB64, "+/", "-_")
    ; Strip padding
    Set tB64 = $ZStrip(tB64, ">", "=")
    Quit tB64
}

}
