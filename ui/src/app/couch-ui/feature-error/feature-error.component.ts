import { Component, EventEmitter, Input, Output } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ErrorDisplayComponent } from '../error-display/error-display.component';
import { DisplayError, mapError } from '../../services/error-mapping';

/**
 * FeatureError — shared wrapper for the "feature page failed to load" pattern.
 *
 * Three feature components (database-list, database-detail, document-detail)
 * had near-duplicate inline code that:
 *   1. Listened for an HTTP error,
 *   2. ran it through `mapError()`,
 *   3. stored `{error, reason}` plus status code as component fields,
 *   4. rendered an `<app-error-display variant="full" [retryable]="true">`,
 *   5. wired a (retry) handler back to the loader.
 *
 * This component extracts steps 4 and 5, and exposes a helper `setFromRaw()`
 * so callers can hand a raw `unknown` error directly without duplicating the
 * `mapError` boilerplate in every feature.
 *
 * Usage:
 *   <app-feature-error
 *     *ngIf="!loading && displayError"
 *     [error]="displayError"
 *     [statusCode]="errorStatus"
 *     [retryable]="true"
 *     (retry)="loadData()">
 *   </app-feature-error>
 *
 * For ergonomics:
 *   [rawError] — pass an unknown value, FeatureError will run mapError()
 *                internally and render the mapped output.
 *
 * See Story 11.0 AC #5 / Task 5.
 */
@Component({
  selector: 'app-feature-error',
  standalone: true,
  imports: [CommonModule, ErrorDisplayComponent],
  template: `
    <app-error-display
      *ngIf="error"
      [error]="error"
      [statusCode]="statusCode"
      [variant]="variant"
      [retryable]="retryable"
      (retry)="onRetry()">
    </app-error-display>
  `,
  styles: [`
    :host {
      display: block;
    }
  `],
})
export class FeatureErrorComponent {
  /**
   * Pre-mapped error to display. If not provided, `rawError` is mapped
   * on-the-fly.
   */
  @Input() error: DisplayError | null = null;

  /** HTTP status code used by ErrorDisplay to select retry copy. */
  @Input() statusCode?: number;

  /** Display variant — full panel by default, inline for tight placements. */
  @Input() variant: 'full' | 'inline' = 'full';

  /** Whether to show the retry button. */
  @Input() retryable = true;

  /**
   * Convenience input: pass a raw error value (HttpErrorResponse, Error, etc.)
   * and FeatureError will apply `mapError()` internally. Takes precedence
   * over the pre-mapped `error` input when both are non-null.
   */
  @Input()
  set rawError(value: unknown | null) {
    if (value == null) {
      this.error = null;
      this.statusCode = undefined;
      return;
    }
    const mapped = mapError(value);
    this.error = mapped.display;
    // Story 13.4 Task 8g: preserve an existing statusCode when the new raw
    // error does not carry one. Previously, a partial-update that mapped to
    // a status-less error (e.g., a plain Error rethrown from a local callback)
    // would overwrite a good HTTP status code with `undefined`, losing the
    // retry-copy selection.
    if (mapped.statusCode !== undefined) {
      this.statusCode = mapped.statusCode;
    }
  }

  @Output() retry = new EventEmitter<void>();

  onRetry(): void {
    this.retry.emit();
  }
}
