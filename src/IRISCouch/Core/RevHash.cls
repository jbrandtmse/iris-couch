/// <p>Revision hash generation for IRISCouch.</p>
/// <p>Generates deterministic revision hashes using MD5 based on the canonical
/// JSON body, parent revision, and deletion flag. The hash algorithm follows
/// the CouchDB revision ID specification.</p>
/// <h4>Algorithm:</h4>
/// <ol>
/// <li>Canonicalize JSON body: remove <code>_id</code>, <code>_rev</code>,
///     <code>_revisions</code>, <code>_deleted</code> metadata fields</li>
/// <li>Compute input: <code>canonicalBody || parentRevId || deletedFlag</code></li>
/// <li>Hash with MD5 and convert to 32-character lowercase hex</li>
/// </ol>
Class IRISCouch.Core.RevHash Extends %RegisteredObject
{

/// <p>Generate a revision hash from document body and context.</p>
/// <p>Produces a 32-character lowercase hex string by MD5-hashing the canonical
/// body concatenated with the parent revision and deletion flag.</p>
/// @param pBody The raw JSON body string
/// @param pParentRev The parent revision string (empty for new documents)
/// @param pDeleted Whether the document is deleted (0 or 1)
/// @return %String 32-character lowercase hex hash
ClassMethod Generate(pBody As %String, pParentRev As %String = "", pDeleted As %Boolean = 0) As %String
{
    Set tHash = ""
    Try {
        ; Canonicalize: parse body, remove metadata fields, serialize back
        Set tObj = ##class(%DynamicObject).%FromJSON(pBody)
        If tObj.%IsDefined("_id") Do tObj.%Remove("_id")
        If tObj.%IsDefined("_rev") Do tObj.%Remove("_rev")
        If tObj.%IsDefined("_revisions") Do tObj.%Remove("_revisions")
        If tObj.%IsDefined("_deleted") Do tObj.%Remove("_deleted")
        Set tCanonical = tObj.%ToJSON()
        ; Build hash input
        Set tInput = tCanonical _ pParentRev _ pDeleted
        ; Compute MD5 (returns raw binary)
        Set tRawMD5 = $System.Encryption.MD5Hash(tInput)
        ; Convert raw bytes to lowercase hex
        Set tHex = ""
        For tI = 1:1:$Length(tRawMD5) {
            Set tByte = $Ascii(tRawMD5, tI)
            Set tHex = tHex _ $Translate($Justify($ZHex(tByte), 2), " ", "0")
        }
        Set tHash = $ZConvert(tHex, "L")
        Quit
    }
    Catch ex {
        Set tHash = ""
        Quit
    }
    Quit tHash
}

/// <p>Mint a full revision string with generation number and hash.</p>
/// <p>Returns a string in the format <code>N-hash</code> where N is the
/// generation number and hash is the 32-character hex hash.</p>
/// @param pGeneration The revision generation number (1 for new documents)
/// @param pBody The raw JSON body string
/// @param pParentRev The parent revision string (empty for new documents)
/// @param pDeleted Whether the document is deleted (0 or 1)
/// @return %String The full revision string (e.g., "1-abc123...")
ClassMethod MintRev(pGeneration As %Integer, pBody As %String, pParentRev As %String = "", pDeleted As %Boolean = 0) As %String
{
    Set tHash = ..Generate(pBody, pParentRev, pDeleted)
    If tHash = "" Quit ""
    Quit pGeneration _ "-" _ tHash
}

}
