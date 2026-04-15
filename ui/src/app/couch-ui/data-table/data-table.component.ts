import {
  Component,
  Input,
  Output,
  EventEmitter,
  TrackByFunction,
  ContentChild,
  TemplateRef,
  AfterContentInit,
} from '@angular/core';
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
            [class.data-table__cell--numeric]="col.numeric"
            (click)="onCellClick($event, row)">
            {{ col.format ? col.format(row[col.key], row) : row[col.key] }}
          </td>
        </ng-container>

        <!-- Story 11.0 AC #2 Task 2: optional trailing action column. See
             the actionTemplate Input docstring on the component class for
             usage notes. Clicks inside the action cell stop propagation so
             they do not trigger row navigation. The column uses the fixed
             key __actions to avoid collision with data fields. -->
        <ng-container *ngIf="effectiveActionTemplate" cdkColumnDef="__actions">
          <th
            cdk-header-cell
            *cdkHeaderCellDef
            class="data-table__header data-table__header--actions"
            scope="col">
            <span class="visually-hidden">{{ actionsLabel }}</span>
          </th>
          <td
            cdk-cell
            *cdkCellDef="let row"
            class="data-table__cell data-table__cell--actions"
            (click)="$event.stopPropagation()"
            (keydown.enter)="$event.stopPropagation()">
            <ng-container
              [ngTemplateOutlet]="effectiveActionTemplate!"
              [ngTemplateOutletContext]="{ $implicit: row, row: row }">
            </ng-container>
          </td>
        </ng-container>

        <!-- Header row -->
        <tr cdk-header-row *cdkHeaderRowDef="displayedColumnKeys"></tr>

        <!-- Data rows -->
        <tr
          cdk-row
          *cdkRowDef="let row; columns: displayedColumnKeys"
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

    /* Action column: right-aligned, compact, doesn't inherit row hover cursor. */
    .data-table__header--actions,
    .data-table__cell--actions {
      text-align: right;
      width: 1%;
      white-space: nowrap;
      padding-right: var(--space-3);
    }

    .data-table__cell--actions {
      cursor: default;
    }

    /* Visually-hidden utility for accessible label on the actions column. */
    .visually-hidden {
      position: absolute;
      width: 1px;
      height: 1px;
      margin: -1px;
      overflow: hidden;
      clip: rect(0, 0, 0, 0);
      border: 0;
    }

    @media (prefers-reduced-motion: reduce) {
      .data-table__sort-icon {
        transition: none;
      }
    }
  `]
})
export class DataTableComponent implements AfterContentInit {
  @Input() columns: ColumnDef[] = [];
  @Input() data: Record<string, unknown>[] = [];
  @Input() sortColumn = '';
  @Input() sortDirection: 'asc' | 'desc' = 'asc';
  @Input() clickable = false;

  /**
   * Optional per-row action template. When provided, the DataTable renders a
   * trailing "__actions" column whose cells are the template's rendering for
   * each row. The template receives the row as `$implicit` and as a named
   * `row` context variable.
   *
   * Usage:
   *   <app-data-table [columns]="cols" [data]="rows" [actionTemplate]="actions">
   *     <ng-template #actions let-row>
   *       <app-icon-button (click)="delete(row)">...</app-icon-button>
   *     </ng-template>
   *   </app-data-table>
   *
   * The template can be passed via [actionTemplate] binding or projected as a
   * `ContentChild` using the template reference `#actions`. Click events
   * inside the action cell are stopPropagation'd so they don't fire rowClick.
   *
   * See Story 11.0 AC #2 / Task 2.
   */
  @Input() actionTemplate?: TemplateRef<{ $implicit: Record<string, unknown>; row: Record<string, unknown> }>;

  /** aria-label for the trailing actions column header (empty by default). */
  @Input() actionsLabel = 'Actions';

  @ContentChild('actions', { read: TemplateRef, static: true })
  projectedActionTemplate?: TemplateRef<any>;

  @Output() sortChange = new EventEmitter<SortChangeEvent>();
  @Output() rowClick = new EventEmitter<Record<string, unknown>>();

  get columnKeys(): string[] {
    return this.columns.map((col) => col.key);
  }

  /**
   * Resolve the content-projected action template (if any) after content init.
   * Kept as a separate private field so we don't mutate the `@Input` binding
   * from inside a getter (which would run on every change-detection pass).
   */
  private resolvedActionTemplate?: TemplateRef<{ $implicit: Record<string, unknown>; row: Record<string, unknown> }>;

  ngAfterContentInit(): void {
    // Prefer the explicit @Input binding; fall back to content projection.
    this.resolvedActionTemplate =
      this.actionTemplate ?? (this.projectedActionTemplate as TemplateRef<any>);
  }

  /** Effective action template (Input takes precedence over ContentChild). */
  get effectiveActionTemplate(): TemplateRef<any> | undefined {
    return this.actionTemplate ?? this.resolvedActionTemplate;
  }

  /**
   * Columns actually displayed in the CDK header/row definitions. Appends
   * the synthetic `__actions` key when an action template is present.
   */
  get displayedColumnKeys(): string[] {
    const keys = this.columnKeys;
    return this.effectiveActionTemplate ? [...keys, '__actions'] : keys;
  }

  onCellClick(_event: Event, _row: Record<string, unknown>): void {
    // Placeholder for future per-cell handling; kept so the (click) binding
    // in the template compiles cleanly.
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
