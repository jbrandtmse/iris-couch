/// <p>Unit tests for <class>IRISCouch.View.BuiltinReduce</class> (Story 12.2
/// Task 4).</p>
/// <p>Does not require a JS interpreter — all assertions exercise
/// ObjectScript logic. This suite is the baseline that must pass on any
/// CI environment regardless of Node availability.</p>
Class IRISCouch.Test.BuiltinReduceTest Extends %UnitTest.TestCase
{

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Quit $$$OK
}

/// AC #3: IsBuiltin returns true for the four documented tokens and false
/// for everything else.
Method TestIsBuiltinRecognisesAllTokens()
{
    Do $$$AssertTrue(##class(IRISCouch.View.BuiltinReduce).IsBuiltin("_sum"), "_sum recognised")
    Do $$$AssertTrue(##class(IRISCouch.View.BuiltinReduce).IsBuiltin("_count"), "_count recognised")
    Do $$$AssertTrue(##class(IRISCouch.View.BuiltinReduce).IsBuiltin("_stats"), "_stats recognised")
    Do $$$AssertTrue(##class(IRISCouch.View.BuiltinReduce).IsBuiltin("_approx_count_distinct"), "_approx_count_distinct recognised")
    Do $$$AssertTrue('##class(IRISCouch.View.BuiltinReduce).IsBuiltin(""), "empty token is not a builtin")
    Do $$$AssertTrue('##class(IRISCouch.View.BuiltinReduce).IsBuiltin("function(k,v,r){return 0;}"), "js source is not a builtin")
    Do $$$AssertTrue('##class(IRISCouch.View.BuiltinReduce).IsBuiltin("_sumx"), "garbage underscore token is not a builtin")
}

/// AC #3: _sum over numeric values.
Method TestSumNumericValues()
{
    Set tVals = [1, 2, 3, 4]
    Do $$$AssertEquals(##class(IRISCouch.View.BuiltinReduce).ApplySum(tVals), 10, "_sum of [1,2,3,4] = 10")
}

/// AC #3: _sum of empty input is 0, not null.
Method TestSumEmptyIsZero()
{
    Set tVals = []
    Do $$$AssertEquals(##class(IRISCouch.View.BuiltinReduce).ApplySum(tVals), 0, "_sum of [] = 0")
}

/// AC #3: _sum tolerates mixed-type input by skipping non-numeric values.
Method TestSumMixedSkipsNonNumeric()
{
    Set tVals = [1, "abc", 2, "", 3]
    Do $$$AssertEquals(##class(IRISCouch.View.BuiltinReduce).ApplySum(tVals), 6, "_sum skips non-numeric, = 6")
}

/// AC #3: _sum handles a single-value input.
Method TestSumSingleValue()
{
    Set tVals = [42]
    Do $$$AssertEquals(##class(IRISCouch.View.BuiltinReduce).ApplySum(tVals), 42, "_sum of [42] = 42")
}

/// AC #3: _count returns %Size() of the input array.
Method TestCountReturnsSize()
{
    Do $$$AssertEquals(##class(IRISCouch.View.BuiltinReduce).ApplyCount([]), 0, "_count of [] = 0")
    Do $$$AssertEquals(##class(IRISCouch.View.BuiltinReduce).ApplyCount([1, 2, 3]), 3, "_count of [1,2,3] = 3")
    Do $$$AssertEquals(##class(IRISCouch.View.BuiltinReduce).ApplyCount(["a", {}, 7, "b"]), 4, "_count ignores type, = 4")
}

/// AC #3: _stats produces the expected envelope with all five fields.
Method TestStatsShapeAndValues()
{
    Set tVals = [1, 2, 3, 4]
    Set tResult = ##class(IRISCouch.View.BuiltinReduce).ApplyStats(tVals)
    Do $$$AssertTrue($IsObject(tResult), "_stats returns an object")
    Do $$$AssertEquals(tResult.sum, 10, "_stats.sum = 10")
    Do $$$AssertEquals(tResult.count, 4, "_stats.count = 4")
    Do $$$AssertEquals(tResult.min, 1, "_stats.min = 1")
    Do $$$AssertEquals(tResult.max, 4, "_stats.max = 4")
    Do $$$AssertEquals(tResult.sumsqr, 30, "_stats.sumsqr = 1+4+9+16 = 30")
}

/// AC #3: _stats on empty input returns zero-count envelope.
Method TestStatsEmpty()
{
    Set tResult = ##class(IRISCouch.View.BuiltinReduce).ApplyStats([])
    Do $$$AssertEquals(tResult.count, 0, "_stats.count of [] = 0")
    Do $$$AssertEquals(tResult.sum, 0, "_stats.sum of [] = 0")
    Do $$$AssertEquals(tResult.sumsqr, 0, "_stats.sumsqr of [] = 0")
}

/// AC #3: _stats on a single value has min=max=sum=value and count=1.
Method TestStatsSingleValue()
{
    Set tResult = ##class(IRISCouch.View.BuiltinReduce).ApplyStats([5])
    Do $$$AssertEquals(tResult.count, 1, "_stats.count = 1")
    Do $$$AssertEquals(tResult.sum, 5, "_stats.sum = 5")
    Do $$$AssertEquals(tResult.min, 5, "_stats.min = 5")
    Do $$$AssertEquals(tResult.max, 5, "_stats.max = 5")
    Do $$$AssertEquals(tResult.sumsqr, 25, "_stats.sumsqr = 25")
}

/// AC #3: _approx_count_distinct returns exact distinct count (Story 12.2
/// deviation — documented in class doc comment).
Method TestApproxCountDistinctBasic()
{
    Do $$$AssertEquals(##class(IRISCouch.View.BuiltinReduce).ApplyApproxCountDistinct([]), 0, "distinct of [] = 0")
    Do $$$AssertEquals(##class(IRISCouch.View.BuiltinReduce).ApplyApproxCountDistinct([1]), 1, "distinct of [1] = 1")
    Do $$$AssertEquals(##class(IRISCouch.View.BuiltinReduce).ApplyApproxCountDistinct([1, 2, 3]), 3, "distinct of [1,2,3] = 3")
    Do $$$AssertEquals(##class(IRISCouch.View.BuiltinReduce).ApplyApproxCountDistinct([1, 1, 1]), 1, "distinct of [1,1,1] = 1")
    Do $$$AssertEquals(##class(IRISCouch.View.BuiltinReduce).ApplyApproxCountDistinct([1, 2, 1, 2, 3]), 3, "distinct of [1,2,1,2,3] = 3")
}

/// AC #3: _approx_count_distinct distinguishes distinct string values.
/// <p>Note: ObjectScript's %DynamicArray collapses a string that parses
/// as a number (e.g., <code>"1"</code>) to the numeric value, so
/// distinct([1, "1"]) is 1 in this runtime. The real-world case we want
/// to cover is distinct non-numeric strings.</p>
Method TestApproxCountDistinctDistinguishesTypes()
{
    Do $$$AssertEquals(##class(IRISCouch.View.BuiltinReduce).ApplyApproxCountDistinct(["alice", "bob", "alice"]), 2, "distinct of alice/bob/alice = 2")
    Do $$$AssertEquals(##class(IRISCouch.View.BuiltinReduce).ApplyApproxCountDistinct(["alice", "bob", "carol", "dave"]), 4, "distinct of 4 distinct strings = 4")
}

/// AC #3: Apply() dispatches to the right builtin by token.
Method TestApplyDispatches()
{
    Set tSum = ##class(IRISCouch.View.BuiltinReduce).Apply("_sum", [1, 2, 3])
    Do $$$AssertEquals(tSum, 6, "Apply(_sum) = 6")
    Set tCount = ##class(IRISCouch.View.BuiltinReduce).Apply("_count", [1, 2, 3])
    Do $$$AssertEquals(tCount, 3, "Apply(_count) = 3")
    Set tStats = ##class(IRISCouch.View.BuiltinReduce).Apply("_stats", [1, 2, 3])
    Do $$$AssertEquals(tStats.sum, 6, "Apply(_stats).sum = 6")
    Set tDistinct = ##class(IRISCouch.View.BuiltinReduce).Apply("_approx_count_distinct", [1, 1, 2])
    Do $$$AssertEquals(tDistinct, 2, "Apply(_approx_count_distinct) = 2")
}

}
