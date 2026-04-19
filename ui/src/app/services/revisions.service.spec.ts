import { TestBed } from '@angular/core/testing';
import { HttpClientTestingModule, HttpTestingController } from '@angular/common/http/testing';
import { HttpErrorResponse } from '@angular/common/http';
import { RevisionsService, RevisionTreeResult } from './revisions.service';
import { CouchApiService } from './couch-api.service';

describe('RevisionsService', () => {
  let service: RevisionsService;
  let http: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      imports: [HttpClientTestingModule],
      providers: [RevisionsService, CouchApiService],
    });
    service = TestBed.inject(RevisionsService);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => http.verify());

  it('hits the combined-query URL and returns 1 node for a single-rev doc', () => {
    let result: RevisionTreeResult | undefined;
    service.getRevisionTree('mydb', 'doc1').subscribe((r) => (result = r));

    const req = http.expectOne(
      '/iris-couch/mydb/doc1?revs_info=true&conflicts=true&deleted_conflicts=true',
    );
    expect(req.request.method).toBe('GET');
    req.flush({
      _id: 'doc1',
      _rev: '1-abc',
      _revs_info: [{ rev: '1-abc', status: 'available' }],
      _conflicts: [],
      _deleted_conflicts: [],
    });

    expect(result?.nodes.length).toBe(1);
    expect(result?.winnerRev).toBe('1-abc');
    expect(result?.nodes[0].isLeaf).toBe(true);
    expect(result?.nodes[0].isWinner).toBe(true);
    // No extra requests should fire
    http.expectNone((r) => r.url.includes('rev='));
  });

  it('stitches a 3-rev linear chain without extra requests', () => {
    let result: RevisionTreeResult | undefined;
    service.getRevisionTree('mydb', 'doc1').subscribe((r) => (result = r));

    http.expectOne(
      '/iris-couch/mydb/doc1?revs_info=true&conflicts=true&deleted_conflicts=true',
    ).flush({
      _id: 'doc1',
      _rev: '3-c',
      _revs_info: [
        { rev: '3-c', status: 'available' },
        { rev: '2-b', status: 'available' },
        { rev: '1-a', status: 'available' },
      ],
      _conflicts: [],
      _deleted_conflicts: [],
    });

    expect(result?.nodes.length).toBe(3);
    expect(result?.winnerRev).toBe('3-c');
    const byRev = Object.fromEntries((result?.nodes ?? []).map((n) => [n.rev, n]));
    expect(byRev['3-c'].isWinner).toBe(true);
    expect(byRev['3-c'].isLeaf).toBe(true);
    expect(byRev['3-c'].parentRev).toBe('2-b');
    expect(byRev['2-b'].parentRev).toBe('1-a');
    expect(byRev['1-a'].parentRev).toBe(null);
    // Non-winner intermediate revs are not leaves
    expect(byRev['2-b'].isLeaf).toBe(false);
    expect(byRev['1-a'].isLeaf).toBe(false);
  });

  it('fans out 1 extra GET per conflict leaf, using forkJoin', () => {
    let result: RevisionTreeResult | undefined;
    service.getRevisionTree('mydb', 'doc1').subscribe((r) => (result = r));

    http.expectOne(
      '/iris-couch/mydb/doc1?revs_info=true&conflicts=true&deleted_conflicts=true',
    ).flush({
      _id: 'doc1',
      _rev: '2-winner',
      _revs_info: [
        { rev: '2-winner', status: 'available' },
        { rev: '1-root', status: 'available' },
      ],
      _conflicts: ['2-conflict'],
      _deleted_conflicts: [],
    });

    const branchReq = http.expectOne(
      '/iris-couch/mydb/doc1?rev=2-conflict&revs_info=true',
    );
    branchReq.flush({
      _id: 'doc1',
      _rev: '2-conflict',
      _revs_info: [
        { rev: '2-conflict', status: 'available' },
        { rev: '1-root', status: 'available' },
      ],
    });

    expect(result?.nodes.length).toBe(3);
    const byRev = Object.fromEntries((result?.nodes ?? []).map((n) => [n.rev, n]));
    expect(byRev['2-conflict'].isLeaf).toBe(true);
    expect(byRev['2-conflict'].isWinner).toBe(false);
    expect(byRev['2-winner'].isWinner).toBe(true);
    // Shared ancestor dedupe — single root node
    expect(byRev['1-root']).toBeTruthy();
  });

  it('fans out 2 parallel GETs for 2 conflicts', () => {
    let result: RevisionTreeResult | undefined;
    service.getRevisionTree('mydb', 'doc1').subscribe((r) => (result = r));

    http.expectOne(
      '/iris-couch/mydb/doc1?revs_info=true&conflicts=true&deleted_conflicts=true',
    ).flush({
      _id: 'doc1',
      _rev: '2-winner',
      _revs_info: [
        { rev: '2-winner', status: 'available' },
        { rev: '1-root', status: 'available' },
      ],
      _conflicts: ['2-c1', '2-c2'],
      _deleted_conflicts: [],
    });

    const reqs = http.match((r) => r.url.includes('rev='));
    expect(reqs.length).toBe(2);
    reqs[0].flush({
      _id: 'doc1',
      _rev: '2-c1',
      _revs_info: [
        { rev: '2-c1', status: 'available' },
        { rev: '1-root', status: 'available' },
      ],
    });
    reqs[1].flush({
      _id: 'doc1',
      _rev: '2-c2',
      _revs_info: [
        { rev: '2-c2', status: 'available' },
        { rev: '1-root', status: 'available' },
      ],
    });

    expect(result?.nodes.length).toBe(4);
    const leaves = result?.nodes.filter((n) => n.isLeaf).map((n) => n.rev) ?? [];
    expect(leaves.sort()).toEqual(['2-c1', '2-c2', '2-winner']);
  });

  it('marks deleted-conflicts with status=deleted', () => {
    let result: RevisionTreeResult | undefined;
    service.getRevisionTree('mydb', 'doc1').subscribe((r) => (result = r));

    http.expectOne(
      '/iris-couch/mydb/doc1?revs_info=true&conflicts=true&deleted_conflicts=true',
    ).flush({
      _id: 'doc1',
      _rev: '2-winner',
      _revs_info: [
        { rev: '2-winner', status: 'available' },
        { rev: '1-root', status: 'available' },
      ],
      _conflicts: [],
      _deleted_conflicts: ['2-dead'],
    });

    const branchReq = http.expectOne('/iris-couch/mydb/doc1?rev=2-dead&revs_info=true');
    branchReq.flush({
      _id: 'doc1',
      _rev: '2-dead',
      _revs_info: [
        { rev: '2-dead', status: 'deleted' },
        { rev: '1-root', status: 'available' },
      ],
    });

    const dead = result?.nodes.find((n) => n.rev === '2-dead');
    expect(dead?.status).toBe('deleted');
    expect(dead?.isLeaf).toBe(true);
    expect(dead?.isWinner).toBe(false);
  });

  it('propagates the head request error verbatim (401/403)', () => {
    const errors: unknown[] = [];
    service.getRevisionTree('mydb', 'doc1').subscribe({
      next: () => fail('should have errored'),
      error: (err) => errors.push(err),
    });

    http.expectOne(
      '/iris-couch/mydb/doc1?revs_info=true&conflicts=true&deleted_conflicts=true',
    ).flush(
      { error: 'unauthorized', reason: 'You must be logged in.' },
      { status: 401, statusText: 'Unauthorized' },
    );

    expect(errors.length).toBe(1);
    const err = errors[0] as HttpErrorResponse;
    expect(err.status).toBe(401);
    expect(err.error.error).toBe('unauthorized');
  });

  it('propagates a non-404 branch-head error (failed live-conflict leaf fetch)', () => {
    const results: RevisionTreeResult[] = [];
    const errors: unknown[] = [];
    service.getRevisionTree('mydb', 'doc1').subscribe({
      next: (r) => results.push(r),
      error: (err) => errors.push(err),
    });

    http.expectOne(
      '/iris-couch/mydb/doc1?revs_info=true&conflicts=true&deleted_conflicts=true',
    ).flush({
      _id: 'doc1',
      _rev: '2-winner',
      _revs_info: [{ rev: '2-winner', status: 'available' }],
      _conflicts: ['2-c1'],
      _deleted_conflicts: [],
    });
    http.expectOne('/iris-couch/mydb/doc1?rev=2-c1&revs_info=true').flush(
      { error: 'server_error', reason: 'boom' },
      { status: 500, statusText: 'Server Error' },
    );

    expect(results.length).toBe(0);
    expect(errors.length).toBe(1);
    expect((errors[0] as HttpErrorResponse).status).toBe(500);
  });

  it('tolerates 404 on a deleted-conflict leaf fetch (synthetic minimal response)', () => {
    let result: RevisionTreeResult | undefined;
    service.getRevisionTree('mydb', 'doc1').subscribe((r) => (result = r));

    http.expectOne(
      '/iris-couch/mydb/doc1?revs_info=true&conflicts=true&deleted_conflicts=true',
    ).flush({
      _id: 'doc1',
      _rev: '2-winner',
      _revs_info: [{ rev: '2-winner', status: 'available' }],
      _conflicts: [],
      _deleted_conflicts: ['2-dead'],
    });
    // Backend returns 404 for ?rev=<deleted-leaf>; service should tolerate.
    http.expectOne('/iris-couch/mydb/doc1?rev=2-dead&revs_info=true').flush(
      { error: 'not_found', reason: 'deleted' },
      { status: 404, statusText: 'Not Found' },
    );

    expect(result).toBeDefined();
    const dead = result?.nodes.find((n) => n.rev === '2-dead');
    expect(dead).toBeTruthy();
    expect(dead?.status).toBe('deleted');
    expect(dead?.isLeaf).toBe(true);
    expect(dead?.isWinner).toBe(false);
  });

  it('URL-encodes composite _design/<name> doc IDs preserving the literal "/"', () => {
    let result: RevisionTreeResult | undefined;
    service.getRevisionTree('mydb', '_design/myapp').subscribe((r) => (result = r));
    const req = http.expectOne(
      '/iris-couch/mydb/_design/myapp?revs_info=true&conflicts=true&deleted_conflicts=true',
    );
    // The literal "/" is preserved (not %2F) so the wire URL matches
    // the CouchDB convention.
    expect(req.request.url).toContain('_design/myapp');
    expect(req.request.url).not.toContain('_design%2Fmyapp');
    req.flush({
      _id: '_design/myapp',
      _rev: '1-a',
      _revs_info: [{ rev: '1-a', status: 'available' }],
      _conflicts: [],
      _deleted_conflicts: [],
    });
    expect(result?.winnerRev).toBe('1-a');
  });
});
