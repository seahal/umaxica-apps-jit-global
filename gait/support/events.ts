// Collecting the CustomEvents a controller dispatches.
//
// A spec that filters events inline needs a conditional in its body, which `vitest/no-conditional-
// in-test` forbids for good reason: a branch in a test is a path the test may quietly not take.
// The narrowing belongs in a helper, where it runs the same way every time.
export type EventRecorder = {
  readonly events: CustomEvent<unknown>[];
  readonly last: () => CustomEvent<unknown> | undefined;
  readonly detail: () => unknown;
};

/** Records every `type` event dispatched on `target` until the spec ends. */
export function recordEvents(target: EventTarget, type: string): EventRecorder {
  const events: CustomEvent<unknown>[] = [];

  target.addEventListener(type, (event) => {
    if (event instanceof CustomEvent) {
      events.push(event);
    }
  });

  return {
    events,
    last: () => events.at(-1),
    detail: (): unknown => events.at(-1)?.detail,
  };
}
