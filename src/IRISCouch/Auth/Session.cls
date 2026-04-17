/// <p>Cookie-based session authentication engine for IRISCouch.</p>
/// <p>Implements CouchDB-compatible <code>AuthSession</code> cookie creation,
/// validation, and HMAC-SHA256 signing. Cookies are stateless and verified
/// against a per-instance secret stored in configuration (NFR-S3).</p>
/// <p>Cookie format: <code>base64(username:hexTimestamp:hmacHex)</code></p>
Class IRISCouch.Auth.Session Extends %RegisteredObject
{

/// <p>Create an HMAC-signed AuthSession cookie value for the given username.</p>
/// <p>Builds a CouchDB-compatible cookie value containing the username,
/// a hex-encoded Unix timestamp, and an HMAC-SHA256 signature. The entire
/// payload is Base64-encoded.</p>
/// @param pUsername The authenticated username
/// @return The full cookie value string (e.g., "AuthSession=base64data")
ClassMethod CreateCookie(pUsername As %String) As %String
{
    Set tResult = ""
    Try {
        Set tSecret = ..GetSecret()
        ; Build timestamp as hex (CouchDB convention)
        Set tTimestamp = $ZHorolog
        Set tHexTime = ..DecToHex($Piece(tTimestamp, ",", 1) + ($Piece(tTimestamp, ",", 2) \ 1))
        ; Build data to sign: username:hexTimestamp
        Set tData = pUsername _ ":" _ tHexTime
        ; HMAC-SHA256 sign the data
        Set tHMAC = $System.Encryption.HMACSHA(256, tData, tSecret)
        Set tHMACHex = ..BytesToHex(tHMAC)
        ; Build cookie payload: username:hexTimestamp:hmacHex
        Set tPayload = pUsername _ ":" _ tHexTime _ ":" _ tHMACHex
        ; Base64 encode the payload (strip linebreaks IRIS may insert)
        Set tEncoded = $System.Encryption.Base64Encode(tPayload)
        Set tEncoded = $Translate(tEncoded, $Char(13, 10), "")
        Set tResult = tEncoded
        Quit
    }
    Catch ex {
        Set tResult = ""
        Quit
    }
    Quit tResult
}

/// <p>Validate an AuthSession cookie value and extract the username.</p>
/// <p>Decodes the Base64 cookie, extracts the username, timestamp, and HMAC,
/// verifies the HMAC signature against the stored secret, and checks that
/// the timestamp has not expired.</p>
/// @param pCookieValue The Base64-encoded cookie value (without "AuthSession=" prefix)
/// @param pUsername Output: The authenticated username if valid
/// @return 1 if valid, 0 if invalid or expired
ClassMethod ValidateCookie(pCookieValue As %String, Output pUsername As %String) As %Boolean
{
    Set tResult = 0
    Set pUsername = ""
    Try {
        ; Decode Base64
        Set tDecoded = $System.Encryption.Base64Decode(pCookieValue)
        If tDecoded = "" Quit
        ; Parse: username:hexTimestamp:hmacHex
        Set tUsername = $Piece(tDecoded, ":", 1)
        Set tHexTime = $Piece(tDecoded, ":", 2)
        Set tHMACHex = $Piece(tDecoded, ":", 3)
        If (tUsername = "") || (tHexTime = "") || (tHMACHex = "") Quit
        ; Verify HMAC using constant-time comparison to prevent timing attacks
        Set tSecret = ..GetSecret()
        Set tData = tUsername _ ":" _ tHexTime
        Set tExpectedHMAC = $System.Encryption.HMACSHA(256, tData, tSecret)
        Set tExpectedHex = ..BytesToHex(tExpectedHMAC)
        If '..ConstantTimeEquals(tHMACHex, tExpectedHex) Quit
        ; Check expiration
        Set tTimestampSec = ..HexToDec(tHexTime)
        Set tNow = $Piece($ZHorolog, ",", 1) + ($Piece($ZHorolog, ",", 2) \ 1)
        Set tTimeout = ##class(IRISCouch.Config).Get("AUTHTIMEOUT")
        Set tAge = tNow - tTimestampSec
        If (tAge > tTimeout) || (tAge < 0) Quit
        ; All checks passed
        Set pUsername = tUsername
        Set tResult = 1
        Quit
    }
    Catch ex {
        Set tResult = 0
        Quit
    }
    Quit tResult
}

/// <p>Get or auto-generate the HMAC signing secret.</p>
/// <p>Reads the AUTHSECRET from configuration. If empty, generates a random
/// 32-byte hex secret, persists it via Config.Set(), and returns it.
/// Subsequent calls return the persisted value.</p>
/// @return The HMAC signing secret string
ClassMethod GetSecret() As %String
{
    Set tResult = ""
    Try {
        Set tResult = ##class(IRISCouch.Config).Get("AUTHSECRET")
        If tResult '= "" Quit
        ; Auto-generate a 32-byte random hex secret
        Set tBytes = $System.Encryption.GenCryptRand(32)
        Set tResult = ..BytesToHex(tBytes)
        ; Persist the generated secret
        Do ##class(IRISCouch.Config).Set("AUTHSECRET", tResult)
        Quit
    }
    Catch ex {
        Set tResult = ""
        Quit
    }
    Quit tResult
}

/// <p>Build a CouchDB-compatible user context object for JS callbacks (Story 12.3).</p>
/// <p>Returns <code>{"name": &lt;username&gt;, "roles": [&lt;role&gt;...]}</code> read
/// from the Router-populated process-private variables <code>%IRISCouchUser</code>
/// and <code>%IRISCouchRoles</code>. If no auth context is active (e.g. an
/// unauthenticated request reaching a disabled-auth deployment), emits
/// <code>{"name": null, "roles": ["_admin"]}</code> — CouchDB's
/// "admin-party" default (trusted-admin deployment per
/// <code>documentation/js-runtime.md</code>).</p>
/// <p>The <code>name</code> field is emitted as JSON <code>null</code> when the
/// user is anonymous (following
/// <code>.claude/rules/iris-objectscript-basics.md::feedback_json_null_pattern</code>).</p>
/// @return %DynamicObject with <code>name</code> (string or null) and
///         <code>roles</code> (%DynamicArray of strings)
ClassMethod BuildUserCtx() As %DynamicObject
{
    Set tCtx = {}
    Set tUser = $Get(%IRISCouchUser, "")
    Set tRoles = $Get(%IRISCouchRoles, "")
    If tUser = "" {
        ; Anonymous — admin-party default.
        Do tCtx.%Set("name", "", "null")
        Set tDefault = []
        Do tDefault.%Push("_admin")
        Do tCtx.%Set("roles", tDefault)
        Quit tCtx
    }
    Do tCtx.%Set("name", tUser)
    If $IsObject(tRoles) {
        Do tCtx.%Set("roles", tRoles)
    } Else {
        Do tCtx.%Set("roles", [])
    }
    Quit tCtx
}

/// <p>Convert a decimal integer to a lowercase hexadecimal string.</p>
/// @param pDec The decimal integer value
/// @return Lowercase hexadecimal string representation
ClassMethod DecToHex(pDec As %Integer) As %String
{
    Set tHex = ""
    Set tVal = pDec
    If tVal = 0 Quit "0"
    While tVal > 0 {
        Set tRemainder = tVal # 16
        Set tHex = $Extract("0123456789abcdef", tRemainder + 1) _ tHex
        Set tVal = tVal \ 16
    }
    Quit tHex
}

/// <p>Convert a lowercase hexadecimal string to a decimal integer.</p>
/// @param pHex The hexadecimal string
/// @return Decimal integer value
ClassMethod HexToDec(pHex As %String) As %Integer
{
    Set tResult = 0
    Set tLen = $Length(pHex)
    For i = 1:1:tLen {
        Set tChar = $Extract(pHex, i)
        Set tVal = $Find("0123456789abcdef", tChar) - 2
        If tVal < 0 Set tVal = 0
        Set tResult = (tResult * 16) + tVal
    }
    Quit tResult
}

/// <p>Constant-time string comparison to prevent timing attacks on HMAC verification.</p>
/// <p>Compares every character regardless of mismatch to avoid leaking
/// information about which character position differs.</p>
/// @param pA First string to compare
/// @param pB Second string to compare
/// @return 1 if equal, 0 if not equal
ClassMethod ConstantTimeEquals(pA As %String, pB As %String) As %Boolean
{
    If $Length(pA) '= $Length(pB) {
        ; Still iterate to maintain constant time on length mismatch
        Set tDiff = 1
    } Else {
        Set tDiff = 0
    }
    ; Iterate over the longer string to avoid short-circuit
    Set tLen = $Length(pA)
    If $Length(pB) > tLen Set tLen = $Length(pB)
    If tLen = 0 Quit 'tDiff
    For i = 1:1:tLen {
        Set tCharA = $Select(i <= $Length(pA): $Ascii(pA, i), 1: 0)
        Set tCharB = $Select(i <= $Length(pB): $Ascii(pB, i), 1: 0)
        If tCharA '= tCharB Set tDiff = 1
    }
    Quit 'tDiff
}

/// <p>Convert a binary byte string to a lowercase hexadecimal string.</p>
/// @param pBytes The binary byte string
/// @return Lowercase hexadecimal string representation
ClassMethod BytesToHex(pBytes As %String) As %String
{
    Set tHex = ""
    For i = 1:1:$Length(pBytes) {
        Set tByte = $Ascii(pBytes, i)
        Set tHex = tHex _ $Extract("0123456789abcdef", (tByte \ 16) + 1) _ $Extract("0123456789abcdef", (tByte # 16) + 1)
    }
    Quit tHex
}

}
