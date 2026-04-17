import { Component, Input, OnChanges } from '@angular/core';
import { CommonModule } from '@angular/common';
import { CopyButtonComponent } from '../copy-button/copy-button.component';

/** A single token produced by the JSON tokenizer. */
interface JsonToken {
  type: 'key' | 'string' | 'number' | 'boolean' | 'null' | 'punctuation';
  text: string;
}

/** A single line of tokenized JSON. */
interface JsonLine {
  lineNumber: number;
  tokens: JsonToken[];
}

/**
 * CouchUI JsonDisplay component.
 *
 * Renders a read-only, pretty-printed JSON body with palette-based
 * syntax coloring, non-selectable line numbers, and a "Copy raw JSON"
 * button strip above.
 *
 * Uses a tiny custom tokenizer -- no external syntax highlighting
 * library (Prism, Highlight.js, etc.) is used.
 *
 * Usage:
 *   <app-json-display [json]="rawJsonString"></app-json-display>
 */
@Component({
  selector: 'app-json-display',
  standalone: true,
  imports: [CommonModule, CopyButtonComponent],
  template: `
    <div class="json-display__toolbar">
      <app-copy-button
        [value]="json"
        variant="block"
        ariaLabel="Copy raw JSON">
      </app-copy-button>
    </div>
    <div
      class="json-display"
      role="textbox"
      aria-readonly="true"
      aria-label="Document JSON"
      tabindex="0">
      <div
        *ngFor="let line of lines; trackBy: trackByLine"
        class="json-display__line">
        <span class="json-display__line-number">{{ line.lineNumber }}</span>
        <span class="json-display__content">
          <ng-container *ngFor="let token of line.tokens">
            <span [class]="'json-token json-token--' + token.type">{{ token.text }}</span>
          </ng-container>
        </span>
      </div>
    </div>
  `,
  styles: [`
    :host {
      display: block;
    }

    .json-display__toolbar {
      display: flex;
      justify-content: flex-end;
      padding-bottom: var(--space-2);
    }

    .json-display {
      font-family: var(--font-mono);
      font-size: var(--font-size-sm);
      line-height: var(--line-height-sm);
      background-color: var(--color-neutral-50);
      border: 1px solid var(--color-neutral-200);
      border-radius: var(--border-radius);
      padding: var(--space-3);
      overflow-x: auto;
      white-space: pre;
    }

    .json-display:focus-visible {
      outline: 2px solid var(--color-info);
      outline-offset: 2px;
    }

    .json-display__line {
      display: flex;
      gap: var(--space-3);
    }

    .json-display__line-number {
      display: inline-block;
      min-width: 2.5em;
      text-align: right;
      /* Story 12.0: bumped from --color-neutral-400 (#9096A1, 2.79:1 on
         --color-neutral-50) to --color-neutral-600 (#4B5260, ~7.2:1) to
         meet WCAG AA for any line-numbered body. */
      color: var(--color-neutral-600);
      user-select: none;
      -webkit-user-select: none;
      flex-shrink: 0;
    }

    .json-display__content {
      flex: 1;
    }

    /* Syntax coloring using design tokens */
    .json-token--key {
      color: var(--color-neutral-700);
    }

    .json-token--string {
      color: var(--color-neutral-900);
    }

    .json-token--number {
      color: var(--color-neutral-800);
    }

    .json-token--boolean {
      color: var(--color-info);
    }

    .json-token--null {
      color: var(--color-info);
    }

    .json-token--punctuation {
      color: var(--color-neutral-500);
    }
  `]
})
export class JsonDisplayComponent implements OnChanges {
  @Input({ required: true }) json!: string;

  lines: JsonLine[] = [];
  prettyJson = '';

  ngOnChanges(): void {
    this.tokenize();
  }

  trackByLine(_index: number, line: JsonLine): number {
    return line.lineNumber;
  }

  /**
   * Parse and pretty-print the JSON, then tokenize each line
   * for syntax coloring. Uses JSON.stringify(JSON.parse(...), null, 2)
   * to ensure 2-space indent with no key reordering.
   */
  private tokenize(): void {
    if (!this.json) {
      this.prettyJson = '';
      this.lines = [{ lineNumber: 1, tokens: [] }];
      return;
    }

    try {
      const parsed = JSON.parse(this.json);
      this.prettyJson = JSON.stringify(parsed, null, 2);
    } catch {
      // If JSON is invalid, display raw text
      this.prettyJson = this.json;
    }

    const rawLines = this.prettyJson.split('\n');
    this.lines = rawLines.map((text, index) => ({
      lineNumber: index + 1,
      tokens: this.tokenizeLine(text),
    }));
  }

  /**
   * Tiny custom tokenizer for a single line of pretty-printed JSON.
   * Produces spans for keys, strings, numbers, booleans, null, and punctuation.
   */
  private tokenizeLine(line: string): JsonToken[] {
    const tokens: JsonToken[] = [];
    let i = 0;

    while (i < line.length) {
      const ch = line[i];

      // Whitespace -- preserve as punctuation
      if (ch === ' ' || ch === '\t') {
        let ws = '';
        while (i < line.length && (line[i] === ' ' || line[i] === '\t')) {
          ws += line[i];
          i++;
        }
        tokens.push({ type: 'punctuation', text: ws });
        continue;
      }

      // String (could be key or value)
      if (ch === '"') {
        const str = this.readString(line, i);
        i += str.length;

        // Determine if this is a key or a value.
        // A key is followed (possibly with whitespace) by ':'
        const rest = line.substring(i).trimStart();
        if (rest.startsWith(':')) {
          tokens.push({ type: 'key', text: str });
        } else {
          tokens.push({ type: 'string', text: str });
        }
        continue;
      }

      // Number
      if (ch === '-' || (ch >= '0' && ch <= '9')) {
        let num = '';
        while (i < line.length && /[0-9eE.\-+]/.test(line[i])) {
          num += line[i];
          i++;
        }
        tokens.push({ type: 'number', text: num });
        continue;
      }

      // Boolean: true
      if (line.substring(i, i + 4) === 'true') {
        tokens.push({ type: 'boolean', text: 'true' });
        i += 4;
        continue;
      }

      // Boolean: false
      if (line.substring(i, i + 5) === 'false') {
        tokens.push({ type: 'boolean', text: 'false' });
        i += 5;
        continue;
      }

      // Null
      if (line.substring(i, i + 4) === 'null') {
        tokens.push({ type: 'null', text: 'null' });
        i += 4;
        continue;
      }

      // Punctuation (braces, brackets, colon, comma)
      tokens.push({ type: 'punctuation', text: ch });
      i++;
    }

    return tokens;
  }

  /**
   * Read a JSON string starting at position i (which must be '"').
   * Handles escape sequences.
   */
  private readString(line: string, start: number): string {
    let i = start + 1; // skip opening quote
    while (i < line.length) {
      if (line[i] === '\\') {
        i += 2; // skip escape sequence
        continue;
      }
      if (line[i] === '"') {
        i++; // include closing quote
        break;
      }
      i++;
    }
    return line.substring(start, i);
  }
}
