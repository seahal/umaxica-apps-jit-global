// Mounting a React component the way the page does, and driving it with real DOM events.
//
// Testing Library covers the component specs that only query rendered output. These helpers exist
// for the specs that drive a ceremony: they need `act` around each step, a container they can query
// with CSS selectors, and the prototype-setter trick a controlled input requires. Centralising them
// keeps that knowledge in one place rather than at the top of every ceremony spec.
import { act } from "react";
import { createRoot, type Root } from "react-dom/client";
import { afterEach, expect } from "vitest";

declare global {
  // React reads this flag off the global object to decide whether `act` is allowed.
  var IS_REACT_ACT_ENVIRONMENT: boolean;
}

globalThis.IS_REACT_ACT_ENVIRONMENT = true;

export type Mounted = {
  container: HTMLElement;
  /** Sets a controlled input's value the way a keystroke does. */
  type: (selector: string, value: string) => void;
  /** Clicks the first element matching `selector`, failing when nothing matches. */
  click: (selector: string) => void;
  /** The text of the first element matching `selector`, or `null` when nothing matches. */
  text: (selector: string) => string | null;
  /** Lets the queued promises of an async handler settle. */
  flush: () => Promise<void>;
  /** Unmounts the tree, for the specs that assert on effect cleanup. */
  unmount: () => void;
};

let mounted: { root: Root; container: HTMLElement } | null = null;

afterEach(() => {
  const current = mounted;
  mounted = null;
  if (current) {
    act(() => {
      current.root.unmount();
    });
    current.container.remove();
  }
});

export function mount(element: React.ReactElement): Mounted {
  const container = document.createElement("div");
  document.body.append(container);
  const root = createRoot(container);
  act(() => {
    root.render(element);
  });
  mounted = { root, container };

  return {
    container,

    // React tracks the previous value of a controlled input, so assigning `value` directly is
    // ignored. Going through the prototype setter clears that tracker, which is what a real
    // keystroke does.
    type: (selector: string, value: string) => {
      const input = container.querySelector<HTMLInputElement>(selector);
      const descriptor = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, "value");
      expect(input).not.toBeNull();
      act(() => {
        if (input && descriptor?.set) {
          descriptor.set.call(input, value);
          input.dispatchEvent(new Event("input", { bubbles: true }));
        }
      });
    },

    click: (selector: string) => {
      const target = container.querySelector<HTMLElement>(selector);
      expect(target).not.toBeNull();
      act(() => {
        target?.dispatchEvent(new MouseEvent("click", { bubbles: true }));
      });
    },

    text: (selector: string) => container.querySelector(selector)?.textContent ?? null,

    flush: async () => {
      await act(async () => {
        await Promise.resolve();
        await Promise.resolve();
        await Promise.resolve();
      });
    },

    unmount: () => {
      mounted = null;
      act(() => {
        root.unmount();
      });
      container.remove();
    },
  };
}
