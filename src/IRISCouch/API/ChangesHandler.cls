/// <p>HTTP handler for the CouchDB-compatible changes feed.</p>
/// <p>Handles <code>GET /{db}/_changes</code> and <code>POST /{db}/_changes</code>
/// for <code>feed=normal</code> mode. Returns a snapshot of all document changes
/// up to the current sequence number.</p>
/// <p>Supports query parameters: <code>since</code>, <code>limit</code>,
/// <code>include_docs</code>, <code>style</code>, <code>descending</code>,
/// and <code>feed</code>.</p>
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
        ; Validate feed mode — only "normal" supported in this story
        If (tFeed '= "normal") && (tFeed '= "") {
            Do ##class(IRISCouch.Util.Error).Render(400, ##class(IRISCouch.Util.Error).#BADREQUEST, "Feed mode not yet supported")
            Quit
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
            ; Build the result entry
            Set tResultEntry = {}
            Do tResultEntry.%Set("seq", tSeq, "number")
            Do tResultEntry.%Set("id", tDocId)
            ; Check if this is a deleted document
            Set tIsDeleted = ##class(IRISCouch.Storage.RevTree).IsDeleted(pDB, tDocId, tRev)
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
                    Set tBodyStr = ##class(IRISCouch.Storage.Document).Read(pDB, tDocId, tRev)
                    If tBodyStr '= "" {
                        Set tDocObj = ##class(%DynamicObject).%FromJSON(tBodyStr)
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

}
