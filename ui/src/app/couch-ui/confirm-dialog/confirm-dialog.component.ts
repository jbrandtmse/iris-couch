import {
  Component, Input, Output, EventEmitter, OnInit, OnDestroy,
  ElementRef, ViewChild, AfterViewInit
} from '@angular/core';
import { CommonModule } from '@angular/common';
import { A11yModule } from '@angular/cdk/a11y';
import { OverlayModule } from '@angular/cdk/overlay';
import { TextInputComponent } from '../text-input/text-input.component';
import { ButtonComponent } from '../button/button.component';
import { ErrorDisplayComponent } from '../error-display/error-display.component';

export type ConfirmDialogVariant =
  | 'create'
  | 'destructive-type-to-confirm'
  | 'destructive-simple'
  | 'warning';

/**
 * CouchUI ConfirmDialog component.
 *
 * A modal dialog using CDK FocusTrap for accessibility.
 * Three variants: create, destructive-type-to-confirm, destructive-simple.
 * Esc and backdrop click close the dialog.
 * Focus is trapped inside and restored to trigger on close.
 *
 * Usage:
 *   <app-confirm-dialog
 *     *ngIf="showDialog"
 *     title="Create database"
 *     variant="create"
 *     confirmLabel="Create"
 *     inputLabel="Database name"
 *     inputHint="Lowercase letters, digits, _$()+-/"
 *     (confirm)="onConfirm($event)"
 *     (cancel)="showDialog = false">
 *   </app-confirm-dialog>
 */
@Component({
  selector: 'app-confirm-dialog',
  standalone: true,
  imports: [CommonModule, A11yModule, OverlayModule, TextInputComponent, ButtonComponent, ErrorDisplayComponent],
  template: `
    <div class="dialog-backdrop" (click)="onBackdropClick($event)">
      <div
        #dialogEl
        class="dialog"
        [class.dialog--opening]="animating"
        role="dialog"
        aria-modal="true"
        [attr.aria-labelledby]="titleId"
        cdkTrapFocus
        cdkTrapFocusAutoCapture>

        <h2 [id]="titleId" class="dialog__title">{{ title }}</h2>

        <div class="dialog__body" *ngIf="body">
          <p class="dialog__body-text" [innerHTML]="body"></p>
        </div>

        <!-- Create variant: single input -->
        <div *ngIf="variant === 'create'" class="dialog__input-section">
          <app-text-input
            [label]="inputLabel"
            [hint]="inputHint"
            [error]="inputError"
            [value]="inputValue"
            (valueChange)="onInputChange($event)"
            [mono]="true">
          </app-text-input>
        </div>

        <!-- Destructive type-to-confirm: resource name + confirmation input -->
        <div *ngIf="variant === 'destructive-type-to-confirm'" class="dialog__input-section">
          <p class="dialog__confirm-prompt">
            Type <code class="dialog__confirm-value">{{ confirmValue }}</code> to confirm:
          </p>
          <app-text-input
            [label]="inputLabel || 'Confirm name'"
            [value]="inputValue"
            (valueChange)="onInputChange($event)"
            [mono]="true">
          </app-text-input>
        </div>

        <!-- Error display slot -->
        <div *ngIf="serverError" class="dialog__error">
          <app-error-display
            [error]="serverError"
            [statusCode]="serverErrorCode"
            variant="inline">
          </app-error-display>
        </div>

        <!-- Action buttons -->
        <div class="dialog__actions">
          <app-button variant="ghost" (click)="onCancel()">Cancel</app-button>
          <app-button
            [variant]="isDestructive ? 'destructive' : 'primary'"
            [disabled]="!isConfirmEnabled"
            [loading]="loading"
            (click)="onConfirm()">
            {{ confirmLabel }}
          </app-button>
        </div>
      </div>
    </div>
  `,
  styles: [`
    :host {
      display: block;
      position: fixed;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      z-index: 1000;
    }

    .dialog-backdrop {
      display: flex;
      align-items: center;
      justify-content: center;
      width: 100%;
      height: 100%;
      background-color: var(--color-scrim);
    }

    .dialog {
      width: 480px;
      max-width: calc(100vw - 32px);
      max-height: calc(100vh - 64px);
      overflow-y: auto;
      background-color: var(--color-neutral-0);
      border: 1px solid var(--color-neutral-200);
      border-radius: var(--border-radius);
      padding: var(--space-6);
      display: flex;
      flex-direction: column;
      gap: var(--space-4);
      animation: dialog-open 100ms ease-out;
    }

    .dialog--opening {
      animation: dialog-open 100ms ease-out;
    }

    @keyframes dialog-open {
      from {
        opacity: 0;
        transform: scale(0.95);
      }
      to {
        opacity: 1;
        transform: scale(1);
      }
    }

    .dialog__title {
      font-size: var(--font-size-lg);
      line-height: var(--line-height-lg);
      font-weight: 600;
      color: var(--color-neutral-800);
      margin: 0;
    }

    .dialog__body-text {
      font-size: var(--font-size-sm);
      line-height: var(--line-height-sm);
      color: var(--color-neutral-600);
      margin: 0;
    }

    .dialog__input-section {
      display: flex;
      flex-direction: column;
      gap: var(--space-2);
    }

    .dialog__confirm-prompt {
      font-size: var(--font-size-sm);
      line-height: var(--line-height-sm);
      color: var(--color-neutral-600);
      margin: 0;
    }

    .dialog__confirm-value {
      font-family: var(--font-mono);
      font-size: var(--font-size-sm);
      color: var(--color-neutral-800);
      background-color: var(--color-neutral-50);
      padding: 1px 4px;
      border-radius: var(--border-radius);
    }

    .dialog__error {
      margin-top: calc(-1 * var(--space-2));
    }

    .dialog__actions {
      display: flex;
      justify-content: flex-end;
      gap: var(--space-2);
      padding-top: var(--space-2);
    }

    @media (prefers-reduced-motion: reduce) {
      .dialog,
      .dialog--opening {
        animation: none;
      }
    }
  `]
})
export class ConfirmDialogComponent implements OnInit, OnDestroy, AfterViewInit {
  @Input({ required: true }) title!: string;
  @Input() body?: string;
  @Input() variant: ConfirmDialogVariant = 'create';
  @Input() confirmLabel = 'Confirm';
  @Input() confirmValue = '';
  @Input() inputLabel = '';
  @Input() inputHint = '';
  @Input() serverError?: { error: string; reason: string };
  @Input() serverErrorCode?: number;
  @Input() loading = false;

  @Output() confirm = new EventEmitter<string>();
  @Output() cancel = new EventEmitter<void>();

  @ViewChild('dialogEl') dialogEl?: ElementRef<HTMLElement>;

  readonly titleId = `confirm-dialog-title-${Date.now()}`;
  inputValue = '';
  inputError = '';
  animating = true;

  private previousFocus: HTMLElement | null = null;
  private keydownHandler = (e: KeyboardEvent) => this.onKeydown(e);

  get isDestructive(): boolean {
    return (
      this.variant === 'destructive-type-to-confirm' ||
      this.variant === 'destructive-simple' ||
      this.variant === 'warning'
    );
  }

  get isConfirmEnabled(): boolean {
    if (this.loading) return false;
    if (this.variant === 'create') {
      return this.inputValue.trim().length > 0 && !this.inputError;
    }
    if (this.variant === 'destructive-type-to-confirm') {
      return this.inputValue === this.confirmValue;
    }
    return true; // destructive-simple, warning
  }

  ngOnInit(): void {
    this.previousFocus = document.activeElement as HTMLElement;
    document.addEventListener('keydown', this.keydownHandler);
    requestAnimationFrame(() => { this.animating = false; });
  }

  ngAfterViewInit(): void {
    // Focus is handled by cdkTrapFocusAutoCapture
  }

  ngOnDestroy(): void {
    document.removeEventListener('keydown', this.keydownHandler);
    if (this.previousFocus && typeof this.previousFocus.focus === 'function') {
      this.previousFocus.focus();
    }
  }

  onInputChange(value: string): void {
    this.inputValue = value;
    if (this.variant === 'create') {
      this.validateCreateInput(value);
    }
  }

  onConfirm(): void {
    if (!this.isConfirmEnabled) return;
    this.confirm.emit(this.inputValue);
  }

  onCancel(): void {
    this.cancel.emit();
  }

  onBackdropClick(event: MouseEvent): void {
    if (event.target === event.currentTarget) {
      this.cancel.emit();
    }
  }

  private onKeydown(event: KeyboardEvent): void {
    if (event.key === 'Escape') {
      event.preventDefault();
      this.cancel.emit();
    }
  }

  private validateCreateInput(value: string): void {
    if (!value) {
      this.inputError = '';
      return;
    }
    // CouchDB naming rules: ^[a-z][a-z0-9_$()+/-]*$
    const pattern = /^[a-z][a-z0-9_$()+\-/]*$/;
    if (!pattern.test(value)) {
      if (/^[^a-z]/.test(value)) {
        this.inputError = 'Must start with a lowercase letter';
      } else {
        this.inputError = 'Only lowercase letters, digits, and _$()+-/ allowed';
      }
    } else {
      this.inputError = '';
    }
  }
}
