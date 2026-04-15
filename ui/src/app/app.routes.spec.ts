import { UrlSegment } from '@angular/router';
import { docDetailMatcher } from './app.routes';

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
