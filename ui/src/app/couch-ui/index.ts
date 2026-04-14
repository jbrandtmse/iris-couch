/* couch-ui -- barrel export for all UI primitives */

// Icons
export * from './icons';

// Components
export { ButtonComponent } from './button/button.component';
export { IconButtonComponent } from './icon-button/icon-button.component';
export { BadgeComponent } from './badge/badge.component';
export { TextInputComponent } from './text-input/text-input.component';
export { CopyButtonComponent } from './copy-button/copy-button.component';
export { AppShellComponent } from './app-shell/app-shell.component';
export { SideNavComponent } from './side-nav/side-nav.component';
export { BreadcrumbComponent, type BreadcrumbSegment } from './breadcrumb/breadcrumb.component';
export { ErrorDisplayComponent } from './error-display/error-display.component';
export { ShortcutOverlayComponent, ShortcutOverlayContentComponent } from './shortcut-overlay/shortcut-overlay.component';

// NOTE: test-utils.ts is intentionally NOT exported here.
// Import directly from './couch-ui/test-utils' in spec files
// to avoid pulling axe-core into production bundles.
