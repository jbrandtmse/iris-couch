import { TestBed, ComponentFixture } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { provideRouter, ActivatedRoute } from '@angular/router';
import { Clipboard } from '@angular/cdk/clipboard';
import { LiveAnnouncer } from '@angular/cdk/a11y';
import { BehaviorSubject } from 'rxjs';
import { DocumentDetailComponent } from './document-detail.component';
import { expectNoAxeViolations } from '../../couch-ui/test-utils';

describe('DocumentDetailComponent', () => {
  let fixture: ComponentFixture<DocumentDetailComponent>;
  let component: DocumentDetailComponent;
  let httpMock: HttpTestingController;
  let paramMapSubject: BehaviorSubject<any>;

  const mockDoc = {
    _id: 'test-doc-001',
    _rev: '3-abc123def456',
    title: 'Test Document',
    count: 42,
    active: true,
  };

  function createParamMap(params: Record<string, string>): any {
    return {
      get: (key: string) => params[key] ?? null,
      has: (key: string) => key in params,
      getAll: (key: string) => params[key] ? [params[key]] : [],
      keys: Object.keys(params),
    };
  }

  beforeEach(async () => {
    paramMapSubject = new BehaviorSubject(createParamMap({ dbname: 'testdb', docid: 'test-doc-001' }));

    const clipboardSpy = jasmine.createSpyObj('Clipboard', ['copy']);
    clipboardSpy.copy.and.returnValue(true);
    const announcerSpy = jasmine.createSpyObj('LiveAnnouncer', ['announce']);
    announcerSpy.announce.and.returnValue(Promise.resolve());

    await TestBed.configureTestingModule({
      imports: [DocumentDetailComponent],
      providers: [
        provideHttpClient(),
        provideHttpClientTesting(),
        provideRouter([]),
        {
          provide: ActivatedRoute,
          useValue: { paramMap: paramMapSubject.asObservable() },
        },
        { provide: Clipboard, useValue: clipboardSpy },
        { provide: LiveAnnouncer, useValue: announcerSpy },
      ],
    }).compileComponents();

    httpMock = TestBed.inject(HttpTestingController);
    fixture = TestBed.createComponent(DocumentDetailComponent);
    component = fixture.componentInstance;
  });

  afterEach(() => {
    httpMock.verify();
  });

  /** Helper: trigger change detection, then flush the initial GET request. */
  function initAndFlush(doc: any = mockDoc): void {
    fixture.detectChanges(); // triggers ngOnInit -> loadDocument
    const req = httpMock.expectOne((r) =>
      r.url.includes('testdb/test-doc-001') && r.url.includes('conflicts=true')
    );
    req.flush(doc);
    fixture.detectChanges();
  }

  /** Helper: trigger change detection, then fail the initial GET request. */
  function initAndFail(status: number, body: any): void {
    fixture.detectChanges();
    const req = httpMock.expectOne((r) =>
      r.url.includes('testdb/test-doc-001') && r.url.includes('conflicts=true')
    );
    req.flush(body, { status, statusText: 'Error' });
    fixture.detectChanges();
  }

  // --- AC #1: Header zone ---

  it('should fetch the document on init', () => {
    fixture.detectChanges();
    const req = httpMock.expectOne((r) =>
      r.url.includes('testdb/test-doc-001') && r.url.includes('conflicts=true')
    );
    expect(req.request.method).toBe('GET');
    req.flush(mockDoc);
  });

  it('should display _id in large monospace', () => {
    initAndFlush();
    const idEl = fixture.nativeElement.querySelector('.doc-detail__id');
    expect(idEl).toBeTruthy();
    expect(idEl.textContent).toContain('test-doc-001');
  });

  it('should display full _rev in monospace', () => {
    initAndFlush();
    const revEl = fixture.nativeElement.querySelector('.doc-detail__rev');
    expect(revEl).toBeTruthy();
    expect(revEl.textContent).toContain('3-abc123def456');
  });

  it('should render CopyButton for _id and _rev', () => {
    initAndFlush();
    const copyButtons = fixture.nativeElement.querySelectorAll('app-copy-button');
    // At least 2: _id + _rev (JsonDisplay also has one)
    expect(copyButtons.length).toBeGreaterThanOrEqual(2);
  });

  it('should render breadcrumbs with Databases > dbname > docid', () => {
    initAndFlush();
    const breadcrumb = fixture.nativeElement.querySelector('app-breadcrumb');
    expect(breadcrumb).toBeTruthy();
  });

  it('should render PageHeader with fetchedAt', () => {
    initAndFlush();
    const header = fixture.nativeElement.querySelector('app-page-header');
    expect(header).toBeTruthy();
  });

  // --- AC #2: Status badges ---

  it('should show [deleted] badge for deleted documents', () => {
    initAndFlush({ ...mockDoc, _deleted: true });
    const badges = fixture.nativeElement.querySelectorAll('app-badge');
    const deletedBadge = Array.from(badges).find(
      (b) => (b as HTMLElement).textContent?.trim() === 'deleted'
    );
    expect(deletedBadge).toBeTruthy();
  });

  it('should show [has conflicts: N] badge when _conflicts exists', () => {
    initAndFlush({
      ...mockDoc,
      _conflicts: ['2-xyz789', '2-abc000'],
    });
    const badges = fixture.nativeElement.querySelectorAll('app-badge');
    const conflictBadge = Array.from(badges).find(
      (b) => (b as HTMLElement).textContent?.includes('conflicts')
    );
    expect(conflictBadge).toBeTruthy();
    expect((conflictBadge as HTMLElement).textContent).toContain('2');
  });

  it('should show [has attachments: N] badge when _attachments exists', () => {
    initAndFlush({
      ...mockDoc,
      _attachments: {
        'file.txt': { content_type: 'text/plain', length: 1024, digest: 'md5-abc', stub: true },
      },
    });
    const badges = fixture.nativeElement.querySelectorAll('app-badge');
    const attachBadge = Array.from(badges).find(
      (b) => (b as HTMLElement).textContent?.includes('attachment')
    );
    expect(attachBadge).toBeTruthy();
    expect((attachBadge as HTMLElement).textContent).toContain('1');
  });

  it('should not show badges for normal documents', () => {
    initAndFlush();
    const badges = fixture.nativeElement.querySelectorAll('app-badge');
    expect(badges.length).toBe(0);
  });

  // --- AC #3: Body zone with JsonDisplay ---

  it('should render JsonDisplay with document body', () => {
    initAndFlush();
    const jsonDisplay = fixture.nativeElement.querySelector('app-json-display');
    expect(jsonDisplay).toBeTruthy();
  });

  // --- AC #4: Attachment zone ---

  it('should render attachment list when _attachments exists', () => {
    initAndFlush({
      ...mockDoc,
      _attachments: {
        'report.pdf': {
          content_type: 'application/pdf',
          length: 204800,
          digest: 'md5-abc123def456',
          stub: true,
        },
      },
    });
    const attachZone = fixture.nativeElement.querySelector('.doc-detail__attachments');
    expect(attachZone).toBeTruthy();
    expect(attachZone.textContent).toContain('report.pdf');
    expect(attachZone.textContent).toContain('application/pdf');
  });

  it('should show attachment download links', () => {
    initAndFlush({
      ...mockDoc,
      _attachments: {
        'file.txt': {
          content_type: 'text/plain',
          length: 512,
          digest: 'md5-abc',
          stub: true,
        },
      },
    });
    const downloadLink = fixture.nativeElement.querySelector('.doc-detail__attachment-download');
    expect(downloadLink).toBeTruthy();
    expect(downloadLink.getAttribute('href')).toContain('/testdb/test-doc-001/file.txt');
  });

  it('should truncate attachment digest to 12 characters', () => {
    initAndFlush({
      ...mockDoc,
      _attachments: {
        'file.txt': {
          content_type: 'text/plain',
          length: 512,
          digest: 'md5-abc123def456789',
          stub: true,
        },
      },
    });
    const digestEl = fixture.nativeElement.querySelector('.doc-detail__attachment-digest');
    expect(digestEl).toBeTruthy();
    expect(digestEl.textContent?.trim().length).toBeLessThanOrEqual(12);
  });

  // --- AC #5: Conflicts zone ---

  it('should show conflict revisions when badge is clicked', () => {
    initAndFlush({
      ...mockDoc,
      _conflicts: ['2-xyz789'],
    });
    const conflictToggle = fixture.nativeElement.querySelector('.doc-detail__conflict-toggle');
    expect(conflictToggle).toBeTruthy();
    conflictToggle.click();
    fixture.detectChanges();
    const conflictList = fixture.nativeElement.querySelector('.doc-detail__conflicts');
    expect(conflictList).toBeTruthy();
    expect(conflictList.textContent).toContain('2-xyz789');
  });

  it('should fetch and display a conflict revision when clicked', () => {
    const conflictRev = '2-xyz789';
    const conflictDoc = {
      _id: 'test-doc-001',
      _rev: conflictRev,
      title: 'Conflicting Version',
    };
    initAndFlush({
      ...mockDoc,
      _conflicts: [conflictRev],
    });

    // Toggle conflict list open
    const conflictToggle = fixture.nativeElement.querySelector('.doc-detail__conflict-toggle');
    conflictToggle.click();
    fixture.detectChanges();

    // Click on the conflict rev button
    const conflictRevBtn = fixture.nativeElement.querySelector('.doc-detail__conflict-rev');
    expect(conflictRevBtn).toBeTruthy();
    conflictRevBtn.click();

    // Flush the conflict rev fetch request
    const req = httpMock.expectOne((r) =>
      r.url.includes('testdb/test-doc-001') && r.url.includes('rev=2-xyz789')
    );
    expect(req.request.method).toBe('GET');
    req.flush(conflictDoc);
    fixture.detectChanges();

    // Verify the conflict body is displayed
    const conflictBody = fixture.nativeElement.querySelector('.doc-detail__conflict-body');
    expect(conflictBody).toBeTruthy();
    expect(conflictBody.textContent).toContain(conflictRev);

    // Verify a secondary JsonDisplay is rendered
    const jsonDisplays = fixture.nativeElement.querySelectorAll('app-json-display');
    expect(jsonDisplays.length).toBe(2); // main doc + conflict doc
  });

  // --- AC #7: 404 Error handling ---

  it('should show ErrorDisplay for 404 errors', () => {
    initAndFail(404, { error: 'not_found', reason: 'missing' });
    const errorDisplay = fixture.nativeElement.querySelector('app-error-display');
    expect(errorDisplay).toBeTruthy();
  });

  // --- AC #8: Deep-linkable ---

  it('should read dbname and docid from route params', () => {
    initAndFlush();
    expect(component.dbName).toBe('testdb');
    expect(component.docId).toBe('test-doc-001');
  });

  // --- Refresh ---

  it('should refresh document when refresh is triggered', () => {
    initAndFlush();
    component.onRefresh();
    const req = httpMock.expectOne((r) =>
      r.url.includes('testdb/test-doc-001') && r.url.includes('conflicts=true')
    );
    req.flush(mockDoc);
    fixture.detectChanges();
    expect(component.doc).toBeTruthy();
  });

  // --- Helper methods ---

  it('should format bytes to human-readable form', () => {
    expect(component.formatBytes(0)).toBe('0 B');
    expect(component.formatBytes(512)).toBe('512 B');
    expect(component.formatBytes(1024)).toBe('1 KB');
    expect(component.formatBytes(204800)).toBe('200 KB');
    expect(component.formatBytes(1048576)).toBe('1 MB');
  });

  it('should truncate digest to 12 characters', () => {
    expect(component.truncateDigest('md5-abc123def456789')).toBe('md5-abc123de');
    expect(component.truncateDigest('short')).toBe('short');
  });

  // --- Accessibility ---

  it('should pass axe-core accessibility checks with document loaded', async () => {
    initAndFlush();
    await expectNoAxeViolations(fixture.nativeElement);
  });

  it('should pass axe-core accessibility checks on error state', async () => {
    initAndFail(404, { error: 'not_found', reason: 'missing' });
    await expectNoAxeViolations(fixture.nativeElement);
  });
});
