import { Component, OnInit, OnDestroy, ViewChild, ElementRef, HostListener } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, Router } from '@angular/router';
import { FormsModule } from '@angular/forms';
import { Subject, Subscription, debounceTime, distinctUntilChanged } from 'rxjs';
import { DocumentService, AllDocsResponse, AllDocsRow } from '../../services/document.service';
import { EmptyStateComponent } from '../../couch-ui/empty-state/empty-state.component';
import { PageHeaderComponent } from '../../couch-ui/page-header/page-header.component';
import { PaginationComponent } from '../../couch-ui/pagination/pagination.component';
import { BadgeComponent } from '../../couch-ui/badge/badge.component';
import { CopyButtonComponent } from '../../couch-ui/copy-button/copy-button.component';
import { IconButtonComponent } from '../../couch-ui/icon-button/icon-button.component';
import { BreadcrumbComponent, BreadcrumbSegment } from '../../couch-ui/breadcrumb/breadcrumb.component';
import { IconXComponent } from '../../couch-ui/icons';

/** Page size for document list pagination. */
const PAGE_SIZE = 25;

/**
 * Database Detail / Document List component.
 *
 * Displays all documents in a database using the _all_docs endpoint
 * with startkey-based pagination, prefix filtering, and design doc /
 * tombstoned doc badges.
 *
 * Route: /db/:dbname
 */
@Component({
  selector: 'app-database-detail',
  standalone: true,
  imports: [
    CommonModule,
    FormsModule,
    EmptyStateComponent,
    PageHeaderComponent,
    PaginationComponent,
    BadgeComponent,
    CopyButtonComponent,
    IconButtonComponent,
    BreadcrumbComponent,
    IconXComponent,
  ],
  template: `
    <app-page-header
      [title]="dbName"
      [mono]="true"
      [fetchedAt]="fetchedAt"
      [loading]="loading"
      (refresh)="loadDocuments()">
      <ng-container breadcrumb>
        <app-breadcrumb [segments]="breadcrumbs"></app-breadcrumb>
      </ng-container>
    </app-page-header>

    <!-- Filter bar -->
    <div class="filter-bar">
      <div class="filter-bar__input-wrapper">
        <label for="doc-filter" class="filter-bar__label">filter by _id prefix</label>
        <div class="filter-bar__field-wrapper">
          <input
            #filterInput
            id="doc-filter"
            type="text"
            class="filter-bar__field"
            placeholder="e.g. user: or _design/"
            [ngModel]="filterText"
            (ngModelChange)="onFilterChange($event)"
            [attr.aria-describedby]="filterText ? 'filter-clear-hint' : null" />
          <app-icon-button
            *ngIf="filterText"
            class="filter-bar__clear"
            ariaLabel="Clear filter"
            (click)="clearFilter()">
            <app-icon-x [size]="14" />
          </app-icon-button>
        </div>
        <span id="filter-clear-hint" class="sr-only">Press Escape or click the clear button to remove filter</span>
      </div>
      <span class="filter-bar__shortcut" aria-hidden="true">/ to focus</span>
    </div>

    <!-- Data table with custom cell templates -->
    <div class="doc-table" *ngIf="!loading && tableData.length > 0">
      <table class="data-table">
        <thead>
          <tr>
            <th class="data-table__header">Document ID</th>
            <th class="data-table__header data-table__header--rev">Revision</th>
          </tr>
        </thead>
        <tbody>
          <tr
            *ngFor="let row of tableData; trackBy: trackById"
            class="data-table__row data-table__row--clickable"
            [class.data-table__row--deleted]="row.deleted"
            tabindex="0"
            (click)="onRowClick(row)"
            (keydown.enter)="onRowClick(row)">
            <td class="data-table__cell data-table__cell--mono data-table__cell--id">
              <span>{{ row.id }}</span>
              <app-badge *ngIf="row.isDesign" variant="info">design</app-badge>
              <app-badge *ngIf="row.deleted" variant="warn">deleted</app-badge>
            </td>
            <td class="data-table__cell data-table__cell--mono data-table__cell--rev">
              <span class="rev-text" [title]="row.rev">{{ row.revShort }}</span>
              <app-copy-button [value]="row.rev" ariaLabel="Copy revision" />
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Error state -->
    <app-empty-state
      *ngIf="!loading && errorMessage"
      primary="Failed to load documents."
      [secondary]="errorMessage">
    </app-empty-state>

    <!-- Empty state -->
    <app-empty-state
      *ngIf="!loading && !errorMessage && tableData.length === 0 && !filterText"
      primary="No documents yet."
      secondary="This database is empty.">
    </app-empty-state>

    <app-empty-state
      *ngIf="!loading && !errorMessage && tableData.length === 0 && filterText"
      primary="No matching documents."
      [secondary]="'No documents match the prefix &quot;' + filterText + '&quot;.'">
    </app-empty-state>

    <!-- Pagination -->
    <app-pagination
      *ngIf="!loading && tableData.length > 0"
      [startIndex]="paginationStart"
      [endIndex]="paginationEnd"
      [totalRows]="totalRows"
      [hasNext]="hasNextPage"
      [hasPrevious]="hasPreviousPage"
      (next)="nextPage()"
      (previous)="previousPage()">
    </app-pagination>
  `,
  styles: [`
    :host{display:block;padding:0 var(--space-6)}
    .filter-bar{display:flex;align-items:flex-end;gap:var(--space-2);padding-bottom:var(--space-3)}
    .filter-bar__input-wrapper{display:flex;flex-direction:column;gap:2px;flex:1;max-width:400px}
    .filter-bar__label{font-size:var(--font-size-sm);font-weight:500;color:var(--color-neutral-700)}
    .filter-bar__field-wrapper{position:relative;display:flex;align-items:center}
    .filter-bar__field{width:100%;height:32px;padding:0 32px 0 12px;font-size:var(--font-size-sm);font-family:var(--font-mono);color:var(--color-neutral-800);background:var(--color-neutral-0);border:1px solid var(--color-neutral-200);border-radius:var(--border-radius)}
    .filter-bar__field::placeholder{color:var(--color-neutral-400);font-family:var(--font-sans)}
    .filter-bar__field:focus{outline:none;border-color:var(--color-info);box-shadow:0 0 0 2px rgba(60,90,158,.1)}
    .filter-bar__clear{position:absolute;right:4px}
    .filter-bar__shortcut{font-size:var(--font-size-xs);line-height:32px;color:var(--color-neutral-600)}
    .sr-only{position:absolute;width:1px;height:1px;margin:-1px;overflow:hidden;clip:rect(0,0,0,0);border:0}
    .data-table{width:100%;border-collapse:collapse}
    .data-table__header{height:32px;padding:0 var(--space-3);font-size:var(--font-size-xs);font-weight:600;color:var(--color-neutral-500);text-align:left;border-bottom:1px solid var(--color-neutral-200)}
    .data-table__header--rev{width:200px}
    .data-table__cell{height:28px;padding:0 var(--space-3);font-size:var(--font-size-xs);color:var(--color-neutral-700);white-space:nowrap;border-bottom:1px solid var(--color-neutral-100);font-family:var(--font-mono)}
    .data-table__cell--id,.data-table__cell--rev{display:flex;align-items:center}
    .data-table__cell--id{gap:var(--space-2)}
    .data-table__cell--rev{gap:var(--space-1)}
    .data-table__row:hover{background:var(--color-neutral-50)}
    .data-table__row--clickable{cursor:pointer}
    .data-table__row--clickable:focus-visible{outline:2px solid var(--color-info);outline-offset:-2px}
    .data-table__row--deleted{opacity:.5}
  `]
})
export class DatabaseDetailComponent implements OnInit, OnDestroy {
  @ViewChild('filterInput') filterInput!: ElementRef<HTMLInputElement>;

  dbName = '';
  loading = false;
  fetchedAt: Date | null = null;

  // Table data
  tableData: DocRow[] = [];
  totalRows = 0;
  errorMessage = '';

  // Filter
  filterText = '';
  private filterSubject = new Subject<string>();

  // Pagination
  private pageHistory: string[] = []; // stack of startkeys for backward nav
  private currentStartKey: string | undefined;
  private lastRowKey: string | undefined;
  hasNextPage = false;
  hasPreviousPage = false;

  // Active HTTP request (cancel on new request to prevent stale data)
  private activeRequest?: Subscription;

  // Breadcrumbs
  breadcrumbs: BreadcrumbSegment[] = [];

  private subscriptions: Subscription[] = [];

  constructor(
    private readonly route: ActivatedRoute,
    private readonly router: Router,
    private readonly docService: DocumentService,
  ) {}

  ngOnInit(): void {
    // Read route params
    this.subscriptions.push(
      this.route.paramMap.subscribe((params) => {
        this.dbName = params.get('dbname') || '';
        this.breadcrumbs = [
          { label: 'Databases', url: '/databases' },
          { label: this.dbName },
        ];

        // Read query params for filter and startkey
        const queryParams = this.route.snapshot.queryParams;
        this.filterText = queryParams['filter'] || '';
        this.currentStartKey = queryParams['startkey'] || undefined;

        this.loadDocuments();
      })
    );

    // Setup filter debounce
    this.subscriptions.push(
      this.filterSubject.pipe(
        debounceTime(150),
        distinctUntilChanged()
      ).subscribe((prefix) => {
        this.filterText = prefix;
        // Reset pagination when filter changes
        this.pageHistory = [];
        this.currentStartKey = undefined;
        this.updateUrlParams();
        this.loadDocuments();
      })
    );
  }

  ngOnDestroy(): void {
    this.activeRequest?.unsubscribe();
    this.subscriptions.forEach((s) => s.unsubscribe());
    this.filterSubject.complete();
  }

  /** Handle '/' key to focus filter input, Escape to clear filter. */
  @HostListener('document:keydown', ['$event'])
  onKeyDown(event: KeyboardEvent): void {
    if (event.key === '/' && !this.isInputFocused()) {
      event.preventDefault();
      this.filterInput?.nativeElement?.focus();
    } else if (event.key === 'Escape' && this.filterText) {
      this.clearFilter();
      this.filterInput?.nativeElement?.blur();
    }
  }

  get paginationStart(): number {
    if (this.tableData.length === 0) return 0;
    return (this.pageHistory.length * PAGE_SIZE) + 1;
  }

  get paginationEnd(): number {
    return this.paginationStart + this.tableData.length - 1;
  }

  onFilterChange(value: string): void {
    this.filterSubject.next(value);
  }

  clearFilter(): void {
    this.filterText = '';
    this.filterSubject.next('');
  }

  loadDocuments(): void {
    // Cancel any in-flight request to prevent stale data from overwriting fresh results
    this.activeRequest?.unsubscribe();

    this.loading = true;
    this.errorMessage = '';

    const options: Record<string, unknown> = {
      limit: PAGE_SIZE + 1, // fetch one extra to detect next page
      include_docs: false,
    };

    if (this.filterText) {
      // CouchDB prefix trick
      options['startkey'] = this.currentStartKey || this.filterText;
      options['endkey'] = this.filterText + '\ufff0';
    } else if (this.currentStartKey) {
      options['startkey'] = this.currentStartKey;
    }

    this.activeRequest = this.docService.listDocuments(this.dbName, options as any).subscribe({
      next: (response: AllDocsResponse) => {
        this.totalRows = response.total_rows;
        const rows = response.rows;

        // Check if there is a next page
        if (rows.length > PAGE_SIZE) {
          this.hasNextPage = true;
          this.lastRowKey = rows[PAGE_SIZE - 1].key;
          this.tableData = rows.slice(0, PAGE_SIZE).map((r) => this.mapRow(r));
        } else {
          this.hasNextPage = false;
          this.lastRowKey = rows.length > 0 ? rows[rows.length - 1].key : undefined;
          this.tableData = rows.map((r) => this.mapRow(r));
        }

        this.hasPreviousPage = this.pageHistory.length > 0;
        this.fetchedAt = new Date();
        this.loading = false;
      },
      error: (err) => {
        this.loading = false;
        this.errorMessage = err?.error?.reason || err?.message || 'Could not load documents. Please try again.';
        this.tableData = [];
      },
    });
  }

  nextPage(): void {
    if (!this.hasNextPage || !this.lastRowKey) return;

    // Push current startkey to history for back navigation
    this.pageHistory.push(this.currentStartKey || '');
    this.currentStartKey = this.lastRowKey;
    this.updateUrlParams();
    this.loadDocuments();
  }

  previousPage(): void {
    if (this.pageHistory.length === 0) return;

    const prevKey = this.pageHistory.pop()!;
    this.currentStartKey = prevKey || undefined;
    this.updateUrlParams();
    this.loadDocuments();
  }

  onRowClick(row: DocRow): void {
    this.router.navigate(['/db', this.dbName, 'doc', row.id]);
  }

  trackById(_index: number, row: DocRow): string {
    return row.id;
  }

  private mapRow(row: AllDocsRow): DocRow {
    return {
      id: row.id,
      key: row.key,
      rev: row.value.rev,
      revShort: row.value.rev ? row.value.rev.substring(0, 8) : '',
      deleted: !!row.value.deleted,
      isDesign: row.id.startsWith('_design/'),
    };
  }

  private updateUrlParams(): void {
    const queryParams: Record<string, string | null> = {};
    queryParams['filter'] = this.filterText || null;
    queryParams['startkey'] = this.currentStartKey || null;

    this.router.navigate([], {
      relativeTo: this.route,
      queryParams,
      queryParamsHandling: 'merge',
      replaceUrl: false,
    });
  }

  private isInputFocused(): boolean {
    const el = document.activeElement;
    if (!el) return false;
    const tag = el.tagName.toLowerCase();
    return tag === 'input' || tag === 'textarea' || tag === 'select';
  }
}

/** Internal view model for a document row. */
interface DocRow {
  id: string;
  key: string;
  rev: string;
  revShort: string;
  deleted: boolean;
  isDesign: boolean;
}
