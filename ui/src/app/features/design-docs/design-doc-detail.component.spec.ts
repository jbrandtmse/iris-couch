import { TestBed, ComponentFixture } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { provideRouter, ActivatedRoute, convertToParamMap } from '@angular/router';
import { LiveAnnouncer } from '@angular/cdk/a11y';
import { of } from 'rxjs';
import { DesignDocDetailComponent } from './design-doc-detail.component';
import { expectNoAxeViolations } from '../../couch-ui/test-utils';

describe('DesignDocDetailComponent', () => {
  let fixture: ComponentFixture<DesignDocDetailComponent>;
  let component: DesignDocDetailComponent;
  let httpMock: HttpTestingController;
  let announcerSpy: jasmine.SpyObj<LiveAnnouncer>;

  /** Build a TestBed with a given route param payload. */
  async function configure(params: Record<string, string>) {
    announcerSpy = jasmine.createSpyObj('LiveAnnouncer', ['announce']);
    announcerSpy.announce.and.returnValue(Promise.resolve());

    const routeStub = {
      paramMap: of(convertToParamMap(params)),
      snapshot: { paramMap: convertToParamMap(params) },
    } as unknown as ActivatedRoute;

    await TestBed.configureTestingModule({
      imports: [DesignDocDetailComponent],
      providers: [
        provideHttpClient(),
        provideHttpClientTesting(),
        provideRouter([]),
        { provide: LiveAnnouncer, useValue: announcerSpy },
        { provide: ActivatedRoute, useValue: routeStub },
      ],
    }).compileComponents();

    httpMock = TestBed.inject(HttpTestingController);
    fixture = TestBed.createComponent(DesignDocDetailComponent);
    component = fixture.componentInstance;
  }

  afterEach(() => {
    httpMock.verify();
  });

  function expectGetRequest(db: string, composite: string) {
    return httpMock.expectOne(
      (r) =>
        r.url.startsWith(`${db}/${composite}`) &&
        !r.url.includes('%2F') &&
        r.url.includes('conflicts=true'),
    );
  }

  describe('Successful load (AC #2, AC #3)', () => {
    beforeEach(async () => {
      await configure({ dbname: 'testdb', ddocid: 'myapp' });
    });

    it('loads on init using `_design/<name>` composite ID', () => {
      fixture.detectChanges();
      expect(component.loading).toBeTrue();
      expect(component.ddocId).toBe('_design/myapp');
      expect(component.ddocShortName).toBe('myapp');

      const mockDoc = {
        _id: '_design/myapp',
        _rev: '1-abc',
        views: { by_name: { map: 'function(doc){emit(doc.name,null);}' } },
      };
      expectGetRequest('testdb', '_design/myapp').flush(mockDoc);
      fixture.detectChanges();

      expect(component.loading).toBeFalse();
      expect(component.doc).toEqual(mockDoc);
      expect(component.rawJson).toContain('"views"');
      expect(component.fetchedAt).toBeTruthy();
    });

    it('renders the JsonDisplay body', () => {
      fixture.detectChanges();
      expectGetRequest('testdb', '_design/myapp').flush({
        _id: '_design/myapp',
        _rev: '1-abc',
        language: 'javascript',
      });
      fixture.detectChanges();
      const jsonDisplay = fixture.nativeElement.querySelector('app-json-display');
      expect(jsonDisplay).toBeTruthy();
    });

    it('renders two CopyButton affordances (AC #4): _id and _rev', () => {
      fixture.detectChanges();
      expectGetRequest('testdb', '_design/myapp').flush({
        _id: '_design/myapp',
        _rev: '1-abc',
      });
      fixture.detectChanges();
      const copies = fixture.nativeElement.querySelectorAll('app-copy-button');
      // Two on the identity rows; JsonDisplay may have its own internal copy
      // which is why we check >= 2 rather than strict equality.
      expect(copies.length).toBeGreaterThanOrEqual(2);
    });

    it('sets breadcrumbs with short name as the terminal crumb', () => {
      fixture.detectChanges();
      expectGetRequest('testdb', '_design/myapp').flush({
        _id: '_design/myapp',
        _rev: '1-abc',
      });
      expect(component.breadcrumbs.length).toBe(4);
      expect(component.breadcrumbs[3].label).toBe('myapp');
      expect(component.breadcrumbs[2].label).toBe('Design documents');
    });
  });

  describe('Deep-link entry (AC #3)', () => {
    it('renders correctly when entered directly via the URL (no list navigation)', async () => {
      await configure({ dbname: 'prod-db', ddocid: 'queries' });
      fixture.detectChanges();
      expectGetRequest('prod-db', '_design/queries').flush({
        _id: '_design/queries',
        _rev: '2-xyz',
      });
      fixture.detectChanges();
      expect(component.doc).toBeTruthy();
      expect(component.ddocId).toBe('_design/queries');
    });

    it('normalizes a ddocid param that already contains the `_design/` prefix', async () => {
      await configure({ dbname: 'testdb', ddocid: '_design/already-prefixed' });
      fixture.detectChanges();
      expect(component.ddocId).toBe('_design/already-prefixed');
      expect(component.ddocShortName).toBe('already-prefixed');
      expectGetRequest('testdb', '_design/already-prefixed').flush({
        _id: '_design/already-prefixed',
        _rev: '1-a',
      });
    });
  });

  describe('404 error state (AC #6)', () => {
    beforeEach(async () => {
      await configure({ dbname: 'testdb', ddocid: 'missing' });
    });

    it('renders FeatureError with the verbatim backend envelope', () => {
      fixture.detectChanges();
      expectGetRequest('testdb', '_design/missing').flush(
        { error: 'not_found', reason: 'missing' },
        { status: 404, statusText: 'Object Not Found' },
      );
      fixture.detectChanges();

      expect(component.loading).toBeFalse();
      expect(component.doc).toBeNull();
      expect(component.error).toEqual({ error: 'not_found', reason: 'missing' });
      expect(component.errorStatus).toBe(404);

      const featureError = fixture.nativeElement.querySelector('app-feature-error');
      expect(featureError).toBeTruthy();
    });

    it('retries on feature-error (retry) event', () => {
      fixture.detectChanges();
      expectGetRequest('testdb', '_design/missing').flush(
        { error: 'not_found', reason: 'missing' },
        { status: 404, statusText: 'Object Not Found' },
      );
      fixture.detectChanges();

      component.onRefresh();
      expectGetRequest('testdb', '_design/missing').flush({
        _id: '_design/missing',
        _rev: '1-a',
      });
      fixture.detectChanges();
      expect(component.error).toBeNull();
      expect(component.doc).toBeTruthy();
    });
  });

  describe('Subscription discipline', () => {
    beforeEach(async () => {
      await configure({ dbname: 'testdb', ddocid: 'myapp' });
    });

    it('unsubscribes active request on destroy without leaving pending callbacks', () => {
      fixture.detectChanges();
      const req = expectGetRequest('testdb', '_design/myapp');
      expect(component['activeRequest']).toBeDefined();
      fixture.destroy();
      // After destroy, the component's active subscription should be closed
      // so any late response does not mutate state. We flush a response and
      // assert the document field stays null.
      try {
        req.flush({ _id: '_design/myapp', _rev: '9-late' });
      } catch {
        /* angular test may throw on cancelled request -- that is expected */
      }
      expect(component.doc).toBeNull();
    });
  });

  describe('Accessibility', () => {
    beforeEach(async () => {
      await configure({ dbname: 'testdb', ddocid: 'myapp' });
    });

    it('has no axe-core violations in success state', async () => {
      fixture.detectChanges();
      expectGetRequest('testdb', '_design/myapp').flush({
        _id: '_design/myapp',
        _rev: '1-abc',
        views: { by_name: { map: 'function(){}' } },
      });
      fixture.detectChanges();
      await expectNoAxeViolations(fixture.nativeElement);
    });

    it('has no axe-core violations in error state', async () => {
      fixture.detectChanges();
      expectGetRequest('testdb', '_design/myapp').flush(
        { error: 'not_found', reason: 'missing' },
        { status: 404, statusText: 'Object Not Found' },
      );
      fixture.detectChanges();
      await expectNoAxeViolations(fixture.nativeElement);
    });
  });
});
