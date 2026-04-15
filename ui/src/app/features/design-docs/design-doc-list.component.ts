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

/**
 * Design Document List — feature component for the
 * `/db/:dbname/design` route.
 *
 * Alpha scope: read-only. No create/edit/delete affordances at this story
 * level; those arrive in Story 11.3. Rows are clickable and navigate to
 * the design-doc detail view.
 *
 * See Story 11.1 AC #1 and AC #5.
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
    </app-page-header>

    <!-- Error state (Story 11.0 AC #5: shared FeatureError wrapper) -->
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

    <!-- Empty state (AC #5) -->
    <app-empty-state
      *ngIf="!loading && !loadError && rows.length === 0"
      primary="No design documents yet."
      secondary="Use curl or another client to create one at alpha.">
    </app-empty-state>
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

  // Breadcrumbs
  breadcrumbs: BreadcrumbSegment[] = [];

  // DataTable column definitions — single "Name" column with monospace.
  readonly columns: ColumnDef[] = [
    { key: 'id', label: 'Name', mono: true },
  ];

  private subscriptions: Subscription[] = [];
  private activeRequest?: Subscription;

  constructor(
    private readonly route: ActivatedRoute,
    private readonly router: Router,
    private readonly docService: DocumentService,
    private readonly liveAnnouncer: LiveAnnouncer,
  ) {}

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
    this.subscriptions.forEach((s) => s.unsubscribe());
  }

  loadDesignDocs(): void {
    // Cancel in-flight request to prevent stale data from overwriting fresh
    // results. See .claude/rules/angular-patterns.md.
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
    // Defensive: rows sourced from listDesignDocs should always start with
    // `_design/`. If a row without the prefix somehow reaches us (e.g. data
    // leakage from a different list), refuse to navigate rather than
    // producing a nonsensical `/db/<db>/design/<arbitrary>` URL.
    if (!id.startsWith('_design/')) return;
    // Split the composite `_design/<name>` into segments so the custom
    // designDocDetailMatcher (see app.routes.ts) can reassemble them
    // without the Angular router percent-encoding the inner `/`.
    // The path is `/db/:dbname/design/<segments...>` and each segment
    // after `design/` is a piece of the ddoc short name. For plain names
    // (no `/` in the short name), this is a single segment.
    const shortName = id.slice('_design/'.length);
    const segments = shortName.split('/').filter((s) => s.length > 0);
    if (segments.length === 0) return;
    this.router.navigate(['/db', this.dbName, 'design', ...segments]);
  }

  private mapRow(row: AllDocsRow): DesignDocRow {
    return {
      id: row.id,
      rev: row.value.rev,
    };
  }
}

/** Internal view model for a design-doc row. */
interface DesignDocRow {
  [key: string]: unknown;
  id: string;
  rev: string;
}
