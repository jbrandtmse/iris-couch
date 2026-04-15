import { Component, OnInit, OnDestroy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute } from '@angular/router';
import { Subscription } from 'rxjs';
import { DocumentService } from '../../services/document.service';
import { PageHeaderComponent } from '../../couch-ui/page-header/page-header.component';
import { BreadcrumbComponent, BreadcrumbSegment } from '../../couch-ui/breadcrumb/breadcrumb.component';
import { BadgeComponent } from '../../couch-ui/badge/badge.component';
import { CopyButtonComponent } from '../../couch-ui/copy-button/copy-button.component';
import { ErrorDisplayComponent } from '../../couch-ui/error-display/error-display.component';
import { JsonDisplayComponent } from '../../couch-ui/json-display/json-display.component';
import { IconButtonComponent } from '../../couch-ui/icon-button/icon-button.component';
import { IconDownloadComponent } from '../../couch-ui/icons';

/** Attachment stub metadata from CouchDB response. */
interface AttachmentStub {
  name: string;
  content_type: string;
  length: number;
  digest: string;
  stub: boolean;
}

/**
 * Document Detail component.
 *
 * Displays a full document body with metadata, attachments, and conflict info.
 * Deep-linkable at /_utils/db/{dbname}/doc/{docid}.
 *
 * Route: /db/:dbname/doc/:docid
 */
@Component({
  selector: 'app-document-detail',
  standalone: true,
  imports: [
    CommonModule,
    PageHeaderComponent,
    BreadcrumbComponent,
    BadgeComponent,
    CopyButtonComponent,
    ErrorDisplayComponent,
    JsonDisplayComponent,
    IconButtonComponent,
    IconDownloadComponent,
  ],
  template: `
    <app-page-header
      [title]="docId"
      [mono]="true"
      [fetchedAt]="fetchedAt"
      [loading]="loading"
      (refresh)="onRefresh()">
      <ng-container breadcrumb>
        <app-breadcrumb [segments]="breadcrumbs"></app-breadcrumb>
      </ng-container>
    </app-page-header>

    <div class="doc-detail" *ngIf="doc && !error">
      <!-- Header zone: _id, _rev, badges -->
      <div class="doc-detail__header">
        <div class="doc-detail__meta-row">
          <span class="doc-detail__id mono">{{ doc._id }}</span>
          <app-copy-button [value]="doc._id" ariaLabel="Copy document ID" />
        </div>
        <div class="doc-detail__meta-row">
          <span class="doc-detail__rev mono">{{ doc._rev }}</span>
          <app-copy-button [value]="doc._rev" ariaLabel="Copy revision" />
        </div>
        <div class="doc-detail__badges" *ngIf="hasAnyBadge">
          <app-badge *ngIf="doc._deleted" variant="warn">deleted</app-badge>
          <span
            *ngIf="conflictCount > 0"
            class="doc-detail__conflict-toggle"
            tabindex="0"
            role="button"
            [attr.aria-expanded]="showConflicts"
            aria-label="Show conflict revisions"
            (click)="toggleConflicts()"
            (keydown.enter)="toggleConflicts()"
            (keydown.space)="toggleConflicts(); $event.preventDefault()">
            <app-badge variant="warn">has conflicts: {{ conflictCount }}</app-badge>
          </span>
          <app-badge *ngIf="attachmentCount > 0" variant="info">has attachments: {{ attachmentCount }}</app-badge>
        </div>
      </div>

      <!-- Conflicts zone -->
      <div class="doc-detail__conflicts" *ngIf="showConflicts && conflicts.length > 0">
        <h2 class="doc-detail__section-title">Conflicting Revisions</h2>
        <ul class="doc-detail__conflict-list">
          <li *ngFor="let rev of conflicts" class="doc-detail__conflict-item">
            <button
              class="doc-detail__conflict-rev mono"
              (click)="fetchConflictRev(rev)"
              [attr.aria-label]="'Load conflict revision ' + rev">
              {{ rev }}
            </button>
          </li>
        </ul>
        <div *ngIf="conflictDoc" class="doc-detail__conflict-body">
          <h3 class="doc-detail__section-subtitle">
            Revision: <span class="mono">{{ conflictRev }}</span>
          </h3>
          <app-json-display [json]="conflictDocJson"></app-json-display>
        </div>
      </div>

      <!-- Body zone -->
      <div class="doc-detail__body">
        <app-json-display [json]="rawJson"></app-json-display>
      </div>

      <!-- Attachment zone -->
      <div class="doc-detail__attachments" *ngIf="attachments.length > 0">
        <h2 class="doc-detail__section-title">Attachments</h2>
        <table class="doc-detail__attachment-table">
          <thead>
            <tr>
              <th>Name</th>
              <th>Content Type</th>
              <th>Size</th>
              <th>Digest</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr *ngFor="let att of attachments">
              <td class="mono">{{ att.name }}</td>
              <td>{{ att.content_type }}</td>
              <td>{{ formatBytes(att.length) }}</td>
              <td class="doc-detail__attachment-digest mono">{{ truncateDigest(att.digest) }}</td>
              <td>
                <a
                  class="doc-detail__attachment-download"
                  [href]="getAttachmentUrl(att.name)"
                  target="_blank"
                  [attr.aria-label]="'Download ' + att.name">
                  <app-icon-button ariaLabel="Download">
                    <app-icon-download [size]="14" />
                  </app-icon-button>
                </a>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- Error state -->
    <div *ngIf="error" class="doc-detail__error">
      <app-error-display
        [error]="error"
        [statusCode]="errorStatus"
        variant="full"
        [retryable]="true"
        (retry)="onRefresh()">
      </app-error-display>
    </div>
  `,
  styles: [`
    :host {
      display: block;
      padding: 0 var(--space-6);
    }

    .doc-detail__header {
      display: flex;
      flex-direction: column;
      gap: var(--space-2);
      padding-bottom: var(--space-4);
    }

    .doc-detail__meta-row {
      display: flex;
      align-items: center;
      gap: var(--space-1);
    }

    .doc-detail__id {
      font-size: var(--font-size-lg);
      font-weight: 600;
      color: var(--color-neutral-800);
    }

    .doc-detail__rev {
      font-size: var(--font-size-sm);
      color: var(--color-neutral-600);
    }

    .doc-detail__badges {
      display: flex;
      align-items: center;
      gap: var(--space-2);
      padding-top: var(--space-1);
    }

    .doc-detail__conflict-toggle {
      cursor: pointer;
      display: inline-flex;
    }

    .doc-detail__conflict-toggle:focus-visible {
      outline: 2px solid var(--color-info);
      outline-offset: 2px;
      border-radius: var(--border-radius);
    }

    .doc-detail__body {
      padding-bottom: var(--space-4);
    }

    .doc-detail__section-title {
      font-size: var(--font-size-md);
      font-weight: 600;
      color: var(--color-neutral-700);
      padding-bottom: var(--space-2);
    }

    .doc-detail__section-subtitle {
      font-size: var(--font-size-sm);
      font-weight: 500;
      color: var(--color-neutral-600);
      padding-bottom: var(--space-2);
    }

    .doc-detail__conflicts {
      padding-bottom: var(--space-4);
    }

    .doc-detail__conflict-list {
      list-style: none;
      padding: 0;
      margin: 0;
      display: flex;
      flex-direction: column;
      gap: var(--space-1);
      padding-bottom: var(--space-3);
    }

    .doc-detail__conflict-rev {
      font-size: var(--font-size-sm);
      color: var(--color-info);
      background: none;
      border: none;
      cursor: pointer;
      padding: var(--space-1) var(--space-2);
      border-radius: var(--border-radius);
    }

    .doc-detail__conflict-rev:hover {
      background-color: var(--color-neutral-50);
      text-decoration: underline;
    }

    .doc-detail__conflict-rev:focus-visible {
      outline: 2px solid var(--color-info);
      outline-offset: 2px;
    }

    .doc-detail__conflict-body {
      padding-top: var(--space-2);
    }

    .doc-detail__attachments {
      padding-bottom: var(--space-4);
    }

    .doc-detail__attachment-table {
      width: 100%;
      border-collapse: collapse;
    }

    .doc-detail__attachment-table th {
      height: 32px;
      padding: 0 var(--space-3);
      font-size: var(--font-size-xs);
      font-weight: 600;
      color: var(--color-neutral-500);
      text-align: left;
      border-bottom: 1px solid var(--color-neutral-200);
    }

    .doc-detail__attachment-table td {
      height: 28px;
      padding: 0 var(--space-3);
      font-size: var(--font-size-xs);
      color: var(--color-neutral-700);
      border-bottom: 1px solid var(--color-neutral-100);
    }

    .doc-detail__attachment-digest {
      max-width: 100px;
      overflow: hidden;
      text-overflow: ellipsis;
    }

    .doc-detail__attachment-download {
      color: var(--color-info);
      text-decoration: none;
    }

    .doc-detail__error {
      padding-top: var(--space-4);
    }

    .mono {
      font-family: var(--font-mono);
    }
  `]
})
export class DocumentDetailComponent implements OnInit, OnDestroy {
  dbName = '';
  docId = '';
  doc: any = null;
  rawJson = '';
  loading = false;
  fetchedAt: Date | null = null;

  // Error state
  error: { error: string; reason: string } | null = null;
  errorStatus: number | undefined;

  // Badges
  conflictCount = 0;
  attachmentCount = 0;

  // Conflicts
  conflicts: string[] = [];
  showConflicts = false;
  conflictDoc: any = null;
  conflictRev = '';
  conflictDocJson = '';

  // Attachments
  attachments: AttachmentStub[] = [];

  // Breadcrumbs
  breadcrumbs: BreadcrumbSegment[] = [];

  private subscriptions: Subscription[] = [];
  private activeRequest?: Subscription;
  private conflictRequest?: Subscription;

  constructor(
    private readonly route: ActivatedRoute,
    private readonly docService: DocumentService,
  ) {}

  get hasAnyBadge(): boolean {
    return !!this.doc?._deleted || this.conflictCount > 0 || this.attachmentCount > 0;
  }

  ngOnInit(): void {
    this.subscriptions.push(
      this.route.paramMap.subscribe((params) => {
        this.dbName = params.get('dbname') || '';
        this.docId = params.get('docid') || '';
        this.breadcrumbs = [
          { label: 'Databases', url: '/databases' },
          { label: this.dbName, url: `/db/${this.dbName}` },
          { label: this.docId },
        ];
        this.loadDocument();
      })
    );
  }

  ngOnDestroy(): void {
    this.activeRequest?.unsubscribe();
    this.conflictRequest?.unsubscribe();
    this.subscriptions.forEach((s) => s.unsubscribe());
  }

  onRefresh(): void {
    this.loadDocument();
  }

  toggleConflicts(): void {
    this.showConflicts = !this.showConflicts;
    // Clear any previously fetched conflict doc
    if (!this.showConflicts) {
      this.conflictDoc = null;
      this.conflictRev = '';
      this.conflictDocJson = '';
    }
  }

  fetchConflictRev(rev: string): void {
    this.conflictRequest?.unsubscribe();
    this.conflictRev = rev;
    this.conflictRequest = this.docService.getDocument(this.dbName, this.docId, { rev }).subscribe({
      next: (doc) => {
        this.conflictDoc = doc;
        this.conflictDocJson = JSON.stringify(doc);
      },
      error: () => {
        this.conflictDoc = null;
        this.conflictDocJson = '';
      },
    });
  }

  formatBytes(bytes: number): string {
    if (bytes === 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    const k = 1024;
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    const value = bytes / Math.pow(k, i);
    return `${value % 1 === 0 ? value : value.toFixed(1)} ${units[i]}`;
  }

  truncateDigest(digest: string): string {
    return digest?.substring(0, 12) || '';
  }

  getAttachmentUrl(name: string): string {
    return `/${encodeURIComponent(this.dbName)}/${encodeURIComponent(this.docId)}/${encodeURIComponent(name)}`;
  }

  private loadDocument(): void {
    this.activeRequest?.unsubscribe();
    this.loading = true;
    this.error = null;
    this.errorStatus = undefined;

    this.activeRequest = this.docService.getDocument(this.dbName, this.docId).subscribe({
      next: (doc) => {
        this.doc = doc;
        this.rawJson = JSON.stringify(doc);
        this.loading = false;
        this.fetchedAt = new Date();

        // Parse conflicts
        this.conflicts = doc._conflicts || [];
        this.conflictCount = this.conflicts.length;

        // Parse attachments
        this.attachments = [];
        if (doc._attachments) {
          this.attachments = Object.entries(doc._attachments).map(([name, meta]: [string, any]) => ({
            name,
            content_type: meta.content_type,
            length: meta.length,
            digest: meta.digest,
            stub: meta.stub,
          }));
        }
        this.attachmentCount = this.attachments.length;
      },
      error: (err) => {
        this.loading = false;
        this.doc = null;
        this.errorStatus = err.status;
        this.error = err.error || { error: 'unknown', reason: 'An unexpected error occurred' };
      },
    });
  }
}
