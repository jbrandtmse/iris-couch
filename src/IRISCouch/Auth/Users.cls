/// <p>User management sync engine for the <code>_users</code> database.</p>
/// <p>Intercepts document writes and deletes in the <code>_users</code> database
/// to synchronize CouchDB user documents with IRIS <code>Security.Users</code>
/// records. Implements CouchDB-compatible password hashing (PBKDF2-SHA256)
/// and field stripping per <code>couch_users_db.erl</code> behavior.</p>
/// <p>Called by <class>IRISCouch.Core.DocumentEngine</class> within the
/// document write transaction to ensure atomicity (AC #8).</p>
/// <h4>Key behaviors:</h4>
/// <ul>
/// <li>Password hashed via PBKDF2-SHA256 with >= 10,000 iterations (NFR-S2)</li>
/// <li>Plaintext password stripped from document body before storage</li>
/// <li>IRIS user created/updated/deleted via Security.Users in %SYS namespace</li>
/// <li>No credentials stored outside IRIS user directory (NFR-S1)</li>
/// </ul>
Class IRISCouch.Auth.Users Extends %RegisteredObject
{

/// <p>Number of PBKDF2 iterations for password hashing (NFR-S2: >= 10,000).</p>
Parameter ITERATIONS = 10000;

/// <p>Length of random salt in bytes.</p>
Parameter SALTLENGTH = 16;

/// <p>PBKDF2 derived key length in bytes (SHA-256 output).</p>
Parameter DKLENGTH = 20;

/// <p>Check if a database name is the <code>_users</code> system database.</p>
/// @param pDB The database name
/// @return %Boolean 1 if pDB is "_users", 0 otherwise
ClassMethod IsUsersDB(pDB As %String) As %Boolean
{
    Quit (pDB = "_users")
}

/// <p>Extract username from a CouchDB user document ID.</p>
/// <p>Parses the <code>org.couchdb.user:&lt;name&gt;</code> format.
/// Returns empty string if the format does not match.</p>
/// @param pDocId The document ID (e.g., "org.couchdb.user:alice")
/// @return %String The extracted username, or "" if invalid format
ClassMethod ExtractUsername(pDocId As %String) As %String
{
    Set tPrefix = "org.couchdb.user:"
    If $Extract(pDocId, 1, $Length(tPrefix)) '= tPrefix {
        Quit ""
    }
    Set tName = $Extract(pDocId, $Length(tPrefix) + 1, *)
    If tName = "" Quit ""
    Quit tName
}

/// <p>Process a user document save — the <code>before_doc_update</code> hook.</p>
/// <p>Called by <class>IRISCouch.Core.DocumentEngine</class> AFTER normal document
/// save but WITHIN the transaction. Handles password hashing, IRIS user sync,
/// and field stripping.</p>
/// <h4>Processing steps:</h4>
/// <ol>
/// <li>Extract username from document ID</li>
/// <li>If password field exists: hash it, create/update IRIS user, add metadata, strip password</li>
/// <li>If no password: update roles only if present</li>
/// <li>Return modified body (password stripped, metadata added)</li>
/// </ol>
/// @param pDB The database name (must be "_users")
/// @param pDocId The document ID (e.g., "org.couchdb.user:alice")
/// @param pBody The document body as %DynamicObject
/// @return %DynamicObject The modified body with password stripped and metadata added
ClassMethod OnUserDocSave(pDB As %String, pDocId As %String, pBody As %DynamicObject) As %DynamicObject
{
    Set tResult = pBody
    Try {
        ; Only process _users database
        If '..IsUsersDB(pDB) Quit
        ; Extract username from doc ID
        Set tUsername = ..ExtractUsername(pDocId)
        If tUsername = "" Quit
        ; Check if password field exists
        Set tPassword = pBody.%Get("password")
        If (tPassword '= "") {
            ; Generate random salt (16 bytes -> hex)
            Set tSaltBytes = $System.Encryption.GenCryptRand(..#SALTLENGTH)
            Set tSaltHex = $ZConvert(##class(%xsd.hexBinary).LogicalToXSD(tSaltBytes), "L")
            ; Compute PBKDF2-SHA256 derived key
            Set tDerivedBytes = ..PBKDF2SHA256(tPassword, tSaltHex, ..#ITERATIONS, ..#DKLENGTH)
            If tDerivedBytes = "" {
                Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "PBKDF2 key derivation failed"))
            }
            Set tDerivedHex = $ZConvert(##class(%xsd.hexBinary).LogicalToXSD(tDerivedBytes), "L")
            ; Create or update IRIS user with cleartext password
            ; (IRIS hashes it internally)
            Set tRoles = ..ExtractRoles(pBody)
            Set tSC = ..CreateOrUpdateIRISUser(tUsername, tPassword, tRoles)
            If $$$ISERR(tSC) {
                ; Throw to trigger rollback in DocumentEngine
                Throw ##class(%Exception.StatusException).CreateFromStatus(tSC)
            }
            ; Build modified body with CouchDB-compatible metadata
            ; Remove password and old hashing fields, add new ones
            Set tResult = ..StripAndAddMetadata(pBody, tSaltHex, tDerivedHex, ..#ITERATIONS)
            Quit
        }
        ; No password field — still sync roles if user exists
        Set tRoles = ..ExtractRoles(pBody)
        If tRoles '= "" {
            Set tOrigNS = $Namespace
            Set $Namespace = "%SYS"
            Set tExists = ""
            Do ##class(Security.Users).Exists(tUsername, .tExists)
            Set $Namespace = tOrigNS
            If tExists '= "" {
                Set tSC = ..UpdateIRISUserRoles(tUsername, tRoles)
                If $$$ISERR(tSC) {
                    Throw ##class(%Exception.StatusException).CreateFromStatus(tSC)
                }
            }
        }
        Quit
    }
    Catch ex {
        ; Restore namespace if switched during roles-only path
        If $Get(tOrigNS) '= "" Set $Namespace = tOrigNS
        ; Re-throw to let DocumentEngine handle rollback
        Throw ex
    }
    Quit tResult
}

/// <p>Process a user document deletion.</p>
/// <p>Called by <class>IRISCouch.Core.DocumentEngine</class> when deleting a
/// document in the <code>_users</code> database. Removes the corresponding
/// IRIS user via <code>Security.Users.Delete()</code>.</p>
/// @param pDB The database name (must be "_users")
/// @param pDocId The document ID (e.g., "org.couchdb.user:alice")
ClassMethod OnUserDocDelete(pDB As %String, pDocId As %String)
{
    Try {
        ; Only process _users database
        If '..IsUsersDB(pDB) Quit
        ; Extract username from doc ID
        Set tUsername = ..ExtractUsername(pDocId)
        If tUsername = "" Quit
        ; Delete IRIS user
        Set tOrigNS = $Namespace
        Set $Namespace = "%SYS"
        ; Check if user exists before deleting
        Set tExists = ""
        Do ##class(Security.Users).Exists(tUsername, .tExists)
        If tExists '= "" {
            Set tSC = ##class(Security.Users).Delete(tUsername)
            If $$$ISERR(tSC) {
                Set $Namespace = tOrigNS
                Throw ##class(%Exception.StatusException).CreateFromStatus(tSC)
            }
        }
        Set $Namespace = tOrigNS
        Quit
    }
    Catch ex {
        ; Restore namespace on error
        If $Get(tOrigNS) '= "" Set $Namespace = tOrigNS
        ; Re-throw to let DocumentEngine handle rollback
        Throw ex
    }
}

/// <p>Create or update an IRIS user via Security.Users.</p>
/// <p>Switches to <code>%SYS</code> namespace to access Security.Users.
/// If the user exists, modifies password and roles. If new, creates the user.
/// Restores namespace after operation.</p>
/// @param pUsername The IRIS username to create or update
/// @param pPassword The cleartext password (IRIS hashes internally)
/// @param pRoles Comma-separated role string
/// @return %Status
ClassMethod CreateOrUpdateIRISUser(pUsername As %String, pPassword As %String, pRoles As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $Namespace
    Try {
        Set $Namespace = "%SYS"
        ; Check if user exists (Exists returns error status when not found
        ; and does NOT set the output parameter, so initialize first)
        Set tExists = ""
        Do ##class(Security.Users).Exists(pUsername, .tExists)
        If tExists '= "" {
            ; Modify existing user
            Set tProps("Password") = pPassword
            If pRoles '= "" {
                Set tProps("Roles") = pRoles
            }
            Set tSC = ##class(Security.Users).Modify(pUsername, .tProps)
        } Else {
            ; Create new user
            Set tProps("Password") = pPassword
            If pRoles '= "" {
                Set tProps("Roles") = pRoles
            }
            Set tSC = ##class(Security.Users).Create(pUsername, .tProps)
        }
        Set $Namespace = tOrigNS
        Quit
    }
    Catch ex {
        Set $Namespace = tOrigNS
        Set tSC = ex.AsStatus()
        Quit
    }
    Quit tSC
}

/// <p>Update only the roles for an existing IRIS user.</p>
/// @param pUsername The IRIS username
/// @param pRoles Comma-separated role string
/// @return %Status
ClassMethod UpdateIRISUserRoles(pUsername As %String, pRoles As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $Namespace
    Try {
        Set $Namespace = "%SYS"
        Set tProps("Roles") = pRoles
        Set tSC = ##class(Security.Users).Modify(pUsername, .tProps)
        Set $Namespace = tOrigNS
        Quit
    }
    Catch ex {
        Set $Namespace = tOrigNS
        Set tSC = ex.AsStatus()
        Quit
    }
    Quit tSC
}

/// <p>Compute PBKDF2-SHA256 key derivation.</p>
/// <p>Implements PBKDF2 using iterated HMAC-SHA256, compatible with
/// CouchDB's password hashing. Uses <code>$System.Encryption.HMACSHA(256)</code>
/// as the underlying PRF.</p>
/// @param pPassword The password string
/// @param pSalt The salt string (hex-encoded)
/// @param pIterations Number of HMAC iterations
/// @param pDKLen Desired key length in bytes
/// @return %String The derived key as raw bytes
ClassMethod PBKDF2SHA256(pPassword As %String, pSalt As %String, pIterations As %Integer, pDKLen As %Integer) As %String
{
    Set tResult = ""
    Try {
        ; PBKDF2 with single block (dkLen <= hash output length of 32 bytes)
        ; U1 = HMAC(password, salt || INT(1))
        ; INT(1) is big-endian 4-byte representation of block number 1
        Set tBlockNum = $Char(0, 0, 0, 1)
        Set tU = $System.Encryption.HMACSHA(256, pSalt _ tBlockNum, pPassword)
        Set tDK = tU
        ; Iterate: U_i = HMAC(password, U_{i-1}), DK = DK XOR U_i
        For tI = 2:1:pIterations {
            Set tU = $System.Encryption.HMACSHA(256, tU, pPassword)
            ; XOR the current U with accumulated DK
            Set tNewDK = ""
            For tJ = 1:1:$Length(tDK) {
                Set tNewDK = tNewDK _ $Char($ZBoolean($Ascii(tDK, tJ), $Ascii(tU, tJ), 6))
            }
            Set tDK = tNewDK
        }
        ; Truncate to desired key length
        Set tResult = $Extract(tDK, 1, pDKLen)
        Quit
    }
    Catch ex {
        Set tResult = ""
        Quit
    }
    Quit tResult
}

/// <p>Strip password fields and add CouchDB-compatible hashing metadata.</p>
/// <p>Removes <code>password</code>, <code>password_sha</code>, and
/// <code>preserve_salt</code> fields from the body and adds
/// PBKDF2 metadata fields (per couch_users_db.erl).</p>
/// @param pBody The original document body
/// @param pSalt The hex-encoded salt
/// @param pDerivedKey The hex-encoded derived key
/// @param pIterations The iteration count
/// @return %DynamicObject The modified body
ClassMethod StripAndAddMetadata(pBody As %DynamicObject, pSalt As %String, pDerivedKey As %String, pIterations As %Integer) As %DynamicObject
{
    Set tNew = {}
    ; Copy all fields except password-related ones
    Set tIter = pBody.%GetIterator()
    While tIter.%GetNext(.tKey, .tVal) {
        ; Skip password fields (per couch_users_db.erl remove_password_fields)
        If (tKey = "password") Continue
        If (tKey = "password_sha") Continue
        If (tKey = "preserve_salt") Continue
        If (tKey = "password_scheme") Continue
        If (tKey = "derived_key") Continue
        If (tKey = "salt") Continue
        If (tKey = "iterations") Continue
        If (tKey = "pbkdf2_prf") Continue
        ; Preserve the type for special values
        Set tType = pBody.%GetTypeOf(tKey)
        If tType = "boolean" {
            Do tNew.%Set(tKey, tVal, "boolean")
        } ElseIf tType = "number" {
            Do tNew.%Set(tKey, tVal, "number")
        } ElseIf tType = "null" {
            Do tNew.%Set(tKey, "", "null")
        } ElseIf tType = "array" || (tType = "object") {
            Do tNew.%Set(tKey, tVal)
        } Else {
            Do tNew.%Set(tKey, tVal)
        }
    }
    ; Add PBKDF2 metadata (per couch_users_db.erl)
    Do tNew.%Set("password_scheme", "pbkdf2")
    Do tNew.%Set("pbkdf2_prf", "sha256")
    Do tNew.%Set("derived_key", pDerivedKey)
    Do tNew.%Set("salt", pSalt)
    Do tNew.%Set("iterations", pIterations, "number")
    Quit tNew
}

/// <p>Extract roles from a user document body as a comma-separated string.</p>
/// <p>Reads the <code>roles</code> field (expected to be a JSON array)
/// and converts to a comma-separated string for IRIS Security.Users.</p>
/// @param pBody The document body
/// @return %String Comma-separated roles, or "" if no roles
ClassMethod ExtractRoles(pBody As %DynamicObject) As %String
{
    Set tResult = ""
    Try {
        Set tRoles = pBody.%Get("roles")
        If '$IsObject(tRoles) Quit
        Set tSize = tRoles.%Size()
        For tI = 0:1:(tSize - 1) {
            Set tRole = tRoles.%Get(tI)
            If tRole '= "" {
                If tResult '= "" Set tResult = tResult _ ","
                Set tResult = tResult _ tRole
            }
        }
        Quit
    }
    Catch ex {
        Set tResult = ""
        Quit
    }
    Quit tResult
}

}
