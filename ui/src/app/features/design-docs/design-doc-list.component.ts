import { Component, OnInit, OnDestroy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, Router } from '@angular/router';
import { LiveAnnouncer } from '@angular/cdk/a11y';
import { Subscription } from 'rxjs';
import { DocumentService, AllDocsResponse, AllDocsRow } from '../../services/document.service';
import { mapError } from '../../services/error-mapping';
import { PageHeaderComponent } from '../../couch-ui/page-header/page-header.component';
import { BreadcrumbComponent, BreadcrumbSegment } from '../../couch-ui/breadcrumb/breadcrumb.component';
import { DataTableComponent, ColumnDef } from '../../couch-ui/data-table/data-table.component';
import { EmptyStateComponent } from '../../couch-ui/empty-state/empty-state.component';
import { FeatureErrorComponent } from '../../couch-ui/feature-error/feature-error.component';
import { ButtonComponent } from '../../couch-ui/button/button.component';
import { IconPlusComponent } from '../../couch-ui/icons';
import { DesignDocCreateDialogComponent } from './design-doc-create-dialog.component';

/**
 * Design Document List — feature component for the
 * `/db/:dbname/design` route.
 *
 * Beta scope (Story 11.3): adds a Create button + dialog to the read-only
 * list view from Story 11.1. Rows remain clickable and navigate to the
 * design-doc detail view.
 *
 * See Story 11.1 AC #1, AC #5; Story 11.3 AC #3.
 */
@Component({
  selector: 'app-design-doc-list',
  standalone: true,
  imports: [
    CommonModule,
    PageHeaderComponent,
    BreadcrumbComponent,
    DataTableComponent,
    EmptyStateComponent,
    FeatureErrorComponent,
    ButtonComponent,
    IconPlusComponent,
    DesignDocCreateDialogComponent,
  ],
  template: `
    <app-page-header
      title="Design documents"
      [fetchedAt]="fetchedAt"
      [loading]="loading"
      (refresh)="loadDesignDocs()">
      <ng-container breadcrumb>
        <app-breadcrumb [segments]="breadcrumbs"></app-breadcrumb>
      </ng-container>
      <ng-container actions>
        <app-button variant="primary" (click)="openCreateDialog()">
          <app-icon-plus [size]="14" />
          Create design doc
        </app-button>
      </ng-container>
    </app-page-header>

    <!-- Error state -->
    <app-feature-error
      *ngIf="!loading && loadError"
      [error]="loadError"
      [statusCode]="loadErrorCode"
      [retryable]="true"
      (retry)="loadDesignDocs()">
    </app-feature-error>

    <!-- Populated list -->
    <app-data-table
      *ngIf="!loading && !loadError && rows.length > 0"
      [columns]="columns"
      [data]="rows"
      [clickable]="true"
      (rowClick)="onRowClick($event)">
    </app-data-table>

    <!-- Empty state -->
    <app-empty-state
      *ngIf="!loading && !loadError && rows.length === 0"
      primary="No design documents yet."
      secondary="Use Create to add one.">
    </app-empty-state>

    <!-- Create dialog (Story 11.3 AC #3) -->
    <app-design-doc-create-dialog
      *ngIf="showCreateDialog"
      [existingNames]="existingShortNames"
      [serverError]="createError ?? undefined"
      [serverErrorCode]="createErrorStatus"
      [loading]="creating"
      (create)="onCreateConfirmed($event)"
      (cancel)="onCreateCancelled()">
    </app-design-doc-create-dialog>
  `,
  styles: [`
    :host {
      display: block;
      padding: 0 var(--space-6);
    }
  `],
})
export class DesignDocListComponent implements OnInit, OnDestroy {
  dbName = '';
  loading = false;
  fetchedAt: Date | null = null;

  rows: DesignDocRow[] = [];

  // Error state
  loadError: { error: string; reason: string } | null = null;
  loadErrorCode: number | undefined;

  // Create dialog state
  showCreateDialog = false;
  creating = false;
  createError: { error: string; reason: string } | null = null;
  createErrorStatus: number | undefined;

  // Breadcrumbs
  breadcrumbs: BreadcrumbSegment[] = [];

  readonly columns: ColumnDef[] = [
    { key: 'id', label: 'Name', mono: true },
  ];

  private subscriptions: Subscription[] = [];
  private activeRequest?: Subscription;
  private createRequest?: Subscription;

  constructor(
    private readonly route: ActivatedRoute,
    private readonly router: Router,
    private readonly docService: DocumentService,
    private readonly liveAnnouncer: LiveAnnouncer,
  ) {}

  /** Set of existing design-doc short names, used for client-side dedupe
   *  inside the create dialog. */
  get existingShortNames(): string[] {
    return this.rows
      .map((r) => String(r['id']))
      .filter((id) => id.startsWith('_design/'))
      .map((id) => id.slice('_design/'.length));
  }

  ngOnInit(): void {
    this.subscriptions.push(
      this.route.paramMap.subscribe((params) => {
        this.dbName = params.get('dbname') || '';
        this.breadcrumbs = [
          { label: 'Databases', url: '/databases' },
          { label: this.dbName, url: `/db/${this.dbName}` },
          { label: 'Design documents' },
        ];
        this.loadDesignDocs();
      }),
    );
  }

  ngOnDestroy(): void {
    this.activeRequest?.unsubscribe();
    this.createRequest?.unsubscribe();
    this.subscriptions.forEach((s) => s.unsubscribe());
  }

  loadDesignDocs(): void {
    this.activeRequest?.unsubscribe();
    this.loading = true;
    this.loadError = null;
    this.loadErrorCode = undefined;

    this.activeRequest = this.docService
      .listDesignDocs(this.dbName, { include_docs: false })
      .subscribe({
        next: (response: AllDocsResponse) => {
          this.rows = response.rows.map((r) => this.mapRow(r));
          this.fetchedAt = new Date();
          this.loading = false;
          this.liveAnnouncer.announce(
            this.rows.length === 0
              ? `No design documents in ${this.dbName}`
              : `Loaded ${this.rows.length} design documents for ${this.dbName}`,
          );
        },
        error: (err: unknown) => {
          this.loading = false;
          this.rows = [];
          const mapped = mapError(err);
          this.loadError = mapped.display;
          this.loadErrorCode = mapped.statusCode;
        },
      });
  }

  onRowClick(row: Record<string, unknown>): void {
    const id = String(row['id'] || '');
    if (!id) return;
    if (!id.startsWith('_design/')) return;
    const shortName = id.slice('_design/'.length);
    const segments = shortName.split('/').filter((s) => s.length > 0);
    if (segments.length === 0) return;
    this.router.navigate(['/db', this.dbName, 'design', ...segments]);
  }

  // ---------- Create dialog ----------

  openCreateDialog(): void {
    this.createError = null;
    this.createErrorStatus = undefined;
    this.showCreateDialog = true;
  }

  onCreateCancelled(): void {
    if (this.creating) return;
    this.showCreateDialog = false;
    this.createError = null;
    this.createErrorStatus = undefined;
  }

  onCreateConfirmed(payload: { name: string; body: unknown }): void {
    if (this.creating) return;
    this.createRequest?.unsubscribe();
    this.creating = true;
    this.createError = null;
    this.createErrorStatus = undefined;
    const docId = '_design/' + payload.name;
    this.createRequest = this.docService
      .putDocument(this.dbName, docId, payload.body)
      .subscribe({
        next: () => {
          this.creating = false;
          this.showCreateDialog = false;
          this.liveAnnouncer.announce(
            `Created design document ${payload.name}`,
          );
          this.loadDesignDocs();
        },
        error: (err: unknown) => {
          this.creating = false;
          const mapped = mapError(err);
          this.createError = mapped.display;
          this.createErrorStatus = mapped.statusCode;
        },
      });
  }

  private mapRow(row: AllDocsRow): DesignDocRow {
    return {
      id: row.id,
      rev: row.value.rev,
    };
  }
}

interface DesignDocRow {
  [key: string]: unknown;
  id: string;
  rev: string;
}
