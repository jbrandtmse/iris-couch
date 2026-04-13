/// <p>HTTP handler for the CouchDB-compatible changes feed.</p>
/// <p>Handles <code>GET /{db}/_changes</code> and <code>POST /{db}/_changes</code>
/// for <code>feed=normal</code> and <code>feed=longpoll</code> modes.</p>
/// <p>In <code>longpoll</code> mode, if no new changes exist since the client's
/// <code>since</code> value, the request blocks until a new change arrives via
/// <code>$System.Event</code> or the <code>timeout</code> expires.</p>
/// <p>Supports query parameters: <code>since</code>, <code>limit</code>,
/// <code>include_docs</code>, <code>style</code>, <code>descending</code>,
/// <code>feed</code>, <code>timeout</code>, <code>heartbeat</code>, and
/// <code>filter</code>.</p>
/// <p>Built-in filters: <code>_doc_ids</code>, <code>_selector</code>,
/// <code>_design</code>.</p>
Class IRISCouch.API.ChangesHandler Extends %RegisteredObject
{

/// <p>Handle both GET and POST <code>/{db}/_changes</code> requests.</p>
/// <p>For POST requests, parameters are read from the JSON body with query string
/// parameters taking precedence (CouchDB behavior). For GET requests, all parameters
/// come from the query string.</p>
/// @param pDB The database name from the URL path
/// @return %Status
ClassMethod HandleChanges(pDB As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        ; Check database exists
        If '##class(IRISCouch.Storage.Database).Exists(pDB) {
            Do ##class(IRISCouch.Util.Error).Render(404, ##class(IRISCouch.Util.Error).#NOTFOUND, "Database does not exist.")
            Quit
        }
        ; Initialize defaults
        Set tSince = 0
        Set tLimit = 0
        Set tIncludeDocs = 0
        Set tStyle = "main_only"
        Set tDescending = 0
        Set tFeed = "normal"
        Set tTimeout = 60000
        Set tHeartbeat = 0
        Set tFilter = ""
        Set tDocIdsParam = ""
        Set tSelectorObj = ""
        Set tBodyObj = ""
        ; For POST: read body parameters first (body is base, query overrides)
        If %request.Method = "POST" {
            Set tContent = ""
            If $IsObject(%request.Content) {
                Set tContent = %request.Content.Read()
            }
            If tContent '= "" {
                Try {
                    Set tBodyObj = ##class(%DynamicObject).%FromJSON(tContent)
                } Catch tParseEx {
                    Do ##class(IRISCouch.Util.Error).Render(400, ##class(IRISCouch.Util.Error).#BADREQUEST, "invalid UTF-8 JSON")
                    Return $$$OK
                }
                ; Extract parameters from body
                If tBodyObj.%IsDefined("since") {
                    Set tSince = +tBodyObj.%Get("since")
                }
                If tBodyObj.%IsDefined("limit") {
                    Set tLimit = +tBodyObj.%Get("limit")
                }
                If tBodyObj.%IsDefined("include_docs") {
                    Set tIncludeDocs = (tBodyObj.%Get("include_docs") = 1) || (tBodyObj.%Get("include_docs") = "true")
                }
                If tBodyObj.%IsDefined("style") {
                    Set tStyle = tBodyObj.%Get("style")
                }
                If tBodyObj.%IsDefined("descending") {
                    Set tDescending = (tBodyObj.%Get("descending") = 1) || (tBodyObj.%Get("descending") = "true")
                }
                If tBodyObj.%IsDefined("feed") {
                    Set tFeed = tBodyObj.%Get("feed")
                }
                If tBodyObj.%IsDefined("timeout") {
                    Set tTimeout = +tBodyObj.%Get("timeout")
                }
                If tBodyObj.%IsDefined("heartbeat") {
                    Set tHeartbeat = +tBodyObj.%Get("heartbeat")
                }
                If tBodyObj.%IsDefined("filter") {
                    Set tFilter = tBodyObj.%Get("filter")
                }
                If tBodyObj.%IsDefined("doc_ids") {
                    Set tDocIdsParam = tBodyObj.%Get("doc_ids")
                }
                If tBodyObj.%IsDefined("selector") {
                    Set tSelectorObj = tBodyObj.%Get("selector")
                }
            }
        }
        ; Query string parameters override body parameters
        If $Data(%request.Data("since", 1)) {
            Set tSince = +$Get(%request.Data("since", 1))
        }
        If $Data(%request.Data("limit", 1)) {
            Set tLimit = +$Get(%request.Data("limit", 1))
        }
        If $Data(%request.Data("include_docs", 1)) {
            Set tIncludeDocs = ($Get(%request.Data("include_docs", 1)) = "true")
        }
        If $Data(%request.Data("style", 1)) {
            Set tStyle = $Get(%request.Data("style", 1))
        }
        If $Data(%request.Data("descending", 1)) {
            Set tDescending = ($Get(%request.Data("descending", 1)) = "true")
        }
        If $Data(%request.Data("feed", 1)) {
            Set tFeed = $Get(%request.Data("feed", 1))
        }
        If $Data(%request.Data("timeout", 1)) {
            Set tTimeout = +$Get(%request.Data("timeout", 1))
        }
        If $Data(%request.Data("heartbeat", 1)) {
            Set tHeartbeat = +$Get(%request.Data("heartbeat", 1))
        }
        If $Data(%request.Data("filter", 1)) {
            Set tFilter = $Get(%request.Data("filter", 1))
        }
        If $Data(%request.Data("doc_ids", 1)) {
            Set tDocIdsParam = $Get(%request.Data("doc_ids", 1))
        }
        ; Validate filter value
        If (tFilter '= "") && (tFilter '= "_doc_ids") && (tFilter '= "_selector") && (tFilter '= "_design") {
            Do ##class(IRISCouch.Util.Error).Render(404, ##class(IRISCouch.Util.Error).#NOTFOUND, "missing")
            Quit
        }
        ; Build doc_ids lookup array for _doc_ids filter
        If tFilter = "_doc_ids" {
            ; doc_ids from query string is a JSON-encoded array string
            If '$IsObject(tDocIdsParam) && (tDocIdsParam '= "") {
                Try {
                    Set tDocIdsParam = ##class(%DynamicArray).%FromJSON(tDocIdsParam)
                } Catch tParseDocIds {
                    ; Invalid JSON — treat as empty
                    Set tDocIdsParam = ##class(%DynamicArray).%New()
                }
            }
            If $IsObject(tDocIdsParam) {
                Set tDI = 0
                While tDI < tDocIdsParam.%Size() {
                    Set tDocIdFilter(tDocIdsParam.%Get(tDI)) = 1
                    Set tDI = tDI + 1
                }
            }
        }
        ; Parse selector for _selector filter
        If tFilter = "_selector" {
            If '$IsObject(tSelectorObj) {
                Set tSelectorObj = {}
            }
        }
        ; Clamp negative timeout to 0 (immediate return)
        If tTimeout < 0 Set tTimeout = 0
        ; Validate feed mode — accept "normal", "", and "longpoll"
        If (tFeed '= "normal") && (tFeed '= "") && (tFeed '= "longpoll") {
            Do ##class(IRISCouch.Util.Error).Render(400, ##class(IRISCouch.Util.Error).#BADREQUEST, "Feed mode not yet supported")
            Quit
        }
        ; Longpoll mode: block until new changes arrive or timeout
        If tFeed = "longpoll" {
            Set tLastSeq = ##class(IRISCouch.Storage.Changes).GetLastSeq(pDB)
            If tLastSeq <= tSince {
                ; No new changes — enter wait loop
                Set tEventName = "^IRISCouch.LPChanges(""" _ pDB _ """)"
                Set tEvtCreate = ##class(%SYSTEM.Event).Create(tEventName)
                If tHeartbeat > 0 {
                    ; Heartbeat mode: wait in intervals, send newlines to keep alive
                    Set tElapsed = 0
                    Set tHeartbeatSec = tHeartbeat / 1000
                    Set tTimeoutSec = tTimeout / 1000
                    For {
                        ; Cap wait interval at remaining time so heartbeat > timeout is respected
                        Set tRemainingSec = tTimeoutSec - (tElapsed / 1000)
                        If tRemainingSec <= 0 Quit
                        Set tWaitSec = $Select(tHeartbeatSec < tRemainingSec : tHeartbeatSec, 1 : tRemainingSec)
                        Set tResult = ##class(%SYSTEM.Event).WaitMsg(tEventName, tWaitSec)
                        If $ListGet(tResult, 1) '= 0 {
                            ; Event received — changes happened
                            Quit
                        }
                        ; Timeout on wait — send heartbeat
                        Do %response.Write($Char(10))
                        Do %response.Flush()
                        Set tElapsed = tElapsed + (tWaitSec * 1000)
                        If tElapsed >= tTimeout {
                            ; Total timeout expired — return empty results
                            Quit
                        }
                    }
                } Else {
                    ; No heartbeat: wait for full timeout
                    Set tTimeoutSec = tTimeout / 1000
                    Set tResult = ##class(%SYSTEM.Event).WaitMsg(tEventName, tTimeoutSec)
                }
                ; Re-check for changes after wait
                Set tLastSeqNow = ##class(IRISCouch.Storage.Changes).GetLastSeq(pDB)
                If tLastSeqNow <= tSince {
                    ; Timeout with no new changes — return empty results
                    Set tResp = {}
                    Set tResp.results = []
                    Do tResp.%Set("last_seq", tSince, "number")
                    Do tResp.%Set("pending", 0, "number")
                    Do ##class(IRISCouch.Util.Response).JSON(tResp)
                    Quit
                }
                ; Fall through to normal processing with new changes
            }
            ; If lastSeq > tSince, changes exist — fall through to normal processing
        }
        ; Get raw changes from storage
        Set tRaw = ##class(IRISCouch.Storage.Changes).ListChanges(pDB, tSince, tLimit, tDescending)
        Set tRawResults = tRaw.%Get("results")
        ; Post-process each result entry
        Set tFinalResults = []
        Set tI = 0
        While tI < tRawResults.%Size() {
            Set tEntry = tRawResults.%Get(tI)
            Set tI = tI + 1
            Set tDocId = tEntry.%Get("id")
            Set tSeq = tEntry.%Get("seq")
            ; Get the rev from the first changes entry
            Set tRev = tEntry.%Get("changes").%Get(0).%Get("rev")
            ; Apply filter early — skip non-matching entries before other processing
            Set tSelectorDocObj = ""
            If tFilter = "_doc_ids" {
                If '$Data(tDocIdFilter(tDocId)) Continue
            } ElseIf tFilter = "_design" {
                If $Extract(tDocId, 1, 8) '= "_design/" Continue
            } ElseIf tFilter = "_selector" {
                ; Skip deleted documents for selector filter
                Set tIsDeletedForFilter = ##class(IRISCouch.Storage.RevTree).IsDeleted(pDB, tDocId, tRev)
                If tIsDeletedForFilter Continue
                ; Read document body and match against selector
                Set tDocBodyStr = ##class(IRISCouch.Storage.Document).Read(pDB, tDocId, tRev)
                If tDocBodyStr = "" Continue
                Try {
                    Set tSelectorDocObj = ##class(%DynamicObject).%FromJSON(tDocBodyStr)
                } Catch tFilterParseEx {
                    Continue
                }
                If '..MatchesSelector(tSelectorObj, tSelectorDocObj) Continue
            }
            ; Build the result entry
            Set tResultEntry = {}
            Do tResultEntry.%Set("seq", tSeq, "number")
            Do tResultEntry.%Set("id", tDocId)
            ; Check if this is a deleted document
            If tFilter '= "_selector" {
                Set tIsDeleted = ##class(IRISCouch.Storage.RevTree).IsDeleted(pDB, tDocId, tRev)
            } Else {
                Set tIsDeleted = 0
            }
            If tIsDeleted {
                Do tResultEntry.%Set("deleted", 1, "boolean")
            }
            ; Handle style=all_docs: replace changes array with all leaf revisions
            If tStyle = "all_docs" {
                Set tLeafRevs = ##class(IRISCouch.Storage.RevTree).GetLeafRevs(pDB, tDocId)
                Set tChangesArr = []
                Set tJ = 0
                While tJ < tLeafRevs.%Size() {
                    Set tLeafRev = tLeafRevs.%Get(tJ)
                    Set tJ = tJ + 1
                    Set tRevObj = {}
                    Do tRevObj.%Set("rev", tLeafRev)
                    Do tChangesArr.%Push(tRevObj)
                }
                Do tResultEntry.%Set("changes", tChangesArr)
            } Else {
                ; Default style=main_only: single winning rev
                Set tChangesArr = []
                Set tRevObj = {}
                Do tRevObj.%Set("rev", tRev)
                Do tChangesArr.%Push(tRevObj)
                Do tResultEntry.%Set("changes", tChangesArr)
            }
            ; Handle include_docs
            If tIncludeDocs {
                If tIsDeleted {
                    Set tDocObj = {}
                    Do tDocObj.%Set("_id", tDocId)
                    Do tDocObj.%Set("_rev", tRev)
                    Do tDocObj.%Set("_deleted", 1, "boolean")
                    Do tResultEntry.%Set("doc", tDocObj)
                } Else {
                    ; Reuse doc object from _selector filter if available
                    If $IsObject(tSelectorDocObj) {
                        Set tDocObj = tSelectorDocObj
                    } Else {
                        Set tBodyStr = ##class(IRISCouch.Storage.Document).Read(pDB, tDocId, tRev)
                        If tBodyStr = "" {
                            Set tDocObj = ""
                        } Else {
                            Set tDocObj = ##class(%DynamicObject).%FromJSON(tBodyStr)
                        }
                    }
                    If $IsObject(tDocObj) {
                        Set tFullDoc = {}
                        Do tFullDoc.%Set("_id", tDocId)
                        Do tFullDoc.%Set("_rev", tRev)
                        Set tDocIter = tDocObj.%GetIterator()
                        While tDocIter.%GetNext(.tDKey, .tDVal) {
                            Do tFullDoc.%Set(tDKey, tDVal)
                        }
                        Do tResultEntry.%Set("doc", tFullDoc)
                    }
                }
            }
            Do tFinalResults.%Push(tResultEntry)
        }
        ; Build response
        Set tResp = {}
        Do tResp.%Set("results", tFinalResults)
        Do tResp.%Set("last_seq", tRaw.%Get("lastSeq"), "number")
        Do tResp.%Set("pending", tRaw.%Get("pending"), "number")
        Do ##class(IRISCouch.Util.Response).JSON(tResp)
        Quit
    }
    Catch ex {
        Do ##class(IRISCouch.Util.Error).RenderInternal(##class(IRISCouch.Util.Error).#SERVERERROR, "changes: feed error", ex)
        Quit
    }
    Quit $$$OK
}

/// <p>Match a document against a Mango selector (simple subset).</p>
/// <p>Supports equality, <code>$eq</code>, and <code>$exists</code> operators.
/// Unsupported operators match permissively (return true).
/// All selector conditions must match (implicit <code>$and</code>).</p>
/// @param pSelector The Mango selector as a %DynamicObject
/// @param pDoc The document body as a %DynamicObject
/// @return %Boolean 1 if document matches, 0 otherwise
ClassMethod MatchesSelector(pSelector As %DynamicObject, pDoc As %DynamicObject) As %Boolean
{
    Set tResult = 1
    Try {
        If '$IsObject(pSelector) Quit
        If '$IsObject(pDoc) Quit
        Set tIter = pSelector.%GetIterator()
        While tIter.%GetNext(.tKey, .tVal) {
            If '$IsObject(tVal) {
                ; Scalar value — equality check
                If pDoc.%Get(tKey) '= tVal {
                    Set tResult = 0
                    Quit
                }
            } Else {
                ; Value is an object — check for operators
                Set tOpIter = tVal.%GetIterator()
                Set tHasOperator = 0
                Set tAllOpsMatch = 1
                While tOpIter.%GetNext(.tOpKey, .tOpVal) {
                    If $Extract(tOpKey, 1) = "$" {
                        Set tHasOperator = 1
                        If tOpKey = "$eq" {
                            If pDoc.%Get(tKey) '= tOpVal {
                                Set tAllOpsMatch = 0
                                Quit
                            }
                        } ElseIf tOpKey = "$exists" {
                            Set tFieldExists = pDoc.%IsDefined(tKey)
                            If tOpVal = 1 || (tOpVal = "true") {
                                If 'tFieldExists {
                                    Set tAllOpsMatch = 0
                                    Quit
                                }
                            } Else {
                                If tFieldExists {
                                    Set tAllOpsMatch = 0
                                    Quit
                                }
                            }
                        }
                        ; Unknown operators ($gt, $lt, etc.) — permissive, match all
                    }
                }
                If tHasOperator {
                    If 'tAllOpsMatch {
                        Set tResult = 0
                        Quit
                    }
                } Else {
                    ; No operators found — nested object equality
                    ; Treat as literal value equality (compare JSON)
                    Set tDocVal = pDoc.%Get(tKey)
                    If '$IsObject(tDocVal) {
                        Set tResult = 0
                        Quit
                    }
                    ; Compare by serializing both to JSON
                    If tVal.%ToJSON() '= tDocVal.%ToJSON() {
                        Set tResult = 0
                        Quit
                    }
                }
            }
        }
        Quit
    }
    Catch ex {
        ; On error, match permissively
        Set tResult = 1
        Quit
    }
    Quit tResult
}

}
