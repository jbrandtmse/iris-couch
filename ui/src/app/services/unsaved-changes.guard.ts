import { CanDeactivateFn } from '@angular/router';
import { Observable } from 'rxjs';

/**
 * Contract for any component that wants to participate in the
 * `unsavedChangesGuard`. Implementing components return `true` from
 * `hasUnsavedChanges()` whenever a discard would lose data.
 *
 * Components are also responsible for surfacing the actual confirmation
 * dialog: when the guard fires, it calls `confirmDiscard()` and waits for
 * the resolved promise/observable. This keeps the presentation concern in
 * the component and the guard pure (no Material/CDK overlay imports here).
 *
 * Story 11.3 Task 6.
 */
export interface HasUnsavedChanges {
  hasUnsavedChanges(): boolean;
  /**
   * Show the "discard changes?" prompt and resolve to true (discard, allow
   * navigation) or false (cancel, stay on this view). Implementations are
   * expected to use the shared `ConfirmDialog` warning variant for visual
   * consistency.
   */
  confirmDiscard(): Promise<boolean> | Observable<boolean>;
}

/**
 * Functional `CanDeactivate` guard for components that hold an editor with
 * unsaved changes (Story 11.3 design-doc-detail and security-view).
 *
 * Algorithm:
 *   1. If the leaving component does not implement `HasUnsavedChanges`,
 *      allow the navigation immediately (defensive default).
 *   2. If `hasUnsavedChanges()` returns false, allow the navigation.
 *   3. Otherwise, delegate to `confirmDiscard()` and bubble its decision
 *      back to the router.
 *
 * Reused across multiple routes per the story's "shared guard" requirement.
 */
export const unsavedChangesGuard: CanDeactivateFn<HasUnsavedChanges | unknown> = (
  component,
) => {
  if (!component || typeof (component as HasUnsavedChanges).hasUnsavedChanges !== 'function') {
    return true;
  }
  const target = component as HasUnsavedChanges;
  if (!target.hasUnsavedChanges()) {
    return true;
  }
  // Component owns the visual confirmation. Promise<boolean> | Observable<boolean>
  // are both legal CanDeactivate return types, so just pass it through.
  return target.confirmDiscard();
};
