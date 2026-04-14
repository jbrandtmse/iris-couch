# Story 10.2: Core UI Components (Button, Badge, TextInput, CopyButton)

Status: done

## Story

As an operator,
I want polished, accessible core UI primitives,
so that all views have consistent interactive elements with proper keyboard and screen reader support.

## Acceptance Criteria

1. **Given** the Button component is implemented
   **When** it is rendered
   **Then** it wraps a native `<button>` with three variants: `ghost` (default), `primary` (max one per page), `destructive` (only inside ConfirmDialog)
   **And** three sizes: 28px compact, 32px standard, 40px primary-page
   **And** states: default, hover, focus-visible, active, disabled, loading (spinner replaces icon, label stays)
   **And** `aria-label` is required if icon-only

2. **Given** the IconButton component
   **When** it is rendered
   **Then** it has a 24x24px minimum hit target with mandatory `aria-label`
   **And** Lucide SVG icons are marked `aria-hidden="true"`
   **And** neutral-50 fill appears on hover

3. **Given** the Badge component
   **When** it is rendered
   **Then** it displays as an inline `<span>` with 1px semantic-color border and ~10% alpha background
   **And** four variants are available: `info`, `warn`, `error`, `success`

4. **Given** the TextInput component
   **When** it is rendered
   **Then** it wraps a native `<input>` at 32px height with a real `<label>` above (never placeholder-as-label)
   **And** states: default, focus (info-colored border + box-shadow), disabled, error (`aria-invalid="true"`)
   **And** hint text linked via `aria-describedby`

5. **Given** the CopyButton component
   **When** the user clicks it
   **Then** content is copied to clipboard via CDK clipboard
   **And** the icon changes to a check icon for ~600ms
   **And** CDK LiveAnnouncer announces "Copied." to screen readers

6. **Given** any interactive component
   **When** it receives keyboard focus
   **Then** a visible 2px outline in `--color-info` at 3px offset is displayed
   **And** all transitions respect `prefers-reduced-motion: reduce`
   **And** no text renders below 12px
   **And** each component `.spec.ts` includes at least one `axe-core` assertion

## Tasks / Subtasks

- [x] Task 1: Install axe-core for accessibility testing (AC: #6)
  - [x] Run `npm install --save-dev axe-core` in the `ui/` directory
  - [x] Verify axe-core integrates with Jasmine test runner
  - [x] Create a test helper `src/app/couch-ui/test-utils.ts` with axe assertion wrapper for component tests

- [x] Task 2: Button component (AC: #1, #6)
  - [x] Create `src/app/couch-ui/button/button.component.ts` as standalone Angular component
  - [x] Inputs:
    - `variant`: `'ghost' | 'primary' | 'destructive'` (default: `'ghost'`)
    - `size`: `'compact' | 'standard' | 'primary-page'` (default: `'standard'`)
    - `loading`: `boolean` (default: `false`)
    - `disabled`: `boolean` (default: `false`)
    - `ariaLabel`: `string` (optional, required for icon-only)
    - `type`: `'button' | 'submit'` (default: `'button'`)
  - [x] Wraps native `<button>` element with `type` attribute
  - [x] Content projection with `<ng-content>` for label text and optional icon slots
  - [x] CSS using design tokens:
    - ghost: transparent background, `--color-neutral-200` border
    - primary: `--color-neutral-800` background, `--color-neutral-0` text
    - destructive: `--color-neutral-0` background, `--color-error` border and text
    - Sizes: 28px compact, 32px standard, 40px primary-page
    - Hover, focus-visible, active, disabled states
    - Loading state: CSS spinner animation replacing icon, label stays visible
    - `prefers-reduced-motion`: disable spinner animation
  - [x] Create `button.component.spec.ts` with:
    - Renders with correct variant classes
    - Disabled state disables native button
    - Loading state shows spinner
    - Focus-visible shows info-colored outline
    - At least one axe-core assertion

- [x] Task 3: IconButton component (AC: #2, #6)
  - [x] Create `src/app/couch-ui/icon-button/icon-button.component.ts` as standalone
  - [x] Inputs:
    - `ariaLabel`: `string` (REQUIRED)
    - `disabled`: `boolean` (default: `false`)
  - [x] 24x24px minimum hit target, icon centered via `<ng-content>`
  - [x] No visible background by default; `--color-neutral-50` fill on hover
  - [x] Icon passed via content projection, must have `aria-hidden="true"`
  - [x] Create `icon-button.component.spec.ts` with:
    - Renders with correct size
    - Hover shows neutral-50 background
    - aria-label is applied
    - At least one axe-core assertion

- [x] Task 4: Badge component (AC: #3, #6)
  - [x] Create `src/app/couch-ui/badge/badge.component.ts` as standalone
  - [x] Inputs:
    - `variant`: `'info' | 'warn' | 'error' | 'success'` (default: `'info'`)
  - [x] Renders as inline `<span>` with:
    - 1px border in semantic color
    - ~10% alpha semantic-color background
    - Semantic-color text
    - Font size 10px uppercase (small-caps style)
    - 1px vertical + 4px horizontal padding
  - [x] Content projection for label text
  - [x] Create `badge.component.spec.ts` with:
    - Renders all four variants with correct colors
    - Displays as inline element
    - At least one axe-core assertion

- [x] Task 5: TextInput component (AC: #4, #6)
  - [x] Create `src/app/couch-ui/text-input/text-input.component.ts` as standalone
  - [x] Inputs:
    - `label`: `string` (REQUIRED)
    - `id`: `string` (auto-generated if not provided)
    - `placeholder`: `string` (optional)
    - `hint`: `string` (optional — linked via `aria-describedby`)
    - `error`: `string` (optional — when set, shows error state)
    - `disabled`: `boolean`
    - `mono`: `boolean` (default: `true` — uses monospace font for identifier inputs)
    - `type`: `'text' | 'password'` (default: `'text'`)
    - `value`: `string` with two-way binding via `[(value)]`
  - [x] Real `<label>` element above the `<input>` (never placeholder-as-label)
  - [x] 32px height, 12px horizontal padding
  - [x] States:
    - Default: `--color-neutral-200` border
    - Focus: `--color-info` border + 2px info-10% box-shadow
    - Disabled: reduced opacity
    - Error: `--color-error` border, error hint text, `aria-invalid="true"`
  - [x] Hint text below input linked via `aria-describedby`
  - [x] Error text replaces hint when error is set
  - [x] Create `text-input.component.spec.ts` with:
    - Renders label above input
    - Focus state shows info border
    - Error state shows error message and sets aria-invalid
    - Hint text linked via aria-describedby
    - At least one axe-core assertion

- [x] Task 6: CopyButton component (AC: #5, #6)
  - [x] Create `src/app/couch-ui/copy-button/copy-button.component.ts` as standalone
  - [x] Inputs:
    - `value`: `string` (REQUIRED — the text to copy)
    - `ariaLabel`: `string` (default: `'Copy'`)
    - `variant`: `'inline' | 'block'` (default: `'inline'`)
  - [x] Uses CDK clipboard (`Clipboard` service) for copy operation
  - [x] Uses CDK LiveAnnouncer to announce "Copied." to screen readers
  - [x] Inline variant: Lucide copy icon (20x20px), switches to check icon for ~600ms on success
  - [x] Block variant: includes "Copy raw JSON" text alongside icon
  - [x] The ~600ms check icon respects `prefers-reduced-motion` (instant switch, no transition)
  - [x] Create `copy-button.component.spec.ts` with:
    - Renders copy icon by default
    - Click triggers clipboard copy
    - Icon changes to check after copy
    - LiveAnnouncer is called with "Copied."
    - Block variant shows text label
    - At least one axe-core assertion

- [x] Task 7: Barrel exports and integration verification
  - [x] Create barrel export `src/app/couch-ui/index.ts` exporting all components
  - [x] Verify all components import correctly from `./couch-ui`
  - [x] Run `ng test` — all existing + new tests pass (103 total)
  - [x] Run `ng build --configuration=production` — clean build (60.52 kB gzip)
  - [x] Verify component rendering in browser via `ng serve` + Chrome DevTools MCP

## Dev Notes

### Architecture Compliance

- All components live in `ui/src/app/couch-ui/` (domain-free component layer)
- Each component is a standalone Angular component with colocated `.spec.ts`
- Each component owns its own CSS — no shared stylesheets between components
- Design tokens come from `tokens.css` via CSS custom properties — the ONLY cross-component dependency
- Components in this story are foundation-layer only — they don't depend on each other (except CopyButton uses IconButton pattern)

### Component Specifications (from UX spec)

**Button variants:**
- `ghost`: transparent background, neutral-200 border (THE DEFAULT — most buttons are ghost)
- `primary`: neutral-800 background, neutral-0 text (max ONE per page — "Create database", "Sign in", "Save")
- `destructive`: neutral-0 background, error-colored border and text (ONLY inside ConfirmDialog)

**Button sizes:**
- compact: 28px (table row actions)
- standard: 32px (most buttons)
- primary-page: 40px (primary page actions, used sparingly)

**Badge anatomy:**
- 1px semantic-color border + ~10% alpha background + semantic-color text
- Font: 10px uppercase small-caps, 1px+4px padding
- Static — no hover, no click, no state changes

**TextInput anatomy:**
- 32px height, 12px horizontal padding
- Real `<label>` above (NEVER placeholder-as-label)
- Monospace font by default (identifier inputs)
- Focus: info-colored border + 2px info-10% box-shadow

**CopyButton:**
- Uses CDK clipboard (NOT navigator.clipboard directly)
- LiveAnnouncer for screen reader announcement (NOT visual toast)
- ~600ms check icon duration, respects prefers-reduced-motion

### Accessibility Requirements (from UX spec + AC #6)

- Every interactive component must have focus-visible: 2px `--color-info` outline at 3px offset
- All transitions respect `prefers-reduced-motion: reduce`
- No text below 12px anywhere
- Each `.spec.ts` includes at least one `axe-core` assertion
- Button: `aria-label` required when icon-only
- IconButton: `aria-label` is MANDATORY
- TextInput: real `<label>`, `aria-describedby` for hints, `aria-invalid` for errors
- CopyButton: LiveAnnouncer announces "Copied."

### Previous Story Intelligence (10.1)

- Angular 18 scaffold with CDK is in place at `ui/`
- 20 Lucide icon components exist in `ui/src/app/couch-ui/icons/` with barrel export
- `tokens.css` has all design tokens; `global.css` has reset, focus-visible base, prefers-reduced-motion
- 45 tests currently passing; production build at 60KB gzip
- Icon components use `@Input()` decorator pattern (not signals) — maintain consistency

### References

- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Component Specifications — Button, IconButton, Badge]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Component Specifications — TextInput, CopyButton]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Component Implementation Strategy]
- [Source: _bmad-output/planning-artifacts/epics.md#Story 10.2]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

- Fixed TypeScript strict type error in text-input spec (nullable hint element)
- Fixed Angular ngModel + disabled binding conflict (used `[attr.disabled]` instead of `[disabled]`)
- Fixed axe-core test utility "no expectations" warning (added explicit `expect()` call)
- Fixed `aria-describedby` referencing non-existent element when no hint/error set

### Completion Notes List

- Task 1: Installed `axe-core` (not `jasmine-axe` which has compatibility risks). Created `test-utils.ts` with `expectNoAxeViolations()` and `runAxe()` helpers that wrap axe-core for Jasmine.
- Task 2: Button component with 3 variants (ghost/primary/destructive), 3 sizes (28/32/40px), loading spinner, disabled state. 16 tests including axe-core.
- Task 3: IconButton with 24x24 hit target, required aria-label, neutral-50 hover fill. 7 tests including axe-core.
- Task 4: Badge as inline span, 4 semantic variants with 10% alpha backgrounds. 8 tests including axe-core.
- Task 5: TextInput with real label, hint/error via aria-describedby, disabled, monospace, two-way binding. 14 tests including axe-core.
- Task 6: CopyButton using CDK Clipboard + LiveAnnouncer, 600ms check icon feedback, block variant. 9 tests including axe-core.
- Task 7: Barrel export at `couch-ui/index.ts`. 103 tests pass, production build clean at 60.52 kB gzip.
- All components use design tokens from tokens.css, focus-visible outline, and prefers-reduced-motion support.
- CopyButton uses CDK Clipboard service directly (not CdkCopyToClipboard directive) for programmatic control.

### Change Log

- 2026-04-14: Story 10.2 implementation complete. 5 new components, 1 test utility, 1 barrel export. 58 new tests added (103 total).

### Review Findings

- [x] [Review][Patch] Hardcoded hex colors in destructive button hover/active states [button.component.ts:117-122] -- replaced #fef2f2 / #fee2e2 with rgba(195, 63, 63, 0.06/0.1) derived from --color-error token
- [x] [Review][Patch] TextInput `id` input never works due to constructor timing [text-input.component.ts:143-147] -- @Input values unavailable in constructor; refactored to getter pattern with private _uid
- [x] [Review][Patch] Test utilities exported in production barrel [index.ts:14] -- removed test-utils export from barrel to avoid pulling axe-core into production bundles
- [x] [Review][Patch] CopyButton missing OnDestroy cleanup for setTimeout [copy-button.component.ts] -- added OnDestroy lifecycle hook to clear pending timeout on component destruction
- [x] [Review][Defer] Badge 10px font-size vs AC #6 "no text below 12px" [badge.component.ts:29] -- deferred; UX spec explicitly requires "10 px uppercase small-caps" for badges; AC #6 and UX spec contradict; design authority takes precedence
- [x] [Review][Defer] Hardcoded RGBA values in badge backgrounds [badge.component.ts:44-59] -- deferred; these are the semantic color raw values at 10% alpha; no CSS token exists for alpha-modified semantic colors; would require new tokens in tokens.css
- [x] [Review][Defer] CopyButton no error feedback on failed clipboard copy [copy-button.component.ts:93] -- deferred; low severity; clipboard.copy() failure silently does nothing; could add visual error feedback in a future pass

### File List

- ui/package.json (modified - added axe-core devDependency)
- ui/package-lock.json (modified - lockfile update)
- ui/src/app/couch-ui/test-utils.ts (new)
- ui/src/app/couch-ui/index.ts (new)
- ui/src/app/couch-ui/button/button.component.ts (new)
- ui/src/app/couch-ui/button/button.component.spec.ts (new)
- ui/src/app/couch-ui/icon-button/icon-button.component.ts (new)
- ui/src/app/couch-ui/icon-button/icon-button.component.spec.ts (new)
- ui/src/app/couch-ui/badge/badge.component.ts (new)
- ui/src/app/couch-ui/badge/badge.component.spec.ts (new)
- ui/src/app/couch-ui/text-input/text-input.component.ts (new)
- ui/src/app/couch-ui/text-input/text-input.component.spec.ts (new)
- ui/src/app/couch-ui/copy-button/copy-button.component.ts (new)
- ui/src/app/couch-ui/copy-button/copy-button.component.spec.ts (new)
