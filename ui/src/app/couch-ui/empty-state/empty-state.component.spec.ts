import { TestBed, ComponentFixture } from '@angular/core/testing';
import { Component } from '@angular/core';
import { EmptyStateComponent } from './empty-state.component';
import { expectNoAxeViolations } from '../test-utils';

@Component({
  standalone: true,
  imports: [EmptyStateComponent],
  template: `
    <app-empty-state
      [primary]="primary"
      [secondary]="secondary"
      [ctaLabel]="ctaLabel"
      (ctaClick)="onCta()">
    </app-empty-state>
  `,
})
class TestHost {
  primary = 'No databases yet.';
  secondary: string | undefined = 'Create one to get started.';
  ctaLabel: string | undefined = 'Create database';
  ctaClicked = false;
  onCta(): void { this.ctaClicked = true; }
}

describe('EmptyStateComponent', () => {
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

  it('should render the primary message', () => {
    const primary = fixture.nativeElement.querySelector('.empty-state__primary');
    expect(primary.textContent.trim()).toBe('No databases yet.');
  });

  it('should render the secondary message', () => {
    const secondary = fixture.nativeElement.querySelector('.empty-state__secondary');
    expect(secondary.textContent.trim()).toBe('Create one to get started.');
  });

  it('should hide secondary when not provided', () => {
    host.secondary = undefined;
    fixture.detectChanges();
    const secondary = fixture.nativeElement.querySelector('.empty-state__secondary');
    expect(secondary).toBeNull();
  });

  it('should render CTA button with label', () => {
    const btn = fixture.nativeElement.querySelector('app-button');
    expect(btn).toBeTruthy();
    expect(btn.textContent.trim()).toBe('Create database');
  });

  it('should hide CTA button when ctaLabel not provided', () => {
    host.ctaLabel = undefined;
    fixture.detectChanges();
    const btn = fixture.nativeElement.querySelector('app-button');
    expect(btn).toBeNull();
  });

  it('should emit ctaClick when CTA is clicked', () => {
    const btn = fixture.nativeElement.querySelector('button');
    btn.click();
    expect(host.ctaClicked).toBeTrue();
  });

  it('should use centered vertical flex layout', () => {
    const container = fixture.nativeElement.querySelector('.empty-state');
    expect(container).toBeTruthy();
  });

  it('should pass axe-core accessibility checks', async () => {
    await expectNoAxeViolations(fixture.nativeElement);
  });
});
