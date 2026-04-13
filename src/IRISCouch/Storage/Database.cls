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
        Set ^IRISCouch.DB(pName, "created") = $ZDateTime($Horolog, 3)
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
        ; Clean up attachment data (Story 5.1)
        Do ##class(IRISCouch.Storage.Attachment).CleanupDatabase(pName)
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
        Set tDiskSize = +$Get(^IRISCouch.DB(pName, "disk_size"))
        Set tPurgeSeq = +$Get(^IRISCouch.DB(pName, "purge_seq"))
        Set result = {}
        Do result.%Set("db_name", pName)
        Do result.%Set("doc_count", tDocCount, "number")
        Set tDocDelCount = +$Get(^IRISCouch.DB(pName, "doc_del_count"))
        Do result.%Set("doc_del_count", tDocDelCount, "number")
        Do result.%Set("update_seq", tUpdateSeq, "number")
        Do result.%Set("purge_seq", tPurgeSeq, "number")
        Do result.%Set("compact_running", 0, "boolean")
        Do result.%Set("disk_size", tDiskSize, "number")
        Do result.%Set("data_size", 0, "number")
        Do result.%Set("instance_start_time", "0")
        Do result.%Set("disk_format_version", 1, "number")
        Do result.%Set("committed_update_seq", tUpdateSeq, "number")
        Quit
    }
    Catch ex {
        Set result = ""
        Quit
    }
    Quit result
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
