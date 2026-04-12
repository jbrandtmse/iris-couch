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
