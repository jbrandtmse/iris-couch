/// <p>Unit tests for IRISCouch session and basic authentication.</p>
/// <p>Tests cookie creation, validation, HMAC tampering detection,
/// expiration, secret auto-generation, Basic auth header parsing,
/// and user role retrieval.</p>
Class IRISCouch.Test.AuthTest Extends %UnitTest.TestCase
{

/// <p>Handle initvalue parameter from parent class.</p>
Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Quit $$$OK
}

/// <p>Clean up auth config before each test.</p>
Method OnBeforeOneTest() As %Status
{
    Kill ^IRISCouch.Config("AUTHSECRET")
    Kill ^IRISCouch.Config("AUTHTIMEOUT")
    Quit $$$OK
}

/// <p>Clean up auth config after each test.</p>
Method OnAfterOneTest() As %Status
{
    Kill ^IRISCouch.Config("AUTHSECRET")
    Kill ^IRISCouch.Config("AUTHTIMEOUT")
    Quit $$$OK
}

/// <p>Test cookie creation and validation round-trip.</p>
/// <p>AC #1: CreateCookie produces a valid cookie that ValidateCookie accepts,
/// extracting the correct username.</p>
Method TestCreateAndValidateCookie()
{
    Set tCookie = ##class(IRISCouch.Auth.Session).CreateCookie("_SYSTEM")
    Do $$$AssertTrue(tCookie '= "", "CreateCookie returns non-empty value")
    ; Validate the cookie
    Set tValid = ##class(IRISCouch.Auth.Session).ValidateCookie(tCookie, .tUsername)
    Do $$$AssertTrue(tValid, "ValidateCookie returns true for fresh cookie")
    Do $$$AssertEquals(tUsername, "_SYSTEM", "ValidateCookie extracts correct username")
}

/// <p>Test that a tampered cookie is rejected.</p>
/// <p>AC #5: Modifying the HMAC portion of the cookie causes validation to fail.</p>
Method TestTamperedCookieRejected()
{
    Set tCookie = ##class(IRISCouch.Auth.Session).CreateCookie("_SYSTEM")
    Do $$$AssertTrue(tCookie '= "", "Cookie created for tampering test")
    ; Decode, tamper, re-encode
    Set tDecoded = $System.Encryption.Base64Decode(tCookie)
    ; Change the last character of the HMAC
    Set tLen = $Length(tDecoded)
    Set tLastChar = $Extract(tDecoded, tLen)
    If tLastChar = "a" {
        Set tTampered = $Extract(tDecoded, 1, tLen - 1) _ "b"
    } Else {
        Set tTampered = $Extract(tDecoded, 1, tLen - 1) _ "a"
    }
    Set tTamperedCookie = $System.Encryption.Base64Encode(tTampered)
    Set tTamperedCookie = $Translate(tTamperedCookie, $Char(13, 10), "")
    ; Validate tampered cookie
    Set tValid = ##class(IRISCouch.Auth.Session).ValidateCookie(tTamperedCookie, .tUsername)
    Do $$$AssertTrue('tValid, "Tampered cookie is rejected by ValidateCookie")
    Do $$$AssertEquals(tUsername, "", "Username is empty for tampered cookie")
}

/// <p>Test that an expired cookie is rejected.</p>
/// <p>AC #5: Cookie with timestamp older than AUTHTIMEOUT is rejected.</p>
Method TestExpiredCookieRejected()
{
    ; Set a very short timeout (1 second)
    Do ##class(IRISCouch.Config).Set("AUTHTIMEOUT", 1)
    Set tCookie = ##class(IRISCouch.Auth.Session).CreateCookie("_SYSTEM")
    Do $$$AssertTrue(tCookie '= "", "Cookie created for expiration test")
    ; Wait for expiration (Hang 2 seconds)
    Hang 2
    ; Validate expired cookie
    Set tValid = ##class(IRISCouch.Auth.Session).ValidateCookie(tCookie, .tUsername)
    Do $$$AssertTrue('tValid, "Expired cookie is rejected by ValidateCookie")
}

/// <p>Test secret auto-generation and persistence.</p>
/// <p>GetSecret() auto-generates on first call and returns same value on second call.</p>
Method TestGetSecretAutoGenerate()
{
    ; Ensure no secret exists
    Kill ^IRISCouch.Config("AUTHSECRET")
    ; First call should auto-generate
    Set tSecret1 = ##class(IRISCouch.Auth.Session).GetSecret()
    Do $$$AssertTrue(tSecret1 '= "", "GetSecret returns non-empty value on first call")
    Do $$$AssertTrue($Length(tSecret1) = 64, "Auto-generated secret is 64 hex chars (32 bytes)")
    ; Second call should return same value
    Set tSecret2 = ##class(IRISCouch.Auth.Session).GetSecret()
    Do $$$AssertEquals(tSecret1, tSecret2, "GetSecret returns same value on second call")
    ; Verify it was persisted in config
    Set tStored = ##class(IRISCouch.Config).Get("AUTHSECRET")
    Do $$$AssertEquals(tStored, tSecret1, "Secret was persisted in config global")
}

/// <p>Test parsing of valid and invalid Authorization headers.</p>
/// <p>AC #4: Basic auth header with valid credentials succeeds.
/// Invalid headers are rejected.</p>
Method TestBasicAuthParse()
{
    ; Valid Basic auth header
    Set tEncoded = $System.Encryption.Base64Encode("_SYSTEM:SYS")
    Set tHeader = "Basic " _ tEncoded
    Set tOK = ##class(IRISCouch.Auth.Basic).Authenticate(tHeader, .tUsername, .tRoles)
    Do $$$AssertTrue(tOK, "Valid Basic auth header is accepted")
    Do $$$AssertEquals(tUsername, "_SYSTEM", "Username extracted from Basic auth")
    ; Invalid scheme
    Set tOK2 = ##class(IRISCouch.Auth.Basic).Authenticate("Bearer token123", .tUser2, .tRoles2)
    Do $$$AssertTrue('tOK2, "Bearer scheme is rejected")
    ; Empty header
    Set tOK3 = ##class(IRISCouch.Auth.Basic).Authenticate("", .tUser3, .tRoles3)
    Do $$$AssertTrue('tOK3, "Empty header is rejected")
    ; Malformed Base64
    Set tOK4 = ##class(IRISCouch.Auth.Basic).Authenticate("Basic !!!invalid!!!", .tUser4, .tRoles4)
    Do $$$AssertTrue('tOK4, "Malformed Base64 is rejected")
    ; Wrong password
    Set tBadEnc = $System.Encryption.Base64Encode("_SYSTEM:WRONGPASS")
    Set tOK5 = ##class(IRISCouch.Auth.Basic).Authenticate("Basic " _ tBadEnc, .tUser5, .tRoles5)
    Do $$$AssertTrue('tOK5, "Wrong password is rejected via Basic auth")
}

/// <p>Test role retrieval for known IRIS user.</p>
/// <p>AC #4: GetUserRoles returns roles for _SYSTEM user.</p>
Method TestGetUserRoles()
{
    Set tRoles = ##class(IRISCouch.Auth.Basic).GetUserRoles("_SYSTEM")
    Do $$$AssertTrue($IsObject(tRoles), "GetUserRoles returns an object")
    Do $$$AssertTrue(tRoles.%Size() > 0, "SYSTEM user has at least one role")
    Do $$$AssertEquals(tRoles.%Get(0), "%All", "SYSTEM user has %All role")
}

/// <p>Test hex conversion utilities.</p>
Method TestHexConversion()
{
    ; Test DecToHex
    Do $$$AssertEquals(##class(IRISCouch.Auth.Session).DecToHex(0), "0", "DecToHex(0) = 0")
    Do $$$AssertEquals(##class(IRISCouch.Auth.Session).DecToHex(255), "ff", "DecToHex(255) = ff")
    Do $$$AssertEquals(##class(IRISCouch.Auth.Session).DecToHex(256), "100", "DecToHex(256) = 100")
    ; Test HexToDec
    Do $$$AssertEquals(##class(IRISCouch.Auth.Session).HexToDec("0"), 0, "HexToDec(0) = 0")
    Do $$$AssertEquals(##class(IRISCouch.Auth.Session).HexToDec("ff"), 255, "HexToDec(ff) = 255")
    Do $$$AssertEquals(##class(IRISCouch.Auth.Session).HexToDec("100"), 256, "HexToDec(100) = 256")
    ; Round-trip
    Set tVal = 1234567890
    Set tHex = ##class(IRISCouch.Auth.Session).DecToHex(tVal)
    Set tDec = ##class(IRISCouch.Auth.Session).HexToDec(tHex)
    Do $$$AssertEquals(tDec, tVal, "Hex round-trip preserves value")
}

/// <p>Test cookie with different usernames.</p>
Method TestCookieWithDifferentUsernames()
{
    ; Create cookies for different users - they should be distinct
    Set tCookie1 = ##class(IRISCouch.Auth.Session).CreateCookie("UserA")
    Set tCookie2 = ##class(IRISCouch.Auth.Session).CreateCookie("UserB")
    Do $$$AssertTrue(tCookie1 '= tCookie2, "Different users produce different cookies")
    ; Validate each returns correct username
    Set tValid1 = ##class(IRISCouch.Auth.Session).ValidateCookie(tCookie1, .tUser1)
    Set tValid2 = ##class(IRISCouch.Auth.Session).ValidateCookie(tCookie2, .tUser2)
    Do $$$AssertTrue(tValid1, "Cookie for UserA is valid")
    Do $$$AssertTrue(tValid2, "Cookie for UserB is valid")
    Do $$$AssertEquals(tUser1, "UserA", "Cookie extracts UserA correctly")
    Do $$$AssertEquals(tUser2, "UserB", "Cookie extracts UserB correctly")
}

/// <p>Test that completely invalid cookie values are rejected.</p>
Method TestInvalidCookieFormats()
{
    ; Empty cookie
    Set tValid1 = ##class(IRISCouch.Auth.Session).ValidateCookie("", .tUser1)
    Do $$$AssertTrue('tValid1, "Empty cookie is rejected")
    ; Random garbage
    Set tValid2 = ##class(IRISCouch.Auth.Session).ValidateCookie("notbase64!!!", .tUser2)
    Do $$$AssertTrue('tValid2, "Random garbage cookie is rejected")
    ; Valid Base64 but wrong format
    Set tValid3 = ##class(IRISCouch.Auth.Session).ValidateCookie($System.Encryption.Base64Encode("just-a-string"), .tUser3)
    Do $$$AssertTrue('tValid3, "Wrong format cookie is rejected")
}

}
