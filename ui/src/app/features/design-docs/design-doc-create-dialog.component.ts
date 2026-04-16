import {
  Component,
  Input,
  Output,
  EventEmitter,
  OnInit,
  OnDestroy,
} from '@angular/core';
import { CommonModule } from '@angular/common';
import { A11yModule } from '@angular/cdk/a11y';
import { TextInputComponent } from '../../couch-ui/text-input/text-input.component';
import { ButtonComponent } from '../../couch-ui/button/button.component';
import { ErrorDisplayComponent } from '../../couch-ui/error-display/error-display.component';
import {
  TextAreaJsonComponent,
  TextAreaJsonValidity,
} from '../../couch-ui/text-area-json/text-area-json.component';

/**
 * Default body inserted into the editor for a new design document. Matches
 * the minimal "JS view" template shape used throughout the CouchDB docs.
 */
const DEFAULT_BODY = `{
  "language": "javascript",
  "views": {}
}`;

/**
 * Design-doc create dialog.
 *
 * Composite dialog: short-name input + JSON body textarea. Lives in the
 * design-docs feature folder rather than couch-ui because it embeds
 * domain knowledge (the design-doc body template + validation pattern).
 *
 * Story 11.3 Task 3 / AC #3.
 *
 * Usage:
 *   <app-design-doc-create-dialog
 *     *ngIf="showCreate"
 *     [existingNames]="existingNames"
 *     [serverError]="createError"
 *     [serverErrorCode]="createErrorCode"
 *     [loading]="creating"
 *     (create)="onCreateConfirmed($event)"
 *     (cancel)="showCreate = false">
 *   </app-design-doc-create-dialog>
 */
@Component({
  selector: 'app-design-doc-create-dialog',
  standalone: true,
  imports: [
    CommonModule,
    A11yModule,
    TextInputComponent,
    ButtonComponent,
    ErrorDisplayComponent,
    TextAreaJsonComponent,
  ],
  template: `
    <div class="dialog-backdrop" (click)="onBackdropClick($event)">
      <div
        class="dialog"
        role="dialog"
        aria-modal="true"
        [attr.aria-labelledby]="titleId"
        cdkTrapFocus
        cdkTrapFocusAutoCapture>

        <h2 [id]="titleId" class="dialog__title">Create design document</h2>

        <div class="dialog__field">
          <app-text-input
            label="Design document name"
            hint="Lowercase letters, digits, hyphen, underscore"
            [error]="nameError"
            [value]="nameValue"
            (valueChange)="onNameChange($event)"
            [mono]="true">
          </app-text-input>
        </div>

        <div class="dialog__field">
          <app-text-area-json
            label="Document body"
            [(value)]="bodyValue"
            (validityChange)="onBodyValidity($event)"
            [rows]="14">
          </app-text-area-json>
        </div>

        <div *ngIf="serverError" class="dialog__error">
          <app-error-display
            [error]="serverError"
            [statusCode]="serverErrorCode"
            variant="inline">
          </app-error-display>
        </div>

        <div class="dialog__actions">
          <app-button variant="ghost" (click)="onCancel()">Cancel</app-button>
          <app-button
            variant="primary"
            [disabled]="!isCreateEnabled"
            [loading]="loading"
            (click)="onCreate()">
            Create
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
      width: 640px;
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
    }

    .dialog__title {
      font-size: var(--font-size-lg);
      line-height: var(--line-height-lg);
      font-weight: 600;
      color: var(--color-neutral-800);
      margin: 0;
    }

    .dialog__field {
      display: flex;
      flex-direction: column;
      gap: var(--space-2);
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
  `],
})
export class DesignDocCreateDialogComponent implements OnInit, OnDestroy {
  /** Existing design-doc short names (without `_design/` prefix) used to
   *  surface a duplicate-name error before the network round-trip. */
  @Input() existingNames: string[] = [];
  @Input() serverError?: { error: string; reason: string };
  @Input() serverErrorCode?: number;
  @Input() loading = false;

  @Output() create = new EventEmitter<{ name: string; body: unknown }>();
  @Output() cancel = new EventEmitter<void>();

  readonly titleId = `ddoc-create-title-${Date.now()}`;

  nameValue = '';
  nameError = '';
  bodyValue = DEFAULT_BODY;
  bodyValid = true;

  private previousFocus: HTMLElement | null = null;
  private keydownHandler = (e: KeyboardEvent) => this.onKeydown(e);

  get isCreateEnabled(): boolean {
    if (this.loading) return false;
    if (!this.nameValue || this.nameError) return false;
    if (!this.bodyValid) return false;
    return true;
  }

  ngOnInit(): void {
    this.previousFocus = document.activeElement as HTMLElement;
    document.addEventListener('keydown', this.keydownHandler);
  }

  ngOnDestroy(): void {
    document.removeEventListener('keydown', this.keydownHandler);
    if (this.previousFocus && typeof this.previousFocus.focus === 'function') {
      this.previousFocus.focus();
    }
  }

  onNameChange(v: string): void {
    this.nameValue = v;
    this.nameError = this.validateName(v);
  }

  onBodyValidity(v: TextAreaJsonValidity): void {
    this.bodyValid = v.valid;
  }

  onCreate(): void {
    if (!this.isCreateEnabled) return;
    let body: unknown;
    try {
      body = JSON.parse(this.bodyValue);
    } catch {
      this.bodyValid = false;
      return;
    }
    this.create.emit({ name: this.nameValue.trim(), body });
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

  /**
   * CouchDB design-doc short-name rules (per the spec): the segment after
   * `_design/` must satisfy the same naming rules as a regular doc id but
   * cannot be empty. We narrow further to the conservative subset the
   * Story 11.3 spec calls out: lowercase letters, digits, hyphen, underscore.
   */
  private validateName(v: string): string {
    if (!v) return '';
    if (this.existingNames.includes(v)) {
      return `Design doc "${v}" already exists`;
    }
    if (!/^[a-z0-9_-]+$/.test(v)) {
      return 'Only lowercase letters, digits, hyphen, underscore allowed';
    }
    return '';
  }
}
