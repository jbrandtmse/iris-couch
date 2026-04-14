import { Component, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterOutlet, Router } from '@angular/router';
import { AuthService } from '../../services/auth.service';
import { SideNavComponent } from '../side-nav/side-nav.component';
import { IconButtonComponent } from '../icon-button/icon-button.component';

/**
 * AppShell component.
 *
 * CSS grid layout: sticky 48px header (full width), 240px fixed sidenav,
 * flex-1 main content area with router outlet. Hides shell for
 * unauthenticated users (shows only centered LoginForm). Shows a
 * viewport-too-small message below 1280px.
 */
@Component({
  selector: 'app-shell',
  standalone: true,
  imports: [CommonModule, RouterOutlet, SideNavComponent, IconButtonComponent],
  template: `
    <!-- Viewport guard: shown when screen is too narrow -->
    <div class="viewport-guard" role="alert">
      <p>iris-couch requires a viewport of at least 1280 pixels wide.</p>
    </div>

    <!-- Unauthenticated: only show the router-outlet (login page) -->
    <ng-container *ngIf="!(isAuthenticated$ | async)">
      <div class="login-wrapper">
        <router-outlet></router-outlet>
      </div>
    </ng-container>

    <!-- Authenticated: full shell with header, sidenav, main -->
    <ng-container *ngIf="isAuthenticated$ | async">
      <div class="shell">
        <a class="skip-link" href="#main-content">Skip to content</a>

        <header class="shell-header" role="banner">
          <span class="shell-wordmark mono">iris-couch</span>
          <div class="shell-session">
            <span class="shell-username">{{ username$ | async }}</span>
            <span class="shell-separator">|</span>
            <app-icon-button ariaLabel="Sign out" (click)="onSignOut()">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none"
                   stroke="currentColor" stroke-width="2" stroke-linecap="round"
                   stroke-linejoin="round" aria-hidden="true">
                <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/>
                <polyline points="16 17 21 12 16 7"/>
                <line x1="21" y1="12" x2="9" y2="12"/>
              </svg>
            </app-icon-button>
          </div>
        </header>

        <app-side-nav class="shell-sidenav"></app-side-nav>

        <main id="main-content" class="shell-main" role="main">
          <router-outlet></router-outlet>
        </main>
      </div>
    </ng-container>
  `,
  styles: [`
    :host {
      display: block;
    }

    /* ── Viewport guard ── */
    .viewport-guard {
      display: none;
      align-items: center;
      justify-content: center;
      height: 100vh;
      padding: var(--space-4);
      text-align: center;
      font-size: var(--font-size-lg);
      color: var(--color-neutral-600);
    }

    @media (max-width: 1279px) {
      .viewport-guard {
        display: flex;
      }
      .shell,
      .login-wrapper {
        display: none !important;
      }
    }

    /* ── Login wrapper (no shell) ── */
    .login-wrapper {
      display: block;
    }

    /* ── Skip-to-content link ── */
    .skip-link {
      position: absolute;
      top: -100px;
      left: var(--space-4);
      z-index: 1000;
      padding: var(--space-2) var(--space-4);
      background: var(--color-neutral-800);
      color: var(--color-neutral-0);
      border-radius: var(--border-radius);
      font-size: var(--font-size-sm);
      text-decoration: none;
    }

    .skip-link:focus {
      top: var(--space-2);
    }

    /* ── Shell grid layout ── */
    .shell {
      display: grid;
      grid-template-rows: 48px 1fr;
      grid-template-columns: 240px 1fr;
      height: 100vh;
    }

    /* ── Header ── */
    .shell-header {
      grid-column: 1 / -1;
      display: flex;
      align-items: center;
      justify-content: space-between;
      height: 48px;
      padding: 0 var(--space-4);
      border-bottom: 1px solid var(--color-neutral-200);
      background: var(--color-neutral-0);
      position: sticky;
      top: 0;
      z-index: 100;
    }

    .shell-wordmark {
      font-size: var(--font-size-lg);
      line-height: var(--line-height-lg);
      color: var(--color-neutral-600);
      font-weight: 400;
    }

    .shell-session {
      display: flex;
      align-items: center;
      gap: var(--space-2);
    }

    .shell-username {
      font-size: var(--font-size-sm);
      color: var(--color-neutral-500);
    }

    .shell-separator {
      font-size: var(--font-size-sm);
      color: var(--color-neutral-300);
    }

    /* ── Sidenav ── */
    .shell-sidenav {
      grid-row: 2;
      grid-column: 1;
      border-right: 1px solid var(--color-neutral-200);
      overflow-y: auto;
    }

    /* ── Main content ── */
    .shell-main {
      grid-row: 2;
      grid-column: 2;
      overflow-y: auto;
      padding: var(--space-4);
    }
  `]
})
export class AppShellComponent {
  private readonly auth = inject(AuthService);
  private readonly router = inject(Router);

  readonly isAuthenticated$ = this.auth.isAuthenticated$;
  readonly username$ = this.auth.username$;

  onSignOut(): void {
    this.auth.logout().subscribe(() => {
      this.router.navigate(['/login']);
    });
  }
}
