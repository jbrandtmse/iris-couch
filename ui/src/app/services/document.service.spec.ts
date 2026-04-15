import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import {
  DocumentService,
  AllDocsResponse,
  GetDocumentOptions,
  encodeDocId,
  designDocId,
} from './document.service';

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

  // Story 11.1 AC #1 / Task 1 -- enumerate design docs via _all_docs prefix trick.
  describe('listDesignDocs', () => {
    const mockResponse: AllDocsResponse = {
      total_rows: 2,
      offset: 0,
      rows: [
        { id: '_design/myapp', key: '_design/myapp', value: { rev: '1-aaa' } },
        { id: '_design/otherapp', key: '_design/otherapp', value: { rev: '1-bbb' } },
      ],
    };

    it('emits startkey="_design/" and endkey="_design0" as JSON-encoded strings', () => {
      service.listDesignDocs('mydb').subscribe((res) => {
        expect(res.rows.length).toBe(2);
        expect(res.rows[0].id).toBe('_design/myapp');
      });
      // startkey JSON-encoded is "_design/" (with literal slash)
      // The URLSearchParams layer percent-encodes the inner `/` and the `"`
      // characters; we assert the presence of both encoded tokens rather
      // than matching the full query string character for character.
      const req = httpMock.expectOne((r) => {
        const url = r.url;
        return (
          url.startsWith('mydb/_all_docs?') &&
          // startkey="_design/"
          url.includes('startkey=%22_design%2F%22') &&
          // endkey="_design0"
          url.includes('endkey=%22_design0%22')
        );
      });
      expect(req.request.method).toBe('GET');
      req.flush(mockResponse);
    });

    it('forwards include_docs and limit options', () => {
      service.listDesignDocs('mydb', { include_docs: true, limit: 10 }).subscribe();
      const req = httpMock.expectOne((r) =>
        r.url.includes('mydb/_all_docs') &&
        r.url.includes('limit=10') &&
        r.url.includes('include_docs=true') &&
        r.url.includes('startkey=%22_design%2F%22') &&
        r.url.includes('endkey=%22_design0%22'),
      );
      expect(req.request.method).toBe('GET');
      req.flush(mockResponse);
    });

    it('returns an empty rows array when the database has no design docs', () => {
      const emptyResponse: AllDocsResponse = { total_rows: 0, offset: 0, rows: [] };
      service.listDesignDocs('mydb').subscribe((res) => {
        expect(res.rows.length).toBe(0);
      });
      const req = httpMock.expectOne((r) => r.url.startsWith('mydb/_all_docs?'));
      req.flush(emptyResponse);
    });

    it('encodes database name with special characters', () => {
      service.listDesignDocs('my/db').subscribe();
      const req = httpMock.expectOne((r) => r.url.startsWith('my%2Fdb/_all_docs?'));
      expect(req.request.method).toBe('GET');
      req.flush(mockResponse);
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

  // Story 11.0 AC #3 / Task 3 -- _design/<name> composite ID encoding.
  describe('encodeDocId', () => {
    it('encodes ordinary doc IDs via encodeURIComponent', () => {
      expect(encodeDocId('doc1')).toBe('doc1');
      expect(encodeDocId('my doc')).toBe('my%20doc');
      expect(encodeDocId('ID/with/slashes')).toBe('ID%2Fwith%2Fslashes');
    });

    it('preserves the literal `/` between `_design/` and the design name', () => {
      expect(encodeDocId('_design/myapp')).toBe('_design/myapp');
    });

    it('encodes the design name portion but keeps the prefix separator literal', () => {
      expect(encodeDocId('_design/my app')).toBe('_design/my%20app');
      expect(encodeDocId('_design/foo&bar')).toBe('_design/foo%26bar');
    });

    it('preserves the literal `/` between `_local/` and the doc name', () => {
      expect(encodeDocId('_local/ckpt-1')).toBe('_local/ckpt-1');
    });
  });

  describe('designDocId', () => {
    it('constructs the composite ID from a bare name', () => {
      expect(designDocId('myapp')).toBe('_design/myapp');
    });
  });

  describe('getDocument with design doc IDs', () => {
    // Story 11.1 AC #2 / Task 2 -- confirm existing getDocument + encodeDocId
    // correctly handles a `_design/<name>` composite without a new method.
    it('getDocument("testdb", "_design/myapp") hits /testdb/_design/myapp', () => {
      service.getDocument('testdb', '_design/myapp').subscribe();
      const req = httpMock.expectOne(
        (r) => r.url.startsWith('testdb/_design/myapp?') && !r.url.includes('%2F'),
      );
      expect(req.request.method).toBe('GET');
      req.flush({ _id: '_design/myapp', _rev: '1-abc' });
    });

    it('sends a request to `/{db}/_design/{name}` with literal `/` (not %2F)', () => {
      service.getDocument('testdb', '_design/ddoc-a').subscribe();
      // HttpTestingController matches URLs against the path portion passed to
      // HttpClient.get() — here `testdb/_design/ddoc-a?conflicts=true`. We
      // check that the url does NOT contain `%2F` (which would indicate the
      // `/` inside `_design/` was percent-encoded) and that the path shape
      // is the expected literal form.
      const req = httpMock.expectOne(
        (r) => r.url.includes('testdb/_design/ddoc-a') && !r.url.includes('%2F'),
      );
      expect(req.request.method).toBe('GET');
      expect(req.request.urlWithParams).toContain('conflicts=true');
      req.flush({ _id: '_design/ddoc-a', _rev: '1-abc' });
    });
  });
});
