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
export { DataTableComponent, type ColumnDef, type SortChangeEvent } from './data-table/data-table.component';
export { EmptyStateComponent } from './empty-state/empty-state.component';
export { ConfirmDialogComponent, type ConfirmDialogVariant } from './confirm-dialog/confirm-dialog.component';
export { PageHeaderComponent } from './page-header/page-header.component';

// NOTE: test-utils.ts is intentionally NOT exported here.
// Import directly from './couch-ui/test-utils' in spec files
// to avoid pulling axe-core into production bundles.
