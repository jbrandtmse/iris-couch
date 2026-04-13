/// <p>HTTP handler for attachment CRUD operations.</p>
/// <p>Handles <code>PUT /{db}/{docid}/{attname}</code> (upload attachment),
/// <code>GET /{db}/{docid}/{attname}</code> (download attachment),
/// and <code>DELETE /{db}/{docid}/{attname}</code> (remove attachment).
/// Delegates to <class>IRISCouch.Core.DocumentEngine</class> for writes
/// and <class>IRISCouch.Storage.Attachment</class> for reads.</p>
/// <p>All binary I/O is stream-based to satisfy NFR-P8 (memory bounded
/// by stream buffer size, not attachment size).</p>
Class IRISCouch.API.AttachmentHandler Extends %RegisteredObject
{

/// <p>Handle <code>PUT /{db}/{docid}/{attname}</code> — upload a binary attachment.</p>
/// <p>Reads the binary body as a stream (NFR-P8 compliant), validates database
/// and document existence, checks revision for concurrency, stores the attachment,
/// and creates a new document revision.</p>
/// @param pDB The database name from the URL path
/// @param pDocId The document identifier from the URL path
/// @param pAttName The attachment filename from the URL path
/// @return %Status
ClassMethod HandlePut(pDB As %String, pDocId As %String, pAttName As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        ; Check database exists
        If '##class(IRISCouch.Storage.Database).Exists(pDB) {
            Do ##class(IRISCouch.Util.Error).Render(404, ##class(IRISCouch.Util.Error).#NOTFOUND, "Database does not exist.")
            Quit
        }
        ; Get rev from query param
        Set tRev = ""
        If $Data(%request.Data("rev", 1)) {
            Set tRev = $Get(%request.Data("rev", 1))
        }
        ; Optimistic concurrency check for existing documents
        If ##class(IRISCouch.Storage.Document).Exists(pDB, pDocId) {
            If tRev = "" {
                Do ##class(IRISCouch.Util.Error).Render(409, ##class(IRISCouch.Util.Error).#CONFLICT, "Document update conflict.")
                Quit
            }
            ; Verify rev matches current winner
            Set tCurrentWinner = ##class(IRISCouch.Storage.RevTree).GetWinner(pDB, pDocId)
            If tRev '= tCurrentWinner {
                Do ##class(IRISCouch.Util.Error).Render(409, ##class(IRISCouch.Util.Error).#CONFLICT, "Document update conflict.")
                Quit
            }
        }
        ; Get Content-Type from request
        Set tContentType = %request.ContentType
        If tContentType = "" {
            Set tContentType = "application/octet-stream"
        }
        ; Read binary body as stream — %request.Content IS the stream (NFR-P8)
        If '$IsObject(%request.Content) {
            Do ##class(IRISCouch.Util.Error).Render(400, ##class(IRISCouch.Util.Error).#BADREQUEST, "Request body is empty or missing.")
            Quit
        }
        Set tStream = %request.Content
        ; Save attachment via DocumentEngine (creates new revision in transaction)
        Set tNewRev = ##class(IRISCouch.Core.DocumentEngine).SaveAttachment(pDB, pDocId, tRev, pAttName, tContentType, tStream)
        If tNewRev = "" {
            Do ##class(IRISCouch.Util.Error).RenderInternal(##class(IRISCouch.Util.Error).#SERVERERROR, "attachment: save error")
            Quit
        }
        ; Return 201 Created
        Set tResp = {}
        Do tResp.%Set("ok", 1, "boolean")
        Do tResp.%Set("id", pDocId)
        Do tResp.%Set("rev", tNewRev)
        Do ##class(IRISCouch.Util.Response).JSONStatus(201, tResp)
        Quit
    }
    Catch ex {
        Do ##class(IRISCouch.Util.Error).RenderInternal(##class(IRISCouch.Util.Error).#SERVERERROR, "attachment: put error", ex)
        Quit
    }
    Quit $$$OK
}

/// <p>Handle <code>GET /{db}/{docid}/{attname}</code> — download a binary attachment.</p>
/// <p>Retrieves the attachment stream and outputs it directly to the HTTP response
/// using <code>OutputToDevice()</code> (NFR-P8 compliant — no in-memory buffering).</p>
/// @param pDB The database name from the URL path
/// @param pDocId The document identifier from the URL path
/// @param pAttName The attachment filename from the URL path
/// @return %Status
ClassMethod HandleGet(pDB As %String, pDocId As %String, pAttName As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        ; Check database exists
        If '##class(IRISCouch.Storage.Database).Exists(pDB) {
            Do ##class(IRISCouch.Util.Error).Render(404, ##class(IRISCouch.Util.Error).#NOTFOUND, "Database does not exist.")
            Quit
        }
        ; Check document exists
        If '##class(IRISCouch.Storage.Document).Exists(pDB, pDocId) {
            Do ##class(IRISCouch.Util.Error).Render(404, ##class(IRISCouch.Util.Error).#NOTFOUND, "missing")
            Quit
        }
        ; Get rev parameter — default to winning revision
        Set tRev = ""
        If $Data(%request.Data("rev", 1)) {
            Set tRev = $Get(%request.Data("rev", 1))
        }
        If tRev = "" {
            Set tRev = ##class(IRISCouch.Storage.RevTree).GetWinner(pDB, pDocId)
            If tRev = "" {
                Do ##class(IRISCouch.Util.Error).Render(404, ##class(IRISCouch.Util.Error).#NOTFOUND, "missing")
                Quit
            }
        }
        ; Retrieve attachment from the specific revision
        Set tSC = ##class(IRISCouch.Storage.Attachment).Get(pDB, pDocId, pAttName, .tStream, .tContentType, .tLength, .tDigest, tRev)
        If $$$ISERR(tSC) {
            Do ##class(IRISCouch.Util.Error).Render(404, ##class(IRISCouch.Util.Error).#NOTFOUND, "Document is missing attachment")
            Quit
        }
        ; Set response headers
        Set %response.ContentType = tContentType
        Set %response.Status = 200
        ; Stream output directly to device (NFR-P8: no buffering)
        Do tStream.Rewind()
        Do tStream.OutputToDevice()
        Quit
    }
    Catch ex {
        Do ##class(IRISCouch.Util.Error).RenderInternal(##class(IRISCouch.Util.Error).#SERVERERROR, "attachment: get error", ex)
        Quit
    }
    Quit $$$OK
}

/// <p>Handle <code>DELETE /{db}/{docid}/{attname}</code> — remove an attachment.</p>
/// <p>Validates revision, removes the attachment from the document, and creates
/// a new revision carrying forward all other attachments.</p>
/// @param pDB The database name from the URL path
/// @param pDocId The document identifier from the URL path
/// @param pAttName The attachment filename from the URL path
/// @return %Status
ClassMethod HandleDelete(pDB As %String, pDocId As %String, pAttName As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        ; Check database exists
        If '##class(IRISCouch.Storage.Database).Exists(pDB) {
            Do ##class(IRISCouch.Util.Error).Render(404, ##class(IRISCouch.Util.Error).#NOTFOUND, "Database does not exist.")
            Quit
        }
        ; Check document exists
        If '##class(IRISCouch.Storage.Document).Exists(pDB, pDocId) {
            Do ##class(IRISCouch.Util.Error).Render(404, ##class(IRISCouch.Util.Error).#NOTFOUND, "missing")
            Quit
        }
        ; Get rev from query param — required
        Set tRev = ""
        If $Data(%request.Data("rev", 1)) {
            Set tRev = $Get(%request.Data("rev", 1))
        }
        If tRev = "" {
            Do ##class(IRISCouch.Util.Error).Render(409, ##class(IRISCouch.Util.Error).#CONFLICT, "Document update conflict.")
            Quit
        }
        ; Verify rev matches current winner
        Set tCurrentWinner = ##class(IRISCouch.Storage.RevTree).GetWinner(pDB, pDocId)
        If tRev '= tCurrentWinner {
            Do ##class(IRISCouch.Util.Error).Render(409, ##class(IRISCouch.Util.Error).#CONFLICT, "Document update conflict.")
            Quit
        }
        ; Check attachment actually exists
        If '##class(IRISCouch.Storage.Attachment).Exists(pDB, pDocId, pAttName) {
            Do ##class(IRISCouch.Util.Error).Render(404, ##class(IRISCouch.Util.Error).#NOTFOUND, "Document is missing attachment")
            Quit
        }
        ; Delete attachment via DocumentEngine (creates new revision in transaction)
        Set tNewRev = ##class(IRISCouch.Core.DocumentEngine).DeleteAttachment(pDB, pDocId, tRev, pAttName)
        If tNewRev = "" {
            Do ##class(IRISCouch.Util.Error).RenderInternal(##class(IRISCouch.Util.Error).#SERVERERROR, "attachment: delete error")
            Quit
        }
        ; Return 200 OK
        Set tResp = {}
        Do tResp.%Set("ok", 1, "boolean")
        Do tResp.%Set("id", pDocId)
        Do tResp.%Set("rev", tNewRev)
        Do ##class(IRISCouch.Util.Response).JSON(tResp)
        Quit
    }
    Catch ex {
        Do ##class(IRISCouch.Util.Error).RenderInternal(##class(IRISCouch.Util.Error).#SERVERERROR, "attachment: delete error", ex)
        Quit
    }
    Quit $$$OK
}

}
