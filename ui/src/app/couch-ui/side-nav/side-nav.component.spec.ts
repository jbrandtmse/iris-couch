import { TestBed, ComponentFixture } from '@angular/core/testing';
import { provideRouter, Router } from '@angular/router';
import {
  NAV_ENTRY_CONFIG,
  PerDbNavEntry,
  SideNavComponent,
} from './side-nav.component';
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

  // Story 11.1 AC #1 / Task 6 -- confirm the per-database Design Documents
  // link wires to the new /db/:dbname/design route.
  describe('per-database scope (Story 11.1)', () => {
    beforeEach(() => {
      // Simulate the per-database scope by setting items directly (the real
      // scope-switching logic is driven by router.url; verifying the link
      // shape is sufficient here).
      component.items = [
        { label: 'Documents', route: '/db/testdb' },
        { label: 'Design Documents', route: '/db/testdb/design' },
        { label: 'Security', route: '/db/testdb/security' },
      ];
      fixture.detectChanges();
    });

    it('renders a Design Documents link that resolves to /db/{name}/design', () => {
      const links = fixture.nativeElement.querySelectorAll('a.nav-link');
      const labels = Array.from(links).map((a: any) => a.textContent.trim());
      expect(labels).toContain('Design Documents');
      const designLink = Array.from(links).find(
        (a: any) => a.textContent.trim() === 'Design Documents',
      ) as HTMLAnchorElement | undefined;
      expect(designLink).toBeTruthy();
      // routerLink attribute is bound; Angular reflects it on the href too.
      expect(designLink!.getAttribute('href')).toBe('/db/testdb/design');
    });
  });

  // Story 11.4 -- Revision History entry:
  //   - enabled (routes to /db/{db}/doc/{id}/revisions) when docId is set
  //   - disabled with tooltip otherwise
  describe('per-database scope — Revision History (Story 11.4)', () => {
    it('renders a disabled Revision History entry when docId is absent', () => {
      component.items = [
        { label: 'Documents', route: '/db/testdb' },
        { label: 'Design Documents', route: '/db/testdb/design' },
        { label: 'Security', route: '/db/testdb/security' },
        {
          label: 'Revision History',
          route: '',
          disabled: true,
          tooltip: 'Select a document first to view its revisions',
        },
      ];
      fixture.detectChanges();
      const disabledSpan = fixture.nativeElement.querySelector(
        'span.nav-link--disabled',
      ) as HTMLElement | null;
      expect(disabledSpan).toBeTruthy();
      expect(disabledSpan?.textContent?.trim()).toBe('Revision History');
      expect(disabledSpan?.getAttribute('aria-disabled')).toBe('true');
      expect(disabledSpan?.getAttribute('title')).toContain('Select a document');
    });

    it('renders an enabled Revision History link when docId is in scope', () => {
      component.items = [
        { label: 'Documents', route: '/db/testdb' },
        { label: 'Design Documents', route: '/db/testdb/design' },
        { label: 'Security', route: '/db/testdb/security' },
        { label: 'Revision History', route: '/db/testdb/doc/doc1/revisions' },
      ];
      fixture.detectChanges();
      const links = fixture.nativeElement.querySelectorAll('a.nav-link');
      const revLink = Array.from(links).find(
        (a: any) => a.textContent.trim() === 'Revision History',
      ) as HTMLAnchorElement | undefined;
      expect(revLink).toBeTruthy();
      expect(revLink!.getAttribute('href')).toBe('/db/testdb/doc/doc1/revisions');
    });

    it('is axe-clean with a disabled Revision History entry', async () => {
      component.items = [
        { label: 'Documents', route: '/db/testdb' },
        {
          label: 'Revision History',
          route: '',
          disabled: true,
          tooltip: 'Select a document first to view its revisions',
        },
      ];
      fixture.detectChanges();
      await expectNoAxeViolations(fixture.nativeElement);
    });
  });

  // Story 12.0 AC #2 — SideNav per-db entries are now produced from a typed
  // config array. Verify that appending a fifth entry to the config (without
  // any template edit) flows through to an additional `<li>` with the right
  // attributes. This is the regression that makes future epic additions
  // one-line appends.
  describe('per-database scope — config-driven rendering (Story 12.0)', () => {
    it('canonical NAV_ENTRY_CONFIG produces the expected four entries', () => {
      expect(NAV_ENTRY_CONFIG.map((e) => e.id)).toEqual([
        'documents',
        'design-documents',
        'security',
        'revision-history',
      ]);
    });

    it('appending a config entry renders an additional <li> with correct attributes', () => {
      // Arrange: extend the canonical config with a synthetic fifth entry.
      const extendedConfig: PerDbNavEntry[] = [
        ...NAV_ENTRY_CONFIG,
        {
          id: 'stats',
          label: 'Stats',
          route: (ctx) => `/db/${ctx.dbName}/stats`,
          enabled: () => true,
        },
      ];
      component.navEntryConfig = extendedConfig;

      // Act: trigger the per-db scope with a URL carrying a doc ID so the
      // Revision History entry is also enabled (the original four all render
      // as <a>s; the fifth appends at the end).
      const router = TestBed.inject(Router);
      spyOnProperty(router, 'url', 'get').and.returnValue('/db/testdb/doc/d1');
      (component as any).updateNavScope();
      fixture.detectChanges();

      const listItems = fixture.nativeElement.querySelectorAll('li.nav-item');
      expect(listItems.length).toBe(5);

      const anchors = fixture.nativeElement.querySelectorAll('a.nav-link');
      const labels = Array.from(anchors).map((a: any) => a.textContent.trim());
      expect(labels).toEqual([
        'Documents',
        'Design Documents',
        'Security',
        'Revision History',
        'Stats',
      ]);

      const statsLink = Array.from(anchors).find(
        (a: any) => a.textContent.trim() === 'Stats',
      ) as HTMLAnchorElement | undefined;
      expect(statsLink).toBeTruthy();
      expect(statsLink!.getAttribute('href')).toBe('/db/testdb/stats');
    });

    it('disabled-with-tooltip branch survives the refactor for Revision History', () => {
      // Simulate a per-db scope with no doc in URL -> Revision History should
      // remain disabled with the Story 11.4 tooltip text.
      const router = TestBed.inject(Router);
      spyOnProperty(router, 'url', 'get').and.returnValue('/db/testdb');
      (component as any).updateNavScope();
      fixture.detectChanges();

      const disabled = fixture.nativeElement.querySelector(
        'span.nav-link--disabled',
      ) as HTMLElement | null;
      expect(disabled).toBeTruthy();
      expect(disabled?.textContent?.trim()).toBe('Revision History');
      expect(disabled?.getAttribute('aria-disabled')).toBe('true');
      expect(disabled?.getAttribute('title')).toBe(
        'Select a document first to view its revisions',
      );
    });
  });
});
