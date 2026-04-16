import { TestBed, ComponentFixture, fakeAsync, tick } from '@angular/core/testing';
import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { DesignDocCreateDialogComponent } from './design-doc-create-dialog.component';
import { expectNoAxeViolations } from '../../couch-ui/test-utils';

@Component({
  standalone: true,
  imports: [CommonModule, DesignDocCreateDialogComponent],
  template: `
    <app-design-doc-create-dialog
      *ngIf="show"
      [existingNames]="existingNames"
      [serverError]="serverError"
      [serverErrorCode]="serverErrorCode"
      [loading]="loading"
      (create)="onCreate($event)"
      (cancel)="onCancel()">
    </app-design-doc-create-dialog>
  `,
})
class TestHost {
  show = true;
  existingNames: string[] = [];
  serverError?: { error: string; reason: string };
  serverErrorCode?: number;
  loading = false;
  lastCreate?: { name: string; body: unknown };
  cancelled = false;
  onCreate(p: { name: string; body: unknown }): void {
    this.lastCreate = p;
  }
  onCancel(): void {
    this.cancelled = true;
  }
}

describe('DesignDocCreateDialogComponent', () => {
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

  function getNameInput(): HTMLInputElement {
    return fixture.nativeElement.querySelector('app-text-input input');
  }
  function getTextarea(): HTMLTextAreaElement {
    return fixture.nativeElement.querySelector('app-text-area-json textarea');
  }
  function getCreateBtn(): HTMLButtonElement {
    const buttons = fixture.nativeElement.querySelectorAll('button');
    return buttons[buttons.length - 1] as HTMLButtonElement;
  }

  it('renders with role="dialog" and aria-modal', () => {
    const dialog = fixture.nativeElement.querySelector('[role="dialog"]');
    expect(dialog).toBeTruthy();
    expect(dialog.getAttribute('aria-modal')).toBe('true');
  });

  it('pre-fills the body with the default JS view template', () => {
    const ta = getTextarea();
    expect(ta.value).toContain('"language": "javascript"');
    expect(ta.value).toContain('"views": {}');
  });

  it('disables the Create button when name is empty', () => {
    expect(getCreateBtn().disabled).toBeTrue();
  });

  it('enables the Create button with a valid name + valid JSON', fakeAsync(() => {
    const input = getNameInput();
    input.value = 'myapp';
    input.dispatchEvent(new Event('input'));
    fixture.detectChanges();
    tick(200);
    fixture.detectChanges();
    expect(getCreateBtn().disabled).toBeFalse();
  }));

  it('disables Create when name conflicts with existingNames', fakeAsync(() => {
    host.existingNames = ['exists'];
    fixture.detectChanges();
    const input = getNameInput();
    input.value = 'exists';
    input.dispatchEvent(new Event('input'));
    fixture.detectChanges();
    tick(200);
    fixture.detectChanges();
    expect(getCreateBtn().disabled).toBeTrue();
    const error = fixture.nativeElement.querySelector('.text-input__hint--error');
    expect(error?.textContent?.trim()).toContain('already exists');
  }));

  it('disables Create when name has invalid characters', () => {
    const input = getNameInput();
    input.value = 'BAD NAME';
    input.dispatchEvent(new Event('input'));
    fixture.detectChanges();
    expect(getCreateBtn().disabled).toBeTrue();
  });

  it('disables Create when JSON body is invalid', fakeAsync(() => {
    const input = getNameInput();
    input.value = 'good';
    input.dispatchEvent(new Event('input'));
    fixture.detectChanges();
    const ta = getTextarea();
    ta.value = '{invalid';
    ta.dispatchEvent(new Event('input'));
    fixture.detectChanges();
    tick(200);
    fixture.detectChanges();
    expect(getCreateBtn().disabled).toBeTrue();
  }));

  it('emits create event with parsed body on confirm', fakeAsync(() => {
    const input = getNameInput();
    input.value = 'myapp';
    input.dispatchEvent(new Event('input'));
    fixture.detectChanges();
    tick(200);
    fixture.detectChanges();
    getCreateBtn().click();
    expect(host.lastCreate).toEqual({
      name: 'myapp',
      body: { language: 'javascript', views: {} },
    });
  }));

  it('emits cancel on Esc', () => {
    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }));
    expect(host.cancelled).toBeTrue();
  });

  it('emits cancel on backdrop click', () => {
    const backdrop = fixture.nativeElement.querySelector('.dialog-backdrop');
    backdrop.click();
    expect(host.cancelled).toBeTrue();
  });

  it('shows server error inline when provided', () => {
    host.serverError = { error: 'conflict', reason: 'Document update conflict.' };
    host.serverErrorCode = 409;
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('app-error-display')).toBeTruthy();
  });

  it('passes axe-core checks', async () => {
    await expectNoAxeViolations(fixture.nativeElement);
  });
});
