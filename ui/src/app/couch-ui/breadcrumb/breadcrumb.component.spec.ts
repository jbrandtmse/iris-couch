import { TestBed, ComponentFixture } from '@angular/core/testing';
import { Component } from '@angular/core';
import { provideRouter } from '@angular/router';
import { BreadcrumbComponent, BreadcrumbSegment } from './breadcrumb.component';
import { expectNoAxeViolations } from '../test-utils';

@Component({
  standalone: true,
  imports: [BreadcrumbComponent],
  template: `<app-breadcrumb [segments]="segments"></app-breadcrumb>`,
})
class TestHost {
  segments: BreadcrumbSegment[] = [
    { label: 'Databases', url: '/databases' },
    { label: 'mydb', url: '/db/mydb' },
    { label: 'doc-001' },
  ];
}

describe('BreadcrumbComponent', () => {
  let fixture: ComponentFixture<TestHost>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [TestHost],
      providers: [provideRouter([])],
    }).compileComponents();

    fixture = TestBed.createComponent(TestHost);
    fixture.detectChanges();
  });

  it('should render in a <nav> with aria-label="Breadcrumb"', () => {
    const nav = fixture.nativeElement.querySelector('nav[aria-label="Breadcrumb"]');
    expect(nav).toBeTruthy();
  });

  it('should render clickable segments as <a> tags', () => {
    const links = fixture.nativeElement.querySelectorAll('.breadcrumb__link');
    expect(links.length).toBe(2);
    expect(links[0].textContent.trim()).toBe('Databases');
    expect(links[1].textContent.trim()).toBe('mydb');
  });

  it('should render the last segment as a non-clickable <span>', () => {
    const span = fixture.nativeElement.querySelector('.breadcrumb__current');
    expect(span).toBeTruthy();
    expect(span.tagName).toBe('SPAN');
    expect(span.textContent.trim()).toBe('doc-001');
  });

  it('should set aria-current="page" on the last segment', () => {
    const span = fixture.nativeElement.querySelector('.breadcrumb__current');
    expect(span.getAttribute('aria-current')).toBe('page');
  });

  it('should render separator / between segments', () => {
    const seps = fixture.nativeElement.querySelectorAll('.breadcrumb__sep');
    expect(seps.length).toBe(2);
    expect(seps[0].textContent.trim()).toBe('/');
    expect(seps[0].getAttribute('aria-hidden')).toBe('true');
  });

  it('should use monospace font class on all segment labels', () => {
    const links = fixture.nativeElement.querySelectorAll('.breadcrumb__link');
    links.forEach((link: HTMLElement) => {
      expect(link.classList).toContain('mono');
    });
    const current = fixture.nativeElement.querySelector('.breadcrumb__current');
    expect(current.classList).toContain('mono');
  });

  it('should pass axe-core accessibility checks', async () => {
    await expectNoAxeViolations(fixture.nativeElement);
  });
});
