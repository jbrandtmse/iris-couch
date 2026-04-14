import { Component, Input, Output, EventEmitter } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';

let nextId = 0;

/**
 * CouchUI TextInput component.
 *
 * Wraps a native `<input>` at 32px height with a real `<label>` above.
 * Supports hint text, error state, disabled state, and monospace font.
 *
 * Usage:
 *   <app-text-input
 *     label="Database Name"
 *     hint="Lowercase letters, digits, dashes"
 *     [(value)]="dbName">
 *   </app-text-input>
 */
@Component({
  selector: 'app-text-input',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div class="text-input">
      <label [for]="inputId" class="text-input__label">{{ label }}</label>
      <input
        [id]="inputId"
        [type]="type"
        class="text-input__field"
        [class.text-input__field--mono]="mono"
        [class.text-input__field--error]="!!error"
        [placeholder]="placeholder"
        [attr.disabled]="disabled ? '' : null"
        [attr.aria-invalid]="error ? 'true' : null"
        [attr.aria-describedby]="(hint || error) ? descriptionId : null"
        [ngModel]="value"
        (ngModelChange)="onValueChange($event)" />
      <span
        *ngIf="error || hint"
        [id]="descriptionId"
        class="text-input__hint"
        [class.text-input__hint--error]="!!error">
        {{ error || hint }}
      </span>
    </div>
  `,
  styles: [`
    :host {
      display: block;
    }

    .text-input {
      display: flex;
      flex-direction: column;
      gap: 2px;
    }

    .text-input__label {
      font-size: var(--font-size-sm);
      line-height: var(--line-height-sm);
      font-weight: 500;
      color: var(--color-neutral-700);
    }

    .text-input__field {
      height: 32px;
      padding: 0 12px;
      font-size: var(--font-size-sm);
      line-height: var(--line-height-sm);
      color: var(--color-neutral-800);
      background-color: var(--color-neutral-0);
      border: 1px solid var(--color-neutral-200);
      border-radius: var(--border-radius);
      transition: border-color 0.15s ease, box-shadow 0.15s ease;
    }

    .text-input__field--mono {
      font-family: var(--font-mono);
    }

    .text-input__field::placeholder {
      color: var(--color-neutral-400);
    }

    .text-input__field:focus {
      outline: none;
      border-color: var(--color-info);
      box-shadow: 0 0 0 2px rgba(60, 90, 158, 0.1);
    }

    .text-input__field:focus-visible {
      outline: 2px solid var(--color-info);
      outline-offset: 3px;
    }

    .text-input__field:disabled {
      opacity: 0.5;
      cursor: not-allowed;
    }

    .text-input__field--error {
      border-color: var(--color-error);
    }

    .text-input__field--error:focus {
      border-color: var(--color-error);
      box-shadow: 0 0 0 2px rgba(195, 63, 63, 0.1);
    }

    .text-input__hint {
      font-size: var(--font-size-xs);
      line-height: var(--line-height-xs);
      color: var(--color-neutral-500);
    }

    .text-input__hint--error {
      color: var(--color-error);
    }

    @media (prefers-reduced-motion: reduce) {
      .text-input__field {
        transition: none;
      }
    }
  `]
})
export class TextInputComponent {
  @Input({ required: true }) label!: string;
  @Input() id?: string;
  @Input() placeholder = '';
  @Input() hint?: string;
  @Input() error?: string;
  @Input() disabled = false;
  @Input() mono = true;
  @Input() type: 'text' | 'password' = 'text';
  @Input() value = '';
  @Output() valueChange = new EventEmitter<string>();

  private readonly _uid = `text-input-${nextId++}`;

  get inputId(): string {
    return this.id || this._uid;
  }

  get descriptionId(): string {
    return `${this.inputId}-desc`;
  }

  onValueChange(newValue: string): void {
    this.value = newValue;
    this.valueChange.emit(newValue);
  }
}
