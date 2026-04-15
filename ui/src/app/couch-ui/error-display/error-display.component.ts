import { Component, Input, Output, EventEmitter } from '@angular/core';
import { CommonModule } from '@angular/common';
import { BadgeComponent } from '../badge/badge.component';
import { ButtonComponent } from '../button/button.component';

/**
 * ErrorDisplay component.
 *
 * Displays a verbatim server error envelope with optional status code badge
 * and retry button. Content is ALWAYS verbatim from the server -- no
 * rephrasing, no "Oops".
 *
 * Two variants:
 * - `full`: error-colored 1px border, error-10% background, full block
 * - `inline`: compact, no border container
 */
@Component({
  selector: 'app-error-display',
  standalone: true,
  imports: [CommonModule, BadgeComponent, ButtonComponent],
  template: `
    <div
      class="error-display"
      [class.error-display--full]="variant === 'full'"
      [class.error-display--inline]="variant === 'inline'"
      role="alert"
      aria-live="assertive">
      <div class="error-display__header">
        <app-badge *ngIf="statusCode" variant="error">{{ statusCode }}</app-badge>
        <span class="error-display__error mono">{{ error.error }}</span>
      </div>
      <span *ngIf="error.reason" class="error-display__reason mono">{{ error.reason }}</span>
      <app-button
        *ngIf="retryable"
        variant="ghost"
        size="compact"
        (click)="retry.emit()"
        ariaLabel="Retry">
        Retry
      </app-button>
    </div>
  `,
  styles: [`
    :host {
      display: block;
    }

    .error-display {
      display: flex;
      flex-direction: column;
      gap: var(--space-2);
    }

    .error-display--full {
      padding: var(--space-3);
      border: 1px solid var(--color-error);
      border-radius: var(--border-radius);
      background-color: var(--color-danger-bg);
    }

    .error-display--inline {
      padding: var(--space-2) 0;
    }

    .error-display__header {
      display: flex;
      align-items: center;
      gap: var(--space-2);
    }

    .error-display__error {
      font-size: var(--font-size-sm);
      line-height: var(--line-height-sm);
      font-weight: 600;
      color: var(--color-error-fg);
    }

    .error-display__reason {
      font-size: var(--font-size-sm);
      line-height: var(--line-height-sm);
      color: var(--color-neutral-600);
    }
  `]
})
export class ErrorDisplayComponent {
  @Input({ required: true }) error!: { error: string; reason: string };
  @Input() statusCode?: number;
  @Input() variant: 'full' | 'inline' = 'full';
  @Input() retryable = false;
  @Output() retry = new EventEmitter<void>();
}
