/// <p>Mango query execution engine.</p>
/// <p>Executes _find queries using either an index-backed path (via MangoIndex table)
/// or a full-scan path (via Winners table). Handles field projection, sorting,
/// pagination via skip/limit and bookmarks, and execution stats collection.</p>
Class IRISCouch.Query.MangoExecutor Extends %RegisteredObject
{

/// <p>Execute a Mango _find query.</p>
/// <p>Normalizes the selector, selects an index via MangoPlanner, executes the query,
/// applies field projection, sorting, skip/limit, and generates bookmarks.</p>
/// @param pDB The database name
/// @param pSelector The raw selector object
/// @param pOpts Query options: limit, skip, sort, fields, bookmark, use_index, execution_stats, conflicts, allow_fallback
/// @return %DynamicObject with docs, bookmark, warning, execution_stats
ClassMethod Execute(pDB As %String, pSelector As %DynamicObject, pOpts As %DynamicObject) As %DynamicObject
{
    Set tResult = {}
    Try {
        Set tStartTime = $ZHorolog
        ; Parse options
        Set tLimit = 25
        If $IsObject(pOpts) && pOpts.%IsDefined("limit") Set tLimit = +pOpts.%Get("limit")
        If tLimit < 0 Set tLimit = 25
        Set tSkip = 0
        If $IsObject(pOpts) && pOpts.%IsDefined("skip") Set tSkip = +pOpts.%Get("skip")
        If tSkip < 0 Set tSkip = 0
        Set tSort = ""
        If $IsObject(pOpts) && pOpts.%IsDefined("sort") Set tSort = pOpts.%Get("sort")
        Set tFields = ""
        If $IsObject(pOpts) && pOpts.%IsDefined("fields") Set tFields = pOpts.%Get("fields")
        Set tBookmark = ""
        If $IsObject(pOpts) && pOpts.%IsDefined("bookmark") Set tBookmark = pOpts.%Get("bookmark")
        Set tUseIndex = ""
        If $IsObject(pOpts) && pOpts.%IsDefined("use_index") Set tUseIndex = pOpts.%Get("use_index")
        Set tExecStats = 0
        If $IsObject(pOpts) && pOpts.%IsDefined("execution_stats") Set tExecStats = pOpts.%Get("execution_stats")
        Set tAllowFallback = 1
        If $IsObject(pOpts) && pOpts.%IsDefined("allow_fallback") Set tAllowFallback = pOpts.%Get("allow_fallback")
        ; Normalize selector
        Set tNormSelector = ##class(IRISCouch.Query.MangoSelector).Normalize(pSelector)
        ; Validate sort if provided
        If $IsObject(tSort) && (tSort.%Size() > 0) {
            Set tSortSC = ##class(IRISCouch.Query.MangoSort).Validate(tSort)
            If $$$ISERR(tSortSC) {
                Do tResult.%Set("error", "bad_request")
                Do tResult.%Set("reason", "Invalid sort specification")
                Quit
            }
        }
        ; Choose index
        Set tPlan = ##class(IRISCouch.Query.MangoPlanner).ChooseIndex(pDB, tNormSelector, tSort, tUseIndex)
        Set tIndex = tPlan.%Get("index")
        Set tWarning = tPlan.%Get("warning")
        ; Check if use_index failed and fallback not allowed
        If (tUseIndex '= "") && (tWarning '= "") && 'tAllowFallback {
            Do tResult.%Set("error", "no_usable_index")
            Do tResult.%Set("reason", "No matching index found for the specified use_index value")
            Quit
        }
        ; Initialize stats
        Set tKeysExamined = 0
        Set tDocsExamined = 0
        Set tResultsReturned = 0
        ; Decode bookmark if present
        Set tBookmarkDocId = ""
        Set tBookmarkKey = ""
        If tBookmark '= "" && (tBookmark '= "nil") {
            Set tBkSC = ..DecodeBookmark(tBookmark, .tBookmarkDocId, .tBookmarkKey)
        }
        ; Execute query based on index type
        Set tIndexType = ""
        If $IsObject(tIndex) Set tIndexType = tIndex.%Get("type")
        Set tMatchedDocs = []
        If tIndexType = "json" {
            ; Index-backed query
            Set tDDoc = tIndex.%Get("ddoc")
            Set tIdxName = tIndex.%Get("name")
            Do ..ExecuteIndexQuery(pDB, tDDoc, tIdxName, tNormSelector, tBookmarkDocId, .tMatchedDocs, .tKeysExamined, .tDocsExamined)
        } Else {
            ; Full scan via Winners
            Do ..ExecuteFullScan(pDB, tNormSelector, tBookmarkDocId, .tMatchedDocs, .tDocsExamined)
        }
        ; Apply sort if needed (in-memory)
        If $IsObject(tSort) && (tSort.%Size() > 0) {
            Set tMatchedDocs = ##class(IRISCouch.Query.MangoSort).SortDocs(tMatchedDocs, tSort)
        }
        ; Apply skip and limit
        Set tDocs = []
        Set tTotal = tMatchedDocs.%Size()
        Set tStart = tSkip
        Set tCount = 0
        Set tLastDocId = ""
        Set tLastKey = ""
        For tI = tStart:1:(tTotal - 1) {
            If tCount >= tLimit Quit
            Set tDoc = tMatchedDocs.%Get(tI)
            ; Apply field projection
            If $IsObject(tFields) && (tFields.%Size() > 0) {
                Set tDoc = ##class(IRISCouch.Query.MangoFields).Project(tDoc, tFields)
            }
            Do tDocs.%Push(tDoc)
            ; Track last doc for bookmark
            Set tOrigDoc = tMatchedDocs.%Get(tI)
            If $IsObject(tOrigDoc) {
                Set tLastDocId = tOrigDoc.%Get("_id")
                If tLastDocId = "" Set tLastDocId = ""
                ; Extract sort key for bookmark if sort is active
                If $IsObject(tSort) && (tSort.%Size() > 0) {
                    Set tSortElem = tSort.%Get(0)
                    Set tSortField = ""
                    If $IsObject(tSortElem) {
                        Set tSEIter = tSortElem.%GetIterator()
                        If tSEIter.%GetNext(.tSortField)
                    } Else {
                        Set tSortField = tSortElem
                    }
                    If tSortField '= "" {
                        Set tLastKey = ##class(IRISCouch.Query.MangoSelector).GetFieldValue(tOrigDoc, tSortField, .tKeyFound)
                        If 'tKeyFound Set tLastKey = ""
                    }
                }
            }
            Set tCount = tCount + 1
        }
        Set tResultsReturned = tCount
        ; Generate bookmark for pagination
        Set tNewBookmark = "nil"
        If (tLastDocId '= "") && ((tStart + tCount) < tTotal) {
            Set tNewBookmark = ..GenerateBookmark(tLastDocId, tLastKey)
        }
        ; Build response
        Do tResult.%Set("docs", tDocs)
        Do tResult.%Set("bookmark", tNewBookmark)
        ; Add warning if full scan
        If tWarning '= "" {
            Do tResult.%Set("warning", tWarning)
        }
        ; Add execution stats if requested
        If tExecStats {
            Set tEndTime = $ZHorolog
            Set tElapsed = (tEndTime - tStartTime) * 1000
            Set tStats = {}
            Do tStats.%Set("total_keys_examined", tKeysExamined, "number")
            Do tStats.%Set("total_docs_examined", tDocsExamined, "number")
            Do tStats.%Set("results_returned", tResultsReturned, "number")
            Do tStats.%Set("execution_time_ms", $FNumber(tElapsed, "", 1), "number")
            Do tResult.%Set("execution_stats", tStats)
        }
        Quit
    }
    Catch ex {
        Do tResult.%Set("docs", [])
        Do tResult.%Set("bookmark", "nil")
        Quit
    }
    Quit tResult
}

/// <p>Execute an index-backed query using MangoIndex table.</p>
ClassMethod ExecuteIndexQuery(pDB As %String, pDDoc As %String, pIdxName As %String, pSelector As %DynamicObject, pBookmarkDocId As %String, ByRef pDocs As %DynamicArray, ByRef pKeysExamined As %Integer, ByRef pDocsExamined As %Integer)
{
    Try {
        Set pDocs = []
        Set pKeysExamined = 0
        Set pDocsExamined = 0
        ; Get candidate DocIds from MangoIndex
        Set tSQL = "SELECT DISTINCT %EXACT(DocId) AS DocId FROM IRISCouch_Projection.MangoIndex WHERE %EXACT(DbName) = ? AND %EXACT(DDoc) = ? AND %EXACT(IndexName) = ?"
        If pBookmarkDocId '= "" {
            Set tSQL = tSQL _ " AND %EXACT(DocId) > ?"
            Set tSQL = tSQL _ " ORDER BY DocId"
            Set tRS = ##class(%SQL.Statement).%ExecDirect(, tSQL, pDB, pDDoc, pIdxName, pBookmarkDocId)
        } Else {
            Set tSQL = tSQL _ " ORDER BY DocId"
            Set tRS = ##class(%SQL.Statement).%ExecDirect(, tSQL, pDB, pDDoc, pIdxName)
        }
        ; Collect candidate doc IDs
        While tRS.%Next() {
            Set pKeysExamined = pKeysExamined + 1
            Set tDocId = tRS.%Get("DocId")
            Set tDocIds(tDocId) = 1
        }
        ; For each candidate, get body from Winners and post-filter
        Set tDocId = ""
        Set tDocId = $Order(tDocIds(tDocId))
        While tDocId '= "" {
            Set tBodyStr = ##class(IRISCouch.Projection.Winners).GetBody(pDB, tDocId)
            If tBodyStr '= "" {
                Set pDocsExamined = pDocsExamined + 1
                Try {
                    Set tDoc = ##class(%DynamicObject).%FromJSON(tBodyStr)
                    ; Ensure _id is set
                    If 'tDoc.%IsDefined("_id") {
                        Do tDoc.%Set("_id", tDocId)
                    }
                    ; Post-filter with full selector
                    If ##class(IRISCouch.Query.MangoSelector).Match(pSelector, tDoc) {
                        Do pDocs.%Push(tDoc)
                    }
                }
                Catch tParseEx {
                    ; Skip unparseable docs
                }
            }
            Set tDocId = $Order(tDocIds(tDocId))
        }
        Quit
    }
    Catch ex {
        If '$IsObject(pDocs) Set pDocs = []
        Quit
    }
}

/// <p>Execute a full-scan query using Winners table.</p>
ClassMethod ExecuteFullScan(pDB As %String, pSelector As %DynamicObject, pBookmarkDocId As %String, ByRef pDocs As %DynamicArray, ByRef pDocsExamined As %Integer)
{
    Try {
        Set pDocs = []
        Set pDocsExamined = 0
        Set tSQL = "SELECT %EXACT(DocId) AS DocId, Body FROM IRISCouch_Projection.Winners WHERE %EXACT(DbName) = ? AND Deleted = 0"
        If pBookmarkDocId '= "" {
            Set tSQL = tSQL _ " AND %EXACT(DocId) > ?"
            Set tSQL = tSQL _ " ORDER BY DocId"
            Set tRS = ##class(%SQL.Statement).%ExecDirect(, tSQL, pDB, pBookmarkDocId)
        } Else {
            Set tSQL = tSQL _ " ORDER BY DocId"
            Set tRS = ##class(%SQL.Statement).%ExecDirect(, tSQL, pDB)
        }
        While tRS.%Next() {
            Set pDocsExamined = pDocsExamined + 1
            Set tDocId = tRS.%Get("DocId")
            Set tBodyStr = tRS.%Get("Body")
            If tBodyStr = "" Continue
            Try {
                Set tDoc = ##class(%DynamicObject).%FromJSON(tBodyStr)
                If 'tDoc.%IsDefined("_id") {
                    Do tDoc.%Set("_id", tDocId)
                }
                If ##class(IRISCouch.Query.MangoSelector).Match(pSelector, tDoc) {
                    Do pDocs.%Push(tDoc)
                }
            }
            Catch tParseEx {
                Continue
            }
        }
        Quit
    }
    Catch ex {
        If '$IsObject(pDocs) Set pDocs = []
        Quit
    }
}

/// <p>Generate a base64url-encoded bookmark from last document ID and sort key.</p>
/// @param pLastDocId The last document ID
/// @param pLastKey The last sort key value
/// @return %String Base64url-encoded bookmark
ClassMethod GenerateBookmark(pLastDocId As %String, pLastKey As %String = "") As %String
{
    Set tBookmark = ""
    Try {
        Set tRaw = pLastDocId _ "|" _ pLastKey
        Set tB64 = $System.Encryption.Base64Encode(tRaw)
        ; Make URL-safe: + → -, / → _, remove =
        Set tBookmark = $Translate(tB64, "+/=", "-_")
        Quit
    }
    Catch ex {
        Quit
    }
    Quit tBookmark
}

/// <p>Decode a base64url-encoded bookmark back to document ID and sort key.</p>
/// @param pBookmark The bookmark string
/// @param pDocId Output: document ID
/// @param pKey Output: sort key
/// @return %Status
ClassMethod DecodeBookmark(pBookmark As %String, Output pDocId As %String, Output pKey As %String) As %Status
{
    Set tSC = $$$OK
    Set pDocId = ""
    Set pKey = ""
    Try {
        If pBookmark = "" || (pBookmark = "nil") Quit
        ; Reverse URL-safe: - → +, _ → /
        Set tB64 = $Translate(pBookmark, "-_", "+/")
        ; Add padding if needed
        Set tMod = $Length(tB64) # 4
        If tMod = 2 Set tB64 = tB64 _ "=="
        If tMod = 3 Set tB64 = tB64 _ "="
        Set tRaw = $System.Encryption.Base64Decode(tB64)
        Set pDocId = $Piece(tRaw, "|", 1)
        Set pKey = $Piece(tRaw, "|", 2, *)
        Quit
    }
    Catch ex {
        Set tSC = ex.AsStatus()
        Quit
    }
    Quit tSC
}

}
