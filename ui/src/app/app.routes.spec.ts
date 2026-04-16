import { TestBed } from '@angular/core/testing';
import { provideRouter, Router, UrlSegment, Route } from '@angular/router';
import { Component } from '@angular/core';
import { docDetailMatcher, designDocDetailMatcher, revisionsMatcher, routes } from './app.routes';

describe('docDetailMatcher', () => {
  const seg = (path: string) => new UrlSegment(path, {});

  // Calls the matcher with a best-effort stub for the unused arguments.
  function match(segments: UrlSegment[]) {
    return docDetailMatcher(segments, {} as any, {} as any);
  }

  it('returns null for unrelated paths', () => {
    expect(match([seg('foo')])).toBeNull();
    expect(match([seg('db'), seg('testdb')])).toBeNull();
    expect(match([seg('db'), seg('testdb'), seg('something'), seg('else')])).toBeNull();
  });

  it('matches /db/{dbname}/doc/{docid} for a plain doc id', () => {
    const result = match([seg('db'), seg('testdb'), seg('doc'), seg('doc1')]);
    expect(result).not.toBeNull();
    expect(result!.posParams!['dbname'].path).toBe('testdb');
    expect(result!.posParams!['docid'].path).toBe('doc1');
  });

  it('reassembles `_design/<name>` into a single docid with the literal `/`', () => {
    const result = match([seg('db'), seg('testdb'), seg('doc'), seg('_design'), seg('myapp')]);
    expect(result).not.toBeNull();
    expect(result!.posParams!['dbname'].path).toBe('testdb');
    expect(result!.posParams!['docid'].path).toBe('_design/myapp');
  });

  it('reassembles `_local/<name>` into a single docid with the literal `/`', () => {
    const result = match([seg('db'), seg('testdb'), seg('doc'), seg('_local'), seg('ckpt-1')]);
    expect(result).not.toBeNull();
    expect(result!.posParams!['docid'].path).toBe('_local/ckpt-1');
  });
});

// Story 11.1 AC #3 / Task 5 -- design-doc detail route matcher.
describe('designDocDetailMatcher', () => {
  const seg = (path: string) => new UrlSegment(path, {});

  function match(segments: UrlSegment[]) {
    return designDocDetailMatcher(segments, {} as any, {} as any);
  }

  it('returns null for unrelated paths', () => {
    expect(match([seg('foo')])).toBeNull();
    expect(match([seg('db'), seg('testdb')])).toBeNull();
    expect(match([seg('db'), seg('testdb'), seg('something'), seg('else')])).toBeNull();
  });

  it('returns null for the bare `/db/:dbname/design` list path (so list route catches it)', () => {
    expect(match([seg('db'), seg('testdb'), seg('design')])).toBeNull();
  });

  it('matches /db/{dbname}/design/{ddocid} for a plain short name', () => {
    const result = match([seg('db'), seg('testdb'), seg('design'), seg('myapp')]);
    expect(result).not.toBeNull();
    expect(result!.posParams!['dbname'].path).toBe('testdb');
    expect(result!.posParams!['ddocid'].path).toBe('myapp');
  });

  it('rejoins multi-segment short names (defensive — CouchDB forbids `/` in ddoc names)', () => {
    const result = match([seg('db'), seg('testdb'), seg('design'), seg('parent'), seg('child')]);
    expect(result).not.toBeNull();
    expect(result!.posParams!['ddocid'].path).toBe('parent/child');
  });
});

// Route table wiring: ensure the new routes are registered in the correct
// order (list route before matcher, so the bare path reaches the list).
describe('app routes table', () => {
  it('registers the design-doc list route at /db/:dbname/design', () => {
    const listRoute = routes.find((r) => r.path === 'db/:dbname/design');
    expect(listRoute).toBeDefined();
    expect(listRoute!.canActivate).toBeTruthy();
  });

  it('registers the design-doc detail matcher route', () => {
    const detailRoute = routes.find((r) => r.matcher === designDocDetailMatcher);
    expect(detailRoute).toBeDefined();
    expect(detailRoute!.canActivate).toBeTruthy();
  });

  it('orders the design-doc list route before the design-doc detail matcher', () => {
    const listIdx = routes.findIndex((r) => r.path === 'db/:dbname/design');
    const detailIdx = routes.findIndex((r) => r.matcher === designDocDetailMatcher);
    expect(listIdx).toBeGreaterThan(-1);
    expect(detailIdx).toBeGreaterThan(-1);
    expect(listIdx).toBeLessThan(detailIdx);
  });

  // Story 11.2 AC #3 -- security view route wiring.
  it('registers the security view route at /db/:dbname/security', () => {
    const secRoute = routes.find((r) => r.path === 'db/:dbname/security');
    expect(secRoute).toBeDefined();
    expect(secRoute!.canActivate).toBeTruthy();
    expect(secRoute!.component).toBeDefined();
  });

  // Story 11.4 -- revisions view route wiring.
  it('registers the revisions matcher route', () => {
    const revRoute = routes.find((r) => r.matcher === revisionsMatcher);
    expect(revRoute).toBeDefined();
    expect(revRoute!.canActivate).toBeTruthy();
    expect(revRoute!.component).toBeDefined();
  });

  it('orders revisionsMatcher BEFORE docDetailMatcher (so /doc/{id}/revisions does not get swallowed)', () => {
    const revIdx = routes.findIndex((r) => r.matcher === revisionsMatcher);
    const docIdx = routes.findIndex((r) => r.matcher === docDetailMatcher);
    expect(revIdx).toBeGreaterThan(-1);
    expect(docIdx).toBeGreaterThan(-1);
    expect(revIdx).toBeLessThan(docIdx);
  });
});

// Story 11.4 Task 5 -- revision-history URL matcher.
describe('revisionsMatcher', () => {
  const seg = (path: string) => new UrlSegment(path, {});

  function match(segments: UrlSegment[]) {
    return revisionsMatcher(segments, {} as any, {} as any);
  }

  it('returns null for unrelated paths', () => {
    expect(match([seg('foo')])).toBeNull();
    expect(match([seg('db'), seg('testdb'), seg('doc'), seg('doc1')])).toBeNull();
    expect(match([seg('db'), seg('testdb'), seg('doc'), seg('doc1'), seg('other')])).toBeNull();
  });

  it('matches /db/{dbname}/doc/{docid}/revisions for a plain doc id', () => {
    const result = match([seg('db'), seg('testdb'), seg('doc'), seg('doc1'), seg('revisions')]);
    expect(result).not.toBeNull();
    expect(result!.posParams!['dbname'].path).toBe('testdb');
    expect(result!.posParams!['docid'].path).toBe('doc1');
  });

  it('matches /db/{dbname}/doc/_design/{name}/revisions and rejoins the composite ID', () => {
    const result = match([
      seg('db'),
      seg('testdb'),
      seg('doc'),
      seg('_design'),
      seg('myapp'),
      seg('revisions'),
    ]);
    expect(result).not.toBeNull();
    expect(result!.posParams!['dbname'].path).toBe('testdb');
    expect(result!.posParams!['docid'].path).toBe('_design/myapp');
  });

  it('does NOT match the plain doc detail path /db/{db}/doc/{id}', () => {
    const result = match([seg('db'), seg('testdb'), seg('doc'), seg('doc1')]);
    expect(result).toBeNull();
  });
});

// Story 11.4 — Router integration regression test.
// The user-visible risk is that `/db/{db}/doc/{id}/revisions` could be
// swallowed by `docDetailMatcher` (which consumes all trailing segments
// after `/doc/`) and activate DocumentDetailComponent with a doc id of
// `{id}/revisions` instead of routing to RevisionsViewComponent.
//
// The order-index test above catches misordering statically, but we also
// want a "real" router resolve-path check — we build a minimal Router
// config that mirrors the app.routes ordering, point it at stub
// components, and assert that navigating to the revisions URL lands on
// the stub bound to revisionsMatcher, not the one bound to
// docDetailMatcher.
describe('Router resolution — /doc/{id}/revisions routes to RevisionsViewComponent', () => {
  @Component({ standalone: true, template: 'doc-stub' })
  class DocStubComponent {}

  @Component({ standalone: true, template: 'rev-stub' })
  class RevStubComponent {}

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [
        provideRouter([
          // Mirror the REAL ordering — revisionsMatcher before docDetailMatcher.
          { matcher: revisionsMatcher, component: RevStubComponent } as Route,
          { matcher: docDetailMatcher, component: DocStubComponent } as Route,
        ]),
      ],
    });
  });

  async function resolveTo(url: string): Promise<string> {
    const router = TestBed.inject(Router);
    await router.navigateByUrl(url);
    // Walk the activated route tree to find the component class.
    let route = router.routerState.root;
    while (route.firstChild) route = route.firstChild;
    const component = route.snapshot.component as { name?: string } | null;
    return component?.name ?? '';
  }

  it('/db/foo/doc/bar/revisions activates RevStubComponent (not DocStubComponent)', async () => {
    const name = await resolveTo('/db/foo/doc/bar/revisions');
    expect(name).toBe('RevStubComponent');
  });

  it('/db/foo/doc/_design/myapp/revisions activates RevStubComponent', async () => {
    const name = await resolveTo('/db/foo/doc/_design/myapp/revisions');
    expect(name).toBe('RevStubComponent');
  });

  it('/db/foo/doc/bar (no /revisions suffix) activates DocStubComponent', async () => {
    const name = await resolveTo('/db/foo/doc/bar');
    expect(name).toBe('DocStubComponent');
  });

  it('/db/foo/doc/bar/revisions does NOT activate DocStubComponent', async () => {
    const name = await resolveTo('/db/foo/doc/bar/revisions');
    expect(name).not.toBe('DocStubComponent');
  });

  it('swapping the order causes the doc route to swallow the revisions URL (negative control)', async () => {
    // Rebuild TestBed with REVERSED order to prove the ordering matters.
    TestBed.resetTestingModule();
    TestBed.configureTestingModule({
      providers: [
        provideRouter([
          { matcher: docDetailMatcher, component: DocStubComponent } as Route,
          { matcher: revisionsMatcher, component: RevStubComponent } as Route,
        ]),
      ],
    });
    const router = TestBed.inject(Router);
    await router.navigateByUrl('/db/foo/doc/bar/revisions');
    let route = router.routerState.root;
    while (route.firstChild) route = route.firstChild;
    const name = (route.snapshot.component as { name?: string } | null)?.name ?? '';
    expect(name).toBe('DocStubComponent'); // bug if order is reversed
  });
});
