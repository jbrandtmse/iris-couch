import { ComponentFixture, TestBed } from '@angular/core/testing';
import { NoopAnimationsModule } from '@angular/platform-browser/animations';
import { RevisionTreeComponent } from './revision-tree.component';
import { RevisionNode } from './revision-tree-layout';
import { expectNoAxeViolations } from '../test-utils';

function leaf(
  rev: string,
  parentRev: string | null,
  opts: Partial<RevisionNode> = {},
): RevisionNode {
  return {
    rev,
    parentRev,
    status: 'available',
    isLeaf: true,
    isWinner: false,
    branch: 0,
    ...opts,
  };
}

function mid(rev: string, parentRev: string | null): RevisionNode {
  return { rev, parentRev, status: 'available', isLeaf: false, isWinner: false, branch: 0 };
}

describe('RevisionTreeComponent', () => {
  let fixture: ComponentFixture<RevisionTreeComponent>;
  let component: RevisionTreeComponent;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [RevisionTreeComponent, NoopAnimationsModule],
    }).compileComponents();
    fixture = TestBed.createComponent(RevisionTreeComponent);
    component = fixture.componentInstance;
  });

  it('creates', () => {
    expect(component).toBeTruthy();
  });

  it('renders a loading skeleton when [loading]=true', () => {
    component.loading = true;
    fixture.detectChanges();
    const el = fixture.nativeElement.querySelector('.revision-tree__skeleton');
    expect(el).toBeTruthy();
    expect(el.getAttribute('role')).toBe('status');
  });

  it('renders the empty message with no nodes', () => {
    component.nodes = [];
    fixture.detectChanges();
    const el = fixture.nativeElement.querySelector('.revision-tree__empty');
    expect(el).toBeTruthy();
  });

  it('renders an SVG with one node per rev', () => {
    component.nodes = [leaf('1-a', null, { isWinner: true })];
    fixture.detectChanges();
    const nodes = fixture.nativeElement.querySelectorAll('.revision-tree__node');
    expect(nodes.length).toBe(1);
    const svg = fixture.nativeElement.querySelector('svg');
    expect(svg).toBeTruthy();
  });

  it('marks the winner node with the winner class', () => {
    component.nodes = [
      mid('1-a', null),
      leaf('2-b', '1-a', { isWinner: true }),
    ];
    fixture.detectChanges();
    const winner = fixture.nativeElement.querySelector('.revision-tree__node--winner');
    expect(winner).toBeTruthy();
  });

  it('marks deleted nodes with the deleted class', () => {
    component.nodes = [
      mid('1-a', null),
      leaf('2-b', '1-a', { isWinner: true }),
      leaf('2-c', '1-a', { status: 'deleted' }),
    ];
    fixture.detectChanges();
    const deleted = fixture.nativeElement.querySelector('.revision-tree__node--deleted');
    expect(deleted).toBeTruthy();
  });

  it('renders "?" for missing ancestors', () => {
    component.nodes = [
      { rev: '1-missing', parentRev: null, status: 'missing', isLeaf: false, isWinner: false, branch: 0 },
      leaf('2-a', '1-missing', { isWinner: true }),
    ];
    fixture.detectChanges();
    const labels = Array.from(
      fixture.nativeElement.querySelectorAll('.revision-tree__node-label'),
    ) as SVGTextElement[];
    const missingLabels = labels.filter((el) => el.textContent?.trim() === '?');
    expect(missingLabels.length).toBe(1);
  });

  it('emits nodeSelect on click', () => {
    component.nodes = [leaf('1-a', null, { isWinner: true })];
    fixture.detectChanges();
    const emissions: string[] = [];
    component.nodeSelect.subscribe((rev) => emissions.push(rev));
    const node = fixture.nativeElement.querySelector('.revision-tree__node') as HTMLElement;
    node.dispatchEvent(new MouseEvent('click'));
    expect(emissions).toEqual(['1-a']);
  });

  it('emits nodeSelect on Enter keypress', () => {
    component.nodes = [leaf('1-a', null, { isWinner: true })];
    fixture.detectChanges();
    const emissions: string[] = [];
    component.nodeSelect.subscribe((rev) => emissions.push(rev));
    const node = fixture.nativeElement.querySelector('.revision-tree__node') as HTMLElement;
    node.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true }));
    expect(emissions).toEqual(['1-a']);
  });

  it('emits nodeSelect on Space keypress', () => {
    component.nodes = [leaf('1-a', null, { isWinner: true })];
    fixture.detectChanges();
    const emissions: string[] = [];
    component.nodeSelect.subscribe((rev) => emissions.push(rev));
    const node = fixture.nativeElement.querySelector('.revision-tree__node') as HTMLElement;
    node.dispatchEvent(new KeyboardEvent('keydown', { key: ' ', bubbles: true }));
    expect(emissions).toEqual(['1-a']);
  });

  it('marks the selected rev with the selected class', () => {
    component.nodes = [
      leaf('1-a', null, { isWinner: true }),
      leaf('2-b', '1-a'),
    ];
    component.selectedRev = '2-b';
    fixture.detectChanges();
    const selected = fixture.nativeElement.querySelector('.revision-tree__node--selected');
    expect(selected).toBeTruthy();
    const ariaSelected = selected?.getAttribute('aria-selected');
    expect(ariaSelected).toBe('true');
  });

  it('sets aria-label describing rev, status, and winner role', () => {
    component.nodes = [leaf('1-a', null, { isWinner: true })];
    fixture.detectChanges();
    const node = fixture.nativeElement.querySelector('.revision-tree__node');
    const label = node?.getAttribute('aria-label') ?? '';
    expect(label).toContain('Revision 1-a');
    expect(label).toContain('available');
    expect(label).toContain('winner');
  });

  it('handles ArrowUp to move focus to parent', () => {
    component.nodes = [
      mid('1-a', null),
      leaf('2-b', '1-a', { isWinner: true }),
    ];
    fixture.detectChanges();
    component.focusedRev = '2-b';
    const container = fixture.nativeElement.querySelector('.revision-tree__scroll') as HTMLElement;
    const event = new KeyboardEvent('keydown', { key: 'ArrowUp', bubbles: true });
    container.dispatchEvent(event);
    fixture.detectChanges();
    expect(component.focusedRev).toBe('1-a');
  });

  it('handles ArrowDown to move focus to child', () => {
    component.nodes = [
      mid('1-a', null),
      leaf('2-b', '1-a', { isWinner: true }),
    ];
    fixture.detectChanges();
    component.focusedRev = '1-a';
    const container = fixture.nativeElement.querySelector('.revision-tree__scroll') as HTMLElement;
    container.dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowDown', bubbles: true }));
    fixture.detectChanges();
    expect(component.focusedRev).toBe('2-b');
  });

  it('handles ArrowRight to move to next sibling at same generation', () => {
    component.nodes = [
      mid('1-a', null),
      leaf('2-b', '1-a', { isWinner: true }),
      leaf('2-c', '1-a'),
    ];
    fixture.detectChanges();
    component.focusedRev = '2-b';
    const container = fixture.nativeElement.querySelector('.revision-tree__scroll') as HTMLElement;
    container.dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowRight', bubbles: true }));
    fixture.detectChanges();
    expect(component.focusedRev).toBe('2-c');
  });

  it('handles Tab to cycle through leaves', () => {
    component.nodes = [
      mid('1-a', null),
      leaf('2-b', '1-a', { isWinner: true }),
      leaf('2-c', '1-a'),
    ];
    fixture.detectChanges();
    component.focusedRev = '2-b';
    const container = fixture.nativeElement.querySelector('.revision-tree__scroll') as HTMLElement;
    container.dispatchEvent(new KeyboardEvent('keydown', { key: 'Tab', bubbles: true }));
    fixture.detectChanges();
    expect(component.focusedRev).toBe('2-c');
  });

  it('has a scrollable container for long chains', () => {
    const chain: RevisionNode[] = [];
    for (let i = 1; i <= 50; i++) {
      chain.push({
        rev: `${i}-rev${i}`,
        parentRev: i === 1 ? null : `${i - 1}-rev${i - 1}`,
        status: 'available',
        isLeaf: i === 50,
        isWinner: i === 50,
        branch: 0,
      });
    }
    component.nodes = chain;
    fixture.detectChanges();
    const container = fixture.nativeElement.querySelector('.revision-tree__scroll');
    const style = getComputedStyle(container);
    expect(style.overflow).toBe('auto');
    const nodes = fixture.nativeElement.querySelectorAll('.revision-tree__node');
    expect(nodes.length).toBe(50);
  });

  it('Escape dismisses an open hover popover (does not propagate to parent)', () => {
    component.nodes = [leaf('1-a', null, { isWinner: true })];
    fixture.detectChanges();
    component.focusedRev = '1-a';
    // Open a popover directly.
    const nodeEl = fixture.nativeElement.querySelector('.revision-tree__node') as HTMLElement;
    component.showPopover(component.layout.nodes[0], { currentTarget: nodeEl } as any);
    expect((component as any).overlayRef).toBeTruthy();
    // Dispatch Escape from the scroll container.
    const container = fixture.nativeElement.querySelector('.revision-tree__scroll') as HTMLElement;
    const event = new KeyboardEvent('keydown', { key: 'Escape', bubbles: true, cancelable: true });
    container.dispatchEvent(event);
    expect((component as any).overlayRef).toBeNull();
    // Event should have been stopped so the parent view's Esc does not fire.
    expect(event.defaultPrevented).toBe(true);
  });

  it('is axe-clean in the loaded state', async () => {
    component.nodes = [
      mid('1-a', null),
      leaf('2-b', '1-a', { isWinner: true }),
      leaf('2-c', '1-a', { status: 'deleted' }),
    ];
    fixture.detectChanges();
    await expectNoAxeViolations(fixture.nativeElement);
  });

  it('is axe-clean in the loading state', async () => {
    component.loading = true;
    fixture.detectChanges();
    await expectNoAxeViolations(fixture.nativeElement);
  });

  it('is axe-clean in the empty state', async () => {
    component.nodes = [];
    fixture.detectChanges();
    await expectNoAxeViolations(fixture.nativeElement);
  });

  it('is axe-clean with a missing-ancestor tree', async () => {
    component.nodes = [
      { rev: '1-missing', parentRev: null, status: 'missing', isLeaf: false, isWinner: false, branch: 0 },
      leaf('2-a', '1-missing', { isWinner: true }),
    ];
    fixture.detectChanges();
    await expectNoAxeViolations(fixture.nativeElement);
  });
});
