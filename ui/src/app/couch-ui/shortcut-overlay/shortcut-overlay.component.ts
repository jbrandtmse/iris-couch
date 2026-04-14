import { Component, HostListener, OnDestroy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Overlay, OverlayRef, OverlayModule } from '@angular/cdk/overlay';
import { ComponentPortal } from '@angular/cdk/portal';

/** Content shown inside the overlay. */
@Component({
  selector: 'app-shortcut-overlay-content',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div class="shortcut-panel" role="dialog" aria-label="Keyboard shortcuts">
      <div class="shortcut-panel__header">
        <h2 class="shortcut-panel__title">Keyboard Shortcuts</h2>
      </div>
      <dl class="shortcut-list">
        <div class="shortcut-row">
          <dt class="shortcut-key"><kbd>?</kbd></dt>
          <dd class="shortcut-desc">Show keyboard shortcuts</dd>
        </div>
        <div class="shortcut-row">
          <dt class="shortcut-key"><kbd>/</kbd></dt>
          <dd class="shortcut-desc">Focus filter / search</dd>
        </div>
        <div class="shortcut-row">
          <dt class="shortcut-key"><kbd>Esc</kbd></dt>
          <dd class="shortcut-desc">Close overlay / cancel</dd>
        </div>
      </dl>
    </div>
  `,
  styles: [`
    .shortcut-panel {
      background: var(--color-neutral-0);
      border: 1px solid var(--color-neutral-200);
      border-radius: var(--border-radius);
      padding: var(--space-6);
      min-width: 320px;
      max-width: 480px;
      box-shadow: 0 4px 24px rgba(0, 0, 0, 0.12);
    }

    .shortcut-panel__header {
      margin-bottom: var(--space-4);
    }

    .shortcut-panel__title {
      font-size: var(--font-size-lg);
      font-weight: 600;
      color: var(--color-neutral-800);
      margin: 0;
    }

    .shortcut-list {
      display: flex;
      flex-direction: column;
      gap: var(--space-2);
      margin: 0;
    }

    .shortcut-row {
      display: flex;
      align-items: center;
      gap: var(--space-3);
    }

    .shortcut-key {
      min-width: 48px;
    }

    .shortcut-key kbd {
      display: inline-block;
      padding: 2px 8px;
      font-family: var(--font-mono);
      font-size: var(--font-size-sm);
      color: var(--color-neutral-700);
      background: var(--color-neutral-50);
      border: 1px solid var(--color-neutral-200);
      border-radius: var(--border-radius);
    }

    .shortcut-desc {
      font-size: var(--font-size-sm);
      color: var(--color-neutral-600);
      margin: 0;
    }
  `]
})
export class ShortcutOverlayContentComponent {}

/**
 * ShortcutOverlay component.
 *
 * Listens for `?` keypress (when not in an input/textarea) and opens
 * a CDK overlay listing available keyboard shortcuts. Esc closes it.
 */
@Component({
  selector: 'app-shortcut-overlay',
  standalone: true,
  imports: [OverlayModule],
  template: '',
})
export class ShortcutOverlayComponent implements OnDestroy {
  private overlayRef: OverlayRef | null = null;

  constructor(private readonly overlay: Overlay) {}

  ngOnDestroy(): void {
    this.close();
  }

  @HostListener('document:keydown', ['$event'])
  onKeydown(event: KeyboardEvent): void {
    const target = event.target as HTMLElement | null;
    const tagName = target?.tagName?.toLowerCase() ?? '';

    // Close on Escape
    if (event.key === 'Escape' && this.overlayRef) {
      this.close();
      return;
    }

    // Don't trigger from input/textarea/contenteditable
    if (tagName === 'input' || tagName === 'textarea' || (target && target.isContentEditable)) {
      return;
    }

    if (event.key === '?') {
      event.preventDefault();
      this.toggle();
    }
  }

  private toggle(): void {
    if (this.overlayRef) {
      this.close();
    } else {
      this.open();
    }
  }

  private open(): void {
    const positionStrategy = this.overlay
      .position()
      .global()
      .centerHorizontally()
      .centerVertically();

    this.overlayRef = this.overlay.create({
      positionStrategy,
      hasBackdrop: true,
      backdropClass: 'cdk-overlay-dark-backdrop',
    });

    this.overlayRef.backdropClick().subscribe(() => this.close());

    const portal = new ComponentPortal(ShortcutOverlayContentComponent);
    this.overlayRef.attach(portal);
  }

  private close(): void {
    this.overlayRef?.dispose();
    this.overlayRef = null;
  }
}
