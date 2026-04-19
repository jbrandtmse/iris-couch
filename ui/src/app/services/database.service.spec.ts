import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { DatabaseService, DbInfo, DatabaseEntry } from './database.service';

describe('DatabaseService', () => {
  let service: DatabaseService;
  let httpMock: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [
        provideHttpClient(),
        provideHttpClientTesting(),
      ],
    });
    service = TestBed.inject(DatabaseService);
    httpMock = TestBed.inject(HttpTestingController);
  });

  afterEach(() => {
    httpMock.verify();
  });

  it('should be created', () => {
    expect(service).toBeTruthy();
  });

  describe('listDatabases', () => {
    it('should GET /_all_dbs', () => {
      const mockDbs = ['mydb', 'testdb'];
      service.listDatabases().subscribe((dbs) => {
        expect(dbs).toEqual(mockDbs);
      });
      const req = httpMock.expectOne('/iris-couch/_all_dbs');
      expect(req.request.method).toBe('GET');
      req.flush(mockDbs);
    });
  });

  describe('getDatabaseInfo', () => {
    it('should GET /{name}', () => {
      const mockInfo: DbInfo = {
        db_name: 'mydb',
        doc_count: 42,
        update_seq: '100-abc',
        sizes: { file: 1024, external: 512, active: 768 },
      };
      service.getDatabaseInfo('mydb').subscribe((info) => {
        expect(info.db_name).toBe('mydb');
        expect(info.doc_count).toBe(42);
      });
      const req = httpMock.expectOne('/iris-couch/mydb');
      expect(req.request.method).toBe('GET');
      req.flush(mockInfo);
    });

    it('should encode special characters in name', () => {
      service.getDatabaseInfo('my/db').subscribe();
      const req = httpMock.expectOne('/iris-couch/my%2Fdb');
      expect(req.request.method).toBe('GET');
      req.flush({});
    });
  });

  describe('createDatabase', () => {
    it('should PUT /{name}', () => {
      service.createDatabase('newdb').subscribe((res) => {
        expect(res.ok).toBeTrue();
      });
      const req = httpMock.expectOne('/iris-couch/newdb');
      expect(req.request.method).toBe('PUT');
      req.flush({ ok: true });
    });
  });

  describe('deleteDatabase', () => {
    it('should DELETE /{name}', () => {
      service.deleteDatabase('olddb').subscribe((res) => {
        expect(res.ok).toBeTrue();
      });
      const req = httpMock.expectOne('/iris-couch/olddb');
      expect(req.request.method).toBe('DELETE');
      req.flush({ ok: true });
    });
  });

  describe('listAllWithInfo', () => {
    it('should fetch all dbs then info for each', () => {
      let result: DatabaseEntry[] = [];
      service.listAllWithInfo().subscribe((entries) => {
        result = entries;
      });

      // First: _all_dbs
      const allDbsReq = httpMock.expectOne('/iris-couch/_all_dbs');
      allDbsReq.flush(['db1', 'db2']);

      // Then: info for each
      const db1Req = httpMock.expectOne('/iris-couch/db1');
      db1Req.flush({
        db_name: 'db1',
        doc_count: 10,
        update_seq: '50-xyz',
        sizes: { file: 2048, external: 1024, active: 1536 },
      });

      const db2Req = httpMock.expectOne('/iris-couch/db2');
      db2Req.flush({
        db_name: 'db2',
        doc_count: 5,
        update_seq: '25-abc',
        sizes: { file: 512, external: 256, active: 384 },
      });

      expect(result.length).toBe(2);
      expect(result[0].name).toBe('db1');
      expect(result[0].docCount).toBe(10);
      expect(result[0].updateSeq).toBe('50-xyz');
      expect(result[0].diskSize).toBe(2048);
      expect(result[1].name).toBe('db2');
    });

    it('should return empty array when no databases exist', () => {
      let result: DatabaseEntry[] | undefined;
      service.listAllWithInfo().subscribe((entries) => {
        result = entries;
      });
      const req = httpMock.expectOne('/iris-couch/_all_dbs');
      req.flush([]);
      expect(result).toEqual([]);
    });
  });
});
