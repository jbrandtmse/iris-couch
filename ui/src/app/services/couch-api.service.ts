import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';

/**
 * CouchApiService — HttpClient wrapper for the iris-couch REST API.
 *
 * The admin UI is served from `/iris-couch/_utils/` (via Story 11.5
 * `AdminUIHandler.cls`) and the index.html sets `<base href="/iris-couch/_utils/">`.
 * That base href causes relative URLs (e.g. `_session`) to resolve to
 * `/iris-couch/_utils/_session`, which the AdminUIHandler serves as the
 * SPA fallback (index.html) — which is NOT the REST API.
 *
 * The REST API lives at `/iris-couch/` (one level up from `_utils/`).
 * All callers pass CouchDB-style relative paths (`_session`, `_all_dbs`,
 * `mydb/doc1`, etc.); this service prepends the REST API base path so
 * requests hit the CouchDB-compatible handlers rather than the SPA.
 */
@Injectable({ providedIn: 'root' })
export class CouchApiService {
  /**
   * Absolute REST API base path, with trailing slash. Absolute (starts
   * with `/`) so it is NOT resolved against the SPA's `<base href>`.
   */
  private static readonly API_BASE = '/iris-couch/';

  constructor(private readonly http: HttpClient) {}

  /**
   * Resolve a caller-supplied CouchDB path (e.g. `_session`, `_all_dbs`,
   * `mydb/_all_docs`) to the absolute URL under the REST API root.
   *
   * Absolute paths (starting with `/`) and fully-qualified URLs are
   * passed through unchanged so callers can still opt out when they
   * already know the absolute path they need.
   */
  private resolve(path: string): string {
    if (path.startsWith('http://') || path.startsWith('https://') || path.startsWith('/')) {
      return path;
    }
    return CouchApiService.API_BASE + path;
  }

  get<T>(path: string): Observable<T> {
    return this.http.get<T>(this.resolve(path));
  }

  post<T>(path: string, body: unknown): Observable<T> {
    return this.http.post<T>(this.resolve(path), body);
  }

  put<T>(path: string, body: unknown): Observable<T> {
    return this.http.put<T>(this.resolve(path), body);
  }

  delete<T>(path: string): Observable<T> {
    return this.http.delete<T>(this.resolve(path));
  }
}
