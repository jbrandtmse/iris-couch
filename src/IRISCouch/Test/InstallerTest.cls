/// <p>Unit tests for <class>IRISCouch.Installer</class>.</p>
/// <p>Validates web application installation, idempotency, uninstallation,
/// and source directory structure compatibility.</p>
Class IRISCouch.Test.InstallerTest Extends %UnitTest.TestCase
{

/// <p>Test web application path used by tests to avoid conflicts.</p>
Parameter TESTWEBAPPPATH = "/iris-couch-test-install/";

/// <p>Handle initvalue parameter from parent class.</p>
Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Quit $$$OK
}

/// <p>Clean up test web application after each test.</p>
Method OnAfterOneTest() As %Status
{
    ; Clean up test webapp if it was created
    Set tSC = ##class(IRISCouch.Installer).Uninstall(..#TESTWEBAPPPATH)
    Quit $$$OK
}

/// <p>Verify Install() creates a web application entry.</p>
/// <p>AC #1: All IRISCouch classes compile and webapp can be created.</p>
/// <p>AC #2: Webapp can be configured programmatically.</p>
Method TestInstallCreatesWebApp()
{
    ; Verify webapp does not exist before install
    Set tExists = ##class(IRISCouch.Installer).IsInstalled(..#TESTWEBAPPPATH)
    Do $$$AssertTrue('tExists, "Test webapp does not exist before install")

    ; Install the webapp
    Set tSC = ##class(IRISCouch.Installer).Install($Namespace, ..#TESTWEBAPPPATH)
    Do $$$AssertStatusOK(tSC, "Install returns OK status")

    ; Verify webapp now exists
    Set tExists = ##class(IRISCouch.Installer).IsInstalled(..#TESTWEBAPPPATH)
    Do $$$AssertTrue(tExists, "Test webapp exists after install")
}

/// <p>Verify running Install() twice does not produce an error.</p>
/// <p>AC #1: Idempotent installation handling.</p>
Method TestInstallIdempotent()
{
    ; First install
    Set tSC1 = ##class(IRISCouch.Installer).Install($Namespace, ..#TESTWEBAPPPATH)
    Do $$$AssertStatusOK(tSC1, "First Install returns OK")

    ; Second install should also succeed (skip existing)
    Set tSC2 = ##class(IRISCouch.Installer).Install($Namespace, ..#TESTWEBAPPPATH)
    Do $$$AssertStatusOK(tSC2, "Second Install returns OK (idempotent)")

    ; Verify webapp still exists
    Set tExists = ##class(IRISCouch.Installer).IsInstalled(..#TESTWEBAPPPATH)
    Do $$$AssertTrue(tExists, "Webapp exists after double install")
}

/// <p>Verify Uninstall() removes the web application.</p>
/// <p>AC #2: Cleanup is supported via programmatic uninstall.</p>
Method TestUninstallRemovesWebApp()
{
    ; Install first
    Set tSC = ##class(IRISCouch.Installer).Install($Namespace, ..#TESTWEBAPPPATH)
    Do $$$AssertStatusOK(tSC, "Install succeeds")

    ; Uninstall
    Set tSC = ##class(IRISCouch.Installer).Uninstall(..#TESTWEBAPPPATH)
    Do $$$AssertStatusOK(tSC, "Uninstall returns OK")

    ; Verify webapp is gone
    Set tExists = ##class(IRISCouch.Installer).IsInstalled(..#TESTWEBAPPPATH)
    Do $$$AssertTrue('tExists, "Webapp does not exist after uninstall")
}

/// <p>Verify Uninstall() on nonexistent webapp does not error.</p>
Method TestUninstallNonexistent()
{
    Set tSC = ##class(IRISCouch.Installer).Uninstall("/iris-couch-nonexistent-test/")
    Do $$$AssertStatusOK(tSC, "Uninstall of nonexistent webapp returns OK")
}

/// <p>Verify core IRISCouch classes exist and are compiled.</p>
/// <p>AC #1: Source structure supports $System.OBJ.ImportDir import.</p>
Method TestSourceStructure()
{
    ; Verify key classes are compiled and available
    Do $$$AssertTrue($$$comClassDefined("IRISCouch.Config"), "IRISCouch.Config class exists")
    Do $$$AssertTrue($$$comClassDefined("IRISCouch.API.Router"), "IRISCouch.API.Router class exists")
    Do $$$AssertTrue($$$comClassDefined("IRISCouch.API.ServerHandler"), "IRISCouch.API.ServerHandler class exists")
    Do $$$AssertTrue($$$comClassDefined("IRISCouch.Util.Error"), "IRISCouch.Util.Error class exists")
    Do $$$AssertTrue($$$comClassDefined("IRISCouch.Util.Response"), "IRISCouch.Util.Response class exists")
    Do $$$AssertTrue($$$comClassDefined("IRISCouch.Util.UUID"), "IRISCouch.Util.UUID class exists")
    Do $$$AssertTrue($$$comClassDefined("IRISCouch.Installer"), "IRISCouch.Installer class exists")
}

/// <p>Verify Install() defaults to current namespace when none specified.</p>
Method TestInstallDefaultNamespace()
{
    ; Install with empty namespace (should default to current)
    Set tSC = ##class(IRISCouch.Installer).Install("", ..#TESTWEBAPPPATH)
    Do $$$AssertStatusOK(tSC, "Install with default namespace returns OK")

    ; Verify webapp was created
    Set tExists = ##class(IRISCouch.Installer).IsInstalled(..#TESTWEBAPPPATH)
    Do $$$AssertTrue(tExists, "Webapp created with default namespace")
}

}
