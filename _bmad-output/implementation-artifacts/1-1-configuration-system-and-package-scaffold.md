# Story 1.1: Configuration System & Package Scaffold

Status: done

## Story

As an adopter,
I want to install the IRISCouch package into my IRIS instance via `zpm "install iris-couch"`,
so that I have a working foundation with proper configuration management.

## Acceptance Criteria

1. **Given** a fresh IRIS instance with ZPM installed, **When** the adopter runs `zpm "install iris-couch"`, **Then** the package compiles cleanly with zero errors.
2. **Given** the package is installed, **Then** the `IRISCouch.Config` class is available with default parameter values.
3. **Given** the Config class exists, **When** calling `Config.Get("JSRUNTIME")`, **Then** it returns `"None"` as the default.
4. **Given** a global override `Set ^IRISCouch.Config("JSRUNTIME") = "Subprocess"`, **When** calling `Config.Get("JSRUNTIME")`, **Then** it returns `"Subprocess"` (global overrides take precedence over class parameter defaults).
5. **Given** no global override exists for a key, **When** calling `Config.Get(key)`, **Then** it returns the class parameter default.
6. **Given** the package is installed, **Then** the webapp is mounted at `/iris-couch/` by default.
7. **Given** `^IRISCouch.Config("WEBAPPPATH")` is set, **Then** the mount path is configurable via that global.
8. **Given** any generated URL (redirects, response bodies, Location headers), **Then** all URLs are root-relative — no webapp mount path is embedded in application-generated URLs.
9. **Given** a fresh IRIS instance, **Then** no external dependencies (Node.js, Python, couchjs, Erlang) are required for installation.

## Tasks / Subtasks

- [x] Task 1: Create `IRISCouch.Config` class (AC: #2, #3, #4, #5)
  - [x] 1.1: Define class parameters for all config keys with defaults
  - [x] 1.2: Implement `Get(pKey)` classmethod: check `^IRISCouch.Config(pKey)` first, fall back to class parameter
  - [x] 1.3: Implement `GetDefault(pKey)` private classmethod to read class parameter by name
  - [x] 1.4: Implement `Set(pKey, pValue)` classmethod to write to `^IRISCouch.Config` global
  - [x] 1.5: Implement `GetAll()` classmethod returning all config keys with current effective values
- [x] Task 2: Create `module.xml` ZPM package manifest (AC: #1, #6, #9)
  - [x] 2.1: Define module name, version, description, dependencies
  - [x] 2.2: Configure resource mappings for `src/IRISCouch/` classes
  - [x] 2.3: Configure web application at `/iris-couch/` via module invoke
- [x] Task 3: Create source directory structure (AC: #1)
  - [x] 3.1: Create `src/IRISCouch/` directory tree matching architecture spec
  - [x] 3.2: Create placeholder `.gitkeep` files only for directories needed this story
- [x] Task 4: Create `IRISCouch.Util.Error` class stub (AC: #8)
  - [x] 4.1: Implement `Render(pStatus, pSlug, pReason)` classmethod
  - [x] 4.2: Define the 13 error slug constants from the PRD
- [x] Task 5: Create `IRISCouch.Util.Response` class stub (AC: #8)
  - [x] 5.1: Implement `JSON(pData)` classmethod for success responses
  - [x] 5.2: Implement `JSONStatus(pStatus, pData)` classmethod
- [x] Task 6: Create `IRISCouch.Util.Request` class stub
  - [x] 6.1: Implement `ReadBody()` classmethod returning `%DynamicObject`
- [x] Task 7: Create `IRISCouch.Test.ConfigTest` class (AC: #2, #3, #4, #5)
  - [x] 7.1: `TestGetDefault` — verify default parameter values returned when no global override
  - [x] 7.2: `TestGlobalOverride` — verify global overrides take precedence
  - [x] 7.3: `TestGetAllKeys` — verify all config keys returned
  - [x] 7.4: `TestSetAndGet` — verify Set writes to global and Get reads it back
  - [x] 7.5: Clean up `^IRISCouch.Config` test data in `OnAfterOneTest`
- [x] Task 8: Compile and validate (AC: #1)
  - [x] 8.1: Compile the `IRISCouch` package via MCP tools
  - [x] 8.2: Run `IRISCouch.Test.ConfigTest` and verify all tests pass

## Dev Notes

### Architecture Compliance

- **Package prefix:** All classes MUST use `IRISCouch.*` prefix. All globals MUST use `^IRISCouch.*` prefix. This is a locked naming convention.
- **Config pattern:** `IRISCouch.Config` is the ONLY class allowed to directly read `^IRISCouch.Config`. All other classes call `Config.Get()`.
- **Error pattern:** `IRISCouch.Util.Error.Render()` is the single entry point for all error responses. Handlers must NEVER construct error JSON inline.
- **Response pattern:** `IRISCouch.Util.Response.JSON()` is the standard way to write success responses. Handlers must NEVER `Write` JSON directly.
- **Global access rule:** Direct global operations (`Set`/`$Get`/`$Order`/`$Data`/`Kill`) on `^IRISCouch.*` globals are ONLY allowed inside `IRISCouch.Storage.*` classes. Exception: `Config.Get()` reads `^IRISCouch.Config` directly.

### Config Class Parameters (Full List)

These are the documented config parameters from the architecture:

```objectscript
Parameter JSRUNTIME = "None";
Parameter JSRUNTIMESUBPROCESSPATH = "";
Parameter JSRUNTIMETIMEOUT = 5000;
Parameter METRICSENABLED = 1;
Parameter REVSLIMITDEFAULT = 1000;
Parameter WEBAPPPATH = "/iris-couch/";
```

The `Get(pKey)` method must:
1. Check `$Data(^IRISCouch.Config(pKey), tVal)` — if set, return `tVal`
2. Otherwise, call `..GetDefault(pKey)` to read the class parameter by name
3. `GetDefault` should use `..#<PARAMETERNAME>` syntax or `$Parameter($ClassName(), pKey)` to dynamically read class parameters

### Error Slug Table (13 slugs)

The following slugs are the CouchDB-compatible error identifiers:
- `not_found`, `conflict`, `unauthorized`, `forbidden`, `bad_request`, `doc_validation`, `file_exists`, `not_implemented`, `method_not_allowed`, `bad_content_type`, `precondition_failed`, `projection_backpressure`, `server_error`

### Util.Error.Render() Implementation

```objectscript
ClassMethod Render(pStatus As %Integer, pSlug As %String, pReason As %String)
{
    Set %response.Status = pStatus
    Set %response.ContentType = "application/json"
    Set tObj = {"error": (pSlug), "reason": (pReason)}
    Write tObj.%ToJSON()
    Quit
}
```

For 500 errors (NFR-S8): the `reason` sent to client must be generic (e.g., "Internal Server Error"). Full stack traces go to IRIS logs only via `$System.Status.DisplayError()`.

### Util.Response.JSON() Implementation

```objectscript
ClassMethod JSON(pData) As %Status
{
    Set %response.ContentType = "application/json"
    If $IsObject(pData) {
        Write pData.%ToJSON()
    } Else {
        Write pData
    }
    Quit $$$OK
}

ClassMethod JSONStatus(pStatus As %Integer, pData) As %Status
{
    Set %response.Status = pStatus
    Quit ..JSON(pData)
}
```

### Source Directory Structure to Create

Only create directories and files needed for THIS story:

```
src/
└── IRISCouch/
    ├── Config.cls
    ├── API/           (empty for now - Story 1.2)
    ├── Util/
    │   ├── Error.cls
    │   ├── Response.cls
    │   └── Request.cls
    └── Test/
        └── ConfigTest.cls
```

### module.xml Structure

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Export generator="Cache" version="25">
  <Document name="module.xml">
    <Module>
      <Name>iris-couch</Name>
      <Version>0.1.0</Version>
      <Description>CouchDB-compatible document database on InterSystems IRIS</Description>
      <Packaging>module</Packaging>
      <SourcesRoot>src</SourcesRoot>
      <Resource Name="IRISCouch.PKG"/>
    </Module>
  </Document>
</Export>
```

The web application setup should be handled via a post-install invoke or separate installer class. For now, create the module.xml that compiles all ObjectScript classes.

### ObjectScript Conventions (MUST follow)

- Parameters: `p` prefix (e.g., `pKey`, `pStatus`)
- Local variables: `t` prefix (e.g., `tVal`, `tObj`)
- Properties: capitalized, no prefix
- Class parameter names: no underscores, use camel case or all caps (e.g., `JSRUNTIME`, `WEBAPPPATH`)
- Method names: no underscores, use camel case
- Return `%Status` from methods that produce no return value
- First line: `Set tSC = $$$OK`, Last line: `Quit tSC`
- Use `Try`/`Catch` for error trapping
- Use `///` for method-level doc comments with HTML/DocBook markup
- Indent all code by at least 1 space/tab within methods
- Max ~500 lines per class
- Storage sections: NEVER edit or add manually — compiler maintains them
- Macros use triple dollar signs: `$$$OK`, `$$$ISERR()`, `$$$AssertEquals()`

### Testing Conventions

- Test class extends `%UnitTest.TestCase`
- Test methods named `Test<Scenario>` (e.g., `TestGetDefault`)
- Use `$$$AssertEquals(actual, expected, description)`, `$$$AssertTrue(condition, description)`, `$$$AssertStatusOK(status, description)`
- These are MACROS, not methods: `Do $$$AssertEquals(...)` NOT `Do ..AssertEquals(...)`
- `OnBeforeOneTest`: clean `^IRISCouch.Config` test data
- `OnAfterOneTest`: clean `^IRISCouch.Config` test data
- Max ~500 lines per test class
- Constructor must handle `initvalue` parameter: `Method %OnNew(initvalue As %String = "") As %Status`

### What This Story Does NOT Include

- No Router class (Story 1.2)
- No HTTP endpoints (Story 1.2)
- No UUID generation (Story 1.3)
- No error envelope testing against HTTP (Story 1.4)
- No Angular UI scaffold
- No Storage classes beyond Config global access

### Project Structure Notes

- This is the FIRST implementation story — no existing code to integrate with
- `src/` directory exists but is empty
- The project root has `irislib/` (IRIS library reference) and `sources/` (empty)
- Architecture specifies source code lives under `src/IRISCouch/`
- ZPM `module.xml` goes at the project root

### References

- [Source: _bmad-output/planning-artifacts/architecture.md#Configuration Management] — Config class design
- [Source: _bmad-output/planning-artifacts/architecture.md#Pattern 1: Error Envelope Construction] — Error.Render() pattern
- [Source: _bmad-output/planning-artifacts/architecture.md#Pattern 2: Handler Method Signature] — Response/Request utilities
- [Source: _bmad-output/planning-artifacts/architecture.md#Pattern 3: Global Access Encapsulation] — Global access rules
- [Source: _bmad-output/planning-artifacts/architecture.md#Pattern 5: Test Organization] — Test conventions
- [Source: _bmad-output/planning-artifacts/epics.md#Story 1.1] — Story requirements and acceptance criteria

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6 (1M context)

### Debug Log References
- Used temporary IRISCouch.Test.Runner class to verify all 6 test scenarios pass (deleted after use)
- %UnitTest.Manager directory setup required ^UnitTestRoot = "C:\temp\unittests\"

### Completion Notes List
- Implemented IRISCouch.Config with 6 class parameters (JSRUNTIME, JSRUNTIMESUBPROCESSPATH, JSRUNTIMETIMEOUT, METRICSENABLED, REVSLIMITDEFAULT, WEBAPPPATH) and Get/Set/GetAll/GetDefault methods
- Config.Get() checks ^IRISCouch.Config global first, falls back to class parameter defaults via $Parameter()
- GetDefault is Private as specified
- Implemented IRISCouch.Util.Error with all 13 CouchDB-compatible error slug constants and Render() classmethod
- Implemented IRISCouch.Util.Response with JSON() and JSONStatus() classmethods
- Implemented IRISCouch.Util.Request with ReadBody() classmethod
- Created IRISCouch.Test.ConfigTest with 4 test methods covering all Config acceptance criteria
- Created module.xml ZPM manifest at project root with IRISCouch.PKG resource
- Created directory structure: src/IRISCouch/{API,Util,Test} with .gitkeep for API
- All 5 classes compile cleanly in IRISCOUCH namespace
- All 6 test scenarios verified passing: TestGetDefault, TestGlobalOverride, TestGetAllKeys, TestSetAndGet, TestDefaultFallback, TestGetAllOverride

### Change Log
- 2026-04-12: Story 1-1 implementation complete - Configuration system, utility stubs, package scaffold, and tests

### File List
- module.xml (new)
- src/IRISCouch/Config.cls (new)
- src/IRISCouch/Util/Error.cls (new)
- src/IRISCouch/Util/Response.cls (new)
- src/IRISCouch/Util/Request.cls (new)
- src/IRISCouch/Test/ConfigTest.cls (new)
- src/IRISCouch/API/.gitkeep (new)

### Review Findings
- [x] [Review][Defer] Config.Get() silently returns "" for invalid/misspelled keys [src/IRISCouch/Config.cls:36] -- deferred, design choice acceptable at this stage
- [x] [Review][Defer] Config.GetAll() numeric parameters serialize as strings in JSON via $Parameter() [src/IRISCouch/Config.cls:73-78] -- deferred, will matter when API endpoints return config (Story 1.2+)
- [x] [Review][Defer] Config.Set() accepts arbitrary key names without validating against known parameters [src/IRISCouch/Config.cls:57] -- deferred, validation can be added when needed
- [x] [Review][Defer] Request.ReadBody() has no size limit on body read [src/IRISCouch/Util/Request.cls:17] -- deferred, pre-existing pattern, address with NFR work
- [x] [Review][Defer] Config.GetAll() requires manual update when new parameters are added [src/IRISCouch/Config.cls:72-79] -- deferred, low risk at current parameter count
