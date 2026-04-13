/// <p>Sort validation and in-memory sort execution for Mango queries.</p>
/// <p>Validates sort specifications per CouchDB rules (all same direction)
/// and performs in-memory sorting of result documents using
/// CouchDB type-aware comparison.</p>
Class IRISCouch.Query.MangoSort Extends %RegisteredObject
{

/// <p>Validate a sort specification.</p>
/// <p>Each element must be a string or object with single key mapping to "asc"/"desc".
/// All elements must have the same direction — CouchDB constraint.</p>
/// @param pSort The sort array
/// @return %Status
ClassMethod Validate(pSort As %DynamicArray) As %Status
{
    Set tSC = $$$OK
    Try {
        If '$IsObject(pSort) Quit
        If pSort.%Size() = 0 Quit
        Set tFirstDir = ""
        For tI = 0:1:(pSort.%Size() - 1) {
            Set tElem = pSort.%Get(tI)
            If $IsObject(tElem) {
                ; Must be object with single key
                Set tEIter = tElem.%GetIterator()
                If 'tEIter.%GetNext(.tName, .tDir) {
                    Set tSC = $$$ERROR($$$GeneralError, "Invalid sort element at index "_tI)
                    Quit
                }
                If (tDir '= "asc") && (tDir '= "desc") {
                    Set tSC = $$$ERROR($$$GeneralError, "Sort direction must be ""asc"" or ""desc""")
                    Quit
                }
                If tFirstDir = "" {
                    Set tFirstDir = tDir
                } ElseIf tDir '= tFirstDir {
                    Set tSC = $$$ERROR($$$GeneralError, "All sort fields must have the same direction")
                    Quit
                }
            } Else {
                ; Bare string defaults to "asc"
                If tFirstDir = "" {
                    Set tFirstDir = "asc"
                } ElseIf tFirstDir '= "asc" {
                    Set tSC = $$$ERROR($$$GeneralError, "All sort fields must have the same direction")
                    Quit
                }
            }
        }
        Quit
    }
    Catch ex {
        Set tSC = ex.AsStatus()
        Quit
    }
    Quit tSC
}

/// <p>Sort documents in-memory by specified fields.</p>
/// <p>Uses insertion sort (suitable for limited result sets).
/// Uses MangoSelector.CompareValues for CouchDB-compatible type ordering.</p>
/// @param pDocs Array of documents to sort
/// @param pSort Sort specification array
/// @return %DynamicArray sorted documents
ClassMethod SortDocs(pDocs As %DynamicArray, pSort As %DynamicArray) As %DynamicArray
{
    Set tResult = ""
    Try {
        If '$IsObject(pDocs) || (pDocs.%Size() <= 1) {
            Set tResult = pDocs
            Quit
        }
        If '$IsObject(pSort) || (pSort.%Size() = 0) {
            Set tResult = pDocs
            Quit
        }
        ; Parse sort fields and directions
        Set tSortFields = []
        Set tSortDirs = []
        For tI = 0:1:(pSort.%Size() - 1) {
            Set tElem = pSort.%Get(tI)
            If $IsObject(tElem) {
                Set tEIter = tElem.%GetIterator()
                If tEIter.%GetNext(.tName, .tDir) {
                    Do tSortFields.%Push(tName)
                    Do tSortDirs.%Push(tDir)
                }
            } Else {
                Do tSortFields.%Push(tElem)
                Do tSortDirs.%Push("asc")
            }
        }
        ; Copy docs to array for sorting
        Set tLen = pDocs.%Size()
        For tI = 0:1:(tLen - 1) {
            Set tArr(tI) = pDocs.%Get(tI)
        }
        ; Insertion sort
        For tI = 1:1:(tLen - 1) {
            Set tCurrent = tArr(tI)
            Set tJ = tI - 1
            While tJ >= 0 {
                Set tCmp = ..CompareDocs(tArr(tJ), tCurrent, tSortFields, tSortDirs)
                If tCmp > 0 {
                    Set tArr(tJ + 1) = tArr(tJ)
                    Set tJ = tJ - 1
                } Else {
                    Quit
                }
            }
            Set tArr(tJ + 1) = tCurrent
        }
        ; Build result array
        Set tResult = []
        For tI = 0:1:(tLen - 1) {
            Do tResult.%Push(tArr(tI))
        }
        Quit
    }
    Catch ex {
        If '$IsObject(tResult) Set tResult = pDocs
        Quit
    }
    Quit tResult
}

/// <p>Compare two documents by sort fields.</p>
ClassMethod CompareDocs(pA As %DynamicObject, pB As %DynamicObject, pFields As %DynamicArray, pDirs As %DynamicArray) As %Integer
{
    Set tResult = 0
    Try {
        For tI = 0:1:(pFields.%Size() - 1) {
            Set tField = pFields.%Get(tI)
            Set tDir = pDirs.%Get(tI)
            Set tValA = ##class(IRISCouch.Query.MangoSelector).GetFieldValue(pA, tField, .tFoundA)
            Set tValB = ##class(IRISCouch.Query.MangoSelector).GetFieldValue(pB, tField, .tFoundB)
            ; Missing fields sort before present fields
            If 'tFoundA && 'tFoundB Continue
            If 'tFoundA { Set tResult = -1 If tDir = "desc" { Set tResult = 1 } Quit }
            If 'tFoundB { Set tResult = 1 If tDir = "desc" { Set tResult = -1 } Quit }
            Set tCmp = ##class(IRISCouch.Query.MangoSelector).CompareValues(tValA, tValB)
            If tCmp '= 0 {
                If tDir = "desc" Set tCmp = -tCmp
                Set tResult = tCmp
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

/// <p>Get the sort direction from the first element of a sort array.</p>
/// @param pSort The sort array
/// @return %String "asc" or "desc"
ClassMethod GetDirection(pSort As %DynamicArray) As %String
{
    Set tDir = "asc"
    Try {
        If '$IsObject(pSort) || (pSort.%Size() = 0) Quit
        Set tElem = pSort.%Get(0)
        If $IsObject(tElem) {
            Set tEIter = tElem.%GetIterator()
            If tEIter.%GetNext(.tName, .tD) {
                Set tDir = tD
            }
        }
        Quit
    }
    Catch ex {
        Quit
    }
    Quit tDir
}

}
