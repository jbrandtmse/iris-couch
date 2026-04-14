import { TestBed, ComponentFixture, fakeAsync, tick } from '@angular/core/testing';
import { Component } from '@angular/core';
import { Clipboard } from '@angular/cdk/clipboard';
import { LiveAnnouncer } from '@angular/cdk/a11y';
import { CopyButtonComponent } from './copy-button.component';
import { expectNoAxeViolations } from '../test-utils';

@Component({
  standalone: true,
  imports: [CopyButtonComponent],
  template: `
    <app-copy-button
      [value]="value"
      [ariaLabel]="ariaLabel"
      [variant]="variant">
    </app-copy-button>
  `,
})
class TestHost {
  value = 'test-doc-id';
  ariaLabel = 'Copy';
  variant: 'inline' | 'block' = 'inline';
}

describe('CopyButtonComponent', () => {
  let fixture: ComponentFixture<TestHost>;
  let host: TestHost;
  let clipboardSpy: jasmine.SpyObj<Clipboard>;
  let announcerSpy: jasmine.SpyObj<LiveAnnouncer>;

  beforeEach(async () => {
    clipboardSpy = jasmine.createSpyObj('Clipboard', ['copy']);
    clipboardSpy.copy.and.returnValue(true);

    announcerSpy = jasmine.createSpyObj('LiveAnnouncer', ['announce']);
    announcerSpy.announce.and.returnValue(Promise.resolve());

    await TestBed.configureTestingModule({
      imports: [TestHost],
      providers: [
        { provide: Clipboard, useValue: clipboardSpy },
        { provide: LiveAnnouncer, useValue: announcerSpy },
      ],
    }).compileComponents();
    fixture = TestBed.createComponent(TestHost);
    host = fixture.componentInstance;
    fixture.detectChanges();
  });

  function getButton(): HTMLButtonElement {
    return fixture.nativeElement.querySelector('button');
  }

  it('should render a <button> element', () => {
    expect(getButton()).toBeTruthy();
    expect(getButton().tagName).toBe('BUTTON');
  });

  it('should render copy icon by default', () => {
    const copyIcon = fixture.nativeElement.querySelector('app-icon-copy');
    expect(copyIcon).toBeTruthy();
    const checkIcon = fixture.nativeElement.querySelector('app-icon-check');
    expect(checkIcon).toBeFalsy();
  });

  it('should have aria-label', () => {
    expect(getButton().getAttribute('aria-label')).toBe('Copy');
  });

  it('should copy value to clipboard on click', () => {
    getButton().click();
    expect(clipboardSpy.copy).toHaveBeenCalledWith('test-doc-id');
  });

  it('should show check icon after copy', () => {
    getButton().click();
    fixture.detectChanges();
    const checkIcon = fixture.nativeElement.querySelector('app-icon-check');
    expect(checkIcon).toBeTruthy();
    const copyIcon = fixture.nativeElement.querySelector('app-icon-copy');
    expect(copyIcon).toBeFalsy();
  });

  it('should announce "Copied." via LiveAnnouncer', () => {
    getButton().click();
    expect(announcerSpy.announce).toHaveBeenCalledWith('Copied.');
  });

  it('should revert to copy icon after ~600ms', fakeAsync(() => {
    getButton().click();
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('app-icon-check')).toBeTruthy();

    tick(600);
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('app-icon-copy')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('app-icon-check')).toBeFalsy();
  }));

  it('should show text label in block variant', () => {
    host.variant = 'block';
    fixture.detectChanges();
    const label = fixture.nativeElement.querySelector('.copy-btn__label');
    expect(label).toBeTruthy();
    expect(label.textContent.trim()).toBe('Copy raw JSON');
  });

  it('should not show text label in inline variant', () => {
    const label = fixture.nativeElement.querySelector('.copy-btn__label');
    expect(label).toBeFalsy();
  });

  it('should pass axe-core accessibility checks', async () => {
    await expectNoAxeViolations(fixture.nativeElement);
  });
});
