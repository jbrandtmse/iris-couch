# Story 10.1: Angular Scaffold, Design Tokens & Icon System

Status: done

## Story

As an operator,
I want the admin UI foundation to be established with consistent visual design tokens,
so that all subsequent UI components share a unified look and feel.

## Acceptance Criteria

1. **Given** the admin UI project is initialized
   **When** the scaffold is created
   **Then** it uses `ng new` with `--style=css --routing --ssr=false --skip-tests=false`
   **And** `@angular/cdk` is added as a dependency (no Angular Material)
   **And** no other UI framework or state management library (NgRx, PrimeNG, etc.) is installed

2. **Given** the `tokens.css` file is created
   **When** the design tokens are defined
   **Then** it includes exactly 11 neutral gray palette tokens (`--color-neutral-0` through `--color-neutral-900`)
   **And** 4 semantic color tokens (`--color-error`, `--color-warn`, `--color-success`, `--color-info`)
   **And** 7-step spacing scale (`--space-1` through `--space-12`)
   **And** 6-step type scale (`--font-size-xs` through `--font-size-2xl`) with corresponding line heights
   **And** border-radius of 2px and border color of `--color-neutral-200`

3. **Given** the typography stack is configured
   **When** fonts are loaded
   **Then** proportional text uses the system font stack (zero bytes loaded)
   **And** JetBrains Mono WOFF2 (~30KB, Latin-1 subset) is bundled and served from `/iris-couch/_utils/` with `font-display: block`

4. **Given** the icon system is set up
   **When** icons are used in the UI
   **Then** approximately 20 hand-picked Lucide icons are available as standalone Angular SVG components
   **And** no icon font, runtime icon library, or CDN is used

5. **Given** the HTML document
   **When** it is rendered
   **Then** `<html lang="en">` is set on the document root
   **And** `<meta name="viewport" content="width=1280">` is present
   **And** the iris-couch wordmark is rendered as text-only monospace string in neutral-600 in the header

6. **Given** the built SPA
   **When** assets are examined
   **Then** all UI assets are self-contained with no external CDN loads, no Google Fonts, no analytics beacons
   **And** every byte the browser loads comes from `/iris-couch/_utils/`

## Tasks / Subtasks

- [x] Task 1: Angular project scaffold (AC: #1)
  - [x] Run `ng new iris-couch-ui --style=css --routing --ssr=false --skip-tests=false` inside the project root to create `ui/` directory
  - [x] Rename the generated directory from `iris-couch-ui` to `ui` (architecture mandates `ui/` as the directory name)
  - [x] Run `cd ui && ng add @angular/cdk` (no Angular Material)
  - [x] Verify `package.json` has NO Angular Material, NgRx, PrimeNG, or other UI/state libraries
  - [x] Create directory structure per architecture:
    - `src/app/couch-ui/` — custom component layer (domain-free)
    - `src/app/features/databases/` — database feature module
    - `src/app/features/documents/` — document feature module
    - `src/app/features/design-docs/` — design docs feature module
    - `src/app/features/security/` — security feature module
    - `src/app/features/revisions/` — revisions feature module (γ)
  - [x] Verify `ng build` and `ng test` succeed with the clean scaffold

- [x] Task 2: Design tokens — `tokens.css` (AC: #2)
  - [x] Create `src/styles/tokens.css` with CSS custom properties on `:root`
  - [x] 11 neutral gray palette tokens (exact hex values from UX spec):
    - `--color-neutral-0: #FFFFFF`
    - `--color-neutral-50: #F7F8FA`
    - `--color-neutral-100: #EEF0F3`
    - `--color-neutral-200: #E1E4E9`
    - `--color-neutral-300: #C7CBD3`
    - `--color-neutral-400: #9096A1`
    - `--color-neutral-500: #6B7280`
    - `--color-neutral-600: #4B5260`
    - `--color-neutral-700: #374050`
    - `--color-neutral-800: #242B38`
    - `--color-neutral-900: #12161F`
  - [x] 4 semantic color tokens:
    - `--color-error: #C33F3F`
    - `--color-warn: #B57B21`
    - `--color-success: #3C7A5A`
    - `--color-info: #3C5A9E`
  - [x] 7-step spacing scale:
    - `--space-1: 4px`
    - `--space-2: 8px`
    - `--space-3: 12px`
    - `--space-4: 16px`
    - `--space-6: 24px`
    - `--space-8: 32px`
    - `--space-12: 48px`
  - [x] 6-step type scale with line heights:
    - `--font-size-xs: 12px` / `--line-height-xs: 16px`
    - `--font-size-sm: 13px` / `--line-height-sm: 20px`
    - `--font-size-md: 14px` / `--line-height-md: 20px`
    - `--font-size-lg: 16px` / `--line-height-lg: 24px`
    - `--font-size-xl: 20px` / `--line-height-xl: 28px`
    - `--font-size-2xl: 24px` / `--line-height-2xl: 32px`
  - [x] Border tokens:
    - `--border-radius: 2px`
    - `--border-color: var(--color-neutral-200)`
  - [x] Font family tokens:
    - `--font-sans: system-ui, -apple-system, "Segoe UI", Roboto, Oxygen, Ubuntu, Cantarell, "Helvetica Neue", sans-serif`
    - `--font-mono: "JetBrains Mono", ui-monospace, "Cascadia Code", "Source Code Pro", Menlo, Consolas, "DejaVu Sans Mono", monospace`
  - [x] Add `tokens.css` to `angular.json` styles array

- [x] Task 3: Global styles — `global.css` (AC: #2, #3, #5)
  - [x] Create `src/styles/global.css` with:
    - CSS reset (box-sizing, margin/padding, consistent defaults)
    - Base `body` styles using `--font-sans`, `--font-size-md`, `--color-neutral-600` text, `--color-neutral-0` background
    - `html` with `lang="en"` (set in `index.html`)
    - Monospace class `.mono` using `--font-mono`
    - Focus-visible style: 2px outline in `--color-info` at 3px offset
    - `prefers-reduced-motion: reduce` media query disabling all transitions
  - [x] Add `global.css` to `angular.json` styles array (after tokens.css)

- [x] Task 4: Typography — JetBrains Mono font (AC: #3)
  - [x] Download JetBrains Mono WOFF2 (Latin-1 subset, ~30KB) — Regular weight (400) only
  - [x] Place in `src/assets/fonts/jetbrains-mono-latin-400.woff2`
  - [x] Add `@font-face` declaration in `global.css`:
    ```css
    @font-face {
      font-family: "JetBrains Mono";
      src: url("/iris-couch/_utils/assets/fonts/jetbrains-mono-latin-400.woff2") format("woff2");
      font-weight: 400;
      font-style: normal;
      font-display: block;
    }
    ```
  - [x] Verify the font path works with Angular's asset handling

- [x] Task 5: Icon system — Lucide SVG components (AC: #4)
  - [x] Create `src/app/couch-ui/icons/` directory
  - [x] Hand-pick ~20 Lucide icons as standalone Angular SVG components. Required icons based on UX spec component inventory:
    - Navigation: `database`, `file-text`, `shield`, `settings`, `info`, `menu`
    - Actions: `plus`, `trash-2`, `refresh-cw`, `copy`, `check`, `download`, `search`, `x`
    - Status: `alert-triangle`, `alert-circle`, `check-circle`, `chevron-right`, `chevron-left`, `chevron-down`
  - [x] Each icon is a standalone Angular component with inline SVG, `aria-hidden="true"`, 16x16 default viewBox, `currentColor` for stroke
  - [x] Create a barrel export file `src/app/couch-ui/icons/index.ts`
  - [x] Each icon component should accept `[size]` input for width/height override

- [x] Task 6: HTML document configuration (AC: #5, #6)
  - [x] Set `<html lang="en">` in `src/index.html`
  - [x] Add `<meta name="viewport" content="width=1280">` in `src/index.html`
  - [x] Remove any default Angular favicon or replace with a minimal one
  - [x] Set page title to "iris-couch"
  - [x] Verify no external resource references in `index.html`

- [x] Task 7: Build configuration for `/iris-couch/_utils/` serving (AC: #6)
  - [x] Configure `angular.json` with:
    - `outputPath`: `dist/browser`
    - `baseHref`: `/iris-couch/_utils/`
  - [x] Verify `ng build --configuration=production` produces output in `ui/dist/browser/`
  - [x] Verify all asset paths are relative and self-contained
  - [x] Verify the font file is included in the build output
  - [x] Verify zero external CDN loads in the built output

- [x] Task 8: Smoke test verification
  - [x] Run `ng test` — default tests pass
  - [x] Run `ng build --configuration=production` — clean build
  - [x] Start `ng serve` and verify in browser:
    - tokens.css loads and custom properties are visible in DevTools
    - JetBrains Mono font loads (check network tab — no external requests)
    - `<html lang="en">` is present
    - viewport meta tag is present
    - No external network requests (CDN, Google Fonts, analytics)
  - [x] Take a screenshot via Chrome DevTools MCP to verify

## Dev Notes

### Architecture Compliance

- **Directory**: `ui/` at project root (NOT `src/ui/` — architecture specifies `ui/` at root level, see architecture.md line 128)
- **Component layer**: `src/app/couch-ui/` — domain-free, ~15-20 components total across all stories
- **Feature modules**: `src/app/features/{databases,documents,design-docs,security,revisions}/`
- **Build output**: `ui/dist/browser/` — committed to git for ZPM distribution
- **Base href**: `/iris-couch/_utils/` — all assets served from this path
- **Admin UI is a CouchDB client**: `CouchApiService` base URL is `/` (relative to origin)

### Prohibited Patterns (from UX spec)

- NO Angular Material (`@angular/material`)
- NO CSS framework (Tailwind, Bootstrap, Bulma)
- NO state management library (NgRx, Akita)
- NO icon font or CDN icons (Font Awesome, Material Icons CDN)
- NO webfont CDN loads (Google Fonts)
- NO analytics, telemetry, or error-tracking SDKs
- NO SCSS — plain CSS with custom properties only
- NO theming engine

### Design Token Specifications (exact values from UX spec)

- Font weights: only 400 (regular) and 500 (medium) — no bold, no light
- Border radius: 2px everywhere — sharp corners match SMP industrial feel
- No gradients anywhere
- Semantic colors: desaturated, never pure red/green/blue
- 95% of surface area uses neutral scale; semantic colors are rare
- Table row height: 32px (small density target for later stories)
- Focus-visible: 2px outline in `--color-info` at 3px offset

### Previous Story Intelligence

- Story 10.0 was ObjectScript cleanup only — no Angular work done yet
- This is the first Angular story in the project — greenfield scaffold
- All backend REST API endpoints (Epics 1-9) are complete and available for the Angular UI to consume

### Project Structure Notes

- The `ui/` directory is at the project root level, parallel to `src/IRISCouch/`
- The Angular app compiles to static assets that are committed to `ui/dist/browser/`
- The ObjectScript `AdminUIHandler` class serves these static assets from `/_utils/`

### References

- [Source: _bmad-output/planning-artifacts/architecture.md#Selected Foundation — Angular Admin UI]
- [Source: _bmad-output/planning-artifacts/architecture.md#Admin UI Build Integration]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Color System]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Typography System]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Spacing & Layout Foundation]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Design System Foundation]
- [Source: _bmad-output/planning-artifacts/epics.md#Story 10.1]

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6 (1M context)

### Debug Log References
- No debug issues encountered; greenfield scaffold went cleanly.

### Completion Notes List
- Created Angular 18 project scaffold in `ui/` at project root using `ng new` with `--style=css --routing --ssr=false --skip-tests=false --skip-git`
- Added `@angular/cdk@18.2.14` as only additional dependency; verified no Angular Material, NgRx, PrimeNG, or other banned libraries
- Created full directory structure: `src/app/couch-ui/`, `src/app/features/{databases,documents,design-docs,security,revisions}/`
- Created `src/styles/tokens.css` with all 11 neutral palette, 4 semantic color, 7 spacing, 6 type scale, border, and font-family tokens matching exact UX spec hex values
- Created `src/styles/global.css` with CSS reset, base body styles, `.mono` class, focus-visible outline, and `prefers-reduced-motion` media query
- Downloaded JetBrains Mono WOFF2 Latin-1 subset (21KB) to `src/assets/fonts/`; `@font-face` declaration uses `/iris-couch/_utils/` path with `font-display: block`
- Created 20 standalone Lucide SVG icon components in `src/app/couch-ui/icons/` with barrel export; each supports `[size]` input, `aria-hidden="true"`, `currentColor` stroke, 16x16 default
- Configured `index.html` with `lang="en"`, `viewport width=1280`, title "iris-couch", no favicon, no external references
- Configured `angular.json` with `outputPath: {base: "dist", browser: "browser"}`, `baseHref: /iris-couch/_utils/`
- Updated `app.component` to render iris-couch wordmark as text-only monospace string in neutral-600 in the header
- All 45 tests pass (4 app component tests + 41 icon component tests)
- Production build outputs to `ui/dist/browser/` with zero external CDN references
- Verified in browser via Chrome DevTools MCP: all design tokens visible, font loads from local path, correct HTML attributes, no external network requests

### File List
- ui/angular.json (modified — outputPath, baseHref, styles array, assets config)
- ui/package.json (modified — @angular/cdk added)
- ui/package-lock.json (modified — @angular/cdk dependency tree)
- ui/src/index.html (modified — lang, viewport, title, removed favicon)
- ui/src/app/app.component.html (modified — iris-couch wordmark header)
- ui/src/app/app.component.css (modified — header/wordmark styles)
- ui/src/app/app.component.spec.ts (modified — tests for new template)
- ui/src/styles/tokens.css (new — design token custom properties)
- ui/src/styles/global.css (new — CSS reset, base styles, @font-face, focus-visible)
- ui/src/assets/fonts/jetbrains-mono-latin-400.woff2 (new — bundled font, 21KB)
- ui/src/app/couch-ui/icons/icon-database.component.ts (new)
- ui/src/app/couch-ui/icons/icon-file-text.component.ts (new)
- ui/src/app/couch-ui/icons/icon-shield.component.ts (new)
- ui/src/app/couch-ui/icons/icon-settings.component.ts (new)
- ui/src/app/couch-ui/icons/icon-info.component.ts (new)
- ui/src/app/couch-ui/icons/icon-menu.component.ts (new)
- ui/src/app/couch-ui/icons/icon-plus.component.ts (new)
- ui/src/app/couch-ui/icons/icon-trash.component.ts (new)
- ui/src/app/couch-ui/icons/icon-refresh.component.ts (new)
- ui/src/app/couch-ui/icons/icon-copy.component.ts (new)
- ui/src/app/couch-ui/icons/icon-check.component.ts (new)
- ui/src/app/couch-ui/icons/icon-download.component.ts (new)
- ui/src/app/couch-ui/icons/icon-search.component.ts (new)
- ui/src/app/couch-ui/icons/icon-x.component.ts (new)
- ui/src/app/couch-ui/icons/icon-alert-triangle.component.ts (new)
- ui/src/app/couch-ui/icons/icon-alert-circle.component.ts (new)
- ui/src/app/couch-ui/icons/icon-check-circle.component.ts (new)
- ui/src/app/couch-ui/icons/icon-chevron-right.component.ts (new)
- ui/src/app/couch-ui/icons/icon-chevron-left.component.ts (new)
- ui/src/app/couch-ui/icons/icon-chevron-down.component.ts (new)
- ui/src/app/couch-ui/icons/index.ts (new — barrel export)
- ui/src/app/couch-ui/icons/icon-components.spec.ts (new — 41 icon tests)
- ui/src/styles.css (deleted — replaced by tokens.css + global.css)
- ui/public/favicon.ico (deleted — removed default Angular favicon)

### Review Findings

- [x] [Review][Defer] No ChangeDetectionStrategy.OnPush on icon components [ui/src/app/couch-ui/icons/*.ts] — deferred, LOW, address project-wide when more components exist
- [x] [Review][Defer] @Input() decorator vs modern input() signal [ui/src/app/couch-ui/icons/*.ts] — deferred, LOW, stylistic preference for later adoption
- [x] [Review][Defer] No JetBrains Mono weight 500 bundled [ui/src/assets/fonts/] — deferred, LOW, per story decision; revisit if synthetic bold looks poor

## Change Log
- 2026-04-14: Story 10.1 implemented — Angular scaffold, design tokens, global styles, JetBrains Mono font, 20 Lucide icon components, HTML document config, build config for /iris-couch/_utils/, smoke test verified via Chrome DevTools MCP. 45 tests passing.
- 2026-04-14: Code review complete — clean review. 0 decision-needed, 0 patches, 3 deferred (LOW), 2 dismissed as noise.
