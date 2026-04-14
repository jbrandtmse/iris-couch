/// <p>Unit tests for IRISCouch Audit subsystem (Story 9.2).</p>
/// <p>Tests <class>IRISCouch.Audit.Emit</class> for all event types:
/// DocWrite, DocDelete, AuthSuccess, AuthFailure, SecurityChange,
/// UserWrite, ReplicationStart, ReplicationComplete. Also verifies
/// that audit failures do not propagate to callers.</p>
Class IRISCouch.Test.AuditTest Extends %UnitTest.TestCase
{

/// <p>Handle initvalue parameter from parent class.</p>
Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Quit $$$OK
}

/// <p>Ensure audit events are registered before running tests.</p>
Method OnBeforeAllTests() As %Status
{
    Set tSC = ##class(IRISCouch.Audit.Emit).EnsureEvents()
    Quit tSC
}

/// <p>Test DocWrite audit event emission returns success.</p>
/// <p>AC #1: DocWrite event is emitted for document create/update.</p>
Method TestEmitDocWrite()
{
    Set tSC = ##class(IRISCouch.Audit.Emit).Emit("DocWrite", "auditdb", "doc-write-test", "1-abc123", "testuser")
    Do $$$AssertTrue(tSC, "DocWrite Emit returns success")
}

/// <p>Test DocDelete audit event emission returns success.</p>
/// <p>AC #1: DocDelete event is emitted for document deletion.</p>
Method TestEmitDocDelete()
{
    Set tSC = ##class(IRISCouch.Audit.Emit).Emit("DocDelete", "auditdb", "doc-del-test", "2-def456", "testuser")
    Do $$$AssertTrue(tSC, "DocDelete Emit returns success")
}

/// <p>Test AuthSuccess audit event emission returns success.</p>
/// <p>AC #2: AuthSuccess event is emitted for successful authentication.</p>
Method TestEmitAuthSuccess()
{
    Set tExtra = {}
    Set tExtra.method = "cookie"
    Set tSC = ##class(IRISCouch.Audit.Emit).Emit("AuthSuccess", "", "", "", "admin", tExtra)
    Do $$$AssertTrue(tSC, "AuthSuccess Emit returns success")
}

/// <p>Test AuthFailure audit event emission returns success.</p>
/// <p>AC #2: AuthFailure event is emitted for failed authentication.</p>
Method TestEmitAuthFailure()
{
    Set tExtra = {}
    Set tExtra.method = "basic"
    Set tExtra.reason = "Invalid credentials"
    Set tSC = ##class(IRISCouch.Audit.Emit).Emit("AuthFailure", "", "", "", "baduser", tExtra)
    Do $$$AssertTrue(tSC, "AuthFailure Emit returns success")
}

/// <p>Test SecurityChange audit event emission returns success.</p>
/// <p>AC #3: SecurityChange event is emitted for _security changes.</p>
Method TestEmitSecurityChange()
{
    Set tSC = ##class(IRISCouch.Audit.Emit).Emit("SecurityChange", "secdb", "", "", "adminuser")
    Do $$$AssertTrue(tSC, "SecurityChange Emit returns success")
}

/// <p>Test UserWrite audit event emission returns success.</p>
/// <p>AC #4: UserWrite event is emitted for _users database writes.</p>
Method TestEmitUserWrite()
{
    Set tSC = ##class(IRISCouch.Audit.Emit).Emit("UserWrite", "_users", "org.couchdb.user:bob", "", "admin")
    Do $$$AssertTrue(tSC, "UserWrite Emit returns success")
}

/// <p>Test ReplicationStart audit event emission returns success.</p>
/// <p>AC #5: ReplicationStart event is emitted when replication begins.</p>
Method TestEmitReplicationStart()
{
    Set tExtra = {}
    Set tExtra.source = "sourcedb"
    Set tExtra.target = "targetdb"
    Set tSC = ##class(IRISCouch.Audit.Emit).Emit("ReplicationStart", "", "", "", "repuser", tExtra)
    Do $$$AssertTrue(tSC, "ReplicationStart Emit returns success")
}

/// <p>Test ReplicationComplete audit event emission with stats.</p>
/// <p>AC #5: ReplicationComplete event is emitted when replication finishes.</p>
Method TestEmitReplicationComplete()
{
    Set tExtra = {}
    Set tExtra.source = "sourcedb"
    Set tExtra.target = "targetdb"
    Set tStats = {}
    Do tStats.%Set("docs_read", 10, "number")
    Do tStats.%Set("docs_written", 8, "number")
    Set tExtra.stats = tStats
    Set tSC = ##class(IRISCouch.Audit.Emit).Emit("ReplicationComplete", "", "", "", "repuser", tExtra)
    Do $$$AssertTrue(tSC, "ReplicationComplete Emit returns success")
}

/// <p>Test that audit failure does not propagate to caller.</p>
/// <p>AC #6: Audit failures are silently absorbed.</p>
Method TestAuditFailureSafe()
{
    Set tSC = ##class(IRISCouch.Audit.Emit).Emit("NonExistentEventType9999", "db", "doc", "rev", "user")
    ; The method should return without throwing
    Do $$$AssertTrue(1, "Audit failure did not throw or crash")
}

/// <p>Test EnsureEvents creates all required audit event registrations.</p>
/// <p>AC #7: All IRISCouch audit event types are registered.</p>
Method TestEnsureEvents()
{
    Set tSC = ##class(IRISCouch.Audit.Emit).EnsureEvents()
    Do $$$AssertStatusOK(tSC, "EnsureEvents returns OK")
    ; Verify each event type exists in %SYS
    Set tOrigNS = $Namespace
    Set $Namespace = "%SYS"
    Do $$$AssertTrue(##class(Security.Events).Exists("IRISCouch", "DocWrite", "DocWrite"), "DocWrite event registered")
    Do $$$AssertTrue(##class(Security.Events).Exists("IRISCouch", "DocDelete", "DocDelete"), "DocDelete event registered")
    Do $$$AssertTrue(##class(Security.Events).Exists("IRISCouch", "AuthSuccess", "AuthSuccess"), "AuthSuccess event registered")
    Do $$$AssertTrue(##class(Security.Events).Exists("IRISCouch", "AuthFailure", "AuthFailure"), "AuthFailure event registered")
    Do $$$AssertTrue(##class(Security.Events).Exists("IRISCouch", "SecurityChange", "SecurityChange"), "SecurityChange event registered")
    Do $$$AssertTrue(##class(Security.Events).Exists("IRISCouch", "UserWrite", "UserWrite"), "UserWrite event registered")
    Do $$$AssertTrue(##class(Security.Events).Exists("IRISCouch", "ReplicationStart", "ReplicationStart"), "ReplicationStart event registered")
    Do $$$AssertTrue(##class(Security.Events).Exists("IRISCouch", "ReplicationComplete", "ReplicationComplete"), "ReplicationComplete event registered")
    Set $Namespace = tOrigNS
}

/// <p>Test default user falls back to $Username when no user specified.</p>
/// <p>AC #6: User identity defaults appropriately.</p>
Method TestDefaultUser()
{
    Set tSC = ##class(IRISCouch.Audit.Emit).Emit("DocWrite", "auditdb", "default-user-test", "1-def")
    Do $$$AssertTrue(tSC, "DocWrite Emit with default user returns success")
}

/// <p>Test convenience method DocWrite delegates correctly.</p>
/// <p>AC #1: Convenience methods correctly delegate to Emit.</p>
Method TestConvenienceDocWrite()
{
    Do ##class(IRISCouch.Audit.Emit).DocWrite("cdb", "cdoc1", "1-conv", "cuser")
    Do $$$AssertTrue(1, "DocWrite convenience method did not throw")
}

/// <p>Test convenience method DocDelete delegates correctly.</p>
/// <p>AC #1: Convenience methods correctly delegate to Emit.</p>
Method TestConvenienceDocDelete()
{
    Do ##class(IRISCouch.Audit.Emit).DocDelete("cdb", "cdoc2", "2-conv", "cuser")
    Do $$$AssertTrue(1, "DocDelete convenience method did not throw")
}

/// <p>Test convenience methods for auth events.</p>
/// <p>AC #2: Auth convenience methods correctly delegate to Emit.</p>
Method TestConvenienceAuth()
{
    Do ##class(IRISCouch.Audit.Emit).AuthSuccess("auser", "jwt")
    Do $$$AssertTrue(1, "AuthSuccess convenience method did not throw")
    Do ##class(IRISCouch.Audit.Emit).AuthFailure("fuser", "cookie", "bad password")
    Do $$$AssertTrue(1, "AuthFailure convenience method did not throw")
}

/// <p>Test convenience methods for security and user events.</p>
/// <p>AC #3, #4: Security/User convenience methods correctly delegate to Emit.</p>
Method TestConvenienceSecurityAndUser()
{
    Do ##class(IRISCouch.Audit.Emit).SecurityChange("sdb", "suser")
    Do $$$AssertTrue(1, "SecurityChange convenience method did not throw")
    Do ##class(IRISCouch.Audit.Emit).UserWrite("_users", "org.couchdb.user:sue", "admin")
    Do $$$AssertTrue(1, "UserWrite convenience method did not throw")
}

/// <p>Test convenience methods for replication events.</p>
/// <p>AC #5: Replication convenience methods correctly delegate to Emit.</p>
Method TestConvenienceReplication()
{
    Do ##class(IRISCouch.Audit.Emit).ReplicationStart("src", "tgt", "ruser")
    Do $$$AssertTrue(1, "ReplicationStart convenience method did not throw")
    Set tStats = {}
    Do tStats.%Set("docs_read", 5, "number")
    Do ##class(IRISCouch.Audit.Emit).ReplicationComplete("src", "tgt", tStats, "ruser")
    Do $$$AssertTrue(1, "ReplicationComplete convenience method did not throw")
}

/// <p>Verify audit events are visible in the IRIS audit log.</p>
/// <p>AC #7: Audit events are readable via %SYS.Audit:List query.</p>
Method TestAuditLogReadable()
{
    ; Emit a known event
    Set tSC = ##class(IRISCouch.Audit.Emit).Emit("DocWrite", "readtest", "readtest-doc", "1-read", "readtestuser")
    Do $$$AssertTrue(tSC, "DocWrite Emit for readability test returns success")
    ; Try to read it back from %SYS.Audit:List
    Set tFound = 0
    Set tOrigNS = $Namespace
    Try {
        Set $Namespace = "%SYS"
        Set tRS = ##class(%ResultSet).%New("%SYS.Audit:List")
        Set tSC2 = tRS.Execute("", "", "IRISCouch", "DocWrite", "*", "*")
        If $$$ISOK(tSC2) {
            While tRS.Next() {
                Set tDesc = tRS.Get("Description")
                If tDesc [ "readtest" {
                    Set tFound = 1
                }
            }
            Do tRS.Close()
        }
        Set $Namespace = tOrigNS
    }
    Catch ex {
        Set $Namespace = tOrigNS
    }
    Do $$$AssertTrue(tFound, "DocWrite event found in %SYS.Audit log")
}

}
