import { Component, OnInit, OnDestroy, HostListener } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, Router } from '@angular/router';
import { LiveAnnouncer } from '@angular/cdk/a11y';
import { Subscription } from 'rxjs';
import { DocumentService } from '../../services/document.service';
import { mapError } from '../../services/error-mapping';
import { HasUnsavedChanges } from '../../services/unsaved-changes.guard';
import { PageHeaderComponent } from '../../couch-ui/page-header/page-header.component';
import { BreadcrumbComponent, BreadcrumbSegment } from '../../couch-ui/breadcrumb/breadcrumb.component';
import { CopyButtonComponent } from '../../couch-ui/copy-button/copy-button.component';
import { FeatureErrorComponent } from '../../couch-ui/feature-error/feature-error.component';
import { JsonDisplayComponent } from '../../couch-ui/json-display/json-display.component';
import { TextAreaJsonComponent, TextAreaJsonValidity } from '../../couch-ui/text-area-json/text-area-json.component';
import { ButtonComponent } from '../../couch-ui/button/button.component';
import { ConfirmDialogComponent } from '../../couch-ui/confirm-dialog/confirm-dialog.component';

type ViewMode = 'view' | 'edit';

/**
 * Design Document Detail — feature component for the
 * `/db/:dbname/design/:ddocname[/...]` route.
 *
 * Beta scope (Story 11.3): adds Edit/Save/Delete on top of the read-only
 * detail view from Story 11.1. Switching to edit mode hides the
 * `JsonDisplay` and renders a `TextAreaJson` populated with the document
 * body (sans `_id`/`_rev` metadata). Save issues a `PUT` with the current
 * `?rev=`; Delete asks for type-to-confirm before issuing a `DELETE`.
 *
 * Implements `HasUnsavedChanges` for the shared `unsavedChangesGuard` so
 * navigating away with a dirty editor opens the same warning dialog as
 * Cancel-from-edit.
 *
 * See Story 11.3 AC #2, #4, #6, #7, #8.
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
    TextAreaJsonComponent,
    ButtonComponent,
    ConfirmDialogComponent,
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
      <!-- Action bar (AC #2 + #4) -->
      <div class="ddoc-detail__actions" role="toolbar" aria-label="Design document actions">
        <ng-container *ngIf="mode === 'view'">
          <app-button variant="primary" (click)="onEdit()">Edit</app-button>
          <app-button variant="destructive" (click)="onDeleteClick()">Delete</app-button>
        </ng-container>
        <ng-container *ngIf="mode === 'edit'">
          <app-button
            variant="primary"
            [disabled]="!editValid || saving"
            [loading]="saving"
            (click)="onSave()">Save</app-button>
          <app-button variant="ghost" [disabled]="saving" (click)="onCancel()">Cancel</app-button>
        </ng-container>
      </div>

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

      <!-- Save error envelope (AC #8) -->
      <div *ngIf="saveError" class="ddoc-detail__save-error">
        <app-feature-error
          [error]="saveError"
          [statusCode]="saveErrorStatus"
          [retryable]="false">
        </app-feature-error>
      </div>

      <!-- View mode: JsonDisplay (read-only) -->
      <div class="ddoc-detail__body" *ngIf="mode === 'view'">
        <app-json-display [json]="rawJson"></app-json-display>
      </div>

      <!-- Edit mode: TextAreaJson -->
      <div class="ddoc-detail__body" *ngIf="mode === 'edit'">
        <app-text-area-json
          label="Design document body"
          [(value)]="editValue"
          (validityChange)="onEditValidity($event)"
          [rows]="20">
        </app-text-area-json>
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

    <!-- Discard-changes warning dialog (AC #7) -->
    <app-confirm-dialog
      *ngIf="showDiscardDialog"
      title="Discard changes?"
      body="You have unsaved changes. Discard them?"
      variant="warning"
      confirmLabel="Discard"
      (confirm)="onDiscardConfirmed()"
      (cancel)="onDiscardCancelled()">
    </app-confirm-dialog>

    <!-- Delete confirm dialog (AC #4) -->
    <app-confirm-dialog
      *ngIf="showDeleteDialog"
      title="Delete design document"
      [body]="'This will permanently delete the design document &lt;code class=&quot;mono&quot;&gt;' + ddocShortName + '&lt;/code&gt; and all associated views.'"
      variant="destructive-type-to-confirm"
      confirmLabel="Delete"
      [confirmValue]="ddocShortName"
      [loading]="deleting"
      [serverError]="deleteError ?? undefined"
      [serverErrorCode]="deleteErrorStatus"
      (confirm)="onDeleteConfirmed()"
      (cancel)="onDeleteCancelled()">
    </app-confirm-dialog>
  `,
  styles: [`
    :host {
      display: block;
      padding: 0 var(--space-6);
    }

    .ddoc-detail__actions {
      display: flex;
      justify-content: flex-end;
      gap: var(--space-2);
      padding-bottom: var(--space-4);
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

    .ddoc-detail__save-error,
    .ddoc-detail__error {
      padding-top: var(--space-4);
      padding-bottom: var(--space-4);
    }

    .mono {
      font-family: var(--font-mono);
    }
  `],
})
export class DesignDocDetailComponent implements OnInit, OnDestroy, HasUnsavedChanges {
  dbName = '';
  /** Full composite ID on the wire, e.g. `_design/myapp`. */
  ddocId = '';
  /** Short (non-prefix) name, e.g. `myapp`. Used in the breadcrumb. */
  ddocShortName = '';

  doc: any = null;
  rawJson = '';
  loading = false;
  fetchedAt: Date | null = null;

  // Mode + edit state
  mode: ViewMode = 'view';
  editValue = '';
  editValid = false;
  /** Snapshot of `editValue` taken when entering edit mode -- compared
   *  against current `editValue` for dirty detection. */
  private editBaseline = '';
  saving = false;
  saveError: { error: string; reason: string } | null = null;
  saveErrorStatus: number | undefined;

  // Delete state
  showDeleteDialog = false;
  deleting = false;
  deleteError: { error: string; reason: string } | null = null;
  deleteErrorStatus: number | undefined;

  // Discard-changes dialog
  showDiscardDialog = false;
  /** Pending callback to resolve the discard prompt's promise. */
  private discardResolver: ((discard: boolean) => void) | null = null;

  // Error state
  error: { error: string; reason: string } | null = null;
  errorStatus: number | undefined;

  // Breadcrumbs
  breadcrumbs: BreadcrumbSegment[] = [];

  private subscriptions: Subscription[] = [];
  /** Active load/save/delete request, cancelled on destroy or before next call. */
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
        const rawDdoc = params.get('ddocid') || '';
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

  // ------------- HasUnsavedChanges contract -------------

  hasUnsavedChanges(): boolean {
    return this.mode === 'edit' && this.editValue !== this.editBaseline;
  }

  confirmDiscard(): Promise<boolean> {
    return new Promise<boolean>((resolve) => {
      this.discardResolver = resolve;
      this.showDiscardDialog = true;
    });
  }

  // ------------- Refresh / Load -------------

  onRefresh(): void {
    this.loadDesignDoc();
  }

  private loadDesignDoc(): void {
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

  // ------------- Edit mode -------------

  onEdit(): void {
    if (!this.doc) return;
    this.editValue = this.serializeBodyForEdit(this.doc);
    this.editBaseline = this.editValue;
    this.editValid = true; // serialized via JSON.stringify -> guaranteed valid
    this.saveError = null;
    this.saveErrorStatus = undefined;
    this.mode = 'edit';
  }

  onEditValidity(v: TextAreaJsonValidity): void {
    this.editValid = v.valid;
  }

  onSave(): void {
    if (!this.editValid || this.saving) return;
    let parsed: unknown;
    try {
      parsed = JSON.parse(this.editValue);
    } catch {
      this.editValid = false;
      return;
    }
    this.activeRequest?.unsubscribe();
    this.saving = true;
    this.saveError = null;
    this.saveErrorStatus = undefined;
    const currentRev = this.doc._rev;
    this.activeRequest = this.docService
      .putDocument(this.dbName, this.ddocId, parsed, currentRev)
      .subscribe({
        next: () => {
          this.saving = false;
          this.mode = 'view';
          this.editBaseline = this.editValue;
          this.liveAnnouncer.announce(`Saved design document ${this.ddocId}`);
          // Re-fetch so the displayed _rev and JSON reflect the server state.
          this.loadDesignDoc();
        },
        error: (err: unknown) => {
          this.saving = false;
          const mapped = mapError(err);
          this.saveError = mapped.display;
          this.saveErrorStatus = mapped.statusCode;
        },
      });
  }

  onCancel(): void {
    if (!this.hasUnsavedChanges()) {
      this.exitEditMode();
      return;
    }
    this.confirmDiscard().then((discard) => {
      if (discard) {
        this.exitEditMode();
      }
    });
  }

  /**
   * AC #7 -- pressing Esc while in edit mode behaves like Cancel: exits
   * cleanly if not dirty, otherwise opens the discard-changes warning. Esc
   * is ignored while any modal is already visible (the dialog handles its
   * own Esc), while saving (safety lock), and in view mode.
   */
  @HostListener('document:keydown.escape', ['$event'])
  onEscape(event: KeyboardEvent): void {
    if (this.mode !== 'edit') return;
    if (this.saving) return;
    if (this.showDeleteDialog || this.showDiscardDialog) return;
    event.preventDefault();
    this.onCancel();
  }

  private exitEditMode(): void {
    this.mode = 'view';
    this.editValue = '';
    this.editBaseline = '';
    this.saveError = null;
    this.saveErrorStatus = undefined;
  }

  // Discard dialog callbacks -- resolve the pending confirmDiscard() promise.
  onDiscardConfirmed(): void {
    this.showDiscardDialog = false;
    this.discardResolver?.(true);
    this.discardResolver = null;
  }

  onDiscardCancelled(): void {
    this.showDiscardDialog = false;
    this.discardResolver?.(false);
    this.discardResolver = null;
  }

  // ------------- Delete -------------

  onDeleteClick(): void {
    this.deleteError = null;
    this.deleteErrorStatus = undefined;
    this.showDeleteDialog = true;
  }

  onDeleteConfirmed(): void {
    if (this.deleting) return;
    this.activeRequest?.unsubscribe();
    this.deleting = true;
    this.deleteError = null;
    const currentRev = this.doc._rev;
    this.activeRequest = this.docService
      .deleteDocument(this.dbName, this.ddocId, currentRev)
      .subscribe({
        next: () => {
          this.deleting = false;
          this.showDeleteDialog = false;
          this.liveAnnouncer.announce(`Deleted design document ${this.ddocId}`);
          this.router.navigate(['/db', this.dbName, 'design']);
        },
        error: (err: unknown) => {
          this.deleting = false;
          const mapped = mapError(err);
          this.deleteError = mapped.display;
          this.deleteErrorStatus = mapped.statusCode;
        },
      });
  }

  onDeleteCancelled(): void {
    if (this.deleting) return;
    this.showDeleteDialog = false;
    this.deleteError = null;
    this.deleteErrorStatus = undefined;
  }

  // ------------- Helpers -------------

  /**
   * Serialize the doc body for the editor, stripping the metadata fields
   * that the user should not edit (`_id` and `_rev` are resource identity;
   * `_revisions`/`_conflicts` are server-computed and re-applied on read).
   */
  private serializeBodyForEdit(doc: Record<string, unknown>): string {
    const stripped: Record<string, unknown> = { ...doc };
    delete stripped['_id'];
    delete stripped['_rev'];
    delete stripped['_revisions'];
    delete stripped['_conflicts'];
    return JSON.stringify(stripped, null, 2);
  }
}
