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

/**
 * DocumentService -- CRUD operations for CouchDB documents.
 *
 * Wraps CouchApiService with typed methods for the _all_docs endpoint.
 */
@Injectable({ providedIn: 'root' })
export class DocumentService {
  constructor(private readonly api: CouchApiService) {}

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
