import { TestBed, ComponentFixture } from '@angular/core/testing';
import { provideRouter, Router } from '@angular/router';
import { SideNavComponent } from './side-nav.component';
import { expectNoAxeViolations } from '../test-utils';

describe('SideNavComponent', () => {
  let fixture: ComponentFixture<SideNavComponent>;
  let component: SideNavComponent;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [SideNavComponent],
      providers: [provideRouter([])],
    }).compileComponents();

    fixture = TestBed.createComponent(SideNavComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });

  it('should render global nav items', () => {
    const links = fixture.nativeElement.querySelectorAll('.nav-link');
    const labels = Array.from(links).map((a: any) => a.textContent.trim());
    expect(labels).toEqual(['Databases', 'Active tasks', 'Setup', 'About']);
  });

  it('should wrap nav items in a <nav> with role="navigation"', () => {
    const nav = fixture.nativeElement.querySelector('nav[role="navigation"]');
    expect(nav).toBeTruthy();
    expect(nav.getAttribute('aria-label')).toBe('Main navigation');
  });

  it('should use an unordered list for nav items', () => {
    const ul = fixture.nativeElement.querySelector('ul.nav-list');
    expect(ul).toBeTruthy();
  });

  it('should render each nav item as a link', () => {
    const links = fixture.nativeElement.querySelectorAll('a.nav-link');
    expect(links.length).toBe(4);
  });

  it('should have first item focused by default (tabindex=0)', () => {
    const firstLink = fixture.nativeElement.querySelector('a.nav-link');
    expect(firstLink.getAttribute('tabindex')).toBe('0');
  });

  describe('Keyboard navigation', () => {
    it('should handle arrow key navigation via FocusKeyManager', () => {
      const ul = fixture.nativeElement.querySelector('ul.nav-list');
      expect(ul).toBeTruthy();
      spyOn(component, 'onKeydown').and.callThrough();
      const event = new KeyboardEvent('keydown', { key: 'ArrowDown', bubbles: true });
      ul.dispatchEvent(event);
      expect(component.onKeydown).toHaveBeenCalled();
    });

    it('should set non-focused items to tabindex=-1', () => {
      const links = fixture.nativeElement.querySelectorAll('a.nav-link');
      // First link should be tabindex=0, others -1
      expect(links[0].getAttribute('tabindex')).toBe('0');
      for (let i = 1; i < links.length; i++) {
        expect(links[i].getAttribute('tabindex')).toBe('-1');
      }
    });
  });

  it('should pass axe-core accessibility checks', async () => {
    await expectNoAxeViolations(fixture.nativeElement);
  });
});
