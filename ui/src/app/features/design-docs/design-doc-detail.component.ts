import { Component, OnInit, OnDestroy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute } from '@angular/router';
import { LiveAnnouncer } from '@angular/cdk/a11y';
import { Subscription } from 'rxjs';
import { DocumentService } from '../../services/document.service';
import { mapError } from '../../services/error-mapping';
import { PageHeaderComponent } from '../../couch-ui/page-header/page-header.component';
import { BreadcrumbComponent, BreadcrumbSegment } from '../../couch-ui/breadcrumb/breadcrumb.component';
import { CopyButtonComponent } from '../../couch-ui/copy-button/copy-button.component';
import { FeatureErrorComponent } from '../../couch-ui/feature-error/feature-error.component';
import { JsonDisplayComponent } from '../../couch-ui/json-display/json-display.component';

/**
 * Design Document Detail — feature component for the
 * `/db/:dbname/design/:ddocname[/...]` route.
 *
 * Alpha scope: read-only. Displays the full JSON body of a design document
 * with CopyButton affordances on the identity fields. No edit controls, no
 * delete controls, no conflict zone, no attachment list — Story 11.3 adds
 * editing; conflicts and attachments on design docs are out of alpha scope.
 *
 * Deep-linkable: the URL alone must render the full detail view without
 * requiring the list view to be visited first (AC #3).
 *
 * See Story 11.1 AC #2, AC #3, AC #4, AC #6.
 */
@Component({
  selector: 'app-design-doc-detail',
  standalone: true,
  imports: [
    CommonModule,
    PageHeaderComponent,
    BreadcrumbComponent,
    CopyButtonComponent,
    FeatureErrorComponent,
    JsonDisplayComponent,
  ],
  template: `
    <app-page-header
      [title]="ddocId"
      [mono]="true"
      [fetchedAt]="fetchedAt"
      [loading]="loading"
      (refresh)="onRefresh()">
      <ng-container breadcrumb>
        <app-breadcrumb [segments]="breadcrumbs"></app-breadcrumb>
      </ng-container>
    </app-page-header>

    <div class="ddoc-detail" *ngIf="doc && !error">
      <!-- Identity zone: _id, _rev, each with CopyButton (AC #4) -->
      <div class="ddoc-detail__header">
        <div class="ddoc-detail__meta-row">
          <span class="ddoc-detail__id mono">{{ doc._id }}</span>
          <app-copy-button [value]="doc._id" ariaLabel="Copy design document ID" />
        </div>
        <div class="ddoc-detail__meta-row">
          <span class="ddoc-detail__rev mono">{{ doc._rev }}</span>
          <app-copy-button [value]="doc._rev" ariaLabel="Copy revision" />
        </div>
      </div>

      <!-- Body zone: full JSON (AC #2 + AC #4) -->
      <div class="ddoc-detail__body">
        <app-json-display [json]="rawJson"></app-json-display>
      </div>
    </div>

    <!-- Error state: verbatim backend envelope via FeatureError (AC #6) -->
    <div *ngIf="error" class="ddoc-detail__error">
      <app-feature-error
        [error]="error"
        [statusCode]="errorStatus"
        [retryable]="true"
        (retry)="onRefresh()">
      </app-feature-error>
    </div>
  `,
  styles: [`
    :host {
      display: block;
      padding: 0 var(--space-6);
    }

    .ddoc-detail__header {
      display: flex;
      flex-direction: column;
      gap: var(--space-2);
      padding-bottom: var(--space-4);
    }

    .ddoc-detail__meta-row {
      display: flex;
      align-items: center;
      gap: var(--space-1);
    }

    .ddoc-detail__id {
      font-size: var(--font-size-lg);
      font-weight: 600;
      color: var(--color-neutral-800);
    }

    .ddoc-detail__rev {
      font-size: var(--font-size-sm);
      color: var(--color-neutral-600);
    }

    .ddoc-detail__body {
      padding-bottom: var(--space-4);
    }

    .ddoc-detail__error {
      padding-top: var(--space-4);
    }

    .mono {
      font-family: var(--font-mono);
    }
  `],
})
export class DesignDocDetailComponent implements OnInit, OnDestroy {
  dbName = '';
  /** Full composite ID on the wire, e.g. `_design/myapp`. */
  ddocId = '';
  /** Short (non-prefix) name, e.g. `myapp`. Used in the breadcrumb. */
  ddocShortName = '';

  doc: any = null;
  rawJson = '';
  loading = false;
  fetchedAt: Date | null = null;

  // Error state
  error: { error: string; reason: string } | null = null;
  errorStatus: number | undefined;

  // Breadcrumbs
  breadcrumbs: BreadcrumbSegment[] = [];

  private subscriptions: Subscription[] = [];
  private activeRequest?: Subscription;

  constructor(
    private readonly route: ActivatedRoute,
    private readonly docService: DocumentService,
    private readonly liveAnnouncer: LiveAnnouncer,
  ) {}

  ngOnInit(): void {
    this.subscriptions.push(
      this.route.paramMap.subscribe((params) => {
        this.dbName = params.get('dbname') || '';
        const rawDdoc = params.get('ddocid') || '';
        // `ddocid` param from the matcher is the short name (no `_design/`
        // prefix). For robustness, accept either and normalize.
        this.ddocShortName = rawDdoc.startsWith('_design/')
          ? rawDdoc.slice('_design/'.length)
          : rawDdoc;
        this.ddocId = '_design/' + this.ddocShortName;

        this.breadcrumbs = [
          { label: 'Databases', url: '/databases' },
          { label: this.dbName, url: `/db/${this.dbName}` },
          { label: 'Design documents', url: `/db/${this.dbName}/design` },
          { label: this.ddocShortName },
        ];
        this.loadDesignDoc();
      }),
    );
  }

  ngOnDestroy(): void {
    this.activeRequest?.unsubscribe();
    this.subscriptions.forEach((s) => s.unsubscribe());
  }

  onRefresh(): void {
    this.loadDesignDoc();
  }

  private loadDesignDoc(): void {
    // Cancel any in-flight request — see .claude/rules/angular-patterns.md.
    this.activeRequest?.unsubscribe();

    this.loading = true;
    this.error = null;
    this.errorStatus = undefined;

    this.activeRequest = this.docService.getDocument(this.dbName, this.ddocId).subscribe({
      next: (doc) => {
        this.doc = doc;
        this.rawJson = JSON.stringify(doc);
        this.loading = false;
        this.fetchedAt = new Date();
        this.liveAnnouncer.announce(`Loaded design document ${this.ddocId}`);
      },
      error: (err: unknown) => {
        this.loading = false;
        this.doc = null;
        this.rawJson = '';
        const mapped = mapError(err);
        this.error = mapped.display;
        this.errorStatus = mapped.statusCode;
      },
    });
  }
}
