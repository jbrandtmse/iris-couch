import { TestBed } from '@angular/core/testing';
import { ActivatedRouteSnapshot, RouterStateSnapshot } from '@angular/router';
import { firstValueFrom, of } from 'rxjs';
import { unsavedChangesGuard, HasUnsavedChanges } from './unsaved-changes.guard';

class CleanComponent implements HasUnsavedChanges {
  hasUnsavedChanges(): boolean {
    return false;
  }
  confirmDiscard(): Promise<boolean> {
    throw new Error('should not be called when clean');
  }
}

class DirtyComponent implements HasUnsavedChanges {
  promptResult: boolean | Promise<boolean> = false;
  promptCalls = 0;
  hasUnsavedChanges(): boolean {
    return true;
  }
  confirmDiscard(): Promise<boolean> | any {
    this.promptCalls++;
    return Promise.resolve(this.promptResult);
  }
}

class DirtyObservableComponent implements HasUnsavedChanges {
  hasUnsavedChanges(): boolean {
    return true;
  }
  confirmDiscard() {
    return of(true);
  }
}

class NotImplementing {
  // No methods at all
}

describe('unsavedChangesGuard', () => {
  // Per Angular 18 functional-guard test pattern: invoke the guard directly,
  // passing the component plus stubs for the route/state args.
  function runGuard(component: unknown) {
    return TestBed.runInInjectionContext(() =>
      unsavedChangesGuard(
        component,
        {} as ActivatedRouteSnapshot,
        {} as RouterStateSnapshot,
        {} as RouterStateSnapshot,
      ),
    );
  }

  it('allows navigation when component does not implement HasUnsavedChanges', () => {
    const result = runGuard(new NotImplementing());
    expect(result).toBeTrue();
  });

  it('allows navigation when component is null/undefined', () => {
    expect(runGuard(null)).toBeTrue();
    expect(runGuard(undefined)).toBeTrue();
  });

  it('allows navigation when there are no unsaved changes', () => {
    const result = runGuard(new CleanComponent());
    expect(result).toBeTrue();
  });

  it('returns the prompt observable/promise when there are unsaved changes', async () => {
    const dirty = new DirtyComponent();
    dirty.promptResult = false;
    const result = runGuard(dirty);
    // Promise<boolean>
    const decision = await Promise.resolve(result as Promise<boolean>);
    expect(decision).toBeFalse();
    expect(dirty.promptCalls).toBe(1);
  });

  it('resolves true when the prompt resolves true', async () => {
    const dirty = new DirtyComponent();
    dirty.promptResult = true;
    const decision = await Promise.resolve(runGuard(dirty) as Promise<boolean>);
    expect(decision).toBeTrue();
  });

  it('handles Observable-returning prompts', async () => {
    const result = runGuard(new DirtyObservableComponent());
    const decision = await firstValueFrom(result as any);
    expect(decision).toBeTrue();
  });
});
