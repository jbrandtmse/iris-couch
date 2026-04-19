import { TestBed, ComponentFixture } from '@angular/core/testing';
import { Component } from '@angular/core';
import { ErrorDisplayComponent } from './error-display.component';
import { expectNoAxeViolations } from '../test-utils';

@Component({
  standalone: true,
  imports: [ErrorDisplayComponent],
  template: `
    <app-error-display
      [error]="error"
      [statusCode]="statusCode"
      [variant]="variant"
      [retryable]="retryable"
      (retry)="onRetry()">
    </app-error-display>
  `,
})
class TestHost {
  error = { error: 'unauthorized', reason: 'Name or password is incorrect.' };
  statusCode: number | undefined = 401;
  variant: 'full' | 'inline' = 'full';
  retryable = false;
  retried = false;
  onRetry(): void {
    this.retried = true;
  }
}

describe('ErrorDisplayComponent', () => {
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

  it('should render with role="alert" and aria-live="assertive"', () => {
    const el = fixture.nativeElement.querySelector('[role="alert"]');
    expect(el).toBeTruthy();
    expect(el.getAttribute('aria-live')).toBe('assertive');
  });

  it('should display the error text verbatim', () => {
    const errorEl = fixture.nativeElement.querySelector('.error-display__error');
    expect(errorEl.textContent.trim()).toBe('unauthorized');
  });

  it('should display the reason text verbatim', () => {
    const reasonEl = fixture.nativeElement.querySelector('.error-display__reason');
    expect(reasonEl.textContent.trim()).toBe('Name or password is incorrect.');
  });

  it('should display status code badge for 401', () => {
    const badge = fixture.nativeElement.querySelector('app-badge');
    expect(badge).toBeTruthy();
    expect(badge.textContent.trim()).toBe('401');
  });

  it('should apply full variant class by default', () => {
    const display = fixture.nativeElement.querySelector('.error-display--full');
    expect(display).toBeTruthy();
  });

  it('should apply inline variant class when specified', () => {
    host.variant = 'inline';
    fixture.detectChanges();
    const display = fixture.nativeElement.querySelector('.error-display--inline');
    expect(display).toBeTruthy();
  });

  it('should not show retry button by default', () => {
    const btn = fixture.nativeElement.querySelector('app-button');
    expect(btn).toBeNull();
  });

  it('should show retry button when retryable', () => {
    host.retryable = true;
    fixture.detectChanges();
    const btn = fixture.nativeElement.querySelector('app-button');
    expect(btn).toBeTruthy();
  });

  it('should emit retry event when retry button is clicked', () => {
    host.retryable = true;
    fixture.detectChanges();
    const btn = fixture.nativeElement.querySelector('app-button button') as HTMLButtonElement;
    btn.click();
    expect(host.retried).toBeTrue();
  });

  describe('with 404 error', () => {
    beforeEach(() => {
      host.error = { error: 'not_found', reason: 'missing' };
      host.statusCode = 404;
      fixture.detectChanges();
    });

    it('should display 404 badge', () => {
      const badge = fixture.nativeElement.querySelector('app-badge');
      expect(badge.textContent.trim()).toBe('404');
    });

    it('should display not_found error', () => {
      const errorEl = fixture.nativeElement.querySelector('.error-display__error');
      expect(errorEl.textContent.trim()).toBe('not_found');
    });
  });

  describe('with 500 error', () => {
    beforeEach(() => {
      host.error = { error: 'internal_server_error', reason: 'Unknown error' };
      host.statusCode = 500;
      host.retryable = true;
      fixture.detectChanges();
    });

    it('should display 500 badge', () => {
      const badge = fixture.nativeElement.querySelector('app-badge');
      expect(badge.textContent.trim()).toBe('500');
    });

    it('should show retry button for server errors', () => {
      const btn = fixture.nativeElement.querySelector('app-button');
      expect(btn).toBeTruthy();
    });
  });

  // Story 13.4 Task 8f: add 409 (conflict) and 0 (network error) fixtures so
  // the ErrorDisplay coverage matches the 5 states called out by the UX spec.
  describe('with 409 conflict error', () => {
    beforeEach(() => {
      host.error = { error: 'conflict', reason: 'Document update conflict.' };
      host.statusCode = 409;
      fixture.detectChanges();
    });

    it('should display 409 badge', () => {
      const badge = fixture.nativeElement.querySelector('app-badge');
      expect(badge.textContent.trim()).toBe('409');
    });

    it('should display conflict error slug', () => {
      const errorEl = fixture.nativeElement.querySelector('.error-display__error');
      expect(errorEl.textContent.trim()).toBe('conflict');
    });
  });

  describe('with network error (status 0)', () => {
    beforeEach(() => {
      host.error = { error: 'network_error', reason: 'Network request failed' };
      host.statusCode = 0;
      fixture.detectChanges();
    });

    it('should render the error envelope even for status 0', () => {
      const errorEl = fixture.nativeElement.querySelector('.error-display__error');
      expect(errorEl).toBeTruthy();
      expect(errorEl.textContent.trim()).toBe('network_error');
    });

    it('should render the reason text', () => {
      const reasonEl = fixture.nativeElement.querySelector('.error-display__reason');
      expect(reasonEl.textContent.trim()).toBe('Network request failed');
    });
  });

  it('should pass axe-core accessibility checks', async () => {
    await expectNoAxeViolations(fixture.nativeElement);
  });
});
