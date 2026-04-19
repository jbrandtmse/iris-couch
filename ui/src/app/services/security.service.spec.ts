import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import {
  SecurityService,
  DEFAULT_SECURITY,
  normalizeSecurity,
} from './security.service';

describe('SecurityService', () => {
  let service: SecurityService;
  let httpMock: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [provideHttpClient(), provideHttpClientTesting()],
    });
    service = TestBed.inject(SecurityService);
    httpMock = TestBed.inject(HttpTestingController);
  });

  afterEach(() => {
    httpMock.verify();
  });

  it('is created', () => {
    expect(service).toBeTruthy();
  });

  describe('getSecurity URL', () => {
    it('GETs /{db}/_security with the database name URI-encoded', () => {
      service.getSecurity('my db').subscribe();
      const req = httpMock.expectOne('/iris-couch/my%20db/_security');
      expect(req.request.method).toBe('GET');
      req.flush(DEFAULT_SECURITY);
    });

    it('passes through simple db names without extra encoding', () => {
      service.getSecurity('testdb').subscribe();
      const req = httpMock.expectOne('/iris-couch/testdb/_security');
      expect(req.request.method).toBe('GET');
      req.flush(DEFAULT_SECURITY);
    });
  });

  describe('getSecurity normalization (AC #2)', () => {
    it('returns the populated response verbatim when fully formed', (done) => {
      const populated = {
        admins: { names: ['alice'], roles: ['admin'] },
        members: { names: ['bob'], roles: ['reader'] },
      };
      service.getSecurity('testdb').subscribe((sec) => {
        expect(sec).toEqual(populated);
        done();
      });
      httpMock.expectOne('/iris-couch/testdb/_security').flush(populated);
    });

    it('normalizes an empty object `{}` to the full default shape', (done) => {
      service.getSecurity('testdb').subscribe((sec) => {
        expect(sec).toEqual(DEFAULT_SECURITY);
        done();
      });
      httpMock.expectOne('/iris-couch/testdb/_security').flush({});
    });

    it('fills missing admins/members with empty defaults', (done) => {
      service.getSecurity('testdb').subscribe((sec) => {
        expect(sec.admins).toEqual({ names: ['alice'], roles: [] });
        expect(sec.members).toEqual({ names: [], roles: [] });
        done();
      });
      httpMock.expectOne('/iris-couch/testdb/_security').flush({ admins: { names: ['alice'] } });
    });

    it('fills missing nested arrays with empty arrays', (done) => {
      service.getSecurity('testdb').subscribe((sec) => {
        expect(sec.admins.roles).toEqual([]);
        expect(sec.members.names).toEqual([]);
        done();
      });
      httpMock
        .expectOne('/iris-couch/testdb/_security')
        .flush({ admins: { names: ['a'] }, members: { roles: ['r'] } });
    });

    it('propagates HTTP errors to the subscriber', (done) => {
      service.getSecurity('testdb').subscribe({
        next: () => fail('expected error'),
        error: (err) => {
          expect(err.status).toBe(500);
          done();
        },
      });
      httpMock
        .expectOne('/iris-couch/testdb/_security')
        .flush(
          { error: 'internal_server_error', reason: 'boom' },
          { status: 500, statusText: 'Internal Server Error' },
        );
    });
  });

  // Story 11.3 Task 5 -- write method.
  describe('setSecurity', () => {
    const sec = {
      admins: { names: ['alice'], roles: ['admin'] },
      members: { names: ['bob'], roles: [] },
    };

    it('PUTs /{db}/_security with the doc as the body', () => {
      service.setSecurity('testdb', sec).subscribe((res) => {
        expect(res.ok).toBeTrue();
      });
      const req = httpMock.expectOne('/iris-couch/testdb/_security');
      expect(req.request.method).toBe('PUT');
      expect(req.request.body).toEqual(sec);
      req.flush({ ok: true });
    });

    it('encodes db name with special characters', () => {
      service.setSecurity('my db', sec).subscribe();
      const req = httpMock.expectOne('/iris-couch/my%20db/_security');
      expect(req.request.method).toBe('PUT');
      req.flush({ ok: true });
    });

    it('propagates 401 unauthorized', (done) => {
      service.setSecurity('testdb', sec).subscribe({
        next: () => fail('expected error'),
        error: (err) => {
          expect(err.status).toBe(401);
          done();
        },
      });
      httpMock
        .expectOne('/iris-couch/testdb/_security')
        .flush(
          { error: 'unauthorized', reason: 'You are not a server admin.' },
          { status: 401, statusText: 'Unauthorized' },
        );
    });

    it('propagates 500 server error', (done) => {
      service.setSecurity('testdb', sec).subscribe({
        next: () => fail('expected error'),
        error: (err) => {
          expect(err.status).toBe(500);
          done();
        },
      });
      httpMock
        .expectOne('/iris-couch/testdb/_security')
        .flush(
          { error: 'internal_server_error', reason: 'boom' },
          { status: 500, statusText: 'Internal Server Error' },
        );
    });
  });

  describe('normalizeSecurity pure function', () => {
    it('handles null/undefined input', () => {
      expect(normalizeSecurity(null)).toEqual(DEFAULT_SECURITY);
      expect(normalizeSecurity(undefined)).toEqual(DEFAULT_SECURITY);
    });

    it('handles non-object input defensively', () => {
      expect(normalizeSecurity('string')).toEqual(DEFAULT_SECURITY);
      expect(normalizeSecurity(42)).toEqual(DEFAULT_SECURITY);
    });

    it('coerces non-array names/roles to empty arrays', () => {
      const result = normalizeSecurity({
        admins: { names: 'not-array', roles: null },
        members: { names: undefined, roles: 5 },
      });
      expect(result).toEqual(DEFAULT_SECURITY);
    });

    it('preserves valid role-list content', () => {
      const result = normalizeSecurity({
        admins: { names: ['a1'], roles: ['r1'] },
        members: { names: ['m1'], roles: ['r2'] },
      });
      expect(result.admins.names).toEqual(['a1']);
      expect(result.members.roles).toEqual(['r2']);
    });
  });
});
