import { TestBed } from '@angular/core/testing';
import {
  provideHttpClient,
  withInterceptors,
  HttpClient,
  HttpErrorResponse,
} from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { provideRouter, Router } from '@angular/router';
import { authInterceptor } from './auth.interceptor';
import { AuthService } from './auth.service';

describe('authInterceptor', () => {
  let http: HttpClient;
  let httpMock: HttpTestingController;
  let router: Router;
  let auth: AuthService;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [
        provideHttpClient(withInterceptors([authInterceptor])),
        provideHttpClientTesting(),
        provideRouter([]),
      ],
    });
    http = TestBed.inject(HttpClient);
    httpMock = TestBed.inject(HttpTestingController);
    router = TestBed.inject(Router);
    auth = TestBed.inject(AuthService);
  });

  afterEach(() => {
    httpMock.verify();
  });

  it('should pass through non-401 responses', () => {
    http.get('/test').subscribe((res) => {
      expect(res).toEqual({ ok: true });
    });
    httpMock.expectOne('/test').flush({ ok: true });
  });

  it('should redirect to /login on 401 for non-session requests', () => {
    spyOn(router, 'navigate');
    spyOn(auth, 'clearSession');

    http.get('/_all_dbs').subscribe({
      error: (err: HttpErrorResponse) => {
        expect(err.status).toBe(401);
      },
    });

    httpMock.expectOne('/_all_dbs').flush(
      { error: 'unauthorized', reason: 'You are not authorized.' },
      { status: 401, statusText: 'Unauthorized' }
    );

    expect(auth.clearSession).toHaveBeenCalled();
    expect(router.navigate).toHaveBeenCalledWith(['/login'], jasmine.objectContaining({
      queryParams: jasmine.objectContaining({}),
    }));
  });

  it('should NOT redirect on 401 for /_session requests', () => {
    spyOn(router, 'navigate');

    http.post('_session', { name: 'x', password: 'y' }).subscribe({
      error: () => { /* expected */ },
    });

    httpMock.expectOne('_session').flush(
      { error: 'unauthorized', reason: 'Name or password is incorrect.' },
      { status: 401, statusText: 'Unauthorized' }
    );

    expect(router.navigate).not.toHaveBeenCalled();
  });

  it('should propagate non-401 errors without redirect', () => {
    spyOn(router, 'navigate');

    http.get('/some-path').subscribe({
      error: (err: HttpErrorResponse) => {
        expect(err.status).toBe(500);
      },
    });

    httpMock.expectOne('/some-path').flush(
      { error: 'internal_error', reason: 'Something went wrong' },
      { status: 500, statusText: 'Internal Server Error' }
    );

    expect(router.navigate).not.toHaveBeenCalled();
  });
});
