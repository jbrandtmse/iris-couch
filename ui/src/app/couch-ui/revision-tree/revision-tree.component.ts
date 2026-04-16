import {
  Component,
  Input,
  Output,
  EventEmitter,
  OnChanges,
  OnDestroy,
  ElementRef,
  ViewChild,
  inject,
  ChangeDetectionStrategy,
} from '@angular/core';
import { CommonModule } from '@angular/common';
import { Overlay, OverlayRef } from '@angular/cdk/overlay';
import { ComponentPortal } from '@angular/cdk/portal';
import {
  RevisionNode,
  RevisionTreeLayout,
  PositionedNode,
  LayoutEdge,
  computeRevisionTreeLayout,
} from './revision-tree-layout';
import { RevisionTreePopoverComponent } from './revision-tree-popover.component';

/** Fixed grid step (px). Kept in the component so tests can hit the helper. */
export const REVTREE_COL_STEP = 56;
export const REVTREE_ROW_STEP = 56;
export const REVTREE_NODE_RADIUS = 14;
export const REVTREE_PADDING = 24;

/**
 * RevisionTree — the one visually ambitious primitive in the IRISCouch
 * admin UI (Story 11.4, per `ux-design-specification.md` lines 1360–1373).
 *
 * Renders a CouchDB document's revision tree as an SVG graph. Uses an
 * internal pure helper ({@link computeRevisionTreeLayout}) for the layout
 * calculation — this component only handles DOM, accessibility, and
 * CDK-overlay popovers.
 *
 * Resist the urge to reach for D3 / dagre / vis.js: the layout is
 * fixed-grid and simple enough to compute in <100 lines, and the
 * zero-runtime-dependency constraint (UX spec line 410) matters more
 * than layout sophistication for a read-mostly operator tool.
 */
@Component({
  selector: 'app-revision-tree',
  standalone: true,
  imports: [CommonModule],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <div
      class="revision-tree"
      [class.revision-tree--loading]="loading">
      <ng-container *ngIf="loading">
        <div
          class="revision-tree__skeleton"
          role="status"
          aria-live="polite"
          aria-label="Loading revision tree">
          Loading revision tree…
        </div>
      </ng-container>

      <ng-container *ngIf="!loading && layout.nodes.length > 0">
        <div
          #scrollContainer
          class="revision-tree__scroll"
          role="tree"
          aria-label="Document revision tree"
          (keydown)="onKeydown($event)">
          <svg
            class="revision-tree__svg"
            [attr.width]="svgWidth"
            [attr.height]="svgHeight"
            [attr.viewBox]="'0 0 ' + svgWidth + ' ' + svgHeight"
            xmlns="http://www.w3.org/2000/svg"
            focusable="false">
            <!-- Edges first so nodes paint over them -->
            <g class="revision-tree__edges" aria-hidden="true">
              <line
                *ngFor="let edge of layout.edges; trackBy: trackByEdge"
                [attr.x1]="colToX(edge.fromCol)"
                [attr.y1]="rowToY(edge.fromRow)"
                [attr.x2]="colToX(edge.toCol)"
                [attr.y2]="rowToY(edge.toRow)"
                [attr.class]="'revision-tree__edge revision-tree__edge--' + edge.status" />
            </g>
            <!-- Nodes -->
            <g class="revision-tree__nodes">
              <g
                *ngFor="let n of layout.nodes; let i = index; trackBy: trackByNode"
                [attr.id]="nodeDomId(n.rev)"
                [attr.transform]="'translate(' + colToX(n.col) + ',' + rowToY(n.row) + ')'"
                [attr.class]="nodeClass(n)"
                role="treeitem"
                [attr.tabindex]="n.rev === focusedRev ? 0 : -1"
                [attr.aria-selected]="n.rev === selectedRev"
                [attr.aria-label]="nodeAriaLabel(n)"
                (click)="activate(n)"
                (keydown.enter)="activate(n); $event.preventDefault()"
                (keydown.space)="activate(n); $event.preventDefault()"
                (focus)="onNodeFocus(n, $event)"
                (mouseenter)="showPopover(n, $event)"
                (mouseleave)="hidePopover()"
                (blur)="hidePopover()">
                <circle
                  class="revision-tree__node-circle"
                  [attr.r]="radius"
                  [attr.cx]="0"
                  [attr.cy]="0" />
                <text
                  class="revision-tree__node-label"
                  [attr.x]="0"
                  [attr.y]="radius + 14"
                  text-anchor="middle">
                  <ng-container *ngIf="n.status === 'missing'">?</ng-container>
                  <ng-container *ngIf="n.status !== 'missing'">{{ shortRev(n.rev) }}</ng-container>
                </text>
                <text
                  *ngIf="n.isWinner"
                  class="revision-tree__node-badge"
                  [attr.x]="0"
                  [attr.y]="4"
                  text-anchor="middle">★</text>
              </g>
            </g>
          </svg>
        </div>
      </ng-container>

      <ng-container *ngIf="!loading && layout.nodes.length === 0">
        <div class="revision-tree__empty" role="status">
          No revisions to display.
        </div>
      </ng-container>
    </div>
  `,
  styles: [`
    :host {
      display: block;
    }

    .revision-tree__scroll {
      width: 100%;
      max-height: 60vh;
      overflow: auto;
      border: 1px solid var(--border-color);
      border-radius: var(--border-radius);
      background: var(--color-revtree-node-fill);
    }

    .revision-tree__svg {
      display: block;
    }

    .revision-tree__skeleton,
    .revision-tree__empty {
      padding: var(--space-6);
      font-size: var(--font-size-sm);
      color: var(--color-neutral-500);
      text-align: center;
    }

    /* Edges — stroke colour reflects the child's status */
    .revision-tree__edge {
      stroke: var(--color-revtree-edge);
      stroke-width: 1.5;
    }
    .revision-tree__edge--deleted {
      stroke: var(--color-revtree-deleted-border);
      stroke-dasharray: 4 2;
    }
    .revision-tree__edge--missing {
      stroke: var(--color-revtree-missing-border);
      stroke-dasharray: 2 2;
    }

    /* Nodes — circle + text */
    .revision-tree__node {
      cursor: pointer;
      outline: none;
    }
    .revision-tree__node-circle {
      fill: var(--color-revtree-node-fill);
      stroke: var(--color-revtree-node-border);
      stroke-width: 1.5;
    }
    .revision-tree__node--leaf .revision-tree__node-circle {
      stroke: var(--color-revtree-leaf-border);
      stroke-width: 2;
    }
    .revision-tree__node--winner .revision-tree__node-circle {
      stroke: var(--color-revtree-winner-border);
      stroke-width: 2.5;
      fill: var(--color-revtree-winner-fill);
    }
    .revision-tree__node--deleted .revision-tree__node-circle {
      stroke: var(--color-revtree-deleted-border);
      fill: var(--color-revtree-deleted-fill);
      stroke-dasharray: 3 2;
    }
    .revision-tree__node--missing .revision-tree__node-circle {
      stroke: var(--color-revtree-missing-border);
      stroke-dasharray: 4 2;
      fill: transparent;
    }
    .revision-tree__node--selected .revision-tree__node-circle {
      stroke-width: 3;
      stroke: var(--color-revtree-selected-ring);
    }
    .revision-tree__node:hover .revision-tree__node-circle,
    .revision-tree__node:focus .revision-tree__node-circle {
      stroke: var(--color-revtree-selected-ring);
    }
    .revision-tree__node:focus .revision-tree__node-circle {
      filter: drop-shadow(0 0 2px var(--color-revtree-selected-ring));
    }

    .revision-tree__node-label {
      font-family: var(--font-mono);
      font-size: var(--font-size-xs);
      fill: var(--color-neutral-700);
      user-select: none;
    }
    .revision-tree__node--deleted .revision-tree__node-label {
      fill: var(--color-revtree-deleted-border);
      text-decoration: line-through;
    }
    .revision-tree__node-badge {
      font-size: 12px;
      fill: var(--color-revtree-winner-border);
      pointer-events: none;
      user-select: none;
    }
  `]
})
export class RevisionTreeComponent implements OnChanges, OnDestroy {
  private _nodes: readonly RevisionNode[] = [];
  /** Nodes to render. Setting this recomputes the layout immediately
   * so consumers that mutate the input imperatively (e.g., tests that
   * bypass the template binding) see the update on the next
   * detectChanges() tick. */
  @Input() set nodes(value: readonly RevisionNode[]) {
    this._nodes = value ?? [];
    this.recomputeLayout();
  }
  get nodes(): readonly RevisionNode[] {
    return this._nodes;
  }
  @Input() selectedRev: string | null = null;
  @Input() loading = false;

  @Output() nodeSelect = new EventEmitter<string>();

  @ViewChild('scrollContainer') scrollContainer?: ElementRef<HTMLElement>;

  /** Computed layout — recomputed on every `nodes` change. */
  layout: RevisionTreeLayout = { nodes: [], edges: [], rows: 0, columns: 0 };
  /** The rev currently accepting Tab focus; persists across renders. */
  focusedRev: string | null = null;

  readonly radius = REVTREE_NODE_RADIUS;

  private overlayRef: OverlayRef | null = null;
  private readonly overlay = inject(Overlay);
  private readonly host: ElementRef<HTMLElement> = inject(ElementRef);

  get svgWidth(): number {
    return Math.max(
      REVTREE_COL_STEP,
      this.layout.columns * REVTREE_COL_STEP + REVTREE_PADDING * 2,
    );
  }

  get svgHeight(): number {
    return Math.max(
      REVTREE_ROW_STEP,
      this.layout.rows * REVTREE_ROW_STEP + REVTREE_PADDING * 2,
    );
  }

  ngOnChanges(): void {
    this.recomputeLayout();
  }

  private recomputeLayout(): void {
    this.layout = computeRevisionTreeLayout(this._nodes);
    // Seed focus to the winner, falling back to the first leaf, falling
    // back to the first node.
    if (!this.focusedRev || !this.layout.nodes.some((n) => n.rev === this.focusedRev)) {
      const winner = this.layout.nodes.find((n) => n.isWinner);
      const firstLeaf = this.layout.nodes.find((n) => n.isLeaf);
      this.focusedRev = winner?.rev ?? firstLeaf?.rev ?? this.layout.nodes[0]?.rev ?? null;
    }
  }

  ngOnDestroy(): void {
    this.hidePopover();
  }

  // ── Layout helpers ─────────────────────────────────────────────────────
  colToX(col: number): number {
    return REVTREE_PADDING + col * REVTREE_COL_STEP + REVTREE_COL_STEP / 2;
  }
  rowToY(row: number): number {
    return REVTREE_PADDING + row * REVTREE_ROW_STEP + REVTREE_ROW_STEP / 2;
  }

  // ── Classes & labels ──────────────────────────────────────────────────
  nodeClass(n: PositionedNode): string {
    const classes = ['revision-tree__node'];
    if (n.isLeaf) classes.push('revision-tree__node--leaf');
    if (n.isWinner) classes.push('revision-tree__node--winner');
    if (n.status === 'deleted') classes.push('revision-tree__node--deleted');
    if (n.status === 'missing') classes.push('revision-tree__node--missing');
    if (n.rev === this.selectedRev) classes.push('revision-tree__node--selected');
    return classes.join(' ');
  }

  nodeAriaLabel(n: PositionedNode): string {
    const parts = [`Revision ${n.rev}`, n.status];
    if (n.isWinner) parts.push('winner');
    if (n.isLeaf && !n.isWinner) parts.push('conflict leaf');
    if (n.rev === this.selectedRev) parts.push('selected');
    return parts.join(', ');
  }

  shortRev(rev: string): string {
    // "3-abc123def456…" → "3-abc123"
    const idx = rev.indexOf('-');
    if (idx < 0) return rev;
    return rev.slice(0, Math.min(rev.length, idx + 8));
  }

  nodeDomId(rev: string): string {
    return 'revtree-node-' + rev.replace(/[^a-zA-Z0-9-]/g, '_');
  }

  trackByNode(_i: number, n: PositionedNode): string {
    return n.rev;
  }
  trackByEdge(_i: number, e: LayoutEdge): string {
    return e.fromRev + '→' + e.toRev;
  }

  // ── Interaction ────────────────────────────────────────────────────────
  activate(n: PositionedNode): void {
    this.focusedRev = n.rev;
    this.nodeSelect.emit(n.rev);
  }

  onNodeFocus(n: PositionedNode, event: FocusEvent): void {
    this.focusedRev = n.rev;
    this.showPopover(n, event);
  }

  onKeydown(event: KeyboardEvent): void {
    if (!this.focusedRev) return;
    const current = this.layout.nodes.find((n) => n.rev === this.focusedRev);
    if (!current) return;

    let target: PositionedNode | undefined;
    switch (event.key) {
      case 'ArrowUp':
        // Move to parent (if parent is present)
        if (current.parentRev) {
          target = this.layout.nodes.find((n) => n.rev === current.parentRev);
        }
        break;
      case 'ArrowDown':
        // Move to first child
        target = this.layout.nodes.find((n) => n.parentRev === current.rev);
        break;
      case 'ArrowLeft':
      case 'ArrowRight': {
        // Move to sibling at same generation (sorted by column)
        const siblings = this.layout.nodes
          .filter((n) => n.row === current.row && n.rev !== current.rev)
          .sort((a, b) => a.col - b.col);
        if (siblings.length === 0) break;
        const curCol = current.col;
        if (event.key === 'ArrowLeft') {
          target = [...siblings].reverse().find((s) => s.col < curCol) ?? siblings[siblings.length - 1];
        } else {
          target = siblings.find((s) => s.col > curCol) ?? siblings[0];
        }
        break;
      }
      case 'Escape':
        // Close an open hover/focus popover. The parent view treats an
        // open .cdk-overlay-pane as "someone else handles Esc", so this
        // gives the popover first shot at the key before the view's
        // "Back to document" shortcut fires.
        if (this.overlayRef) {
          event.preventDefault();
          event.stopPropagation();
          this.hidePopover();
        }
        return;
      case 'Tab': {
        // Cycle through leaves. Preserve default if user holds Shift
        // at the boundary — the browser's own tabbing handles that.
        const leaves = this.layout.nodes.filter((n) => n.isLeaf);
        if (leaves.length <= 1) return;
        const idx = leaves.findIndex((n) => n.rev === current.rev);
        if (idx < 0) {
          target = leaves[0];
        } else {
          const next = event.shiftKey ? idx - 1 : idx + 1;
          if (next < 0 || next >= leaves.length) return; // let browser move focus out
          target = leaves[next];
        }
        break;
      }
      default:
        return;
    }

    if (target) {
      event.preventDefault();
      this.focusedRev = target.rev;
      const el = this.host.nativeElement.querySelector(
        '#' + this.nodeDomId(target.rev),
      ) as HTMLElement | null;
      el?.focus();
    }
  }

  // ── CDK overlay popover ────────────────────────────────────────────────
  showPopover(n: PositionedNode, event: MouseEvent | FocusEvent): void {
    this.hidePopover();
    const anchor = (event.currentTarget as SVGGraphicsElement | HTMLElement) ?? null;
    if (!anchor) return;
    // Use flexibleConnectedTo anchored to the anchor element.
    const position = this.overlay
      .position()
      .flexibleConnectedTo(anchor as unknown as HTMLElement)
      .withPositions([
        { originX: 'center', originY: 'top', overlayX: 'center', overlayY: 'bottom', offsetY: -4 },
        { originX: 'center', originY: 'bottom', overlayX: 'center', overlayY: 'top', offsetY: 4 },
      ])
      .withPush(true);

    this.overlayRef = this.overlay.create({
      positionStrategy: position,
      scrollStrategy: this.overlay.scrollStrategies.reposition(),
      hasBackdrop: false,
      panelClass: 'revision-tree__popover-panel',
    });

    const portal = new ComponentPortal(RevisionTreePopoverComponent);
    const ref = this.overlayRef.attach(portal);
    ref.setInput('rev', n.rev);
    ref.setInput('status', n.status);
    ref.setInput('parentRev', n.parentRev);
    ref.setInput('isWinner', n.isWinner);
    ref.setInput('isLeaf', n.isLeaf);
  }

  hidePopover(): void {
    this.overlayRef?.dispose();
    this.overlayRef = null;
  }
}
