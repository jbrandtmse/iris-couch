import { Component, Input } from '@angular/core';

/**
 * CouchUI Badge component.
 *
 * An inline status indicator with semantic color variants.
 * Static element (no hover, click, or state changes).
 *
 * Usage:
 *   <app-badge variant="success">online</app-badge>
 *   <app-badge variant="error">offline</app-badge>
 */
@Component({
  selector: 'app-badge',
  standalone: true,
  template: `
    <span class="badge" [class]="'badge badge--' + variant">
      <ng-content></ng-content>
    </span>
  `,
  styles: [`
    :host {
      display: inline;
    }

    .badge {
      display: inline;
      font-size: 10px;
      font-weight: 600;
      line-height: 1;
      text-transform: uppercase;
      letter-spacing: 0.05em;
      padding: 1px 4px;
      border-width: 1px;
      border-style: solid;
      border-radius: var(--border-radius);
      white-space: nowrap;
    }

    .badge--info {
      color: var(--color-info);
      border-color: var(--color-info);
      background-color: rgba(60, 90, 158, 0.1);
    }

    .badge--warn {
      color: var(--color-warn);
      border-color: var(--color-warn);
      background-color: rgba(181, 123, 33, 0.1);
    }

    .badge--error {
      color: #9A2E2E;
      border-color: var(--color-error);
      background-color: rgba(195, 63, 63, 0.1);
    }

    .badge--success {
      color: var(--color-success);
      border-color: var(--color-success);
      background-color: rgba(60, 122, 90, 0.1);
    }
  `]
})
export class BadgeComponent {
  @Input() variant: 'info' | 'warn' | 'error' | 'success' = 'info';
}
