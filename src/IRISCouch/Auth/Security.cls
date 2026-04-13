/// <p>Per-database security configuration for IRISCouch.</p>
/// <p>Implements CouchDB's <code>_security</code> object semantics: a non-versioned
/// configuration object stored in a dedicated global, NOT a regular document.
/// Controls per-database admin and member access lists.</p>
/// <h4>Key behaviors (per CouchDB design):</h4>
/// <ul>
/// <li>Members can read all docs and write non-design docs</li>
/// <li>Admins have all member privileges plus write design docs, modify _security</li>
/// <li>No members defined: any authenticated user can read/write regular docs</li>
/// <li>No admins defined: only server admins can write design docs</li>
/// <li>Server admins (_admin role, IRIS %All role) bypass all restrictions</li>
/// </ul>
Class IRISCouch.Auth.Security Extends %RegisteredObject
{

/// <p>Store a security configuration for a database.</p>
/// <p>Validates the structure and persists the security object as a JSON string
/// in <code>^IRISCouch.Security(pDB)</code>.</p>
/// @param pDB The database name
/// @param pSecObj The security configuration as %DynamicObject
/// @return %Status
ClassMethod Put(pDB As %String, pSecObj As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Try {
        ; Validate structure: must have admins and members objects
        If '$IsObject(pSecObj.admins) {
            Set tSC = $$$ERROR($$$GeneralError, "admins field must be an object")
            Quit
        }
        If '$IsObject(pSecObj.members) {
            Set tSC = $$$ERROR($$$GeneralError, "members field must be an object")
            Quit
        }
        ; Validate admins has names and/or roles arrays (allow missing — treat as empty)
        Set tAdminNames = pSecObj.admins.names
        If $IsObject(tAdminNames) && (tAdminNames.%IsA("%Library.DynamicArray") = 0) {
            Set tSC = $$$ERROR($$$GeneralError, "admins.names must be an array")
            Quit
        }
        Set tAdminRoles = pSecObj.admins.roles
        If $IsObject(tAdminRoles) && (tAdminRoles.%IsA("%Library.DynamicArray") = 0) {
            Set tSC = $$$ERROR($$$GeneralError, "admins.roles must be an array")
            Quit
        }
        ; Validate members has names and/or roles arrays
        Set tMemberNames = pSecObj.members.names
        If $IsObject(tMemberNames) && (tMemberNames.%IsA("%Library.DynamicArray") = 0) {
            Set tSC = $$$ERROR($$$GeneralError, "members.names must be an array")
            Quit
        }
        Set tMemberRoles = pSecObj.members.roles
        If $IsObject(tMemberRoles) && (tMemberRoles.%IsA("%Library.DynamicArray") = 0) {
            Set tSC = $$$ERROR($$$GeneralError, "members.roles must be an array")
            Quit
        }
        ; Normalize: ensure names and roles arrays exist
        Set tNormalized = ..Normalize(pSecObj)
        ; Store as JSON string in dedicated global
        Set ^IRISCouch.Security(pDB) = tNormalized.%ToJSON()
        Quit
    }
    Catch ex {
        Set tSC = ex.AsStatus()
        Quit
    }
    Quit tSC
}

/// <p>Retrieve the security configuration for a database.</p>
/// <p>Returns the stored security object from <code>^IRISCouch.Security(pDB)</code>.
/// If no security has been configured, returns an empty security object with
/// empty arrays (per CouchDB behavior).</p>
/// @param pDB The database name
/// @return %DynamicObject The security configuration
ClassMethod Get(pDB As %String) As %DynamicObject
{
    Set tResult = ""
    Try {
        Set tJSON = $Get(^IRISCouch.Security(pDB), "")
        If tJSON '= "" {
            Set tResult = ##class(%DynamicObject).%FromJSON(tJSON)
        } Else {
            ; Return empty security object (per CouchDB: empty when never set)
            Set tResult = ..EmptySecurityObject()
        }
        Quit
    }
    Catch ex {
        Set tResult = ..EmptySecurityObject()
        Quit
    }
    Quit tResult
}

/// <p>Delete the security configuration for a database.</p>
/// <p>Called when a database is deleted to clean up the security global.</p>
/// @param pDB The database name
ClassMethod Delete(pDB As %String)
{
    Kill ^IRISCouch.Security(pDB)
}

/// <p>Check if a security configuration exists for a database.</p>
/// @param pDB The database name
/// @return %Boolean 1 if security config exists, 0 otherwise
ClassMethod Exists(pDB As %String) As %Boolean
{
    Quit ($Data(^IRISCouch.Security(pDB)) > 0)
}

/// <p>Check if a user has access to a database operation.</p>
/// <p>Implements CouchDB's security enforcement logic:</p>
/// <ol>
/// <li>No _security config: open access (return 1)</li>
/// <li>Server admin (_admin or %All role): bypass all restrictions (return 1)</li>
/// <li>Admin operation: user must be in admins.names or have admins.roles</li>
/// <li>Member operation: user must be in members.names, have members.roles, OR be an admin</li>
/// <li>If members lists are both empty: any authenticated user can access</li>
/// </ol>
/// @param pDB The database name
/// @param pUsername The authenticated username (empty for anonymous)
/// @param pRoles A %DynamicArray of the user's role strings
/// @param pIsAdminOp Whether this is an admin-level operation (default 0)
/// @return %Boolean 1 if access allowed, 0 if denied
ClassMethod CheckAccess(pDB As %String, pUsername As %String, pRoles As %DynamicArray, pIsAdminOp As %Boolean = 0) As %Boolean
{
    Set tResult = 1
    Try {
        ; If no security config exists, open access
        If '..Exists(pDB) {
            Set tResult = 1
            Quit
        }
        ; Server admin bypass: check for _admin or %All role
        If ..IsServerAdmin(pUsername, pRoles) {
            Set tResult = 1
            Quit
        }
        ; Load security object
        Set tSecObj = ..Get(pDB)
        ; For admin operations, user must be a database admin
        If pIsAdminOp {
            Set tResult = ..IsDBAdmin(pUsername, pRoles, tSecObj)
            Quit
        }
        ; For member operations:
        ; If members lists are both empty, any authenticated user can access
        Set tMemberNames = tSecObj.members.names
        Set tMemberRoles = tSecObj.members.roles
        Set tMemberNamesSize = 0
        Set tMemberRolesSize = 0
        If $IsObject(tMemberNames) Set tMemberNamesSize = tMemberNames.%Size()
        If $IsObject(tMemberRoles) Set tMemberRolesSize = tMemberRoles.%Size()
        If (tMemberNamesSize = 0) && (tMemberRolesSize = 0) {
            ; No member restrictions — any authenticated user can access
            Set tResult = 1
            Quit
        }
        ; Check if user is a database admin (admins are super-members)
        If ..IsDBAdmin(pUsername, pRoles, tSecObj) {
            Set tResult = 1
            Quit
        }
        ; Check if user is in members.names
        If ..IsInNamesList(pUsername, tMemberNames) {
            Set tResult = 1
            Quit
        }
        ; Check if user has any members.roles
        If ..HasMatchingRole(pRoles, tMemberRoles) {
            Set tResult = 1
            Quit
        }
        ; Access denied
        Set tResult = 0
        Quit
    }
    Catch ex {
        ; On error, deny access (safe default)
        Set tResult = 0
        Quit
    }
    Quit tResult
}

/// <p>Check if a user is a server admin.</p>
/// <p>Server admins are users with the <code>_admin</code> role (CouchDB convention)
/// or the <code>%All</code> role (IRIS convention). They bypass all _security restrictions.</p>
/// @param pUsername The username
/// @param pRoles The user's roles as %DynamicArray
/// @return %Boolean
ClassMethod IsServerAdmin(pUsername As %String, pRoles As %DynamicArray) As %Boolean [ Private ]
{
    If '$IsObject(pRoles) Quit 0
    Set tFound = 0
    For tI = 0:1:(pRoles.%Size() - 1) {
        Set tRole = pRoles.%Get(tI)
        If (tRole = "_admin") || (tRole = "%All") {
            Set tFound = 1
            Quit
        }
    }
    Quit tFound
}

/// <p>Check if a user is a database admin.</p>
/// @param pUsername The username
/// @param pRoles The user's roles as %DynamicArray
/// @param pSecObj The security configuration object
/// @return %Boolean
ClassMethod IsDBAdmin(pUsername As %String, pRoles As %DynamicArray, pSecObj As %DynamicObject) As %Boolean [ Private ]
{
    ; Check admins.names
    If ..IsInNamesList(pUsername, pSecObj.admins.names) Quit 1
    ; Check admins.roles
    If ..HasMatchingRole(pRoles, pSecObj.admins.roles) Quit 1
    Quit 0
}

/// <p>Check if a username is in a names array.</p>
/// @param pUsername The username to look for
/// @param pNames A %DynamicArray of name strings
/// @return %Boolean
ClassMethod IsInNamesList(pUsername As %String, pNames As %DynamicArray) As %Boolean [ Private ]
{
    If '$IsObject(pNames) Quit 0
    If pUsername = "" Quit 0
    Set tFound = 0
    For tI = 0:1:(pNames.%Size() - 1) {
        If pNames.%Get(tI) = pUsername {
            Set tFound = 1
            Quit
        }
    }
    Quit tFound
}

/// <p>Check if any of the user's roles match the required roles.</p>
/// @param pUserRoles A %DynamicArray of the user's role strings
/// @param pRequiredRoles A %DynamicArray of required role strings
/// @return %Boolean
ClassMethod HasMatchingRole(pUserRoles As %DynamicArray, pRequiredRoles As %DynamicArray) As %Boolean [ Private ]
{
    If '$IsObject(pUserRoles) Quit 0
    If '$IsObject(pRequiredRoles) Quit 0
    Set tFound = 0
    For tI = 0:1:(pUserRoles.%Size() - 1) {
        Set tUserRole = pUserRoles.%Get(tI)
        For tJ = 0:1:(pRequiredRoles.%Size() - 1) {
            If tUserRole = pRequiredRoles.%Get(tJ) {
                Set tFound = 1
                Quit
            }
        }
        If tFound Quit
    }
    Quit tFound
}

/// <p>Return an empty security object with the standard structure.</p>
/// @return %DynamicObject
ClassMethod EmptySecurityObject() As %DynamicObject
{
    Set tObj = {}
    Set tAdmins = {}
    Do tAdmins.%Set("names", [])
    Do tAdmins.%Set("roles", [])
    Do tObj.%Set("admins", tAdmins)
    Set tMembers = {}
    Do tMembers.%Set("names", [])
    Do tMembers.%Set("roles", [])
    Do tObj.%Set("members", tMembers)
    Quit tObj
}

/// <p>Normalize a security object to ensure all required arrays exist.</p>
/// @param pSecObj The input security object
/// @return %DynamicObject Normalized security object
ClassMethod Normalize(pSecObj As %DynamicObject) As %DynamicObject [ Private ]
{
    Set tObj = {}
    ; Normalize admins
    Set tAdmins = {}
    If $IsObject(pSecObj.admins.names) {
        Do tAdmins.%Set("names", pSecObj.admins.names)
    } Else {
        Do tAdmins.%Set("names", [])
    }
    If $IsObject(pSecObj.admins.roles) {
        Do tAdmins.%Set("roles", pSecObj.admins.roles)
    } Else {
        Do tAdmins.%Set("roles", [])
    }
    Do tObj.%Set("admins", tAdmins)
    ; Normalize members
    Set tMembers = {}
    If $IsObject(pSecObj.members.names) {
        Do tMembers.%Set("names", pSecObj.members.names)
    } Else {
        Do tMembers.%Set("names", [])
    }
    If $IsObject(pSecObj.members.roles) {
        Do tMembers.%Set("roles", pSecObj.members.roles)
    } Else {
        Do tMembers.%Set("roles", [])
    }
    Do tObj.%Set("members", tMembers)
    Quit tObj
}

}
