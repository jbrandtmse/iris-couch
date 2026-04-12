---
stepsCompleted:
  - step-01-init
  - step-02-technical-overview
  - step-03-integration-patterns
  - step-06-research-synthesis
inputDocuments:
  - _bmad-output/planning-artifacts/prd.md
  - _bmad-output/planning-artifacts/architecture.md
  - _bmad-output/planning-artifacts/epics.md
workflowType: 'research'
lastStep: 6
research_type: 'technical'
research_topic: 'IRISCouch Multi-Instance Deployment & URL Path Routing'
research_goals: 'Determine how CouchDB databases map to IRIS namespaces, whether multiple IRISCouch instances can coexist, and how to handle URL path prefix routing for CouchDB client compatibility'
user_name: 'Developer'
date: '2026-04-12'
web_research_enabled: true
source_verification: true
---

# Research Report: IRISCouch Multi-Instance Deployment & URL Path Routing

**Date:** 2026-04-12
**Author:** Developer
**Research Type:** Technical

---

## Research Overview

This research investigates three related questions about the IRISCouch deployment model:

1. **Database mapping** — Does each CouchDB database map to a single IRIS database/namespace, or do multiple CouchDB databases share one?
2. **Multi-instance support** — Can multiple IRISCouch instances run in a single IRIS installation?
3. **URL path routing** — How do CouchDB clients handle non-root URL prefixes, and what are the practical options for IRIS web application deployment?

### Methodology

- Analysis of existing IRISCouch planning artifacts (PRD, architecture, epics)
- Web research on CouchDB client library behavior with path-prefixed servers
- Web research on IRIS web application and Web Gateway configuration
- Cross-referencing CouchDB ecosystem best practices with IRIS operational patterns

---

## Finding 1: CouchDB Database → IRIS Namespace Mapping

**Multiple CouchDB databases map to a single IRIS namespace.**

The architecture uses a single-namespace, multi-database model. CouchDB-compatible "databases" created via `PUT /{db}` coexist within one IRIS namespace, discriminated by the first subscript in the global structure:

```
^IRISCouch.Docs(db, docId, rev)           // document bodies
^IRISCouch.Tree(db, docId, "R", childRev) // revision tree
^IRISCouch.Changes(db, seq)               // changes feed
^IRISCouch.DB(db)                         // database metadata
```

All eight named globals (`^IRISCouch.Docs`, `^IRISCouch.Tree`, `^IRISCouch.Changes`, `^IRISCouch.Seq`, `^IRISCouch.Atts`, `^IRISCouch.Local`, `^IRISCouch.DB`, `^IRISCouch.Config`) are namespace-scoped with no cross-namespace leakage.

**Source:** architecture.md line 70, epics.md line 213, PRD FR102 (lines 2117-2121)

### Scaling via Global Subscript Mapping

If a particular CouchDB database grows large or needs I/O isolation, IRIS's native global subscript mapping can route specific subscript ranges to different IRIS database files — e.g., `^IRISCouch.Docs("bigdb")` → a separate `.DAT` file. This is purely an operational configuration change with no code modifications required.

---

## Finding 2: Multiple IRISCouch Instances

**Yes — deploy to separate IRIS namespaces.** Since all state is namespace-scoped, installing IRISCouch into two namespaces yields two fully isolated instances, each with its own document store, revision trees, changes feeds, configuration, and Mango indexes.

Each instance requires its own IRIS web application (see Finding 3).

IRISCouch does not build multi-tenancy — isolation is delegated to IRIS's native namespace model. HA, backup, journaling, and mirroring are likewise IRIS platform responsibilities.

**Source:** PRD lines 317-321, 1032-1035

---

## Finding 3: URL Path Routing & CouchDB Client Compatibility

### The Problem

IRIS `%CSP.REST` web applications are mounted at URL path prefixes (e.g., `/iriscouch`). CouchDB clients expect the server root at `/`. Real CouchDB has the same limitation — it assumes it owns the root path and generates absolute URLs internally (redirects, replication checkpoints, `_design` doc paths) without prefix awareness.

**Known issues with path-prefixed CouchDB servers:**
- Replication constructs URLs like `/{db}/_local/{checkpoint}` without the prefix — breaks replication
- 301 redirects point to `/dbname/...` instead of `/prefix/dbname/...`
- PouchDB follows redirects, so broken redirects break sync
- Session-based replication (default since CouchDB 2.3.0) requires `/_session` to be accessible

**Sources:**
- https://github.com/apache/couchdb/issues/4635
- https://github.com/apache/couchdb/discussions/5135
- https://docs.couchdb.org/en/stable/best-practices/reverse-proxies.html

### Option 1: Prefix-Aware Dispatch (Application-Level)

IRISCouch controls all URL generation, so the dispatch class can use `%request.Application` to prepend the mount prefix to every generated URL.

**IRIS Setup:**
- Create web application `/iriscouch` via Management Portal or `Security.Applications`
- Set dispatch class to `IRISCouch.REST.Dispatch`
- Bind to target namespace

**Code Requirements:**
- Every URL-generating code path must use a helper:
  ```objectscript
  ClassMethod BuildURL(pPath As %String) As %String
  {
      Quit %request.Application _ pPath
  }
  ```
- Affected paths: welcome JSON `"uri"` field, `Location` headers on redirects, `_changes` responses, replication checkpoint references, `_bulk_get`/`_all_docs` self-links

| Pros | Cons |
|------|------|
| No external infrastructure needed | Must apply prefix to every URL-generating path |
| Simpler deployment for single-instance | Miss one path = broken client |
| Lower operational complexity | No established CouchDB precedent |

### Option 2: Reverse Proxy with Prefix Stripping (Infrastructure-Level) — SELECTED

A reverse proxy (nginx or Apache) sits in front of IRIS and strips the external prefix, so IRISCouch generates all URLs from `/` and clients see a standard CouchDB-compatible root endpoint.

**IRIS Setup:**
- Create web application `/iriscouch` via Management Portal or `Security.Applications`
- Set dispatch class to `IRISCouch.REST.Dispatch`
- Bind to target namespace

**Reverse Proxy Setup (nginx):**

Single instance on dedicated port (clients connect to port 5984, see standard CouchDB):
```nginx
server {
    listen 5984;
    location / {
        rewrite ^/(.*) /iriscouch/$1 break;
        proxy_pass http://localhost:52773;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

Multiple instances on separate ports:
```nginx
server {
    listen 5984;    # Production instance
    location / {
        rewrite ^/(.*) /iriscouch-prod/$1 break;
        proxy_pass http://localhost:52773;
    }
}
server {
    listen 5985;    # Development instance
    location / {
        rewrite ^/(.*) /iriscouch-dev/$1 break;
        proxy_pass http://localhost:52773;
    }
}
```

**Reverse Proxy Setup (Apache):**
```apache
<Location /couch>
    ProxyPass http://localhost:52773/iriscouch retry=0
    ProxyPassReverse http://localhost:52773/iriscouch
</Location>
```

| Pros | Cons |
|------|------|
| Battle-tested CouchDB deployment pattern | Requires nginx/Apache infrastructure |
| Zero code complexity for URL generation | Additional ops layer to manage |
| Maximum client compatibility | Slight latency from proxy hop |
| CouchDB docs recommend this approach | |

**Sources:**
- https://docs.intersystems.com/healthconnectlatest/csp/docbook/DocBook.UI.Page.cls?KEY=GCGI_intro
- https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=GCGI_webserver
- https://docs.couchdb.org/en/stable/best-practices/reverse-proxies.html

---

## Decision

**Proceed with Option 2 (Reverse Proxy)** as the primary deployment model.

### Rationale

1. **Proven pattern** — CouchDB's own documentation recommends reverse proxy deployment; operators and clients already expect it.
2. **Zero URL generation risk** — IRISCouch generates all URLs from `/`, eliminating an entire class of subtle routing bugs.
3. **Client compatibility** — PouchDB, Nano, and other clients work without any special configuration when the server appears at root.
4. **Multi-instance support is natural** — separate ports per instance is the established pattern.
5. **IRIS Web Gateway already expects this** — IRIS deployments commonly use Apache/nginx in front of the Web Gateway.

### Implementation Notes

- IRISCouch code generates all URLs relative to `/` (no prefix awareness needed)
- Deployment documentation should include nginx and Apache example configurations
- Example configs should cover: single instance, multi-instance, HTTPS termination
- The `GET /` welcome endpoint should return standard CouchDB-compatible JSON with no prefix in URLs

### Future Consideration

Option 1 (prefix-aware dispatch via `%request.Application`) remains viable as a future enhancement for simplified single-instance deployments where operators want to avoid a proxy layer. The `%request.Application` property is available at runtime and could be added later without architectural changes — it's an additive improvement, not a retrofit.

---

## Summary

| Question | Answer |
|----------|--------|
| CouchDB DB → IRIS mapping | Many-to-one: multiple CouchDB databases share one IRIS namespace |
| Multiple IRISCouch instances | Yes, via separate IRIS namespaces + web applications |
| Scaling large databases | IRIS global subscript mapping (operational config, no code change) |
| URL routing strategy | **Option 2: Reverse proxy with prefix stripping** |
| Client compatibility | Maximized — server appears at root, standard CouchDB pattern |
