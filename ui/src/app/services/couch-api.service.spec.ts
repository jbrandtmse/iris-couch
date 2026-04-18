import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { CouchApiService } from './couch-api.service';

describe('CouchApiService', () => {
  let service: CouchApiService;
  let httpMock: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [
        provideHttpClient(),
        provideHttpClientTesting(),
      ],
    });
    service = TestBed.inject(CouchApiService);
    httpMock = TestBed.inject(HttpTestingController);
  });

  afterEach(() => {
    httpMock.verify();
  });

  it('should be created', () => {
    expect(service).toBeTruthy();
  });

  it('should send GET requests', () => {
    service.get<{ ok: boolean }>('_all_dbs').subscribe((res) => {
      expect(res).toBeTruthy();
    });
    const req = httpMock.expectOne('/iris-couch/_all_dbs');
    expect(req.request.method).toBe('GET');
    req.flush({ ok: true });
  });

  it('should send POST requests with body', () => {
    const body = { name: 'admin', password: 'pass' };
    service.post<{ ok: boolean }>('_session', body).subscribe((res) => {
      expect(res.ok).toBeTrue();
    });
    const req = httpMock.expectOne('/iris-couch/_session');
    expect(req.request.method).toBe('POST');
    expect(req.request.body).toEqual(body);
    req.flush({ ok: true });
  });

  it('should send PUT requests with body', () => {
    const body = { _id: 'doc1', value: 42 };
    service.put<{ ok: boolean }>('mydb/doc1', body).subscribe();
    const req = httpMock.expectOne('/iris-couch/mydb/doc1');
    expect(req.request.method).toBe('PUT');
    expect(req.request.body).toEqual(body);
    req.flush({ ok: true });
  });

  it('should send DELETE requests', () => {
    service.delete<{ ok: boolean }>('_session').subscribe();
    const req = httpMock.expectOne('/iris-couch/_session');
    expect(req.request.method).toBe('DELETE');
    req.flush({ ok: true });
  });

  it('should prepend /iris-couch/ REST API base to relative paths', () => {
    service.get('_session').subscribe();
    const req = httpMock.expectOne('/iris-couch/_session');
    // Absolute path under the REST API root, NOT resolved against the
    // SPA's <base href="/iris-couch/_utils/">.
    expect(req.request.url).toBe('/iris-couch/_session');
    req.flush({});
  });

  it('should pass absolute paths through unchanged', () => {
    service.get('/custom/path').subscribe();
    const req = httpMock.expectOne('/custom/path');
    expect(req.request.url).toBe('/custom/path');
    req.flush({});
  });
});
