import { TestBed, ComponentFixture, fakeAsync, tick } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { provideHttpClientTesting, HttpTestingController } from '@angular/common/http/testing';
import { provideRouter, Router } from '@angular/router';
import { LoginComponent } from './login.component';
import { AuthService } from '../../services/auth.service';
import { expectNoAxeViolations } from '../../couch-ui/test-utils';
import { of, throwError, Subject } from 'rxjs';

describe('LoginComponent', () => {
  let fixture: ComponentFixture<LoginComponent>;
  let component: LoginComponent;
  let mockAuth: jasmine.SpyObj<AuthService>;
  let router: Router;

  beforeEach(async () => {
    mockAuth = jasmine.createSpyObj('AuthService', ['login', 'logout', 'getSession', 'checkSession', 'clearSession'], {
      isAuthenticated$: of(false),
      username$: of(''),
    });

    await TestBed.configureTestingModule({
      imports: [LoginComponent],
      providers: [
        provideHttpClient(),
        provideHttpClientTesting(),
        provideRouter([
          { path: 'databases', component: LoginComponent },
          { path: 'login', component: LoginComponent },
        ]),
        { provide: AuthService, useValue: mockAuth },
      ],
    }).compileComponents();

    fixture = TestBed.createComponent(LoginComponent);
    component = fixture.componentInstance;
    router = TestBed.inject(Router);
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });

  it('should render a form element', () => {
    const form = fixture.nativeElement.querySelector('form');
    expect(form).toBeTruthy();
  });

  it('should render the iris-couch wordmark', () => {
    const wordmark = fixture.nativeElement.querySelector('.login-wordmark');
    expect(wordmark).toBeTruthy();
    expect(wordmark.textContent.trim()).toBe('iris-couch');
    expect(wordmark.classList).toContain('mono');
  });

  it('should render username and password inputs with labels', () => {
    const labels = fixture.nativeElement.querySelectorAll('label');
    const labelTexts = Array.from(labels).map((l: any) => l.textContent.trim());
    expect(labelTexts).toContain('Username');
    expect(labelTexts).toContain('Password');

    const usernameInput = fixture.nativeElement.querySelector('#login-username');
    const passwordInput = fixture.nativeElement.querySelector('#login-password');
    expect(usernameInput).toBeTruthy();
    expect(usernameInput.type).toBe('text');
    expect(passwordInput).toBeTruthy();
    expect(passwordInput.type).toBe('password');
  });

  it('should render a Sign in button', () => {
    const button = fixture.nativeElement.querySelector('app-button button');
    expect(button).toBeTruthy();
    expect(button.textContent.trim()).toContain('Sign in');
  });

  it('should have an auto-focus mechanism on the username input', () => {
    // Verify the ViewChild reference exists and points to the username input
    const usernameInput = fixture.nativeElement.querySelector('#login-username');
    expect(usernameInput).toBeTruthy();
    expect(component.usernameInput).toBeTruthy();
    expect(component.usernameInput.nativeElement).toBe(usernameInput);
  });

  it('should call authService.login on form submit', fakeAsync(() => {
    mockAuth.login.and.returnValue(of({ ok: true, name: 'admin', roles: [] }));
    spyOn(router, 'navigateByUrl');

    component.username = 'admin';
    component.password = 'secret';
    component.onSubmit();
    tick();

    expect(mockAuth.login).toHaveBeenCalledWith('admin', 'secret');
  }));

  it('should redirect to /databases on successful login', fakeAsync(() => {
    mockAuth.login.and.returnValue(of({ ok: true, name: 'admin', roles: [] }));
    spyOn(router, 'navigateByUrl');

    component.username = 'admin';
    component.password = 'secret';
    component.onSubmit();
    tick();

    expect(router.navigateByUrl).toHaveBeenCalledWith('/databases');
  }));

  it('should show error on failed login', fakeAsync(() => {
    mockAuth.login.and.returnValue(throwError(() => ({
      status: 401,
      error: { error: 'unauthorized', reason: 'Name or password is incorrect.' },
    })));

    component.username = 'baduser';
    component.password = 'badpass';
    component.onSubmit();
    tick();
    fixture.detectChanges();

    expect(component.error).toBeTruthy();
    expect(component.error?.error).toBe('unauthorized');
    expect(component.error?.reason).toBe('Name or password is incorrect.');
    expect(component.errorStatusCode).toBe(401);
  }));

  it('should NOT reset the username field on error', fakeAsync(() => {
    mockAuth.login.and.returnValue(throwError(() => ({
      status: 401,
      error: { error: 'unauthorized', reason: 'Bad credentials.' },
    })));

    component.username = 'keepme';
    component.password = 'badpass';
    component.onSubmit();
    tick();

    expect(component.username).toBe('keepme');
  }));

  it('should show error display component on failure', fakeAsync(() => {
    mockAuth.login.and.returnValue(throwError(() => ({
      status: 401,
      error: { error: 'unauthorized', reason: 'Name or password is incorrect.' },
    })));

    component.username = 'x';
    component.password = 'y';
    component.onSubmit();
    tick();
    fixture.detectChanges();

    const errorDisplay = fixture.nativeElement.querySelector('app-error-display');
    expect(errorDisplay).toBeTruthy();
  }));

  it('should disable inputs while submitting', () => {
    const loginSubject = new Subject<any>();
    mockAuth.login.and.returnValue(loginSubject.asObservable());

    component.username = 'admin';
    component.password = 'secret';
    component.onSubmit();

    // While the observable has not emitted, submitting should be true
    expect(component.submitting).toBeTrue();

    // Complete the login
    spyOn(router, 'navigateByUrl');
    loginSubject.next({ ok: true, name: 'admin', roles: [] });
    loginSubject.complete();

    expect(component.submitting).toBeFalse();
  });

  it('should pass axe-core accessibility checks', async () => {
    await expectNoAxeViolations(fixture.nativeElement);
  });
});
