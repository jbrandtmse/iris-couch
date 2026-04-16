import { TestBed, ComponentFixture } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { provideRouter, ActivatedRoute, convertToParamMap, Router } from '@angular/router';
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

    it('has no axe-core violations in edit-clean state', async () => {
      fixture.detectChanges();
      expectGetRequest('testdb', '_design/myapp').flush({
        _id: '_design/myapp',
        _rev: '1-abc',
        language: 'javascript',
      });
      fixture.detectChanges();
      component.onEdit();
      fixture.detectChanges();
      await expectNoAxeViolations(fixture.nativeElement);
    });
  });

  // -------------- Story 11.3 -- edit/save/delete --------------

  describe('Edit mode (AC #2)', () => {
    beforeEach(async () => {
      await configure({ dbname: 'testdb', ddocid: 'myapp' });
      fixture.detectChanges();
      expectGetRequest('testdb', '_design/myapp').flush({
        _id: '_design/myapp',
        _rev: '1-abc',
        language: 'javascript',
        views: { by_name: { map: 'function(){}' } },
      });
      fixture.detectChanges();
    });

    it('shows Edit + Delete buttons in view mode', () => {
      const buttons = Array.from(fixture.nativeElement.querySelectorAll('app-button'));
      expect(buttons.length).toBeGreaterThanOrEqual(2);
    });

    it('switches to edit mode and pre-fills body without _id/_rev', () => {
      component.onEdit();
      fixture.detectChanges();
      expect(component.mode).toBe('edit');
      const ta = fixture.nativeElement.querySelector('app-text-area-json');
      expect(ta).toBeTruthy();
      expect(component.editValue).toContain('"language"');
      expect(component.editValue).not.toContain('"_id"');
      expect(component.editValue).not.toContain('"_rev"');
    });

    it('PUTs the body with ?rev= on Save and re-fetches on success', () => {
      component.onEdit();
      fixture.detectChanges();
      // Mutate the editor body
      component.editValue = '{"language":"javascript","views":{"a":{"map":"function(){}"}}}';
      component.editValid = true;
      component.onSave();
      const putReq = httpMock.expectOne(
        (r) => r.url === 'testdb/_design/myapp?rev=1-abc' && r.method === 'PUT',
      );
      expect(putReq.request.body).toEqual({
        language: 'javascript',
        views: { a: { map: 'function(){}' } },
      });
      putReq.flush({ ok: true, id: '_design/myapp', rev: '2-def' });
      // After save success the component re-fetches to refresh the rev/body.
      const refetch = expectGetRequest('testdb', '_design/myapp');
      refetch.flush({
        _id: '_design/myapp',
        _rev: '2-def',
        language: 'javascript',
        views: { a: { map: 'function(){}' } },
      });
      fixture.detectChanges();
      expect(component.mode).toBe('view');
      expect(component.doc._rev).toBe('2-def');
      expect(component.saving).toBeFalse();
    });

    it('shows inline FeatureError on save failure (409 conflict) and stays in edit mode', () => {
      component.onEdit();
      fixture.detectChanges();
      component.editValue = '{"language":"javascript"}';
      component.editValid = true;
      component.onSave();
      httpMock
        .expectOne((r) => r.url === 'testdb/_design/myapp?rev=1-abc' && r.method === 'PUT')
        .flush(
          { error: 'conflict', reason: 'Document update conflict.' },
          { status: 409, statusText: 'Conflict' },
        );
      fixture.detectChanges();
      expect(component.mode).toBe('edit');
      expect(component.saveError).toEqual({
        error: 'conflict',
        reason: 'Document update conflict.',
      });
      expect(component.saveErrorStatus).toBe(409);
      expect(component.saving).toBeFalse();
    });

    it('Cancel without changes returns to view mode without prompt', () => {
      component.onEdit();
      fixture.detectChanges();
      // No edit baseline drift -> not dirty.
      expect(component.hasUnsavedChanges()).toBeFalse();
      component.onCancel();
      fixture.detectChanges();
      expect(component.mode).toBe('view');
      expect(component.showDiscardDialog).toBeFalse();
    });

    it('Cancel with dirty state opens the warning dialog and keeps edit mode on cancel', async () => {
      component.onEdit();
      fixture.detectChanges();
      component.editValue = component.editValue + '\n// dirty';
      expect(component.hasUnsavedChanges()).toBeTrue();
      const cancelP = (component as any).onCancel();
      fixture.detectChanges();
      expect(component.showDiscardDialog).toBeTrue();
      // User cancels the discard prompt -> stay in edit mode.
      component.onDiscardCancelled();
      fixture.detectChanges();
      // Allow the awaited promise to settle if returned.
      await Promise.resolve();
      expect(component.showDiscardDialog).toBeFalse();
      expect(component.mode).toBe('edit');
      void cancelP;
    });

    it('Cancel with dirty state + Discard exits edit mode', async () => {
      component.onEdit();
      fixture.detectChanges();
      component.editValue = component.editValue + 'oops';
      component.onCancel();
      fixture.detectChanges();
      component.onDiscardConfirmed();
      // Wait one microtask so the .then() fires.
      await Promise.resolve();
      await Promise.resolve();
      fixture.detectChanges();
      expect(component.mode).toBe('view');
    });
  });

  describe('Delete (AC #4)', () => {
    beforeEach(async () => {
      await configure({ dbname: 'testdb', ddocid: 'myapp' });
      fixture.detectChanges();
      expectGetRequest('testdb', '_design/myapp').flush({
        _id: '_design/myapp',
        _rev: '1-abc',
      });
      fixture.detectChanges();
    });

    it('opens the type-to-confirm dialog on Delete click', () => {
      component.onDeleteClick();
      fixture.detectChanges();
      expect(component.showDeleteDialog).toBeTrue();
      const dialog = fixture.nativeElement.querySelector('app-confirm-dialog');
      expect(dialog).toBeTruthy();
    });

    it('issues DELETE with ?rev= on confirm and routes back to /db/:dbname/design', () => {
      const router = TestBed.inject(Router);
      const navSpy = spyOn(router, 'navigate');
      component.onDeleteClick();
      fixture.detectChanges();
      component.onDeleteConfirmed();
      const req = httpMock.expectOne(
        (r) => r.url === 'testdb/_design/myapp?rev=1-abc' && r.method === 'DELETE',
      );
      req.flush({ ok: true, id: '_design/myapp', rev: '2-def' });
      fixture.detectChanges();
      expect(component.deleting).toBeFalse();
      expect(component.showDeleteDialog).toBeFalse();
      expect(navSpy).toHaveBeenCalledWith(['/db', 'testdb', 'design']);
    });

    it('shows inline error in dialog on DELETE failure and keeps dialog open', () => {
      component.onDeleteClick();
      fixture.detectChanges();
      component.onDeleteConfirmed();
      httpMock
        .expectOne(
          (r) => r.url === 'testdb/_design/myapp?rev=1-abc' && r.method === 'DELETE',
        )
        .flush(
          { error: 'forbidden', reason: 'You may not delete this design document.' },
          { status: 403, statusText: 'Forbidden' },
        );
      fixture.detectChanges();
      expect(component.deleting).toBeFalse();
      expect(component.showDeleteDialog).toBeTrue();
      expect(component.deleteError).toEqual({
        error: 'forbidden',
        reason: 'You may not delete this design document.',
      });
      expect(component.deleteErrorStatus).toBe(403);
    });

    it('cancels delete dialog cleanly', () => {
      component.onDeleteClick();
      fixture.detectChanges();
      component.onDeleteCancelled();
      fixture.detectChanges();
      expect(component.showDeleteDialog).toBeFalse();
      expect(component.deleteError).toBeNull();
    });
  });

  // Story 11.3 AC #7 — Esc key in edit mode triggers Cancel flow.
  describe('Esc key handling in edit mode (AC #7)', () => {
    beforeEach(async () => {
      await configure({ dbname: 'testdb', ddocid: 'myapp' });
      fixture.detectChanges();
      expectGetRequest('testdb', '_design/myapp').flush({
        _id: '_design/myapp',
        _rev: '1-abc',
        language: 'javascript',
      });
      fixture.detectChanges();
    });

    it('Esc in view mode does nothing', () => {
      document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }));
      fixture.detectChanges();
      expect(component.mode).toBe('view');
      expect(component.showDiscardDialog).toBeFalse();
    });

    it('Esc in clean edit mode exits to view without prompt', () => {
      component.onEdit();
      fixture.detectChanges();
      document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }));
      fixture.detectChanges();
      expect(component.mode).toBe('view');
      expect(component.showDiscardDialog).toBeFalse();
    });

    it('Esc in dirty edit mode opens the discard-changes warning', () => {
      component.onEdit();
      fixture.detectChanges();
      component.editValue = component.editValue + ' ';
      document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }));
      fixture.detectChanges();
      expect(component.showDiscardDialog).toBeTrue();
      expect(component.mode).toBe('edit');
    });

    it('Esc is ignored while saving', () => {
      component.onEdit();
      (component as any).saving = true;
      fixture.detectChanges();
      document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }));
      fixture.detectChanges();
      expect(component.mode).toBe('edit');
      expect(component.showDiscardDialog).toBeFalse();
    });
  });

  describe('CanDeactivate guard contract (AC #7)', () => {
    beforeEach(async () => {
      await configure({ dbname: 'testdb', ddocid: 'myapp' });
      fixture.detectChanges();
      expectGetRequest('testdb', '_design/myapp').flush({
        _id: '_design/myapp',
        _rev: '1-abc',
        language: 'javascript',
      });
      fixture.detectChanges();
    });

    it('hasUnsavedChanges() is false outside edit mode', () => {
      expect(component.hasUnsavedChanges()).toBeFalse();
    });

    it('hasUnsavedChanges() is false in edit mode with no edits', () => {
      component.onEdit();
      expect(component.hasUnsavedChanges()).toBeFalse();
    });

    it('hasUnsavedChanges() is true in edit mode after a value change', () => {
      component.onEdit();
      component.editValue = component.editValue + ' ';
      expect(component.hasUnsavedChanges()).toBeTrue();
    });

    it('confirmDiscard() returns a Promise that resolves on dialog action', async () => {
      component.onEdit();
      component.editValue = component.editValue + ' ';
      const p = component.confirmDiscard();
      expect(component.showDiscardDialog).toBeTrue();
      component.onDiscardConfirmed();
      const r = await p;
      expect(r).toBeTrue();
    });
  });
});

