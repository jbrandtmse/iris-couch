import { TestBed, ComponentFixture, fakeAsync, tick } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { provideRouter, Router } from '@angular/router';
import { DatabaseListComponent } from './database-list.component';
import { expectNoAxeViolations } from '../../couch-ui/test-utils';

describe('DatabaseListComponent', () => {
  let fixture: ComponentFixture<DatabaseListComponent>;
  let component: DatabaseListComponent;
  let httpMock: HttpTestingController;
  let router: Router;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [DatabaseListComponent],
      providers: [
        provideHttpClient(),
        provideHttpClientTesting(),
        provideRouter([]),
      ],
    }).compileComponents();

    httpMock = TestBed.inject(HttpTestingController);
    router = TestBed.inject(Router);
    spyOn(router, 'navigate');

    fixture = TestBed.createComponent(DatabaseListComponent);
    component = fixture.componentInstance;
  });

  afterEach(() => {
    httpMock.verify();
  });

  function flushDatabases(dbs: Array<{ name: string; docCount: number; updateSeq: string; diskSize: number }>): void {
    const names = dbs.map((d) => d.name);
    const allDbsReq = httpMock.expectOne('_all_dbs');
    allDbsReq.flush(names);

    for (const db of dbs) {
      const infoReq = httpMock.expectOne(db.name);
      infoReq.flush({
        db_name: db.name,
        doc_count: db.docCount,
        update_seq: db.updateSeq,
        sizes: { file: db.diskSize, external: 0, active: 0 },
      });
    }
    fixture.detectChanges();
  }

  function flushEmptyDatabases(): void {
    const req = httpMock.expectOne('_all_dbs');
    req.flush([]);
    fixture.detectChanges();
  }

  describe('Loading state', () => {
    it('should start loading on init', () => {
      fixture.detectChanges();
      expect(component.loading).toBeTrue();
      flushEmptyDatabases();
    });

    it('should stop loading after data loads', () => {
      fixture.detectChanges();
      flushEmptyDatabases();
      expect(component.loading).toBeFalse();
    });

    it('should set fetchedAt after loading', () => {
      fixture.detectChanges();
      flushEmptyDatabases();
      expect(component.fetchedAt).toBeTruthy();
    });
  });

  describe('Data table rendering', () => {
    const testDbs = [
      { name: 'alpha', docCount: 10, updateSeq: '100-abcdef1234', diskSize: 2048 },
      { name: 'beta', docCount: 42, updateSeq: '200-xyz', diskSize: 1048576 },
    ];

    it('should render DataTable with databases', () => {
      fixture.detectChanges();
      flushDatabases(testDbs);
      const table = fixture.nativeElement.querySelector('app-data-table');
      expect(table).toBeTruthy();
    });

    it('should display database names', () => {
      fixture.detectChanges();
      flushDatabases(testDbs);
      const cells = fixture.nativeElement.querySelectorAll('td');
      const nameCell = cells[0];
      expect(nameCell.textContent.trim()).toBe('alpha');
    });

    it('should display doc counts', () => {
      fixture.detectChanges();
      flushDatabases(testDbs);
      const cells = fixture.nativeElement.querySelectorAll('td');
      expect(cells[1].textContent.trim()).toBe('10');
    });

    it('should truncate update_seq to 8 chars', () => {
      fixture.detectChanges();
      flushDatabases(testDbs);
      const cells = fixture.nativeElement.querySelectorAll('td');
      // '100-abcdef1234' should become '100-abcd...'
      expect(cells[2].textContent.trim()).toContain('100-abcd');
    });

    it('should format disk size in human-readable format', () => {
      fixture.detectChanges();
      flushDatabases(testDbs);
      const cells = fixture.nativeElement.querySelectorAll('td');
      // 2048 = 2.0 KB
      expect(cells[3].textContent.trim()).toBe('2.0 KB');
    });
  });

  describe('Sorting', () => {
    const testDbs = [
      { name: 'beta', docCount: 5, updateSeq: '50', diskSize: 100 },
      { name: 'alpha', docCount: 10, updateSeq: '100', diskSize: 200 },
    ];

    it('should default sort by name ascending', () => {
      fixture.detectChanges();
      flushDatabases(testDbs);
      expect(component.sortColumn).toBe('name');
      expect(component.sortDirection).toBe('asc');
      // alpha should be first
      const rows = fixture.nativeElement.querySelectorAll('tr.data-table__row');
      const firstCell = rows[0].querySelector('td');
      expect(firstCell.textContent.trim()).toBe('alpha');
    });

    it('should update sort on sortChange', () => {
      fixture.detectChanges();
      flushDatabases(testDbs);
      component.onSortChange({ column: 'docCount', direction: 'desc' });
      fixture.detectChanges();
      expect(component.sortColumn).toBe('docCount');
      expect(component.sortDirection).toBe('desc');
    });
  });

  describe('Row click navigation', () => {
    it('should navigate to /db/{name} on row click', () => {
      fixture.detectChanges();
      flushDatabases([
        { name: 'mydb', docCount: 1, updateSeq: '1', diskSize: 0 },
      ]);
      component.onRowClick({ name: 'mydb' });
      expect(router.navigate).toHaveBeenCalledWith(['/db', 'mydb']);
    });
  });

  describe('Empty state', () => {
    it('should show EmptyState when no databases', () => {
      fixture.detectChanges();
      flushEmptyDatabases();
      const empty = fixture.nativeElement.querySelector('app-empty-state');
      expect(empty).toBeTruthy();
    });

    it('should not show DataTable when no databases', () => {
      fixture.detectChanges();
      flushEmptyDatabases();
      const table = fixture.nativeElement.querySelector('app-data-table');
      expect(table).toBeNull();
    });
  });

  describe('Create database', () => {
    it('should open create dialog', () => {
      fixture.detectChanges();
      flushEmptyDatabases();
      component.openCreateDialog();
      fixture.detectChanges();
      const dialog = fixture.nativeElement.querySelector('app-confirm-dialog');
      expect(dialog).toBeTruthy();
    });

    it('should close create dialog on cancel', () => {
      fixture.detectChanges();
      flushEmptyDatabases();
      component.openCreateDialog();
      fixture.detectChanges();
      component.closeCreateDialog();
      fixture.detectChanges();
      expect(component.showCreateDialog).toBeFalse();
    });

    it('should call createDatabase on confirm', () => {
      fixture.detectChanges();
      flushEmptyDatabases();
      component.openCreateDialog();
      fixture.detectChanges();
      component.onCreateConfirm('newdb');
      const req = httpMock.expectOne('newdb');
      expect(req.request.method).toBe('PUT');
      req.flush({ ok: true });
      // Should then reload
      const reloadReq = httpMock.expectOne('_all_dbs');
      reloadReq.flush(['newdb']);
      const infoReq = httpMock.expectOne('newdb');
      infoReq.flush({
        db_name: 'newdb',
        doc_count: 0,
        update_seq: '0',
        sizes: { file: 0, external: 0, active: 0 },
      });
      fixture.detectChanges();
      expect(component.showCreateDialog).toBeFalse();
    });

    it('should show error on 412 conflict', () => {
      fixture.detectChanges();
      flushEmptyDatabases();
      component.openCreateDialog();
      fixture.detectChanges();
      component.onCreateConfirm('existing');
      const req = httpMock.expectOne('existing');
      req.flush(
        { error: 'file_exists', reason: 'The database could not be created, the file already exists.' },
        { status: 412, statusText: 'Precondition Failed' }
      );
      fixture.detectChanges();
      expect(component.createError).toBeTruthy();
      expect(component.createErrorCode).toBe(412);
      expect(component.createError!.error).toBe('file_exists');
    });
  });

  describe('Delete database', () => {
    it('should open delete dialog with target', () => {
      fixture.detectChanges();
      flushDatabases([
        { name: 'todelete', docCount: 5, updateSeq: '10', diskSize: 100 },
      ]);
      component.openDeleteDialog(component.databases[0]);
      fixture.detectChanges();
      expect(component.showDeleteDialog).toBeTrue();
      expect(component.deleteTarget!.name).toBe('todelete');
    });

    it('should call deleteDatabase on confirm', () => {
      fixture.detectChanges();
      flushDatabases([
        { name: 'todelete', docCount: 3, updateSeq: '5', diskSize: 50 },
      ]);
      component.openDeleteDialog(component.databases[0]);
      component.onDeleteConfirm();
      const req = httpMock.expectOne('todelete');
      expect(req.request.method).toBe('DELETE');
      req.flush({ ok: true });
      // Reload
      const reloadReq = httpMock.expectOne('_all_dbs');
      reloadReq.flush([]);
      fixture.detectChanges();
      expect(component.showDeleteDialog).toBeFalse();
    });
  });

  describe('Format bytes', () => {
    it('should format 0 as "0 B"', () => {
      expect(component.formatBytes(0)).toBe('0 B');
    });

    it('should format bytes', () => {
      expect(component.formatBytes(500)).toBe('500 B');
    });

    it('should format kilobytes', () => {
      expect(component.formatBytes(2048)).toBe('2.0 KB');
    });

    it('should format megabytes', () => {
      expect(component.formatBytes(1048576)).toBe('1.0 MB');
    });

    it('should format gigabytes', () => {
      expect(component.formatBytes(1073741824)).toBe('1.0 GB');
    });
  });

  describe('Page header', () => {
    it('should render title "Databases"', () => {
      fixture.detectChanges();
      flushEmptyDatabases();
      const header = fixture.nativeElement.querySelector('app-page-header');
      expect(header).toBeTruthy();
    });

    it('should have create button in header', () => {
      fixture.detectChanges();
      flushEmptyDatabases();
      const createBtn = fixture.nativeElement.querySelector('app-page-header app-button');
      expect(createBtn).toBeTruthy();
      expect(createBtn.textContent.trim()).toContain('Create database');
    });

    it('should reload on refresh', () => {
      fixture.detectChanges();
      flushEmptyDatabases();
      component.loadDatabases();
      const req = httpMock.expectOne('_all_dbs');
      req.flush([]);
      fixture.detectChanges();
    });
  });

  it('should pass axe-core checks with data', async () => {
    fixture.detectChanges();
    flushDatabases([
      { name: 'mydb', docCount: 10, updateSeq: '50-abc', diskSize: 2048 },
    ]);
    await expectNoAxeViolations(fixture.nativeElement);
  });

  it('should pass axe-core checks with empty state', async () => {
    fixture.detectChanges();
    flushEmptyDatabases();
    await expectNoAxeViolations(fixture.nativeElement);
  });
});
