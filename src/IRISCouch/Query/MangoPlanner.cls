/// <p>Mango query index selection and ranking engine.</p>
/// <p>Analyzes a normalized selector, available indexes, and sort requirements
/// to choose the optimal index for query execution. Follows CouchDB's ranking
/// algorithm: prefix difference, then column count, then alphabetical.</p>
Class IRISCouch.Query.MangoPlanner Extends %RegisteredObject
{

/// <p>Choose the best index for a query.</p>
/// <p>Returns an object with: index (selected), candidates (all considered), warning (if full scan).</p>
/// @param pDB The database name
/// @param pSelector The normalized selector
/// @param pSort The sort specification array
/// @param pUseIndex Explicit index to use (ddoc or [ddoc, name])
/// @return %DynamicObject with index, candidates, warning
ClassMethod ChooseIndex(pDB As %String, pSelector As %DynamicObject, pSort As %DynamicArray = "", pUseIndex As %String = "") As %DynamicObject
{
    Set tResult = {}
    Try {
        ; Get all user indexes
        Set tUserIndexes = ##class(IRISCouch.Projection.MangoIndexDef).GetActiveIndexes(pDB)
        ; Build candidate list
        Set tCandidates = []
        ; Get selector fields
        Set tSelectorFields = ..GetSelectorFields(pSelector)
        ; Parse use_index into ddoc and name
        Set tUseIndexDDoc = ""
        Set tUseIndexName = ""
        If pUseIndex '= "" {
            If $IsObject(pUseIndex) && pUseIndex.%IsA("%DynamicArray") {
                If pUseIndex.%Size() > 0 Set tUseIndexDDoc = pUseIndex.%Get(0)
                If pUseIndex.%Size() > 1 Set tUseIndexName = pUseIndex.%Get(1)
            } Else {
                Set tUseIndexDDoc = pUseIndex
            }
            ; Normalize ddoc
            If (tUseIndexDDoc '= "") && ($Extract(tUseIndexDDoc, 1, 8) '= "_design/") {
                Set tUseIndexDDoc = "_design/" _ tUseIndexDDoc
            }
        }
        ; Evaluate each user index
        Set tUsable = []
        For tI = 0:1:(tUserIndexes.%Size() - 1) {
            Set tIdx = tUserIndexes.%Get(tI)
            Set tDDoc = tIdx.%Get("ddoc")
            Set tName = tIdx.%Get("name")
            Set tFieldsStr = tIdx.%Get("fields")
            Set tPartialFilter = tIdx.%Get("partialFilter")
            ; If use_index specified, filter to that index only
            If tUseIndexDDoc '= "" {
                If tDDoc '= tUseIndexDDoc Continue
                If (tUseIndexName '= "") && (tName '= tUseIndexName) Continue
            }
            ; Skip partial filter indexes unless explicitly requested
            If (tPartialFilter '= "") && (tUseIndexDDoc = "") Continue
            ; Get index columns
            Set tIndexCols = ..GetIndexColumns(tFieldsStr)
            ; Check usability
            Set tReasons = []
            Set tUsableFlag = 1
            ; Check field coverage
            Set tFieldMatch = ..CheckFieldCoverage(tIndexCols, tSelectorFields, pSort)
            If 'tFieldMatch {
                Set tUsableFlag = 0
                Set tReasonObj = {}
                Do tReasonObj.%Set("name", "field_mismatch")
                Do tReasons.%Push(tReasonObj)
            }
            ; Check sort compatibility
            If $IsObject(pSort) && (pSort.%Size() > 0) {
                Set tSortOk = ..CheckSortCompatibility(tIndexCols, pSort)
                If 'tSortOk {
                    Set tUsableFlag = 0
                    Set tReasonObj = {}
                    Do tReasonObj.%Set("name", "sort_order_mismatch")
                    Do tReasons.%Push(tReasonObj)
                }
            }
            ; Build candidate entry
            Set tCandidate = {}
            Set tIdxInfo = ..BuildIndexInfo(tDDoc, tName, "json", tFieldsStr)
            Do tCandidate.%Set("index", tIdxInfo)
            Set tAnalysis = {}
            Do tAnalysis.%Set("usable", tUsableFlag, "boolean")
            Do tAnalysis.%Set("reasons", tReasons)
            Do tAnalysis.%Set("ranking", 0, "number")
            Do tAnalysis.%Set("covering", "null", "null")
            Do tCandidate.%Set("analysis", tAnalysis)
            Do tCandidates.%Push(tCandidate)
            If tUsableFlag {
                ; Calculate ranking metrics
                Set tPrefixDiff = ..ComputePrefixDifference(tIndexCols, tSelectorFields)
                Set tColCount = tIndexCols.%Size()
                Set tRankObj = {}
                Do tRankObj.%Set("prefixDiff", tPrefixDiff, "number")
                Do tRankObj.%Set("colCount", tColCount, "number")
                Do tRankObj.%Set("ddoc", tDDoc)
                Do tRankObj.%Set("name", tName)
                Do tRankObj.%Set("candidate", tCandidate)
                Do tRankObj.%Set("index", tIdxInfo)
                Do tUsable.%Push(tRankObj)
            }
        }
        ; Add _all_docs special index candidate
        Set tAllDocsCandidate = {}
        Set tAllDocsInfo = ..BuildAllDocsInfo()
        Do tAllDocsCandidate.%Set("index", tAllDocsInfo)
        Set tAllDocsAnalysis = {}
        Do tAllDocsAnalysis.%Set("usable", 1, "boolean")
        Set tAllDocsReasons = []
        Set tReasonObj = {}
        Do tReasonObj.%Set("name", "unfavored_type")
        Do tAllDocsReasons.%Push(tReasonObj)
        Do tAllDocsAnalysis.%Set("reasons", tAllDocsReasons)
        Do tAllDocsAnalysis.%Set("ranking", 0, "number")
        Do tAllDocsAnalysis.%Set("covering", "null", "null")
        Do tAllDocsCandidate.%Set("analysis", tAllDocsAnalysis)
        Do tCandidates.%Push(tAllDocsCandidate)
        ; Sort usable indexes by ranking criteria
        Set tBestIdx = ""
        Set tBestPrefixDiff = 999999
        Set tBestColCount = 999999
        Set tBestDDoc = ""
        Set tBestName = ""
        For tI = 0:1:(tUsable.%Size() - 1) {
            Set tR = tUsable.%Get(tI)
            Set tPD = tR.%Get("prefixDiff")
            Set tCC = tR.%Get("colCount")
            Set tDD = tR.%Get("ddoc")
            Set tNN = tR.%Get("name")
            Set tBetter = 0
            If tPD < tBestPrefixDiff {
                Set tBetter = 1
            } ElseIf tPD = tBestPrefixDiff {
                If tCC < tBestColCount {
                    Set tBetter = 1
                } ElseIf tCC = tBestColCount {
                    If (tDD _ tNN) ] "" {
                        If (tBestDDoc _ tBestName) = "" {
                            Set tBetter = 1
                        } ElseIf '((tDD _ tNN) ] (tBestDDoc _ tBestName)) {
                            Set tBetter = 1
                        }
                    }
                }
            }
            If tBetter {
                Set tBestPrefixDiff = tPD
                Set tBestColCount = tCC
                Set tBestDDoc = tDD
                Set tBestName = tNN
                Set tBestIdx = tR
            }
        }
        ; Assign rankings to candidates
        ; Simple approach: best usable gets rank 1, others get 2+
        Set tRank = 1
        If $IsObject(tBestIdx) {
            ; Find this candidate and set its ranking
            For tI = 0:1:(tCandidates.%Size() - 1) {
                Set tC = tCandidates.%Get(tI)
                Set tCIdx = tC.%Get("index")
                If (tCIdx.%Get("ddoc") = tBestDDoc) && (tCIdx.%Get("name") = tBestName) {
                    Set tCAnalysis = tC.%Get("analysis")
                    Do tCAnalysis.%Set("ranking", 1, "number")
                    Set tRank = 2
                }
            }
        }
        ; Build result
        If $IsObject(tBestIdx) {
            Do tResult.%Set("index", tBestIdx.%Get("index"))
        } Else {
            ; Fall back to _all_docs
            Do tResult.%Set("index", tAllDocsInfo)
            Do tResult.%Set("warning", "No matching index found, create an index to optimize query time.")
            ; Set _all_docs ranking to 1
            Set tAllDocsA = tAllDocsCandidate.%Get("analysis")
            Do tAllDocsA.%Set("ranking", 1, "number")
        }
        Do tResult.%Set("candidates", tCandidates)
        Quit
    }
    Catch ex {
        Do tResult.%Set("index", ..BuildAllDocsInfo())
        Do tResult.%Set("warning", "No matching index found, create an index to optimize query time.")
        Do tResult.%Set("candidates", [])
        Quit
    }
    Quit tResult
}

/// <p>Extract all field names referenced in a normalized selector.</p>
/// @param pSelector The normalized selector
/// @return %DynamicArray of field name strings
ClassMethod GetSelectorFields(pSelector As %DynamicObject) As %DynamicArray
{
    Set tFields = []
    Try {
        If '$IsObject(pSelector) Quit
        Set tIter = pSelector.%GetIterator()
        While tIter.%GetNext(.tKey, .tVal) {
            If tKey = "$and" || (tKey = "$or") || (tKey = "$nor") {
                If $IsObject(tVal) && tVal.%IsA("%DynamicArray") {
                    For tI = 0:1:(tVal.%Size() - 1) {
                        Set tSub = ..GetSelectorFields(tVal.%Get(tI))
                        For tJ = 0:1:(tSub.%Size() - 1) {
                            Set tF = tSub.%Get(tJ)
                            If '..ArrayContainsStr(tFields, tF) {
                                Do tFields.%Push(tF)
                            }
                        }
                    }
                }
            } ElseIf tKey = "$not" {
                If $IsObject(tVal) {
                    Set tSub = ..GetSelectorFields(tVal)
                    For tJ = 0:1:(tSub.%Size() - 1) {
                        Set tF = tSub.%Get(tJ)
                        If '..ArrayContainsStr(tFields, tF) {
                            Do tFields.%Push(tF)
                        }
                    }
                }
            } ElseIf $Extract(tKey, 1) '= "$" {
                If '..ArrayContainsStr(tFields, tKey) {
                    Do tFields.%Push(tKey)
                }
            }
        }
        Quit
    }
    Catch ex {
        Quit
    }
    Quit tFields
}

/// <p>Compute prefix difference between index columns and selector fields.</p>
/// <p>Lower is better — means more selector fields are covered by index leading columns.</p>
/// @param pIndexColumns Array of index column names
/// @param pSelectorFields Array of selector field names
/// @return %Integer The prefix difference
ClassMethod ComputePrefixDifference(pIndexColumns As %DynamicArray, pSelectorFields As %DynamicArray) As %Integer
{
    Set tDiff = 0
    Try {
        If '$IsObject(pSelectorFields) Quit
        Set tCovered = 0
        For tI = 0:1:(pSelectorFields.%Size() - 1) {
            Set tField = pSelectorFields.%Get(tI)
            If ..ArrayContainsStr(pIndexColumns, tField) {
                Set tCovered = tCovered + 1
            }
        }
        Set tDiff = pSelectorFields.%Size() - tCovered
        Quit
    }
    Catch ex {
        Quit
    }
    Quit tDiff
}

/// <p>Get index column names from a fields JSON string.</p>
ClassMethod GetIndexColumns(pFieldsStr As %String) As %DynamicArray
{
    Set tCols = []
    Try {
        If pFieldsStr = "" Quit
        Set tFieldsArr = ##class(%DynamicAbstractObject).%FromJSON(pFieldsStr)
        For tI = 0:1:(tFieldsArr.%Size() - 1) {
            Set tField = tFieldsArr.%Get(tI)
            If $IsObject(tField) {
                Set tFIter = tField.%GetIterator()
                If tFIter.%GetNext(.tName, .tDir) {
                    Do tCols.%Push(tName)
                }
            } Else {
                Do tCols.%Push(tField)
            }
        }
        Quit
    }
    Catch ex {
        Quit
    }
    Quit tCols
}

/// <p>Check if all index columns are referenced in the selector fields or sort fields.</p>
ClassMethod CheckFieldCoverage(pIndexCols As %DynamicArray, pSelectorFields As %DynamicArray, pSort As %DynamicArray = "") As %Boolean
{
    Set tResult = 1
    Try {
        ; Get sort field names
        Set tSortFields = []
        If $IsObject(pSort) {
            For tI = 0:1:(pSort.%Size() - 1) {
                Set tSortElem = pSort.%Get(tI)
                If $IsObject(tSortElem) {
                    Set tSIter = tSortElem.%GetIterator()
                    If tSIter.%GetNext(.tSName, .tSDir) {
                        Do tSortFields.%Push(tSName)
                    }
                } Else {
                    Do tSortFields.%Push(tSortElem)
                }
            }
        }
        ; Each index column must be in selector fields, sort fields, or be _id/_rev
        For tI = 0:1:(pIndexCols.%Size() - 1) {
            Set tCol = pIndexCols.%Get(tI)
            If (tCol = "_id") || (tCol = "_rev") Continue
            If ..ArrayContainsStr(pSelectorFields, tCol) Continue
            If ..ArrayContainsStr(tSortFields, tCol) Continue
            Set tResult = 0
            Quit
        }
        Quit
    }
    Catch ex {
        Set tResult = 0
        Quit
    }
    Quit tResult
}

/// <p>Check if sort fields are a prefix of index columns in the same order.</p>
ClassMethod CheckSortCompatibility(pIndexCols As %DynamicArray, pSort As %DynamicArray) As %Boolean
{
    Set tResult = 1
    Try {
        If '$IsObject(pSort) || (pSort.%Size() = 0) {
            Quit
        }
        For tI = 0:1:(pSort.%Size() - 1) {
            Set tSortElem = pSort.%Get(tI)
            If $IsObject(tSortElem) {
                Set tSIter = tSortElem.%GetIterator()
                If tSIter.%GetNext(.tSName, .tSDir) {
                    ; ok
                } Else {
                    Set tResult = 0
                    Quit
                }
            } Else {
                Set tSName = tSortElem
            }
            ; Sort field at position tI must match index column at same position
            If tI >= pIndexCols.%Size() {
                Set tResult = 0
                Quit
            }
            If pIndexCols.%Get(tI) '= tSName {
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

/// <p>Build index info object for a JSON index.</p>
ClassMethod BuildIndexInfo(pDDoc As %String, pName As %String, pType As %String, pFieldsStr As %String) As %DynamicObject
{
    Set tInfo = {}
    Try {
        Do tInfo.%Set("ddoc", pDDoc)
        Do tInfo.%Set("name", pName)
        Do tInfo.%Set("type", pType)
        Set tDef = {}
        If pFieldsStr '= "" {
            Set tFieldsArr = ##class(%DynamicAbstractObject).%FromJSON(pFieldsStr)
            Do tDef.%Set("fields", tFieldsArr)
        } Else {
            Do tDef.%Set("fields", [])
        }
        Do tInfo.%Set("def", tDef)
        Quit
    }
    Catch ex {
        Quit
    }
    Quit tInfo
}

/// <p>Build info object for the special _all_docs index.</p>
ClassMethod BuildAllDocsInfo() As %DynamicObject
{
    Set tInfo = {}
    Do tInfo.%Set("ddoc", "null", "null")
    Do tInfo.%Set("name", "_all_docs")
    Do tInfo.%Set("type", "special")
    Set tDef = {}
    Do tDef.%Set("fields", [{"_id":"asc"}])
    Do tInfo.%Set("def", tDef)
    Quit tInfo
}

/// <p>Helper: check if a string array contains a specific string.</p>
ClassMethod ArrayContainsStr(pArray As %DynamicArray, pValue As %String) As %Boolean
{
    Set tFound = 0
    Try {
        If '$IsObject(pArray) Quit
        For tI = 0:1:(pArray.%Size() - 1) {
            If pArray.%Get(tI) = pValue {
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
