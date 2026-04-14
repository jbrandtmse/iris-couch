import { Component, OnInit, ViewChild, ElementRef, AfterViewInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router, ActivatedRoute } from '@angular/router';
import { AuthService } from '../../services/auth.service';
import {
  TextInputComponent,
  ButtonComponent,
} from '../../couch-ui';
import { ErrorDisplayComponent } from '../../couch-ui/error-display/error-display.component';

/**
 * LoginForm component.
 *
 * Centered card (~360px) with iris-couch wordmark, username/password
 * TextInputs, and Sign In primary button. On success, redirects to
 * the return URL or /databases.
 */
@Component({
  selector: 'app-login',
  standalone: true,
  imports: [
    CommonModule,
    FormsModule,
    TextInputComponent,
    ButtonComponent,
    ErrorDisplayComponent,
  ],
  template: `
    <div class="login-page">
      <form class="login-card" (ngSubmit)="onSubmit()" #loginForm="ngForm">
        <span class="login-wordmark mono">iris-couch</span>

        <div class="login-fields">
          <label for="login-username" class="login-label">Username</label>
          <input
            #usernameInput
            id="login-username"
            type="text"
            class="login-field"
            name="username"
            autocomplete="username"
            [disabled]="submitting"
            [(ngModel)]="username"
            [attr.aria-describedby]="error ? 'login-error' : null"
            [attr.aria-invalid]="error ? true : null"
            required />

          <label for="login-password" class="login-label">Password</label>
          <input
            id="login-password"
            type="password"
            class="login-field"
            name="password"
            autocomplete="current-password"
            [disabled]="submitting"
            [(ngModel)]="password"
            [attr.aria-describedby]="error ? 'login-error' : null"
            [attr.aria-invalid]="error ? true : null"
            required />
        </div>

        <app-button
          variant="primary"
          size="standard"
          type="submit"
          [loading]="submitting"
          [disabled]="submitting"
          ariaLabel="Sign in">
          Sign in
        </app-button>

        <app-error-display
          *ngIf="error"
          id="login-error"
          [error]="error"
          [statusCode]="errorStatusCode"
          variant="inline">
        </app-error-display>
      </form>
    </div>
  `,
  styles: [`
    :host {
      display: block;
      width: 100%;
      height: 100vh;
    }

    .login-page {
      display: flex;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      background-color: var(--color-neutral-50);
    }

    .login-card {
      display: flex;
      flex-direction: column;
      gap: var(--space-4);
      width: 360px;
      padding: var(--space-8);
      background-color: var(--color-neutral-0);
      border: 1px solid var(--color-neutral-200);
      border-radius: var(--border-radius);
    }

    .login-wordmark {
      font-size: var(--font-size-xl);
      line-height: var(--line-height-xl);
      color: var(--color-neutral-600);
      font-weight: 400;
      text-align: center;
    }

    .login-fields {
      display: flex;
      flex-direction: column;
      gap: var(--space-1);
    }

    .login-label {
      font-size: var(--font-size-sm);
      line-height: var(--line-height-sm);
      font-weight: 500;
      color: var(--color-neutral-700);
      margin-top: var(--space-2);
    }

    .login-label:first-child {
      margin-top: 0;
    }

    .login-field {
      height: 32px;
      padding: 0 12px;
      font-size: var(--font-size-sm);
      line-height: var(--line-height-sm);
      color: var(--color-neutral-800);
      background-color: var(--color-neutral-0);
      border: 1px solid var(--color-neutral-200);
      border-radius: var(--border-radius);
      transition: border-color 0.15s ease, box-shadow 0.15s ease;
    }

    .login-field:focus {
      outline: none;
      border-color: var(--color-info);
      box-shadow: 0 0 0 2px rgba(60, 90, 158, 0.1);
    }

    .login-field:focus-visible {
      outline: 2px solid var(--color-info);
      outline-offset: 3px;
    }

    .login-field:disabled {
      opacity: 0.5;
      cursor: not-allowed;
    }
  `]
})
export class LoginComponent implements AfterViewInit {
  @ViewChild('usernameInput') usernameInput!: ElementRef<HTMLInputElement>;

  username = '';
  password = '';
  submitting = false;
  error: { error: string; reason: string } | null = null;
  errorStatusCode = 0;

  constructor(
    private readonly auth: AuthService,
    private readonly router: Router,
    private readonly route: ActivatedRoute
  ) {}

  ngAfterViewInit(): void {
    // Auto-focus the username input on render
    setTimeout(() => this.usernameInput?.nativeElement?.focus(), 0);
  }

  onSubmit(): void {
    if (this.submitting) return;

    this.submitting = true;
    this.error = null;

    this.auth.login(this.username, this.password).subscribe({
      next: () => {
        this.submitting = false;
        const returnUrl = this.route.snapshot.queryParamMap.get('returnUrl') || '/databases';
        this.router.navigateByUrl(returnUrl);
      },
      error: (err) => {
        this.submitting = false;
        this.errorStatusCode = err.status || 401;
        this.error = err.error && err.error.error
          ? { error: err.error.error, reason: err.error.reason || '' }
          : { error: 'unauthorized', reason: 'Name or password is incorrect.' };
        // Do NOT reset the username field
      },
    });
  }
}
