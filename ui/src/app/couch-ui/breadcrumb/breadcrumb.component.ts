import { Component, Input } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';

/** A single breadcrumb segment. Last segment has no url. */
export interface BreadcrumbSegment {
  label: string;
  url?: string;
}

/**
 * Breadcrumb component.
 *
 * Renders an inline flex row of clickable segments separated by
 * neutral-300 `/` separators. The last segment is a non-clickable
 * <span> with aria-current="page".
 */
@Component({
  selector: 'app-breadcrumb',
  standalone: true,
  imports: [CommonModule, RouterLink],
  template: `
    <nav aria-label="Breadcrumb">
      <ol class="breadcrumb">
        <ng-container *ngFor="let seg of segments; let last = last">
          <li class="breadcrumb__item">
            <a
              *ngIf="!last && seg.url"
              class="breadcrumb__link mono"
              [routerLink]="seg.url">
              {{ seg.label }}
            </a>
            <span
              *ngIf="last || !seg.url"
              class="breadcrumb__current mono"
              [attr.aria-current]="last ? 'page' : null">
              {{ seg.label }}
            </span>
          </li>
          <li *ngIf="!last" class="breadcrumb__sep" aria-hidden="true">/</li>
        </ng-container>
      </ol>
    </nav>
  `,
  styles: [`
    :host {
      display: block;
    }

    .breadcrumb {
      display: inline-flex;
      align-items: center;
      gap: var(--space-1);
      list-style: none;
      margin: 0;
      padding: 0;
    }

    .breadcrumb__item {
      display: inline-flex;
    }

    .breadcrumb__link {
      font-size: var(--font-size-sm);
      line-height: var(--line-height-sm);
      color: var(--color-info);
      text-decoration: none;
    }

    .breadcrumb__link:hover {
      text-decoration: underline;
    }

    .breadcrumb__link:focus-visible {
      outline: 2px solid var(--color-info);
      outline-offset: 2px;
    }

    .breadcrumb__current {
      font-size: var(--font-size-sm);
      line-height: var(--line-height-sm);
      color: var(--color-neutral-600);
    }

    .breadcrumb__sep {
      font-size: var(--font-size-sm);
      color: var(--color-neutral-300);
      user-select: none;
    }
  `]
})
export class BreadcrumbComponent {
  @Input() segments: BreadcrumbSegment[] = [];
}
