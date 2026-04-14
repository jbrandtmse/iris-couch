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
    const req = httpMock.expectOne('_all_dbs');
    expect(req.request.method).toBe('GET');
    req.flush({ ok: true });
  });

  it('should send POST requests with body', () => {
    const body = { name: 'admin', password: 'pass' };
    service.post<{ ok: boolean }>('_session', body).subscribe((res) => {
      expect(res.ok).toBeTrue();
    });
    const req = httpMock.expectOne('_session');
    expect(req.request.method).toBe('POST');
    expect(req.request.body).toEqual(body);
    req.flush({ ok: true });
  });

  it('should send PUT requests with body', () => {
    const body = { _id: 'doc1', value: 42 };
    service.put<{ ok: boolean }>('mydb/doc1', body).subscribe();
    const req = httpMock.expectOne('mydb/doc1');
    expect(req.request.method).toBe('PUT');
    expect(req.request.body).toEqual(body);
    req.flush({ ok: true });
  });

  it('should send DELETE requests', () => {
    service.delete<{ ok: boolean }>('_session').subscribe();
    const req = httpMock.expectOne('_session');
    expect(req.request.method).toBe('DELETE');
    req.flush({ ok: true });
  });

  it('should use relative paths (base URL is /)', () => {
    service.get('_session').subscribe();
    const req = httpMock.expectOne('_session');
    // URL should not have an absolute prefix like http://
    expect(req.request.url).toBe('_session');
    req.flush({});
  });
});
