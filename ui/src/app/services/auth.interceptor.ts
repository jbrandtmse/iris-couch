import { HttpInterceptorFn } from '@angular/common/http';
import { inject } from '@angular/core';
import { Router } from '@angular/router';
import { catchError, throwError } from 'rxjs';
import { AuthService } from './auth.service';

/**
 * HTTP interceptor that handles 401 responses.
 *
 * On any 401 (except requests to /_session itself), clears the local
 * session and redirects to /login with the current URL as returnUrl.
 */
export const authInterceptor: HttpInterceptorFn = (req, next) => {
  const router = inject(Router);
  const auth = inject(AuthService);

  return next(req).pipe(
    catchError((error) => {
      if (
        error.status === 401 &&
        !req.url.endsWith('/_session') &&
        !req.url.endsWith('_session')
      ) {
        auth.clearSession();
        router.navigate(['/login'], {
          queryParams: { returnUrl: router.url },
        });
      }
      return throwError(() => error);
    })
  );
};
