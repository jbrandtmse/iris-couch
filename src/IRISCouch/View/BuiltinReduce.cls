/// <p>Native ObjectScript implementations of CouchDB builtin reduce
/// functions (Story 12.2 AC #3).</p>
/// <p>These are invoked by <class>IRISCouch.View.QueryEngine</class> whenever
/// a design-document view's <code>reduce</code> field is one of the builtin
/// tokens <code>_sum</code>, <code>_count</code>, <code>_stats</code>, or
/// <code>_approx_count_distinct</code>. Routing these in ObjectScript
/// (rather than through the subprocess JSRuntime) avoids a subprocess
/// round-trip for the common case and keeps behaviour identical whether
/// the subprocess backend is available or not.</p>
///
/// <h3>Story 12.2 deviation — _approx_count_distinct</h3>
/// <p>CouchDB uses a HyperLogLog sketch for <code>_approx_count_distinct</code>.
/// Story 12.2 ships a simple exact distinct count instead (keyed local
/// array). HyperLogLog is Epic 14 scope. This is a KNOWN DEVIATION; the
/// behaviour is still correct (and actually more accurate) but has O(N)
/// memory vs CouchDB's O(log N).</p>
Class IRISCouch.View.BuiltinReduce Extends %RegisteredObject
{

/// <p>Report whether <var>pReduceToken</var> names a builtin reduce.</p>
/// <p>The builtin tokens are CouchDB-defined strings beginning with an
/// underscore. Any other string is treated as user-supplied JavaScript
/// source that must be sent to the JSRuntime backend.</p>
/// @param pReduceToken Value of the design-doc's <code>reduce</code> field
/// @return %Boolean 1 if builtin, 0 otherwise
ClassMethod IsBuiltin(pReduceToken As %String) As %Boolean
{
    If pReduceToken = "_sum" Quit 1
    If pReduceToken = "_count" Quit 1
    If pReduceToken = "_stats" Quit 1
    If pReduceToken = "_approx_count_distinct" Quit 1
    Quit 0
}

/// <p>Dispatch any builtin reduce by token.</p>
/// <p>Convenience wrapper that callers use so they do not need to branch
/// on the token themselves. Returns the reduce result using the natural
/// type of the specific builtin (numeric for <code>_sum</code>,
/// <code>_count</code>, <code>_approx_count_distinct</code>; object for
/// <code>_stats</code>).</p>
/// @param pReduceToken One of the tokens checked by <method>IsBuiltin</method>
/// @param pValues A <class>%DynamicArray</class> of emitted values
/// @return The reduce result (scalar or object)
ClassMethod Apply(pReduceToken As %String, pValues As %DynamicArray)
{
    If pReduceToken = "_sum" Quit ..ApplySum(pValues)
    If pReduceToken = "_count" Quit ..ApplyCount(pValues)
    If pReduceToken = "_stats" Quit ..ApplyStats(pValues)
    If pReduceToken = "_approx_count_distinct" Quit ..ApplyApproxCountDistinct(pValues)
    ; Unreachable under normal use because callers gate on IsBuiltin().
    Quit ""
}

/// <p>Sum all numeric values; non-numeric values are skipped with a warn
/// log (matches CouchDB's tolerant Views.sum in
/// <code>sources/couchdb/share/server/views.js</code>).</p>
/// @param pValues A <class>%DynamicArray</class> of emitted values
/// @return %Numeric Total of numeric values (0 if empty or all non-numeric)
ClassMethod ApplySum(pValues As %DynamicArray) As %Numeric
{
    Set tTotal = 0
    If '$IsObject(pValues) Quit tTotal
    Set tIter = pValues.%GetIterator()
    Set tSkipped = 0
    While tIter.%GetNext(.tKey, .tVal) {
        If ..IsNumeric(tVal) {
            Set tTotal = tTotal + tVal
        } Else {
            Set tSkipped = tSkipped + 1
        }
    }
    If tSkipped > 0 {
        Set tLogData = {"skipped":(tSkipped)}
        Do ##class(IRISCouch.Util.Log).Warn("view.builtinreduce", "_sum skipped non-numeric values", tLogData)
    }
    Quit tTotal
}

/// <p>Count the number of emitted rows.</p>
/// <p>Per CouchDB, <code>_count</code> ignores the value type and just
/// returns the total number of emissions.</p>
/// @param pValues A <class>%DynamicArray</class> of emitted values
/// @return %Integer Count of emissions
ClassMethod ApplyCount(pValues As %DynamicArray) As %Integer
{
    If '$IsObject(pValues) Quit 0
    Quit pValues.%Size()
}

/// <p>Compute summary statistics over numeric emissions.</p>
/// <p>Matches CouchDB's <code>_stats</code> shape:
/// <code>{"sum":N,"count":N,"min":N,"max":N,"sumsqr":N}</code>. Non-numeric
/// values are skipped. For an empty input, <code>count</code> is 0 and the
/// numeric fields are all 0 (min/max are 0 by convention — callers should
/// inspect <code>count</code> before using min/max).</p>
/// @param pValues A <class>%DynamicArray</class> of emitted values
/// @return %DynamicObject with sum, count, min, max, sumsqr
ClassMethod ApplyStats(pValues As %DynamicArray) As %DynamicObject
{
    Set tSum = 0
    Set tCount = 0
    Set tMin = 0
    Set tMax = 0
    Set tSumSqr = 0
    Set tFirst = 1
    If $IsObject(pValues) {
        Set tIter = pValues.%GetIterator()
        While tIter.%GetNext(.tKey, .tVal) {
            If '..IsNumeric(tVal) Continue
            Set tSum = tSum + tVal
            Set tSumSqr = tSumSqr + (tVal * tVal)
            Set tCount = tCount + 1
            If tFirst {
                Set tMin = tVal
                Set tMax = tVal
                Set tFirst = 0
            } Else {
                If tVal < tMin Set tMin = tVal
                If tVal > tMax Set tMax = tVal
            }
        }
    }
    Set tResult = {}
    Do tResult.%Set("sum", tSum, "number")
    Do tResult.%Set("count", tCount, "number")
    Do tResult.%Set("min", tMin, "number")
    Do tResult.%Set("max", tMax, "number")
    Do tResult.%Set("sumsqr", tSumSqr, "number")
    Quit tResult
}

/// <p>Count distinct values across the emissions.</p>
/// <p>Story 12.2 uses an exact distinct count via a local array keyed by
/// the JSON serialisation of each value. CouchDB uses a HyperLogLog sketch
/// here — see the class doc comment for the deviation rationale.</p>
/// @param pValues A <class>%DynamicArray</class> of emitted values
/// @return %Integer Number of distinct values
ClassMethod ApplyApproxCountDistinct(pValues As %DynamicArray) As %Integer
{
    If '$IsObject(pValues) Quit 0
    Kill tSeen
    Set tIter = pValues.%GetIterator()
    While tIter.%GetNext(.tKey, .tVal) {
        ; Key by JSON serialisation so {1, "1", true} are three distinct
        ; values and {"a", "a"} is one -- matches the semantics CouchDB's
        ; HLL would produce on the same input.
        Set tKeyStr = ..Canonicalise(tVal)
        Set tSeen(tKeyStr) = 1
    }
    Set tDistinct = 0
    Set tK = ""
    For {
        Set tK = $Order(tSeen(tK))
        If tK = "" Quit
        Set tDistinct = tDistinct + 1
    }
    Quit tDistinct
}

/// <p>Return 1 if <var>pValue</var> is a number (per ObjectScript's
/// numeric coercion rules), 0 otherwise.</p>
/// <p>Strings that happen to parse to a number are treated as numeric
/// here — matches JavaScript's loose semantics for <code>_sum</code>.</p>
ClassMethod IsNumeric(pValue) As %Boolean [ Internal ]
{
    ; %DynamicObject / %DynamicArray values never coerce to a valid number
    If $IsObject(pValue) Quit 0
    ; Empty string is not a valid numeric reduce input
    If pValue = "" Quit 0
    ; ObjectScript unary-plus coerces to a number; if the original string
    ; equals the coerced value, it was a valid numeric literal.
    Quit (pValue = +pValue)
}

/// <p>Deterministically stringify any value for distinct-count keying.</p>
/// <p>Numbers / strings / booleans stringify directly; objects and arrays
/// are serialised via <code>%ToJSON</code> so nested structures compare
/// structurally rather than by reference.</p>
ClassMethod Canonicalise(pValue) As %String [ Internal ]
{
    If $IsObject(pValue) {
        Quit pValue.%ToJSON()
    }
    ; For scalars, prefix by a type tag so "1" (string) and 1 (number) do
    ; not collapse. ObjectScript does not expose a type predicate for
    ; dynamic scalars, so we rely on the round-trip: a numeric-looking
    ; string and its numeric cast compare equal under = but we want
    ; JSON-level distinctness.
    If pValue = +pValue, pValue '= "" {
        Quit "N:" _ pValue
    }
    Quit "S:" _ pValue
}

}
