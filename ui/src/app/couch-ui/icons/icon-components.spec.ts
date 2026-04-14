import { TestBed, ComponentFixture } from '@angular/core/testing';
import {
  IconDatabaseComponent,
  IconFileTextComponent,
  IconShieldComponent,
  IconSettingsComponent,
  IconInfoComponent,
  IconMenuComponent,
  IconPlusComponent,
  IconTrashComponent,
  IconRefreshComponent,
  IconCopyComponent,
  IconCheckComponent,
  IconDownloadComponent,
  IconSearchComponent,
  IconXComponent,
  IconAlertTriangleComponent,
  IconAlertCircleComponent,
  IconCheckCircleComponent,
  IconChevronRightComponent,
  IconChevronLeftComponent,
  IconChevronDownComponent,
} from './index';

/* Helper: assert common SVG icon traits */
function assertIconDefaults(fixture: ComponentFixture<any>, label: string): void {
  fixture.detectChanges();
  const svg = fixture.nativeElement.querySelector('svg') as SVGElement;

  expect(svg).withContext(`${label}: svg element exists`).toBeTruthy();
  expect(svg.getAttribute('width')).withContext(`${label}: default width`).toBe('16');
  expect(svg.getAttribute('height')).withContext(`${label}: default height`).toBe('16');
  expect(svg.getAttribute('viewBox')).withContext(`${label}: viewBox`).toBe('0 0 24 24');
  expect(svg.getAttribute('aria-hidden')).withContext(`${label}: aria-hidden`).toBe('true');
  expect(svg.getAttribute('fill')).withContext(`${label}: fill`).toBe('none');
  expect(svg.getAttribute('stroke')).withContext(`${label}: stroke`).toBe('currentColor');
}

function assertSizeInput(fixture: ComponentFixture<any>, label: string): void {
  fixture.componentInstance.size = 24;
  fixture.detectChanges();
  const svg = fixture.nativeElement.querySelector('svg') as SVGElement;
  expect(svg.getAttribute('width')).withContext(`${label}: custom width`).toBe('24');
  expect(svg.getAttribute('height')).withContext(`${label}: custom height`).toBe('24');
}

const ALL_ICONS = [
  { component: IconDatabaseComponent, name: 'database' },
  { component: IconFileTextComponent, name: 'file-text' },
  { component: IconShieldComponent, name: 'shield' },
  { component: IconSettingsComponent, name: 'settings' },
  { component: IconInfoComponent, name: 'info' },
  { component: IconMenuComponent, name: 'menu' },
  { component: IconPlusComponent, name: 'plus' },
  { component: IconTrashComponent, name: 'trash' },
  { component: IconRefreshComponent, name: 'refresh' },
  { component: IconCopyComponent, name: 'copy' },
  { component: IconCheckComponent, name: 'check' },
  { component: IconDownloadComponent, name: 'download' },
  { component: IconSearchComponent, name: 'search' },
  { component: IconXComponent, name: 'x' },
  { component: IconAlertTriangleComponent, name: 'alert-triangle' },
  { component: IconAlertCircleComponent, name: 'alert-circle' },
  { component: IconCheckCircleComponent, name: 'check-circle' },
  { component: IconChevronRightComponent, name: 'chevron-right' },
  { component: IconChevronLeftComponent, name: 'chevron-left' },
  { component: IconChevronDownComponent, name: 'chevron-down' },
];

describe('Icon components', () => {
  it('should have exactly 20 icons in the barrel export', () => {
    expect(ALL_ICONS.length).toBe(20);
  });

  ALL_ICONS.forEach(({ component, name }) => {
    describe(`Icon: ${name}`, () => {
      let fixture: ComponentFixture<any>;

      beforeEach(async () => {
        await TestBed.configureTestingModule({
          imports: [component],
        }).compileComponents();
        fixture = TestBed.createComponent(component);
      });

      it('should render with default 16x16 size, correct viewBox, aria-hidden, and currentColor stroke', () => {
        assertIconDefaults(fixture, name);
      });

      it('should accept [size] input to override width/height', () => {
        assertSizeInput(fixture, name);
      });
    });
  });
});
