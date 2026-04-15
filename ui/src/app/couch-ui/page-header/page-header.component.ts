import { Component, Input, Output, EventEmitter, OnInit, OnDestroy, OnChanges } from '@angular/core';
import { CommonModule } from '@angular/common';
import { IconButtonComponent } from '../icon-button/icon-button.component';
import { IconRefreshComponent } from '../icons';

/**
 * CouchUI PageHeader component.
 *
 * Horizontal flex layout: title block (left) + action cluster (right).
 * Shows a fetched-at timestamp with relative/absolute format,
 * a refresh icon button, and a 300ms-delayed loading bar at the top.
 *
 * Content projection for action buttons (right side) and breadcrumb (above title).
 *
 * Usage:
 *   <app-page-header
 *     title="Databases"
 *     [fetchedAt]="lastFetched"
 *     [loading]="isLoading"
 *     (refresh)="onRefresh()">
 *     <ng-container breadcrumb>
 *       <app-breadcrumb [segments]="crumbs"></app-breadcrumb>
 *     </ng-container>
 *     <ng-container actions>
 *       <app-button variant="primary">Create database</app-button>
 *     </ng-container>
 *   </app-page-header>
 */
@Component({
  selector: 'app-page-header',
  standalone: true,
  imports: [CommonModule, IconButtonComponent, IconRefreshComponent],
  template: `
    <!-- 300ms-delayed loading bar -->
    <div
      *ngIf="showLoadingBar"
      class="page-header__loading-bar"
      role="progressbar"
      aria-label="Loading data">
    </div>

    <div class="page-header">
      <div class="page-header__left">
        <div class="page-header__breadcrumb">
          <ng-content select="[breadcrumb]"></ng-content>
        </div>
        <h1
          class="page-header__title"
          [class.page-header__title--mono]="mono">
          {{ title }}
        </h1>
        <div class="page-header__meta" *ngIf="fetchedAt">
          <span class="page-header__timestamp">{{ formattedTimestamp }}</span>
          <app-icon-button ariaLabel="Refresh data" (click)="refresh.emit()">
            <app-icon-refresh [size]="14" />
          </app-icon-button>
        </div>
      </div>
      <div class="page-header__right">
        <ng-content select="[actions]"></ng-content>
      </div>
    </div>
  `,
  styles: [`
    :host {
      display: block;
      position: relative;
    }

    .page-header__loading-bar {
      position: absolute;
      top: 0;
      left: 0;
      right: 0;
      height: 2px;
      background-color: var(--color-info);
      animation: loading-progress 1.5s ease-in-out infinite;
    }

    @keyframes loading-progress {
      0% { transform: scaleX(0); transform-origin: left; }
      50% { transform: scaleX(1); transform-origin: left; }
      50.1% { transform: scaleX(1); transform-origin: right; }
      100% { transform: scaleX(0); transform-origin: right; }
    }

    .page-header {
      display: flex;
      align-items: flex-start;
      justify-content: space-between;
      gap: var(--space-4);
      padding: var(--space-4) 0;
    }

    .page-header__left {
      display: flex;
      flex-direction: column;
      gap: var(--space-1);
    }

    .page-header__breadcrumb:empty {
      display: none;
    }

    .page-header__title {
      font-size: var(--font-size-xl);
      line-height: var(--line-height-xl);
      font-weight: 600;
      color: var(--color-neutral-800);
      margin: 0;
    }

    .page-header__title--mono {
      font-family: var(--font-mono);
    }

    .page-header__meta {
      display: flex;
      align-items: center;
      gap: var(--space-1);
    }

    .page-header__timestamp {
      font-size: var(--font-size-xs);
      line-height: var(--line-height-xs);
      color: var(--color-neutral-500);
    }

    .page-header__right {
      display: flex;
      align-items: center;
      gap: var(--space-2);
      flex-shrink: 0;
    }

    @media (prefers-reduced-motion: reduce) {
      .page-header__loading-bar {
        animation: none;
        transform: scaleX(1);
      }
    }
  `]
})
export class PageHeaderComponent implements OnInit, OnDestroy, OnChanges {
  @Input({ required: true }) title!: string;
  @Input() mono = false;
  @Input() fetchedAt: Date | null = null;
  @Input() loading = false;

  @Output() refresh = new EventEmitter<void>();

  showLoadingBar = false;
  formattedTimestamp = '';

  private loadingTimer: ReturnType<typeof setTimeout> | null = null;
  private timestampTimer: ReturnType<typeof setInterval> | null = null;

  ngOnInit(): void {
    this.timestampTimer = setInterval(() => this.updateTimestamp(), 1000);
  }

  ngOnDestroy(): void {
    if (this.loadingTimer) clearTimeout(this.loadingTimer);
    if (this.timestampTimer) clearInterval(this.timestampTimer);
  }

  /** React to loading changes: show bar after 300ms delay. */
  ngOnChanges(): void {
    this.updateTimestamp();
    this.updateLoadingBar();
  }

  private updateLoadingBar(): void {
    if (this.loading) {
      if (!this.loadingTimer && !this.showLoadingBar) {
        this.loadingTimer = setTimeout(() => {
          this.showLoadingBar = true;
          this.loadingTimer = null;
        }, 300);
      }
    } else {
      if (this.loadingTimer) {
        clearTimeout(this.loadingTimer);
        this.loadingTimer = null;
      }
      this.showLoadingBar = false;
    }
  }

  private updateTimestamp(): void {
    if (!this.fetchedAt) {
      this.formattedTimestamp = '';
      return;
    }
    const now = Date.now();
    const diff = now - this.fetchedAt.getTime();
    const seconds = Math.floor(diff / 1000);

    if (seconds < 60) {
      this.formattedTimestamp = `${seconds}s ago`;
    } else {
      this.formattedTimestamp = this.fetchedAt.toISOString();
    }
  }
}
