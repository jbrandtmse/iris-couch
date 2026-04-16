import { Injectable } from '@angular/core';
import { Observable, map } from 'rxjs';
import { CouchApiService } from './couch-api.service';

/**
 * CouchDB security role list — holds named principals and named roles.
 *
 * Shape per CouchDB 3.x spec (see
 * `sources/couchdb/src/chttpd/src/chttpd_db.erl` → `handle_security_req/2`).
 */
export interface SecurityRoleList {
  names: string[];
  roles: string[];
}

/** Full `_security` document: admins and members. */
export interface SecurityDoc {
  admins: SecurityRoleList;
  members: SecurityRoleList;
}

/**
 * The empty-default `_security` shape. Displayed when the backend returns
 * `{}` or a partial object (Story 11.2 AC #2).
 */
export const DEFAULT_SECURITY: SecurityDoc = {
  admins: { names: [], roles: [] },
  members: { names: [], roles: [] },
};

/**
 * Normalize a raw `_security` response into the full default shape.
 *
 * Backend behavior observed at Story 11.2 implementation time: IRISCouch
 * returns the full default object `{"admins":{"names":[],"roles":[]},...}`
 * when `_security` has never been set (diverges from CouchDB 3.x which
 * returns `{}`). This function is defensive for both cases: if any of the
 * top-level keys or nested arrays are missing, they are filled with empty
 * defaults before the component hands the JSON to `JsonDisplay`.
 */
export function normalizeSecurity(raw: unknown): SecurityDoc {
  const input = (raw && typeof raw === 'object' ? raw : {}) as Partial<SecurityDoc>;
  const normalizeRoleList = (v: unknown): SecurityRoleList => {
    const r = (v && typeof v === 'object' ? v : {}) as Partial<SecurityRoleList>;
    return {
      names: Array.isArray(r.names) ? r.names : [],
      roles: Array.isArray(r.roles) ? r.roles : [],
    };
  };
  return {
    admins: normalizeRoleList(input.admins),
    members: normalizeRoleList(input.members),
  };
}

/**
 * SecurityService — read access to the per-database `_security` endpoint.
 *
 * Kept as a small dedicated service for cohesion (Story 11.2 Task 1). Edit
 * semantics arrive in Story 11.3 and will be added here alongside the
 * existing read call.
 *
 * `_security` is special: no `_id`/`_rev`, no revisions. See
 * `sources/couchdb/src/chttpd/src/chttpd_db.erl` → `handle_security_req/2`.
 */
@Injectable({ providedIn: 'root' })
export class SecurityService {
  constructor(private readonly api: CouchApiService) {}

  /**
   * GET /{db}/_security — returns the full security document, normalized to
   * the empty default shape when the backend omits keys or returns `{}`.
   */
  getSecurity(db: string): Observable<SecurityDoc> {
    return this.api
      .get<unknown>(`${encodeURIComponent(db)}/_security`)
      .pipe(map((raw) => normalizeSecurity(raw)));
  }
}
