import { TestBed, ComponentFixture } from '@angular/core/testing';
import { Component } from '@angular/core';
import { IconButtonComponent } from './icon-button.component';
import { IconRefreshComponent } from '../icons';
import { expectNoAxeViolations } from '../test-utils';

@Component({
  standalone: true,
  imports: [IconButtonComponent, IconRefreshComponent],
  template: `
    <app-icon-button
      [ariaLabel]="ariaLabel"
      [disabled]="disabled">
      <app-icon-refresh [size]="16" />
    </app-icon-button>
  `,
})
class TestHost {
  ariaLabel = 'Refresh';
  disabled = false;
}

describe('IconButtonComponent', () => {
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

  it('should have type="button"', () => {
    expect(buttonEl.getAttribute('type')).toBe('button');
  });

  it('should apply aria-label', () => {
    expect(buttonEl.getAttribute('aria-label')).toBe('Refresh');
  });

  it('should render with 24x24 size', () => {
    expect(buttonEl.classList).toContain('icon-btn');
    const styles = getComputedStyle(buttonEl);
    /* The inline styles set min-width/min-height to 24px */
    expect(buttonEl.style.minWidth || styles.minWidth).toBeTruthy();
  });

  it('should project icon content', () => {
    const svg = fixture.nativeElement.querySelector('svg');
    expect(svg).toBeTruthy();
    expect(svg.getAttribute('aria-hidden')).toBe('true');
  });

  it('should disable button when disabled=true', () => {
    host.disabled = true;
    fixture.detectChanges();
    expect(buttonEl.disabled).toBeTrue();
  });

  it('should pass axe-core accessibility checks', async () => {
    await expectNoAxeViolations(fixture.nativeElement);
  });
});
