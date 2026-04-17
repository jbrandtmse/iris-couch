import {
  Component,
  QueryList,
  ViewChildren,
  ElementRef,
  AfterViewInit,
  OnDestroy,
  Input,
  OnChanges,
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
  /** When true, render the item but disable routing / focus (Story 11.4). */
  disabled?: boolean;
  /** Optional tooltip shown via title attribute (e.g. "Select a document first"). */
  tooltip?: string;
}

/**
 * Context passed to each per-database nav entry's functions. Grows over time
 * as new conditional-rendering signals emerge (e.g. user role gates in
 * Epic 14). Keep it flat — factories should not read from component state.
 */
export interface NavContext {
  dbName: string;
  docId: string | null;
}

/**
 * Declarative shape for a single per-database nav entry. Story 12.0 replaced
 * the hardcoded four-entry array inside `updateNavScope()` with a config list
 * of these records so that adding a fifth entry (Epic 14 user-role gates,
 * Epic 15 replication view, etc.) is a one-line append rather than another
 * bolt-on inside a growing if/else chain.
 *
 *   - `route(ctx)`   — route string rendered on an enabled entry. Unused when
 *                      `enabled()` returns false.
 *   - `enabled(ctx)` — if false, the entry renders as a disabled `<span>`
 *                      with `aria-disabled="true"` and `tooltip()` text.
 *   - `tooltip(ctx)` — optional title-attribute hint shown when disabled.
 */
export interface PerDbNavEntry {
  id: string;
  label: string;
  route: (ctx: NavContext) => string;
  enabled: (ctx: NavContext) => boolean;
  tooltip?: (ctx: NavContext) => string | null;
}

/**
 * The canonical per-database nav config. Order here is the render order in
 * the SideNav list. To add a fifth entry, append one record.
 */
export const NAV_ENTRY_CONFIG: readonly PerDbNavEntry[] = [
  {
    id: 'documents',
    label: 'Documents',
    route: (ctx) => `/db/${ctx.dbName}`,
    enabled: () => true,
  },
  {
    id: 'design-documents',
    label: 'Design Documents',
    route: (ctx) => `/db/${ctx.dbName}/design`,
    enabled: () => true,
  },
  {
    id: 'security',
    label: 'Security',
    route: (ctx) => `/db/${ctx.dbName}/security`,
    enabled: () => true,
  },
  {
    id: 'revision-history',
    label: 'Revision History',
    route: (ctx) => `/db/${ctx.dbName}/doc/${ctx.docId}/revisions`,
    enabled: (ctx) => ctx.docId !== null,
    tooltip: (ctx) =>
      ctx.docId === null ? 'Select a document first to view its revisions' : null,
  },
];

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
          <!-- Enabled entry: a real router link. -->
          <a
            *ngIf="!item.disabled"
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
          <!-- Disabled entry (Story 11.4): a non-link with aria-disabled
               and a tooltip explaining why it can't be clicked. -->
          <span
            *ngIf="item.disabled"
            #navLink
            class="nav-link nav-link--disabled"
            role="link"
            aria-disabled="true"
            [attr.title]="item.tooltip || null"
            [attr.tabindex]="i === focusedIndex ? 0 : -1"
            (focus)="onFocusItem(i)">
            {{ item.label }}
          </span>
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

    .nav-link--disabled {
      color: var(--color-neutral-400);
      cursor: not-allowed;
    }

    .nav-link--disabled:hover {
      background-color: transparent;
    }

    @media (prefers-reduced-motion: reduce) {
      .nav-link {
        transition: none;
      }
    }
  `]
})
export class SideNavComponent implements AfterViewInit, OnDestroy, OnChanges {
  @ViewChildren('navLink') navLinks!: QueryList<ElementRef<HTMLElement>>;

  /**
   * When the consumer is on a document-detail or revisions view, pass the
   * current doc ID in so the "Revision History" entry becomes an enabled
   * deep link. When absent, the entry renders in a disabled state.
   * (Story 11.4 Task 5.)
   */
  @Input() docId?: string | null;

  /** Global navigation items. */
  private readonly globalItems: NavItem[] = [
    { label: 'Databases', route: '/databases' },
    { label: 'Active tasks', route: '/active-tasks' },
    { label: 'Setup', route: '/setup' },
    { label: 'About', route: '/about' },
  ];

  /**
   * Per-database nav-entry config. Defaults to the canonical
   * {@link NAV_ENTRY_CONFIG}; tests may override via `TestBed.overrideComponent`
   * or direct assignment to verify that appending a fifth entry flows through
   * to the rendered `<li>` list without template changes.
   */
  navEntryConfig: readonly PerDbNavEntry[] = NAV_ENTRY_CONFIG;

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
    const url = this.router.url.split('?')[0];
    const dbMatch = url.match(/^\/db\/([^/]+)/);

    if (dbMatch) {
      this.dbName = decodeURIComponent(dbMatch[1]);
      // Story 11.4: detect if a doc is in scope from the URL so the
      // Revision History entry becomes an enabled deep link. The parent
      // component can also override by passing in `[docId]`.
      const effectiveDocId = this.docId ?? this.extractDocIdFromUrl(url, this.dbName);
      const ctx: NavContext = { dbName: this.dbName, docId: effectiveDocId };
      this.items = this.navEntryConfig.map((entry) => this.toNavItem(entry, ctx));
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

  /**
   * Translate a {@link PerDbNavEntry} + context into the {@link NavItem}
   * shape the template consumes. Preserves the Story 11.4 disabled-with-
   * tooltip contract: when `enabled(ctx)` returns false, the entry renders
   * as a disabled `<span>` with an empty `route` (it must never navigate)
   * and whatever `tooltip(ctx)` returns.
   */
  private toNavItem(entry: PerDbNavEntry, ctx: NavContext): NavItem {
    if (entry.enabled(ctx)) {
      return { label: entry.label, route: entry.route(ctx) };
    }
    return {
      label: entry.label,
      route: '',
      disabled: true,
      tooltip: entry.tooltip?.(ctx) ?? undefined,
    };
  }

  /**
   * Extract a docid from the URL when it looks like
   * `/db/{dbname}/doc/<anything>[/revisions]`. Returns null when no doc
   * is in scope.
   */
  private extractDocIdFromUrl(url: string, dbName: string): string | null {
    const prefix = `/db/${dbName}/doc/`;
    if (!url.startsWith(prefix)) return null;
    let remainder = url.slice(prefix.length);
    if (remainder.endsWith('/revisions')) {
      remainder = remainder.slice(0, -'/revisions'.length);
    }
    return remainder.length > 0 ? decodeURIComponent(remainder) : null;
  }

  ngOnChanges(): void {
    // Re-evaluate scope when the host passes in a new docId (e.g. the user
    // navigated from the doc list to a doc detail view).
    this.updateNavScope();
  }

  private setupKeyManager(): void {
    if (!this.navLinks) return;
    const focusableItems = this.navLinks.map(
      (ref) => new FocusableNavItem(ref.nativeElement as HTMLElement)
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

/** Wrapper to make anchor or span elements work with CDK FocusKeyManager. */
class FocusableNavItem implements FocusableOption {
  constructor(private readonly element: HTMLElement) {}

  focus(): void {
    this.element.focus();
  }
}
