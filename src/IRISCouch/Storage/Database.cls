/// <p>Storage layer for IRISCouch database lifecycle operations.</p>
/// <p>Encapsulates all direct global access for database metadata.
/// Handlers must NEVER touch <code>^IRISCouch.DB</code> globals directly;
/// all access goes through this class (Pattern 3: Storage Encapsulation).</p>
Class IRISCouch.Storage.Database Extends %RegisteredObject
{

/// <p>Valid characters for database names (after first character).</p>
Parameter VALIDCHARS = "abcdefghijklmnopqrstuvwxyz0123456789_$()+-/";

/// <p>Create a new database with the given name.</p>
/// <p>Initializes <code>^IRISCouch.DB(pName)</code> with metadata subscripts
/// and sets up the sequence counter global. Returns an error if the
/// database already exists.</p>
/// @param pName The database name (must be pre-validated)
/// @return %Status
ClassMethod Create(pName As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        ; Check if database already exists
        If ..Exists(pName) {
            Set tSC = $$$ERROR($$$GeneralError, "Database already exists: " _ pName)
            Quit
        }
        ; Initialize metadata subscripts
        Set ^IRISCouch.DB(pName, "created") = $Translate($ZDateTime($ZTimeStamp, 3, 1), " ", "T") _ "Z"
        Set ^IRISCouch.DB(pName, "doc_count") = 0
        Set ^IRISCouch.DB(pName, "doc_del_count") = 0
        Set ^IRISCouch.DB(pName, "update_seq") = 0
        Set ^IRISCouch.DB(pName, "disk_size") = 0
        Set ^IRISCouch.DB(pName, "purge_seq") = 0
        Set ^IRISCouch.DB(pName, "revs_limit") = 1000
        ; Initialize sequence counter
        Set ^IRISCouch.Seq(pName) = 0
        Quit
    }
    Catch ex {
        Set tSC = ex.AsStatus()
        Quit
    }
    Quit tSC
}

/// <p>Delete an existing database and all associated globals.</p>
/// <p>Removes <code>^IRISCouch.DB</code>, <code>^IRISCouch.Docs</code>,
/// <code>^IRISCouch.Tree</code>, <code>^IRISCouch.Changes</code>, and
/// <code>^IRISCouch.Seq</code> globals for the specified database.</p>
/// @param pName The database name
/// @return %Status
ClassMethod Delete(pName As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        ; Check if database exists
        If '..Exists(pName) {
            Set tSC = $$$ERROR($$$GeneralError, "Database does not exist: " _ pName)
            Quit
        }
        ; Kill all associated globals
        Kill ^IRISCouch.DB(pName)
        Kill ^IRISCouch.Docs(pName)
        Kill ^IRISCouch.Tree(pName)
        Kill ^IRISCouch.Changes(pName)
        Kill ^IRISCouch.Seq(pName)
        ; Best-effort cleanup: capture errors, continue all steps (Story 9.0)
        Set tErrors = ""
        ; Clean up attachment data (Story 5.1)
        Set tSC2 = ##class(IRISCouch.Storage.Attachment).CleanupDatabase(pName)
        If $$$ISERR(tSC2) Set tErrors = tErrors _ "Attachment cleanup failed; "
        ; Clean up projection data (Story 6.1)
        Set tSC2 = ##class(IRISCouch.Projection.Winners).DeleteAll(pName)
        If $$$ISERR(tSC2) Set tErrors = tErrors _ "Winners cleanup failed; "
        Set tSC2 = ##class(IRISCouch.Projection.MangoIndex).DeleteAll(pName)
        If $$$ISERR(tSC2) Set tErrors = tErrors _ "MangoIndex cleanup failed; "
        Set tSC2 = ##class(IRISCouch.Projection.MangoIndexDef).DeleteAll(pName)
        If $$$ISERR(tSC2) Set tErrors = tErrors _ "MangoIndexDef cleanup failed; "
        ; Clean up security configuration (Story 7.4)
        ; Auth.Security.Delete has no return value (Kill global only), use Do
        Do ##class(IRISCouch.Auth.Security).Delete(pName)
        ; Clean up local documents (Story 8.1)
        Set tSC2 = ##class(IRISCouch.Storage.Local).DeleteAll(pName)
        If $$$ISERR(tSC2) Set tErrors = tErrors _ "Local cleanup failed; "
        ; Report accumulated errors if any
        If tErrors '= "" {
            Set tSC = $$$ERROR($$$GeneralError, "Database deletion had cleanup errors: " _ tErrors)
        }
        Quit
    }
    Catch ex {
        Set tSC = ex.AsStatus()
        Quit
    }
    Quit tSC
}

/// <p>Check if a database exists.</p>
/// @param pName The database name
/// @return %Boolean 1 if exists, 0 otherwise
ClassMethod Exists(pName As %String) As %Boolean
{
    Quit $Data(^IRISCouch.DB(pName))>0
}

/// <p>List all database names in alphabetical order.</p>
/// <p>Iterates <code>^IRISCouch.DB</code> using <code>$Order</code> to collect
/// all database names. Global collation returns string keys in alphabetical
/// order, so no explicit sort is needed.</p>
/// @return %DynamicArray of database name strings
ClassMethod ListAll() As %DynamicArray
{
    Set tArr = []
    Set tName = ""
    For {
        Set tName = $Order(^IRISCouch.DB(tName))
        Quit:tName=""
        Do tArr.%Push(tName)
    }
    Quit tArr
}

/// <p>Get CouchDB-compatible metadata for a database.</p>
/// <p>Reads <code>^IRISCouch.DB(pName, ...)</code> subscripts and returns a
/// <class>%DynamicObject</class> with standard CouchDB database info fields.
/// Returns empty string if the database does not exist.</p>
/// @param pName The database name
/// @return %DynamicObject with metadata fields, or "" if not found
ClassMethod GetInfo(pName As %String) As %DynamicObject
{
    Set result = ""
    Try {
        If '..Exists(pName) {
            Quit
        }
        Set tDocCount = +$Get(^IRISCouch.DB(pName, "doc_count"))
        Set tUpdateSeq = +$Get(^IRISCouch.DB(pName, "update_seq"))
        Set tPurgeSeq = +$Get(^IRISCouch.DB(pName, "purge_seq"))
        ; Compute real disk size from ^IRISCouch.* globals for this database.
        ; CouchDB spec: sizes.file = bytes allocated on disk (includes overhead),
        ; sizes.external = uncompressed JSON size, sizes.active = live (non-deleted) size.
        ; IRIS does not expose compressed vs. uncompressed distinctions the same way,
        ; so we report sizes.file (allocated bytes) and approximate active/external
        ; as Used bytes. Keep legacy disk_size in sync with sizes.file for back-compat.
        Set tFileBytes = ..ComputeDiskSize(pName, .tUsedBytes)
        Set tActiveBytes = tUsedBytes
        Set tExternalBytes = tUsedBytes
        Set result = {}
        Do result.%Set("db_name", pName)
        Do result.%Set("doc_count", tDocCount, "number")
        Set tDocDelCount = +$Get(^IRISCouch.DB(pName, "doc_del_count"))
        Do result.%Set("doc_del_count", tDocDelCount, "number")
        ; CouchDB spec: update_seq is an opaque string sequence identifier.
        ; We stringify the numeric seq (e.g., 42 -> "42") for spec compliance.
        ; The changes feed is updated in lockstep to emit string seqs too.
        Do result.%Set("update_seq", tUpdateSeq_"")
        Do result.%Set("purge_seq", tPurgeSeq, "number")
        Do result.%Set("compact_running", 0, "boolean")
        ; CouchDB-spec sizes object.
        Set tSizes = {}
        Do tSizes.%Set("file", tFileBytes, "number")
        Do tSizes.%Set("external", tExternalBytes, "number")
        Do tSizes.%Set("active", tActiveBytes, "number")
        Do result.%Set("sizes", tSizes)
        ; Legacy disk_size kept for backward compatibility (older clients).
        Do result.%Set("disk_size", tFileBytes, "number")
        Do result.%Set("data_size", tActiveBytes, "number")
        Do result.%Set("instance_start_time", "0")
        Do result.%Set("disk_format_version", 1, "number")
        Do result.%Set("committed_update_seq", tUpdateSeq_"")
        Quit
    }
    Catch ex {
        Set result = ""
        Quit
    }
    Quit result
}

/// <p>Compute the approximate on-disk size, in bytes, of the IRIS globals that back a database.</p>
/// <p>Aggregates <code>%Library.GlobalEdit.GetGlobalSizeBySubscript()</code> across
/// the five IRISCouch globals (<code>^IRISCouch.DB</code>, <code>^IRISCouch.Docs</code>,
/// <code>^IRISCouch.Tree</code>, <code>^IRISCouch.Changes</code>, <code>^IRISCouch.Seq</code>)
/// for a specific database subscript. Currently calls with Fast=0 (precise) — if the
/// DbInfo response becomes slow on large databases, switch the 5th argument to 1
/// (stochastic estimate) to trade accuracy for latency.</p>
/// <p>Returns "Allocated" bytes as the function result and passes "Used" bytes
/// via the <var>pUsedBytes</var> output variable. Returns 0 on any error to
/// avoid masking DbInfo responses for minor plumbing issues.</p>
/// @param pName The database name (used as the first global subscript)
/// @param pUsedBytes Output: used bytes across all IRISCouch.* globals for this DB
/// @return %Integer The allocated bytes (sizes.file value)
ClassMethod ComputeDiskSize(pName As %String, Output pUsedBytes As %Integer) As %Integer
{
    Set pUsedBytes = 0
    Set tTotalAlloc = 0
    Try {
        ; Get the directory where ^IRISCouch.DB is mapped in the current namespace.
        Set tDest = ##class(%SYS.Namespace).GetGlobalDest($Namespace, "^IRISCouch.DB")
        ; Dest format is "system^directory" where system is empty on local node,
        ; producing a leading "^" followed by the directory. Take the piece
        ; after the first "^" delimiter.
        Set tDir = $Piece(tDest, "^", 2)
        If tDir = "" {
            Quit
        }
        ; Query each of the 5 IRISCouch globals, scoped to this database subscript,
        ; via %Library.GlobalEdit.GetGlobalSizeBySubscript(), which reports MB with
        ; fractional precision for small globals. We convert MB -> bytes and sum.
        Set tGlobals = $ListBuild(
            "IRISCouch.DB(""" _ pName _ """)",
            "IRISCouch.Docs(""" _ pName _ """)",
            "IRISCouch.Tree(""" _ pName _ """)",
            "IRISCouch.Changes(""" _ pName _ """)",
            "IRISCouch.Seq(""" _ pName _ """)"
        )
        Set tPtr = 0
        While $ListNext(tGlobals, tPtr, tGlob) {
            Kill tSize
            Set tSize = 0
            Set tSC = ##class(%Library.GlobalEdit).GetGlobalSizeBySubscript(tDir, tGlob, "", .tSize, 0, 0)
            If $$$ISOK(tSC) {
                ; tSize (top-level) = total allocated MB for this subtree.
                ; tSize("MB","Total") = same. Convert MB -> bytes.
                Set tBytes = +tSize * 1048576
                Set tTotalAlloc = tTotalAlloc + tBytes
                ; IRIS does not report a separate "used" breakdown per subscript;
                ; treat allocated as a conservative proxy for both file and active.
                Set pUsedBytes = pUsedBytes + tBytes
            }
        }
        ; Return integer byte counts (CouchDB spec: sizes.* are integers).
        Set tTotalAlloc = tTotalAlloc \ 1
        Set pUsedBytes = pUsedBytes \ 1
        Quit
    }
    Catch ex {
        Set tTotalAlloc = 0
        Set pUsedBytes = 0
        Quit
    }
    Quit tTotalAlloc
}

/// <p>Set the revision retention limit for a database.</p>
/// <p>Stores the revs_limit value in <code>^IRISCouch.DB(pName, "revs_limit")</code>.
/// The caller is responsible for validating that the database exists.</p>
/// @param pName The database name
/// @param pLimit The revision retention limit (positive integer)
/// @return %Status
ClassMethod SetRevsLimit(pName As %String, pLimit As %Integer) As %Status
{
    Set tSC = $$$OK
    Try {
        Set ^IRISCouch.DB(pName, "revs_limit") = pLimit
        Quit
    }
    Catch ex {
        Set tSC = ex.AsStatus()
        Quit
    }
    Quit tSC
}

/// <p>Get the revision retention limit for a database.</p>
/// <p>Returns the revs_limit value from <code>^IRISCouch.DB(pName, "revs_limit")</code>,
/// defaulting to 1000 if not set.</p>
/// @param pName The database name
/// @return %Integer The current revs_limit value (default 1000)
ClassMethod GetRevsLimit(pName As %String) As %Integer
{
    Quit $Get(^IRISCouch.DB(pName, "revs_limit"), 1000)
}

/// <p>Increment the document count for a database.</p>
/// <p>Wraps <code>$Increment(^IRISCouch.DB(pDB, "doc_count"), pDelta)</code>.</p>
/// @param pDB The database name
/// @param pDelta The increment value (default 1, use -1 to decrement)
ClassMethod IncrementDocCount(pDB As %String, pDelta As %Integer = 1)
{
    Set tCount = $Increment(^IRISCouch.DB(pDB, "doc_count"), pDelta)
}

/// <p>Increment the deleted document count for a database.</p>
/// <p>Wraps <code>$Increment(^IRISCouch.DB(pDB, "doc_del_count"))</code>.</p>
/// @param pDB The database name
ClassMethod IncrementDelCount(pDB As %String)
{
    Set tDelCount = $Increment(^IRISCouch.DB(pDB, "doc_del_count"))
}

/// <p>Set the update sequence number for a database.</p>
/// <p>Wraps <code>Set ^IRISCouch.DB(pDB, "update_seq") = pSeq</code>.</p>
/// @param pDB The database name
/// @param pSeq The sequence number to set
ClassMethod SetUpdateSeq(pDB As %String, pSeq As %Integer)
{
    Set ^IRISCouch.DB(pDB, "update_seq") = pSeq
}

/// <p>Validate a database name against CouchDB naming rules.</p>
/// <p>Valid names must begin with a lowercase letter and contain only
/// lowercase letters, digits, and the characters <code>_$()+-/</code>.
/// Names starting with <code>_</code> are reserved for system databases.</p>
/// @param pName The database name to validate
/// @return %Status OK if valid, error with reason if invalid
ClassMethod ValidateName(pName As %String) As %Status
{
    Set tSC = $$$OK
    Set tReason = "Only lowercase characters (a-z), digits (0-9), and any of the characters _, $, (, ), +, -, and / are allowed. Must begin with a letter."
    Try {
        ; Empty name check
        If pName = "" {
            Set tSC = $$$ERROR($$$GeneralError, "Name: ''. " _ tReason)
            Quit
        }
        Set tValid = ..#VALIDCHARS
        ; System database names starting with underscore are allowed
        If $Extract(pName, 1) = "_" {
            ; Validate rest of system db name - must have at least one more char
            If $Length(pName) < 2 {
                Set tSC = $$$ERROR($$$GeneralError, "Name: '" _ pName _ "'. " _ tReason)
                Quit
            }
            ; Validate each character in rest of system db name
            For tI = 2:1:$Length(pName) {
                Set tChar = $Extract(pName, tI)
                If '$Find(tValid, tChar) {
                    Set tSC = $$$ERROR($$$GeneralError, "Name: '" _ pName _ "'. " _ tReason)
                    Quit
                }
            }
            Quit
        }
        ; Must begin with a lowercase letter
        If $Extract(pName, 1) '? 1L {
            Set tSC = $$$ERROR($$$GeneralError, "Name: '" _ pName _ "'. " _ tReason)
            Quit
        }
        ; Validate remaining characters
        For tI = 2:1:$Length(pName) {
            Set tChar = $Extract(pName, tI)
            If '$Find(tValid, tChar) {
                Set tSC = $$$ERROR($$$GeneralError, "Name: '" _ pName _ "'. " _ tReason)
                Quit
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

}
