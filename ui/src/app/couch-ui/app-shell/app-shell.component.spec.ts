import { TestBed, ComponentFixture } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { provideHttpClientTesting } from '@angular/common/http/testing';
import { provideRouter } from '@angular/router';
import { BehaviorSubject } from 'rxjs';
import { AppShellComponent } from './app-shell.component';
import { AuthService } from '../../services/auth.service';
import { expectNoAxeViolations } from '../test-utils';

describe('AppShellComponent', () => {
  let fixture: ComponentFixture<AppShellComponent>;
  let isAuthenticated$: BehaviorSubject<boolean>;
  let username$: BehaviorSubject<string>;

  function setup(authenticated: boolean): void {
    isAuthenticated$ = new BehaviorSubject<boolean>(authenticated);
    username$ = new BehaviorSubject<string>(authenticated ? 'admin' : '');

    TestBed.configureTestingModule({
      imports: [AppShellComponent],
      providers: [
        provideHttpClient(),
        provideHttpClientTesting(),
        provideRouter([]),
        {
          provide: AuthService,
          useValue: {
            isAuthenticated$: isAuthenticated$.asObservable(),
            username$: username$.asObservable(),
            logout: () => new BehaviorSubject({ ok: true }).asObservable(),
          },
        },
      ],
    });
    fixture = TestBed.createComponent(AppShellComponent);
    fixture.detectChanges();
  }

  describe('when authenticated', () => {
    beforeEach(() => setup(true));

    it('should render the shell grid', () => {
      const shell = fixture.nativeElement.querySelector('.shell');
      expect(shell).toBeTruthy();
    });

    it('should have a header with role="banner"', () => {
      const header = fixture.nativeElement.querySelector('[role="banner"]');
      expect(header).toBeTruthy();
      expect(header.tagName).toBe('HEADER');
    });

    it('should have a nav with role="navigation"', () => {
      const nav = fixture.nativeElement.querySelector('[role="navigation"]');
      expect(nav).toBeTruthy();
    });

    it('should have a main with role="main"', () => {
      const main = fixture.nativeElement.querySelector('[role="main"]');
      expect(main).toBeTruthy();
      expect(main.id).toBe('main-content');
    });

    it('should have a skip-to-content link targeting main', () => {
      const skipLink = fixture.nativeElement.querySelector('.skip-link');
      expect(skipLink).toBeTruthy();
      expect(skipLink.getAttribute('href')).toBe('#main-content');
      expect(skipLink.textContent).toContain('Skip to content');
    });

    it('should display the iris-couch wordmark in the header', () => {
      const wordmark = fixture.nativeElement.querySelector('.shell-wordmark');
      expect(wordmark).toBeTruthy();
      expect(wordmark.textContent).toContain('iris-couch');
      expect(wordmark.classList).toContain('mono');
    });

    it('should display the username', () => {
      const usernameEl = fixture.nativeElement.querySelector('.shell-username');
      expect(usernameEl?.textContent?.trim()).toBe('admin');
    });

    it('should have a Sign out button', () => {
      const signOutBtn = fixture.nativeElement.querySelector('[aria-label="Sign out"]');
      expect(signOutBtn).toBeTruthy();
    });

    it('should render the side-nav component', () => {
      const sideNav = fixture.nativeElement.querySelector('app-side-nav');
      expect(sideNav).toBeTruthy();
    });

    it('should render a router-outlet inside main', () => {
      const main = fixture.nativeElement.querySelector('.shell-main');
      expect(main.querySelector('router-outlet')).toBeTruthy();
    });

    it('should pass axe-core accessibility checks', async () => {
      await expectNoAxeViolations(fixture.nativeElement);
    });
  });

  describe('when not authenticated', () => {
    beforeEach(() => setup(false));

    it('should not render the shell grid', () => {
      const shell = fixture.nativeElement.querySelector('.shell');
      expect(shell).toBeNull();
    });

    it('should render the login-wrapper with router-outlet', () => {
      const wrapper = fixture.nativeElement.querySelector('.login-wrapper');
      expect(wrapper).toBeTruthy();
      expect(wrapper.querySelector('router-outlet')).toBeTruthy();
    });
  });

  describe('viewport guard', () => {
    beforeEach(() => setup(true));

    it('should have a viewport-guard element', () => {
      const guard = fixture.nativeElement.querySelector('.viewport-guard');
      expect(guard).toBeTruthy();
      expect(guard.textContent).toContain('1280 pixels');
    });
  });
});
