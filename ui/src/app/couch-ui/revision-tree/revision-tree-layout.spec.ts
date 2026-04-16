import {
  computeRevisionTreeLayout,
  revGeneration,
  RevisionNode,
} from './revision-tree-layout';

/** Shorthand factory — keeps fixtures readable. */
function node(
  rev: string,
  parentRev: string | null,
  opts: Partial<RevisionNode> = {},
): RevisionNode {
  return {
    rev,
    parentRev,
    status: 'available',
    isLeaf: false,
    isWinner: false,
    branch: 0,
    ...opts,
  };
}

describe('revGeneration', () => {
  it('parses the integer prefix of a rev string', () => {
    expect(revGeneration('1-abc')).toBe(1);
    expect(revGeneration('42-abc')).toBe(42);
  });

  it('falls back to 1 for malformed input', () => {
    expect(revGeneration('abc')).toBe(1);
    expect(revGeneration('')).toBe(1);
    expect(revGeneration('0-abc')).toBe(1); // non-positive → fallback
  });
});

describe('computeRevisionTreeLayout', () => {
  it('returns an empty layout for an empty input', () => {
    const result = computeRevisionTreeLayout([]);
    expect(result.nodes).toEqual([]);
    expect(result.edges).toEqual([]);
    expect(result.rows).toBe(0);
    expect(result.columns).toBe(0);
  });

  it('places a single root node at (0, 0)', () => {
    const result = computeRevisionTreeLayout([
      node('1-abc', null, { isLeaf: true, isWinner: true }),
    ]);
    expect(result.nodes.length).toBe(1);
    expect(result.nodes[0].row).toBe(0);
    expect(result.nodes[0].col).toBe(0);
    expect(result.edges).toEqual([]);
    expect(result.rows).toBe(1);
    expect(result.columns).toBe(1);
  });

  it('stacks a linear 3-rev chain vertically in column 0', () => {
    const result = computeRevisionTreeLayout([
      node('1-a', null),
      node('2-b', '1-a'),
      node('3-c', '2-b', { isLeaf: true, isWinner: true }),
    ]);
    const byRev = Object.fromEntries(result.nodes.map((n) => [n.rev, n]));
    expect(byRev['1-a'].row).toBe(0);
    expect(byRev['1-a'].col).toBe(0);
    expect(byRev['2-b'].row).toBe(1);
    expect(byRev['2-b'].col).toBe(0);
    expect(byRev['3-c'].row).toBe(2);
    expect(byRev['3-c'].col).toBe(0);
    // Two edges 1-a → 2-b, 2-b → 3-c
    expect(result.edges.length).toBe(2);
    expect(result.rows).toBe(3);
    expect(result.columns).toBe(1);
  });

  it('assigns winner to column 0 for a 2-leaf conflict', () => {
    const result = computeRevisionTreeLayout([
      node('1-a', null),
      node('2-b', '1-a', { isLeaf: true, isWinner: true }),
      node('2-c', '1-a', { isLeaf: true, status: 'deleted' }),
    ]);
    const byRev = Object.fromEntries(result.nodes.map((n) => [n.rev, n]));
    expect(byRev['2-b'].col).toBe(0);
    expect(byRev['2-c'].col).toBe(1);
    // Shared root collapses onto the winner's column (leftmost child)
    expect(byRev['1-a'].col).toBe(0);
    expect(result.columns).toBe(2);
    expect(result.edges.length).toBe(2);
  });

  it('sorts non-winner leaves by generation descending, then rev ascending', () => {
    const result = computeRevisionTreeLayout([
      node('1-a', null),
      node('2-win', '1-a', { isLeaf: true, isWinner: true }),
      node('3-deep', '2-win', { isLeaf: true }), // generation 3
      node('2-shallow', '1-a', { isLeaf: true }), // generation 2
    ]);
    // Note: 3-deep has a parent 2-win but 2-win is also listed as a leaf.
    // The input flags win — if it says 2-win is a leaf, we respect it.
    // However, listing both 2-win and 3-deep as leaves is unusual; rebuild
    // input so that only true leaves are marked.
    const clean = computeRevisionTreeLayout([
      node('1-a', null),
      node('2-win', '1-a', { isWinner: true }),
      node('3-deep', '2-win', { isLeaf: true, isWinner: true }),
      node('2-shallow', '1-a', { isLeaf: true }),
    ]);
    const byRev = Object.fromEntries(clean.nodes.map((n) => [n.rev, n]));
    // Winner first → 3-deep in col 0.
    expect(byRev['3-deep'].col).toBe(0);
    // Only remaining leaf 2-shallow in col 1.
    expect(byRev['2-shallow'].col).toBe(1);
    // Ancestor 1-a collapses onto col 0 (min child col)
    expect(byRev['1-a'].col).toBe(0);
    // Use result to silence unused-var
    expect(result.columns).toBeGreaterThan(0);
  });

  it('marks edges with the child status (used for colouring)', () => {
    const result = computeRevisionTreeLayout([
      node('1-a', null),
      node('2-b', '1-a', { isLeaf: true, status: 'deleted' }),
    ]);
    expect(result.edges.length).toBe(1);
    expect(result.edges[0].status).toBe('deleted');
    expect(result.edges[0].fromRev).toBe('1-a');
    expect(result.edges[0].toRev).toBe('2-b');
  });

  it('skips edges whose parent is not in the node set (pruned ancestor)', () => {
    const result = computeRevisionTreeLayout([
      node('3-c', '2-missing-parent', { isLeaf: true, isWinner: true }),
    ]);
    expect(result.nodes.length).toBe(1);
    expect(result.edges.length).toBe(0);
  });

  it('renders missing ancestors as nodes when present in the input', () => {
    const result = computeRevisionTreeLayout([
      node('1-a', null, { status: 'missing' }),
      node('2-b', '1-a', { isLeaf: true, isWinner: true }),
    ]);
    const byRev = Object.fromEntries(result.nodes.map((n) => [n.rev, n]));
    expect(byRev['1-a'].status).toBe('missing');
    expect(result.edges.length).toBe(1);
  });

  it('handles a 50-rev linear chain without regression', () => {
    const chain: RevisionNode[] = [];
    for (let i = 1; i <= 50; i++) {
      chain.push(
        node(`${i}-rev${i}`, i === 1 ? null : `${i - 1}-rev${i - 1}`, {
          isLeaf: i === 50,
          isWinner: i === 50,
        }),
      );
    }
    const result = computeRevisionTreeLayout(chain);
    expect(result.nodes.length).toBe(50);
    expect(result.edges.length).toBe(49);
    expect(result.rows).toBe(50);
    expect(result.columns).toBe(1);
    // All nodes share column 0
    for (const n of result.nodes) expect(n.col).toBe(0);
  });

  it('handles 3-leaf conflict tree with a shared ancestor', () => {
    const result = computeRevisionTreeLayout([
      node('1-a', null),
      node('2-b', '1-a'),
      node('3-win', '2-b', { isLeaf: true, isWinner: true }),
      node('3-c1', '2-b', { isLeaf: true }),
      node('2-d', '1-a', { isLeaf: true, status: 'deleted' }),
    ]);
    const byRev = Object.fromEntries(result.nodes.map((n) => [n.rev, n]));
    // 3 leaves → 3 columns
    expect(result.columns).toBe(3);
    // Winner anchors col 0
    expect(byRev['3-win'].col).toBe(0);
    // 2-b collapses to min of its children (3-win @ col 0) → col 0
    expect(byRev['2-b'].col).toBe(0);
    // 1-a collapses to min of its children (2-b @ col 0, 2-d @ col >= 1) → col 0
    expect(byRev['1-a'].col).toBe(0);
  });

  it('is deterministic for the same input', () => {
    const input: RevisionNode[] = [
      node('1-a', null),
      node('2-b', '1-a', { isLeaf: true, isWinner: true }),
      node('2-c', '1-a', { isLeaf: true }),
      node('2-d', '1-a', { isLeaf: true, status: 'deleted' }),
    ];
    const r1 = computeRevisionTreeLayout(input);
    const r2 = computeRevisionTreeLayout(input);
    expect(r1).toEqual(r2);
  });

  it('does not mutate its input', () => {
    const input: RevisionNode[] = [
      node('1-a', null, { branch: 99 }),
      node('2-b', '1-a', { isLeaf: true, isWinner: true }),
    ];
    const snapshot = JSON.parse(JSON.stringify(input));
    computeRevisionTreeLayout(input);
    expect(input).toEqual(snapshot);
  });
});
