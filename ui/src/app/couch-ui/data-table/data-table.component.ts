import { Component, Input, Output, EventEmitter, TrackByFunction } from '@angular/core';
import { CommonModule } from '@angular/common';
import { CdkTableModule } from '@angular/cdk/table';
import { IconChevronDownComponent } from '../icons';

/** Definition for a single column in the DataTable. */
export interface ColumnDef {
  key: string;
  label: string;
  align?: 'left' | 'right';
  mono?: boolean;
  sortable?: boolean;
  numeric?: boolean;
  /** Optional function to format cell value for display */
  format?: (value: unknown, row: Record<string, unknown>) => string;
}

/** Emitted when the user clicks a sortable column header. */
export interface SortChangeEvent {
  column: string;
  direction: 'asc' | 'desc';
}

/**
 * CouchUI DataTable component.
 *
 * Built on CDK Table (CdkTableModule) for a minimal, accessible data grid.
 * 28px row height, 12px row text, sortable column headers with aria-sort,
 * clickable rows, monospace and numeric column support.
 */
@Component({
  selector: 'app-data-table',
  standalone: true,
  imports: [CommonModule, CdkTableModule, IconChevronDownComponent],
  template: `
    <div class="data-table-wrapper">
      <table cdk-table [dataSource]="data" [trackBy]="trackByIndex" class="data-table">
        <!-- Column definitions -->
        <ng-container *ngFor="let col of columns" [cdkColumnDef]="col.key">
          <th
            cdk-header-cell
            *cdkHeaderCellDef
            class="data-table__header"
            [class.data-table__header--sortable]="col.sortable"
            [class.data-table__header--right]="col.align === 'right'"
            [attr.aria-sort]="getAriaSort(col)"
            (click)="onHeaderClick(col)"
            (keydown.enter)="onHeaderClick(col)"
            (keydown.space)="onHeaderClick(col); $event.preventDefault()"
            [attr.tabindex]="col.sortable ? 0 : null"
            [attr.role]="col.sortable ? 'columnheader' : null">
            <span class="data-table__header-content">
              {{ col.label }}
              <app-icon-chevron-down
                *ngIf="col.sortable && sortColumn === col.key"
                class="data-table__sort-icon"
                [class.data-table__sort-icon--asc]="sortDirection === 'asc'"
                [size]="12"
                aria-hidden="true">
              </app-icon-chevron-down>
            </span>
          </th>
          <td
            cdk-cell
            *cdkCellDef="let row"
            class="data-table__cell"
            [class.data-table__cell--right]="col.align === 'right'"
            [class.data-table__cell--mono]="col.mono"
            [class.data-table__cell--numeric]="col.numeric">
            {{ col.format ? col.format(row[col.key], row) : row[col.key] }}
          </td>
        </ng-container>

        <!-- Header row -->
        <tr cdk-header-row *cdkHeaderRowDef="columnKeys"></tr>

        <!-- Data rows -->
        <tr
          cdk-row
          *cdkRowDef="let row; columns: columnKeys"
          class="data-table__row"
          [class.data-table__row--clickable]="clickable"
          [attr.tabindex]="clickable ? 0 : null"
          (click)="onRowClick(row)"
          (keydown.enter)="onRowClick(row)">
        </tr>
      </table>
    </div>
  `,
  styles: [`
    :host {
      display: block;
    }

    .data-table-wrapper {
      overflow-x: auto;
    }

    .data-table {
      width: 100%;
      border-collapse: collapse;
      font-family: var(--font-sans);
    }

    .data-table__header {
      height: 32px;
      padding: 0 var(--space-3);
      font-size: var(--font-size-xs);
      line-height: var(--line-height-xs);
      font-weight: 600;
      color: var(--color-neutral-500);
      text-align: left;
      white-space: nowrap;
      border-bottom: 1px solid var(--color-neutral-200);
      user-select: none;
    }

    .data-table__header--sortable {
      cursor: pointer;
    }

    .data-table__header--sortable:hover {
      color: var(--color-neutral-700);
    }

    .data-table__header--sortable:focus-visible {
      outline: 2px solid var(--color-info);
      outline-offset: -2px;
    }

    .data-table__header--right {
      text-align: right;
    }

    .data-table__header-content {
      display: inline-flex;
      align-items: center;
      gap: 2px;
    }

    .data-table__sort-icon {
      display: inline-flex;
      transition: transform 0.15s ease;
    }

    .data-table__sort-icon--asc {
      transform: rotate(180deg);
    }

    .data-table__cell {
      height: 28px;
      padding: 0 var(--space-3);
      font-size: var(--font-size-xs);
      line-height: var(--line-height-xs);
      color: var(--color-neutral-700);
      white-space: nowrap;
      border-bottom: 1px solid var(--color-neutral-100);
    }

    .data-table__cell--right {
      text-align: right;
    }

    .data-table__cell--mono {
      font-family: var(--font-mono);
    }

    .data-table__cell--numeric {
      font-variant-numeric: tabular-nums;
    }

    .data-table__row:hover {
      background-color: var(--color-neutral-50);
    }

    .data-table__row--clickable {
      cursor: pointer;
    }

    .data-table__row--clickable:focus-visible {
      outline: 2px solid var(--color-info);
      outline-offset: -2px;
    }

    @media (prefers-reduced-motion: reduce) {
      .data-table__sort-icon {
        transition: none;
      }
    }
  `]
})
export class DataTableComponent {
  @Input() columns: ColumnDef[] = [];
  @Input() data: Record<string, unknown>[] = [];
  @Input() sortColumn = '';
  @Input() sortDirection: 'asc' | 'desc' = 'asc';
  @Input() clickable = false;

  @Output() sortChange = new EventEmitter<SortChangeEvent>();
  @Output() rowClick = new EventEmitter<Record<string, unknown>>();

  get columnKeys(): string[] {
    return this.columns.map((col) => col.key);
  }

  trackByIndex: TrackByFunction<Record<string, unknown>> = (index: number) => index;

  getAriaSort(col: ColumnDef): string | null {
    if (!col.sortable) return null;
    if (this.sortColumn !== col.key) return 'none';
    return this.sortDirection === 'asc' ? 'ascending' : 'descending';
  }

  onHeaderClick(col: ColumnDef): void {
    if (!col.sortable) return;
    const direction: 'asc' | 'desc' =
      this.sortColumn === col.key && this.sortDirection === 'asc' ? 'desc' : 'asc';
    this.sortChange.emit({ column: col.key, direction });
  }

  onRowClick(row: Record<string, unknown>): void {
    if (this.clickable) {
      this.rowClick.emit(row);
    }
  }
}
