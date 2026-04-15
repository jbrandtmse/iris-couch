import { TestBed, ComponentFixture, fakeAsync, tick } from '@angular/core/testing';
import { Component } from '@angular/core';
import { PageHeaderComponent } from './page-header.component';
import { expectNoAxeViolations } from '../test-utils';

@Component({
  standalone: true,
  imports: [PageHeaderComponent],
  template: `
    <app-page-header
      [title]="title"
      [mono]="mono"
      [fetchedAt]="fetchedAt"
      [loading]="loading"
      (refresh)="onRefresh()">
      <ng-container actions>
        <button class="projected-action">Action</button>
      </ng-container>
    </app-page-header>
  `,
})
class TestHost {
  title = 'Databases';
  mono = false;
  fetchedAt: Date | null = null;
  loading = false;
  refreshed = false;
  onRefresh(): void { this.refreshed = true; }
}

describe('PageHeaderComponent', () => {
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

  it('should render the title', () => {
    const title = fixture.nativeElement.querySelector('.page-header__title');
    expect(title.textContent.trim()).toBe('Databases');
  });

  it('should apply mono class when mono=true', () => {
    host.mono = true;
    fixture.detectChanges();
    const title = fixture.nativeElement.querySelector('.page-header__title');
    expect(title.classList).toContain('page-header__title--mono');
  });

  it('should project action buttons', () => {
    const action = fixture.nativeElement.querySelector('.projected-action');
    expect(action).toBeTruthy();
  });

  it('should not show timestamp when fetchedAt is null', () => {
    const timestamp = fixture.nativeElement.querySelector('.page-header__timestamp');
    expect(timestamp).toBeNull();
  });

  it('should show relative timestamp under 60 seconds', () => {
    host.fetchedAt = new Date(Date.now() - 5000); // 5 seconds ago
    fixture.detectChanges();
    const timestamp = fixture.nativeElement.querySelector('.page-header__timestamp');
    expect(timestamp).toBeTruthy();
    expect(timestamp.textContent).toMatch(/\d+s ago/);
  });

  it('should show ISO-8601 timestamp after 60 seconds', () => {
    host.fetchedAt = new Date(Date.now() - 120000); // 2 minutes ago
    fixture.detectChanges();
    const timestamp = fixture.nativeElement.querySelector('.page-header__timestamp');
    expect(timestamp).toBeTruthy();
    // ISO format includes 'T' separator
    expect(timestamp.textContent).toContain('T');
  });

  it('should show refresh button when fetchedAt is set', () => {
    host.fetchedAt = new Date();
    fixture.detectChanges();
    const refreshBtn = fixture.nativeElement.querySelector('app-icon-button');
    expect(refreshBtn).toBeTruthy();
  });

  it('should emit refresh when refresh button clicked', () => {
    host.fetchedAt = new Date();
    fixture.detectChanges();
    const refreshBtn = fixture.nativeElement.querySelector('app-icon-button button');
    refreshBtn.click();
    expect(host.refreshed).toBeTrue();
  });

  it('should not show loading bar initially when loading=false', () => {
    const bar = fixture.nativeElement.querySelector('.page-header__loading-bar');
    expect(bar).toBeNull();
  });

  it('should show loading bar after 300ms delay', fakeAsync(() => {
    host.loading = true;
    fixture.detectChanges();

    // Not shown immediately
    let bar = fixture.nativeElement.querySelector('.page-header__loading-bar');
    expect(bar).toBeNull();

    // After 300ms
    tick(300);
    fixture.detectChanges();
    bar = fixture.nativeElement.querySelector('.page-header__loading-bar');
    expect(bar).toBeTruthy();
  }));

  it('should not show loading bar for fast loads under 300ms', fakeAsync(() => {
    host.loading = true;
    fixture.detectChanges();

    tick(200);
    host.loading = false;
    fixture.detectChanges();

    tick(200);
    fixture.detectChanges();

    const bar = fixture.nativeElement.querySelector('.page-header__loading-bar');
    expect(bar).toBeNull();
  }));

  it('should have aria-label on refresh button', () => {
    host.fetchedAt = new Date();
    fixture.detectChanges();
    const btn = fixture.nativeElement.querySelector('app-icon-button button');
    expect(btn.getAttribute('aria-label')).toBe('Refresh data');
  });

  it('should pass axe-core accessibility checks', async () => {
    host.fetchedAt = new Date();
    fixture.detectChanges();
    await expectNoAxeViolations(fixture.nativeElement);
  });
});
