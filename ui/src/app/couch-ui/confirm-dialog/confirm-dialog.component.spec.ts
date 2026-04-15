import { TestBed, ComponentFixture, fakeAsync, tick } from '@angular/core/testing';
import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ConfirmDialogComponent, ConfirmDialogVariant } from './confirm-dialog.component';
import { expectNoAxeViolations } from '../test-utils';

@Component({
  standalone: true,
  imports: [CommonModule, ConfirmDialogComponent],
  template: `
    <app-confirm-dialog
      *ngIf="show"
      [title]="title"
      [body]="body"
      [variant]="variant"
      [confirmLabel]="confirmLabel"
      [confirmValue]="confirmValue"
      [inputLabel]="inputLabel"
      [inputHint]="inputHint"
      [serverError]="serverError"
      [serverErrorCode]="serverErrorCode"
      [loading]="loading"
      (confirm)="onConfirm($event)"
      (cancel)="onCancel()">
    </app-confirm-dialog>
  `,
})
class TestHost {
  show = true;
  title = 'Create database';
  body?: string;
  variant: ConfirmDialogVariant = 'create';
  confirmLabel = 'Create';
  confirmValue = '';
  inputLabel = 'Database name';
  inputHint = 'Lowercase letters, digits, _$()+-/';
  serverError?: { error: string; reason: string };
  serverErrorCode?: number;
  loading = false;
  lastConfirm?: string;
  cancelled = false;
  onConfirm(val: string): void { this.lastConfirm = val; }
  onCancel(): void { this.cancelled = true; }
}

describe('ConfirmDialogComponent', () => {
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

  it('should render with role="dialog" and aria-modal', () => {
    const dialog = fixture.nativeElement.querySelector('[role="dialog"]');
    expect(dialog).toBeTruthy();
    expect(dialog.getAttribute('aria-modal')).toBe('true');
  });

  it('should render the title', () => {
    const title = fixture.nativeElement.querySelector('.dialog__title');
    expect(title.textContent.trim()).toBe('Create database');
  });

  it('should have aria-labelledby pointing to title', () => {
    const dialog = fixture.nativeElement.querySelector('[role="dialog"]');
    const title = fixture.nativeElement.querySelector('.dialog__title');
    expect(dialog.getAttribute('aria-labelledby')).toBe(title.id);
  });

  describe('Create variant', () => {
    it('should render input field', () => {
      const input = fixture.nativeElement.querySelector('app-text-input');
      expect(input).toBeTruthy();
    });

    it('should disable confirm button when input is empty', () => {
      const buttons = fixture.nativeElement.querySelectorAll('button');
      const confirmBtn = buttons[buttons.length - 1];
      expect(confirmBtn.disabled).toBeTrue();
    });

    it('should enable confirm button with valid input', () => {
      const input = fixture.nativeElement.querySelector('input');
      input.value = 'mydb';
      input.dispatchEvent(new Event('input'));
      fixture.detectChanges();
      const buttons = fixture.nativeElement.querySelectorAll('button');
      const confirmBtn = buttons[buttons.length - 1];
      expect(confirmBtn.disabled).toBeFalse();
    });

    it('should show validation error for invalid name', () => {
      const input = fixture.nativeElement.querySelector('input');
      input.value = '123invalid';
      input.dispatchEvent(new Event('input'));
      fixture.detectChanges();
      const hint = fixture.nativeElement.querySelector('.text-input__hint--error');
      expect(hint).toBeTruthy();
      expect(hint.textContent).toContain('Must start with a lowercase letter');
    });

    it('should show validation error for uppercase letters', () => {
      const input = fixture.nativeElement.querySelector('input');
      input.value = 'MyDb';
      input.dispatchEvent(new Event('input'));
      fixture.detectChanges();
      const hint = fixture.nativeElement.querySelector('.text-input__hint--error');
      expect(hint).toBeTruthy();
    });

    it('should emit confirm with input value', () => {
      const input = fixture.nativeElement.querySelector('input');
      input.value = 'validdb';
      input.dispatchEvent(new Event('input'));
      fixture.detectChanges();
      const buttons = fixture.nativeElement.querySelectorAll('button');
      const confirmBtn = buttons[buttons.length - 1];
      confirmBtn.click();
      expect(host.lastConfirm).toBe('validdb');
    });
  });

  describe('Destructive type-to-confirm variant', () => {
    beforeEach(() => {
      host.variant = 'destructive-type-to-confirm';
      host.title = 'Delete database';
      host.confirmLabel = 'Delete';
      host.confirmValue = 'mydb';
      host.body = 'This will permanently delete the database and all 42 documents.';
      fixture.detectChanges();
    });

    it('should show the confirm value in monospace', () => {
      const code = fixture.nativeElement.querySelector('.dialog__confirm-value');
      expect(code).toBeTruthy();
      expect(code.textContent.trim()).toBe('mydb');
    });

    it('should disable delete button until exact match', () => {
      const buttons = fixture.nativeElement.querySelectorAll('button');
      const deleteBtn = buttons[buttons.length - 1];
      expect(deleteBtn.disabled).toBeTrue();
    });

    it('should enable delete button when exact match typed', () => {
      const input = fixture.nativeElement.querySelector('input');
      input.value = 'mydb';
      input.dispatchEvent(new Event('input'));
      fixture.detectChanges();
      const buttons = fixture.nativeElement.querySelectorAll('button');
      const deleteBtn = buttons[buttons.length - 1];
      expect(deleteBtn.disabled).toBeFalse();
    });

    it('should keep delete disabled for partial match', () => {
      const input = fixture.nativeElement.querySelector('input');
      input.value = 'myd';
      input.dispatchEvent(new Event('input'));
      fixture.detectChanges();
      const buttons = fixture.nativeElement.querySelectorAll('button');
      const deleteBtn = buttons[buttons.length - 1];
      expect(deleteBtn.disabled).toBeTrue();
    });

    it('should use destructive button variant', () => {
      const input = fixture.nativeElement.querySelector('input');
      input.value = 'mydb';
      input.dispatchEvent(new Event('input'));
      fixture.detectChanges();
      const buttons = fixture.nativeElement.querySelectorAll('button');
      const deleteBtn = buttons[buttons.length - 1];
      expect(deleteBtn.classList).toContain('btn--destructive');
    });
  });

  describe('Destructive simple variant', () => {
    beforeEach(() => {
      host.variant = 'destructive-simple';
      host.title = 'Remove item';
      host.confirmLabel = 'Remove';
      fixture.detectChanges();
    });

    it('should enable confirm button immediately', () => {
      const buttons = fixture.nativeElement.querySelectorAll('button');
      const confirmBtn = buttons[buttons.length - 1];
      expect(confirmBtn.disabled).toBeFalse();
    });
  });

  describe('Dialog interactions', () => {
    it('should close on Escape key', () => {
      document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }));
      expect(host.cancelled).toBeTrue();
    });

    it('should close on Escape key via keyboard event', () => {
      host.cancelled = false;
      const dialog = fixture.nativeElement.querySelector('[role="dialog"]');
      dialog.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }));
      // Escape is handled at document level
      expect(host.cancelled).toBeTrue();
    });

    it('should close on backdrop click', () => {
      const backdrop = fixture.nativeElement.querySelector('.dialog-backdrop');
      backdrop.click();
      expect(host.cancelled).toBeTrue();
    });

    it('should not close when clicking inside dialog', () => {
      const dialog = fixture.nativeElement.querySelector('.dialog');
      dialog.click();
      expect(host.cancelled).toBeFalse();
    });

    it('should show server error when provided', () => {
      host.serverError = { error: 'file_exists', reason: 'The database could not be created, the file already exists.' };
      host.serverErrorCode = 412;
      fixture.detectChanges();
      const error = fixture.nativeElement.querySelector('app-error-display');
      expect(error).toBeTruthy();
    });

    it('should disable confirm button when loading', () => {
      host.loading = true;
      const input = fixture.nativeElement.querySelector('input');
      input.value = 'validdb';
      input.dispatchEvent(new Event('input'));
      fixture.detectChanges();
      const buttons = fixture.nativeElement.querySelectorAll('button');
      const confirmBtn = buttons[buttons.length - 1];
      expect(confirmBtn.disabled).toBeTrue();
    });
  });

  it('should pass axe-core accessibility checks', async () => {
    await expectNoAxeViolations(fixture.nativeElement);
  });
});
