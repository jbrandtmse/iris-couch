import { UrlSegment } from '@angular/router';
import { docDetailMatcher, designDocDetailMatcher, routes } from './app.routes';

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
});
