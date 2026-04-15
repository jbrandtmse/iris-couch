import { TestBed, ComponentFixture } from '@angular/core/testing';
import { Component } from '@angular/core';
import { DataTableComponent, ColumnDef, SortChangeEvent } from './data-table.component';
import { expectNoAxeViolations } from '../test-utils';

@Component({
  standalone: true,
  imports: [DataTableComponent],
  template: `
    <app-data-table
      [columns]="columns"
      [data]="data"
      [sortColumn]="sortColumn"
      [sortDirection]="sortDirection"
      [clickable]="clickable"
      (sortChange)="onSortChange($event)"
      (rowClick)="onRowClick($event)">
    </app-data-table>
  `,
})
class TestHost {
  columns: ColumnDef[] = [
    { key: 'name', label: 'Name', sortable: true, mono: true },
    { key: 'docs', label: 'Docs', sortable: true, align: 'right', numeric: true },
    { key: 'size', label: 'Size', align: 'right' },
  ];
  data: Record<string, unknown>[] = [
    { name: 'mydb', docs: 42, size: '1.2 MB' },
    { name: 'testdb', docs: 7, size: '128 KB' },
  ];
  sortColumn = 'name';
  sortDirection: 'asc' | 'desc' = 'asc';
  clickable = true;
  lastSort?: SortChangeEvent;
  lastRowClick?: Record<string, unknown>;

  onSortChange(e: SortChangeEvent): void { this.lastSort = e; }
  onRowClick(row: Record<string, unknown>): void { this.lastRowClick = row; }
}

describe('DataTableComponent', () => {
  let fixture: ComponentFixture<TestHost>;
  let host: TestHost;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [TestHost],
    }).compileComponents();
    fixture = TestBed.createComponent(TestHost);
    host = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should render a table with header row', () => {
    const table = fixture.nativeElement.querySelector('table');
    expect(table).toBeTruthy();
    const headers = fixture.nativeElement.querySelectorAll('th');
    expect(headers.length).toBe(3);
    expect(headers[0].textContent.trim()).toBe('Name');
    expect(headers[1].textContent.trim()).toBe('Docs');
  });

  it('should render data rows', () => {
    const rows = fixture.nativeElement.querySelectorAll('tr.data-table__row');
    expect(rows.length).toBe(2);
  });

  it('should render cell values', () => {
    const cells = fixture.nativeElement.querySelectorAll('td');
    expect(cells[0].textContent.trim()).toBe('mydb');
    expect(cells[1].textContent.trim()).toBe('42');
    expect(cells[2].textContent.trim()).toBe('1.2 MB');
  });

  it('should set aria-sort on sortable column headers', () => {
    const headers = fixture.nativeElement.querySelectorAll('th');
    // name is sortColumn with asc direction
    expect(headers[0].getAttribute('aria-sort')).toBe('ascending');
    // docs is sortable but not the current sort column
    expect(headers[1].getAttribute('aria-sort')).toBe('none');
    // size is not sortable
    expect(headers[2].getAttribute('aria-sort')).toBeNull();
  });

  it('should emit sortChange when clicking a sortable header', () => {
    const headers = fixture.nativeElement.querySelectorAll('th');
    // Click "Docs" header (currently not sorted)
    headers[1].click();
    fixture.detectChanges();
    expect(host.lastSort).toEqual({ column: 'docs', direction: 'asc' });
  });

  it('should toggle direction when clicking the same sorted column', () => {
    const headers = fixture.nativeElement.querySelectorAll('th');
    // Click "Name" header (currently sorted asc)
    headers[0].click();
    fixture.detectChanges();
    expect(host.lastSort).toEqual({ column: 'name', direction: 'desc' });
  });

  it('should not emit sortChange when clicking a non-sortable header', () => {
    const headers = fixture.nativeElement.querySelectorAll('th');
    headers[2].click();
    fixture.detectChanges();
    expect(host.lastSort).toBeUndefined();
  });

  it('should emit rowClick when clicking a clickable row', () => {
    const rows = fixture.nativeElement.querySelectorAll('tr.data-table__row');
    rows[0].click();
    fixture.detectChanges();
    expect(host.lastRowClick).toEqual({ name: 'mydb', docs: 42, size: '1.2 MB' });
  });

  it('should add clickable class when clickable=true', () => {
    const rows = fixture.nativeElement.querySelectorAll('tr.data-table__row');
    expect(rows[0].classList).toContain('data-table__row--clickable');
  });

  it('should add pointer cursor via CSS class on clickable rows', () => {
    const rows = fixture.nativeElement.querySelectorAll('tr.data-table__row--clickable');
    expect(rows.length).toBe(2);
  });

  it('should not emit rowClick when clickable=false', () => {
    host.clickable = false;
    fixture.detectChanges();
    const rows = fixture.nativeElement.querySelectorAll('tr.data-table__row');
    rows[0].click();
    fixture.detectChanges();
    expect(host.lastRowClick).toBeUndefined();
  });

  it('should apply mono class to monospace columns', () => {
    // First column (name) has mono=true
    const cells = fixture.nativeElement.querySelectorAll('td');
    expect(cells[0].classList).toContain('data-table__cell--mono');
  });

  it('should apply numeric class to numeric columns', () => {
    // Second column (docs) has numeric=true
    const cells = fixture.nativeElement.querySelectorAll('td');
    expect(cells[1].classList).toContain('data-table__cell--numeric');
  });

  it('should apply right alignment class to right-aligned columns', () => {
    const cells = fixture.nativeElement.querySelectorAll('td');
    expect(cells[1].classList).toContain('data-table__cell--right');
    expect(cells[2].classList).toContain('data-table__cell--right');
  });

  it('should use format function when provided', () => {
    host.columns = [
      {
        key: 'docs',
        label: 'Docs',
        format: (v: unknown) => `${v} documents`,
      },
    ];
    fixture.detectChanges();
    const cell = fixture.nativeElement.querySelector('td');
    expect(cell.textContent.trim()).toBe('42 documents');
  });

  it('should pass axe-core accessibility checks', async () => {
    await expectNoAxeViolations(fixture.nativeElement);
  });
});
