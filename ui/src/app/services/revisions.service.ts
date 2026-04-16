import { Injectable } from '@angular/core';
import { Observable, forkJoin, map, of, switchMap, catchError } from 'rxjs';
import { CouchApiService } from './couch-api.service';
import { encodeDocId } from './document.service';
import { RevisionNode, RevisionStatus } from '../couch-ui';

/** Raw `_revs_info` entry from CouchDB. */
interface RevsInfoEntry {
  rev: string;
  status: string;
}

/** Shape of the GET {db}/{doc}?revs_info=true&conflicts=true&deleted_conflicts=true response. */
interface HeadResponse {
  _id: string;
  _rev: string;
  _revs_info?: RevsInfoEntry[];
  _conflicts?: string[];
  _deleted_conflicts?: string[];
  // …plus the document body, which we ignore here.
}

/** Shape of a branch-head GET {db}/{doc}?rev={leaf}&revs_info=true response. */
interface BranchHeadResponse {
  _id: string;
  _rev: string;
  _revs_info?: RevsInfoEntry[];
}

/**
 * Full result of {@link RevisionsService.getRevisionTree}.
 *
 * `nodes` is ready to feed directly into `RevisionTreeComponent.nodes`.
 * `raw` exposes the underlying HTTP responses for diagnostics — never
 * render it directly.
 */
export interface RevisionTreeResult {
  nodes: RevisionNode[];
  winnerRev: string;
  raw: {
    head: HeadResponse;
    branchHeads: BranchHeadResponse[];
  };
}

/**
 * RevisionsService — fetches and stitches a CouchDB document's revision
 * tree into a shape ready for the {@link RevisionTreeComponent}.
 *
 * CouchDB itself has no `/_revs_tree` endpoint — Fauxton (and now this
 * service) reconstructs the graph client-side by combining:
 *   1. the winning-branch ancestor chain (`?revs_info=true`),
 *   2. one extra GET per conflict leaf (`?rev={leaf}&revs_info=true`).
 *
 * Those linear chains are merged into one node set, deduplicated by
 * rev string. The service matches CouchDB's wire convention and keeps
 * backend changes to zero beyond the `?deleted_conflicts=true` support
 * added in Story 11.4 Task 1.
 *
 * Subscription discipline: exactly one outer subscription (returned
 * `Observable`) flows through a single `forkJoin` — no nested
 * `.subscribe()` calls inside the service (per `.claude/rules/angular-patterns.md`).
 */
@Injectable({ providedIn: 'root' })
export class RevisionsService {
  constructor(private readonly api: CouchApiService) {}

  /**
   * Fetch the full revision tree for a document.
   *
   * @param db     the database name (e.g., `mydb`)
   * @param docid  the document id — may be a composite `_design/<name>`
   *               or `_local/<name>` (the service preserves the literal `/`)
   */
  getRevisionTree(db: string, docid: string): Observable<RevisionTreeResult> {
    const headPath =
      `${encodeURIComponent(db)}/${encodeDocId(docid)}` +
      `?revs_info=true&conflicts=true&deleted_conflicts=true`;

    return this.api.get<HeadResponse>(headPath).pipe(
      switchMap((head) => this.fetchBranchHeads(db, docid, head).pipe(
        map((branchHeads) => this.stitch(head, branchHeads)),
      )),
    );
  }

  /**
   * Issue one GET per non-winner conflict leaf. Runs in parallel via
   * `forkJoin`; returns an empty array when there are no conflicts.
   *
   * Deleted conflicts: a plain `?rev=<deleted-leaf>` GET returns 404
   * (CouchDB requires `?deleted=true` or `?open_revs=...` for tombstoned
   * revs). Since we already know the leaf rev from `_deleted_conflicts`,
   * we tolerate 404s on those branch-head fetches by emitting a synthetic
   * minimum-info response — the tree still shows the leaf, just without
   * its full ancestor chain. Live conflicts continue to surface their
   * errors verbatim.
   */
  private fetchBranchHeads(
    db: string,
    docid: string,
    head: HeadResponse,
  ): Observable<BranchHeadResponse[]> {
    const liveLeaves = head._conflicts ?? [];
    const deletedLeaves = head._deleted_conflicts ?? [];
    const leaves = [...liveLeaves, ...deletedLeaves];
    if (leaves.length === 0) return of([]);
    const requests = leaves.map((leaf) => {
      const isDeleted = deletedLeaves.includes(leaf);
      const path =
        `${encodeURIComponent(db)}/${encodeDocId(docid)}` +
        `?rev=${encodeURIComponent(leaf)}&revs_info=true`;
      const obs = this.api.get<BranchHeadResponse>(path);
      if (!isDeleted) return obs;
      // Deleted leaf: tolerate 404 with a synthetic minimal response so
      // the leaf still appears in the tree.
      return obs.pipe(
        catchError((err) => {
          // Re-throw non-404 errors (e.g., 401/500) — those should still
          // bubble up to the caller.
          if (err && typeof err === 'object' && 'status' in err && err.status !== 404) {
            throw err;
          }
          return of<BranchHeadResponse>({
            _id: docid,
            _rev: leaf,
            _revs_info: [{ rev: leaf, status: 'deleted' }],
          });
        }),
      );
    });
    return forkJoin(requests);
  }

  /**
   * Merge the head chain + branch-head chains into a deduplicated
   * `RevisionNode[]`. Pure function — unit-test-friendly.
   */
  private stitch(
    head: HeadResponse,
    branchHeads: BranchHeadResponse[],
  ): RevisionTreeResult {
    const byRev = new Map<string, RevisionNode>();
    const winnerRev = head._rev;

    const liveConflicts = new Set(head._conflicts ?? []);
    const deletedConflicts = new Set(head._deleted_conflicts ?? []);
    const leafSet = new Set<string>([
      winnerRev,
      ...liveConflicts,
      ...deletedConflicts,
    ]);

    const mergeChain = (chain: RevsInfoEntry[] | undefined, leafRev: string) => {
      if (!chain || chain.length === 0) return;
      // `_revs_info` is ordered newest → oldest. The first entry is the leaf
      // we queried; each subsequent entry is its parent.
      for (let i = 0; i < chain.length; i++) {
        const entry = chain[i];
        const parentRev = i + 1 < chain.length ? chain[i + 1].rev : null;
        const existing = byRev.get(entry.rev);
        const node: RevisionNode = existing ?? {
          rev: entry.rev,
          parentRev,
          status: normalizeStatus(entry.status),
          isLeaf: false,
          isWinner: false,
          branch: 0,
        };
        // Prefer a non-null parentRev when stitching (the root rev in one
        // chain may appear mid-chain in another).
        if (!node.parentRev && parentRev) node.parentRev = parentRev;
        // If one chain says "missing" but another says "available", trust
        // the more-informative status.
        if (node.status === 'missing' && entry.status && entry.status !== 'missing') {
          node.status = normalizeStatus(entry.status);
        }
        byRev.set(entry.rev, node);
      }
    };

    mergeChain(head._revs_info, winnerRev);
    for (const branch of branchHeads) {
      mergeChain(branch._revs_info, branch._rev);
    }

    // Mark leaves and winner flags.
    for (const node of byRev.values()) {
      if (leafSet.has(node.rev)) node.isLeaf = true;
      if (node.rev === winnerRev) node.isWinner = true;
      // Deleted leaves take the `deleted` status regardless of any
      // intermediate `?`-missing fill-in.
      if (deletedConflicts.has(node.rev)) node.status = 'deleted';
    }

    return {
      nodes: Array.from(byRev.values()),
      winnerRev,
      raw: { head, branchHeads },
    };
  }
}

/** Narrow the free-form server `status` field into the typed enum. */
function normalizeStatus(raw: string): RevisionStatus {
  if (raw === 'deleted') return 'deleted';
  if (raw === 'missing') return 'missing';
  return 'available';
}
