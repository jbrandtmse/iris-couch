import { TestBed, ComponentFixture } from '@angular/core/testing';
import { Component } from '@angular/core';
import { ButtonComponent } from './button.component';
import { expectNoAxeViolations } from '../test-utils';

/* Host component for content-projection tests */
@Component({
  standalone: true,
  imports: [ButtonComponent],
  template: `
    <app-button
      [variant]="variant"
      [size]="size"
      [loading]="loading"
      [disabled]="disabled"
      [ariaLabel]="ariaLabel"
      [type]="type">
      {{ label }}
    </app-button>
  `,
})
class TestHost {
  variant: 'ghost' | 'primary' | 'destructive' = 'ghost';
  size: 'compact' | 'standard' | 'primary-page' = 'standard';
  loading = false;
  disabled = false;
  ariaLabel?: string;
  type: 'button' | 'submit' = 'button';
  label = 'Click me';
}

describe('ButtonComponent', () => {
  let fixture: ComponentFixture<TestHost>;
  let host: TestHost;
  let buttonEl: HTMLButtonElement;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [TestHost],
    }).compileComponents();
    fixture = TestBed.createComponent(TestHost);
    host = fixture.componentInstance;
    fixture.detectChanges();
    buttonEl = fixture.nativeElement.querySelector('button');
  });

  it('should render a native <button> element', () => {
    expect(buttonEl).toBeTruthy();
    expect(buttonEl.tagName).toBe('BUTTON');
  });

  it('should default to type="button"', () => {
    expect(buttonEl.getAttribute('type')).toBe('button');
  });

  it('should allow type="submit"', () => {
    host.type = 'submit';
    fixture.detectChanges();
    expect(buttonEl.getAttribute('type')).toBe('submit');
  });

  it('should render with ghost variant class by default', () => {
    expect(buttonEl.classList).toContain('btn--ghost');
    expect(buttonEl.classList).toContain('btn--standard');
  });

  it('should render primary variant class', () => {
    host.variant = 'primary';
    fixture.detectChanges();
    expect(buttonEl.classList).toContain('btn--primary');
  });

  it('should render destructive variant class', () => {
    host.variant = 'destructive';
    fixture.detectChanges();
    expect(buttonEl.classList).toContain('btn--destructive');
  });

  it('should render compact size class', () => {
    host.size = 'compact';
    fixture.detectChanges();
    expect(buttonEl.classList).toContain('btn--compact');
  });

  it('should render primary-page size class', () => {
    host.size = 'primary-page';
    fixture.detectChanges();
    expect(buttonEl.classList).toContain('btn--primary-page');
  });

  it('should disable the native button when disabled=true', () => {
    host.disabled = true;
    fixture.detectChanges();
    expect(buttonEl.disabled).toBeTrue();
  });

  it('should disable the native button when loading=true', () => {
    host.loading = true;
    fixture.detectChanges();
    expect(buttonEl.disabled).toBeTrue();
  });

  it('should show spinner when loading', () => {
    host.loading = true;
    fixture.detectChanges();
    const spinner = fixture.nativeElement.querySelector('.btn__spinner');
    expect(spinner).toBeTruthy();
  });

  it('should set aria-busy when loading', () => {
    host.loading = true;
    fixture.detectChanges();
    expect(buttonEl.getAttribute('aria-busy')).toBe('true');
  });

  it('should not show spinner when not loading', () => {
    const spinner = fixture.nativeElement.querySelector('.btn__spinner');
    expect(spinner).toBeNull();
  });

  it('should preserve label text when loading', () => {
    host.loading = true;
    fixture.detectChanges();
    const content = fixture.nativeElement.querySelector('.btn__content');
    expect(content.textContent.trim()).toBe('Click me');
  });

  it('should apply aria-label when provided', () => {
    host.ariaLabel = 'Delete item';
    fixture.detectChanges();
    expect(buttonEl.getAttribute('aria-label')).toBe('Delete item');
  });

  it('should not have aria-label when not provided', () => {
    expect(buttonEl.getAttribute('aria-label')).toBeNull();
  });

  it('should project content text', () => {
    expect(buttonEl.textContent).toContain('Click me');
  });

  it('should pass axe-core accessibility checks', async () => {
    host.ariaLabel = 'Test button';
    fixture.detectChanges();
    await expectNoAxeViolations(fixture.nativeElement);
  });
});
