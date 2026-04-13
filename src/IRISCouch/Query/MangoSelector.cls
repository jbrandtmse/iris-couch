/// <p>Mango selector normalization and matching engine.</p>
/// <p>Implements the full CouchDB Mango query selector specification including
/// normalization of implicit operators and evaluation of all 18+ selector operators
/// against document bodies. Follows CouchDB type ordering for cross-type comparisons.</p>
Class IRISCouch.Query.MangoSelector Extends %RegisteredObject
{

/// <p>Normalize a selector into canonical form.</p>
/// <p>Step 1: Convert bare values to <code>{"$eq": value}</code>.<br/>
/// Step 2: Convert multi-field top-level to implicit <code>$and</code>.<br/>
/// Step 3: Flatten nested field paths to dot-notation.</p>
/// @param pSelector The raw selector as %DynamicObject
/// @return %DynamicObject The normalized selector
ClassMethod Normalize(pSelector As %DynamicObject) As %DynamicObject
{
    Set tResult = ""
    Try {
        If '$IsObject(pSelector) {
            Set tResult = {}
            Quit
        }
        ; Step 1: Collect all top-level keys
        Set tIter = pSelector.%GetIterator()
        Set tKeys = []
        While tIter.%GetNext(.tKey, .tVal) {
            Do tKeys.%Push(tKey)
        }
        ; If empty selector, return as-is
        If tKeys.%Size() = 0 {
            Set tResult = {}
            Quit
        }
        ; Count non-operator fields vs operator fields
        Set tFieldCount = 0
        Set tOpCount = 0
        For tI = 0:1:(tKeys.%Size() - 1) {
            Set tKey = tKeys.%Get(tI)
            If $Extract(tKey, 1) = "$" {
                Set tOpCount = tOpCount + 1
            } Else {
                Set tFieldCount = tFieldCount + 1
            }
        }
        ; Step 2: Multi-field top-level → implicit $and
        If (tFieldCount > 1) || ((tFieldCount > 0) && (tOpCount > 0)) {
            Set tAndArr = []
            For tI = 0:1:(tKeys.%Size() - 1) {
                Set tKey = tKeys.%Get(tI)
                Set tVal = pSelector.%Get(tKey)
                Set tSub = {}
                If $IsObject(tVal) {
                    Do tSub.%Set(tKey, tVal)
                } Else {
                    Do tSub.%Set(tKey, ..NormalizeFieldValue(pSelector, tKey))
                }
                Do tAndArr.%Push(..Normalize(tSub))
            }
            Set tResult = {}
            Do tResult.%Set("$and", tAndArr)
            Quit
        }
        ; Single key
        Set tKey = tKeys.%Get(0)
        Set tVal = pSelector.%Get(tKey)
        ; Handle logical operators
        If tKey = "$and" || (tKey = "$or") || (tKey = "$nor") {
            If $IsObject(tVal) && tVal.%IsA("%DynamicArray") {
                Set tNewArr = []
                For tI = 0:1:(tVal.%Size() - 1) {
                    Do tNewArr.%Push(..Normalize(tVal.%Get(tI)))
                }
                Set tResult = {}
                Do tResult.%Set(tKey, tNewArr)
                Quit
            }
            Set tResult = pSelector
            Quit
        }
        If tKey = "$not" {
            Set tResult = {}
            If $IsObject(tVal) {
                Do tResult.%Set("$not", ..Normalize(tVal))
            } Else {
                Do tResult.%Set("$not", tVal)
            }
            Quit
        }
        ; Field key - normalize the value
        If $Extract(tKey, 1) '= "$" {
            Set tResult = ..NormalizeField(tKey, tVal, pSelector)
            Quit
        }
        ; Fallback
        Set tResult = pSelector
        Quit
    }
    Catch ex {
        If '$IsObject(tResult) Set tResult = {}
        Quit
    }
    Quit tResult
}

/// <p>Normalize a field value, handling nested objects and bare values.</p>
/// @param pField The field name
/// @param pValue The field value from the selector
/// @param pParent The parent object (for type detection)
/// @return %DynamicObject Normalized field condition
ClassMethod NormalizeField(pField As %String, pValue, pParent As %DynamicObject) As %DynamicObject
{
    Set tResult = {}
    Try {
        ; Check if pValue is an object with operator keys
        If $IsObject(pValue) && pValue.%IsA("%DynamicObject") {
            ; Check if it has operator keys or is a nested object path
            Set tHasOps = 0
            Set tHasFields = 0
            Set tVIter = pValue.%GetIterator()
            While tVIter.%GetNext(.tVK, .tVV) {
                If $Extract(tVK, 1) = "$" {
                    Set tHasOps = 1
                } Else {
                    Set tHasFields = 1
                }
            }
            If tHasOps && 'tHasFields {
                ; Object with operator keys like {"$gt": 10, "$lt": 20}
                ; Wrap the operators under this field
                Do tResult.%Set(pField, pValue)
                Quit
            }
            If tHasFields && 'tHasOps {
                ; Nested field path: {"foo": {"bar": {"$gt": 10}}} → {"foo.bar": {"$gt": 10}}
                Set tVIter2 = pValue.%GetIterator()
                While tVIter2.%GetNext(.tVK2, .tVV2) {
                    Set tNestedPath = pField _ "." _ tVK2
                    Set tSub = ..NormalizeField(tNestedPath, tVV2, pValue)
                    ; Merge keys from tSub into tResult
                    Set tSubIter = tSub.%GetIterator()
                    While tSubIter.%GetNext(.tSK, .tSV) {
                        Do tResult.%Set(tSK, tSV)
                    }
                }
                ; If result has multiple keys, wrap in $and
                Set tRIter = tResult.%GetIterator()
                Set tRCount = 0
                While tRIter.%GetNext(.tRK) {
                    Set tRCount = tRCount + 1
                }
                If tRCount > 1 {
                    Set tAndArr = []
                    Set tR2Iter = tResult.%GetIterator()
                    While tR2Iter.%GetNext(.tR2K, .tR2V) {
                        Set tSub2 = {}
                        Do tSub2.%Set(tR2K, tR2V)
                        Do tAndArr.%Push(tSub2)
                    }
                    Set tResult = {}
                    Do tResult.%Set("$and", tAndArr)
                }
                Quit
            }
            ; Mixed or array value — treat as equality
            Set tEqObj = {}
            Do tEqObj.%Set("$eq", pValue)
            Do tResult.%Set(pField, tEqObj)
            Quit
        }
        ; Bare value — convert to $eq
        Set tEqObj = {}
        Set tType = pParent.%GetTypeOf(pField)
        If tType = "null" {
            Do tEqObj.%Set("$eq", "null", "null")
        } ElseIf tType = "boolean" {
            Do tEqObj.%Set("$eq", pValue, "boolean")
        } ElseIf tType = "number" {
            Do tEqObj.%Set("$eq", pValue, "number")
        } Else {
            Do tEqObj.%Set("$eq", pValue)
        }
        Do tResult.%Set(pField, tEqObj)
        Quit
    }
    Catch ex {
        Quit
    }
    Quit tResult
}

/// <p>Get the normalized field value preserving JSON type.</p>
ClassMethod NormalizeFieldValue(pParent As %DynamicObject, pKey As %String) As %DynamicObject
{
    Set tVal = pParent.%Get(pKey)
    Set tEq = {}
    Set tType = pParent.%GetTypeOf(pKey)
    If tType = "null" {
        Do tEq.%Set("$eq", "null", "null")
    } ElseIf tType = "boolean" {
        Do tEq.%Set("$eq", tVal, "boolean")
    } ElseIf tType = "number" {
        Do tEq.%Set("$eq", tVal, "number")
    } Else {
        Do tEq.%Set("$eq", tVal)
    }
    Quit tEq
}

/// <p>Match a normalized selector against a document.</p>
/// <p>Evaluates the selector tree recursively. Empty selector matches all documents.
/// For each field-condition pair, traverses the document using dot-notation,
/// gets the value, and applies the operator.</p>
/// @param pSelector The normalized selector as %DynamicObject
/// @param pDoc The document body as %DynamicObject
/// @return %Boolean 1 if matches, 0 otherwise
ClassMethod Match(pSelector As %DynamicObject, pDoc As %DynamicObject) As %Boolean
{
    Set tMatch = 1
    Try {
        If '$IsObject(pSelector) {
            Quit
        }
        ; Empty selector matches all
        Set tIter = pSelector.%GetIterator()
        Set tHasKeys = 0
        While tIter.%GetNext(.tKey, .tVal) {
            Set tHasKeys = 1
            ; Handle logical operators
            If tKey = "$and" {
                If $IsObject(tVal) && tVal.%IsA("%DynamicArray") {
                    For tI = 0:1:(tVal.%Size() - 1) {
                        If '..Match(tVal.%Get(tI), pDoc) {
                            Set tMatch = 0
                            Quit
                        }
                    }
                }
                If 'tMatch Quit
                Continue
            }
            If tKey = "$or" {
                If $IsObject(tVal) && tVal.%IsA("%DynamicArray") {
                    Set tAnyMatch = 0
                    For tI = 0:1:(tVal.%Size() - 1) {
                        If ..Match(tVal.%Get(tI), pDoc) {
                            Set tAnyMatch = 1
                            Quit
                        }
                    }
                    If 'tAnyMatch {
                        Set tMatch = 0
                        Quit
                    }
                }
                Continue
            }
            If tKey = "$nor" {
                If $IsObject(tVal) && tVal.%IsA("%DynamicArray") {
                    For tI = 0:1:(tVal.%Size() - 1) {
                        If ..Match(tVal.%Get(tI), pDoc) {
                            Set tMatch = 0
                            Quit
                        }
                    }
                }
                If 'tMatch Quit
                Continue
            }
            If tKey = "$not" {
                If $IsObject(tVal) {
                    If ..Match(tVal, pDoc) {
                        Set tMatch = 0
                        Quit
                    }
                }
                Continue
            }
            ; Field condition: key is a field path, value is operator object
            If $Extract(tKey, 1) '= "$" {
                If '..MatchField(tKey, tVal, pDoc) {
                    Set tMatch = 0
                    Quit
                }
                Continue
            }
        }
        Quit
    }
    Catch ex {
        Set tMatch = 0
        Quit
    }
    Quit tMatch
}

/// <p>Match a field condition against a document.</p>
/// @param pFieldPath The dot-notation field path
/// @param pCondition The operator object (e.g., {"$eq": "value"})
/// @param pDoc The document body
/// @return %Boolean 1 if matches
ClassMethod MatchField(pFieldPath As %String, pCondition, pDoc As %DynamicObject) As %Boolean
{
    Set tMatch = 1
    Try {
        ; Get the field value from the document
        Set tValue = ..GetFieldValue(pDoc, pFieldPath, .tFound)
        Set tValueType = ""
        If tFound {
            Set tValueType = ..InferType(tValue)
        }
        ; If condition is not an object, treat as implicit $eq
        If '$IsObject(pCondition) {
            If 'tFound {
                Set tMatch = 0
                Quit
            }
            ; Check if array field contains the value (CouchDB behavior)
            If $IsObject(tValue) && tValue.%IsA("%DynamicArray") {
                Set tMatch = ..ArrayContains(tValue, pCondition)
                Quit
            }
            Set tMatch = ..OpEq(tValue, pCondition)
            Quit
        }
        ; Iterate operator conditions
        Set tCondIter = pCondition.%GetIterator()
        While tCondIter.%GetNext(.tOp, .tOperand) {
            Set tOpResult = ..EvalOperator(tOp, tValue, tOperand, tFound, tValueType, pCondition, pDoc)
            If 'tOpResult {
                Set tMatch = 0
                Quit
            }
        }
        Quit
    }
    Catch ex {
        Set tMatch = 0
        Quit
    }
    Quit tMatch
}

/// <p>Evaluate a single operator against a value.</p>
ClassMethod EvalOperator(pOp As %String, pValue, pOperand, pFound As %Boolean, pValueType As %String, pCondition As %DynamicObject, pDoc As %DynamicObject) As %Boolean
{
    Set tResult = 1
    Try {
        If pOp = "$eq" {
            If 'pFound { Set tResult = 0 Quit }
            ; Array field contains value check
            If $IsObject(pValue) && pValue.%IsA("%DynamicArray") {
                Set tResult = ..ArrayContains(pValue, pOperand)
                Quit
            }
            Set tResult = ..OpEq(pValue, pOperand)
            Quit
        }
        If pOp = "$ne" {
            ; CouchDB: missing field is not equal to anything, so $ne returns true
            If 'pFound { Set tResult = 1 Quit }
            Set tResult = ..OpNe(pValue, pOperand)
            Quit
        }
        If pOp = "$gt" {
            If 'pFound { Set tResult = 0 Quit }
            Set tResult = ..OpGt(pValue, pOperand)
            Quit
        }
        If pOp = "$gte" {
            If 'pFound { Set tResult = 0 Quit }
            Set tResult = ..OpGte(pValue, pOperand)
            Quit
        }
        If pOp = "$lt" {
            If 'pFound { Set tResult = 0 Quit }
            Set tResult = ..OpLt(pValue, pOperand)
            Quit
        }
        If pOp = "$lte" {
            If 'pFound { Set tResult = 0 Quit }
            Set tResult = ..OpLte(pValue, pOperand)
            Quit
        }
        If pOp = "$in" {
            If 'pFound { Set tResult = 0 Quit }
            Set tResult = ..OpIn(pValue, pOperand)
            Quit
        }
        If pOp = "$nin" {
            ; CouchDB: missing field is not in any array, so $nin returns true
            If 'pFound { Set tResult = 1 Quit }
            Set tResult = ..OpNin(pValue, pOperand)
            Quit
        }
        If pOp = "$exists" {
            Set tResult = ..OpExists(pValue, pOperand, pFound)
            Quit
        }
        If pOp = "$type" {
            If 'pFound { Set tResult = 0 Quit }
            Set tResult = ..OpType(pValue, pOperand, pValueType)
            Quit
        }
        If pOp = "$regex" {
            If 'pFound { Set tResult = 0 Quit }
            Set tResult = ..OpRegex(pValue, pOperand)
            Quit
        }
        If pOp = "$mod" {
            If 'pFound { Set tResult = 0 Quit }
            Set tResult = ..OpMod(pValue, pOperand)
            Quit
        }
        If pOp = "$size" {
            If 'pFound { Set tResult = 0 Quit }
            Set tResult = ..OpSize(pValue, pOperand)
            Quit
        }
        If pOp = "$all" {
            If 'pFound { Set tResult = 0 Quit }
            Set tResult = ..OpAll(pValue, pOperand)
            Quit
        }
        If pOp = "$elemMatch" {
            If 'pFound { Set tResult = 0 Quit }
            Set tResult = ..OpElemMatch(pValue, pOperand)
            Quit
        }
        If pOp = "$allMatch" {
            If 'pFound { Set tResult = 0 Quit }
            Set tResult = ..OpAllMatch(pValue, pOperand)
            Quit
        }
        If pOp = "$not" {
            ; $not at field level: negate sub-condition
            If $IsObject(pOperand) {
                Set tInner = {}
                Do tInner.%Set("_dummy_", pOperand)
                ; Re-evaluate field match with negated result
                Set tFieldSel = {}
                Do tFieldSel.%Set("$not", pOperand)
                ; Actually just negate: evaluate the inner conditions and negate
                Set tInnerMatch = 1
                Set tInnerIter = pOperand.%GetIterator()
                While tInnerIter.%GetNext(.tInnerOp, .tInnerOperand) {
                    If '..EvalOperator(tInnerOp, pValue, tInnerOperand, pFound, pValueType, pOperand, pDoc) {
                        Set tInnerMatch = 0
                        Quit
                    }
                }
                Set tResult = 'tInnerMatch
                Quit
            }
            Quit
        }
        ; Unknown operator — skip
        Quit
    }
    Catch ex {
        Set tResult = 0
        Quit
    }
    Quit tResult
}

/// <p>Exact equality comparison.</p>
/// @param pValue The document field value
/// @param pOperand The selector operand
/// @return %Boolean
ClassMethod OpEq(pValue, pOperand) As %Boolean
{
    Quit (..CompareValues(pValue, pOperand) = 0)
}

/// <p>Not-equal comparison. Field must exist.</p>
/// @param pValue The document field value
/// @param pOperand The selector operand
/// @return %Boolean
ClassMethod OpNe(pValue, pOperand) As %Boolean
{
    Quit (..CompareValues(pValue, pOperand) '= 0)
}

/// <p>Greater-than comparison (type-aware).</p>
/// @param pValue The document field value
/// @param pOperand The selector operand
/// @return %Boolean
ClassMethod OpGt(pValue, pOperand) As %Boolean
{
    Quit (..CompareValues(pValue, pOperand) > 0)
}

/// <p>Greater-than-or-equal comparison (type-aware).</p>
/// @param pValue The document field value
/// @param pOperand The selector operand
/// @return %Boolean
ClassMethod OpGte(pValue, pOperand) As %Boolean
{
    Quit (..CompareValues(pValue, pOperand) >= 0)
}

/// <p>Less-than comparison (type-aware).</p>
/// @param pValue The document field value
/// @param pOperand The selector operand
/// @return %Boolean
ClassMethod OpLt(pValue, pOperand) As %Boolean
{
    Quit (..CompareValues(pValue, pOperand) < 0)
}

/// <p>Less-than-or-equal comparison (type-aware).</p>
/// @param pValue The document field value
/// @param pOperand The selector operand
/// @return %Boolean
ClassMethod OpLte(pValue, pOperand) As %Boolean
{
    Quit (..CompareValues(pValue, pOperand) <= 0)
}

/// <p>Value-in-array check.</p>
/// @param pValue The document field value
/// @param pOperand The array of allowed values
/// @return %Boolean
ClassMethod OpIn(pValue, pOperand As %DynamicArray) As %Boolean
{
    Set tResult = 0
    Try {
        If '$IsObject(pOperand) Quit
        For tI = 0:1:(pOperand.%Size() - 1) {
            If ..CompareValues(pValue, pOperand.%Get(tI)) = 0 {
                Set tResult = 1
                Quit
            }
        }
        Quit
    }
    Catch ex {
        Quit
    }
    Quit tResult
}

/// <p>Value-not-in-array check.</p>
/// @param pValue The document field value
/// @param pOperand The array of disallowed values
/// @return %Boolean
ClassMethod OpNin(pValue, pOperand As %DynamicArray) As %Boolean
{
    Quit '..OpIn(pValue, pOperand)
}

/// <p>Field existence check.</p>
/// @param pValue The field value (unused when field not found)
/// @param pOperand Boolean: true = must exist, false = must not exist
/// @param pFieldFound Whether the field was found in the document
/// @return %Boolean
ClassMethod OpExists(pValue, pOperand As %Boolean, pFieldFound As %Boolean) As %Boolean
{
    If pOperand {
        Quit pFieldFound
    }
    Quit 'pFieldFound
}

/// <p>Type check operator.</p>
/// @param pValue The field value
/// @param pOperand Expected type name: "null", "boolean", "number", "string", "array", "object"
/// @param pActualType The inferred type of the value
/// @return %Boolean
ClassMethod OpType(pValue, pOperand As %String, pActualType As %String) As %Boolean
{
    Quit (pActualType = pOperand)
}

/// <p>Regex partial match using $Locate (CouchDB uses partial matching).</p>
/// @param pValue The field value (must be string)
/// @param pOperand The regex pattern
/// @return %Boolean
ClassMethod OpRegex(pValue, pOperand As %String) As %Boolean
{
    Set tResult = 0
    Try {
        If $IsObject(pValue) Quit
        Set tResult = ''$Locate(pValue, pOperand)
        Quit
    }
    Catch ex {
        Quit
    }
    Quit tResult
}

/// <p>Modulo check: [divisor, remainder].</p>
/// @param pValue The field value (must be numeric)
/// @param pOperand Array of [divisor, remainder]
/// @return %Boolean
ClassMethod OpMod(pValue, pOperand As %DynamicArray) As %Boolean
{
    Set tResult = 0
    Try {
        If '$IsObject(pOperand) Quit
        If pOperand.%Size() < 2 Quit
        Set tDivisor = pOperand.%Get(0)
        Set tRemainder = pOperand.%Get(1)
        If tDivisor = 0 Quit
        If $IsObject(pValue) Quit
        Set tActual = pValue # tDivisor
        Set tResult = (tActual = tRemainder)
        Quit
    }
    Catch ex {
        Quit
    }
    Quit tResult
}

/// <p>Array size check.</p>
/// @param pValue The field value (must be array)
/// @param pOperand Expected size
/// @return %Boolean
ClassMethod OpSize(pValue, pOperand As %Integer) As %Boolean
{
    Set tResult = 0
    Try {
        If '$IsObject(pValue) Quit
        If 'pValue.%IsA("%DynamicArray") Quit
        Set tResult = (pValue.%Size() = pOperand)
        Quit
    }
    Catch ex {
        Quit
    }
    Quit tResult
}

/// <p>Array contains all specified values.</p>
/// @param pValue The document field value (must be array)
/// @param pOperand Array of values that must all be present
/// @return %Boolean
ClassMethod OpAll(pValue, pOperand As %DynamicArray) As %Boolean
{
    Set tResult = 1
    Try {
        If '$IsObject(pValue) || '$IsObject(pOperand) {
            Set tResult = 0
            Quit
        }
        If 'pValue.%IsA("%DynamicArray") {
            Set tResult = 0
            Quit
        }
        For tI = 0:1:(pOperand.%Size() - 1) {
            Set tNeeded = pOperand.%Get(tI)
            If '..ArrayContains(pValue, tNeeded) {
                Set tResult = 0
                Quit
            }
        }
        Quit
    }
    Catch ex {
        Set tResult = 0
        Quit
    }
    Quit tResult
}

/// <p>At least one array element matches sub-selector.</p>
/// @param pValue The document field value (must be array)
/// @param pSubSelector The sub-selector to match against elements
/// @return %Boolean
ClassMethod OpElemMatch(pValue As %DynamicArray, pSubSelector As %DynamicObject) As %Boolean
{
    Set tResult = 0
    Try {
        If '$IsObject(pValue) Quit
        If 'pValue.%IsA("%DynamicArray") Quit
        For tI = 0:1:(pValue.%Size() - 1) {
            Set tElem = pValue.%Get(tI)
            If $IsObject(tElem) && tElem.%IsA("%DynamicObject") {
                If ..Match(pSubSelector, tElem) {
                    Set tResult = 1
                    Quit
                }
            }
        }
        Quit
    }
    Catch ex {
        Quit
    }
    Quit tResult
}

/// <p>All array elements match sub-selector.</p>
/// @param pValue The document field value (must be array)
/// @param pSubSelector The sub-selector all elements must match
/// @return %Boolean
ClassMethod OpAllMatch(pValue As %DynamicArray, pSubSelector As %DynamicObject) As %Boolean
{
    Set tResult = 1
    Try {
        If '$IsObject(pValue) { Set tResult = 0 Quit }
        If 'pValue.%IsA("%DynamicArray") { Set tResult = 0 Quit }
        If pValue.%Size() = 0 { Set tResult = 0 Quit }
        For tI = 0:1:(pValue.%Size() - 1) {
            Set tElem = pValue.%Get(tI)
            If $IsObject(tElem) && tElem.%IsA("%DynamicObject") {
                If '..Match(pSubSelector, tElem) {
                    Set tResult = 0
                    Quit
                }
            } Else {
                Set tResult = 0
                Quit
            }
        }
        Quit
    }
    Catch ex {
        Set tResult = 0
        Quit
    }
    Quit tResult
}

/// <p>Cross-type value comparison following CouchDB type ordering.</p>
/// <p>Type ordering: null(0) &lt; false(1) &lt; true(2) &lt; numbers(3) &lt; strings(4) &lt; arrays(5) &lt; objects(6)</p>
/// @param pA First value
/// @param pB Second value
/// @return %Integer -1 if A &lt; B, 0 if equal, 1 if A &gt; B
ClassMethod CompareValues(pA, pB) As %Integer
{
    Set tResult = 0
    Try {
        Set tTypeA = ..TypeRank(pA)
        Set tTypeB = ..TypeRank(pB)
        ; Different type ranks → compare by rank
        If tTypeA '= tTypeB {
            If tTypeA < tTypeB { Set tResult = -1 }
            Else { Set tResult = 1 }
            Quit
        }
        ; Same type rank — compare within type
        ; Null
        If tTypeA = 0 {
            Set tResult = 0
            Quit
        }
        ; Boolean false(1) vs true(2)
        If (tTypeA = 1) || (tTypeA = 2) {
            Set tBoolA = ''pA
            Set tBoolB = ''pB
            If tBoolA < tBoolB { Set tResult = -1 }
            ElseIf tBoolA > tBoolB { Set tResult = 1 }
            Else { Set tResult = 0 }
            Quit
        }
        ; Number
        If tTypeA = 3 {
            If +pA < +pB { Set tResult = -1 }
            ElseIf +pA > +pB { Set tResult = 1 }
            Else { Set tResult = 0 }
            Quit
        }
        ; String
        If tTypeA = 4 {
            If pA ] pB { Set tResult = 1 }
            ElseIf pB ] pA { Set tResult = -1 }
            Else { Set tResult = 0 }
            Quit
        }
        ; Array
        If tTypeA = 5 {
            Set tResult = ..CompareArrays(pA, pB)
            Quit
        }
        ; Object
        If tTypeA = 6 {
            Set tResult = 0
            Quit
        }
        Quit
    }
    Catch ex {
        Quit
    }
    Quit tResult
}

/// <p>Get the type rank for a value following CouchDB ordering.</p>
/// <p>null=0, false=1, true=2, number=3, string=4, array=5, object=6</p>
/// @param pValue The value to rank
/// @param pTypeHint Optional JSON type hint from %GetTypeOf (e.g., "null", "boolean", "number", "string")
/// @return %Integer The type rank
ClassMethod TypeRank(pValue, pTypeHint As %String = "") As %Integer
{
    Set tRank = 4
    Try {
        ; Use type hint if available (most reliable path)
        If pTypeHint '= "" {
            If pTypeHint = "null" { Set tRank = 0 Quit }
            If pTypeHint = "boolean" {
                If pValue { Set tRank = 2 } Else { Set tRank = 1 }
                Quit
            }
            If pTypeHint = "number" { Set tRank = 3 Quit }
            If pTypeHint = "string" { Set tRank = 4 Quit }
            If pTypeHint = "array" { Set tRank = 5 Quit }
            If pTypeHint = "object" { Set tRank = 6 Quit }
        }
        ; Fallback heuristic when no type hint available
        If '$Data(pValue) { Set tRank = 0 Quit }
        If $IsObject(pValue) {
            If pValue.%IsA("%DynamicArray") { Set tRank = 5 Quit }
            If pValue.%IsA("%DynamicObject") { Set tRank = 6 Quit }
            Set tRank = 6
            Quit
        }
        ; Empty string without type hint treated as null (CouchDB: missing fields are null)
        If pValue = "" { Set tRank = 0 Quit }
        If pValue = +pValue {
            Set tRank = 3
            Quit
        }
        Set tRank = 4
        Quit
    }
    Catch ex {
        Quit
    }
    Quit tRank
}

/// <p>Compare two arrays element-wise.</p>
ClassMethod CompareArrays(pA As %DynamicArray, pB As %DynamicArray) As %Integer
{
    Set tResult = 0
    Try {
        Set tLenA = pA.%Size()
        Set tLenB = pB.%Size()
        Set tMin = tLenA
        If tLenB < tMin Set tMin = tLenB
        For tI = 0:1:(tMin - 1) {
            Set tCmp = ..CompareValues(pA.%Get(tI), pB.%Get(tI))
            If tCmp '= 0 {
                Set tResult = tCmp
                Quit
            }
        }
        If tResult '= 0 Quit
        If tLenA < tLenB { Set tResult = -1 }
        ElseIf tLenA > tLenB { Set tResult = 1 }
        Quit
    }
    Catch ex {
        Quit
    }
    Quit tResult
}

/// <p>Traverse dot-notation path through nested objects to get a field value.</p>
/// @param pDoc The document body as %DynamicObject
/// @param pFieldPath The dot-notation field path (e.g., "address.city")
/// @param pFound Output: 1 if field was found, 0 otherwise
/// @return The value at the final path segment
ClassMethod GetFieldValue(pDoc As %DynamicObject, pFieldPath As %String, Output pFound As %Boolean)
{
    Set pFound = 0
    Set tValue = ""
    Try {
        If '$IsObject(pDoc) Quit
        Set tObj = pDoc
        Set tParts = $Length(pFieldPath, ".")
        For tI = 1:1:tParts {
            Set tPart = $Piece(pFieldPath, ".", tI)
            If '$IsObject(tObj) {
                Quit
            }
            If 'tObj.%IsDefined(tPart) {
                Quit
            }
            If tI = tParts {
                Set pFound = 1
                Set tValue = tObj.%Get(tPart)
                Quit
            }
            Set tObj = tObj.%Get(tPart)
        }
        Quit
    }
    Catch ex {
        Set pFound = 0
        Quit
    }
    Quit tValue
}

/// <p>Infer the JSON type of a value.</p>
/// <p>Note: Cannot distinguish empty string from null, or boolean from number,
/// without type hints from the parent %DynamicObject. Callers needing exact
/// type should use %GetTypeOf() on the parent object when available.</p>
/// @param pValue The value to check
/// @return %String One of: "null", "boolean", "number", "string", "array", "object"
ClassMethod InferType(pValue) As %String
{
    If '$Data(pValue) Quit "null"
    If $IsObject(pValue) {
        If pValue.%IsA("%DynamicArray") Quit "array"
        If pValue.%IsA("%DynamicObject") Quit "object"
        Quit "object"
    }
    ; Empty string: heuristic defaults to string (callers needing null
    ; detection should use %GetTypeOf on the source DynamicObject)
    If pValue = "" Quit "string"
    If pValue = +pValue Quit "number"
    Quit "string"
}

/// <p>Check if a %DynamicArray contains a specific value.</p>
ClassMethod ArrayContains(pArray As %DynamicArray, pValue) As %Boolean
{
    Set tFound = 0
    Try {
        If '$IsObject(pArray) Quit
        For tI = 0:1:(pArray.%Size() - 1) {
            If ..CompareValues(pArray.%Get(tI), pValue) = 0 {
                Set tFound = 1
                Quit
            }
        }
        Quit
    }
    Catch ex {
        Quit
    }
    Quit tFound
}

}
