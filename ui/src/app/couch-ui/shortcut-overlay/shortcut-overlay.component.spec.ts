import { TestBed, ComponentFixture } from '@angular/core/testing';
import { ShortcutOverlayComponent, ShortcutOverlayContentComponent } from './shortcut-overlay.component';
import { OverlayModule } from '@angular/cdk/overlay';
import { expectNoAxeViolations } from '../test-utils';

describe('ShortcutOverlayComponent', () => {
  let fixture: ComponentFixture<ShortcutOverlayComponent>;
  let component: ShortcutOverlayComponent;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [ShortcutOverlayComponent, OverlayModule],
    }).compileComponents();

    fixture = TestBed.createComponent(ShortcutOverlayComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  afterEach(() => {
    // Clean up any open overlays
    const backdrop = document.querySelector('.cdk-overlay-backdrop');
    if (backdrop) {
      (backdrop as HTMLElement).click();
    }
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });

  it('should open overlay on ? keypress', () => {
    const event = new KeyboardEvent('keydown', { key: '?' });
    document.dispatchEvent(event);

    const panel = document.querySelector('.shortcut-panel');
    expect(panel).toBeTruthy();
  });

  it('should close overlay on Escape', () => {
    // Open first
    document.dispatchEvent(new KeyboardEvent('keydown', { key: '?' }));
    expect(document.querySelector('.shortcut-panel')).toBeTruthy();

    // Close
    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }));
    expect(document.querySelector('.shortcut-panel')).toBeNull();
  });

  it('should not open when focus is in an input', () => {
    const input = document.createElement('input');
    document.body.appendChild(input);
    input.focus();

    const event = new KeyboardEvent('keydown', { key: '?' });
    Object.defineProperty(event, 'target', { value: input });
    component.onKeydown(event);

    const panel = document.querySelector('.shortcut-panel');
    expect(panel).toBeNull();

    document.body.removeChild(input);
  });

  it('should toggle overlay on repeated ? keypress', () => {
    document.dispatchEvent(new KeyboardEvent('keydown', { key: '?' }));
    expect(document.querySelector('.shortcut-panel')).toBeTruthy();

    document.dispatchEvent(new KeyboardEvent('keydown', { key: '?' }));
    expect(document.querySelector('.shortcut-panel')).toBeNull();
  });
});

describe('ShortcutOverlayContentComponent', () => {
  let fixture: ComponentFixture<ShortcutOverlayContentComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [ShortcutOverlayContentComponent],
    }).compileComponents();

    fixture = TestBed.createComponent(ShortcutOverlayContentComponent);
    fixture.detectChanges();
  });

  it('should render the shortcut panel', () => {
    const panel = fixture.nativeElement.querySelector('.shortcut-panel');
    expect(panel).toBeTruthy();
  });

  it('should have role="dialog"', () => {
    const panel = fixture.nativeElement.querySelector('[role="dialog"]');
    expect(panel).toBeTruthy();
  });

  it('should list at least the ? shortcut', () => {
    const rows = fixture.nativeElement.querySelectorAll('.shortcut-row');
    expect(rows.length).toBeGreaterThanOrEqual(2);
    const kbds = fixture.nativeElement.querySelectorAll('kbd');
    const keys = Array.from(kbds).map((k: any) => k.textContent.trim());
    expect(keys).toContain('?');
    expect(keys).toContain('/');
  });

  it('should pass axe-core accessibility checks', async () => {
    await expectNoAxeViolations(fixture.nativeElement);
  });
});
