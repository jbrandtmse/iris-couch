/// <p>HTTP handler for database lifecycle operations.</p>
/// <p>Handles <code>PUT /{db}</code> (create) and <code>DELETE /{db}</code>
/// (delete) requests. Delegates to <class>IRISCouch.Storage.Database</class>
/// for all global access (Pattern 3: Storage Encapsulation).</p>
Class IRISCouch.API.DatabaseHandler Extends %RegisteredObject
{

/// <p>Handle <code>PUT /{db}</code> — create a new database.</p>
/// <p>Validates the database name, checks for existence, and creates the
/// database with initialized metadata. Returns 201 on success, 400 for
/// invalid names, 412 if the database already exists.</p>
/// @param pDB The database name from the URL path
/// @return %Status
ClassMethod HandleCreate(pDB As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        ; Validate database name
        Set tSC = ##class(IRISCouch.Storage.Database).ValidateName(pDB)
        If $$$ISERR(tSC) {
            Do ##class(IRISCouch.Util.Error).Render(400, ##class(IRISCouch.Util.Error).#ILLEGALDATABASENAME, $System.Status.GetErrorText(tSC))
            Quit
        }
        ; Check if database already exists
        If ##class(IRISCouch.Storage.Database).Exists(pDB) {
            Do ##class(IRISCouch.Util.Error).Render(412, ##class(IRISCouch.Util.Error).#FILEEXISTS, "The database could not be created, the file already exists.")
            Quit
        }
        ; Create the database
        Set tSC = ##class(IRISCouch.Storage.Database).Create(pDB)
        If $$$ISERR(tSC) {
            Do ##class(IRISCouch.Util.Error).RenderInternal(##class(IRISCouch.Util.Error).#SERVERERROR, "database: create error")
            Quit
        }
        ; Return 201 Created with {"ok": true}
        Do ##class(IRISCouch.Util.Response).JSONStatus(201, {"ok": true})
        Quit
    }
    Catch ex {
        Do ##class(IRISCouch.Util.Error).RenderInternal(##class(IRISCouch.Util.Error).#SERVERERROR, "database: create error", ex)
        Quit
    }
    Quit $$$OK
}

/// <p>Handle <code>GET /{db}</code> — retrieve database metadata.</p>
/// <p>Returns CouchDB-compatible database info including document count,
/// update sequence, disk size, and other metadata fields. Returns 404
/// if the database does not exist.</p>
/// @param pDB The database name from the URL path
/// @return %Status
ClassMethod HandleInfo(pDB As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        ; Check if database exists
        If '##class(IRISCouch.Storage.Database).Exists(pDB) {
            Do ##class(IRISCouch.Util.Error).Render(404, ##class(IRISCouch.Util.Error).#NOTFOUND, "Database does not exist.")
            Quit
        }
        ; Get database metadata
        Set tInfo = ##class(IRISCouch.Storage.Database).GetInfo(pDB)
        If '$IsObject(tInfo) {
            Do ##class(IRISCouch.Util.Error).RenderInternal(##class(IRISCouch.Util.Error).#SERVERERROR, "database: info error")
            Quit
        }
        ; Return 200 OK with metadata
        Do ##class(IRISCouch.Util.Response).JSON(tInfo)
        Quit
    }
    Catch ex {
        Do ##class(IRISCouch.Util.Error).RenderInternal(##class(IRISCouch.Util.Error).#SERVERERROR, "database: info error", ex)
        Quit
    }
    Quit $$$OK
}

/// <p>Handle <code>GET /_all_dbs</code> — list all databases.</p>
/// <p>Returns a JSON array of all database names sorted alphabetically.
/// Returns an empty array if no databases exist.</p>
/// @return %Status
ClassMethod HandleAllDbs() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tDbs = ##class(IRISCouch.Storage.Database).ListAll()
        Do ##class(IRISCouch.Util.Response).JSON(tDbs)
        Quit
    }
    Catch ex {
        Do ##class(IRISCouch.Util.Error).RenderInternal(##class(IRISCouch.Util.Error).#SERVERERROR, "database: list error", ex)
        Quit
    }
    Quit $$$OK
}

/// <p>Handle <code>GET /{db}/_revs_limit</code> — retrieve the revision retention limit.</p>
/// <p>Returns the current revs_limit value as a plain integer. Returns 404
/// if the database does not exist.</p>
/// @param pDB The database name from the URL path
/// @return %Status
ClassMethod HandleRevsLimitGet(pDB As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        ; Check if database exists
        If '##class(IRISCouch.Storage.Database).Exists(pDB) {
            Do ##class(IRISCouch.Util.Error).Render(404, ##class(IRISCouch.Util.Error).#NOTFOUND, "Database does not exist.")
            Quit
        }
        ; Return revs_limit as plain integer
        Set tLimit = ##class(IRISCouch.Storage.Database).GetRevsLimit(pDB)
        Do ##class(IRISCouch.Util.Response).JSON(tLimit)
        Quit
    }
    Catch ex {
        Do ##class(IRISCouch.Util.Error).RenderInternal(##class(IRISCouch.Util.Error).#SERVERERROR, "database: revs_limit get error", ex)
        Quit
    }
    Quit $$$OK
}

/// <p>Handle <code>PUT /{db}/_revs_limit</code> — set the revision retention limit.</p>
/// <p>Reads the request body as a raw integer, validates it is a positive integer,
/// and stores it in the database metadata. Returns 200 OK with the value on success,
/// 400 if the body is not a valid positive integer, 404 if the database does not exist.</p>
/// @param pDB The database name from the URL path
/// @return %Status
ClassMethod HandleRevsLimitPut(pDB As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        ; Check if database exists
        If '##class(IRISCouch.Storage.Database).Exists(pDB) {
            Do ##class(IRISCouch.Util.Error).Render(404, ##class(IRISCouch.Util.Error).#NOTFOUND, "Database does not exist.")
            Quit
        }
        ; Read raw request body
        Set tContent = ""
        If $IsObject(%request.Content) {
            Set tContent = %request.Content.Read()
        }
        ; Trim whitespace and validate positive integer
        Set tContent = $ZStrip(tContent, "<>W")
        If (tContent '= +tContent) || (tContent < 1) || (tContent \ 1 '= tContent) {
            Do ##class(IRISCouch.Util.Error).Render(400, ##class(IRISCouch.Util.Error).#BADREQUEST, "Body must be a positive integer")
            Quit
        }
        ; Set revs_limit
        Set tSC = ##class(IRISCouch.Storage.Database).SetRevsLimit(pDB, +tContent)
        If $$$ISERR(tSC) {
            Do ##class(IRISCouch.Util.Error).RenderInternal(##class(IRISCouch.Util.Error).#SERVERERROR, "database: revs_limit set error")
            Quit
        }
        ; Return 200 OK with the value as plain integer
        Do ##class(IRISCouch.Util.Response).JSON(+tContent)
        Quit
    }
    Catch ex {
        Do ##class(IRISCouch.Util.Error).RenderInternal(##class(IRISCouch.Util.Error).#SERVERERROR, "database: revs_limit set error", ex)
        Quit
    }
    Quit $$$OK
}

/// <p>Handle <code>POST /{db}/_compact</code> — trigger database compaction.</p>
/// <p>IRIS globals do not require compaction like CouchDB's .couch files.
/// This is a no-op that returns 202 Accepted with <code>{"ok":true}</code>
/// for CouchDB API compatibility. Returns 404 if the database does not exist.</p>
/// @param pDB The database name from the URL path
/// @return %Status
ClassMethod HandleCompact(pDB As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        ; Check if database exists
        If '##class(IRISCouch.Storage.Database).Exists(pDB) {
            Do ##class(IRISCouch.Util.Error).Render(404, ##class(IRISCouch.Util.Error).#NOTFOUND, "Database does not exist.")
            Quit
        }
        ; Return 202 Accepted with {"ok": true} (no-op for IRIS)
        Do ##class(IRISCouch.Util.Response).JSONStatus(202, {"ok": true})
        Quit
    }
    Catch ex {
        Do ##class(IRISCouch.Util.Error).RenderInternal(##class(IRISCouch.Util.Error).#SERVERERROR, "database: compact error", ex)
        Quit
    }
    Quit $$$OK
}

/// <p>Handle <code>POST /{db}/_ensure_full_commit</code> — request a full commit.</p>
/// <p>IRIS journaling provides durability guarantees, so this is a no-op.
/// Returns 201 Created with <code>{"ok":true,"instance_start_time":"0"}</code>
/// for CouchDB API compatibility. Older replicators still call this endpoint.
/// Returns 404 if the database does not exist.</p>
/// @param pDB The database name from the URL path
/// @return %Status
ClassMethod HandleEnsureFullCommit(pDB As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        ; Check if database exists
        If '##class(IRISCouch.Storage.Database).Exists(pDB) {
            Do ##class(IRISCouch.Util.Error).Render(404, ##class(IRISCouch.Util.Error).#NOTFOUND, "Database does not exist.")
            Quit
        }
        ; Return 201 Created with {"ok": true, "instance_start_time": "0"} (no-op for IRIS)
        Set tObj = {}
        Do tObj.%Set("ok", 1, "boolean")
        Do tObj.%Set("instance_start_time", "0")
        Do ##class(IRISCouch.Util.Response).JSONStatus(201, tObj)
        Quit
    }
    Catch ex {
        Do ##class(IRISCouch.Util.Error).RenderInternal(##class(IRISCouch.Util.Error).#SERVERERROR, "database: ensure_full_commit error", ex)
        Quit
    }
    Quit $$$OK
}

/// <p>Handle <code>DELETE /{db}</code> — delete an existing database.</p>
/// <p>Checks for existence and deletes the database and all associated
/// globals. Returns 200 on success, 404 if the database does not exist.</p>
/// @param pDB The database name from the URL path
/// @return %Status
ClassMethod HandleDelete(pDB As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        ; Check if database exists
        If '##class(IRISCouch.Storage.Database).Exists(pDB) {
            Do ##class(IRISCouch.Util.Error).Render(404, ##class(IRISCouch.Util.Error).#NOTFOUND, "Database does not exist.")
            Quit
        }
        ; Delete the database
        Set tSC = ##class(IRISCouch.Storage.Database).Delete(pDB)
        If $$$ISERR(tSC) {
            Do ##class(IRISCouch.Util.Error).RenderInternal(##class(IRISCouch.Util.Error).#SERVERERROR, "database: delete error")
            Quit
        }
        ; Return 200 OK with {"ok": true}
        Do ##class(IRISCouch.Util.Response).JSON({"ok": true})
        Quit
    }
    Catch ex {
        Do ##class(IRISCouch.Util.Error).RenderInternal(##class(IRISCouch.Util.Error).#SERVERERROR, "database: delete error", ex)
        Quit
    }
    Quit $$$OK
}

}
