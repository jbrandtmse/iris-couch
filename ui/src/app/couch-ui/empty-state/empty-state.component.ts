import { Component, Input, Output, EventEmitter } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ButtonComponent } from '../button/button.component';

/**
 * CouchUI EmptyState component.
 *
 * Displays a centered vertical flex column with primary and secondary
 * text lines, and an optional primary CTA button. No illustration, no icon.
 *
 * Usage:
 *   <app-empty-state
 *     primary="No databases yet."
 *     secondary="Create one to get started."
 *     ctaLabel="Create database"
 *     (ctaClick)="onCreate()">
 *   </app-empty-state>
 */
@Component({
  selector: 'app-empty-state',
  standalone: true,
  imports: [CommonModule, ButtonComponent],
  template: `
    <div class="empty-state">
      <p class="empty-state__primary">{{ primary }}</p>
      <p *ngIf="secondary" class="empty-state__secondary">{{ secondary }}</p>
      <app-button
        *ngIf="ctaLabel"
        variant="primary"
        (click)="ctaClick.emit()"
        class="empty-state__cta">
        {{ ctaLabel }}
      </app-button>
    </div>
  `,
  styles: [`
    :host {
      display: block;
    }

    .empty-state {
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      gap: var(--space-2);
      padding: var(--space-12) var(--space-4);
      text-align: center;
    }

    .empty-state__primary {
      font-size: var(--font-size-md);
      line-height: var(--line-height-md);
      font-weight: 500;
      color: var(--color-neutral-700);
    }

    .empty-state__secondary {
      font-size: var(--font-size-sm);
      line-height: var(--line-height-sm);
      color: var(--color-neutral-500);
    }

    .empty-state__cta {
      margin-top: var(--space-2);
    }
  `]
})
export class EmptyStateComponent {
  @Input({ required: true }) primary!: string;
  @Input() secondary?: string;
  @Input() ctaLabel?: string;
  @Output() ctaClick = new EventEmitter<void>();
}
