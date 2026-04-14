import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { provideHttpClientTesting } from '@angular/common/http/testing';
import { provideRouter, Router, UrlTree } from '@angular/router';
import { BehaviorSubject, firstValueFrom, Observable } from 'rxjs';
import { authGuard } from './auth.guard';
import { AuthService } from '../services/auth.service';

describe('authGuard', () => {
  let authService: AuthService;
  let router: Router;
  let isAuthenticated$: BehaviorSubject<boolean>;

  beforeEach(() => {
    isAuthenticated$ = new BehaviorSubject<boolean>(false);

    TestBed.configureTestingModule({
      providers: [
        provideHttpClient(),
        provideHttpClientTesting(),
        provideRouter([]),
        {
          provide: AuthService,
          useValue: { isAuthenticated$: isAuthenticated$.asObservable() },
        },
      ],
    });

    authService = TestBed.inject(AuthService);
    router = TestBed.inject(Router);
  });

  function runGuard(url: string): Observable<boolean | UrlTree> {
    const route = {} as any;
    const state = { url } as any;
    return TestBed.runInInjectionContext(() => authGuard(route, state)) as Observable<boolean | UrlTree>;
  }

  it('should allow navigation when authenticated', async () => {
    isAuthenticated$.next(true);
    const result = await firstValueFrom(runGuard('/databases'));
    expect(result).toBeTrue();
  });

  it('should redirect to /login when not authenticated', async () => {
    isAuthenticated$.next(false);
    const result = await firstValueFrom(runGuard('/databases'));
    expect(result instanceof UrlTree).toBeTrue();
    expect((result as UrlTree).toString()).toContain('/login');
  });

  it('should include returnUrl when redirecting', async () => {
    isAuthenticated$.next(false);
    const result = await firstValueFrom(runGuard('/db/mydb'));
    const tree = result as UrlTree;
    expect(tree.queryParams['returnUrl']).toBe('/db/mydb');
  });
});
