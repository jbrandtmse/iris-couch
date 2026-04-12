/// <p>HTTP handler for _all_docs view operations.</p>
/// <p>Handles <code>GET /{db}/_all_docs</code> (list all documents with pagination)
/// and <code>POST /{db}/_all_docs</code> (retrieve documents by specific keys).
/// Extracted from <class>IRISCouch.API.DocumentHandler</class> for separation of concerns.</p>
/// <h4>Known encapsulation exception:</h4>
/// <p>The <code>$Order(^IRISCouch.Docs(...))</code> iteration in HandleAllDocs is a known
/// storage encapsulation exception. The loop logic is tightly coupled to pagination
/// parameters (skip, limit, startkey, endkey, descending). Creating a full iterator
/// abstraction would add complexity without clear value. See deferred-work.md.</p>
Class IRISCouch.API.AllDocsHandler Extends %RegisteredObject
{

/// <p>Handle <code>GET /{db}/_all_docs</code> — list all documents with pagination and key-range filtering.</p>
/// <p>Returns rows sorted by document ID ascending. Supports <code>limit</code>, <code>skip</code>,
/// <code>startkey</code>, <code>endkey</code>, <code>inclusive_end</code>, <code>descending</code>,
/// and <code>include_docs</code> query parameters.</p>
/// <p><b>Note:</b> The <code>$Order(^IRISCouch.Docs(...))</code> iteration is a known
/// storage encapsulation exception documented in deferred-work.md.</p>
/// @param pDB The database name from the URL path
/// @return %Status
ClassMethod HandleAllDocs(pDB As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        ; Check database exists
        If '##class(IRISCouch.Storage.Database).Exists(pDB) {
            Do ##class(IRISCouch.Util.Error).Render(404, ##class(IRISCouch.Util.Error).#NOTFOUND, "Database does not exist.")
            Quit
        }
        ; Parse query parameters
        Set tLimit = $Get(%request.Data("limit", 1))
        Set tSkip = +$Get(%request.Data("skip", 1))
        Set tStartKey = $Get(%request.Data("startkey", 1))
        Set tEndKey = $Get(%request.Data("endkey", 1))
        Set tIncludeDocs = ($Get(%request.Data("include_docs", 1)) = "true")
        Set tDescending = ($Get(%request.Data("descending", 1)) = "true")
        Set tInclusiveEnd = 1
        If $Data(%request.Data("inclusive_end", 1)) {
            Set tInclusiveEnd = ($Get(%request.Data("inclusive_end", 1)) '= "false")
        }
        ; Strip surrounding quotes from startkey/endkey (CouchDB JSON-encodes them)
        If ($Extract(tStartKey, 1) = """") {
            Set tStartKey = $Extract(tStartKey, 2, $Length(tStartKey) - 1)
        }
        If ($Extract(tEndKey, 1) = """") {
            Set tEndKey = $Extract(tEndKey, 2, $Length(tEndKey) - 1)
        }
        ; Get total_rows (all non-deleted docs, unaffected by filters)
        Set tTotalRows = ##class(IRISCouch.Storage.Document).CountNonDeleted(pDB)
        ; Handle descending: swap start/end keys for $Order direction
        Set tDirection = 1
        If tDescending {
            Set tDirection = -1
            ; Swap startkey and endkey for descending
            Set tTemp = tStartKey
            Set tStartKey = tEndKey
            Set tEndKey = tTemp
        }
        ; Build rows
        Set tRows = []
        Set tSkipped = 0
        Set tCount = 0
        ; Determine starting point for $Order
        ; NOTE: Direct ^IRISCouch.Docs iteration — known encapsulation exception (see class doc)
        If tStartKey '= "" {
            ; Start just before startkey so $Order returns startkey first
            If tDirection = 1 {
                Set tDocId = $Order(^IRISCouch.Docs(pDB, tStartKey), 1)
                ; Check if startkey itself exists
                If $Data(^IRISCouch.Docs(pDB, tStartKey)) {
                    Set tDocId = tStartKey
                }
            } Else {
                Set tDocId = $Order(^IRISCouch.Docs(pDB, tStartKey), -1)
                If $Data(^IRISCouch.Docs(pDB, tStartKey)) {
                    Set tDocId = tStartKey
                }
            }
        } Else {
            Set tDocId = $Order(^IRISCouch.Docs(pDB, ""), tDirection)
        }
        ; Iterate through documents
        For {
            Quit:tDocId=""
            ; Apply endkey filtering
            If tEndKey '= "" {
                If tDirection = 1 {
                    If tInclusiveEnd {
                        Quit:(tDocId]tEndKey)
                    } Else {
                        Quit:(tDocId]]tEndKey)!(tDocId=tEndKey)
                    }
                } Else {
                    If tInclusiveEnd {
                        Quit:(tEndKey]tDocId)
                    } Else {
                        Quit:(tEndKey]]tDocId)!(tDocId=tEndKey)
                    }
                }
            }
            ; Get winning rev, skip deleted
            Set tWinRev = ##class(IRISCouch.Storage.RevTree).GetWinner(pDB, tDocId)
            If tWinRev = "" {
                Set tDocId = $Order(^IRISCouch.Docs(pDB, tDocId), tDirection)
                Continue
            }
            If ##class(IRISCouch.Storage.RevTree).IsDeleted(pDB, tDocId, tWinRev) {
                Set tDocId = $Order(^IRISCouch.Docs(pDB, tDocId), tDirection)
                Continue
            }
            ; Apply skip
            If tSkipped < tSkip {
                Set tSkipped = tSkipped + 1
                Set tDocId = $Order(^IRISCouch.Docs(pDB, tDocId), tDirection)
                Continue
            }
            ; Apply limit
            If (tLimit '= "") && (tCount >= +tLimit) {
                Quit
            }
            ; Build row
            Set tRow = {}
            Do tRow.%Set("id", tDocId)
            Do tRow.%Set("key", tDocId)
            Set tValue = {}
            Do tValue.%Set("rev", tWinRev)
            Do tRow.%Set("value", tValue)
            ; Include full document body if requested
            If tIncludeDocs {
                Set tBodyStr = ##class(IRISCouch.Storage.Document).Read(pDB, tDocId, tWinRev)
                If tBodyStr '= "" {
                    Set tDocObj = ##class(%DynamicObject).%FromJSON(tBodyStr)
                    ; Inject _id and _rev
                    Set tFullDoc = {}
                    Do tFullDoc.%Set("_id", tDocId)
                    Do tFullDoc.%Set("_rev", tWinRev)
                    Set tDocIter = tDocObj.%GetIterator()
                    While tDocIter.%GetNext(.tDKey, .tDVal) {
                        Do tFullDoc.%Set(tDKey, tDVal)
                    }
                    Do tRow.%Set("doc", tFullDoc)
                }
            }
            Do tRows.%Push(tRow)
            Set tCount = tCount + 1
            Set tDocId = $Order(^IRISCouch.Docs(pDB, tDocId), tDirection)
        }
        ; Build response
        Set tResp = {}
        Do tResp.%Set("total_rows", tTotalRows, "number")
        Do tResp.%Set("offset", tSkip, "number")
        Do tResp.%Set("rows", tRows)
        Do ##class(IRISCouch.Util.Response).JSON(tResp)
        Quit
    }
    Catch ex {
        Do ##class(IRISCouch.Util.Error).RenderInternal(##class(IRISCouch.Util.Error).#SERVERERROR, "document: all_docs error", ex)
        Quit
    }
    Quit $$$OK
}

/// <p>Handle <code>POST /{db}/_all_docs</code> — retrieve documents by specific keys.</p>
/// <p>Accepts a JSON body with a <code>keys</code> array. Returns rows in the same
/// order as the keys array. Missing or deleted documents get an error row.</p>
/// @param pDB The database name from the URL path
/// @return %Status
ClassMethod HandleAllDocsPost(pDB As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        ; Check database exists
        If '##class(IRISCouch.Storage.Database).Exists(pDB) {
            Do ##class(IRISCouch.Util.Error).Render(404, ##class(IRISCouch.Util.Error).#NOTFOUND, "Database does not exist.")
            Quit
        }
        ; Read JSON body
        Set tContent = ""
        If $IsObject(%request.Content) {
            Set tContent = %request.Content.Read()
        }
        If tContent = "" {
            Do ##class(IRISCouch.Util.Error).Render(400, ##class(IRISCouch.Util.Error).#BADREQUEST, "Request body is empty or missing.")
            Quit
        }
        ; Parse body
        Try {
            Set tBody = ##class(%DynamicObject).%FromJSON(tContent)
        } Catch tParseEx {
            Do ##class(IRISCouch.Util.Error).Render(400, ##class(IRISCouch.Util.Error).#BADREQUEST, "invalid UTF-8 JSON")
            Quit
        }
        ; Extract keys array
        If 'tBody.%IsDefined("keys") || (tBody.%GetTypeOf("keys") '= "array") {
            Do ##class(IRISCouch.Util.Error).Render(400, ##class(IRISCouch.Util.Error).#BADREQUEST, "Request body must contain a ""keys"" array.")
            Quit
        }
        Set tKeys = tBody.%Get("keys")
        ; Parse include_docs from query params
        Set tIncludeDocs = ($Get(%request.Data("include_docs", 1)) = "true")
        ; Get total_rows
        Set tTotalRows = ##class(IRISCouch.Storage.Document).CountNonDeleted(pDB)
        ; Build rows in order of keys array
        Set tRows = []
        Set tI = 0
        While tI < tKeys.%Size() {
            Set tDocId = tKeys.%Get(tI)
            Set tI = tI + 1
            ; Look up the document
            Set tWinRev = ##class(IRISCouch.Storage.RevTree).GetWinner(pDB, tDocId)
            If (tWinRev = "") || (##class(IRISCouch.Storage.RevTree).IsDeleted(pDB, tDocId, tWinRev)) {
                ; Not found or deleted — error row
                Set tRow = {}
                Do tRow.%Set("key", tDocId)
                Do tRow.%Set("error", "not_found")
                Do tRows.%Push(tRow)
                Continue
            }
            ; Found — normal row
            Set tRow = {}
            Do tRow.%Set("id", tDocId)
            Do tRow.%Set("key", tDocId)
            Set tValue = {}
            Do tValue.%Set("rev", tWinRev)
            Do tRow.%Set("value", tValue)
            ; Include full document body if requested
            If tIncludeDocs {
                Set tBodyStr = ##class(IRISCouch.Storage.Document).Read(pDB, tDocId, tWinRev)
                If tBodyStr '= "" {
                    Set tDocObj = ##class(%DynamicObject).%FromJSON(tBodyStr)
                    Set tFullDoc = {}
                    Do tFullDoc.%Set("_id", tDocId)
                    Do tFullDoc.%Set("_rev", tWinRev)
                    Set tDocIter = tDocObj.%GetIterator()
                    While tDocIter.%GetNext(.tDKey, .tDVal) {
                        Do tFullDoc.%Set(tDKey, tDVal)
                    }
                    Do tRow.%Set("doc", tFullDoc)
                }
            }
            Do tRows.%Push(tRow)
        }
        ; Build response
        Set tResp = {}
        Do tResp.%Set("total_rows", tTotalRows, "number")
        Do tResp.%Set("offset", 0, "number")
        Do tResp.%Set("rows", tRows)
        Do ##class(IRISCouch.Util.Response).JSON(tResp)
        Quit
    }
    Catch ex {
        Do ##class(IRISCouch.Util.Error).RenderInternal(##class(IRISCouch.Util.Error).#SERVERERROR, "document: all_docs_post error", ex)
        Quit
    }
    Quit $$$OK
}

}
