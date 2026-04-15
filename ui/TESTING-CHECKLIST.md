# iris-couch Admin UI -- Alpha Release Testing Checklist

This checklist covers manual QA verification for the iris-couch admin UI.
Each section must be completed before an alpha release is approved.

---

## 1. Keyboard-Only Smoke Test

Unplug the mouse (or disable the trackpad). Complete the entire flow using only keyboard.

- [ ] **Login**: Tab to username field, type username, Tab to password, type password, Tab to Sign In, press Enter
- [ ] **Database list**: Verify page loads after login, Tab to "Create database" button, press Enter
- [ ] **Create database dialog**: Tab to input, type name, Tab to Create button, press Enter; verify dialog closes
- [ ] **Delete database**: Tab to a table row, press Enter to navigate, navigate back; open delete dialog via context
- [ ] **Database detail / Document list**: Tab through filter input, table rows; press Enter on a row to navigate to document detail
- [ ] **Filter**: Press `/` to focus filter input; type prefix; press Escape to clear
- [ ] **Document detail**: Tab through breadcrumbs, copy buttons, conflict toggle (if present), attachment download links
- [ ] **Dialogs**: Press Escape to close any open dialog
- [ ] **Side navigation**: Use Arrow Up/Down to move between nav items; Enter to activate
- [ ] **Skip-to-content**: Press Tab immediately after page load; verify "Skip to content" link appears; press Enter to jump to main content

**Result**: [ ] PASS / [ ] FAIL

---

## 2. Screen Reader Smoke Test

Use NVDA (Windows), VoiceOver (macOS), or JAWS. Verify the following announcements.

- [ ] **ErrorDisplay**: role="alert" and aria-live="assertive" are announced immediately when an error appears
- [ ] **CopyButton**: "Copied." is announced via LiveAnnouncer after clicking a copy button
- [ ] **Database list load**: "Loaded database list" is announced on navigation to /databases
- [ ] **Document detail load**: "Loaded document {id}" is announced on navigation to a document
- [ ] **Dialog open**: Dialog title is announced when a confirm dialog opens (aria-labelledby)
- [ ] **Dialog close**: Focus returns to the triggering element after dialog closes
- [ ] **Navigation**: aria-current="page" is set on the active SideNav item

**Result**: [ ] PASS / [ ] FAIL

---

## 3. Color-Blind Simulation

Use Chrome DevTools > Rendering > "Emulate vision deficiencies" for each mode.

- [ ] **Protanopia** (red-blind): All badges remain distinguishable via text labels; error states are readable
- [ ] **Deuteranopia** (green-blind): Success and error badges are distinguishable via text, not color alone
- [ ] **Tritanopia** (blue-blind): Info badges remain readable
- [ ] **Achromatopsia** (no color): All semantic information is conveyed by text and/or icons, not color alone

**Result**: [ ] PASS / [ ] FAIL

---

## 4. Reduced-Motion Toggle

Enable "Reduce motion" in OS accessibility settings, or use Chrome DevTools > Rendering > "Emulate CSS media feature prefers-reduced-motion".

- [ ] **Button loading spinner**: Spinner is static (no rotation animation)
- [ ] **CopyButton icon transition**: Icon swap is instant (no fade/transition)
- [ ] **ConfirmDialog open**: Dialog appears instantly (no scale/opacity animation)
- [ ] **PageHeader loading bar**: Loading bar is static (no progress animation)
- [ ] **SideNav hover**: No transition on hover state change
- [ ] **All interactive elements**: No visible transitions on any hover, focus, or state change

**Result**: [ ] PASS / [ ] FAIL

---

## 5. Cross-Browser Test

Complete the login -> database list -> document detail flow in each browser.

| Browser          | Login | DB List | Create DB | Doc List | Doc Detail | Notes |
|------------------|-------|---------|-----------|----------|------------|-------|
| Chrome (latest)  | [ ]   | [ ]     | [ ]       | [ ]      | [ ]        |       |
| Firefox (latest) | [ ]   | [ ]     | [ ]       | [ ]      | [ ]        |       |
| Safari (macOS)   | [ ]   | [ ]     | [ ]       | [ ]      | [ ]        |       |
| Edge (latest)    | [ ]   | [ ]     | [ ]       | [ ]      | [ ]        |       |

**Result**: [ ] PASS / [ ] FAIL

---

## 6. Error Handling Verification

- [ ] **Network error**: Stop the IRIS server, navigate to /databases; verify "Cannot reach `/iris-couch/`. Check that the server is running." message with Retry button
- [ ] **5xx error on database list**: Verify ErrorDisplay appears in-place (not a toast)
- [ ] **5xx error on document detail**: Verify ErrorDisplay appears in-place with Retry button
- [ ] **404 error on document detail**: Verify ErrorDisplay shows "not_found" verbatim
- [ ] **Retry**: Click Retry button; verify it re-fetches the failed request

**Result**: [ ] PASS / [ ] FAIL

---

## Sign-Off

| Tester | Date | Overall Result |
|--------|------|----------------|
|        |      | [ ] PASS / [ ] FAIL |
