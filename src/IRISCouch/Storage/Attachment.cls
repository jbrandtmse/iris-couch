/// <p>Storage layer for IRISCouch binary attachment operations.</p>
/// <p>Encapsulates all direct global access for attachment data stored in
/// <code>^IRISCouch.Atts(db, docId, rev, attName)</code>.
/// Handlers must NEVER touch attachment globals directly;
/// all access goes through this class (Pattern 3: Storage Encapsulation).</p>
Class IRISCouch.Storage.Attachment Extends %RegisteredObject
{

/// <p>Store a binary attachment for a document revision.</p>
/// <p>Copies the input stream to a <class>%Stream.GlobalBinary</class> stored at
/// <code>^IRISCouch.Atts(pDB, pDocId, pRev, pAttName)</code>.
/// Computes MD5 digest in CouchDB format (<code>md5-&lt;base64&gt;</code>)
/// and records metadata (content_type, length, digest, revpos).</p>
/// @param pDB The database name
/// @param pDocId The document identifier
/// @param pRev The revision string this attachment belongs to
/// @param pAttName The attachment filename
/// @param pContentType The MIME content type (e.g., "text/plain")
/// @param pStream The binary stream containing attachment data
/// @param pRevPos The revision position (generation number) for this attachment
/// @param Output pDigest The computed MD5 digest string
/// @param Output pLength The byte length of the attachment
/// @return %Status
ClassMethod Store(pDB As %String, pDocId As %String, pRev As %String, pAttName As %String, pContentType As %String, pStream As %Stream.GlobalBinary, pRevPos As %Integer = 1, Output pDigest As %String, Output pLength As %Integer) As %Status
{
    Set tSC = $$$OK
    Try {
        ; Create target stream stored in the attachment global
        Set tTarget = ##class(%Stream.GlobalBinary).%New()
        Set tTarget.%Location = "^IRISCouch.Atts"
        ; Copy source stream to target (stream-to-stream, no string buffer)
        Do pStream.Rewind()
        Set tSC = tTarget.CopyFrom(pStream)
        If $$$ISERR(tSC) Quit
        Set tSC = tTarget.%Save()
        If $$$ISERR(tSC) Quit
        ; Compute length
        Set pLength = tTarget.Size
        ; Compute MD5 digest
        Do tTarget.Rewind()
        Set tHash = $System.Encryption.MD5HashStream(tTarget)
        Set tB64 = $System.Encryption.Base64Encode(tHash)
        Set pDigest = "md5-" _ tB64
        Do tTarget.Rewind()
        ; Get the OID of the saved stream for later retrieval
        Set tOID = tTarget.%Oid()
        ; Store metadata: $ListBuild(content_type, length, digest, revpos)
        Set ^IRISCouch.Atts(pDB, pDocId, pRev, pAttName) = $ListBuild(pContentType, pLength, pDigest, pRevPos)
        ; Store the stream OID for retrieval
        Set ^IRISCouch.Atts(pDB, pDocId, pRev, pAttName, "stream") = tOID
        Quit
    }
    Catch ex {
        Set tSC = ex.AsStatus()
        Quit
    }
    Quit tSC
}

/// <p>Retrieve an attachment stream and metadata.</p>
/// <p>Finds the attachment on the specified revision (or latest revision that has it).
/// Returns the binary stream, content type, length, and digest.</p>
/// @param pDB The database name
/// @param pDocId The document identifier
/// @param pAttName The attachment filename
/// @param Output pStream The binary stream containing attachment data
/// @param Output pContentType The MIME content type
/// @param Output pLength The byte length
/// @param Output pDigest The MD5 digest string
/// @param pRev Optional specific revision to retrieve from
/// @return %Status
ClassMethod Get(pDB As %String, pDocId As %String, pAttName As %String, Output pStream As %Stream.GlobalBinary, Output pContentType As %String, Output pLength As %Integer, Output pDigest As %String, pRev As %String = "") As %Status
{
    Set tSC = $$$OK
    Set pStream = ""
    Set pContentType = ""
    Set pLength = 0
    Set pDigest = ""
    Try {
        ; If no specific rev, find the latest rev that has this attachment
        Set tRev = pRev
        If tRev = "" {
            Set tRev = ..FindRevWithAttachment(pDB, pDocId, pAttName)
            If tRev = "" {
                Set tSC = $$$ERROR($$$GeneralError, "Attachment not found")
                Quit
            }
        }
        ; Check attachment exists on this revision
        If '$Data(^IRISCouch.Atts(pDB, pDocId, tRev, pAttName)) {
            Set tSC = $$$ERROR($$$GeneralError, "Attachment not found")
            Quit
        }
        ; Read metadata
        Set tMeta = ^IRISCouch.Atts(pDB, pDocId, tRev, pAttName)
        Set pContentType = $ListGet(tMeta, 1)
        Set pLength = $ListGet(tMeta, 2)
        Set pDigest = $ListGet(tMeta, 3)
        ; Retrieve the stream via OID
        Set tOID = $Get(^IRISCouch.Atts(pDB, pDocId, tRev, pAttName, "stream"))
        If tOID = "" {
            Set tSC = $$$ERROR($$$GeneralError, "Attachment stream not found")
            Quit
        }
        Set pStream = ##class(%Stream.GlobalBinary).%Open(tOID)
        If '$IsObject(pStream) {
            Set tSC = $$$ERROR($$$GeneralError, "Failed to open attachment stream")
            Quit
        }
        Quit
    }
    Catch ex {
        Set tSC = ex.AsStatus()
        Quit
    }
    Quit tSC
}

/// <p>Delete an attachment from a specific revision.</p>
/// <p>Removes the attachment metadata and stream reference from
/// <code>^IRISCouch.Atts(pDB, pDocId, pRev, pAttName)</code>.</p>
/// @param pDB The database name
/// @param pDocId The document identifier
/// @param pRev The revision string
/// @param pAttName The attachment filename
/// @return %Status
ClassMethod Delete(pDB As %String, pDocId As %String, pRev As %String, pAttName As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        ; Kill the attachment data for this revision
        Kill ^IRISCouch.Atts(pDB, pDocId, pRev, pAttName)
        Quit
    }
    Catch ex {
        Set tSC = ex.AsStatus()
        Quit
    }
    Quit tSC
}

/// <p>Get attachment metadata for all attachments on a specific revision.</p>
/// <p>Returns a <class>%DynamicObject</class> in CouchDB <code>_attachments</code>
/// stub format with content_type, length, digest, revpos, and stub:true.</p>
/// @param pDB The database name
/// @param pDocId The document identifier
/// @param pRev The revision string
/// @return %DynamicObject The _attachments JSON object, or "" if no attachments
ClassMethod GetMetadata(pDB As %String, pDocId As %String, pRev As %String) As %DynamicObject
{
    Set tResult = ""
    Set tAttName = ""
    Set tFound = 0
    For {
        Set tAttName = $Order(^IRISCouch.Atts(pDB, pDocId, pRev, tAttName))
        Quit:tAttName=""
        ; Skip the "stream" sub-node
        If tAttName = "stream" Continue
        If 'tFound {
            Set tResult = {}
            Set tFound = 1
        }
        Set tMeta = ^IRISCouch.Atts(pDB, pDocId, pRev, tAttName)
        Set tStub = {}
        Do tStub.%Set("content_type", $ListGet(tMeta, 1))
        Do tStub.%Set("length", +$ListGet(tMeta, 2), "number")
        Do tStub.%Set("digest", $ListGet(tMeta, 3))
        Do tStub.%Set("revpos", +$ListGet(tMeta, 4), "number")
        Do tStub.%Set("stub", 1, "boolean")
        Do tResult.%Set(tAttName, tStub)
    }
    ; Also check if previous revisions had attachments that should carry forward
    ; For now, only return attachments explicitly on this revision
    Quit tResult
}

/// <p>Check if an attachment exists on any revision of a document.</p>
/// @param pDB The database name
/// @param pDocId The document identifier
/// @param pAttName The attachment filename
/// @return %Boolean 1 if attachment exists, 0 otherwise
ClassMethod Exists(pDB As %String, pDocId As %String, pAttName As %String) As %Boolean
{
    Set tFound = 0
    Set tRev = ""
    For {
        Set tRev = $Order(^IRISCouch.Atts(pDB, pDocId, tRev))
        Quit:tRev=""
        If $Data(^IRISCouch.Atts(pDB, pDocId, tRev, pAttName)) {
            Set tFound = 1
            Quit
        }
    }
    Quit tFound
}

/// <p>Find the latest revision that has a specific attachment.</p>
/// <p>Iterates through revisions in reverse order to find the most recent
/// revision containing the named attachment.</p>
/// @param pDB The database name
/// @param pDocId The document identifier
/// @param pAttName The attachment filename
/// @return %String The revision string, or "" if not found
ClassMethod FindRevWithAttachment(pDB As %String, pDocId As %String, pAttName As %String) As %String
{
    Set tFoundRev = ""
    Set tRev = ""
    For {
        Set tRev = $Order(^IRISCouch.Atts(pDB, pDocId, tRev))
        Quit:tRev=""
        If $Data(^IRISCouch.Atts(pDB, pDocId, tRev, pAttName)) {
            Set tFoundRev = tRev
        }
    }
    Quit tFoundRev
}

/// <p>Copy attachments from one revision to another.</p>
/// <p>Used when creating a new revision to carry forward existing attachments.
/// Copies metadata and stream references (not the actual stream data).</p>
/// @param pDB The database name
/// @param pDocId The document identifier
/// @param pFromRev The source revision
/// @param pToRev The target revision
/// @param pExclude Optional attachment name to exclude (for delete operations)
/// @return %Status
ClassMethod CopyAttachments(pDB As %String, pDocId As %String, pFromRev As %String, pToRev As %String, pExclude As %String = "") As %Status
{
    Set tSC = $$$OK
    Try {
        Set tAttName = ""
        For {
            Set tAttName = $Order(^IRISCouch.Atts(pDB, pDocId, pFromRev, tAttName))
            Quit:tAttName=""
            If tAttName = "stream" Continue
            If (pExclude '= "") && (tAttName = pExclude) Continue
            ; Copy metadata
            Set ^IRISCouch.Atts(pDB, pDocId, pToRev, tAttName) = ^IRISCouch.Atts(pDB, pDocId, pFromRev, tAttName)
            ; Copy stream reference (share the same stream OID)
            If $Data(^IRISCouch.Atts(pDB, pDocId, pFromRev, tAttName, "stream")) {
                Set ^IRISCouch.Atts(pDB, pDocId, pToRev, tAttName, "stream") = ^IRISCouch.Atts(pDB, pDocId, pFromRev, tAttName, "stream")
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

/// <p>Copy a single named attachment from one revision to another.</p>
/// <p>Copies metadata and stream OID reference for one specific attachment.
/// Used by <method>DocumentEngine.SaveWithAttachments</method> to carry forward
/// individual stub attachments without copying the entire revision's attachments.</p>
/// @param pDB The database name
/// @param pDocId The document identifier
/// @param pFromRev The source revision
/// @param pToRev The target revision
/// @param pAttName The attachment name to copy
/// @return %Status
ClassMethod CopyOneAttachment(pDB As %String, pDocId As %String, pFromRev As %String, pToRev As %String, pAttName As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        If '$Data(^IRISCouch.Atts(pDB, pDocId, pFromRev, pAttName)) {
            ; Attachment not found on source revision — not an error, just skip
            Quit
        }
        ; Copy metadata
        Set ^IRISCouch.Atts(pDB, pDocId, pToRev, pAttName) = ^IRISCouch.Atts(pDB, pDocId, pFromRev, pAttName)
        ; Copy stream reference (share the same stream OID)
        If $Data(^IRISCouch.Atts(pDB, pDocId, pFromRev, pAttName, "stream")) {
            Set ^IRISCouch.Atts(pDB, pDocId, pToRev, pAttName, "stream") = ^IRISCouch.Atts(pDB, pDocId, pFromRev, pAttName, "stream")
        }
        Quit
    }
    Catch ex {
        Set tSC = ex.AsStatus()
        Quit
    }
    Quit tSC
}

/// <p>Clean up all attachments for a database.</p>
/// <p>Used during database deletion to remove all attachment data.</p>
/// @param pDB The database name
/// @return %Status
ClassMethod CleanupDatabase(pDB As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Kill ^IRISCouch.Atts(pDB)
        Quit
    }
    Catch ex {
        Set tSC = ex.AsStatus()
        Quit
    }
    Quit tSC
}

}
