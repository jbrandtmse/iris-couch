import {
  Component,
  Input,
  Output,
  EventEmitter,
  OnDestroy,
  ChangeDetectionStrategy,
  ChangeDetectorRef,
} from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';

let nextId = 0;

/**
 * Validity payload emitted by `TextAreaJsonComponent.validityChange`.
 *
 * `valid: true` means `JSON.parse(value)` succeeded. When false, the
 * `errorMessage` field carries the human-readable validation error in the
 * shape `"Invalid JSON at line N"`.
 */
export interface TextAreaJsonValidity {
  valid: boolean;
  errorMessage?: string;
}

/**
 * Compute the 1-based line number where a JSON parse error occurred.
 *
 * V8/Chrome `JSON.parse` errors typically include a `at position N` substring
 * in `error.message`. We extract that position and count `\n` characters in
 * `input` up to that index to derive the line. When the position cannot be
 * recovered (Firefox uses a `at line:column` format; Safari may emit yet a
 * different shape), we fall back to a regex match on `line N` then to line 1.
 *
 * Exposed as a top-level helper for testability.
 */
export function jsonErrorLine(input: string, error: unknown): number {
  if (!(error instanceof Error)) return 1;
  const msg = error.message || '';

  // V8 / Chrome / Node: "Unexpected token x in JSON at position 42"
  // V8 newer:           "Expected ',' or '}' after property value in JSON at position 42 (line 3 column 12)"
  const positionMatch = /at position (\d+)/i.exec(msg);
  if (positionMatch) {
    const pos = Math.min(Number(positionMatch[1]), input.length);
    let line = 1;
    for (let i = 0; i < pos; i++) {
      if (input.charCodeAt(i) === 10 /* '\n' */) line++;
    }
    return line;
  }

  // Newer V8 / Chrome 117+ also embeds "(line N column M)"
  const lineColMatch = /line (\d+)/i.exec(msg);
  if (lineColMatch) return Math.max(1, Number(lineColMatch[1]));

  // Firefox: "JSON.parse: ... at line 3 column 12 of the JSON data"
  // Safari: "JSON Parse error: Unexpected EOF" (no position info -> default to 1)
  return 1;
}

/**
 * CouchUI TextAreaJson component.
 *
 * A monospace, resizable textarea for editing JSON with inline validation.
 * Renders a sibling line-numbers gutter that scrolls in sync with the
 * textarea content. Emits `valueChange` for two-way binding and
 * `validityChange` whenever the JSON parse-state changes (debounced).
 *
 * Visual states (border + focus ring tokens, no inline rgba()):
 *   default  -- border `--color-neutral-200`
 *   focus    -- border `--color-info` + `--focus-ring-info`
 *   disabled -- opacity 0.5, cursor not-allowed
 *   invalid  -- border `--color-danger` + `--focus-ring-danger`
 *
 * Accessibility: real `<label for="{id}">{label}</label>`, `spellcheck="false"`
 * to avoid red squiggles in code, `aria-describedby` points at the inline
 * error element when invalid, `aria-invalid="true"` while invalid.
 *
 * Story 11.3 AC #1.
 *
 * Usage:
 *   <app-text-area-json
 *     label="Document body"
 *     [(value)]="json"
 *     (validityChange)="onValidity($event)">
 *   </app-text-area-json>
 */
@Component({
  selector: 'app-text-area-json',
  standalone: true,
  imports: [CommonModule, FormsModule],
  changeDetection: ChangeDetectionStrategy.Default,
  template: `
    <div class="ta-json">
      <label [for]="textareaId" class="ta-json__label">{{ label }}</label>

      <div
        class="ta-json__shell"
        [class.ta-json__shell--focused]="focused"
        [class.ta-json__shell--invalid]="!!internalErrorMessage"
        [class.ta-json__shell--disabled]="disabled">
        <pre
          class="ta-json__gutter"
          aria-hidden="true"
          #gutterEl>{{ gutterText }}</pre>
        <textarea
          #textareaEl
          [id]="textareaId"
          class="ta-json__textarea"
          spellcheck="false"
          autocomplete="off"
          autocorrect="off"
          autocapitalize="off"
          [rows]="rows"
          [placeholder]="placeholder"
          [attr.disabled]="disabled ? '' : null"
          [attr.aria-invalid]="internalErrorMessage ? 'true' : null"
          [attr.aria-describedby]="internalErrorMessage ? errorId : null"
          [ngModel]="value"
          (ngModelChange)="onValueChange($event)"
          (focus)="focused = true"
          (blur)="focused = false"
          (scroll)="syncGutterScroll()"></textarea>
      </div>

      <span
        *ngIf="internalErrorMessage"
        [id]="errorId"
        class="ta-json__error"
        role="status">
        {{ internalErrorMessage }}
      </span>
    </div>
  `,
  styles: [`
    :host {
      display: block;
    }

    .ta-json {
      display: flex;
      flex-direction: column;
      gap: 2px;
    }

    .ta-json__label {
      font-size: var(--font-size-sm);
      line-height: var(--line-height-sm);
      font-weight: 500;
      color: var(--color-neutral-700);
    }

    .ta-json__shell {
      position: relative;
      display: grid;
      grid-template-columns: auto 1fr;
      align-items: stretch;
      border: 1px solid var(--color-neutral-200);
      border-radius: var(--border-radius);
      background-color: var(--color-neutral-0);
      overflow: hidden;
      transition: border-color 0.15s ease, box-shadow 0.15s ease;
      min-height: 80px;
    }

    .ta-json__shell--focused {
      border-color: var(--color-info);
      box-shadow: var(--focus-ring-info);
    }

    .ta-json__shell--invalid {
      border-color: var(--color-danger);
    }

    .ta-json__shell--invalid.ta-json__shell--focused {
      box-shadow: var(--focus-ring-danger);
    }

    .ta-json__shell--disabled {
      opacity: 0.5;
      cursor: not-allowed;
    }

    .ta-json__gutter {
      margin: 0;
      padding: var(--space-3) var(--space-2);
      min-width: 2.75em;
      max-width: 4em;
      text-align: right;
      font-family: var(--font-mono);
      font-size: var(--font-size-sm);
      line-height: var(--line-height-sm);
      color: var(--color-neutral-600);
      background-color: var(--color-neutral-50);
      border-right: 1px solid var(--color-neutral-200);
      user-select: none;
      -webkit-user-select: none;
      white-space: pre;
      overflow: hidden;
      pointer-events: none;
    }

    .ta-json__textarea {
      box-sizing: border-box;
      width: 100%;
      padding: var(--space-3);
      font-family: var(--font-mono);
      font-size: var(--font-size-sm);
      line-height: var(--line-height-sm);
      color: var(--color-neutral-900);
      background-color: var(--color-neutral-0);
      border: none;
      outline: none;
      resize: vertical;
      tab-size: 2;
      -moz-tab-size: 2;
      white-space: pre;
      overflow: auto;
    }

    .ta-json__textarea:disabled {
      cursor: not-allowed;
      background-color: var(--color-neutral-50);
    }

    .ta-json__textarea::placeholder {
      color: var(--color-neutral-400);
    }

    .ta-json__error {
      font-size: var(--font-size-xs);
      line-height: var(--line-height-xs);
      color: var(--color-error-fg);
    }

    @media (prefers-reduced-motion: reduce) {
      .ta-json__shell {
        transition: none;
      }
    }
  `],
})
export class TextAreaJsonComponent implements OnDestroy {
  @Input({ required: true }) label!: string;
  @Input() id?: string;
  @Input() placeholder = '';
  @Input() rows = 20;
  @Input() disabled = false;

  /** Optional caller-provided error message overlay (e.g., from a backend
   *  validation response). When set, takes precedence over the internal
   *  parse-validation message. */
  @Input() errorMessage?: string;

  @Input()
  set value(v: string) {
    if (v === this._value) return;
    this._value = v ?? '';
    this.scheduleValidate(this._value);
  }
  get value(): string {
    return this._value;
  }

  @Output() valueChange = new EventEmitter<string>();
  @Output() validityChange = new EventEmitter<TextAreaJsonValidity>();

  focused = false;

  /** Internal validation message derived from JSON.parse failures. */
  parseErrorMessage: string | null = null;

  private _value = '';
  private debounceHandle: number | null = null;
  private lastEmittedValid: boolean | null = null;
  private readonly _uid = `text-area-json-${nextId++}`;

  constructor(private readonly cdr: ChangeDetectorRef) {}

  /** Reactive gutter text -- one line-number per textarea row. */
  get gutterText(): string {
    const lines = this._value.split('\n').length;
    let s = '';
    for (let i = 1; i <= lines; i++) {
      s += i + (i < lines ? '\n' : '');
    }
    return s;
  }

  /** Resolve the active error message (caller override beats parse error). */
  get internalErrorMessage(): string | null {
    if (this.errorMessage) return this.errorMessage;
    return this.parseErrorMessage;
  }

  get textareaId(): string {
    return this.id || this._uid;
  }

  get errorId(): string {
    return `${this.textareaId}-err`;
  }

  ngOnDestroy(): void {
    if (this.debounceHandle != null) {
      clearTimeout(this.debounceHandle);
      this.debounceHandle = null;
    }
  }

  onValueChange(newValue: string): void {
    this._value = newValue;
    this.valueChange.emit(newValue);
    this.scheduleValidate(newValue);
  }

  /**
   * Keep the gutter scrolled in sync with the textarea content. Without this,
   * scrolling a long body in the textarea would leave the line numbers stuck
   * at the top.
   *
   * Implementation note: bound directly to the (scroll) event for simplicity.
   * The pure-CSS overflow:hidden + pointer-events:none on the gutter means
   * the gutter never scrolls on its own.
   */
  syncGutterScroll(): void {
    // Read scrollTop from the textarea element via querySelector; cheap.
    // Use a try/catch in case the elements aren't yet in the DOM.
    try {
      const ta: HTMLTextAreaElement | null = (document.getElementById(this.textareaId) as HTMLTextAreaElement | null);
      const gutter = ta?.parentElement?.querySelector('.ta-json__gutter') as HTMLElement | null;
      if (ta && gutter) {
        gutter.scrollTop = ta.scrollTop;
      }
    } catch {
      /* noop -- gutter scroll sync is best-effort */
    }
  }

  /** Debounced validation. 150ms delay matches the task spec. */
  private scheduleValidate(value: string): void {
    if (this.debounceHandle != null) {
      clearTimeout(this.debounceHandle);
    }
    this.debounceHandle = window.setTimeout(() => {
      this.debounceHandle = null;
      this.validateNow(value);
      this.cdr.markForCheck();
    }, 150);
  }

  private validateNow(value: string): void {
    if (value === '') {
      // Empty input is treated as invalid (no JSON document) but we do not
      // surface a parse error -- the shell only reflects "invalid" once the
      // user has typed something. Match TextInput's "no error until dirty".
      this.parseErrorMessage = null;
      this.emitValidity(false);
      return;
    }
    try {
      JSON.parse(value);
      this.parseErrorMessage = null;
      this.emitValidity(true);
    } catch (e) {
      const line = jsonErrorLine(value, e);
      this.parseErrorMessage = `Invalid JSON at line ${line}`;
      this.emitValidity(false, this.parseErrorMessage);
    }
  }

  private emitValidity(valid: boolean, errorMessage?: string): void {
    if (this.lastEmittedValid === valid && !errorMessage) return;
    this.lastEmittedValid = valid;
    this.validityChange.emit({ valid, errorMessage });
  }
}
