import { ComponentFixture, TestBed } from '@angular/core/testing';
import { NoopAnimationsModule } from '@angular/platform-browser/animations';
import { HttpClientTestingModule, HttpTestingController } from '@angular/common/http/testing';
import { provideRouter, Router, ActivatedRoute, convertToParamMap } from '@angular/router';
import { of } from 'rxjs';
import { RevisionsViewComponent } from './revisions-view.component';
import { expectNoAxeViolations } from '../../couch-ui/test-utils';

/** Minimal route-stub so we can stand up the component without the router. */
function stubRoute(
  dbname: string,
  docid: string,
  rev?: string,
): Partial<ActivatedRoute> {
  return {
    paramMap: of(convertToParamMap({ dbname, docid })),
    queryParamMap: of(convertToParamMap(rev ? { rev } : {})),
    snapshot: {
      queryParamMap: convertToParamMap(rev ? { rev } : {}),
      paramMap: convertToParamMap({ dbname, docid }),
    } as any,
  };
}

describe('RevisionsViewComponent', () => {
  let fixture: ComponentFixture<RevisionsViewComponent>;
  let component: RevisionsViewComponent;
  let http: HttpTestingController;
  let router: Router;
  let navigateSpy: jasmine.Spy;

  async function setup(dbname: string, docid: string, rev?: string) {
    await TestBed.configureTestingModule({
      imports: [RevisionsViewComponent, HttpClientTestingModule, NoopAnimationsModule],
      providers: [
        provideRouter([]),
        { provide: ActivatedRoute, useValue: stubRoute(dbname, docid, rev) },
      ],
    }).compileComponents();
    http = TestBed.inject(HttpTestingController);
    router = TestBed.inject(Router);
    navigateSpy = spyOn(router, 'navigate').and.returnValue(Promise.resolve(true));
    fixture = TestBed.createComponent(RevisionsViewComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  }

  afterEach(() => {
    if (http) http.verify();
  });

  function flushHead(body: any) {
    const req = http.expectOne((r) =>
      r.url.includes('revs_info=true&conflicts=true&deleted_conflicts=true'),
    );
    req.flush(body);
  }

  function flushBody(rev: string, body: any) {
    const req = http.expectOne((r) => r.url.includes(`rev=${rev}&conflicts=true`) || r.url.includes(`conflicts=true&rev=${rev}`));
    req.flush(body);
  }

  it('creates', async () => {
    await setup('mydb', 'doc1');
    expect(component).toBeTruthy();
    // Drain the pending tree fetch so HttpTestingController.verify() passes.
    const req = http.expectOne((r) =>
      r.url.includes('revs_info=true&conflicts=true&deleted_conflicts=true'),
    );
    req.flush({
      _id: 'doc1',
      _rev: '1-a',
      _revs_info: [{ rev: '1-a', status: 'available' }],
      _conflicts: [],
      _deleted_conflicts: [],
    });
    flushBody('1-a', { _id: 'doc1', _rev: '1-a' });
  });

  it('fetches the tree and defaults selection to the winner', async () => {
    await setup('mydb', 'doc1');
    flushHead({
      _id: 'doc1',
      _rev: '2-winner',
      _revs_info: [
        { rev: '2-winner', status: 'available' },
        { rev: '1-root', status: 'available' },
      ],
      _conflicts: [],
      _deleted_conflicts: [],
    });
    // Body fetch for the winner
    flushBody('2-winner', { _id: 'doc1', _rev: '2-winner', foo: 'bar' });
    fixture.detectChanges();
    expect(component.selectedRev).toBe('2-winner');
    expect(component.tree?.winnerRev).toBe('2-winner');
    expect(component.selectedBody).toEqual({ _id: 'doc1', _rev: '2-winner', foo: 'bar' });
  });

  it('honors ?rev= query param when loading', async () => {
    await setup('mydb', 'doc1', '1-root');
    flushHead({
      _id: 'doc1',
      _rev: '2-winner',
      _revs_info: [
        { rev: '2-winner', status: 'available' },
        { rev: '1-root', status: 'available' },
      ],
      _conflicts: [],
      _deleted_conflicts: [],
    });
    flushBody('1-root', { _id: 'doc1', _rev: '1-root', v: 0 });
    fixture.detectChanges();
    expect(component.selectedRev).toBe('1-root');
    expect(component.selectedBody?.v).toBe(0);
  });

  it('updates URL + fetches body on node click', async () => {
    await setup('mydb', 'doc1');
    flushHead({
      _id: 'doc1',
      _rev: '2-winner',
      _revs_info: [
        { rev: '2-winner', status: 'available' },
        { rev: '1-root', status: 'available' },
      ],
      _conflicts: [],
      _deleted_conflicts: [],
    });
    flushBody('2-winner', { _id: 'doc1', _rev: '2-winner' });
    // Simulate user clicking an older rev
    component.onNodeSelect('1-root');
    flushBody('1-root', { _id: 'doc1', _rev: '1-root' });
    fixture.detectChanges();
    expect(component.selectedRev).toBe('1-root');
    expect(navigateSpy).toHaveBeenCalled();
    const firstArg = navigateSpy.calls.mostRecent().args[1] as any;
    expect(firstArg.queryParams.rev).toBe('1-root');
    expect(firstArg.replaceUrl).toBe(true);
  });

  it('does not re-fetch when selecting the same node twice', async () => {
    await setup('mydb', 'doc1');
    flushHead({
      _id: 'doc1',
      _rev: '2-winner',
      _revs_info: [
        { rev: '2-winner', status: 'available' },
        { rev: '1-root', status: 'available' },
      ],
      _conflicts: [],
      _deleted_conflicts: [],
    });
    flushBody('2-winner', { _id: 'doc1', _rev: '2-winner' });
    // Click the same (already-selected) node — no new HTTP request
    component.onNodeSelect('2-winner');
    const reqs = http.match((r) => r.url.includes('rev=2-winner'));
    expect(reqs.length).toBe(0);
  });

  it('renders FeatureError when tree fetch fails', async () => {
    await setup('mydb', 'doc1');
    const req = http.expectOne((r) =>
      r.url.includes('revs_info=true&conflicts=true&deleted_conflicts=true'),
    );
    req.flush(
      { error: 'unauthorized', reason: 'log in' },
      { status: 401, statusText: 'Unauthorized' },
    );
    fixture.detectChanges();
    expect(component.error).toEqual({ error: 'unauthorized', reason: 'log in' });
    expect(component.tree).toBeNull();
    const errorEl = fixture.nativeElement.querySelector('.revisions-view__error');
    expect(errorEl).toBeTruthy();
  });

  it('renders body-error when body fetch fails, keeping tree visible', async () => {
    await setup('mydb', 'doc1');
    flushHead({
      _id: 'doc1',
      _rev: '1-a',
      _revs_info: [{ rev: '1-a', status: 'available' }],
      _conflicts: [],
      _deleted_conflicts: [],
    });
    const req = http.expectOne((r) => r.url.includes('rev=1-a'));
    req.flush({ error: 'not_found', reason: 'missing' }, { status: 404, statusText: 'Not Found' });
    fixture.detectChanges();
    expect(component.bodyError?.error).toBe('not_found');
    expect(component.tree).toBeTruthy();
    const bodyErrorEl = fixture.nativeElement.querySelector('.revisions-view__body-error');
    expect(bodyErrorEl).toBeTruthy();
  });

  it('navigates back to the document via backToDocument()', async () => {
    await setup('mydb', 'doc1');
    flushHead({
      _id: 'doc1',
      _rev: '1-a',
      _revs_info: [{ rev: '1-a', status: 'available' }],
      _conflicts: [],
      _deleted_conflicts: [],
    });
    flushBody('1-a', { _id: 'doc1', _rev: '1-a' });
    component.backToDocument();
    const lastCall = navigateSpy.calls.mostRecent();
    expect(lastCall.args[0]).toEqual(['/db', 'mydb', 'doc', 'doc1']);
  });

  it('splits composite _design/<name> IDs for back navigation', async () => {
    await setup('mydb', '_design/myapp');
    flushHead({
      _id: '_design/myapp',
      _rev: '1-a',
      _revs_info: [{ rev: '1-a', status: 'available' }],
      _conflicts: [],
      _deleted_conflicts: [],
    });
    flushBody('1-a', { _id: '_design/myapp', _rev: '1-a' });
    component.backToDocument();
    const lastCall = navigateSpy.calls.mostRecent();
    // Second segment after 'doc' must preserve the composite ID as two
    // route-segments so docDetailMatcher stitches it back as "_design/myapp"
    expect(lastCall.args[0]).toEqual(['/db', 'mydb', 'doc', '_design', 'myapp']);
  });

  it('Esc key triggers backToDocument', async () => {
    await setup('mydb', 'doc1');
    flushHead({
      _id: 'doc1',
      _rev: '1-a',
      _revs_info: [{ rev: '1-a', status: 'available' }],
      _conflicts: [],
      _deleted_conflicts: [],
    });
    flushBody('1-a', { _id: 'doc1', _rev: '1-a' });
    navigateSpy.calls.reset();
    // Fire an Escape keydown from the document body (not an input)
    const event = new KeyboardEvent('keydown', { key: 'Escape', bubbles: true });
    Object.defineProperty(event, 'target', { value: document.body });
    component.onEscape(event);
    expect(navigateSpy).toHaveBeenCalled();
  });

  it('Esc is ignored when a CDK overlay pane is open (popover handles Esc first)', async () => {
    await setup('mydb', 'doc1');
    flushHead({
      _id: 'doc1',
      _rev: '1-a',
      _revs_info: [{ rev: '1-a', status: 'available' }],
      _conflicts: [],
      _deleted_conflicts: [],
    });
    flushBody('1-a', { _id: 'doc1', _rev: '1-a' });
    navigateSpy.calls.reset();
    // Simulate an open CDK overlay pane in the DOM.
    const pane = document.createElement('div');
    pane.className = 'cdk-overlay-pane';
    document.body.appendChild(pane);
    try {
      const event = new KeyboardEvent('keydown', { key: 'Escape', bubbles: true });
      Object.defineProperty(event, 'target', { value: document.body });
      component.onEscape(event);
      expect(navigateSpy).not.toHaveBeenCalled();
    } finally {
      pane.remove();
    }
  });

  it('Esc is ignored when focus is in a textarea/input (e.g., a dialog)', async () => {
    await setup('mydb', 'doc1');
    flushHead({
      _id: 'doc1',
      _rev: '1-a',
      _revs_info: [{ rev: '1-a', status: 'available' }],
      _conflicts: [],
      _deleted_conflicts: [],
    });
    flushBody('1-a', { _id: 'doc1', _rev: '1-a' });
    navigateSpy.calls.reset();
    const input = document.createElement('input');
    const event = new KeyboardEvent('keydown', { key: 'Escape', bubbles: true });
    Object.defineProperty(event, 'target', { value: input });
    component.onEscape(event);
    expect(navigateSpy).not.toHaveBeenCalled();
  });

  it('ngOnDestroy cancels in-flight requests (no leaked callbacks)', async () => {
    await setup('mydb', 'doc1');
    flushHead({
      _id: 'doc1',
      _rev: '1-a',
      _revs_info: [{ rev: '1-a', status: 'available' }],
      _conflicts: [],
      _deleted_conflicts: [],
    });
    flushBody('1-a', { _id: 'doc1', _rev: '1-a' });
    // Start a selection change that re-fetches body
    component.onNodeSelect('1-a-other');
    // Destroy the component — in-flight body request must be cancelled
    fixture.destroy();
    // Any outstanding requests should already have been cancelled so
    // verify() does not see them as "open".
    const pending = http.match(() => true);
    pending.forEach((r) => {
      // A cancelled request should not still be open to flush.
      expect(r.cancelled).toBeTruthy();
    });
  });

  it('is axe-clean in the loaded state', async () => {
    await setup('mydb', 'doc1');
    flushHead({
      _id: 'doc1',
      _rev: '2-winner',
      _revs_info: [
        { rev: '2-winner', status: 'available' },
        { rev: '1-root', status: 'available' },
      ],
      _conflicts: [],
      _deleted_conflicts: [],
    });
    flushBody('2-winner', { _id: 'doc1', _rev: '2-winner' });
    fixture.detectChanges();
    await expectNoAxeViolations(fixture.nativeElement);
  });

  it('is axe-clean in the error state', async () => {
    await setup('mydb', 'doc1');
    const req = http.expectOne((r) =>
      r.url.includes('revs_info=true&conflicts=true&deleted_conflicts=true'),
    );
    req.flush({ error: 'server_error', reason: 'x' }, { status: 500, statusText: 'err' });
    fixture.detectChanges();
    await expectNoAxeViolations(fixture.nativeElement);
  });
});
