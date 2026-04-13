/// <p>Unit tests for MangoSelector normalization and matching engine.</p>
/// <p>Tests all 18+ selector operators, normalization, cross-type comparison,
/// and edge cases including empty selectors and missing fields.</p>
Class IRISCouch.Test.MangoSelectorTest Extends %UnitTest.TestCase
{

/// <p>Handle initvalue parameter from parent class.</p>
Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Quit $$$OK
}

/// <p>Test bare value normalization to $eq.</p>
Method TestNormalizeBareValue()
{
    Set tSel = {"name":"Paul"}
    Set tNorm = ##class(IRISCouch.Query.MangoSelector).Normalize(tSel)
    ; Should become {"name":{"$eq":"Paul"}}
    Do $$$AssertTrue($IsObject(tNorm), "Normalized result is object")
    Set tNameCond = tNorm.%Get("name")
    Do $$$AssertTrue($IsObject(tNameCond), "name condition is object")
    Do $$$AssertEquals(tNameCond.%Get("$eq"), "Paul", "Bare value normalized to $eq")
}

/// <p>Test implicit $and for multi-field selectors.</p>
Method TestNormalizeImplicitAnd()
{
    Set tSel = {"a":1,"b":2}
    Set tNorm = ##class(IRISCouch.Query.MangoSelector).Normalize(tSel)
    Do $$$AssertTrue(tNorm.%IsDefined("$and"), "Multi-field selector normalized to $and")
    Set tAndArr = tNorm.%Get("$and")
    Do $$$AssertTrue($IsObject(tAndArr), "$and value is array")
    Do $$$AssertEquals(tAndArr.%Size(), 2, "$and has 2 elements")
}

/// <p>Test nested field path normalization to dot-notation.</p>
Method TestNormalizeNestedField()
{
    Set tSel = ##class(%DynamicObject).%FromJSON("{""foo"":{""bar"":{""$gt"":10}}}")
    Set tNorm = ##class(IRISCouch.Query.MangoSelector).Normalize(tSel)
    ; Should flatten to {"foo.bar":{"$gt":10}}
    Do $$$AssertTrue(tNorm.%IsDefined("foo.bar"), "Nested field flattened to dot-notation")
    Set tCond = tNorm.%Get("foo.bar")
    Do $$$AssertTrue($IsObject(tCond), "Condition is object")
    Do $$$AssertEquals(tCond.%Get("$gt"), 10, "Operator preserved after flattening")
}

/// <p>Test $eq operator.</p>
Method TestEq()
{
    Set tDoc = {"type":"order","total":100}
    Set tSel = ##class(IRISCouch.Query.MangoSelector).Normalize({"type":"order"})
    Do $$$AssertTrue(##class(IRISCouch.Query.MangoSelector).Match(tSel, tDoc), "$eq matches equal value")
    Set tSel2 = ##class(IRISCouch.Query.MangoSelector).Normalize({"type":"invoice"})
    Do $$$AssertTrue('##class(IRISCouch.Query.MangoSelector).Match(tSel2, tDoc), "$eq rejects different value")
}

/// <p>Test $ne operator.</p>
Method TestNe()
{
    Set tDoc = {"type":"order"}
    Set tSel = {"type":{"$ne":"invoice"}}
    Do $$$AssertTrue(##class(IRISCouch.Query.MangoSelector).Match(tSel, tDoc), "$ne matches when different")
    Set tSel2 = {"type":{"$ne":"order"}}
    Do $$$AssertTrue('##class(IRISCouch.Query.MangoSelector).Match(tSel2, tDoc), "$ne rejects when equal")
}

/// <p>Test $gt operator.</p>
Method TestGt()
{
    Set tDoc = {"age":30}
    Set tSel = {"age":{"$gt":25}}
    Do $$$AssertTrue(##class(IRISCouch.Query.MangoSelector).Match(tSel, tDoc), "$gt matches 30 > 25")
    Set tSel2 = {"age":{"$gt":30}}
    Do $$$AssertTrue('##class(IRISCouch.Query.MangoSelector).Match(tSel2, tDoc), "$gt rejects 30 > 30")
}

/// <p>Test $gte operator.</p>
Method TestGte()
{
    Set tDoc = {"age":30}
    Set tSel = {"age":{"$gte":30}}
    Do $$$AssertTrue(##class(IRISCouch.Query.MangoSelector).Match(tSel, tDoc), "$gte matches 30 >= 30")
    Set tSel2 = {"age":{"$gte":31}}
    Do $$$AssertTrue('##class(IRISCouch.Query.MangoSelector).Match(tSel2, tDoc), "$gte rejects 30 >= 31")
}

/// <p>Test $lt operator.</p>
Method TestLt()
{
    Set tDoc = {"age":20}
    Set tSel = {"age":{"$lt":25}}
    Do $$$AssertTrue(##class(IRISCouch.Query.MangoSelector).Match(tSel, tDoc), "$lt matches 20 < 25")
    Set tSel2 = {"age":{"$lt":20}}
    Do $$$AssertTrue('##class(IRISCouch.Query.MangoSelector).Match(tSel2, tDoc), "$lt rejects 20 < 20")
}

/// <p>Test $lte operator.</p>
Method TestLte()
{
    Set tDoc = {"age":20}
    Set tSel = {"age":{"$lte":20}}
    Do $$$AssertTrue(##class(IRISCouch.Query.MangoSelector).Match(tSel, tDoc), "$lte matches 20 <= 20")
    Set tSel2 = {"age":{"$lte":19}}
    Do $$$AssertTrue('##class(IRISCouch.Query.MangoSelector).Match(tSel2, tDoc), "$lte rejects 20 <= 19")
}

/// <p>Test $in operator.</p>
Method TestIn()
{
    Set tDoc = {"status":"active"}
    Set tSel = {"status":{"$in":["active","pending"]}}
    Do $$$AssertTrue(##class(IRISCouch.Query.MangoSelector).Match(tSel, tDoc), "$in matches value in array")
    Set tSel2 = {"status":{"$in":["closed","archived"]}}
    Do $$$AssertTrue('##class(IRISCouch.Query.MangoSelector).Match(tSel2, tDoc), "$in rejects value not in array")
}

/// <p>Test $nin operator.</p>
Method TestNin()
{
    Set tDoc = {"status":"active"}
    Set tSel = {"status":{"$nin":["closed","archived"]}}
    Do $$$AssertTrue(##class(IRISCouch.Query.MangoSelector).Match(tSel, tDoc), "$nin matches value not in array")
    Set tSel2 = {"status":{"$nin":["active","pending"]}}
    Do $$$AssertTrue('##class(IRISCouch.Query.MangoSelector).Match(tSel2, tDoc), "$nin rejects value in array")
}

/// <p>Test $exists with true.</p>
Method TestExists()
{
    Set tDoc = {"name":"Alice","age":30}
    Set tSel = {"name":{"$exists":true}}
    Do $$$AssertTrue(##class(IRISCouch.Query.MangoSelector).Match(tSel, tDoc), "$exists true matches existing field")
    Set tSel2 = {"email":{"$exists":true}}
    Do $$$AssertTrue('##class(IRISCouch.Query.MangoSelector).Match(tSel2, tDoc), "$exists true rejects missing field")
}

/// <p>Test $exists with false.</p>
Method TestExistsFalse()
{
    Set tDoc = {"name":"Alice"}
    Set tSel = {"email":{"$exists":false}}
    Do $$$AssertTrue(##class(IRISCouch.Query.MangoSelector).Match(tSel, tDoc), "$exists false matches missing field")
    Set tSel2 = {"name":{"$exists":false}}
    Do $$$AssertTrue('##class(IRISCouch.Query.MangoSelector).Match(tSel2, tDoc), "$exists false rejects existing field")
}

/// <p>Test $type operator.</p>
Method TestType()
{
    Set tDoc = {"name":"Alice","age":30}
    Set tSel = {"name":{"$type":"string"}}
    Do $$$AssertTrue(##class(IRISCouch.Query.MangoSelector).Match(tSel, tDoc), "$type string matches string field")
    Set tSel2 = {"age":{"$type":"number"}}
    Do $$$AssertTrue(##class(IRISCouch.Query.MangoSelector).Match(tSel2, tDoc), "$type number matches numeric field")
    Set tSel3 = {"name":{"$type":"number"}}
    Do $$$AssertTrue('##class(IRISCouch.Query.MangoSelector).Match(tSel3, tDoc), "$type number rejects string field")
}

/// <p>Test $regex operator.</p>
Method TestRegex()
{
    Set tDoc = {"email":"alice@example.com"}
    Set tSel = {"email":{"$regex":"^alice"}}
    Do $$$AssertTrue(##class(IRISCouch.Query.MangoSelector).Match(tSel, tDoc), "$regex matches pattern")
    Set tSel2 = {"email":{"$regex":"^bob"}}
    Do $$$AssertTrue('##class(IRISCouch.Query.MangoSelector).Match(tSel2, tDoc), "$regex rejects non-matching pattern")
}

/// <p>Test $and operator.</p>
Method TestAnd()
{
    Set tDoc = {"type":"order","status":"active"}
    Set tSel = {"$and":[{"type":{"$eq":"order"}},{"status":{"$eq":"active"}}]}
    Do $$$AssertTrue(##class(IRISCouch.Query.MangoSelector).Match(tSel, tDoc), "$and matches when all conditions true")
    Set tSel2 = {"$and":[{"type":{"$eq":"order"}},{"status":{"$eq":"closed"}}]}
    Do $$$AssertTrue('##class(IRISCouch.Query.MangoSelector).Match(tSel2, tDoc), "$and rejects when one condition false")
}

/// <p>Test $or operator.</p>
Method TestOr()
{
    Set tDoc = {"type":"order"}
    Set tSel = {"$or":[{"type":{"$eq":"order"}},{"type":{"$eq":"invoice"}}]}
    Do $$$AssertTrue(##class(IRISCouch.Query.MangoSelector).Match(tSel, tDoc), "$or matches when one condition true")
    Set tSel2 = {"$or":[{"type":{"$eq":"invoice"}},{"type":{"$eq":"receipt"}}]}
    Do $$$AssertTrue('##class(IRISCouch.Query.MangoSelector).Match(tSel2, tDoc), "$or rejects when all false")
}

/// <p>Test $nor operator.</p>
Method TestNor()
{
    Set tDoc = {"type":"order"}
    Set tSel = {"$nor":[{"type":{"$eq":"invoice"}},{"type":{"$eq":"receipt"}}]}
    Do $$$AssertTrue(##class(IRISCouch.Query.MangoSelector).Match(tSel, tDoc), "$nor matches when none true")
    Set tSel2 = {"$nor":[{"type":{"$eq":"order"}},{"type":{"$eq":"invoice"}}]}
    Do $$$AssertTrue('##class(IRISCouch.Query.MangoSelector).Match(tSel2, tDoc), "$nor rejects when one true")
}

/// <p>Test $not operator.</p>
Method TestNot()
{
    Set tDoc = {"type":"order"}
    Set tSel = {"$not":{"type":{"$eq":"invoice"}}}
    Do $$$AssertTrue(##class(IRISCouch.Query.MangoSelector).Match(tSel, tDoc), "$not matches when inner false")
    Set tSel2 = {"$not":{"type":{"$eq":"order"}}}
    Do $$$AssertTrue('##class(IRISCouch.Query.MangoSelector).Match(tSel2, tDoc), "$not rejects when inner true")
}

/// <p>Test $elemMatch operator.</p>
Method TestElemMatch()
{
    Set tDoc = ##class(%DynamicObject).%FromJSON("{""items"":[{""name"":""apple"",""qty"":5},{""name"":""banana"",""qty"":10}]}")
    Set tSel = {"items":{"$elemMatch":{"name":{"$eq":"apple"}}}}
    Do $$$AssertTrue(##class(IRISCouch.Query.MangoSelector).Match(tSel, tDoc), "$elemMatch matches element")
    Set tSel2 = {"items":{"$elemMatch":{"name":{"$eq":"cherry"}}}}
    Do $$$AssertTrue('##class(IRISCouch.Query.MangoSelector).Match(tSel2, tDoc), "$elemMatch rejects when no element matches")
}

/// <p>Test $allMatch operator.</p>
Method TestAllMatch()
{
    Set tDoc = ##class(%DynamicObject).%FromJSON("{""items"":[{""qty"":5},{""qty"":10}]}")
    Set tSel = {"items":{"$allMatch":{"qty":{"$gt":0}}}}
    Do $$$AssertTrue(##class(IRISCouch.Query.MangoSelector).Match(tSel, tDoc), "$allMatch matches when all elements match")
    Set tSel2 = {"items":{"$allMatch":{"qty":{"$gt":7}}}}
    Do $$$AssertTrue('##class(IRISCouch.Query.MangoSelector).Match(tSel2, tDoc), "$allMatch rejects when not all match")
}

/// <p>Test $mod operator.</p>
Method TestMod()
{
    Set tDoc = {"value":10}
    Set tSel = {"value":{"$mod":[3,1]}}
    Do $$$AssertTrue(##class(IRISCouch.Query.MangoSelector).Match(tSel, tDoc), "$mod matches 10 % 3 == 1")
    Set tSel2 = {"value":{"$mod":[3,0]}}
    Do $$$AssertTrue('##class(IRISCouch.Query.MangoSelector).Match(tSel2, tDoc), "$mod rejects 10 % 3 != 0")
}

/// <p>Test $size operator.</p>
Method TestSize()
{
    Set tDoc = {"tags":["red","blue","green"]}
    Set tSel = {"tags":{"$size":3}}
    Do $$$AssertTrue(##class(IRISCouch.Query.MangoSelector).Match(tSel, tDoc), "$size matches array with 3 elements")
    Set tSel2 = {"tags":{"$size":2}}
    Do $$$AssertTrue('##class(IRISCouch.Query.MangoSelector).Match(tSel2, tDoc), "$size rejects wrong size")
}

/// <p>Test $all operator.</p>
Method TestAll()
{
    Set tDoc = {"tags":["red","blue","green"]}
    Set tSel = {"tags":{"$all":["red","blue"]}}
    Do $$$AssertTrue(##class(IRISCouch.Query.MangoSelector).Match(tSel, tDoc), "$all matches when all values present")
    Set tSel2 = {"tags":{"$all":["red","yellow"]}}
    Do $$$AssertTrue('##class(IRISCouch.Query.MangoSelector).Match(tSel2, tDoc), "$all rejects when not all present")
}

/// <p>Test cross-type comparison: number lt string.</p>
Method TestCompareNumberLtString()
{
    Set tCmp = ##class(IRISCouch.Query.MangoSelector).CompareValues(42, "hello")
    Do $$$AssertTrue(tCmp < 0, "Number is less than string in CouchDB ordering")
}

/// <p>Test empty selector matches all documents.</p>
Method TestEmptySelectorMatchesAll()
{
    Set tDoc = {"type":"order","name":"Test"}
    Set tSel = {}
    Do $$$AssertTrue(##class(IRISCouch.Query.MangoSelector).Match(tSel, tDoc), "Empty selector matches any document")
}

/// <p>Test missing field returns false for most operators.</p>
Method TestMissingFieldReturnsFalse()
{
    Set tDoc = {"name":"Alice"}
    Set tSel = {"email":{"$eq":"alice@test.com"}}
    Do $$$AssertTrue('##class(IRISCouch.Query.MangoSelector).Match(tSel, tDoc), "Missing field returns false for $eq")
}

/// <p>Test dot-notation nested field access.</p>
Method TestDotNotationNestedAccess()
{
    Set tDoc = ##class(%DynamicObject).%FromJSON("{""address"":{""city"":""NYC""}}")
    Set tSel = {"address.city":{"$eq":"NYC"}}
    Do $$$AssertTrue(##class(IRISCouch.Query.MangoSelector).Match(tSel, tDoc), "Dot-notation accesses nested field")
}

/// <p>Test array field implicit contains for bare value equality.</p>
Method TestArrayFieldContainsValue()
{
    Set tDoc = {"tags":["red","blue","green"]}
    Set tSel = ##class(IRISCouch.Query.MangoSelector).Normalize({"tags":"red"})
    Do $$$AssertTrue(##class(IRISCouch.Query.MangoSelector).Match(tSel, tDoc), "Array field contains value matches via implicit $eq")
    Set tSel2 = ##class(IRISCouch.Query.MangoSelector).Normalize({"tags":"yellow"})
    Do $$$AssertTrue('##class(IRISCouch.Query.MangoSelector).Match(tSel2, tDoc), "Array field does not contain value rejects")
}

}
