import {
  Component,
  QueryList,
  ViewChildren,
  ElementRef,
  AfterViewInit,
  OnDestroy,
} from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink, RouterLinkActive, ActivatedRoute, NavigationEnd, Router } from '@angular/router';
import { FocusKeyManager } from '@angular/cdk/a11y';
import { FocusableOption } from '@angular/cdk/a11y';
import { Subscription, filter } from 'rxjs';

/** Navigation item model. */
export interface NavItem {
  label: string;
  route: string;
  icon?: string;
}

/**
 * SideNav component.
 *
 * Displays global navigation items (Databases, Active tasks, Setup, About)
 * or per-database items (Documents, Design Documents, Security) when a
 * database is in scope. Uses CDK FocusKeyManager for arrow-key navigation.
 */
@Component({
  selector: 'app-side-nav',
  standalone: true,
  imports: [CommonModule, RouterLink, RouterLinkActive],
  template: `
    <nav role="navigation" aria-label="Main navigation">
      <ul class="nav-list" (keydown)="onKeydown($event)">
        <li *ngFor="let item of items; let i = index" class="nav-item">
          <a
            #navLink
            class="nav-link"
            [routerLink]="item.route"
            routerLinkActive="nav-link--active"
            [routerLinkActiveOptions]="{ exact: item.route === '/databases' }"
            [attr.aria-current]="isActive(item) ? 'page' : null"
            [attr.tabindex]="i === focusedIndex ? 0 : -1"
            (focus)="onFocusItem(i)">
            {{ item.label }}
          </a>
        </li>
      </ul>
    </nav>
  `,
  styles: [`
    :host {
      display: block;
      padding: var(--space-2) 0;
    }

    .nav-list {
      list-style: none;
      margin: 0;
      padding: 0;
    }

    .nav-item {
      margin: 0;
      padding: 0;
    }

    .nav-link {
      display: flex;
      align-items: center;
      height: 32px;
      padding: 0 var(--space-4);
      font-size: var(--font-size-sm);
      line-height: var(--line-height-sm);
      color: var(--color-neutral-600);
      text-decoration: none;
      border-left: 2px solid transparent;
      transition: background-color 0.15s ease;
      cursor: pointer;
    }

    .nav-link:hover {
      background-color: var(--color-neutral-50);
    }

    .nav-link:focus-visible {
      outline: 2px solid var(--color-info);
      outline-offset: -2px;
    }

    .nav-link--active {
      background-color: var(--color-neutral-100);
      border-left-color: var(--color-info);
      color: var(--color-neutral-800);
      font-weight: 500;
    }

    @media (prefers-reduced-motion: reduce) {
      .nav-link {
        transition: none;
      }
    }
  `]
})
export class SideNavComponent implements AfterViewInit, OnDestroy {
  @ViewChildren('navLink') navLinks!: QueryList<ElementRef<HTMLAnchorElement>>;

  /** Global navigation items. */
  private readonly globalItems: NavItem[] = [
    { label: 'Databases', route: '/databases' },
    { label: 'Active tasks', route: '/active-tasks' },
    { label: 'Setup', route: '/setup' },
    { label: 'About', route: '/about' },
  ];

  /** Per-database navigation items (when a database is in scope). */
  private readonly dbItems: NavItem[] = [];

  items: NavItem[] = this.globalItems;
  focusedIndex = 0;
  dbName: string | null = null;

  private keyManager!: FocusKeyManager<FocusableNavItem>;
  private routerSub!: Subscription;
  private destroyed = false;

  constructor(
    private readonly router: Router,
    private readonly route: ActivatedRoute
  ) {}

  ngAfterViewInit(): void {
    this.updateNavScope();

    // Listen for route changes to update scope
    this.routerSub = this.router.events
      .pipe(filter((e) => e instanceof NavigationEnd))
      .subscribe(() => this.updateNavScope());

    this.setupKeyManager();
  }

  ngOnDestroy(): void {
    this.destroyed = true;
    this.routerSub?.unsubscribe();
  }

  /** Determine if we are in a per-database scope or global. */
  private updateNavScope(): void {
    const url = this.router.url;
    const dbMatch = url.match(/^\/db\/([^/]+)/);

    if (dbMatch) {
      this.dbName = decodeURIComponent(dbMatch[1]);
      this.items = [
        { label: 'Documents', route: `/db/${this.dbName}` },
        { label: 'Design Documents', route: `/db/${this.dbName}/design` },
        { label: 'Security', route: `/db/${this.dbName}/security` },
      ];
    } else {
      this.dbName = null;
      this.items = this.globalItems;
    }

    // Re-setup key manager after items change (guard against destroyed view)
    setTimeout(() => {
      if (!this.destroyed) {
        this.setupKeyManager();
      }
    }, 0);
  }

  private setupKeyManager(): void {
    if (!this.navLinks) return;
    const focusableItems = this.navLinks.map(
      (ref) => new FocusableNavItem(ref.nativeElement)
    );
    this.keyManager = new FocusKeyManager(focusableItems).withWrap();
  }

  onKeydown(event: KeyboardEvent): void {
    if (this.keyManager) {
      this.keyManager.onKeydown(event);
    }
  }

  onFocusItem(index: number): void {
    this.focusedIndex = index;
  }

  /** Check if a nav item is active based on current route. */
  isActive(item: NavItem): boolean {
    const url = this.router.url.split('?')[0];
    if (item.route === '/databases') {
      return url === '/databases';
    }
    // Exact match or match followed by / to avoid false positives
    // e.g., /db/foo should not match when at /db/foobar
    return url === item.route || url.startsWith(item.route + '/');
  }
}

/** Wrapper to make anchor elements work with CDK FocusKeyManager. */
class FocusableNavItem implements FocusableOption {
  constructor(private readonly element: HTMLAnchorElement) {}

  focus(): void {
    this.element.focus();
  }
}
