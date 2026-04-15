import { Component, Input, Output, EventEmitter } from '@angular/core';
import { CommonModule } from '@angular/common';
import { IconButtonComponent } from '../icon-button/icon-button.component';
import { IconChevronLeftComponent, IconChevronRightComponent } from '../icons';

/**
 * CouchUI Pagination component.
 *
 * Displays a range indicator ("rows 1-25 of ~42,187") with Previous/Next
 * buttons. Designed for CouchDB startkey-based pagination -- no page numbers.
 *
 * Usage:
 *   <app-pagination
 *     [startIndex]="1"
 *     [endIndex]="25"
 *     [totalRows]="42187"
 *     [hasNext]="true"
 *     [hasPrevious]="false"
 *     (next)="onNext()"
 *     (previous)="onPrevious()">
 *   </app-pagination>
 */
@Component({
  selector: 'app-pagination',
  standalone: true,
  imports: [CommonModule, IconButtonComponent, IconChevronLeftComponent, IconChevronRightComponent],
  template: `
    <nav class="pagination" aria-label="Pagination">
      <span class="pagination__range">
        rows {{ startIndex | number }}&ndash;{{ endIndex | number }} of ~{{ totalRows | number }}
      </span>
      <div class="pagination__controls">
        <app-icon-button
          ariaLabel="Previous page"
          [disabled]="!hasPrevious"
          (click)="onPrevious()">
          <app-icon-chevron-left [size]="16" />
        </app-icon-button>
        <app-icon-button
          ariaLabel="Next page"
          [disabled]="!hasNext"
          (click)="onNext()">
          <app-icon-chevron-right [size]="16" />
        </app-icon-button>
      </div>
    </nav>
  `,
  styles: [`
    :host {
      display: block;
    }

    .pagination {
      display: flex;
      align-items: center;
      justify-content: flex-end;
      gap: var(--space-3);
      padding: var(--space-2) 0;
    }

    .pagination__range {
      font-size: var(--font-size-xs);
      line-height: var(--line-height-xs);
      color: var(--color-neutral-500);
      font-variant-numeric: tabular-nums;
    }

    .pagination__controls {
      display: flex;
      align-items: center;
      gap: var(--space-1);
    }
  `]
})
export class PaginationComponent {
  @Input() startIndex = 1;
  @Input() endIndex = 25;
  @Input() totalRows = 0;
  @Input() hasNext = false;
  @Input() hasPrevious = false;

  @Output() next = new EventEmitter<void>();
  @Output() previous = new EventEmitter<void>();

  onNext(): void {
    if (this.hasNext) {
      this.next.emit();
    }
  }

  onPrevious(): void {
    if (this.hasPrevious) {
      this.previous.emit();
    }
  }
}
