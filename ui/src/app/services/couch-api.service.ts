import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';

/**
 * CouchApiService — HttpClient wrapper for the iris-couch REST API.
 *
 * Base URL is `/` (relative to origin) because the Angular app is served
 * from the same origin as the CouchDB-compatible API, per architecture
 * deployment topology.
 */
@Injectable({ providedIn: 'root' })
export class CouchApiService {
  constructor(private readonly http: HttpClient) {}

  get<T>(path: string): Observable<T> {
    return this.http.get<T>(path);
  }

  post<T>(path: string, body: unknown): Observable<T> {
    return this.http.post<T>(path, body);
  }

  put<T>(path: string, body: unknown): Observable<T> {
    return this.http.put<T>(path, body);
  }

  delete<T>(path: string): Observable<T> {
    return this.http.delete<T>(path);
  }
}
