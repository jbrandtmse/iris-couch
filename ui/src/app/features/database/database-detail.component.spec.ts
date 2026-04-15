import { TestBed, ComponentFixture, fakeAsync, tick, discardPeriodicTasks } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { provideRouter, Router, ActivatedRoute, convertToParamMap, ParamMap } from '@angular/router';
import { LiveAnnouncer } from '@angular/cdk/a11y';
import { BehaviorSubject } from 'rxjs';
import { DatabaseDetailComponent } from './database-detail.component';
import { AllDocsResponse } from '../../services/document.service';
import { expectNoAxeViolations } from '../../couch-ui/test-utils';

describe('DatabaseDetailComponent', () => {
  let fixture: ComponentFixture<DatabaseDetailComponent>;
  let component: DatabaseDetailComponent;
  let httpMock: HttpTestingController;
  let router: Router;
  let announcerSpy: jasmine.SpyObj<LiveAnnouncer>;

  const paramMapSubject = new BehaviorSubject<ParamMap>(
    convertToParamMap({ dbname: 'testdb' })
  );

  const mockResponse: AllDocsResponse = {
    total_rows: 100,
    offset: 0,
    rows: [
      { id: 'doc1', key: 'doc1', value: { rev: '1-abcdefgh12345678' } },
      { id: 'doc2', key: 'doc2', value: { rev: '2-xyz98765' } },
      { id: '_design/myview', key: '_design/myview', value: { rev: '1-design111' } },
    ],
  };

  const deletedDocResponse: AllDocsResponse = {
    total_rows: 50,
    offset: 0,
    rows: [
      { id: 'active-doc', key: 'active-doc', value: { rev: '1-active12' } },
      { id: 'deleted-doc', key: 'deleted-doc', value: { rev: '3-deleted1', deleted: true } },
    ],
  };

  beforeEach(async () => {
    announcerSpy = jasmine.createSpyObj('LiveAnnouncer', ['announce']);
    announcerSpy.announce.and.returnValue(Promise.resolve());

    await TestBed.configureTestingModule({
      imports: [DatabaseDetailComponent],
      providers: [
        provideHttpClient(),
        provideHttpClientTesting(),
        provideRouter([]),
        {
          provide: ActivatedRoute,
          useValue: {
            paramMap: paramMapSubject.asObservable(),
            snapshot: { queryParams: {} },
          },
        },
        { provide: LiveAnnouncer, useValue: announcerSpy },
      ],
    }).compileComponents();

    httpMock = TestBed.inject(HttpTestingController);
    router = TestBed.inject(Router);
    spyOn(router, 'navigate').and.callFake(() => Promise.resolve(true));

    fixture = TestBed.createComponent(DatabaseDetailComponent);
    component = fixture.componentInstance;
  });

  afterEach(() => {
    httpMock.verify();
  });

  function flushAllDocs(response: AllDocsResponse = mockResponse): void {
    const req = httpMock.expectOne((r) =>
      r.url.includes('testdb/_all_docs')
    );
    expect(req.request.method).toBe('GET');
    req.flush(response);
    fixture.detectChanges();
  }

  describe('Loading state', () => {
    it('should start loading on init', () => {
      fixture.detectChanges(); // triggers ngOnInit -> loadDocuments
      expect(component.loading).toBeTrue();
      flushAllDocs();
    });

    it('should stop loading after data loads', () => {
      fixture.detectChanges();
      flushAllDocs();
      expect(component.loading).toBeFalse();
    });

    it('should set fetchedAt after loading', () => {
      fixture.detectChanges();
      flushAllDocs();
      expect(component.fetchedAt).toBeTruthy();
    });

    it('should set dbName from route params', () => {
      fixture.detectChanges();
      flushAllDocs();
      expect(component.dbName).toBe('testdb');
    });
  });

  describe('Table rendering', () => {
    it('should render document rows', () => {
      fixture.detectChanges();
      flushAllDocs();
      expect(component.tableData.length).toBe(3);
    });

    it('should display document IDs', () => {
      fixture.detectChanges();
      flushAllDocs();
      const cells = fixture.nativeElement.querySelectorAll('.data-table__cell--id');
      expect(cells.length).toBe(3);
      expect(cells[0].textContent).toContain('doc1');
    });

    it('should truncate _rev to 8 chars', () => {
      fixture.detectChanges();
      flushAllDocs();
      // '1-abcdefgh12345678' truncated to '1-abcdef'
      expect(component.tableData[0].revShort).toBe('1-abcdef');
      expect(component.tableData[0].revShort.length).toBe(8);
    });

    it('should show full rev on hover via title attribute', () => {
      fixture.detectChanges();
      flushAllDocs();
      const revSpans = fixture.nativeElement.querySelectorAll('.rev-text');
      expect(revSpans[0].title).toBe('1-abcdefgh12345678');
    });

    it('should render CopyButton for each row', () => {
      fixture.detectChanges();
      flushAllDocs();
      const copyBtns = fixture.nativeElement.querySelectorAll('app-copy-button');
      expect(copyBtns.length).toBe(3);
    });
  });

  describe('Design document badge', () => {
    it('should mark _design/ docs as design', () => {
      fixture.detectChanges();
      flushAllDocs();
      const designRow = component.tableData.find((r) => r.id === '_design/myview');
      expect(designRow).toBeTruthy();
      expect(designRow!.isDesign).toBeTrue();
    });

    it('should not mark regular docs as design', () => {
      fixture.detectChanges();
      flushAllDocs();
      const regularRow = component.tableData.find((r) => r.id === 'doc1');
      expect(regularRow).toBeTruthy();
      expect(regularRow!.isDesign).toBeFalse();
    });

    it('should show design badge for design docs', () => {
      fixture.detectChanges();
      flushAllDocs();
      const badges = fixture.nativeElement.querySelectorAll('app-badge');
      const designBadges = Array.from(badges as NodeListOf<HTMLElement>).filter(
        (b) => b.textContent?.trim() === 'design'
      );
      expect(designBadges.length).toBe(1);
    });
  });

  describe('Deleted document handling', () => {
    it('should mark deleted docs', () => {
      fixture.detectChanges();
      flushAllDocs(deletedDocResponse);
      const deletedRow = component.tableData.find((r) => r.id === 'deleted-doc');
      expect(deletedRow).toBeTruthy();
      expect(deletedRow!.deleted).toBeTrue();
    });

    it('should show deleted badge for tombstoned docs', () => {
      fixture.detectChanges();
      flushAllDocs(deletedDocResponse);
      const badges = fixture.nativeElement.querySelectorAll('app-badge');
      const deletedBadges = Array.from(badges as NodeListOf<HTMLElement>).filter(
        (b) => b.textContent?.trim() === 'deleted'
      );
      expect(deletedBadges.length).toBe(1);
    });

    it('should apply deleted row styling', () => {
      fixture.detectChanges();
      flushAllDocs(deletedDocResponse);
      const deletedRows = fixture.nativeElement.querySelectorAll('.data-table__row--deleted');
      expect(deletedRows.length).toBe(1);
    });
  });

  describe('Filter', () => {
    it('should render filter input', () => {
      fixture.detectChanges();
      flushAllDocs();
      const input = fixture.nativeElement.querySelector('#doc-filter');
      expect(input).toBeTruthy();
    });

    it('should show clear button when filter is active', fakeAsync(() => {
      fixture.detectChanges();
      flushAllDocs();

      component.filterText = 'test';
      fixture.detectChanges();
      const clearBtn = fixture.nativeElement.querySelector('.filter-bar__clear');
      expect(clearBtn).toBeTruthy();
      fixture.destroy();
      discardPeriodicTasks();
    }));

    it('should not show clear button when filter is empty', () => {
      fixture.detectChanges();
      flushAllDocs();
      const clearBtn = fixture.nativeElement.querySelector('.filter-bar__clear');
      expect(clearBtn).toBeNull();
    });

    it('should apply filter with debounce', fakeAsync(() => {
      fixture.detectChanges();
      flushAllDocs();

      component.onFilterChange('user');
      tick(100); // Not yet debounced
      httpMock.expectNone((r) =>
        r.url.includes('testdb/_all_docs') && r.url.includes('startkey')
      );

      tick(60); // Total 160ms > 150ms debounce
      const req = httpMock.expectOne((r) =>
        r.url.includes('testdb/_all_docs')
      );
      req.flush(mockResponse);
      fixture.detectChanges();
      fixture.destroy();
      discardPeriodicTasks();
    }));

    it('should clear filter and reload', fakeAsync(() => {
      fixture.detectChanges();
      flushAllDocs();

      component.filterText = 'test';
      component.clearFilter();
      tick(160);
      const req = httpMock.expectOne((r) =>
        r.url.includes('testdb/_all_docs')
      );
      req.flush(mockResponse);
      expect(component.filterText).toBe('');
      fixture.destroy();
      discardPeriodicTasks();
    }));

    it('should show filtered empty state message', () => {
      fixture.detectChanges();
      flushAllDocs({ total_rows: 100, offset: 0, rows: [] });
      // Need filter text for the filtered empty state
      component.filterText = 'nonexist';
      component.tableData = [];
      fixture.detectChanges();
      const emptyState = fixture.nativeElement.querySelector('app-empty-state');
      expect(emptyState).toBeTruthy();
    });
  });

  describe('Pagination', () => {
    it('should detect next page when rows > PAGE_SIZE', () => {
      const manyRows = [];
      for (let i = 0; i < 26; i++) {
        manyRows.push({ id: `doc${String(i).padStart(3, '0')}`, key: `doc${String(i).padStart(3, '0')}`, value: { rev: `1-rev${i}xx` } });
      }
      fixture.detectChanges();
      flushAllDocs({ total_rows: 100, offset: 0, rows: manyRows });
      expect(component.hasNextPage).toBeTrue();
      expect(component.tableData.length).toBe(25);
    });

    it('should not show next page when rows <= PAGE_SIZE', () => {
      fixture.detectChanges();
      flushAllDocs(mockResponse); // only 3 rows
      expect(component.hasNextPage).toBeFalse();
    });

    it('should not show previous page on first load', () => {
      fixture.detectChanges();
      flushAllDocs();
      expect(component.hasPreviousPage).toBeFalse();
    });

    it('should compute pagination range correctly', () => {
      fixture.detectChanges();
      flushAllDocs();
      expect(component.paginationStart).toBe(1);
      expect(component.paginationEnd).toBe(3);
    });

    it('should show pagination component when data exists', () => {
      fixture.detectChanges();
      flushAllDocs();
      const pagination = fixture.nativeElement.querySelector('app-pagination');
      expect(pagination).toBeTruthy();
    });

    it('should navigate to next page', () => {
      const manyRows = [];
      for (let i = 0; i < 26; i++) {
        manyRows.push({ id: `doc${String(i).padStart(3, '0')}`, key: `doc${String(i).padStart(3, '0')}`, value: { rev: `1-rev${i}xx` } });
      }
      fixture.detectChanges();
      flushAllDocs({ total_rows: 100, offset: 0, rows: manyRows });

      component.nextPage();
      const req = httpMock.expectOne((r) =>
        r.url.includes('testdb/_all_docs')
      );
      req.flush({ total_rows: 100, offset: 25, rows: manyRows.slice(0, 3) });
      fixture.detectChanges();

      expect(component.hasPreviousPage).toBeTrue();
    });
  });

  describe('Row click navigation', () => {
    it('should navigate to /db/{dbname}/doc/{docid} on row click', () => {
      fixture.detectChanges();
      flushAllDocs();
      component.onRowClick(component.tableData[0]);
      expect(router.navigate).toHaveBeenCalledWith(['/db', 'testdb', 'doc', 'doc1']);
    });

    it('should navigate on Enter key on a table row', () => {
      fixture.detectChanges();
      flushAllDocs();
      const row = fixture.nativeElement.querySelector('.data-table__row');
      expect(row).toBeTruthy();
      row.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true }));
      expect(router.navigate).toHaveBeenCalled();
    });

    it('should have tabindex=0 on clickable rows', () => {
      fixture.detectChanges();
      flushAllDocs();
      const rows = fixture.nativeElement.querySelectorAll('.data-table__row');
      for (const row of Array.from(rows) as HTMLElement[]) {
        expect(row.getAttribute('tabindex')).toBe('0');
      }
    });
  });

  describe('Breadcrumb', () => {
    it('should show breadcrumbs', () => {
      fixture.detectChanges();
      flushAllDocs();
      const breadcrumb = fixture.nativeElement.querySelector('app-breadcrumb');
      expect(breadcrumb).toBeTruthy();
    });

    it('should have correct breadcrumb segments', () => {
      fixture.detectChanges();
      flushAllDocs();
      expect(component.breadcrumbs.length).toBe(2);
      expect(component.breadcrumbs[0].label).toBe('Databases');
      expect(component.breadcrumbs[0].url).toBe('/databases');
      expect(component.breadcrumbs[1].label).toBe('testdb');
    });
  });

  describe('Error state', () => {
    it('should display ErrorDisplay when request fails with 404', () => {
      fixture.detectChanges();
      const req = httpMock.expectOne((r) => r.url.includes('testdb/_all_docs'));
      req.flush({ error: 'not_found', reason: 'Database not found' }, { status: 404, statusText: 'Not Found' });
      fixture.detectChanges();
      expect(component.loadError).toBeTruthy();
      expect(component.loadErrorCode).toBe(404);
      expect(component.loading).toBeFalse();
      expect(component.tableData.length).toBe(0);
      const errorDisplay = fixture.nativeElement.querySelector('app-error-display');
      expect(errorDisplay).toBeTruthy();
    });

    it('should show ErrorDisplay on 500 error', () => {
      fixture.detectChanges();
      const req = httpMock.expectOne((r) => r.url.includes('testdb/_all_docs'));
      req.flush({ error: 'internal', reason: 'Server error' }, { status: 500, statusText: 'Internal Server Error' });
      fixture.detectChanges();
      expect(component.loadError).toBeTruthy();
      expect(component.loadErrorCode).toBe(500);
      const errorDisplay = fixture.nativeElement.querySelector('app-error-display');
      expect(errorDisplay).toBeTruthy();
    });

    it('should show network error on status 0', () => {
      fixture.detectChanges();
      const req = httpMock.expectOne((r) => r.url.includes('testdb/_all_docs'));
      req.error(new ProgressEvent('error'), { status: 0, statusText: '' });
      fixture.detectChanges();
      expect(component.loadError).toBeTruthy();
      expect(component.loadError!.reason).toContain('Cannot reach');
      expect(component.loadErrorCode).toBeUndefined();
    });

    it('should clear error on successful reload', () => {
      fixture.detectChanges();
      const req1 = httpMock.expectOne((r) => r.url.includes('testdb/_all_docs'));
      req1.flush({ error: 'internal', reason: 'fail' }, { status: 500, statusText: 'Error' });
      fixture.detectChanges();
      expect(component.loadError).toBeTruthy();

      component.loadDocuments();
      const req2 = httpMock.expectOne((r) => r.url.includes('testdb/_all_docs'));
      req2.flush(mockResponse);
      fixture.detectChanges();
      expect(component.loadError).toBeNull();
    });
  });

  describe('Empty state', () => {
    it('should show empty state when no documents', () => {
      fixture.detectChanges();
      flushAllDocs({ total_rows: 0, offset: 0, rows: [] });
      const empty = fixture.nativeElement.querySelector('app-empty-state');
      expect(empty).toBeTruthy();
    });

    it('should not show pagination when no documents', () => {
      fixture.detectChanges();
      flushAllDocs({ total_rows: 0, offset: 0, rows: [] });
      const pagination = fixture.nativeElement.querySelector('app-pagination');
      expect(pagination).toBeNull();
    });
  });

  describe('Keyboard shortcuts', () => {
    it('should focus filter on / key', () => {
      fixture.detectChanges();
      flushAllDocs();
      const input = fixture.nativeElement.querySelector('#doc-filter');
      spyOn(input, 'focus');
      const event = new KeyboardEvent('keydown', { key: '/' });
      document.dispatchEvent(event);
      expect(input.focus).toHaveBeenCalled();
    });

    it('should clear filter on Escape key', fakeAsync(() => {
      fixture.detectChanges();
      flushAllDocs();
      component.filterText = 'test';
      fixture.detectChanges();

      const event = new KeyboardEvent('keydown', { key: 'Escape' });
      document.dispatchEvent(event);
      expect(component.filterText).toBe('');

      tick(160);
      const req = httpMock.expectOne((r) =>
        r.url.includes('testdb/_all_docs')
      );
      req.flush(mockResponse);
      fixture.destroy();
      discardPeriodicTasks();
    }));
  });

  describe('Page header', () => {
    it('should display database name as title', () => {
      fixture.detectChanges();
      flushAllDocs();
      const header = fixture.nativeElement.querySelector('app-page-header');
      expect(header).toBeTruthy();
    });

    it('should reload on refresh', () => {
      fixture.detectChanges();
      flushAllDocs();
      component.loadDocuments();
      const req = httpMock.expectOne((r) =>
        r.url.includes('testdb/_all_docs')
      );
      req.flush(mockResponse);
      expect(component.tableData.length).toBe(3);
    });
  });

  describe('LiveAnnouncer', () => {
    it('should announce on successful document load', () => {
      fixture.detectChanges();
      flushAllDocs();
      expect(announcerSpy.announce).toHaveBeenCalledWith('Loaded documents for testdb');
    });

    it('should not announce on error', () => {
      fixture.detectChanges();
      const req = httpMock.expectOne((r) => r.url.includes('testdb/_all_docs'));
      req.flush({ error: 'fail', reason: 'fail' }, { status: 500, statusText: 'Error' });
      fixture.detectChanges();
      expect(announcerSpy.announce).not.toHaveBeenCalled();
    });
  });

  it('should pass axe-core checks with data', async () => {
    fixture.detectChanges();
    flushAllDocs();
    await expectNoAxeViolations(fixture.nativeElement);
  });

  it('should pass axe-core checks with empty state', async () => {
    fixture.detectChanges();
    flushAllDocs({ total_rows: 0, offset: 0, rows: [] });
    await expectNoAxeViolations(fixture.nativeElement);
  });

  it('should pass axe-core checks with error state', async () => {
    fixture.detectChanges();
    const req = httpMock.expectOne((r) => r.url.includes('testdb/_all_docs'));
    req.flush(
      { error: 'internal', reason: 'Server error' },
      { status: 500, statusText: 'Internal Server Error' }
    );
    fixture.detectChanges();
    await expectNoAxeViolations(fixture.nativeElement);
  });
});
