import { Component, Input, ChangeDetectionStrategy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RevisionStatus } from './revision-tree-layout';

/**
 * Revision Tree popover — rendered into a CDK overlay above a hovered or
 * focused node. Pure presentation: receives inputs via `setInput()` from
 * the parent overlay-creation code in `RevisionTreeComponent`.
 *
 * Keep this small; additional metadata (e.g., timestamps, writers) can be
 * added later without touching the tree itself.
 */
@Component({
  selector: 'app-revision-tree-popover',
  standalone: true,
  imports: [CommonModule],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <div class="revtree-popover" role="tooltip">
      <dl class="revtree-popover__list">
        <div class="revtree-popover__row">
          <dt>Rev</dt>
          <dd class="mono">{{ rev }}</dd>
        </div>
        <div class="revtree-popover__row">
          <dt>Status</dt>
          <dd>{{ status }}</dd>
        </div>
        <div class="revtree-popover__row">
          <dt>Generation</dt>
          <dd>{{ generation }}</dd>
        </div>
        <div class="revtree-popover__row" *ngIf="parentRev">
          <dt>Parent</dt>
          <dd class="mono">{{ parentRev }}</dd>
        </div>
        <div class="revtree-popover__row" *ngIf="isWinner">
          <dt>Role</dt>
          <dd>winner</dd>
        </div>
        <div class="revtree-popover__row" *ngIf="isLeaf && !isWinner">
          <dt>Role</dt>
          <dd>conflict leaf</dd>
        </div>
      </dl>
    </div>
  `,
  styles: [`
    :host {
      display: block;
    }

    .revtree-popover {
      background: var(--color-neutral-0);
      border: 1px solid var(--color-neutral-200);
      border-radius: var(--border-radius);
      box-shadow: var(--shadow-overlay);
      padding: var(--space-3);
      min-width: 260px;
      max-width: 360px;
      font-size: var(--font-size-sm);
      color: var(--color-revtree-popover-fg);
    }

    .revtree-popover__list {
      margin: 0;
      display: flex;
      flex-direction: column;
      gap: var(--space-1);
    }

    .revtree-popover__row {
      display: grid;
      grid-template-columns: 80px 1fr;
      gap: var(--space-2);
    }

    .revtree-popover__row dt {
      font-weight: 600;
      color: var(--color-neutral-500);
      margin: 0;
    }

    .revtree-popover__row dd {
      margin: 0;
      color: var(--color-neutral-700);
      word-break: break-all;
    }

    .mono {
      font-family: var(--font-mono);
    }
  `]
})
export class RevisionTreePopoverComponent {
  @Input() rev = '';
  @Input() status: RevisionStatus = 'available';
  @Input() parentRev: string | null = null;
  @Input() isWinner = false;
  @Input() isLeaf = false;

  get generation(): number {
    const idx = this.rev.indexOf('-');
    if (idx < 0) return 1;
    const n = parseInt(this.rev.slice(0, idx), 10);
    return Number.isFinite(n) ? n : 1;
  }
}
