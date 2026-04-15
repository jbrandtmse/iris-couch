import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router } from '@angular/router';
import { HttpErrorResponse } from '@angular/common/http';
import { DatabaseService, DatabaseEntry } from '../../services/database.service';
import { DataTableComponent, ColumnDef, SortChangeEvent } from '../../couch-ui/data-table/data-table.component';
import { EmptyStateComponent } from '../../couch-ui/empty-state/empty-state.component';
import { ConfirmDialogComponent } from '../../couch-ui/confirm-dialog/confirm-dialog.component';
import { PageHeaderComponent } from '../../couch-ui/page-header/page-header.component';
import { ButtonComponent } from '../../couch-ui/button/button.component';
import { IconPlusComponent } from '../../couch-ui/icons';

/**
 * Database List — feature component for the /databases route.
 *
 * Displays all databases in a sortable DataTable with create and delete
 * capabilities via modal dialogs.
 */
@Component({
  selector: 'app-database-list',
  standalone: true,
  imports: [
    CommonModule,
    DataTableComponent,
    EmptyStateComponent,
    ConfirmDialogComponent,
    PageHeaderComponent,
    ButtonComponent,
    IconPlusComponent,
  ],
  template: `
    <app-page-header
      title="Databases"
      [fetchedAt]="fetchedAt"
      [loading]="loading"
      (refresh)="loadDatabases()">
      <ng-container actions>
        <app-button variant="primary" (click)="openCreateDialog()">
          <app-icon-plus [size]="14" />
          Create database
        </app-button>
      </ng-container>
    </app-page-header>

    <!-- Data table -->
    <app-data-table
      *ngIf="!loading && databases.length > 0"
      [columns]="columns"
      [data]="sortedData"
      [sortColumn]="sortColumn"
      [sortDirection]="sortDirection"
      [clickable]="true"
      (sortChange)="onSortChange($event)"
      (rowClick)="onRowClick($event)">
    </app-data-table>

    <!-- Empty state -->
    <app-empty-state
      *ngIf="!loading && databases.length === 0"
      primary="No databases yet."
      secondary="Create one to get started."
      ctaLabel="Create database"
      (ctaClick)="openCreateDialog()">
    </app-empty-state>

    <!-- Create dialog -->
    <app-confirm-dialog
      *ngIf="showCreateDialog"
      title="Create database"
      variant="create"
      confirmLabel="Create"
      inputLabel="Database name"
      inputHint="Lowercase letters, digits, and _$()+-/"
      [serverError]="createError"
      [serverErrorCode]="createErrorCode"
      [loading]="createLoading"
      (confirm)="onCreateConfirm($event)"
      (cancel)="closeCreateDialog()">
    </app-confirm-dialog>

    <!-- Delete dialog -->
    <app-confirm-dialog
      *ngIf="showDeleteDialog"
      [title]="'Delete database'"
      [body]="deleteBody"
      variant="destructive-type-to-confirm"
      confirmLabel="Delete"
      [confirmValue]="deleteTarget?.name || ''"
      [serverError]="deleteError"
      [serverErrorCode]="deleteErrorCode"
      [loading]="deleteLoading"
      (confirm)="onDeleteConfirm()"
      (cancel)="closeDeleteDialog()">
    </app-confirm-dialog>
  `,
  styles: [`
    :host {
      display: block;
      padding: 0 var(--space-6);
    }
  `]
})
export class DatabaseListComponent implements OnInit {
  databases: DatabaseEntry[] = [];
  loading = false;
  fetchedAt: Date | null = null;

  // Sort state
  sortColumn = 'name';
  sortDirection: 'asc' | 'desc' = 'asc';

  // Create dialog
  showCreateDialog = false;
  createLoading = false;
  createError?: { error: string; reason: string };
  createErrorCode?: number;

  // Delete dialog
  showDeleteDialog = false;
  deleteTarget: DatabaseEntry | null = null;
  deleteLoading = false;
  deleteError?: { error: string; reason: string };
  deleteErrorCode?: number;

  // Column definitions
  columns: ColumnDef[] = [
    { key: 'name', label: 'Name', sortable: true, mono: true },
    { key: 'docCount', label: 'Docs', sortable: true, align: 'right', numeric: true },
    {
      key: 'updateSeq',
      label: 'Update Seq',
      sortable: true,
      mono: true,
      format: (v: unknown) => {
        const s = String(v ?? '');
        return s.length > 8 ? s.substring(0, 8) + '\u2026' : s;
      },
    },
    {
      key: 'diskSize',
      label: 'Size',
      sortable: true,
      align: 'right',
      numeric: true,
      format: (v: unknown) => this.formatBytes(v as number),
    },
  ];

  get sortedData(): Record<string, unknown>[] {
    const sorted = [...this.databases] as unknown as Record<string, unknown>[];
    sorted.sort((a, b) => {
      const aVal = a[this.sortColumn];
      const bVal = b[this.sortColumn];
      let cmp = 0;
      if (typeof aVal === 'string' && typeof bVal === 'string') {
        cmp = aVal.localeCompare(bVal);
      } else if (typeof aVal === 'number' && typeof bVal === 'number') {
        cmp = aVal - bVal;
      } else {
        cmp = String(aVal).localeCompare(String(bVal));
      }
      return this.sortDirection === 'asc' ? cmp : -cmp;
    });
    return sorted;
  }

  get deleteBody(): string {
    if (!this.deleteTarget) return '';
    const count = this.deleteTarget.docCount;
    return `This will permanently delete <code>${this.deleteTarget.name}</code> and all ${count} document${count !== 1 ? 's' : ''}.`;
  }

  constructor(
    private readonly dbService: DatabaseService,
    private readonly router: Router,
  ) {}

  ngOnInit(): void {
    this.loadDatabases();
  }

  loadDatabases(): void {
    this.loading = true;
    this.dbService.listAllWithInfo().subscribe({
      next: (entries) => {
        this.databases = entries;
        this.fetchedAt = new Date();
        this.loading = false;
      },
      error: () => {
        this.loading = false;
      },
    });
  }

  onSortChange(event: SortChangeEvent): void {
    this.sortColumn = event.column;
    this.sortDirection = event.direction;
  }

  onRowClick(row: Record<string, unknown>): void {
    this.router.navigate(['/db', row['name']]);
  }

  // ── Create Database ──

  openCreateDialog(): void {
    this.showCreateDialog = true;
    this.createError = undefined;
    this.createErrorCode = undefined;
  }

  closeCreateDialog(): void {
    this.showCreateDialog = false;
    this.createError = undefined;
    this.createErrorCode = undefined;
    this.createLoading = false;
  }

  onCreateConfirm(name: string): void {
    this.createLoading = true;
    this.createError = undefined;
    this.dbService.createDatabase(name).subscribe({
      next: () => {
        this.closeCreateDialog();
        this.loadDatabases();
      },
      error: (err: HttpErrorResponse) => {
        this.createLoading = false;
        this.createErrorCode = err.status;
        this.createError = err.error && typeof err.error === 'object'
          ? err.error
          : { error: 'unknown', reason: 'An unexpected error occurred' };
      },
    });
  }

  // ── Delete Database ──

  openDeleteDialog(db: DatabaseEntry): void {
    this.deleteTarget = db;
    this.showDeleteDialog = true;
    this.deleteError = undefined;
    this.deleteErrorCode = undefined;
  }

  closeDeleteDialog(): void {
    this.showDeleteDialog = false;
    this.deleteTarget = null;
    this.deleteError = undefined;
    this.deleteErrorCode = undefined;
    this.deleteLoading = false;
  }

  onDeleteConfirm(): void {
    if (!this.deleteTarget) return;
    this.deleteLoading = true;
    this.deleteError = undefined;
    this.dbService.deleteDatabase(this.deleteTarget.name).subscribe({
      next: () => {
        this.closeDeleteDialog();
        this.loadDatabases();
      },
      error: (err: HttpErrorResponse) => {
        this.deleteLoading = false;
        this.deleteErrorCode = err.status;
        this.deleteError = err.error && typeof err.error === 'object'
          ? err.error
          : { error: 'unknown', reason: 'An unexpected error occurred' };
      },
    });
  }

  // ── Utilities ──

  formatBytes(bytes: number): string {
    if (bytes == null || bytes === 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    let unitIndex = 0;
    let value = bytes;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }
    if (unitIndex === 0) return `${value} ${units[unitIndex]}`;
    return `${value.toFixed(1)} ${units[unitIndex]}`;
  }
}
