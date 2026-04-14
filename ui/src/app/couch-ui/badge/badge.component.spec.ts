import { TestBed, ComponentFixture } from '@angular/core/testing';
import { Component } from '@angular/core';
import { BadgeComponent } from './badge.component';
import { expectNoAxeViolations } from '../test-utils';

@Component({
  standalone: true,
  imports: [BadgeComponent],
  template: `<app-badge [variant]="variant">{{ text }}</app-badge>`,
})
class TestHost {
  variant: 'info' | 'warn' | 'error' | 'success' = 'info';
  text = 'online';
}

describe('BadgeComponent', () => {
  let fixture: ComponentFixture<TestHost>;
  let host: TestHost;
  let badgeEl: HTMLSpanElement;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [TestHost],
    }).compileComponents();
    fixture = TestBed.createComponent(TestHost);
    host = fixture.componentInstance;
    fixture.detectChanges();
    badgeEl = fixture.nativeElement.querySelector('.badge');
  });

  it('should render as a <span> element', () => {
    expect(badgeEl).toBeTruthy();
    expect(badgeEl.tagName).toBe('SPAN');
  });

  it('should display as inline', () => {
    const hostEl = fixture.nativeElement.querySelector('app-badge');
    const styles = getComputedStyle(hostEl);
    expect(styles.display).toBe('inline');
  });

  it('should render info variant by default', () => {
    expect(badgeEl.classList).toContain('badge--info');
  });

  it('should render warn variant', () => {
    host.variant = 'warn';
    fixture.detectChanges();
    badgeEl = fixture.nativeElement.querySelector('.badge');
    expect(badgeEl.classList).toContain('badge--warn');
  });

  it('should render error variant', () => {
    host.variant = 'error';
    fixture.detectChanges();
    badgeEl = fixture.nativeElement.querySelector('.badge');
    expect(badgeEl.classList).toContain('badge--error');
  });

  it('should render success variant', () => {
    host.variant = 'success';
    fixture.detectChanges();
    badgeEl = fixture.nativeElement.querySelector('.badge');
    expect(badgeEl.classList).toContain('badge--success');
  });

  it('should project text content', () => {
    expect(badgeEl.textContent?.trim()).toBe('online');
  });

  it('should pass axe-core accessibility checks', async () => {
    await expectNoAxeViolations(fixture.nativeElement);
  });
});
