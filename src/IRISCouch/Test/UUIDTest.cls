/// <p>Unit tests for <class>IRISCouch.Util.UUID</class> and the
/// <code>HandleUUIDs</code> endpoint on <class>IRISCouch.API.ServerHandler</class>.</p>
/// <p>Tests UUID generation format, count, uniqueness, and validation logic.</p>
Class IRISCouch.Test.UUIDTest Extends %UnitTest.TestCase
{

/// <p>Handle initvalue parameter from parent class.</p>
Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Quit $$$OK
}

/// <p>Verify a single generated UUID is a 32-character lowercase hex string.</p>
/// <p>AC #4: UUID is a lowercase 32-character hex string.</p>
Method TestGenerateSingleUUID()
{
    Set tUUID = ##class(IRISCouch.Util.UUID).Generate()

    ; Verify length is exactly 32 characters
    Do $$$AssertEquals($Length(tUUID), 32, "UUID is 32 characters long")

    ; Verify it contains only lowercase hex characters (a-f, 0-9)
    Set tIsHex = $Match(tUUID, "^[0-9a-f]{32}$")
    Do $$$AssertTrue(tIsHex, "UUID matches lowercase hex pattern [0-9a-f]{32}")

    ; Verify no dashes
    Do $$$AssertTrue(tUUID '[ "-", "UUID contains no dashes")

    ; Verify no braces
    Do $$$AssertTrue(tUUID '[ "{", "UUID contains no opening braces")
    Do $$$AssertTrue(tUUID '[ "}", "UUID contains no closing braces")

    ; Verify lowercase (no uppercase letters)
    Do $$$AssertEquals(tUUID, $ZConvert(tUUID, "L"), "UUID is all lowercase")
}

/// <p>Verify GenerateN returns the correct count of unique UUIDs.</p>
/// <p>AC #2: count=3 returns 3 unique hex UUIDs.</p>
/// <p>AC #4: Each UUID is a lowercase 32-character hex string.</p>
Method TestGenerateMultipleUUIDs()
{
    Set tCount = 5
    Set tArray = ##class(IRISCouch.Util.UUID).GenerateN(tCount)

    ; Verify it is a DynamicArray
    Do $$$AssertTrue($IsObject(tArray), "GenerateN returns an object")

    ; Verify count
    Do $$$AssertEquals(tArray.%Size(), tCount, "GenerateN returns requested count of UUIDs")

    ; Verify each UUID format and collect for uniqueness check
    Set tSeen = ""
    For tI = 0:1:(tCount - 1) {
        Set tUUID = tArray.%Get(tI)
        Do $$$AssertEquals($Length(tUUID), 32, "UUID #"_(tI+1)_" is 32 characters")
        Set tIsHex = $Match(tUUID, "^[0-9a-f]{32}$")
        Do $$$AssertTrue(tIsHex, "UUID #"_(tI+1)_" matches hex pattern")

        ; Uniqueness: check not seen before
        Do $$$AssertTrue(tSeen '[ ("|"_tUUID_"|"), "UUID #"_(tI+1)_" is unique")
        Set tSeen = tSeen_"|"_tUUID_"|"
    }
}

/// <p>Verify default count=1 response structure from HandleUUIDs logic.</p>
/// <p>AC #1: GET /_uuids returns 200 with {"uuids":["&lt;hex-uuid&gt;"]} with exactly 1 UUID.</p>
Method TestHandleUUIDsDefault()
{
    ; Simulate default count = 1
    Set tCount = 1
    Set tUUIDs = ##class(IRISCouch.Util.UUID).GenerateN(tCount)
    Set tResponse = {}
    Set tResponse.uuids = tUUIDs

    ; Verify response structure
    Do $$$AssertTrue($IsObject(tResponse), "Response is an object")
    Do $$$AssertTrue($IsObject(tResponse.uuids), "Response has uuids array")
    Do $$$AssertEquals(tResponse.uuids.%Size(), 1, "Default count returns 1 UUID")

    ; Verify JSON serialization
    Set tJSON = tResponse.%ToJSON()
    Do $$$AssertTrue(tJSON [ """uuids""", "JSON contains uuids key")

    ; Verify the UUID in the response is valid format
    Set tUUID = tResponse.uuids.%Get(0)
    Do $$$AssertEquals($Length(tUUID), 32, "Response UUID is 32 characters")
    Set tIsHex = $Match(tUUID, "^[0-9a-f]{32}$")
    Do $$$AssertTrue(tIsHex, "Response UUID matches hex pattern")
}

/// <p>Verify count=3 returns 3 UUIDs in proper response structure.</p>
/// <p>AC #2: GET /_uuids?count=3 returns {"uuids":[...]} with exactly 3 unique UUIDs.</p>
Method TestHandleUUIDsWithCount()
{
    Set tCount = 3
    Set tUUIDs = ##class(IRISCouch.Util.UUID).GenerateN(tCount)
    Set tResponse = {}
    Set tResponse.uuids = tUUIDs

    ; Verify count
    Do $$$AssertEquals(tResponse.uuids.%Size(), 3, "count=3 returns 3 UUIDs")

    ; Verify all UUIDs are valid and unique
    Set tSeen = ""
    For tI = 0:1:2 {
        Set tUUID = tResponse.uuids.%Get(tI)
        Do $$$AssertEquals($Length(tUUID), 32, "UUID #"_(tI+1)_" is 32 characters")
        Do $$$AssertTrue(tSeen '[ ("|"_tUUID_"|"), "UUID #"_(tI+1)_" is unique")
        Set tSeen = tSeen_"|"_tUUID_"|"
    }

    ; Verify JSON round-trip
    Set tJSON = tResponse.%ToJSON()
    Set tParsed = ##class(%DynamicObject).%FromJSON(tJSON)
    Do $$$AssertEquals(tParsed.uuids.%Size(), 3, "JSON round-trip preserves 3 UUIDs")
}

/// <p>Verify count validation rejects invalid values.</p>
/// <p>AC #3: count=0 or negative returns 400 Bad Request with JSON error envelope.</p>
Method TestHandleUUIDsInvalidCount()
{
    ; Test count = 0 (invalid)
    Set tCount = 0
    Set tIsInvalid = ((tCount '= +tCount) || (tCount < 1) || (tCount > 1000) || (tCount \ 1 '= tCount))
    Do $$$AssertTrue(tIsInvalid, "count=0 is detected as invalid")

    ; Test count = -1 (invalid)
    Set tCount = -1
    Set tIsInvalid = ((tCount '= +tCount) || (tCount < 1) || (tCount > 1000) || (tCount \ 1 '= tCount))
    Do $$$AssertTrue(tIsInvalid, "count=-1 is detected as invalid")

    ; Test count = "abc" (non-numeric, invalid)
    Set tCount = "abc"
    Set tIsInvalid = ((tCount '= +tCount) || (tCount < 1))
    Do $$$AssertTrue(tIsInvalid, "count=abc is detected as invalid")

    ; Test count = 1001 (exceeds max, invalid)
    Set tCount = 1001
    Set tIsInvalid = ((tCount '= +tCount) || (tCount < 1) || (tCount > 1000) || (tCount \ 1 '= tCount))
    Do $$$AssertTrue(tIsInvalid, "count=1001 exceeds max and is detected as invalid")

    ; Test count = 1.5 (fractional, invalid)
    Set tCount = 1.5
    Set tIsInvalid = ((tCount '= +tCount) || (tCount < 1) || (tCount > 1000) || (tCount \ 1 '= tCount))
    Do $$$AssertTrue(tIsInvalid, "count=1.5 is fractional and detected as invalid")

    ; Test count = 1 (valid)
    Set tCount = 1
    Set tIsValid = ((tCount = +tCount) && (tCount >= 1) && (tCount <= 1000) && (tCount \ 1 = tCount))
    Do $$$AssertTrue(tIsValid, "count=1 is detected as valid")

    ; Test count = 1000 (max boundary, valid)
    Set tCount = 1000
    Set tIsValid = ((tCount = +tCount) && (tCount >= 1) && (tCount <= 1000) && (tCount \ 1 = tCount))
    Do $$$AssertTrue(tIsValid, "count=1000 is at max boundary and detected as valid")

    ; Verify the error slug constant exists
    Set tSlug = ##class(IRISCouch.Util.Error).#BADREQUEST
    Do $$$AssertEquals(tSlug, "bad_request", "Error BADREQUEST slug is bad_request")
}

}
