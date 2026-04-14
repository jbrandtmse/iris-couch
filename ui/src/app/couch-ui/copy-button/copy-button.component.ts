import { Component, Input, NgZone, OnDestroy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Clipboard } from '@angular/cdk/clipboard';
import { LiveAnnouncer } from '@angular/cdk/a11y';
import { IconCopyComponent, IconCheckComponent } from '../icons';

/**
 * CouchUI CopyButton component.
 *
 * Copies a text value to the clipboard using CDK Clipboard.
 * Announces "Copied." via CDK LiveAnnouncer for screen readers.
 * Shows a check icon for ~600ms after successful copy.
 *
 * Usage:
 *   <app-copy-button [value]="docId" />
 *   <app-copy-button [value]="jsonText" variant="block" />
 */
@Component({
  selector: 'app-copy-button',
  standalone: true,
  imports: [CommonModule, IconCopyComponent, IconCheckComponent],
  template: `
    <button
      type="button"
      class="copy-btn"
      [class.copy-btn--block]="variant === 'block'"
      [attr.aria-label]="ariaLabel"
      (click)="onCopy()">
      <app-icon-check *ngIf="copied" [size]="20" />
      <app-icon-copy *ngIf="!copied" [size]="20" />
      <span *ngIf="variant === 'block'" class="copy-btn__label">Copy raw JSON</span>
    </button>
  `,
  styles: [`
    :host {
      display: inline-flex;
    }

    .copy-btn {
      display: inline-flex;
      align-items: center;
      gap: var(--space-1);
      padding: 2px;
      border: none;
      background: transparent;
      color: var(--color-neutral-500);
      cursor: pointer;
      border-radius: var(--border-radius);
      transition: color 0.15s ease, background-color 0.15s ease;
    }

    .copy-btn:hover:not(:disabled) {
      color: var(--color-neutral-700);
      background-color: var(--color-neutral-50);
    }

    .copy-btn:focus-visible {
      outline: 2px solid var(--color-info);
      outline-offset: 3px;
    }

    .copy-btn--block {
      padding: var(--space-1) var(--space-2);
    }

    .copy-btn__label {
      font-size: var(--font-size-sm);
      line-height: var(--line-height-sm);
    }

    @media (prefers-reduced-motion: reduce) {
      .copy-btn {
        transition: none;
      }
    }
  `]
})
export class CopyButtonComponent implements OnDestroy {
  @Input({ required: true }) value!: string;
  @Input() ariaLabel = 'Copy';
  @Input() variant: 'inline' | 'block' = 'inline';

  copied = false;
  private timeoutId: ReturnType<typeof setTimeout> | null = null;

  constructor(
    private clipboard: Clipboard,
    private liveAnnouncer: LiveAnnouncer,
    private ngZone: NgZone
  ) {}

  ngOnDestroy(): void {
    if (this.timeoutId !== null) {
      clearTimeout(this.timeoutId);
      this.timeoutId = null;
    }
  }

  onCopy(): void {
    const success = this.clipboard.copy(this.value);
    if (success) {
      this.copied = true;
      this.liveAnnouncer.announce('Copied.');

      /* Clear any existing timeout */
      if (this.timeoutId !== null) {
        clearTimeout(this.timeoutId);
      }

      /* Reset icon after ~600ms (runs outside Angular zone to avoid
         unnecessary change detection, then re-enters zone for the update) */
      this.ngZone.runOutsideAngular(() => {
        this.timeoutId = setTimeout(() => {
          this.ngZone.run(() => {
            this.copied = false;
            this.timeoutId = null;
          });
        }, 600);
      });
    }
  }
}
