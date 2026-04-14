import { TestBed, ComponentFixture } from '@angular/core/testing';
import { Component } from '@angular/core';
import { TextInputComponent } from './text-input.component';
import { expectNoAxeViolations } from '../test-utils';

@Component({
  standalone: true,
  imports: [TextInputComponent],
  template: `
    <app-text-input
      [label]="label"
      [hint]="hint"
      [error]="error"
      [disabled]="disabled"
      [mono]="mono"
      [placeholder]="placeholder"
      [(value)]="value">
    </app-text-input>
  `,
})
class TestHost {
  label = 'Database Name';
  hint?: string;
  error?: string;
  disabled = false;
  mono = true;
  placeholder = '';
  value = '';
}

describe('TextInputComponent', () => {
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
    return fixture.nativeElement.querySelector('label');
  }

  function getInput(): HTMLInputElement {
    return fixture.nativeElement.querySelector('input');
  }

  function getHint(): HTMLSpanElement | null {
    return fixture.nativeElement.querySelector('.text-input__hint');
  }

  it('should render a <label> element above the input', () => {
    const label = getLabel();
    expect(label).toBeTruthy();
    expect(label.textContent?.trim()).toBe('Database Name');
  });

  it('should associate label with input via for/id', () => {
    const label = getLabel();
    const input = getInput();
    expect(label.getAttribute('for')).toBe(input.id);
  });

  it('should render a native <input> element', () => {
    const input = getInput();
    expect(input).toBeTruthy();
    expect(input.tagName).toBe('INPUT');
  });

  it('should default to type="text"', () => {
    expect(getInput().getAttribute('type')).toBe('text');
  });

  it('should apply monospace class by default', () => {
    expect(getInput().classList).toContain('text-input__field--mono');
  });

  it('should remove monospace class when mono=false', () => {
    host.mono = false;
    fixture.detectChanges();
    expect(getInput().classList).not.toContain('text-input__field--mono');
  });

  it('should show hint text when provided', () => {
    host.hint = 'Lowercase letters only';
    fixture.detectChanges();
    const hint = getHint();
    expect(hint).toBeTruthy();
    expect(hint?.textContent?.trim()).toBe('Lowercase letters only');
  });

  it('should link hint via aria-describedby', () => {
    host.hint = 'Lowercase letters only';
    fixture.detectChanges();
    const input = getInput();
    const hint = getHint();
    expect(input.getAttribute('aria-describedby')).toBe(hint!.id);
  });

  it('should not show hint when not provided', () => {
    expect(getHint()).toBeNull();
  });

  it('should show error text and set aria-invalid when error is set', () => {
    host.error = 'Name is required';
    fixture.detectChanges();
    const input = getInput();
    const hint = getHint();
    expect(input.getAttribute('aria-invalid')).toBe('true');
    expect(input.classList).toContain('text-input__field--error');
    expect(hint?.textContent?.trim()).toBe('Name is required');
    expect(hint?.classList).toContain('text-input__hint--error');
  });

  it('should show error text instead of hint when both are set', () => {
    host.hint = 'Normal hint';
    host.error = 'Error message';
    fixture.detectChanges();
    const hint = getHint();
    expect(hint?.textContent?.trim()).toBe('Error message');
  });

  it('should not set aria-invalid when no error', () => {
    expect(getInput().getAttribute('aria-invalid')).toBeNull();
  });

  it('should disable input when disabled=true', () => {
    host.disabled = true;
    fixture.detectChanges();
    expect(getInput().disabled).toBeTrue();
  });

  it('should support two-way value binding', () => {
    const input = getInput();
    input.value = 'my-database';
    input.dispatchEvent(new Event('input'));
    fixture.detectChanges();
    expect(host.value).toBe('my-database');
  });

  it('should pass axe-core accessibility checks', async () => {
    host.hint = 'Enter a valid name';
    fixture.detectChanges();
    await expectNoAxeViolations(fixture.nativeElement);
  });
});
