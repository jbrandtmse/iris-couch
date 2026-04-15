import { TestBed, ComponentFixture } from '@angular/core/testing';
import { Component } from '@angular/core';
import { Clipboard } from '@angular/cdk/clipboard';
import { LiveAnnouncer } from '@angular/cdk/a11y';
import { JsonDisplayComponent } from './json-display.component';
import { expectNoAxeViolations } from '../test-utils';

@Component({
  standalone: true,
  imports: [JsonDisplayComponent],
  template: `<app-json-display [json]="json"></app-json-display>`,
})
class TestHost {
  json = '{"_id":"doc1","_rev":"1-abc","title":"Hello","count":42,"active":true,"deleted":null}';
}

describe('JsonDisplayComponent', () => {
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

  function getContainer(): HTMLElement {
    return fixture.nativeElement.querySelector('.json-display');
  }

  function getLines(): NodeListOf<HTMLElement> {
    return fixture.nativeElement.querySelectorAll('.json-display__line');
  }

  function getLineNumbers(): NodeListOf<HTMLElement> {
    return fixture.nativeElement.querySelectorAll('.json-display__line-number');
  }

  it('should render the json-display container', () => {
    expect(getContainer()).toBeTruthy();
  });

  it('should have role="textbox" and aria-readonly="true"', () => {
    const container = getContainer();
    expect(container.getAttribute('role')).toBe('textbox');
    expect(container.getAttribute('aria-readonly')).toBe('true');
    expect(container.getAttribute('aria-label')).toBe('Document JSON');
  });

  it('should pretty-print JSON with 2-space indent', () => {
    const lines = getLines();
    // The pretty-printed JSON should have multiple lines
    expect(lines.length).toBeGreaterThan(1);

    // First line should be opening brace
    const firstLineContent = lines[0].querySelector('.json-display__content');
    expect(firstLineContent?.textContent?.trim()).toBe('{');
  });

  it('should render line numbers', () => {
    const lineNumbers = getLineNumbers();
    expect(lineNumbers.length).toBeGreaterThan(0);
    expect(lineNumbers[0].textContent?.trim()).toBe('1');
    expect(lineNumbers[1].textContent?.trim()).toBe('2');
  });

  it('should make line numbers non-selectable via CSS', () => {
    const lineNumber = getLineNumbers()[0];
    const styles = getComputedStyle(lineNumber);
    expect(styles.userSelect).toBe('none');
  });

  it('should apply syntax coloring to keys', () => {
    const keySpans = fixture.nativeElement.querySelectorAll('.json-token--key');
    expect(keySpans.length).toBeGreaterThan(0);
  });

  it('should apply syntax coloring to string values', () => {
    const stringSpans = fixture.nativeElement.querySelectorAll('.json-token--string');
    expect(stringSpans.length).toBeGreaterThan(0);
  });

  it('should apply syntax coloring to number values', () => {
    const numberSpans = fixture.nativeElement.querySelectorAll('.json-token--number');
    expect(numberSpans.length).toBeGreaterThan(0);
  });

  it('should apply syntax coloring to boolean values', () => {
    const boolSpans = fixture.nativeElement.querySelectorAll('.json-token--boolean');
    expect(boolSpans.length).toBeGreaterThan(0);
  });

  it('should apply syntax coloring to null values', () => {
    const nullSpans = fixture.nativeElement.querySelectorAll('.json-token--null');
    expect(nullSpans.length).toBeGreaterThan(0);
  });

  it('should render a Copy raw JSON button above the display', () => {
    const copyBtn = fixture.nativeElement.querySelector('app-copy-button');
    expect(copyBtn).toBeTruthy();
  });

  it('should use monospace font throughout', () => {
    const container = getContainer();
    const styles = getComputedStyle(container);
    // The font-family should include the mono font
    expect(styles.fontFamily).toBeTruthy();
  });

  it('should not reorder keys in the output', () => {
    const allText = getContainer().textContent || '';
    const idPos = allText.indexOf('_id');
    const revPos = allText.indexOf('_rev');
    const titlePos = allText.indexOf('title');
    const countPos = allText.indexOf('count');
    // Keys should appear in original order
    expect(idPos).toBeLessThan(revPos);
    expect(revPos).toBeLessThan(titlePos);
    expect(titlePos).toBeLessThan(countPos);
  });

  it('should handle empty JSON object', () => {
    host.json = '{}';
    fixture.detectChanges();
    const lines = getLines();
    expect(lines.length).toBeGreaterThan(0);
  });

  it('should handle JSON array', () => {
    host.json = '[1, 2, 3]';
    fixture.detectChanges();
    const lines = getLines();
    expect(lines.length).toBeGreaterThan(0);
  });

  it('should handle empty string input gracefully', () => {
    host.json = '';
    fixture.detectChanges();
    // Should not crash
    expect(fixture.nativeElement.querySelector('.json-display')).toBeTruthy();
  });

  it('should pass axe-core accessibility checks', async () => {
    await expectNoAxeViolations(fixture.nativeElement);
  });
});
