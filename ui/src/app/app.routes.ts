import { Routes, UrlMatcher, UrlSegment, UrlSegmentGroup, Route } from '@angular/router';
import { authGuard } from './guards/auth.guard';
import { LoginComponent } from './features/auth/login.component';
import { DatabaseListComponent } from './features/databases/database-list.component';
import { DatabaseDetailComponent } from './features/database/database-detail.component';
import { DocumentDetailComponent } from './features/document/document-detail.component';

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

export const routes: Routes = [
  { path: 'login', component: LoginComponent },
  { path: 'databases', component: DatabaseListComponent, canActivate: [authGuard] },
  { path: 'db/:dbname', component: DatabaseDetailComponent, canActivate: [authGuard] },
  { matcher: docDetailMatcher, component: DocumentDetailComponent, canActivate: [authGuard] },
  { path: '', redirectTo: 'databases', pathMatch: 'full' },
  { path: '**', redirectTo: 'databases' },
];
