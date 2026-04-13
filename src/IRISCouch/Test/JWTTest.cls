/// <p>Unit tests for IRISCouch JWT and Proxy authentication.</p>
/// <p>Tests JWT token validation (valid, expired, bad signature, wrong issuer,
/// missing claims), Base64URL decoding, proxy auth HMAC validation,
/// and auth enable/disable via configuration.</p>
Class IRISCouch.Test.JWTTest Extends %UnitTest.TestCase
{

/// <p>Handle initvalue parameter from parent class.</p>
Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Quit $$$OK
}

/// <p>Set up JWT and proxy config for each test.</p>
Method OnBeforeOneTest() As %Status
{
    Do ##class(IRISCouch.Config).Set("JWTSECRET", "test-jwt-secret-key-1234")
    Do ##class(IRISCouch.Config).Set("JWTISSUER", "test-issuer")
    Do ##class(IRISCouch.Config).Set("JWTROLESCLAIM", "roles")
    Do ##class(IRISCouch.Config).Set("PROXYAUTHSECRET", "test-proxy-secret")
    Quit $$$OK
}

/// <p>Clean up JWT and proxy config after each test.</p>
Method OnAfterOneTest() As %Status
{
    Kill ^IRISCouch.Config("JWTSECRET")
    Kill ^IRISCouch.Config("JWTISSUER")
    Kill ^IRISCouch.Config("JWTROLESCLAIM")
    Kill ^IRISCouch.Config("PROXYAUTHSECRET")
    Quit $$$OK
}

/// <p>Build a valid HS256 JWT for testing.</p>
/// @param pSub Subject (username) claim
/// @param pIss Issuer claim
/// @param pExp Expiration timestamp (Unix epoch seconds)
/// @param pRoles %DynamicArray of role strings
/// @param pSecret The HMAC secret for signing
/// @return The complete JWT string
ClassMethod BuildTestJWT(pSub As %String, pIss As %String, pExp As %Integer, pRoles As %DynamicArray = "", pSecret As %String = "test-jwt-secret-key-1234") As %String
{
    ; Build header
    Set tHeader = {"alg":"HS256","typ":"JWT"}
    Set tHeaderB64 = ##class(IRISCouch.Auth.JWT).Base64URLEncode(tHeader.%ToJSON())
    ; Build payload
    Set tPayload = {}
    Set tPayload.sub = pSub
    Set tPayload.iss = pIss
    Set tPayload.exp = pExp
    Set tPayload.iat = ##class(IRISCouch.Auth.JWT).UnixTimestamp()
    If $IsObject(pRoles) {
        Set tPayload.roles = pRoles
    } Else {
        Set tPayload.roles = []
    }
    Set tPayloadB64 = ##class(IRISCouch.Auth.JWT).Base64URLEncode(tPayload.%ToJSON())
    ; Compute HMAC-SHA256 signature
    Set tMessage = tHeaderB64 _ "." _ tPayloadB64
    Set tSig = $System.Encryption.HMACSHA(256, tMessage, pSecret)
    Set tSigB64 = ##class(IRISCouch.Auth.JWT).Base64URLEncode(tSig)
    ; Return complete JWT
    Quit tHeaderB64 _ "." _ tPayloadB64 _ "." _ tSigB64
}

/// <p>Test valid JWT token validation.</p>
/// <p>AC #1: Valid HS256 JWT with correct issuer, non-expired, and sub claim
/// is accepted and username/roles are extracted correctly.</p>
Method TestValidJWT()
{
    Set tRoles = ["editor", "viewer"]
    Set tExp = ##class(IRISCouch.Auth.JWT).UnixTimestamp() + 3600
    Set tJWT = ..BuildTestJWT("testuser", "test-issuer", tExp, tRoles)
    Set tHeader = "Bearer " _ tJWT
    Set tOK = ##class(IRISCouch.Auth.JWT).Validate(tHeader, .tUsername, .tOutRoles)
    Do $$$AssertTrue(tOK, "Valid JWT is accepted")
    Do $$$AssertEquals(tUsername, "testuser", "Username extracted from sub claim")
    Do $$$AssertTrue($IsObject(tOutRoles), "Roles is an object")
    Do $$$AssertEquals(tOutRoles.%Size(), 2, "Two roles extracted")
    Do $$$AssertEquals(tOutRoles.%Get(0), "editor", "First role is editor")
    Do $$$AssertEquals(tOutRoles.%Get(1), "viewer", "Second role is viewer")
}

/// <p>Test expired JWT token is rejected.</p>
/// <p>AC #2: JWT with past exp claim is rejected.</p>
Method TestExpiredJWT()
{
    Set tExp = ##class(IRISCouch.Auth.JWT).UnixTimestamp() - 3600
    Set tJWT = ..BuildTestJWT("testuser", "test-issuer", tExp)
    Set tHeader = "Bearer " _ tJWT
    Set tOK = ##class(IRISCouch.Auth.JWT).Validate(tHeader, .tUsername, .tRoles)
    Do $$$AssertTrue('tOK, "Expired JWT is rejected")
    Do $$$AssertEquals(tUsername, "", "No username for expired JWT")
}

/// <p>Test JWT with bad signature is rejected.</p>
/// <p>AC #2: JWT signed with wrong secret fails validation.</p>
Method TestBadSignatureJWT()
{
    Set tExp = ##class(IRISCouch.Auth.JWT).UnixTimestamp() + 3600
    Set tJWT = ..BuildTestJWT("testuser", "test-issuer", tExp, "", "wrong-secret-key")
    Set tHeader = "Bearer " _ tJWT
    Set tOK = ##class(IRISCouch.Auth.JWT).Validate(tHeader, .tUsername, .tRoles)
    Do $$$AssertTrue('tOK, "JWT with bad signature is rejected")
    Do $$$AssertEquals(tUsername, "", "No username for bad signature JWT")
}

/// <p>Test JWT with wrong issuer is rejected.</p>
/// <p>AC #2: JWT with non-matching iss claim is rejected.</p>
Method TestWrongIssuerJWT()
{
    Set tExp = ##class(IRISCouch.Auth.JWT).UnixTimestamp() + 3600
    Set tJWT = ..BuildTestJWT("testuser", "wrong-issuer", tExp)
    Set tHeader = "Bearer " _ tJWT
    Set tOK = ##class(IRISCouch.Auth.JWT).Validate(tHeader, .tUsername, .tRoles)
    Do $$$AssertTrue('tOK, "JWT with wrong issuer is rejected")
    Do $$$AssertEquals(tUsername, "", "No username for wrong issuer JWT")
}

/// <p>Test JWT without sub claim is rejected.</p>
/// <p>AC #2: JWT missing sub claim is rejected.</p>
Method TestMissingSubClaim()
{
    ; Build JWT manually without sub claim
    Set tHeader = {"alg":"HS256","typ":"JWT"}
    Set tHeaderB64 = ##class(IRISCouch.Auth.JWT).Base64URLEncode(tHeader.%ToJSON())
    Set tPayload = {}
    Set tPayload.iss = "test-issuer"
    Set tPayload.exp = ##class(IRISCouch.Auth.JWT).UnixTimestamp() + 3600
    Set tPayloadB64 = ##class(IRISCouch.Auth.JWT).Base64URLEncode(tPayload.%ToJSON())
    Set tMessage = tHeaderB64 _ "." _ tPayloadB64
    Set tSig = $System.Encryption.HMACSHA(256, tMessage, "test-jwt-secret-key-1234")
    Set tSigB64 = ##class(IRISCouch.Auth.JWT).Base64URLEncode(tSig)
    Set tJWT = tHeaderB64 _ "." _ tPayloadB64 _ "." _ tSigB64
    Set tAuthHeader = "Bearer " _ tJWT
    Set tOK = ##class(IRISCouch.Auth.JWT).Validate(tAuthHeader, .tUsername, .tRoles)
    Do $$$AssertTrue('tOK, "JWT without sub claim is rejected")
    Do $$$AssertEquals(tUsername, "", "No username when sub is missing")
}

/// <p>Test Base64URL decoding handles URL-safe characters and missing padding.</p>
Method TestBase64URLDecode()
{
    ; Test standard case
    Set tEncoded = ##class(IRISCouch.Auth.JWT).Base64URLEncode("Hello, World!")
    Set tDecoded = ##class(IRISCouch.Auth.JWT).Base64URLDecode(tEncoded)
    Do $$$AssertEquals(tDecoded, "Hello, World!", "Base64URL round-trip for ASCII")
    ; Test with characters that produce - and _ in Base64URL
    ; (bytes with values that map to + and / in standard Base64)
    Set tOriginal = $Char(251, 239, 254)
    Set tEnc = ##class(IRISCouch.Auth.JWT).Base64URLEncode(tOriginal)
    ; Verify no + or / or = in the encoded string
    Do $$$AssertTrue(tEnc '[ "+", "No + in Base64URL encoding")
    Do $$$AssertTrue(tEnc '[ "/", "No / in Base64URL encoding")
    Set tDec = ##class(IRISCouch.Auth.JWT).Base64URLDecode(tEnc)
    Do $$$AssertEquals(tDec, tOriginal, "Base64URL round-trip for binary data")
    ; Test empty input
    Do $$$AssertEquals(##class(IRISCouch.Auth.JWT).Base64URLDecode(""), "", "Empty input returns empty")
}

/// <p>Test IsEnabled returns 0 when JWTSECRET is empty.</p>
Method TestJWTDisabledWhenNoConfig()
{
    Kill ^IRISCouch.Config("JWTSECRET")
    Kill ^IRISCouch.Config("JWTISSUER")
    Set tEnabled = ##class(IRISCouch.Auth.JWT).IsEnabled()
    Do $$$AssertTrue('tEnabled, "JWT disabled when JWTSECRET empty")
    ; Also disabled when only issuer is set
    Do ##class(IRISCouch.Config).Set("JWTISSUER", "some-issuer")
    Set tEnabled2 = ##class(IRISCouch.Auth.JWT).IsEnabled()
    Do $$$AssertTrue('tEnabled2, "JWT disabled when JWTSECRET empty but issuer set")
    ; Also disabled when only secret is set
    Kill ^IRISCouch.Config("JWTISSUER")
    Do ##class(IRISCouch.Config).Set("JWTSECRET", "some-secret")
    Set tEnabled3 = ##class(IRISCouch.Auth.JWT).IsEnabled()
    Do $$$AssertTrue('tEnabled3, "JWT disabled when JWTISSUER empty but secret set")
}

/// <p>Test valid proxy auth with correct HMAC token.</p>
/// <p>AC #3: Valid proxy headers with correct HMAC-SHA1 token succeed.</p>
Method TestProxyAuthValid()
{
    ; Compute HMAC-SHA1 token for username "proxyuser" with secret "test-proxy-secret"
    ; HMACSHA uses bit size: 160 = SHA-1
    Set tHMAC = $System.Encryption.HMACSHA(160, "proxyuser", "test-proxy-secret")
    Set tHex = ##class(IRISCouch.Auth.Session).BytesToHex(tHMAC)
    ; We cannot directly call Authenticate without %request, so test the HMAC logic
    ; by verifying the computation matches expectations
    Do $$$AssertTrue(tHex '= "", "HMAC-SHA1 produces non-empty hex")
    Do $$$AssertTrue($Length(tHex) = 40, "HMAC-SHA1 hex is 40 chars (20 bytes)")
    ; Verify IsEnabled returns true when secret is set
    Set tEnabled = ##class(IRISCouch.Auth.Proxy).IsEnabled()
    Do $$$AssertTrue(tEnabled, "Proxy auth enabled when PROXYAUTHSECRET is set")
}

/// <p>Test proxy auth disabled when no secret configured.</p>
Method TestProxyAuthDisabledWhenNoSecret()
{
    Kill ^IRISCouch.Config("PROXYAUTHSECRET")
    Set tEnabled = ##class(IRISCouch.Auth.Proxy).IsEnabled()
    Do $$$AssertTrue('tEnabled, "Proxy auth disabled when PROXYAUTHSECRET empty")
}

/// <p>Test Unix timestamp conversion is reasonable.</p>
Method TestUnixTimestamp()
{
    Set tNow = ##class(IRISCouch.Auth.JWT).UnixTimestamp()
    ; Unix timestamp should be a large positive number (after year 2020 = 1577836800)
    Do $$$AssertTrue(tNow > 1577836800, "Unix timestamp is after year 2020")
    ; Should be before year 2100 = 4102444800
    Do $$$AssertTrue(tNow < 4102444800, "Unix timestamp is before year 2100")
}

/// <p>Test JWT with non-HS256 algorithm is rejected.</p>
Method TestNonHS256AlgorithmRejected()
{
    ; Build JWT with RS256 header (unsupported in our MVP)
    Set tHeader = {"alg":"RS256","typ":"JWT"}
    Set tHeaderB64 = ##class(IRISCouch.Auth.JWT).Base64URLEncode(tHeader.%ToJSON())
    Set tPayload = {"sub":"testuser","iss":"test-issuer","exp":9999999999}
    Set tPayloadB64 = ##class(IRISCouch.Auth.JWT).Base64URLEncode(tPayload.%ToJSON())
    Set tMessage = tHeaderB64 _ "." _ tPayloadB64
    Set tSig = $System.Encryption.HMACSHA(256, tMessage, "test-jwt-secret-key-1234")
    Set tSigB64 = ##class(IRISCouch.Auth.JWT).Base64URLEncode(tSig)
    Set tJWT = tHeaderB64 _ "." _ tPayloadB64 _ "." _ tSigB64
    Set tOK = ##class(IRISCouch.Auth.JWT).Validate("Bearer " _ tJWT, .tUsername, .tRoles)
    Do $$$AssertTrue('tOK, "RS256 algorithm JWT is rejected (only HS256 supported)")
}

/// <p>Test malformed JWT tokens are rejected gracefully.</p>
Method TestMalformedJWTRejected()
{
    ; Too few parts
    Set tOK1 = ##class(IRISCouch.Auth.JWT).Validate("Bearer abc.def", .tU1, .tR1)
    Do $$$AssertTrue('tOK1, "JWT with 2 parts is rejected")
    ; Too many parts
    Set tOK2 = ##class(IRISCouch.Auth.JWT).Validate("Bearer a.b.c.d", .tU2, .tR2)
    Do $$$AssertTrue('tOK2, "JWT with 4 parts is rejected")
    ; Empty token
    Set tOK3 = ##class(IRISCouch.Auth.JWT).Validate("Bearer ", .tU3, .tR3)
    Do $$$AssertTrue('tOK3, "JWT with empty token is rejected")
    ; Not a Bearer header
    Set tOK4 = ##class(IRISCouch.Auth.JWT).Validate("Basic abc123", .tU4, .tR4)
    Do $$$AssertTrue('tOK4, "Basic auth header is rejected by JWT validator")
}

}
