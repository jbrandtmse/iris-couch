# Story 1.5: Manual ObjectScript Import Installation

Status: done

## Story

As an adopter without ZPM available,
I want to install IRISCouch manually via `$System.OBJ.ImportDir` with documented steps,
so that I can deploy IRISCouch in environments where ZPM is not installed.

## Acceptance Criteria

1. **Given** an IRIS instance without ZPM, **When** the adopter follows the documented manual import procedure using `$System.OBJ.ImportDir`, **Then** all IRISCouch ObjectScript classes compile cleanly.
2. **Given** the manual import is complete, **Then** the webapp can be configured manually via the IRIS Management Portal or programmatic setup.
3. **Given** manual setup is complete, **When** `GET /iris-couch/` is sent, **Then** the CouchDB welcome JSON is returned.
4. **Given** the repository, **Then** the installation documentation lists the exact commands and configuration steps required.
5. **Given** the repository structure, **Then** the directory structure supports both ZPM and manual import without modification.

## Tasks / Subtasks

- [x] Task 1: Create `IRISCouch.Installer` class (AC: #1, #2, #3)
  - [x] 1.1: Implement `Install(pNamespace, pWebAppPath)` classmethod that creates the web application programmatically
  - [x] 1.2: Use `%CSP.WebApplication` or Security.Applications API to create the webapp pointing to `IRISCouch.API.Router`
  - [x] 1.3: Configure webapp with `DispatchClass=IRISCouch.API.Router`, `NameSpace=<target>`, `AutheEnabled` for password auth
  - [x] 1.4: Handle case where webapp already exists (skip or update)
  - [x] 1.5: Implement `Uninstall(pWebAppPath)` classmethod for cleanup
- [x] Task 2: Create installation documentation (AC: #4, #5)
  - [x] 2.1: Document manual import steps: `Do $System.OBJ.ImportDir("/path/to/src/IRISCouch/", , "ck", , 1)`
  - [x] 2.2: Document programmatic webapp setup: `Do ##class(IRISCouch.Installer).Install($Namespace, "/iris-couch/")`
  - [x] 2.3: Document Management Portal manual webapp setup steps as alternative
  - [x] 2.4: Document verification: `curl http://localhost:52773/iris-couch/` returns welcome JSON
  - [x] 2.5: Add installation section to README.md
- [x] Task 3: Create `IRISCouch.Test.InstallerTest` class (AC: #1, #2)
  - [x] 3.1: `TestInstallCreatesWebApp` — verify Installer.Install() can create a webapp entry
  - [x] 3.2: `TestInstallIdempotent` — verify running Install() twice doesn't error
  - [x] 3.3: `TestSourceStructure` — verify src/IRISCouch/ directory is importable (classes exist)
- [x] Task 4: Verify directory structure compatibility (AC: #5)
  - [x] 4.1: Verify `src/IRISCouch/` contains only `.cls` files that `$System.OBJ.ImportDir` can process
  - [x] 4.2: Verify `module.xml` (ZPM) and manual import paths are compatible
- [x] Task 5: Compile and validate
  - [x] 5.1: Compile all new classes
  - [x] 5.2: Run all tests including InstallerTest — verify no regressions

### Review Findings
- [x] [Review][Patch] README placeholder `your-org` in git clone URL replaced with actual org `jbrandtmse` [README.md:67] -- auto-resolved
- [x] [Review][Patch] README "Under Construction" section claimed no code committed -- updated to reflect current pre-alpha state [README.md:5-12] -- auto-resolved

## Dev Notes

### Previous Story Intelligence (Stories 1.1-1.4)

**Current project source structure:**
```
src/IRISCouch/
├── Config.cls
├── API/
│   ├── Router.cls
│   └── ServerHandler.cls
├── Util/
│   ├── Error.cls
│   ├── Response.cls
│   ├── Request.cls
│   └── UUID.cls
└── Test/
    ├── ConfigTest.cls
    ├── RouterTest.cls
    ├── UUIDTest.cls
    └── ErrorEnvelopeTest.cls
```

**module.xml (ZPM) already configured:**
- `<SourcesRoot>src</SourcesRoot>`
- `<Resource Name="IRISCouch.PKG"/>`

**Key patterns from prior stories:**
- All classes compile in IRISCOUCH namespace
- Router extends `%CSP.REST` with `DispatchClass` pattern
- 20 tests passing across 4 test classes

### Architecture Compliance

- **Installer class goes in `IRISCouch.Installer`** — top-level utility, not under a subdirectory
- **Web application creation** requires `%SYS` namespace access for `Security.Applications` API
- **Namespace switching pattern (CRITICAL):** Never use `New $NAMESPACE`. Use explicit save/restore:
  ```objectscript
  Set tOrigNS = $NAMESPACE
  Set $NAMESPACE = "%SYS"
  ; ... work in %SYS ...
  Set $NAMESPACE = tOrigNS
  ```
- **In catch blocks, ALWAYS restore namespace first:** `Set $NAMESPACE = tOrigNS`

### Web Application Creation via Security.Applications

```objectscript
ClassMethod Install(pNamespace As %String = "", pWebAppPath As %String = "/iris-couch/") As %Status
{
    Set tSC = $$$OK
    Try {
        If pNamespace = "" Set pNamespace = $Namespace
        
        ; Switch to %SYS for Security.Applications access
        Set tOrigNS = $NAMESPACE
        Set $NAMESPACE = "%SYS"
        
        ; Check if webapp already exists
        If ##class(Security.Applications).Exists(pWebAppPath) {
            Set $NAMESPACE = tOrigNS
            Quit  ; Already installed
        }
        
        ; Create properties for new web application
        Set tProps("NameSpace") = pNamespace
        Set tProps("DispatchClass") = "IRISCouch.API.Router"
        Set tProps("AutheEnabled") = 64  ; Password auth
        Set tProps("Enabled") = 1
        Set tProps("IsNameSpaceDefault") = 0
        Set tProps("Description") = "IRISCouch - CouchDB-compatible API"
        
        Set tSC = ##class(Security.Applications).Create(pWebAppPath, .tProps)
        Set $NAMESPACE = tOrigNS
    }
    Catch ex {
        Set $NAMESPACE = $Get(tOrigNS, pNamespace)
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}
```

### Manual Import Command

The exact command for manual import:
```objectscript
Do $System.OBJ.ImportDir("/path/to/iris-couch/src/IRISCouch/", , "ck", , 1)
```

Parameters:
- Path to source directory
- Empty string (file spec — defaults to `*.cls`)
- `"ck"` flags: compile + keep source
- Empty string (error log)
- `1` = recursive (import subdirectories)

### README.md Installation Section

Add a section covering:
1. **ZPM (recommended):** `zpm "install iris-couch"`
2. **Manual import:**
   - Clone repo
   - `Do $System.OBJ.ImportDir("C:\path\to\iris-couch\src\IRISCouch\", , "ck", , 1)`
   - `Do ##class(IRISCouch.Installer).Install($Namespace, "/iris-couch/")`
3. **Verification:** `curl http://localhost:52773/iris-couch/`

### Testing Approach

- `TestInstallCreatesWebApp`: Call Install(), then check `Security.Applications.Exists()` — requires %SYS access
- `TestInstallIdempotent`: Call Install() twice, verify both return $$$OK
- `TestSourceStructure`: Verify key classes exist via `$$$comClassDefined("IRISCouch.Config")` etc.
- **IMPORTANT:** Tests that create webapps should clean up in `OnAfterOneTest` by calling `Uninstall()`

### What This Story Does NOT Include

- No ZPM repository publishing
- No Docker/container setup
- No CI/CD pipeline configuration
- No Angular UI build/setup

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 1.5] — Story requirements and acceptance criteria
- [Source: _bmad-output/planning-artifacts/architecture.md#Selected Foundation] — Project structure
- [Source: .claude/rules/iris-objectscript-basics.md#Namespace Switching] — Safe namespace switching pattern

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6 (1M context)

### Debug Log References
No debug issues encountered. All classes compiled on first attempt, all tests passed on first run.

### Completion Notes List
- Created `IRISCouch.Installer` class with `Install()`, `Uninstall()`, and `IsInstalled()` classmethods
- `Install()` uses `Security.Applications` API in `%SYS` namespace with safe save/restore namespace pattern
- `Install()` is idempotent -- skips creation if webapp already exists
- `Uninstall()` is safe -- returns OK if webapp does not exist
- Created `IRISCouch.Test.InstallerTest` with 6 tests: InstallCreatesWebApp, InstallIdempotent, UninstallRemovesWebApp, UninstallNonexistent, SourceStructure, InstallDefaultNamespace
- Tests use a dedicated test webapp path (`/iris-couch-test-install/`) to avoid conflicts, with cleanup in OnAfterOneTest
- Added comprehensive Installation section to README.md covering ZPM, manual import, programmatic setup, Management Portal setup, verification, and uninstall
- Verified all 13 source files in `src/IRISCouch/` are `.cls` files compatible with `$System.OBJ.ImportDir`
- Verified `module.xml` SourcesRoot=src and IRISCouch.PKG resource are compatible with manual import path
- Full regression suite: 25/25 tests passing (19 existing + 6 new)

### Change Log
- 2026-04-12: Story 1.5 implementation complete -- Installer class, tests, README installation docs

### File List
- src/IRISCouch/Installer.cls (new)
- src/IRISCouch/Test/InstallerTest.cls (new)
- README.md (modified -- added Installation section)
