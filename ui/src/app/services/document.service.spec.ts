import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { DocumentService, AllDocsResponse, GetDocumentOptions } from './document.service';

describe('DocumentService', () => {
  let service: DocumentService;
  let httpMock: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [
        provideHttpClient(),
        provideHttpClientTesting(),
      ],
    });
    service = TestBed.inject(DocumentService);
    httpMock = TestBed.inject(HttpTestingController);
  });

  afterEach(() => {
    httpMock.verify();
  });

  it('should be created', () => {
    expect(service).toBeTruthy();
  });

  describe('listDocuments', () => {
    const mockResponse: AllDocsResponse = {
      total_rows: 100,
      offset: 0,
      rows: [
        { id: 'doc1', key: 'doc1', value: { rev: '1-abc123' } },
        { id: 'doc2', key: 'doc2', value: { rev: '1-def456' } },
      ],
    };

    it('should GET /{db}/_all_docs with no options', () => {
      service.listDocuments('mydb').subscribe((res) => {
        expect(res.total_rows).toBe(100);
        expect(res.rows.length).toBe(2);
      });
      const req = httpMock.expectOne('mydb/_all_docs');
      expect(req.request.method).toBe('GET');
      req.flush(mockResponse);
    });

    it('should include limit parameter', () => {
      service.listDocuments('mydb', { limit: 25 }).subscribe();
      const req = httpMock.expectOne('mydb/_all_docs?limit=25');
      expect(req.request.method).toBe('GET');
      req.flush(mockResponse);
    });

    it('should include startkey as JSON-encoded string', () => {
      service.listDocuments('mydb', { startkey: 'doc1' }).subscribe();
      const req = httpMock.expectOne((r) =>
        r.url.includes('mydb/_all_docs') && r.url.includes('startkey=%22doc1%22')
      );
      expect(req.request.method).toBe('GET');
      req.flush(mockResponse);
    });

    it('should include endkey as JSON-encoded string', () => {
      service.listDocuments('mydb', { endkey: 'doc2\ufff0' }).subscribe();
      const req = httpMock.expectOne((r) =>
        r.url.includes('mydb/_all_docs') && r.url.includes('endkey=')
      );
      expect(req.request.method).toBe('GET');
      req.flush(mockResponse);
    });

    it('should include include_docs parameter', () => {
      service.listDocuments('mydb', { include_docs: false }).subscribe();
      const req = httpMock.expectOne('mydb/_all_docs?include_docs=false');
      expect(req.request.method).toBe('GET');
      req.flush(mockResponse);
    });

    it('should include descending parameter', () => {
      service.listDocuments('mydb', { descending: true }).subscribe();
      const req = httpMock.expectOne('mydb/_all_docs?descending=true');
      expect(req.request.method).toBe('GET');
      req.flush(mockResponse);
    });

    it('should combine multiple options', () => {
      service.listDocuments('mydb', {
        limit: 25,
        startkey: 'prefix',
        endkey: 'prefix\ufff0',
        include_docs: false,
      }).subscribe();
      const req = httpMock.expectOne((r) =>
        r.url.includes('mydb/_all_docs') &&
        r.url.includes('limit=25') &&
        r.url.includes('startkey=') &&
        r.url.includes('endkey=') &&
        r.url.includes('include_docs=false')
      );
      expect(req.request.method).toBe('GET');
      req.flush(mockResponse);
    });

    it('should encode database name with special characters', () => {
      service.listDocuments('my/db').subscribe();
      const req = httpMock.expectOne((r) =>
        r.url.startsWith('my%2Fdb/_all_docs')
      );
      expect(req.request.method).toBe('GET');
      req.flush(mockResponse);
    });

    it('should return deleted document rows', () => {
      const deletedResponse: AllDocsResponse = {
        total_rows: 1,
        offset: 0,
        rows: [
          { id: 'deleted-doc', key: 'deleted-doc', value: { rev: '2-xyz', deleted: true } },
        ],
      };
      service.listDocuments('mydb').subscribe((res) => {
        expect(res.rows[0].value.deleted).toBeTrue();
      });
      const req = httpMock.expectOne('mydb/_all_docs');
      req.flush(deletedResponse);
    });
  });

  describe('getDocument', () => {
    const mockDoc = {
      _id: 'doc1',
      _rev: '1-abc123',
      title: 'Test Document',
      count: 42,
    };

    it('should GET /{db}/{docid} with conflicts=true by default', () => {
      service.getDocument('mydb', 'doc1').subscribe((res) => {
        expect(res._id).toBe('doc1');
        expect(res._rev).toBe('1-abc123');
      });
      const req = httpMock.expectOne('mydb/doc1?conflicts=true');
      expect(req.request.method).toBe('GET');
      req.flush(mockDoc);
    });

    it('should include rev parameter when specified', () => {
      service.getDocument('mydb', 'doc1', { rev: '2-def456' }).subscribe();
      const req = httpMock.expectOne('mydb/doc1?conflicts=true&rev=2-def456');
      expect(req.request.method).toBe('GET');
      req.flush(mockDoc);
    });

    it('should encode database name with special characters', () => {
      service.getDocument('my/db', 'doc1').subscribe();
      const req = httpMock.expectOne((r) =>
        r.url.startsWith('my%2Fdb/doc1') && r.url.includes('conflicts=true')
      );
      expect(req.request.method).toBe('GET');
      req.flush(mockDoc);
    });

    it('should encode document id with special characters', () => {
      service.getDocument('mydb', 'my/doc').subscribe();
      const req = httpMock.expectOne((r) =>
        r.url.includes('mydb/my%2Fdoc') && r.url.includes('conflicts=true')
      );
      expect(req.request.method).toBe('GET');
      req.flush(mockDoc);
    });

    it('should return document with _conflicts array', () => {
      const conflictDoc = {
        ...mockDoc,
        _conflicts: ['2-xyz789', '2-abc000'],
      };
      service.getDocument('mydb', 'doc1').subscribe((res) => {
        expect(res._conflicts).toEqual(['2-xyz789', '2-abc000']);
      });
      const req = httpMock.expectOne('mydb/doc1?conflicts=true');
      req.flush(conflictDoc);
    });

    it('should return document with _attachments stubs', () => {
      const attachDoc = {
        ...mockDoc,
        _attachments: {
          'file.txt': {
            content_type: 'text/plain',
            length: 1024,
            digest: 'md5-abc123',
            stub: true,
          },
        },
      };
      service.getDocument('mydb', 'doc1').subscribe((res) => {
        expect(res._attachments['file.txt'].content_type).toBe('text/plain');
        expect(res._attachments['file.txt'].stub).toBeTrue();
      });
      const req = httpMock.expectOne('mydb/doc1?conflicts=true');
      req.flush(attachDoc);
    });

    it('should propagate HTTP errors', () => {
      let errorReceived = false;
      service.getDocument('mydb', 'nonexistent').subscribe({
        error: (err) => {
          errorReceived = true;
          expect(err.status).toBe(404);
        },
      });
      const req = httpMock.expectOne('mydb/nonexistent?conflicts=true');
      req.flush(
        { error: 'not_found', reason: 'missing' },
        { status: 404, statusText: 'Object Not Found' }
      );
      expect(errorReceived).toBeTrue();
    });
  });
});
