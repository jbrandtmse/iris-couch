import { Component, Input } from '@angular/core';

/**
 * CouchUI IconButton component.
 *
 * A minimal button wrapper for icon-only actions with mandatory aria-label.
 * 24x24px minimum hit target. Icon is passed via content projection.
 *
 * Usage:
 *   <app-icon-button ariaLabel="Refresh">
 *     <app-icon-refresh />
 *   </app-icon-button>
 */
@Component({
  selector: 'app-icon-button',
  standalone: true,
  template: `
    <button
      type="button"
      class="icon-btn"
      [disabled]="disabled"
      [attr.aria-label]="ariaLabel">
      <ng-content></ng-content>
    </button>
  `,
  styles: [`
    :host {
      display: inline-flex;
    }

    .icon-btn {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      min-width: 24px;
      min-height: 24px;
      width: 24px;
      height: 24px;
      padding: 0;
      border: none;
      background: transparent;
      color: var(--color-neutral-500);
      cursor: pointer;
      border-radius: var(--border-radius);
      transition: background-color 0.15s ease, color 0.15s ease;
    }

    .icon-btn:hover:not(:disabled) {
      background-color: var(--color-neutral-50);
      color: var(--color-neutral-700);
    }

    .icon-btn:active:not(:disabled) {
      background-color: var(--color-neutral-100);
    }

    .icon-btn:focus-visible {
      outline: 2px solid var(--color-info);
      outline-offset: 3px;
    }

    .icon-btn:disabled {
      opacity: 0.5;
      cursor: not-allowed;
    }

    @media (prefers-reduced-motion: reduce) {
      .icon-btn {
        transition: none;
      }
    }
  `]
})
export class IconButtonComponent {
  @Input({ required: true }) ariaLabel!: string;
  @Input() disabled = false;
}
