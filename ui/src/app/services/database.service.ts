import { Injectable } from '@angular/core';
import { Observable, forkJoin, map, switchMap } from 'rxjs';
import { CouchApiService } from './couch-api.service';

/** Shape of the CouchDB GET /{db} response. Tolerates legacy flat `disk_size`. */
export interface DbInfo {
  db_name: string;
  doc_count: number;
  update_seq: string | number;
  sizes?: {
    file: number;
    external: number;
    active: number;
  };
  disk_size?: number;
}

/** Combined database entry for the list view (name + info). */
export interface DatabaseEntry {
  name: string;
  docCount: number;
  updateSeq: string;
  diskSize: number;
}

/**
 * DatabaseService — CRUD operations for CouchDB databases.
 *
 * Wraps CouchApiService with typed methods for the database lifecycle:
 * list, info, create, delete.
 */
@Injectable({ providedIn: 'root' })
export class DatabaseService {
  constructor(private readonly api: CouchApiService) {}

  /** GET /_all_dbs — returns array of database names. */
  listDatabases(): Observable<string[]> {
    return this.api.get<string[]>('_all_dbs');
  }

  /** GET /{name} — returns database info. */
  getDatabaseInfo(name: string): Observable<DbInfo> {
    return this.api.get<DbInfo>(encodeURIComponent(name));
  }

  /** PUT /{name} — creates a new database. */
  createDatabase(name: string): Observable<{ ok: boolean }> {
    return this.api.put<{ ok: boolean }>(encodeURIComponent(name), {});
  }

  /** DELETE /{name} — deletes a database. */
  deleteDatabase(name: string): Observable<{ ok: boolean }> {
    return this.api.delete<{ ok: boolean }>(encodeURIComponent(name));
  }

  /**
   * Fetch all databases with their info.
   * Calls _all_dbs then fetches info for each db via forkJoin.
   */
  listAllWithInfo(): Observable<DatabaseEntry[]> {
    return this.listDatabases().pipe(
      switchMap((names) => {
        if (names.length === 0) {
          return [[] as DatabaseEntry[]];
        }
        const infoRequests = names.map((name) =>
          this.getDatabaseInfo(name).pipe(
            map((info) => ({
              name: info.db_name,
              docCount: info.doc_count,
              updateSeq: typeof info.update_seq === 'string'
                ? info.update_seq
                : String(info.update_seq),
              diskSize: info.sizes?.file ?? info.disk_size ?? 0,
            }))
          )
        );
        return forkJoin(infoRequests);
      })
    );
  }
}
