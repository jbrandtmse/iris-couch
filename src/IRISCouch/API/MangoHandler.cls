/// <p>HTTP handler for Mango index management endpoints.</p>
/// <p>Handles <code>POST /{db}/_index</code> (create), <code>GET /{db}/_index</code>
/// (list), and <code>DELETE /{db}/_index/{ddoc}/{type}/{name}</code> (delete).</p>
Class IRISCouch.API.MangoHandler Extends %RegisteredObject
{

/// <p>Allowed top-level keys in a POST /_index request body.</p>
Parameter ALLOWEDKEYS = "index,name,ddoc,type,partial_filter_selector";

/// <p>Handle POST /{db}/_index — create a Mango index.</p>
/// @param pDB The database name
/// @return %Status
ClassMethod HandleCreateIndex(pDB As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        ; Validate database exists
        If '##class(IRISCouch.Storage.Database).Exists(pDB) {
            Do ##class(IRISCouch.Util.Error).Render(404, "not_found", "Database does not exist.")
            Quit
        }
        ; Read and parse request body
        Set tBody = ##class(IRISCouch.Util.Request).ReadBody()
        ; Validate no unknown top-level keys
        Set tAllowed = ..#ALLOWEDKEYS
        Set tIter = tBody.%GetIterator()
        While tIter.%GetNext(.tKey, .tVal) {
            If '$ListFind($ListFromString(tAllowed), tKey) {
                Do ##class(IRISCouch.Util.Error).Render(400, "invalid_key", "Unknown key: " _ tKey)
                Quit
            }
        }
        ; Check if we already quit due to unknown key
        If %response.Status = 400 Quit
        ; Validate index field
        Set tIndex = tBody.%Get("index")
        If '$IsObject(tIndex) {
            Do ##class(IRISCouch.Util.Error).Render(400, "bad_request", "Missing required field: index")
            Quit
        }
        ; Validate fields array
        Set tFields = tIndex.%Get("fields")
        If '$IsObject(tFields) || 'tFields.%IsA("%DynamicArray") || (tFields.%Size() = 0) {
            Do ##class(IRISCouch.Util.Error).Render(400, "bad_request", "Index fields must be a non-empty array")
            Quit
        }
        ; Validate and normalize each field
        Set tNormFields = []
        Set tFieldCount = tFields.%Size()
        For tI = 0:1:(tFieldCount - 1) {
            Set tField = tFields.%Get(tI)
            If $IsObject(tField) {
                ; Object like {"fieldname":"asc"} — validate it has one key
                Set tFIter = tField.%GetIterator()
                If 'tFIter.%GetNext(.tFName, .tFDir) {
                    Do ##class(IRISCouch.Util.Error).Render(400, "bad_request", "Invalid field definition")
                    Quit
                }
                If '$IsObject(tFName) && (tFName '= +tFName) {
                    ; Valid string key
                    Set tNormField = {}
                    Do tNormField.%Set(tFName, tFDir)
                    Do tNormFields.%Push(tNormField)
                } Else {
                    Do ##class(IRISCouch.Util.Error).Render(400, "bad_request", "Field name must be a string")
                    Quit
                }
            } Else {
                ; Bare value — must be a non-empty string to be a valid field name
                ; Use %GetTypeOf to distinguish strings from numbers in JSON
                Set tFieldType = tFields.%GetTypeOf(tI)
                If tFieldType '= "string" || (tField = "") {
                    Do ##class(IRISCouch.Util.Error).Render(400, "bad_request", "Field name must be a non-empty string")
                    Quit
                }
                Set tNormField = {}
                Do tNormField.%Set(tField, "asc")
                Do tNormFields.%Push(tNormField)
            }
        }
        ; Check if we quit due to validation error
        If %response.Status = 400 Quit
        Set tFieldsJson = tNormFields.%ToJSON()
        ; Validate type if provided
        Set tType = tBody.%Get("type")
        If tType '= "" {
            If tType '= "json" {
                Do ##class(IRISCouch.Util.Error).Render(400, "bad_request", "Only ""json"" type indexes are supported")
                Quit
            }
        } Else {
            Set tType = "json"
        }
        ; Validate name if provided
        Set tName = tBody.%Get("name")
        If tBody.%IsDefined("name") && (tName = "") {
            Do ##class(IRISCouch.Util.Error).Render(400, "bad_request", "Index name must be a non-empty string")
            Quit
        }
        ; Validate ddoc if provided
        Set tDDoc = tBody.%Get("ddoc")
        If tBody.%IsDefined("ddoc") && (tDDoc = "") {
            Do ##class(IRISCouch.Util.Error).Render(400, "bad_request", "Design document name must be a non-empty string")
            Quit
        }
        ; Handle partial_filter_selector
        Set tPartialFilter = ""
        If tBody.%IsDefined("partial_filter_selector") {
            Set tPFS = tBody.%Get("partial_filter_selector")
            If $IsObject(tPFS) {
                Set tPartialFilter = tPFS.%ToJSON()
            }
        }
        ; Auto-generate name if not provided
        If tName = "" {
            Set tName = ##class(IRISCouch.Projection.MangoIndexDef).GenerateName(tFieldsJson, tPartialFilter)
        }
        ; Handle ddoc: normalize and auto-generate if needed
        If tDDoc = "" {
            Set tDDoc = ##class(IRISCouch.Projection.MangoIndexDef).GenerateDDoc(tFieldsJson, tPartialFilter)
        } Else {
            ; Normalize: prepend _design/ if not present
            If $Extract(tDDoc, 1, 8) '= "_design/" {
                Set tDDoc = "_design/" _ tDDoc
            }
        }
        ; Check idempotency: identical definition already exists?
        Set tExistsDDoc = ""
        Set tExistsName = ""
        If ##class(IRISCouch.Projection.MangoIndexDef).FindByDefinition(pDB, tFieldsJson, tPartialFilter, .tExistsDDoc, .tExistsName) {
            Set tResult = {}
            Do tResult.%Set("result", "exists")
            Do tResult.%Set("id", tExistsDDoc)
            Do tResult.%Set("name", tExistsName)
            Do ##class(IRISCouch.Util.Response).JSON(tResult)
            Quit
        }
        ; Create the index definition
        Set tSC = ##class(IRISCouch.Projection.MangoIndexDef).Create(pDB, tDDoc, tName, tType, tFieldsJson, tPartialFilter)
        If $$$ISERR(tSC) {
            Do ##class(IRISCouch.Util.Error).RenderInternal("server_error", "Failed to create index definition")
            Quit
        }
        ; Backfill: index existing documents
        Do ..BackfillIndex(pDB, tDDoc, tName, tFieldsJson, tPartialFilter)
        ; Return success
        Set tResult = {}
        Do tResult.%Set("result", "created")
        Do tResult.%Set("id", tDDoc)
        Do tResult.%Set("name", tName)
        Do ##class(IRISCouch.Util.Response).JSON(tResult)
        Quit
    }
    Catch ex {
        Do ##class(IRISCouch.Util.Error).RenderInternal("server_error", "index: create error", ex)
        Quit
    }
    Quit $$$OK
}

/// <p>Handle GET /{db}/_index — list all Mango indexes.</p>
/// @param pDB The database name
/// @return %Status
ClassMethod HandleListIndexes(pDB As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        ; Validate database exists
        If '##class(IRISCouch.Storage.Database).Exists(pDB) {
            Do ##class(IRISCouch.Util.Error).Render(404, "not_found", "Database does not exist.")
            Quit
        }
        ; Build the indexes array, starting with the built-in _all_docs
        Set tIndexes = []
        ; _all_docs special index
        Set tAllDocs = {}
        Do tAllDocs.%Set("ddoc", "", "null")
        Do tAllDocs.%Set("name", "_all_docs")
        Do tAllDocs.%Set("type", "special")
        Set tAllDocsDef = {}
        Set tAllDocsFields = [{"_id":"asc"}]
        Do tAllDocsDef.%Set("fields", tAllDocsFields)
        Do tAllDocs.%Set("def", tAllDocsDef)
        Do tIndexes.%Push(tAllDocs)
        ; Get user-created indexes
        Set tUserIndexes = ##class(IRISCouch.Projection.MangoIndexDef).List(pDB)
        Set tUserCount = tUserIndexes.%Size()
        For tI = 0:1:(tUserCount - 1) {
            Do tIndexes.%Push(tUserIndexes.%Get(tI))
        }
        ; Build response
        Set tResult = {}
        Do tResult.%Set("total_rows", tIndexes.%Size(), "number")
        Do tResult.%Set("indexes", tIndexes)
        Do ##class(IRISCouch.Util.Response).JSON(tResult)
        Quit
    }
    Catch ex {
        Do ##class(IRISCouch.Util.Error).RenderInternal("server_error", "index: list error", ex)
        Quit
    }
    Quit $$$OK
}

/// <p>Handle DELETE /{db}/_index/{ddoc}/{type}/{name} — delete a Mango index.</p>
/// @param pDB The database name
/// @param pDDoc The design document segment from URL
/// @param pType The index type segment from URL
/// @param pName The index name segment from URL
/// @return %Status
ClassMethod HandleDeleteIndex(pDB As %String, pDDoc As %String, pType As %String, pName As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        ; Validate database exists
        If '##class(IRISCouch.Storage.Database).Exists(pDB) {
            Do ##class(IRISCouch.Util.Error).Render(404, "not_found", "Database does not exist.")
            Quit
        }
        ; Validate type
        If pType '= "json" {
            Do ##class(IRISCouch.Util.Error).Render(400, "bad_request", "Only ""json"" type indexes are supported")
            Quit
        }
        ; Normalize ddoc
        Set tDDoc = pDDoc
        If $Extract(tDDoc, 1, 8) '= "_design/" {
            Set tDDoc = "_design/" _ tDDoc
        }
        ; Check if index exists
        If '##class(IRISCouch.Projection.MangoIndexDef).Exists(pDB, tDDoc, pName) {
            Do ##class(IRISCouch.Util.Error).Render(404, "not_found", "Index not found")
            Quit
        }
        ; Delete index definition
        Set tSC = ##class(IRISCouch.Projection.MangoIndexDef).Delete(pDB, tDDoc, pName)
        If $$$ISERR(tSC) {
            Do ##class(IRISCouch.Util.Error).RenderInternal("server_error", "index: delete error")
            Quit
        }
        ; Delete associated MangoIndex rows
        Set tSC = ##class(IRISCouch.Projection.MangoIndex).DeleteForIndex(pDB, tDDoc, pName)
        If $$$ISERR(tSC) {
            Do ##class(IRISCouch.Util.Error).RenderInternal("server_error", "index: delete index rows error")
            Quit
        }
        ; Return success
        Do ##class(IRISCouch.Util.Response).JSON({"ok": true})
        Quit
    }
    Catch ex {
        Do ##class(IRISCouch.Util.Error).RenderInternal("server_error", "index: delete error", ex)
        Quit
    }
    Quit $$$OK
}

/// <p>Backfill MangoIndex rows for existing documents when a new index is created.</p>
/// <p>Iterates all documents in the database and creates MangoIndex rows for
/// each one based on the new index definition. Uses Winners projection for
/// fast body retrieval; falls back to Storage.Document + RevTree.GetWinner.</p>
/// @param pDB The database name
/// @param pDDoc The design document ID
/// @param pName The index name
/// @param pFieldsJson JSON string of normalized fields array
/// @param pPartialFilter JSON string of partial filter selector
ClassMethod BackfillIndex(pDB As %String, pDDoc As %String, pName As %String, pFieldsJson As %String, pPartialFilter As %String = "")
{
    Try {
        ; Build a single-element index def array for UpsertForDocument
        Set tIndexDef = {}
        Do tIndexDef.%Set("ddoc", pDDoc)
        Do tIndexDef.%Set("name", pName)
        Do tIndexDef.%Set("fields", pFieldsJson)
        Do tIndexDef.%Set("partialFilter", pPartialFilter)
        Set tIndexDefs = []
        Do tIndexDefs.%Push(tIndexDef)
        ; Iterate all documents in the database
        ; Use Winners projection for documents that have winner rows,
        ; and fall back to Storage + RevTree for any remaining documents.
        ; Build set of docs already indexed via Winners
        Set tIndexedDocs = ""
        Set tRS = ##class(%SQL.Statement).%ExecDirect(,
            "SELECT %EXACT(DocId) AS DocId, Body FROM IRISCouch_Projection.Winners WHERE %EXACT(DbName) = ? AND Deleted = 0", pDB)
        While tRS.%Next() {
            Set tDocId = tRS.%Get("DocId")
            Set tBodyStr = tRS.%Get("Body")
            Set tIndexedDocs(tDocId) = 1
            If tBodyStr = "" Continue
            Try {
                Set tBodyObj = ##class(%DynamicObject).%FromJSON(tBodyStr)
                Do ##class(IRISCouch.Projection.MangoIndex).UpsertForDocument(pDB, tDocId, tBodyObj, tIndexDefs)
            }
            Catch tInnerEx {
                ; Skip documents that fail to parse
                Continue
            }
        }
        ; Fall back to Storage + RevTree for any documents not in Winners
        Do ..BackfillFromStorage(pDB, tIndexDefs, .tIndexedDocs)
        Quit
    }
    Catch ex {
        ; Backfill errors are non-fatal — index is still created
        Quit
    }
}

/// <p>Backfill from raw storage for documents not already indexed via Winners.</p>
/// @param pDB The database name
/// @param pIndexDefs Index definitions array
/// @param pIndexedDocs ByRef array of doc IDs already indexed (subscript=docId)
ClassMethod BackfillFromStorage(pDB As %String, pIndexDefs As %DynamicArray, ByRef pIndexedDocs)
{
    Try {
        Set tDocIds = ##class(IRISCouch.Storage.Document).ListDocIds(pDB)
        Set tDocCount = tDocIds.%Size()
        For tI = 0:1:(tDocCount - 1) {
            Set tDocId = tDocIds.%Get(tI)
            ; Skip docs already indexed via Winners
            If $Get(pIndexedDocs(tDocId)) Continue
            Set tWinRev = ##class(IRISCouch.Storage.RevTree).GetWinner(pDB, tDocId)
            If tWinRev = "" Continue
            Set tBodyStr = ##class(IRISCouch.Storage.Document).Read(pDB, tDocId, tWinRev)
            If tBodyStr = "" Continue
            Try {
                Set tBodyObj = ##class(%DynamicObject).%FromJSON(tBodyStr)
                Do ##class(IRISCouch.Projection.MangoIndex).UpsertForDocument(pDB, tDocId, tBodyObj, pIndexDefs)
            }
            Catch tInnerEx {
                Continue
            }
        }
        Quit
    }
    Catch ex {
        Quit
    }
}

/// <p>Handle POST /{db}/_find — execute a Mango query.</p>
/// @param pDB The database name
/// @return %Status
ClassMethod HandleFind(pDB As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        ; Validate database exists
        If '##class(IRISCouch.Storage.Database).Exists(pDB) {
            Do ##class(IRISCouch.Util.Error).Render(404, "not_found", "Database does not exist.")
            Quit
        }
        ; Read and parse request body
        Set tBody = ##class(IRISCouch.Util.Request).ReadBody()
        ; Validate selector is present
        If 'tBody.%IsDefined("selector") {
            Do ##class(IRISCouch.Util.Error).Render(400, "bad_request", "Missing required field: selector")
            Quit
        }
        Set tSelector = tBody.%Get("selector")
        If '$IsObject(tSelector) {
            Do ##class(IRISCouch.Util.Error).Render(400, "bad_request", "Selector must be a JSON object")
            Quit
        }
        ; Build options object
        Set tOpts = {}
        If tBody.%IsDefined("limit") Do tOpts.%Set("limit", tBody.%Get("limit"))
        If tBody.%IsDefined("skip") Do tOpts.%Set("skip", tBody.%Get("skip"))
        If tBody.%IsDefined("sort") Do tOpts.%Set("sort", tBody.%Get("sort"))
        If tBody.%IsDefined("fields") Do tOpts.%Set("fields", tBody.%Get("fields"))
        If tBody.%IsDefined("bookmark") Do tOpts.%Set("bookmark", tBody.%Get("bookmark"))
        If tBody.%IsDefined("use_index") Do tOpts.%Set("use_index", tBody.%Get("use_index"))
        If tBody.%IsDefined("execution_stats") Do tOpts.%Set("execution_stats", tBody.%Get("execution_stats"))
        If tBody.%IsDefined("conflicts") Do tOpts.%Set("conflicts", tBody.%Get("conflicts"))
        If tBody.%IsDefined("allow_fallback") Do tOpts.%Set("allow_fallback", tBody.%Get("allow_fallback"))
        ; Execute query
        Set tQueryResult = ##class(IRISCouch.Query.MangoExecutor).Execute(pDB, tSelector, tOpts)
        ; Check for error in result
        If tQueryResult.%IsDefined("error") {
            Do ##class(IRISCouch.Util.Error).Render(400, tQueryResult.%Get("error"), tQueryResult.%Get("reason"))
            Quit
        }
        ; Return result
        Do ##class(IRISCouch.Util.Response).JSON(tQueryResult)
        Quit
    }
    Catch ex {
        Do ##class(IRISCouch.Util.Error).RenderInternal("server_error", "find: query error", ex)
        Quit
    }
    Quit $$$OK
}

/// <p>Handle POST /{db}/_explain — explain a Mango query plan.</p>
/// @param pDB The database name
/// @return %Status
ClassMethod HandleExplain(pDB As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        ; Validate database exists
        If '##class(IRISCouch.Storage.Database).Exists(pDB) {
            Do ##class(IRISCouch.Util.Error).Render(404, "not_found", "Database does not exist.")
            Quit
        }
        ; Read and parse request body
        Set tBody = ##class(IRISCouch.Util.Request).ReadBody()
        ; Validate selector
        If 'tBody.%IsDefined("selector") {
            Do ##class(IRISCouch.Util.Error).Render(400, "bad_request", "Missing required field: selector")
            Quit
        }
        Set tSelector = tBody.%Get("selector")
        If '$IsObject(tSelector) {
            Do ##class(IRISCouch.Util.Error).Render(400, "bad_request", "Selector must be a JSON object")
            Quit
        }
        ; Parse options
        Set tSort = ""
        If tBody.%IsDefined("sort") Set tSort = tBody.%Get("sort")
        Set tUseIndex = ""
        If tBody.%IsDefined("use_index") Set tUseIndex = tBody.%Get("use_index")
        Set tLimit = 25
        If tBody.%IsDefined("limit") Set tLimit = +tBody.%Get("limit")
        Set tSkip = 0
        If tBody.%IsDefined("skip") Set tSkip = +tBody.%Get("skip")
        Set tFields = ""
        If tBody.%IsDefined("fields") Set tFields = tBody.%Get("fields")
        Set tBookmark = ""
        If tBody.%IsDefined("bookmark") Set tBookmark = tBody.%Get("bookmark")
        ; Normalize selector
        Set tNormSelector = ##class(IRISCouch.Query.MangoSelector).Normalize(tSelector)
        ; Get query plan
        Set tPlan = ##class(IRISCouch.Query.MangoPlanner).ChooseIndex(pDB, tNormSelector, tSort, tUseIndex)
        ; Build response
        Set tResult = {}
        Do tResult.%Set("dbname", pDB)
        Do tResult.%Set("index", tPlan.%Get("index"))
        Do tResult.%Set("selector", tNormSelector)
        ; Build opts
        Set tOptsObj = {}
        If tUseIndex '= "" {
            Do tOptsObj.%Set("use_index", tUseIndex)
        } Else {
            Do tOptsObj.%Set("use_index", [])
        }
        If tBookmark '= "" {
            Do tOptsObj.%Set("bookmark", tBookmark)
        } Else {
            Do tOptsObj.%Set("bookmark", "nil")
        }
        Do tOptsObj.%Set("limit", tLimit, "number")
        Do tOptsObj.%Set("skip", tSkip, "number")
        If $IsObject(tSort) {
            Do tOptsObj.%Set("sort", tSort)
        } Else {
            Do tOptsObj.%Set("sort", {})
        }
        If $IsObject(tFields) {
            Do tOptsObj.%Set("fields", tFields)
        } Else {
            Do tOptsObj.%Set("fields", "all_fields")
        }
        Do tOptsObj.%Set("r", 1, "number")
        Do tOptsObj.%Set("conflicts", 0, "boolean")
        Do tOptsObj.%Set("execution_stats", 0, "boolean")
        Do tResult.%Set("opts", tOptsObj)
        Do tResult.%Set("limit", tLimit, "number")
        Do tResult.%Set("skip", tSkip, "number")
        If $IsObject(tFields) {
            Do tResult.%Set("fields", tFields)
        } Else {
            Do tResult.%Set("fields", "all_fields")
        }
        Do tResult.%Set("index_candidates", tPlan.%Get("candidates"))
        ; Return result
        Do ##class(IRISCouch.Util.Response).JSON(tResult)
        Quit
    }
    Catch ex {
        Do ##class(IRISCouch.Util.Error).RenderInternal("server_error", "explain: query plan error", ex)
        Quit
    }
    Quit $$$OK
}

}
