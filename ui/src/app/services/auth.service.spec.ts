import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { AuthService, SessionResponse, LoginResponse } from './auth.service';
import { firstValueFrom } from 'rxjs';

describe('AuthService', () => {
  let service: AuthService;
  let httpMock: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [
        provideHttpClient(),
        provideHttpClientTesting(),
      ],
    });
    service = TestBed.inject(AuthService);
    httpMock = TestBed.inject(HttpTestingController);
  });

  afterEach(() => {
    httpMock.verify();
  });

  it('should be created', () => {
    expect(service).toBeTruthy();
  });

  it('should initially be unauthenticated', async () => {
    const isAuth = await firstValueFrom(service.isAuthenticated$);
    expect(isAuth).toBeFalse();
  });

  it('should initially have empty username', async () => {
    const username = await firstValueFrom(service.username$);
    expect(username).toBe('');
  });

  it('should login via POST /_session', () => {
    service.login('admin', 'secret').subscribe((res) => {
      expect(res.ok).toBeTrue();
      expect(res.name).toBe('admin');
    });

    const loginReq = httpMock.expectOne('/iris-couch/_session');
    expect(loginReq.request.method).toBe('POST');
    expect(loginReq.request.body).toEqual({ name: 'admin', password: 'secret' });
    loginReq.flush({ ok: true, name: 'admin', roles: ['_admin'] } as LoginResponse);

    // Login triggers a getSession call
    const sessionReq = httpMock.expectOne('/iris-couch/_session');
    expect(sessionReq.request.method).toBe('GET');
    sessionReq.flush({
      ok: true,
      userCtx: { name: 'admin', roles: ['_admin'] },
    } as SessionResponse);
  });

  it('should logout via DELETE /_session', () => {
    service.logout().subscribe();
    const req = httpMock.expectOne('/iris-couch/_session');
    expect(req.request.method).toBe('DELETE');
    req.flush({ ok: true });
  });

  it('should clear session on logout', async () => {
    // First, simulate a login
    service.login('admin', 'pass').subscribe();
    httpMock.expectOne({ method: 'POST', url: '/iris-couch/_session' }).flush({
      ok: true, name: 'admin', roles: [],
    });
    httpMock.expectOne({ method: 'GET', url: '/iris-couch/_session' }).flush({
      ok: true, userCtx: { name: 'admin', roles: [] },
    });

    // Now logout
    service.logout().subscribe();
    httpMock.expectOne({ method: 'DELETE', url: '/iris-couch/_session' }).flush({ ok: true });

    const isAuth = await firstValueFrom(service.isAuthenticated$);
    expect(isAuth).toBeFalse();
  });

  it('should check existing session on checkSession()', () => {
    service.checkSession().subscribe((session) => {
      expect(session.ok).toBeTrue();
      expect(session.userCtx.name).toBe('admin');
    });

    const req = httpMock.expectOne('/iris-couch/_session');
    expect(req.request.method).toBe('GET');
    req.flush({
      ok: true,
      userCtx: { name: 'admin', roles: ['_admin'] },
    } as SessionResponse);
  });

  it('should handle checkSession failure gracefully', async () => {
    service.checkSession().subscribe();
    const req = httpMock.expectOne('/iris-couch/_session');
    req.error(new ProgressEvent('Network error'));

    const isAuth = await firstValueFrom(service.isAuthenticated$);
    expect(isAuth).toBeFalse();
  });

  it('should clear local state with clearSession()', async () => {
    // Simulate authenticated state
    service.checkSession().subscribe();
    httpMock.expectOne('/iris-couch/_session').flush({
      ok: true,
      userCtx: { name: 'admin', roles: ['_admin'] },
    });

    service.clearSession();
    const isAuth = await firstValueFrom(service.isAuthenticated$);
    expect(isAuth).toBeFalse();
  });
});
