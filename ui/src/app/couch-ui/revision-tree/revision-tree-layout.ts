/**
 * Revision Tree layout helper (Story 11.4 — Task 2).
 *
 * Pure, framework-free, dependency-free layout algorithm that assigns a
 * `(column, generation)` grid position to every node in a CouchDB revision
 * tree. Deterministic output — identical input always yields identical
 * output — so the helper gets the heavy unit-test coverage and the SVG
 * render code stays trivial.
 *
 * Grid steps and radii live in the component (UI concern); the helper
 * only emits logical coordinates + edge adjacency.
 */

/** The status of a revision node as reported by `?revs_info=true`. */
export type RevisionStatus = 'available' | 'deleted' | 'missing';

/** Input shape for the layout — matches the component's `RevisionNode`. */
export interface RevisionNode {
  /** The full revision string, e.g. `3-abc123...`. */
  rev: string;
  /** The parent revision string, or `null` for the root. */
  parentRev: string | null;
  /** `available`, `deleted`, or `missing` (pruned ancestor). */
  status: RevisionStatus;
  /** True when this node is a leaf of the tree. */
  isLeaf: boolean;
  /** True when this node is the "winning" rev for the document. */
  isWinner: boolean;
  /** Layout column assigned by {@link computeRevisionTreeLayout}. */
  branch: number;
}

/** Output shape: a node paired with its logical grid position. */
export interface PositionedNode extends RevisionNode {
  /** Zero-based row (the generation number minus 1). */
  row: number;
  /** Zero-based column assigned to this branch. */
  col: number;
}

/** An edge between two positioned nodes. */
export interface LayoutEdge {
  fromRev: string;
  toRev: string;
  fromCol: number;
  fromRow: number;
  toCol: number;
  toRow: number;
  /** Status of the child (used to colour the edge). */
  status: RevisionStatus;
}

/** The full layout result: positioned nodes + edges + bounding grid. */
export interface RevisionTreeLayout {
  nodes: PositionedNode[];
  edges: LayoutEdge[];
  /** Number of columns actually used (max col + 1). Always ≥ 1. */
  columns: number;
  /** Number of rows (max row + 1). Always ≥ 1 when there is at least one node. */
  rows: number;
}

/** Parse the generation number out of a rev string like "3-abc123…". */
export function revGeneration(rev: string): number {
  const dash = rev.indexOf('-');
  if (dash < 0) return 1;
  const n = parseInt(rev.slice(0, dash), 10);
  return Number.isFinite(n) && n > 0 ? n : 1;
}

/**
 * Compute a deterministic layout for the given revision nodes.
 *
 * Algorithm:
 *   1. Build adjacency maps (`parent → children[]` and `child → parent`)
 *   2. Collect leaves (`isLeaf === true`)
 *   3. Sort leaves for column assignment:
 *        (a) winner first, (b) then by generation descending,
 *        (c) then by rev string ascending (stable for tests)
 *   4. Assign each leaf its own column index, left-to-right
 *   5. For each non-leaf (walking rows bottom-up), set column to the
 *      minimum column among its children — shared ancestors collapse
 *      onto the leftmost leaf's column
 *   6. Row = generation − 1 (root at row 0)
 *
 * The helper never mutates its input. If `nodes` is empty it returns
 * an empty layout with `rows = 0` and `columns = 0`.
 */
export function computeRevisionTreeLayout(
  nodes: readonly RevisionNode[],
): RevisionTreeLayout {
  if (nodes.length === 0) {
    return { nodes: [], edges: [], rows: 0, columns: 0 };
  }

  // Index by rev for O(1) lookup. Duplicates are not expected; keep the last
  // occurrence so the caller has a single source of truth.
  const byRev = new Map<string, RevisionNode>();
  for (const n of nodes) byRev.set(n.rev, n);

  // Build child adjacency (parent rev → children revs[]).
  const children = new Map<string, string[]>();
  for (const n of nodes) {
    if (n.parentRev && byRev.has(n.parentRev)) {
      const bucket = children.get(n.parentRev) ?? [];
      bucket.push(n.rev);
      children.set(n.parentRev, bucket);
    }
  }

  // Collect leaves — trust the input `isLeaf` flag.
  const leaves = nodes.filter((n) => n.isLeaf).slice();

  // Stable sort: winner first, then higher generation first, then rev asc.
  leaves.sort((a, b) => {
    if (a.isWinner !== b.isWinner) return a.isWinner ? -1 : 1;
    const genDelta = revGeneration(b.rev) - revGeneration(a.rev);
    if (genDelta !== 0) return genDelta;
    return a.rev < b.rev ? -1 : a.rev > b.rev ? 1 : 0;
  });

  // Edge case: no leaves (shouldn't happen with a well-formed tree, but be
  // robust — treat every node as its own leaf for layout purposes).
  const effectiveLeaves = leaves.length > 0 ? leaves : nodes.slice();

  const colByRev = new Map<string, number>();
  effectiveLeaves.forEach((leaf, i) => colByRev.set(leaf.rev, i));

  // Walk non-leaves in descending generation order so each parent's column
  // is the min of already-assigned children.
  const nonLeaves = nodes
    .filter((n) => !colByRev.has(n.rev))
    .slice()
    .sort((a, b) => revGeneration(b.rev) - revGeneration(a.rev));
  for (const n of nonLeaves) {
    const kids = children.get(n.rev) ?? [];
    let col = Number.POSITIVE_INFINITY;
    for (const childRev of kids) {
      const c = colByRev.get(childRev);
      if (c !== undefined && c < col) col = c;
    }
    if (!Number.isFinite(col)) {
      // Fallback: orphan non-leaf — park it in column 0.
      col = 0;
    }
    colByRev.set(n.rev, col);
  }

  // Emit positioned nodes.
  const positioned: PositionedNode[] = nodes.map((n) => ({
    ...n,
    col: colByRev.get(n.rev) ?? 0,
    row: Math.max(0, revGeneration(n.rev) - 1),
    // Propagate the input branch value for callers who want it,
    // but also set it to the assigned column for internal use.
    branch: colByRev.get(n.rev) ?? 0,
  }));

  // Build edges parent → child. Skip if parent is not in the node set.
  const edges: LayoutEdge[] = [];
  for (const n of positioned) {
    if (!n.parentRev) continue;
    const parent = positioned.find((p) => p.rev === n.parentRev);
    if (!parent) continue;
    edges.push({
      fromRev: parent.rev,
      toRev: n.rev,
      fromCol: parent.col,
      fromRow: parent.row,
      toCol: n.col,
      toRow: n.row,
      status: n.status,
    });
  }

  const maxCol = positioned.reduce((m, n) => Math.max(m, n.col), 0);
  const maxRow = positioned.reduce((m, n) => Math.max(m, n.row), 0);

  return {
    nodes: positioned,
    edges,
    columns: maxCol + 1,
    rows: maxRow + 1,
  };
}
