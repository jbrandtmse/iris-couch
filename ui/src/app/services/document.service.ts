import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { CouchApiService } from './couch-api.service';

/** A single row in the _all_docs response. */
export interface AllDocsRow {
  id: string;
  key: string;
  value: {
    rev: string;
    deleted?: boolean;
  };
}

/** Shape of the CouchDB GET /{db}/_all_docs response. */
export interface AllDocsResponse {
  total_rows: number;
  offset: number;
  rows: AllDocsRow[];
}

/** Options for the listDocuments call. */
export interface ListDocumentsOptions {
  limit?: number;
  skip?: number;
  startkey?: string;
  endkey?: string;
  include_docs?: boolean;
  descending?: boolean;
}

/** Options for the getDocument call. */
export interface GetDocumentOptions {
  rev?: string;
}

/**
 * Encode a CouchDB document ID for use in a URL path.
 *
 * Most doc IDs are encoded via `encodeURIComponent`. The `_design/<name>`
 * and `_local/<name>` composite IDs are special: CouchDB's HTTP API
 * (and the IRISCouch router) expects a literal `/` between the prefix
 * and the name, NOT `%2F`. We therefore encode the prefix and name
 * separately and rejoin with a literal `/`.
 *
 * Examples:
 *   encodeDocId("doc1")           -> "doc1"
 *   encodeDocId("my doc")         -> "my%20doc"
 *   encodeDocId("_design/myapp")  -> "_design/myapp"
 *   encodeDocId("_design/my app") -> "_design/my%20app"
 *   encodeDocId("_local/ckpt")    -> "_local/ckpt"
 *
 * See Story 11.0 AC #3 / Task 3 and sources/couchdb/src/chttpd/src/chttpd_db.erl.
 */
export function encodeDocId(docid: string): string {
  for (const prefix of ['_design/', '_local/']) {
    if (docid.startsWith(prefix)) {
      const name = docid.slice(prefix.length);
      return prefix + encodeURIComponent(name);
    }
  }
  return encodeURIComponent(docid);
}

/**
 * Construct the URL path fragment for a design document by name.
 *
 * Given "myapp", returns "_design/myapp" (ready to pass to route navigation
 * or to encodeDocId()). Callers that need the API wire format should pipe
 * through encodeDocId().
 */
export function designDocId(name: string): string {
  return '_design/' + name;
}

/**
 * DocumentService -- CRUD operations for CouchDB documents.
 *
 * Wraps CouchApiService with typed methods for the _all_docs endpoint.
 */
@Injectable({ providedIn: 'root' })
export class DocumentService {
  constructor(private readonly api: CouchApiService) {}

  /**
   * GET /{db}/{docid} with ?conflicts=true.
   *
   * Returns the full document body including _id, _rev, _conflicts,
   * and _attachments metadata (stubs). Always requests conflicts=true
   * to detect conflict state. Uses `encodeDocId()` to preserve the
   * literal `/` in `_design/<name>` and `_local/<name>` composite IDs.
   */
  getDocument(db: string, docid: string, options: GetDocumentOptions = {}): Observable<any> {
    const params = new URLSearchParams();
    params.set('conflicts', 'true');

    if (options.rev) {
      params.set('rev', options.rev);
    }

    const path = `${encodeURIComponent(db)}/${encodeDocId(docid)}?${params.toString()}`;
    return this.api.get<any>(path);
  }

  /**
   * GET /{db}/_all_docs filtered to design documents only.
   *
   * Emits the CouchDB-spec-standard prefix trick: startkey=`"_design/"` and
   * endkey=`"_design0"` (the ASCII character one byte greater than `/`) so
   * all `_design/<name>` rows are returned without over-fetching.
   *
   * See `sources/couchdb/src/chttpd/src/chttpd_db.erl` for reference and
   * Story 11.1 AC #1 / Task 1.
   *
   * @param db the database name
   * @param opts optional extra options (include_docs, descending, limit, skip)
   */
  listDesignDocs(
    db: string,
    opts: Pick<ListDocumentsOptions, 'include_docs' | 'descending' | 'limit' | 'skip'> = {},
  ): Observable<AllDocsResponse> {
    return this.listDocuments(db, {
      ...opts,
      startkey: '_design/',
      endkey: '_design0',
    });
  }

  /**
   * GET /{db}/_all_docs with query parameters.
   *
   * Returns a paginated list of document IDs and revisions.
   * Does not include document bodies by default (include_docs=false).
   */
  listDocuments(db: string, options: ListDocumentsOptions = {}): Observable<AllDocsResponse> {
    const params = new URLSearchParams();

    if (options.limit != null) {
      params.set('limit', String(options.limit));
    }
    if (options.skip != null) {
      params.set('skip', String(options.skip));
    }
    if (options.startkey != null) {
      params.set('startkey', JSON.stringify(options.startkey));
    }
    if (options.endkey != null) {
      params.set('endkey', JSON.stringify(options.endkey));
    }
    if (options.include_docs != null) {
      params.set('include_docs', String(options.include_docs));
    }
    if (options.descending != null) {
      params.set('descending', String(options.descending));
    }

    const query = params.toString();
    const path = `${encodeURIComponent(db)}/_all_docs${query ? '?' + query : ''}`;
    return this.api.get<AllDocsResponse>(path);
  }
}
