---
stepsCompleted:
  - step-01-init
  - step-02-technical-overview
  - step-03-integration-patterns
  - step-04-architectural-patterns
  - step-06-research-synthesis
inputDocuments:
  - _bmad-output/planning-artifacts/architecture.md
  - _bmad-output/planning-artifacts/epics.md
  - _bmad-output/planning-artifacts/research/technical-iriscouch-multi-instance-url-routing-2026-04-12.md
  - irislib/EnsLib/HTTP/InboundAdapter.cls
  - irislib/EnsLib/HTTP/Service.cls
  - irislib/EnsLib/REST/Service.cls
  - irislib/Ens/BusinessService.cls
  - irislib/%CSP/REST.cls
workflowType: 'research'
lastStep: 6
research_type: 'technical'
research_topic: 'Interoperability Production HTTP Service vs %CSP.REST for IRISCouch'
research_goals: 'Evaluate whether an Interoperability Production with EnsLib.HTTP.InboundAdapter or EnsLib.REST.Service could replace %CSP.REST as the HTTP server layer, natively solving the URL path prefix problem by owning a dedicated port'
user_name: 'Developer'
date: '2026-04-12'
web_research_enabled: true
source_verification: true
---

# Research Report: Interoperability Production HTTP Service vs %CSP.REST

**Date:** 2026-04-12
**Author:** Developer
**Research Type:** Technical
**Decision:** Stay with %CSP.REST + reverse proxy

---

## Research Overview

This research evaluates whether IRISCouch should use an IRIS Interoperability Production with an HTTP-based Business Service instead of the current `%CSP.REST` web application design. The motivation: a Business Service using `EnsLib.HTTP.InboundAdapter` listens on its own TCP port and naturally serves at the URL root `/`, eliminating the path-prefix compatibility problem documented in the companion research (technical-iriscouch-multi-instance-url-routing-2026-04-12.md).

### Methodology

- Source code analysis of IRIS library classes in `irislib/`
- Web research on InterSystems documentation and community resources
- Comparison against IRISCouch architectural requirements (PRD, architecture, epics)

---

## Finding 1: Three Architectural Options

### Option A: Raw EnsLib.HTTP.InboundAdapter

**Source:** `irislib/EnsLib/HTTP/InboundAdapter.cls`

**Class hierarchy:** `EnsLib.HTTP.InboundAdapter` → `EnsLib.TCP.InboundAdapter` → `Ens.InboundAdapter` + `EnsLib.TCP.Common`

**How it works:** The adapter listens on a configurable TCP port (default 9980). When a connection arrives, `OnConnected()` (lines 40-304) performs raw HTTP parsing:

1. Reads the HTTP request line and headers from the socket
2. Parses method, URL, query parameters, Content-Type, Content-Length
3. Reads the HTTP body into a `%GlobalCharacterStream` or `%GlobalBinaryStream`
4. Stores all HTTP metadata in stream `.Attributes()`:
   ```
   tStream.Attributes("HttpRequest")        = "GET"
   tStream.Attributes("URL")                = "/mydb/doc1"
   tStream.Attributes("Params", "rev", 1)   = "2-abc"
   tStream.Attributes("Content-Type")       = "application/json"
   ```
5. Calls `..BusinessHost.ProcessInput(tStream, .tStreamOut)`
6. Writes the HTTP response from `tStreamOut` attributes and body

**Key characteristics:**
- `SERVICEINPUTCLASS = "%Stream.Object"`, `SERVICEOUTPUTCLASS = "%Stream.Object"`
- No `%CSP.Request` / `%CSP.Response` — everything is stream-based
- No URL routing — `OnProcessInput()` receives the raw stream; routing is the implementer's responsibility
- Custom port means the service owns `/` natively

**Assessment:** Solves the path problem but requires rebuilding HTTP parsing, URL routing, cookie handling, content negotiation, and the entire request/response model. For a project with 12 handler classes and ~300 URL routes, this is prohibitively expensive.

### Option B: EnsLib.REST.Service (Hybrid)

**Source:** `irislib/EnsLib/REST/Service.cls`

**Class hierarchy:** `EnsLib.REST.Service` → `EnsLib.HTTP.Service` + `%CSP.REST` + `Ens.Util.JSON`

This is the most interesting option. It inherits from **both** `EnsLib.HTTP.Service` (which provides the Business Service lifecycle) and `%CSP.REST` (which provides `UrlMap` XData routing).

**How it works:**

The `OnProcessInput()` override (lines 32-136) implements a stream-based version of `%CSP.REST` dispatch:
1. Extracts method and URL from stream attributes: `tMethod = pInput.GetAttribute("HttpRequest")`, `tURL = pInput.GetAttribute("URL")`
2. Calls the inherited `DispatchMap(tURL, tMethod, .tVerbsMatched, .tArgs)` — the same compile-time-generated routing method that `%CSP.REST` uses
3. Routes to handler methods via `$classmethod()` or `$method()` with extracted URL parameters
4. Calls `OnPreDispatch()` hook before routing

**Custom port support:** When configured with `ADAPTER = "EnsLib.HTTP.InboundAdapter"` (which is the default), it listens on a dedicated TCP port. The `?CfgItem=` URL parameter is **only required for CSP Gateway invocation** (confirmed in source lines 6-8). Custom port mode does not need `?CfgItem=` — the port itself identifies the service.

**UrlMap routing:** Fully supported via inherited `DispatchMap()`. Same `<Route Url="/path/:param" Method="GET" Call="MethodName"/>` XData format as `%CSP.REST`.

**EnsServicePrefix parameter:** Can strip a URL prefix before matching routes, with special `^` and `|` modes for CSP application path stripping.

**Assessment:** Closer to viable than the raw adapter. Retains UrlMap routing. But the stream-based I/O model and Production pipeline overhead introduce problems (see Findings 2 and 3).

### Option C: %CSP.REST + Reverse Proxy (Current Design)

**Source:** `irislib/%CSP/REST.cls`

Standard CSP Gateway dispatch via `DispatchRequest()` → `DispatchMap()` → handler methods. Full `%CSP.Request` / `%CSP.Response` support. Path prefix solved by reverse proxy presenting IRISCouch at `/` on a dedicated port.

**Assessment:** Already documented and decided. Zero code overhead for the path problem.

---

## Finding 2: The Stream-Based I/O Problem

All Interoperability HTTP paths (Options A and B) use the same I/O model:

**Input:** `%Stream.Object` with HTTP metadata in `.Attributes()`
**Output:** Complete `%Stream.Object` returned from `OnProcessInput()`, then written by the adapter

This differs fundamentally from the `%CSP.REST` model:

| Aspect | %CSP.REST | EnsLib.REST.Service |
|--------|-----------|---------------------|
| **Query parameters** | `%request.Get("rev")` | `pInput.GetAttribute("Params", "rev")` |
| **Request body** | `%request.Content` (stream) | `pInput` (the stream itself) |
| **Cookie access** | `%request.GetCookie("AuthSession")` | Manual parsing from `pInput.GetAttribute("Cookie")` |
| **Set response status** | `Set %response.Status = "200 OK"` | `Do pOutput.SetAttribute("ResponseCode", "200 OK")` |
| **Set response header** | `Do %response.SetHeader("ETag", tEtag)` | `Do pOutput.SetAttribute("ETag", tEtag)` |
| **Write response body** | `Write tDoc.%ToJSON()` — incremental | Build complete stream, return from method |
| **Streaming flush** | `Do %response.Flush()` | Not available — response is assembled then sent |
| **Content negotiation** | Built into `%CSP.Request` | Manual implementation required |

**Impact on IRISCouch:** Every handler class (`IRISCouch.API.*Handler`), every utility class (`IRISCouch.Util.Request`, `IRISCouch.Util.Response`, `IRISCouch.Util.Error`), and every test class is designed around `%request` / `%response`. Switching to stream-based I/O means rewriting the entire HTTP interface layer.

---

## Finding 3: The Streaming Showstopper

Looking at `EnsLib.HTTP.InboundAdapter.OnConnected()` (lines 194-287), the response writing model is:

1. `OnProcessInput()` returns — the complete response stream is ready
2. The adapter reads response headers from stream attributes
3. The adapter writes the HTTP response line and headers
4. The adapter copies the stream body to the socket

**There is no incremental flush capability.** The entire response must be assembled as a complete stream before the adapter sends anything to the client.

This breaks three IRISCouch requirements:

| Requirement | Why it breaks |
|-------------|--------------|
| **FR24: `feed=longpoll`** | Longpoll holds the connection open, then flushes a single change entry when it arrives. The stream model requires the response to be complete before sending — can't hold and flush. |
| **NFR-P8: Attachment streaming (500MB without proportional RSS)** | A 500MB attachment would need to be loaded into a `%Stream.Object` response before the adapter sends it. This violates the bounded-memory streaming requirement. |
| **FR28/FR29: `feed=continuous` and `feed=eventsource` (Epic 14, gamma)** | Continuous feeds write incremental entries over a held connection indefinitely. Fundamentally incompatible with "return complete stream" model. |

With `%CSP.REST`, these work because:
- `Write` sends data incrementally to the response
- `%CSP.Response.Flush()` pushes buffered data to the client
- The connection stays open as long as the handler method is executing

Note: The CSP Gateway has its own buffering limitation for continuous feeds (documented in technical constraint #5), which is why Epic 14 plans a `%Net.TCPServer` standalone listener for gamma. But longpoll and attachment streaming work fine through the CSP Gateway with `Flush()`.

---

## Finding 4: Production Pipeline Overhead

**Source:** `irislib/Ens/BusinessService.cls`, `ProcessInput()` method (lines 44-85)

Every HTTP request through the Interoperability Production flows through:

1. `ProcessInput()` — validates configuration is enabled, manages Ens session
2. `preProcessInput()` — pre-processing hooks
3. `OnProcessInput()` — the actual request handling
4. Post-processing — transaction management, logging, error handling, `%WaitForNextCallInterval` management

This adds per-request overhead that doesn't exist in the `%CSP.REST` path, where dispatch goes directly from `Page()` → `DispatchRequest()` → handler method.

For IRISCouch's performance targets (NFR-P1: ≤2x CouchDB write latency, NFR-P2: ≤1.5x CouchDB read latency), every millisecond matters. The Production pipeline is designed for enterprise integration message routing, not high-throughput REST API serving.

---

## Finding 5: Interoperability License Dependency

Using `EnsLib.REST.Service` or `EnsLib.HTTP.InboundAdapter` requires the IRIS Interoperability (formerly Ensemble) license. Not every IRIS installation includes this — particularly:

- IRIS Community Edition (free tier)
- IRIS installations licensed for data platform only
- Evaluation and development environments

FR109 requires "no mandatory external dependencies beyond IRIS itself." While Interoperability is technically part of IRIS (not external), it's a separately licensed capability. Making it mandatory would narrow the addressable market, particularly for the open-source and community adopters who are the early target audience.

---

## Finding 6: What EnsLib.REST.Service Gets Right

For completeness, the hybrid approach does have genuine advantages:

1. **Native root path** — custom port means no path prefix problem at all
2. **UrlMap routing preserved** — same `DispatchMap()` engine as `%CSP.REST`
3. **Production observability** — automatic message logging, error tracking, and dashboard visibility for every request
4. **Built-in retry/recovery** — Production framework handles service restart on failures
5. **Configuration management** — runtime settings adjustable via Production configuration UI without code changes

These would be valuable for an enterprise integration service. For a high-throughput document database server with streaming requirements, the trade-offs don't justify the benefits.

---

## Decision

**Stay with `%CSP.REST` + reverse proxy.**

### Rationale

1. **Streaming incompatibility** — The Interoperability HTTP adapter's "return complete stream" response model cannot support longpoll, large attachment streaming, or future continuous feeds. This is the showstopper.
2. **HTTP interface rewrite** — Every handler and utility class is designed around `%request`/`%response`. Switching to stream-based I/O is a full rewrite of the HTTP interface layer for no functional gain.
3. **Performance overhead** — The Production pipeline adds per-request overhead inappropriate for a high-throughput REST API with sub-millisecond latency targets.
4. **License narrowing** — Requiring Interoperability licensing reduces the addressable market, conflicting with the open-source adoption strategy.
5. **Solved problem** — The path-prefix issue that motivated this investigation is already resolved by the reverse proxy deployment model, which is a proven CouchDB ecosystem pattern with zero code impact.

### When the Interoperability Approach Would Be Right

This investigation was not wasted — the `EnsLib.REST.Service` hybrid would be the correct choice for:
- An IRIS integration adapter that bridges CouchDB protocol to other Interoperability services
- A lightweight CouchDB-compatible proxy that doesn't need streaming or high throughput
- An environment where Production observability and management are more important than raw performance

These are not IRISCouch's use case, but they could inform future companion projects (e.g., an Interoperability adapter that replicates between IRISCouch and other Ensemble productions).

---

## Summary

| Question | Answer |
|----------|--------|
| Can EnsLib.REST.Service serve as a full REST API? | Yes — UrlMap routing works, custom port works without `?CfgItem=` |
| Does it solve the path prefix problem? | Yes — custom port natively owns `/` |
| Can it handle IRISCouch's streaming requirements? | **No** — response model requires complete stream before sending |
| What's the I/O model difference? | Streams with attributes vs. `%request`/`%response` globals |
| Is the rewrite justified? | No — path problem already solved by reverse proxy |
| License impact? | Narrows addressable market by requiring Interoperability license |

---

## Sources

**IRIS Library Source Code (primary):**
- `irislib/EnsLib/HTTP/InboundAdapter.cls` — HTTP listener, request parsing, response writing
- `irislib/EnsLib/HTTP/Service.cls` — Dual-mode HTTP Business Service (adapter + CSP)
- `irislib/EnsLib/REST/Service.cls` — Hybrid REST routing Business Service
- `irislib/Ens/BusinessService.cls` — Production service pipeline
- `irislib/%CSP/REST.cls` — Standard REST dispatch framework

**InterSystems Documentation:**
- https://docs.intersystems.com/irisforhealthlatest/csp/docbook/DocBook.UI.Page.cls?KEY=EHTTP_inbound
- https://docs.intersystems.com/irislatest/csp/documatic/%25CSP.Documatic.cls?LIBRARY=ENSLIB&CLASSNAME=EnsLib.REST.Service

**Companion Research:**
- technical-iriscouch-multi-instance-url-routing-2026-04-12.md — URL path routing analysis and reverse proxy decision
