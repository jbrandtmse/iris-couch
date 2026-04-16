import { Component, OnInit, OnDestroy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute } from '@angular/router';
import { LiveAnnouncer } from '@angular/cdk/a11y';
import { Subscription } from 'rxjs';
import { SecurityService, SecurityDoc } from '../../services/security.service';
import { mapError } from '../../services/error-mapping';
import { PageHeaderComponent } from '../../couch-ui/page-header/page-header.component';
import { BreadcrumbComponent, BreadcrumbSegment } from '../../couch-ui/breadcrumb/breadcrumb.component';
import { FeatureErrorComponent } from '../../couch-ui/feature-error/feature-error.component';
import { JsonDisplayComponent } from '../../couch-ui/json-display/json-display.component';

/**
 * Security Configuration View — feature component for the
 * `/db/:dbname/security` route.
 *
 * Alpha scope: read-only. Displays the full JSON body of the database's
 * `_security` document via `JsonDisplay`. No `_id`/`_rev` — `_security` is
 * a special endpoint, not a regular document. No edit controls; Story 11.3
 * adds editing.
 *
 * Deep-linkable: the URL alone renders the full view without requiring a
 * list view to be visited first (AC #3).
 *
 * Backend normalization (AC #2): the service normalizes `{}` or partially
 * populated responses into the full default shape with empty names/roles
 * arrays, so the JSON body is always well-formed.
 *
 * See Story 11.2 AC #1, AC #2, AC #3, AC #4, AC #5.
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
      <!-- Body zone: full JSON, with JsonDisplay's "Copy raw JSON" strip (AC #5) -->
      <div class="security-view__body">
        <app-json-display [json]="rawJson"></app-json-display>
      </div>
    </div>

    <!-- Error state: verbatim backend envelope via FeatureError (AC #4) -->
    <div *ngIf="error" class="security-view__error">
      <app-feature-error
        [error]="error"
        [statusCode]="errorStatus"
        [retryable]="true"
        (retry)="loadSecurity()">
      </app-feature-error>
    </div>
  `,
  styles: [`
    :host {
      display: block;
      padding: 0 var(--space-6);
    }

    .security-view__body {
      padding-bottom: var(--space-4);
    }

    .security-view__error {
      padding-top: var(--space-4);
    }
  `],
})
export class SecurityViewComponent implements OnInit, OnDestroy {
  dbName = '';

  security: SecurityDoc | null = null;
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

  loadSecurity(): void {
    // Cancel any in-flight request -- see .claude/rules/angular-patterns.md.
    this.activeRequest?.unsubscribe();

    this.loading = true;
    this.error = null;
    this.errorStatus = undefined;

    this.activeRequest = this.securityService.getSecurity(this.dbName).subscribe({
      next: (sec) => {
        this.security = sec;
        // AC #5: raw JSON body with 2-space indentation for readability.
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
}
