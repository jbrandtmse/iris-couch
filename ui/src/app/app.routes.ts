import { Routes, UrlMatcher, UrlSegment, UrlSegmentGroup, Route } from '@angular/router';
import { authGuard } from './guards/auth.guard';
import { unsavedChangesGuard } from './services/unsaved-changes.guard';
import { LoginComponent } from './features/auth/login.component';
import { DatabaseListComponent } from './features/databases/database-list.component';
import { DatabaseDetailComponent } from './features/database/database-detail.component';
import { DocumentDetailComponent } from './features/document/document-detail.component';
import { DesignDocListComponent } from './features/design-docs/design-doc-list.component';
import { DesignDocDetailComponent } from './features/design-docs/design-doc-detail.component';
import { SecurityViewComponent } from './features/security/security-view.component';
import { RevisionsViewComponent } from './features/revisions/revisions-view.component';

/**
 * Custom URL matcher for /db/:dbname/doc/:docid that supports `_design/<name>`
 * composite document IDs.
 *
 * Angular's default matcher treats `/` as a segment separator, so the URL
 * `/db/testdb/doc/_design/myapp` would parse `docid = "_design"` and the
 * trailing `myapp` would fall off. We manually consume all remaining segments
 * after `doc/` and rejoin them so `docid` becomes `_design/myapp` (un-escaped,
 * matching what CouchDB returns in `row.id`).
 *
 * Matches: /db/:dbname/doc/<anything-including-slashes>
 * Emits:   { dbname, docid } where docid may contain `/`.
 *
 * See Story 11.0 AC #3 / Task 3.
 */
export const docDetailMatcher: UrlMatcher = (
  segments: UrlSegment[],
  _group: UrlSegmentGroup,
  _route: Route,
) => {
  // Expect: db, :dbname, doc, :docid[+]
  if (segments.length < 4) return null;
  if (segments[0].path !== 'db' || segments[2].path !== 'doc') return null;

  const dbname = segments[1];
  // Join segments 3..end with '/' to reconstruct `_design/<name>` composite IDs.
  const docidRaw = segments.slice(3).map((s) => s.path).join('/');
  const docid = new UrlSegment(docidRaw, {});

  return {
    consumed: segments,
    posParams: {
      dbname,
      docid,
    },
  };
};

/**
 * Custom URL matcher for /db/:dbname/design/:ddocid that consumes all
 * remaining segments after `design/` as the design-doc short name.
 *
 * CouchDB forbids `/` in design-doc short names, so in practice this matcher
 * only ever sees a single trailing segment. We still use a multi-segment
 * matcher here for symmetry with `docDetailMatcher` and to remain robust
 * if the wire format ever changes — the component normalizes whatever it
 * receives into `_design/<name>`.
 *
 * Matches: /db/:dbname/design/<name-segments>
 * Emits:   { dbname, ddocid } where ddocid is the short name (no `_design/`
 *          prefix). Component prepends the prefix before calling the API.
 *
 * Explicitly returns null when `segments.length < 4` so that the bare
 * `/db/:dbname/design` path (exactly 3 segments) falls through to the
 * DesignDocListComponent route below. See Story 11.1 AC #3 / Task 5.
 */
export const designDocDetailMatcher: UrlMatcher = (
  segments: UrlSegment[],
  _group: UrlSegmentGroup,
  _route: Route,
) => {
  // Expect: db, :dbname, design, :ddocid[+]
  if (segments.length < 4) return null;
  if (segments[0].path !== 'db' || segments[2].path !== 'design') return null;

  const dbname = segments[1];
  const ddocRaw = segments.slice(3).map((s) => s.path).join('/');
  const ddocid = new UrlSegment(ddocRaw, {});

  return {
    consumed: segments,
    posParams: {
      dbname,
      ddocid,
    },
  };
};

/**
 * Custom URL matcher for `/db/:dbname/doc/<docid+>/revisions`.
 *
 * MUST be registered BEFORE `docDetailMatcher` since that matcher consumes
 * all trailing segments after `/doc/` — otherwise a URL like
 * `/db/foo/doc/bar/revisions` would be swallowed as a doc with id
 * `bar/revisions`.
 *
 * Supports composite `_design/<name>` doc IDs the same way
 * `docDetailMatcher` does: all segments between `doc` and the final
 * `revisions` segment are joined with `/` to form the docid parameter.
 *
 * See Story 11.4 Task 5 and `.claude/rules/angular-patterns.md`
 * (Design-Doc ID Encoding).
 */
export const revisionsMatcher: UrlMatcher = (
  segments: UrlSegment[],
  _group: UrlSegmentGroup,
  _route: Route,
) => {
  // Expect: db, :dbname, doc, :docid[+], revisions
  if (segments.length < 5) return null;
  if (segments[0].path !== 'db' || segments[2].path !== 'doc') return null;
  if (segments[segments.length - 1].path !== 'revisions') return null;

  const dbname = segments[1];
  const docidRaw = segments.slice(3, segments.length - 1).map((s) => s.path).join('/');
  const docid = new UrlSegment(docidRaw, {});

  return {
    consumed: segments,
    posParams: {
      dbname,
      docid,
    },
  };
};

export const routes: Routes = [
  { path: 'login', component: LoginComponent },
  { path: 'databases', component: DatabaseListComponent, canActivate: [authGuard] },
  { path: 'db/:dbname', component: DatabaseDetailComponent, canActivate: [authGuard] },
  { path: 'db/:dbname/design', component: DesignDocListComponent, canActivate: [authGuard] },
  {
    matcher: designDocDetailMatcher,
    component: DesignDocDetailComponent,
    canActivate: [authGuard],
    canDeactivate: [unsavedChangesGuard],
  },
  {
    path: 'db/:dbname/security',
    component: SecurityViewComponent,
    canActivate: [authGuard],
    canDeactivate: [unsavedChangesGuard],
  },
  // NOTE: revisionsMatcher MUST come BEFORE docDetailMatcher — otherwise the
  // trailing "revisions" segment would be swallowed as part of the docid.
  { matcher: revisionsMatcher, component: RevisionsViewComponent, canActivate: [authGuard] },
  { matcher: docDetailMatcher, component: DocumentDetailComponent, canActivate: [authGuard] },
  { path: '', redirectTo: 'databases', pathMatch: 'full' },
  { path: '**', redirectTo: 'databases' },
];
