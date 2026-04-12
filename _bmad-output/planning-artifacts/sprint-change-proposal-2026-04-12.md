---
status: approved
date: '2026-04-12'
scope: minor
trigger: Pre-implementation technical research
artifacts_modified:
  - prd.md
  - architecture.md
  - epics.md
research_source: research/technical-iriscouch-multi-instance-url-routing-2026-04-12.md
---

# Sprint Change Proposal: CouchDB Client Compatibility — Reverse Proxy Deployment Model

**Date:** 2026-04-12
**Scope:** Minor — documentation + one architectural rule, no new epics or stories
**Trigger:** Pre-implementation technical research on URL path routing

---

## 1. Issue Summary

CouchDB clients (PouchDB, Nano, Cradle) expect the server at the URL root `/`. IRIS `%CSP.REST` web applications mount at path prefixes (e.g., `/iris-couch/`). CouchDB itself has this limitation — it generates absolute URLs internally (redirects, replication checkpoints, `_design` doc paths) without prefix awareness, breaking replication and client sync when deployed behind a non-root path.

**Evidence:** Apache CouchDB issues #4635 and #5135; CouchDB's official reverse proxy documentation recommends proxy deployment as the standard solution.

**Discovery:** Technical research conducted during pre-implementation planning, before any code was written.

---

## 2. Impact Analysis

### Epic Impact
- **No epics added, removed, or resequenced.**
- Epic 1 (Foundation): Story 1.1 gains one acceptance criterion (root-relative URL generation)
- Epic 13 (Documentation): Story 13.1 gains deployment topology guidance in Getting Started guide

### Artifact Conflicts
- **PRD:** FR108 and NFR-S4 needed minor extensions (completed)
- **Architecture:** Needed a new "Deployment Topology" section and cross-cutting concern update (completed)
- **Epics:** Story 1.1 AC and Story 13.1 AC needed updates; architecture digest needed the URL rule (completed)
- **UX Design:** No impact — Angular SPA uses relative base URL

### Technical Impact
- **New architectural rule:** All application-generated URLs must be root-relative. No handler, utility, or response method embeds the IRIS webapp mount path.
- **Deployment model:** Reverse proxy (nginx/Apache) presenting IRISCouch at `/` on a dedicated port is the recommended topology.
- **Code impact:** Zero additional code needed — the rule is "don't embed prefixes," which is simpler than the alternative.

---

## 3. Recommended Approach

**Direct Adjustment** — modify existing artifacts to document the deployment model and URL generation rule.

**Rationale:**
- No new code required — the rule simplifies implementation (generate from `/` always)
- Follows established CouchDB ecosystem best practices
- IRIS deployments commonly use Apache/nginx in front of the Web Gateway already
- Future enhancement (prefix-aware URL generation via `%request.Application`) remains possible without retrofit

**Effort:** Low — documentation and acceptance criteria updates only
**Risk:** Low — aligns with proven CouchDB deployment patterns
**Timeline impact:** None

---

## 4. Detailed Changes Applied

### PRD (prd.md)

**FR108** — Added reverse proxy recommendation and reference to deployment documentation (FR110, FR114).

**NFR-S4** — Renamed to "Transport encryption and reverse proxy." Added URL generation contract: IRISCouch generates all URLs relative to `/`, proxy maps external root to IRIS webapp mount path.

### Architecture (architecture.md)

**New section: "Deployment Topology: Reverse Proxy as Recommended Model"** — Added after Admin UI Build Integration. Documents:
- The root-relative URL generation rule
- Recommended nginx configuration (single and multi-instance)
- Direct mount alternative with caveats
- Consistency rules for all subsystems (Location headers, _changes entries, replication checkpoints, welcome JSON, Admin UI base URL)

**Cross-cutting concern #7** — Extended namespace-scoped state description to document multi-instance deployment via separate namespaces and proxy ports.

### Epics (epics.md)

**Story 1.1 AC** — Added acceptance criterion: all generated URLs are root-relative, no webapp mount path embedded.

**Story 13.1 AC** — Added reverse proxy setup to Getting Started guide coverage; added deployment topology options requirement.

**Architecture digest** — Added root-relative URL rule and reverse proxy recommendation to the locked conventions list.

---

## 5. Implementation Handoff

**Scope classification:** Minor — direct implementation by Developer agent.

**No additional action needed.** All changes are documentation/planning updates that have already been applied to the artifacts. The architectural rule (root-relative URLs) will be enforced naturally during implementation — it's the simpler path (no prefix logic needed).

**Success criteria:**
- Story 1.1 implementation generates root-relative URLs
- Story 13.1 Getting Started guide includes reverse proxy setup
- No handler or utility class references `%request.Application` for URL prefix construction (unless a future story explicitly adds opt-in prefix-aware mode)
