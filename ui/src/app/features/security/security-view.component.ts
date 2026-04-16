import { Component, OnInit, OnDestroy, HostListener } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute } from '@angular/router';
import { LiveAnnouncer } from '@angular/cdk/a11y';
import { Subscription } from 'rxjs';
import {
  SecurityService,
  SecurityDoc,
  normalizeSecurity,
} from '../../services/security.service';
import { mapError } from '../../services/error-mapping';
import { HasUnsavedChanges } from '../../services/unsaved-changes.guard';
import { PageHeaderComponent } from '../../couch-ui/page-header/page-header.component';
import { BreadcrumbComponent, BreadcrumbSegment } from '../../couch-ui/breadcrumb/breadcrumb.component';
import { FeatureErrorComponent } from '../../couch-ui/feature-error/feature-error.component';
import { JsonDisplayComponent } from '../../couch-ui/json-display/json-display.component';
import { TextAreaJsonComponent, TextAreaJsonValidity } from '../../couch-ui/text-area-json/text-area-json.component';
import { ButtonComponent } from '../../couch-ui/button/button.component';
import { ConfirmDialogComponent } from '../../couch-ui/confirm-dialog/confirm-dialog.component';

type ViewMode = 'view' | 'edit';

/**
 * Security Configuration View — feature component for the
 * `/db/:dbname/security` route.
 *
 * Beta scope (Story 11.3): adds Edit/Save on top of the read-only view from
 * Story 11.2. No Delete: `_security` is not a regular document and cannot be
 * deleted; it can only be reset to defaults by saving the empty
 * `{admins:{names:[],roles:[]},members:{names:[],roles:[]}}` shape.
 *
 * Implements `HasUnsavedChanges` for the shared `unsavedChangesGuard`.
 *
 * See Story 11.3 AC #5, #6, #7, #8.
 */
@Component({
  selector: 'app-security-view',
  standalone: true,
  imports: [
    CommonModule,
    PageHeaderComponent,
    BreadcrumbComponent,
    FeatureErrorComponent,
    JsonDisplayComponent,
    TextAreaJsonComponent,
    ButtonComponent,
    ConfirmDialogComponent,
  ],
  template: `
    <app-page-header
      title="Security"
      [fetchedAt]="fetchedAt"
      [loading]="loading"
      (refresh)="loadSecurity()">
      <ng-container breadcrumb>
        <app-breadcrumb [segments]="breadcrumbs"></app-breadcrumb>
      </ng-container>
    </app-page-header>

    <div class="security-view" *ngIf="security && !error">
      <!-- Action bar -->
      <div class="security-view__actions" role="toolbar" aria-label="Security actions">
        <ng-container *ngIf="mode === 'view'">
          <app-button variant="primary" (click)="onEdit()">Edit</app-button>
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

      <!-- Save error envelope (AC #8) -->
      <div *ngIf="saveError" class="security-view__save-error">
        <app-feature-error
          [error]="saveError"
          [statusCode]="saveErrorStatus"
          [retryable]="false">
        </app-feature-error>
      </div>

      <!-- View mode -->
      <div class="security-view__body" *ngIf="mode === 'view'">
        <app-json-display [json]="rawJson"></app-json-display>
      </div>

      <!-- Edit mode -->
      <div class="security-view__body" *ngIf="mode === 'edit'">
        <app-text-area-json
          label="Security configuration"
          [(value)]="editValue"
          (validityChange)="onEditValidity($event)"
          [rows]="14">
        </app-text-area-json>
      </div>
    </div>

    <!-- Error state -->
    <div *ngIf="error" class="security-view__error">
      <app-feature-error
        [error]="error"
        [statusCode]="errorStatus"
        [retryable]="true"
        (retry)="loadSecurity()">
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
  `,
  styles: [`
    :host {
      display: block;
      padding: 0 var(--space-6);
    }

    .security-view__actions {
      display: flex;
      justify-content: flex-end;
      gap: var(--space-2);
      padding-bottom: var(--space-4);
    }

    .security-view__body {
      padding-bottom: var(--space-4);
    }

    .security-view__save-error,
    .security-view__error {
      padding-top: var(--space-4);
      padding-bottom: var(--space-4);
    }
  `],
})
export class SecurityViewComponent implements OnInit, OnDestroy, HasUnsavedChanges {
  dbName = '';

  security: SecurityDoc | null = null;
  rawJson = '';
  loading = false;
  fetchedAt: Date | null = null;

  // Mode + edit state
  mode: ViewMode = 'view';
  editValue = '';
  editValid = false;
  private editBaseline = '';
  saving = false;
  saveError: { error: string; reason: string } | null = null;
  saveErrorStatus: number | undefined;

  // Discard dialog state
  showDiscardDialog = false;
  private discardResolver: ((discard: boolean) => void) | null = null;

  // Error state
  error: { error: string; reason: string } | null = null;
  errorStatus: number | undefined;

  // Breadcrumbs
  breadcrumbs: BreadcrumbSegment[] = [];

  private subscriptions: Subscription[] = [];
  private activeRequest?: Subscription;

  constructor(
    private readonly route: ActivatedRoute,
    private readonly securityService: SecurityService,
    private readonly liveAnnouncer: LiveAnnouncer,
  ) {}

  ngOnInit(): void {
    this.subscriptions.push(
      this.route.paramMap.subscribe((params) => {
        this.dbName = params.get('dbname') || '';
        this.breadcrumbs = [
          { label: 'Databases', url: '/databases' },
          { label: this.dbName, url: `/db/${this.dbName}` },
          { label: 'Security' },
        ];
        this.loadSecurity();
      }),
    );
  }

  ngOnDestroy(): void {
    this.activeRequest?.unsubscribe();
    this.subscriptions.forEach((s) => s.unsubscribe());
  }

  // -------------- HasUnsavedChanges contract --------------

  hasUnsavedChanges(): boolean {
    return this.mode === 'edit' && this.editValue !== this.editBaseline;
  }

  confirmDiscard(): Promise<boolean> {
    return new Promise<boolean>((resolve) => {
      this.discardResolver = resolve;
      this.showDiscardDialog = true;
    });
  }

  // -------------- Load --------------

  loadSecurity(): void {
    this.activeRequest?.unsubscribe();

    this.loading = true;
    this.error = null;
    this.errorStatus = undefined;

    this.activeRequest = this.securityService.getSecurity(this.dbName).subscribe({
      next: (sec) => {
        this.security = sec;
        this.rawJson = JSON.stringify(sec, null, 2);
        this.loading = false;
        this.fetchedAt = new Date();
        this.liveAnnouncer.announce(`Loaded security for ${this.dbName}`);
      },
      error: (err: unknown) => {
        this.loading = false;
        this.security = null;
        this.rawJson = '';
        const mapped = mapError(err);
        this.error = mapped.display;
        this.errorStatus = mapped.statusCode;
      },
    });
  }

  // -------------- Edit / Save / Cancel --------------

  onEdit(): void {
    if (!this.security) return;
    this.editValue = JSON.stringify(this.security, null, 2);
    this.editBaseline = this.editValue;
    this.editValid = true;
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
    // Normalize the parsed JSON to enforce the {admins,members} shape so
    // a user who clears nested arrays does not accidentally lock themselves
    // out via a malformed `_security` document. The backend would accept
    // anything, but we save the user from the mistake here.
    const normalized = normalizeSecurity(parsed);
    this.activeRequest?.unsubscribe();
    this.saving = true;
    this.saveError = null;
    this.saveErrorStatus = undefined;
    this.activeRequest = this.securityService.setSecurity(this.dbName, normalized).subscribe({
      next: () => {
        this.saving = false;
        this.mode = 'view';
        this.editBaseline = this.editValue;
        this.liveAnnouncer.announce(`Saved security for ${this.dbName}`);
        this.loadSecurity();
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
      if (discard) this.exitEditMode();
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
    if (this.showDiscardDialog) return;
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
}
