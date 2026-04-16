import { TestBed, ComponentFixture, fakeAsync, tick } from '@angular/core/testing';
import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import {
  TextAreaJsonComponent,
  TextAreaJsonValidity,
  jsonErrorLine,
} from './text-area-json.component';
import { expectNoAxeViolations } from '../test-utils';

@Component({
  standalone: true,
  imports: [CommonModule, TextAreaJsonComponent],
  template: `
    <app-text-area-json
      [label]="label"
      [disabled]="disabled"
      [errorMessage]="errorMessage"
      [placeholder]="placeholder"
      [rows]="rows"
      [(value)]="value"
      (validityChange)="onValidity($event)">
    </app-text-area-json>
  `,
})
class TestHost {
  label = 'Document body';
  disabled = false;
  errorMessage?: string;
  placeholder = '';
  rows = 10;
  value = '';
  lastValidity?: TextAreaJsonValidity;
  onValidity(v: TextAreaJsonValidity): void {
    this.lastValidity = v;
  }
}

describe('TextAreaJsonComponent', () => {
  let fixture: ComponentFixture<TestHost>;
  let host: TestHost;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [TestHost],
    }).compileComponents();
    fixture = TestBed.createComponent(TestHost);
    host = fixture.componentInstance;
    fixture.detectChanges();
  });

  function getLabel(): HTMLLabelElement {
    return fixture.nativeElement.querySelector('label.ta-json__label');
  }
  function getTextarea(): HTMLTextAreaElement {
    return fixture.nativeElement.querySelector('textarea.ta-json__textarea');
  }
  function getShell(): HTMLElement {
    return fixture.nativeElement.querySelector('.ta-json__shell');
  }
  function getGutter(): HTMLElement {
    return fixture.nativeElement.querySelector('.ta-json__gutter');
  }
  function getError(): HTMLElement | null {
    return fixture.nativeElement.querySelector('.ta-json__error');
  }

  it('renders a real <label> bound to the textarea via for/id', () => {
    expect(getLabel()).toBeTruthy();
    expect(getLabel().getAttribute('for')).toBe(getTextarea().id);
    expect(getLabel().textContent?.trim()).toBe('Document body');
  });

  it('renders a textarea with spellcheck="false" and monospace styling', () => {
    const ta = getTextarea();
    expect(ta).toBeTruthy();
    expect(ta.getAttribute('spellcheck')).toBe('false');
    // Monospace is enforced via the shared `--font-mono` token at the CSS level;
    // verify the element receives the textarea class that consumes that token.
    expect(ta.classList).toContain('ta-json__textarea');
  });

  it('renders a line-numbers gutter sibling', () => {
    expect(getGutter()).toBeTruthy();
    // Default empty value -> 1 line in the gutter
    expect(getGutter().textContent?.trim()).toBe('1');
  });

  it('grows the gutter to match line count', fakeAsync(() => {
    host.value = 'line1\nline2\nline3';
    fixture.detectChanges();
    tick(200);
    fixture.detectChanges();
    const lines = getGutter().textContent?.split('\n').filter((s) => s.length) ?? [];
    expect(lines).toEqual(['1', '2', '3']);
  }));

  describe('visual states', () => {
    it('renders default state with no focused/invalid/disabled classes', () => {
      const shell = getShell();
      expect(shell.classList).not.toContain('ta-json__shell--focused');
      expect(shell.classList).not.toContain('ta-json__shell--invalid');
      expect(shell.classList).not.toContain('ta-json__shell--disabled');
    });

    it('applies focused class on textarea focus', () => {
      const ta = getTextarea();
      ta.dispatchEvent(new Event('focus'));
      fixture.detectChanges();
      expect(getShell().classList).toContain('ta-json__shell--focused');
    });

    it('applies disabled class and disables textarea when disabled=true', () => {
      host.disabled = true;
      fixture.detectChanges();
      expect(getShell().classList).toContain('ta-json__shell--disabled');
      expect(getTextarea().disabled).toBeTrue();
    });

    it('applies invalid class when JSON cannot be parsed', fakeAsync(() => {
      host.value = '{not json';
      fixture.detectChanges();
      tick(200);
      fixture.detectChanges();
      expect(getShell().classList).toContain('ta-json__shell--invalid');
      expect(getTextarea().getAttribute('aria-invalid')).toBe('true');
    }));
  });

  describe('validation', () => {
    it('emits validityChange{valid:true} for valid JSON', fakeAsync(() => {
      host.value = '{"a": 1}';
      fixture.detectChanges();
      tick(200);
      fixture.detectChanges();
      expect(host.lastValidity?.valid).toBeTrue();
      expect(host.lastValidity?.errorMessage).toBeUndefined();
    }));

    it('emits validityChange{valid:false} with line-number message for invalid JSON', fakeAsync(() => {
      // Multi-line invalid JSON where the error is on line 2.
      host.value = '{\n  "a": 1,,\n}';
      fixture.detectChanges();
      tick(200);
      fixture.detectChanges();
      expect(host.lastValidity?.valid).toBeFalse();
      expect(host.lastValidity?.errorMessage).toMatch(/^Invalid JSON at line \d+$/);
    }));

    it('shows the inline error message under the textarea on invalid JSON', fakeAsync(() => {
      host.value = '{bad}';
      fixture.detectChanges();
      tick(200);
      fixture.detectChanges();
      const err = getError();
      expect(err).toBeTruthy();
      expect(err?.textContent?.trim()).toMatch(/^Invalid JSON at line \d+$/);
    }));

    it('clears the error message when JSON becomes valid again', fakeAsync(() => {
      host.value = '{bad}';
      fixture.detectChanges();
      tick(200);
      fixture.detectChanges();
      expect(getError()).toBeTruthy();
      host.value = '{"ok": true}';
      fixture.detectChanges();
      tick(200);
      fixture.detectChanges();
      expect(getError()).toBeNull();
    }));

    it('debounces validation by 150ms', fakeAsync(() => {
      host.value = '{bad}';
      fixture.detectChanges();
      tick(50);
      fixture.detectChanges();
      // Before the debounce completes, the error has not yet rendered.
      expect(getError()).toBeNull();
      tick(120);
      fixture.detectChanges();
      expect(getError()).toBeTruthy();
    }));

    it('honors caller-provided errorMessage as override', () => {
      host.errorMessage = 'Server says no';
      fixture.detectChanges();
      const err = getError();
      expect(err?.textContent?.trim()).toBe('Server says no');
      expect(getShell().classList).toContain('ta-json__shell--invalid');
    });

    it('aria-describedby points at the error span when invalid', fakeAsync(() => {
      host.value = '{bad}';
      fixture.detectChanges();
      tick(200);
      fixture.detectChanges();
      const ta = getTextarea();
      const err = getError();
      expect(err).toBeTruthy();
      expect(ta.getAttribute('aria-describedby')).toBe(err!.id);
    }));
  });

  describe('jsonErrorLine helper', () => {
    it('returns 1 for non-Error inputs', () => {
      expect(jsonErrorLine('', 'oops')).toBe(1);
    });

    it('extracts line from "at position N" V8 message', () => {
      // Construct a real parse error so message format matches V8.
      try {
        JSON.parse('{\n  "a": 1,,\n  "b": 2\n}');
        fail('Should have thrown');
      } catch (e) {
        const line = jsonErrorLine('{\n  "a": 1,,\n  "b": 2\n}', e);
        // Error should point to the second `,` on line 2.
        expect(line).toBeGreaterThanOrEqual(2);
      }
    });

    it('falls back to line 1 when no position info is present', () => {
      expect(jsonErrorLine('input', new Error('something else'))).toBe(1);
    });

    it('handles "line N column M" format', () => {
      expect(jsonErrorLine('input', new Error('JSON.parse: trailing comma at line 4 column 2'))).toBe(4);
    });
  });

  describe('two-way binding', () => {
    it('updates host value when textarea content changes', () => {
      const ta = getTextarea();
      ta.value = '{"x": 9}';
      ta.dispatchEvent(new Event('input'));
      fixture.detectChanges();
      expect(host.value).toBe('{"x": 9}');
    });
  });

  describe('accessibility', () => {
    it('passes axe-core in default state', async () => {
      await expectNoAxeViolations(fixture.nativeElement);
    });

    it('passes axe-core in invalid state', async () => {
      host.value = '{bad}';
      fixture.detectChanges();
      // Wait for the 150ms validation debounce in real time -- mixing
      // fakeAsync with axe-core's Promise-based runner triggers
      // "Axe is already running" / "timer(s) still in queue" issues.
      await new Promise((r) => setTimeout(r, 200));
      fixture.detectChanges();
      await expectNoAxeViolations(fixture.nativeElement);
    });

    it('passes axe-core in disabled state', async () => {
      host.disabled = true;
      fixture.detectChanges();
      await expectNoAxeViolations(fixture.nativeElement);
    });
  });
});
