import { Component, Input } from '@angular/core';
import { CommonModule } from '@angular/common';

/**
 * CouchUI Button component.
 *
 * Wraps a native `<button>` with three visual variants and three sizes.
 * Supports loading state with CSS spinner, and disabled state.
 *
 * Usage:
 *   <app-button variant="primary" size="standard">Save</app-button>
 *   <app-button [loading]="true">Processing</app-button>
 *   <app-button variant="destructive" ariaLabel="Delete item">
 *     <app-icon-trash />
 *   </app-button>
 */
@Component({
  selector: 'app-button',
  standalone: true,
  imports: [CommonModule],
  template: `
    <button
      [type]="type"
      [disabled]="disabled || loading"
      [attr.aria-label]="ariaLabel || null"
      [attr.aria-busy]="loading || null"
      [class]="'btn btn--' + variant + ' btn--' + size"
      [class.btn--loading]="loading"
      [class.btn--disabled]="disabled">
      <span class="btn__spinner" *ngIf="loading" aria-hidden="true"></span>
      <span class="btn__content" [class.btn__content--hidden-icon]="loading">
        <ng-content></ng-content>
      </span>
    </button>
  `,
  styles: [`
    :host {
      display: inline-block;
    }

    .btn {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      gap: var(--space-1);
      border-radius: var(--border-radius);
      font-family: var(--font-sans);
      font-size: var(--font-size-sm);
      line-height: var(--line-height-sm);
      font-weight: 500;
      cursor: pointer;
      border: 1px solid transparent;
      transition: background-color 0.15s ease, border-color 0.15s ease, color 0.15s ease;
      position: relative;
      white-space: nowrap;
    }

    /* ── Sizes ── */
    .btn--compact {
      height: 28px;
      padding: 0 var(--space-2);
      font-size: var(--font-size-xs);
    }

    .btn--standard {
      height: 32px;
      padding: 0 var(--space-3);
    }

    .btn--primary-page {
      height: 40px;
      padding: 0 var(--space-4);
      font-size: var(--font-size-md);
    }

    /* ── Ghost Variant (default) ── */
    .btn--ghost {
      background-color: transparent;
      border-color: var(--color-neutral-200);
      color: var(--color-neutral-700);
    }

    .btn--ghost:hover:not(:disabled) {
      background-color: var(--color-neutral-50);
      border-color: var(--color-neutral-300);
    }

    .btn--ghost:active:not(:disabled) {
      background-color: var(--color-neutral-100);
    }

    /* ── Primary Variant ── */
    .btn--primary {
      background-color: var(--color-neutral-800);
      border-color: var(--color-neutral-800);
      color: var(--color-neutral-0);
    }

    .btn--primary:hover:not(:disabled) {
      background-color: var(--color-neutral-900);
      border-color: var(--color-neutral-900);
    }

    .btn--primary:active:not(:disabled) {
      background-color: var(--color-neutral-700);
      border-color: var(--color-neutral-700);
    }

    /* ── Destructive Variant ── */
    .btn--destructive {
      background-color: var(--color-neutral-0);
      border-color: var(--color-error);
      color: var(--color-error);
    }

    .btn--destructive:hover:not(:disabled) {
      background-color: rgba(195, 63, 63, 0.06);
    }

    .btn--destructive:active:not(:disabled) {
      background-color: rgba(195, 63, 63, 0.1);
    }

    /* ── Focus ── */
    .btn:focus-visible {
      outline: 2px solid var(--color-info);
      outline-offset: 3px;
    }

    /* ── Disabled ── */
    .btn:disabled {
      opacity: 0.5;
      cursor: not-allowed;
    }

    /* ── Loading ── */
    .btn__spinner {
      width: 14px;
      height: 14px;
      border: 2px solid currentColor;
      border-right-color: transparent;
      border-radius: 50%;
      display: inline-block;
      animation: spin 0.6s linear infinite;
    }

    .btn__content--hidden-icon ::ng-deep app-icon-copy,
    .btn__content--hidden-icon ::ng-deep app-icon-check,
    .btn__content--hidden-icon ::ng-deep [class^="app-icon-"] {
      visibility: hidden;
      width: 0;
      overflow: hidden;
    }

    .btn__content {
      display: inline-flex;
      align-items: center;
      gap: var(--space-1);
    }

    @keyframes spin {
      to { transform: rotate(360deg); }
    }

    /* ── Reduced Motion ── */
    @media (prefers-reduced-motion: reduce) {
      .btn {
        transition: none;
      }
      .btn__spinner {
        animation: none;
        border-right-color: currentColor;
        opacity: 0.5;
      }
    }
  `]
})
export class ButtonComponent {
  @Input() variant: 'ghost' | 'primary' | 'destructive' = 'ghost';
  @Input() size: 'compact' | 'standard' | 'primary-page' = 'standard';
  @Input() loading = false;
  @Input() disabled = false;
  @Input() ariaLabel?: string;
  @Input() type: 'button' | 'submit' = 'button';
}
