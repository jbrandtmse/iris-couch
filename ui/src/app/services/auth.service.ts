import { Injectable } from '@angular/core';
import { BehaviorSubject, Observable, tap, map, catchError, of, switchMap } from 'rxjs';
import { CouchApiService } from './couch-api.service';

/** Shape of the CouchDB /_session GET response. */
export interface SessionResponse {
  ok: boolean;
  userCtx: {
    name: string | null;
    roles: string[];
  };
  info?: Record<string, unknown>;
}

/** Shape of the CouchDB /_session POST response. */
export interface LoginResponse {
  ok: boolean;
  name: string;
  roles: string[];
}

/**
 * AuthService — session management via the CouchDB /_session API.
 *
 * On initialization, checks for an existing session cookie so that
 * page refreshes do not force re-login.
 */
@Injectable({ providedIn: 'root' })
export class AuthService {
  private readonly sessionSubject = new BehaviorSubject<SessionResponse | null>(null);

  /** Emits true when the user has an authenticated session. */
  readonly isAuthenticated$: Observable<boolean> = this.sessionSubject.pipe(
    map((s) => s?.userCtx?.name != null)
  );

  /** Emits the current username, or empty string when not logged in. */
  readonly username$: Observable<string> = this.sessionSubject.pipe(
    map((s) => s?.userCtx?.name ?? '')
  );

  constructor(private readonly api: CouchApiService) {}

  /** Call on app init to check if a session cookie already exists. */
  checkSession(): Observable<SessionResponse> {
    return this.getSession().pipe(
      tap((session) => this.sessionSubject.next(session)),
      catchError(() => {
        this.sessionSubject.next(null);
        return of({ ok: false, userCtx: { name: null, roles: [] } } as SessionResponse);
      })
    );
  }

  /** POST /_session with {name, password} for cookie auth. */
  login(username: string, password: string): Observable<LoginResponse> {
    return this.api.post<LoginResponse>('_session', { name: username, password }).pipe(
      switchMap((loginRes) =>
        // Re-fetch full session to populate userCtx, then return the login response
        this.getSession().pipe(
          tap((session) => this.sessionSubject.next(session)),
          map(() => loginRes)
        )
      )
    );
  }

  /** DELETE /_session to clear the session cookie. */
  logout(): Observable<unknown> {
    return this.api.delete('_session').pipe(
      tap(() => this.sessionSubject.next(null))
    );
  }

  /** GET /_session to retrieve the current session state. */
  getSession(): Observable<SessionResponse> {
    return this.api.get<SessionResponse>('_session');
  }

  /** Forcefully clear the local session state (used by 401 interceptor). */
  clearSession(): void {
    this.sessionSubject.next(null);
  }
}
