import { TestBed, ComponentFixture } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { provideRouter, Router, ActivatedRoute, convertToParamMap } from '@angular/router';
import { LiveAnnouncer } from '@angular/cdk/a11y';
import { of } from 'rxjs';
import { DesignDocListComponent } from './design-doc-list.component';
import { expectNoAxeViolations } from '../../couch-ui/test-utils';

describe('DesignDocListComponent', () => {
  let fixture: ComponentFixture<DesignDocListComponent>;
  let component: DesignDocListComponent;
  let httpMock: HttpTestingController;
  let router: Router;
  let announcerSpy: jasmine.SpyObj<LiveAnnouncer>;

  const activatedRouteStub = {
    paramMap: of(convertToParamMap({ dbname: 'testdb' })),
    snapshot: { paramMap: convertToParamMap({ dbname: 'testdb' }) },
  } as unknown as ActivatedRoute;

  beforeEach(async () => {
    announcerSpy = jasmine.createSpyObj('LiveAnnouncer', ['announce']);
    announcerSpy.announce.and.returnValue(Promise.resolve());

    await TestBed.configureTestingModule({
      imports: [DesignDocListComponent],
      providers: [
        provideHttpClient(),
        provideHttpClientTesting(),
        provideRouter([]),
        { provide: LiveAnnouncer, useValue: announcerSpy },
        { provide: ActivatedRoute, useValue: activatedRouteStub },
      ],
    }).compileComponents();

    httpMock = TestBed.inject(HttpTestingController);
    router = TestBed.inject(Router);
    spyOn(router, 'navigate').and.returnValue(Promise.resolve(true));

    fixture = TestBed.createComponent(DesignDocListComponent);
    component = fixture.componentInstance;
  });

  afterEach(() => {
    httpMock.verify();
  });

  function expectListRequest() {
    return httpMock.expectOne(
      (r) =>
        r.url.startsWith('testdb/_all_docs') &&
        r.url.includes('startkey=%22_design%2F%22') &&
        r.url.includes('endkey=%22_design0%22'),
    );
  }

  describe('Initial load (AC #1)', () => {
    it('starts loading on init', () => {
      fixture.detectChanges();
      expect(component.loading).toBeTrue();
      expectListRequest().flush({ total_rows: 0, offset: 0, rows: [] });
    });

    it('fetches design docs via listDesignDocs and stops loading', () => {
      fixture.detectChanges();
      expectListRequest().flush({
        total_rows: 2,
        offset: 0,
        rows: [
          { id: '_design/myapp', key: '_design/myapp', value: { rev: '1-aaa' } },
          { id: '_design/otherapp', key: '_design/otherapp', value: { rev: '1-bbb' } },
        ],
      });
      fixture.detectChanges();
      expect(component.loading).toBeFalse();
      expect(component.rows.length).toBe(2);
      expect(component.rows[0].id).toBe('_design/myapp');
      expect(component.fetchedAt).toBeTruthy();
    });

    it('renders a DataTable when design docs exist', () => {
      fixture.detectChanges();
      expectListRequest().flush({
        total_rows: 1,
        offset: 0,
        rows: [{ id: '_design/myapp', key: '_design/myapp', value: { rev: '1-aaa' } }],
      });
      fixture.detectChanges();
      const table = fixture.nativeElement.querySelector('app-data-table');
      expect(table).toBeTruthy();
    });
  });

  describe('Empty state (AC #5)', () => {
    it('renders empty state with the AC-specified copy', () => {
      fixture.detectChanges();
      expectListRequest().flush({ total_rows: 0, offset: 0, rows: [] });
      fixture.detectChanges();

      const empty = fixture.nativeElement.querySelector('app-empty-state');
      expect(empty).toBeTruthy();
      const text = (fixture.nativeElement as HTMLElement).textContent || '';
      expect(text).toContain('No design documents yet.');
      // Story 11.3 replaced the alpha "use curl" copy with the in-app Create
      // affordance; the secondary line now points users at the Create button.
      expect(text).toContain('Use Create to add one.');
    });

    it('does not render the DataTable when empty', () => {
      fixture.detectChanges();
      expectListRequest().flush({ total_rows: 0, offset: 0, rows: [] });
      fixture.detectChanges();
      const table = fixture.nativeElement.querySelector('app-data-table');
      expect(table).toBeFalsy();
    });
  });

  describe('Error state (AC #6)', () => {
    it('renders FeatureError on HTTP 500 and clears rows', () => {
      fixture.detectChanges();
      expectListRequest().flush(
        { error: 'internal_server_error', reason: 'boom' },
        { status: 500, statusText: 'Internal Server Error' },
      );
      fixture.detectChanges();
      expect(component.loading).toBeFalse();
      expect(component.loadError).toEqual({ error: 'internal_server_error', reason: 'boom' });
      expect(component.loadErrorCode).toBe(500);
      expect(component.rows.length).toBe(0);

      const featureError = fixture.nativeElement.querySelector('app-feature-error');
      expect(featureError).toBeTruthy();
    });

    it('retries on feature-error (retry) output', () => {
      fixture.detectChanges();
      expectListRequest().flush(
        { error: 'internal_server_error', reason: 'boom' },
        { status: 500, statusText: 'Internal Server Error' },
      );
      fixture.detectChanges();

      component.loadDesignDocs();
      expectListRequest().flush({ total_rows: 0, offset: 0, rows: [] });
      fixture.detectChanges();
      expect(component.loadError).toBeNull();
    });
  });

  describe('Row click navigation', () => {
    it('navigates to /db/{dbname}/design/<short-name> on row click (plain name)', () => {
      fixture.detectChanges();
      expectListRequest().flush({
        total_rows: 1,
        offset: 0,
        rows: [{ id: '_design/myapp', key: '_design/myapp', value: { rev: '1-aaa' } }],
      });
      fixture.detectChanges();

      component.onRowClick({ id: '_design/myapp', rev: '1-aaa' });
      expect(router.navigate).toHaveBeenCalledWith(['/db', 'testdb', 'design', 'myapp']);
    });

    it('splits multi-segment short names into separate route segments', () => {
      component.dbName = 'testdb';
      component.onRowClick({ id: '_design/nested/thing', rev: '1-aaa' });
      // Defensive — CouchDB forbids `/` in design doc short names, but if
      // the wire somehow returned one the matcher-based route would still
      // reassemble it. We pass separate segments to the router so Angular
      // does not percent-encode the inner `/`.
      expect(router.navigate).toHaveBeenCalledWith(['/db', 'testdb', 'design', 'nested', 'thing']);
    });

    it('ignores empty ids', () => {
      component.onRowClick({ id: '', rev: '' });
      expect(router.navigate).not.toHaveBeenCalled();
    });

    it('refuses to navigate for ids that do not start with `_design/`', () => {
      // Defensive guard: list-view rows always come from listDesignDocs so
      // this case should be unreachable in practice, but we refuse to
      // produce a nonsensical /db/.../design/<arbitrary> URL.
      component.dbName = 'testdb';
      component.onRowClick({ id: 'regular-doc', rev: '1-aaa' });
      expect(router.navigate).not.toHaveBeenCalled();
    });

    it('refuses to navigate for bare `_design/` prefix with no name', () => {
      component.dbName = 'testdb';
      component.onRowClick({ id: '_design/', rev: '1-aaa' });
      expect(router.navigate).not.toHaveBeenCalled();
    });
  });

  describe('Subscription discipline (Story 11.0 rule)', () => {
    it('stale callback does not overwrite fresh data when a new request supersedes', () => {
      fixture.detectChanges();
      // Don't flush the first request yet
      const first = expectListRequest();

      // Trigger a second request
      component.loadDesignDocs();

      // First response should have been cancelled; the second one drives state
      const second = expectListRequest();
      second.flush({
        total_rows: 1,
        offset: 0,
        rows: [{ id: '_design/second', key: '_design/second', value: { rev: '1-xxx' } }],
      });

      // First response now arrives late; callback should not fire because the
      // subscription has been unsubscribed.
      try {
        first.flush({
          total_rows: 1,
          offset: 0,
          rows: [{ id: '_design/first', key: '_design/first', value: { rev: '1-yyy' } }],
        });
      } catch {
        /* angular httptest may throw on cancelled request — ignore */
      }

      expect(component.rows.length).toBe(1);
      expect(component.rows[0].id).toBe('_design/second');
    });

    it('unsubscribes active request on destroy', () => {
      fixture.detectChanges();
      const req = expectListRequest();
      expect(component['activeRequest']).toBeDefined();
      // Destroying the component should cancel the in-flight HTTP request so
      // late responses cannot mutate state.
      fixture.destroy();
      try {
        req.flush({
          total_rows: 1,
          offset: 0,
          rows: [{ id: '_design/late', key: '_design/late', value: { rev: '9-late' } }],
        });
      } catch {
        /* angular test may throw on cancelled request -- expected */
      }
      expect(component.rows.length).toBe(0);
    });
  });

  describe('Accessibility', () => {
    it('has no axe-core violations in populated state', async () => {
      fixture.detectChanges();
      expectListRequest().flush({
        total_rows: 1,
        offset: 0,
        rows: [{ id: '_design/myapp', key: '_design/myapp', value: { rev: '1-aaa' } }],
      });
      fixture.detectChanges();
      await expectNoAxeViolations(fixture.nativeElement);
    });

    it('has no axe-core violations in empty state', async () => {
      fixture.detectChanges();
      expectListRequest().flush({ total_rows: 0, offset: 0, rows: [] });
      fixture.detectChanges();
      await expectNoAxeViolations(fixture.nativeElement);
    });
  });

  // ---------------- Story 11.3 Task 3 -- Create dialog ----------------

  describe('Create dialog (AC #3)', () => {
    function loadEmpty() {
      fixture.detectChanges();
      expectListRequest().flush({ total_rows: 0, offset: 0, rows: [] });
      fixture.detectChanges();
    }

    function loadWith(rows: Array<{ id: string; rev: string }>) {
      fixture.detectChanges();
      expectListRequest().flush({
        total_rows: rows.length,
        offset: 0,
        rows: rows.map((r) => ({ id: r.id, key: r.id, value: { rev: r.rev } })),
      });
      fixture.detectChanges();
    }

    it('opens the dialog on Create button click', () => {
      loadEmpty();
      component.openCreateDialog();
      fixture.detectChanges();
      const dialog = fixture.nativeElement.querySelector('app-design-doc-create-dialog');
      expect(dialog).toBeTruthy();
      expect(component.showCreateDialog).toBeTrue();
    });

    it('PUTs /db/_design/<name> on confirm and refreshes the list', () => {
      loadEmpty();
      component.openCreateDialog();
      fixture.detectChanges();
      component.onCreateConfirmed({ name: 'newapp', body: { language: 'javascript', views: {} } });
      const putReq = httpMock.expectOne(
        (r) => r.url === 'testdb/_design/newapp' && r.method === 'PUT',
      );
      expect(putReq.request.body).toEqual({ language: 'javascript', views: {} });
      putReq.flush({ ok: true, id: '_design/newapp', rev: '1-abc' });
      // After success, dialog closes and list refreshes
      expectListRequest().flush({
        total_rows: 1,
        offset: 0,
        rows: [{ id: '_design/newapp', key: '_design/newapp', value: { rev: '1-abc' } }],
      });
      fixture.detectChanges();
      expect(component.creating).toBeFalse();
      expect(component.showCreateDialog).toBeFalse();
    });

    it('keeps dialog open and shows error on 409 conflict', () => {
      loadEmpty();
      component.openCreateDialog();
      fixture.detectChanges();
      component.onCreateConfirmed({ name: 'dup', body: {} });
      httpMock
        .expectOne((r) => r.url === 'testdb/_design/dup' && r.method === 'PUT')
        .flush(
          { error: 'conflict', reason: 'Document update conflict.' },
          { status: 409, statusText: 'Conflict' },
        );
      fixture.detectChanges();
      expect(component.showCreateDialog).toBeTrue();
      expect(component.creating).toBeFalse();
      expect(component.createError).toEqual({
        error: 'conflict',
        reason: 'Document update conflict.',
      });
      expect(component.createErrorStatus).toBe(409);
    });

    it('cancels the dialog cleanly', () => {
      loadEmpty();
      component.openCreateDialog();
      fixture.detectChanges();
      component.onCreateCancelled();
      fixture.detectChanges();
      expect(component.showCreateDialog).toBeFalse();
    });

    it('exposes existing short names for the dialog name validator', () => {
      loadWith([
        { id: '_design/alpha', rev: '1-a' },
        { id: '_design/beta', rev: '1-b' },
      ]);
      expect(component.existingShortNames).toEqual(['alpha', 'beta']);
    });
  });
});
