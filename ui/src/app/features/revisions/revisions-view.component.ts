import {
  Component,
  OnInit,
  OnDestroy,
  HostListener,
  ChangeDetectionStrategy,
  ChangeDetectorRef,
} from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, Router } from '@angular/router';
import { LiveAnnouncer } from '@angular/cdk/a11y';
import { Subscription } from 'rxjs';
import { RevisionsService, RevisionTreeResult } from '../../services/revisions.service';
import { DocumentService } from '../../services/document.service';
import { mapError } from '../../services/error-mapping';
import {
  PageHeaderComponent,
  BreadcrumbComponent,
  BreadcrumbSegment,
  FeatureErrorComponent,
  JsonDisplayComponent,
  ButtonComponent,
  RevisionTreeComponent,
} from '../../couch-ui';

/**
 * Revisions View (Story 11.4 — γ scope).
 *
 * Deep-linkable revision-history page at
 * `/db/{dbname}/doc/{docid}/revisions[?rev={rev}]`.
 *
 * Responsibilities:
 *  - Fetch the tree via `RevisionsService.getRevisionTree`
 *  - Render the `RevisionTreeComponent` primitive
 *  - When a node is selected, fetch that rev's body and display via
 *    `JsonDisplayComponent` beneath the tree
 *  - Handle URL `?rev=` for deep-link + back-button behavior
 *  - Esc / "Back to document" returns the operator to the document detail
 *
 * Subscription discipline: two separate `activeRequest` slots — one for
 * the tree fetch, one for the per-rev body fetch. Both are cancelled
 * before re-issue and cleared on `ngOnDestroy`
 * (per `.claude/rules/angular-patterns.md`).
 */
@Component({
  selector: 'app-revisions-view',
  standalone: true,
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [
    CommonModule,
    PageHeaderComponent,
    BreadcrumbComponent,
    FeatureErrorComponent,
    JsonDisplayComponent,
    ButtonComponent,
    RevisionTreeComponent,
  ],
  template: `
    <app-page-header
      [title]="'Revision History — ' + docId"
      [mono]="false"
      [fetchedAt]="fetchedAt"
      [loading]="loading"
      (refresh)="onRefresh()">
      <ng-container breadcrumb>
        <app-breadcrumb [segments]="breadcrumbs"></app-breadcrumb>
      </ng-container>
      <ng-container actions>
        <app-button variant="ghost" (click)="backToDocument()">
          Back to document
        </app-button>
      </ng-container>
    </app-page-header>

    <div class="revisions-view">
      <ng-container *ngIf="tree && !error">
        <app-revision-tree
          [nodes]="tree.nodes"
          [selectedRev]="selectedRev"
          [loading]="loading"
          (nodeSelect)="onNodeSelect($event)">
        </app-revision-tree>
      </ng-container>

      <ng-container *ngIf="loading && !tree">
        <app-revision-tree [loading]="true"></app-revision-tree>
      </ng-container>

      <div *ngIf="error" class="revisions-view__error">
        <app-feature-error
          [error]="error"
          [statusCode]="errorStatus"
          [retryable]="true"
          (retry)="onRefresh()">
        </app-feature-error>
      </div>

      <div
        *ngIf="selectedRev && tree && !error"
        class="revisions-view__selected">
        <hr class="revisions-view__divider" />
        <h2 class="revisions-view__selected-title">
          Selected revision:
          <span class="mono">{{ selectedRev }}</span>
          <span *ngIf="selectedStatus" class="revisions-view__status">
            ({{ selectedStatus }})
          </span>
        </h2>

        <div *ngIf="bodyError" class="revisions-view__body-error">
          <app-feature-error
            [error]="bodyError"
            [statusCode]="bodyErrorStatus"
            [retryable]="true"
            (retry)="fetchBody(selectedRev)">
          </app-feature-error>
        </div>

        <app-json-display
          *ngIf="selectedBodyJson && !bodyError"
          [json]="selectedBodyJson">
        </app-json-display>
      </div>
    </div>
  `,
  styles: [`
    :host {
      display: block;
      padding: 0 var(--space-6);
    }

    .revisions-view {
      display: flex;
      flex-direction: column;
      gap: var(--space-4);
      padding-bottom: var(--space-8);
    }

    .revisions-view__error {
      padding-top: var(--space-4);
    }

    .revisions-view__divider {
      border: 0;
      height: 1px;
      background: var(--color-neutral-200);
      margin: var(--space-4) 0;
    }

    .revisions-view__selected-title {
      font-size: var(--font-size-md);
      font-weight: 600;
      color: var(--color-neutral-700);
      margin: 0 0 var(--space-2);
    }

    .revisions-view__status {
      color: var(--color-neutral-500);
      font-weight: 400;
    }

    .revisions-view__body-error {
      padding-top: var(--space-2);
    }

    .mono {
      font-family: var(--font-mono);
    }
  `]
})
export class RevisionsViewComponent implements OnInit, OnDestroy {
  dbName = '';
  docId = '';
  tree: RevisionTreeResult | null = null;
  selectedRev: string | null = null;
  selectedBody: any | null = null;
  selectedBodyJson = '';
  loading = false;
  fetchedAt: Date | null = null;
  breadcrumbs: BreadcrumbSegment[] = [];

  error: { error: string; reason: string } | null = null;
  errorStatus: number | undefined;
  bodyError: { error: string; reason: string } | null = null;
  bodyErrorStatus: number | undefined;

  private paramSub?: Subscription;
  private querySub?: Subscription;
  private activeTreeRequest?: Subscription;
  private activeBodyRequest?: Subscription;

  constructor(
    private readonly route: ActivatedRoute,
    private readonly router: Router,
    private readonly revisionsService: RevisionsService,
    private readonly documentService: DocumentService,
    private readonly liveAnnouncer: LiveAnnouncer,
    private readonly cdr: ChangeDetectorRef,
  ) {}

  get selectedStatus(): string | null {
    if (!this.selectedRev || !this.tree) return null;
    const node = this.tree.nodes.find((n) => n.rev === this.selectedRev);
    return node?.status ?? null;
  }

  ngOnInit(): void {
    this.paramSub = this.route.paramMap.subscribe((params) => {
      this.dbName = params.get('dbname') ?? '';
      this.docId = params.get('docid') ?? '';
      this.breadcrumbs = [
        { label: 'Databases', url: '/databases' },
        { label: this.dbName, url: `/db/${this.dbName}` },
        { label: 'Documents', url: `/db/${this.dbName}` },
        { label: this.docId, url: `/db/${this.dbName}/doc/${this.docId}` },
        { label: 'Revisions' },
      ];
      this.loadTree();
    });
    this.querySub = this.route.queryParamMap.subscribe((qp) => {
      const rev = qp.get('rev');
      if (rev && rev !== this.selectedRev) {
        this.selectedRev = rev;
        if (this.tree) this.fetchBody(rev);
      }
    });
  }

  ngOnDestroy(): void {
    this.paramSub?.unsubscribe();
    this.querySub?.unsubscribe();
    this.activeTreeRequest?.unsubscribe();
    this.activeBodyRequest?.unsubscribe();
  }

  onRefresh(): void {
    this.loadTree();
  }

  onNodeSelect(rev: string): void {
    if (rev === this.selectedRev) return; // idempotent — do not re-fetch
    this.selectedRev = rev;
    // Sync URL — replaceUrl keeps history clean
    this.router.navigate([], {
      relativeTo: this.route,
      queryParams: { rev },
      queryParamsHandling: 'merge',
      replaceUrl: true,
    });
    this.fetchBody(rev);
  }

  backToDocument(): void {
    this.router.navigate(['/db', this.dbName, 'doc', ...this.docId.split('/')]);
  }

  @HostListener('document:keydown.escape', ['$event'])
  onEscape(event: KeyboardEvent): void {
    // Ignore if focus is inside an input or textarea so overlays/forms
    // can handle their own Esc.
    const target = event.target as HTMLElement | null;
    const tag = target?.tagName?.toLowerCase() ?? '';
    if (tag === 'input' || tag === 'textarea' || target?.isContentEditable) return;
    // Defer to any open CDK overlay (e.g. the revision-tree hover/focus
    // popover) so Esc dismisses the overlay first. The next Esc press
    // then navigates back to the document. See Story 11.4 Dev Notes
    // ("Disabled when an overlay popover is open").
    if (typeof document !== 'undefined' && document.querySelector('.cdk-overlay-pane')) {
      return;
    }
    this.backToDocument();
  }

  fetchBody(rev: string): void {
    this.activeBodyRequest?.unsubscribe();
    this.bodyError = null;
    this.bodyErrorStatus = undefined;
    this.activeBodyRequest = this.documentService
      .getDocument(this.dbName, this.docId, { rev })
      .subscribe({
        next: (doc) => {
          this.selectedBody = doc;
          this.selectedBodyJson = JSON.stringify(doc);
          this.cdr.markForCheck();
        },
        error: (err: unknown) => {
          this.selectedBody = null;
          this.selectedBodyJson = '';
          const mapped = mapError(err);
          this.bodyError = mapped.display;
          this.bodyErrorStatus = mapped.statusCode;
          this.cdr.markForCheck();
        },
      });
  }

  private loadTree(): void {
    this.activeTreeRequest?.unsubscribe();
    this.loading = true;
    this.error = null;
    this.errorStatus = undefined;
    this.tree = null;

    this.activeTreeRequest = this.revisionsService
      .getRevisionTree(this.dbName, this.docId)
      .subscribe({
        next: (tree) => {
          this.tree = tree;
          this.loading = false;
          this.fetchedAt = new Date();
          // Default selection: the URL's ?rev= param if valid, else the winner
          const qpRev = this.route.snapshot.queryParamMap.get('rev');
          const candidate = qpRev && tree.nodes.some((n) => n.rev === qpRev) ? qpRev : tree.winnerRev;
          if (candidate && candidate !== this.selectedRev) {
            this.selectedRev = candidate;
            this.fetchBody(candidate);
          } else if (candidate && !this.selectedBody) {
            // Same selection as URL, but body not yet loaded
            this.fetchBody(candidate);
          }
          this.liveAnnouncer.announce(`Loaded ${tree.nodes.length} revisions for ${this.docId}`);
          this.cdr.markForCheck();
        },
        error: (err: unknown) => {
          this.loading = false;
          this.tree = null;
          const mapped = mapError(err);
          this.error = mapped.display;
          this.errorStatus = mapped.statusCode;
          this.cdr.markForCheck();
        },
      });
  }
}
