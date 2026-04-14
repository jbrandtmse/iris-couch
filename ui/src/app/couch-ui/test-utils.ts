/**
 * Accessibility test utilities for couch-ui component specs.
 * Wraps axe-core for use with Jasmine + Angular TestBed.
 */
import axe, { AxeResults, RunOptions } from 'axe-core';

/**
 * Run axe-core accessibility checks against a DOM element.
 * Returns the full AxeResults for custom assertions.
 */
export async function runAxe(
  element: HTMLElement,
  options?: RunOptions
): Promise<AxeResults> {
  return axe.run(element, options ?? {});
}

/**
 * Assert that a DOM element has no axe-core violations.
 * Always registers at least one Jasmine expect() so the spec
 * is not flagged as having "no expectations".
 *
 * Usage in Jasmine:
 *   await expectNoAxeViolations(fixture.nativeElement);
 */
export async function expectNoAxeViolations(
  element: HTMLElement,
  options?: RunOptions
): Promise<void> {
  const results = await runAxe(element, options);
  const violations = results.violations;

  if (violations.length > 0) {
    const messages = violations.map(
      (v) =>
        `[${v.impact}] ${v.id}: ${v.description}\n` +
        v.nodes.map((n) => `  - ${n.html}\n    ${n.failureSummary}`).join('\n')
    );
    expect(violations.length)
      .withContext(`Axe-core violations:\n${messages.join('\n\n')}`)
      .toBe(0);
  } else {
    expect(violations.length).toBe(0);
  }
}
