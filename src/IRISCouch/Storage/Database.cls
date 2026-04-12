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
