import { TestBed, ComponentFixture } from '@angular/core/testing';
import { PaginationComponent } from './pagination.component';
import { expectNoAxeViolations } from '../test-utils';

describe('PaginationComponent', () => {
  let fixture: ComponentFixture<PaginationComponent>;
  let component: PaginationComponent;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [PaginationComponent],
    }).compileComponents();

    fixture = TestBed.createComponent(PaginationComponent);
    component = fixture.componentInstance;
  });

  it('should create', () => {
    fixture.detectChanges();
    expect(component).toBeTruthy();
  });

  describe('Range indicator', () => {
    it('should display range with tabular-nums style', () => {
      component.startIndex = 1;
      component.endIndex = 25;
      component.totalRows = 42187;
      fixture.detectChanges();
      const range = fixture.nativeElement.querySelector('.pagination__range');
      expect(range).toBeTruthy();
      expect(range.textContent).toContain('1');
      expect(range.textContent).toContain('25');
      expect(range.textContent).toContain('42,187');
    });

    it('should format numbers with locale separators', () => {
      component.startIndex = 1;
      component.endIndex = 25;
      component.totalRows = 100000;
      fixture.detectChanges();
      const range = fixture.nativeElement.querySelector('.pagination__range');
      expect(range.textContent).toContain('100,000');
    });

    it('should have tabular-nums style', () => {
      fixture.detectChanges();
      const range = fixture.nativeElement.querySelector('.pagination__range');
      const style = getComputedStyle(range);
      expect(style.fontVariantNumeric).toContain('tabular-nums');
    });
  });

  describe('Navigation buttons', () => {
    it('should have previous and next buttons', () => {
      fixture.detectChanges();
      const buttons = fixture.nativeElement.querySelectorAll('app-icon-button');
      expect(buttons.length).toBe(2);
    });

    it('should disable previous button when hasPrevious is false', () => {
      component.hasPrevious = false;
      component.hasNext = true;
      fixture.detectChanges();
      const prevBtn = fixture.nativeElement.querySelector('app-icon-button button');
      expect(prevBtn.disabled).toBeTrue();
    });

    it('should disable next button when hasNext is false', () => {
      component.hasPrevious = true;
      component.hasNext = false;
      fixture.detectChanges();
      const buttons = fixture.nativeElement.querySelectorAll('app-icon-button button');
      expect(buttons[1].disabled).toBeTrue();
    });

    it('should enable both buttons when hasPrevious and hasNext are true', () => {
      component.hasPrevious = true;
      component.hasNext = true;
      fixture.detectChanges();
      const buttons = fixture.nativeElement.querySelectorAll('app-icon-button button');
      expect(buttons[0].disabled).toBeFalse();
      expect(buttons[1].disabled).toBeFalse();
    });

    it('should emit next event on next click', () => {
      component.hasNext = true;
      fixture.detectChanges();
      spyOn(component.next, 'emit');
      component.onNext();
      expect(component.next.emit).toHaveBeenCalled();
    });

    it('should emit previous event on previous click', () => {
      component.hasPrevious = true;
      fixture.detectChanges();
      spyOn(component.previous, 'emit');
      component.onPrevious();
      expect(component.previous.emit).toHaveBeenCalled();
    });

    it('should not emit next when hasNext is false', () => {
      component.hasNext = false;
      fixture.detectChanges();
      spyOn(component.next, 'emit');
      component.onNext();
      expect(component.next.emit).not.toHaveBeenCalled();
    });

    it('should not emit previous when hasPrevious is false', () => {
      component.hasPrevious = false;
      fixture.detectChanges();
      spyOn(component.previous, 'emit');
      component.onPrevious();
      expect(component.previous.emit).not.toHaveBeenCalled();
    });
  });

  describe('Accessibility', () => {
    it('should have aria-label on nav element', () => {
      fixture.detectChanges();
      const nav = fixture.nativeElement.querySelector('nav');
      expect(nav.getAttribute('aria-label')).toBe('Pagination');
    });

    it('should have aria-labels on buttons', () => {
      fixture.detectChanges();
      const buttons = fixture.nativeElement.querySelectorAll('app-icon-button button');
      expect(buttons[0].getAttribute('aria-label')).toBe('Previous page');
      expect(buttons[1].getAttribute('aria-label')).toBe('Next page');
    });

    it('should pass axe-core checks', async () => {
      component.startIndex = 1;
      component.endIndex = 25;
      component.totalRows = 100;
      component.hasNext = true;
      component.hasPrevious = false;
      fixture.detectChanges();
      await expectNoAxeViolations(fixture.nativeElement);
    });
  });
});
