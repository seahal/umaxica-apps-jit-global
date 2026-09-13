// Shared Vitest setup for frontend specs.
import { cleanup } from "@testing-library/react";
import { afterEach } from "vitest";

// Testing Library keeps every rendered tree in the document until it is told otherwise. React Aria
// renders overlays into a portal on `document.body`, outside the container a spec mounted, so
// without this a dialog from one test is still in the DOM while the next one queries it.
afterEach(() => {
  cleanup();
});

// jsdom implements no scrolling at all, so `Element.prototype.scrollTo` is simply absent. React
// Aria calls it to bring the focused collection item into view, which throws out of an animation
// frame — outside any test's call stack, where it surfaces as an unhandled error rather than a
// failure. There is nothing to assert about scrolling in a layout-less DOM, so the no-op stands in
// for the browser behaviour. This shim exists only in the test environment; no application code
// knows about it.
if (typeof Element !== "undefined" && typeof Element.prototype.scrollTo !== "function") {
  Element.prototype.scrollTo = () => {};
}

// jsdom implements no CSS media queries, so `window.matchMedia` is absent. Theme code asks it for
// the operating system's colour scheme, and a missing function is a TypeError rather than a
// meaningful failure. The stand-in reports "not dark", which is the light default; a spec that
// cares about the dark branch overrides it for its own duration. This shim exists only in the test
// environment; no application code knows about it.
if (typeof window !== "undefined" && typeof window.matchMedia !== "function") {
  window.matchMedia = (query: string): MediaQueryList => {
    const list: MediaQueryList = {
      matches: false,
      media: query,
      onchange: null,
      addEventListener: () => {},
      removeEventListener: () => {},
      // lib.dom still declares these on MediaQueryList, so a value of that type has to carry them
      // even though nothing calls them.
      // oxlint-disable-next-line typescript/no-deprecated
      addListener: () => {},
      // oxlint-disable-next-line typescript/no-deprecated
      removeListener: () => {},
      dispatchEvent: () => false,
    };
    return list;
  };
}

// jsdom implements no Cookie Store API, so `window.cookieStore` is absent while `document.cookie`
// works. Application code reads cookies only through the store now, so without this every read
// throws the "unavailable" error the real API's absence is meant to report. The stand-in is backed
// by `document.cookie`, which keeps one cookie jar in a spec: a test may write with either and read
// with the other. Only what the application uses is implemented - reads, plus the writes and the
// change event a spec needs to drive them. This shim exists only in the test environment; no
// application code knows about it.
const cookieJar = (): { name: string; value: string }[] =>
  document.cookie
    .split(";")
    .map((part) => part.trim())
    .filter((part) => part.length > 0)
    .map((part) => {
      const separator = part.indexOf("=");
      return separator === -1
        ? { name: part, value: "" }
        : { name: part.slice(0, separator), value: part.slice(separator + 1) };
    });

if (typeof window !== "undefined" && typeof window.cookieStore === "undefined") {
  const changes = new EventTarget();

  const announce = (changed: { name: string; value: string }[], deleted: { name: string }[]) => {
    const event = new Event("change");
    Object.defineProperties(event, {
      changed: { value: changed },
      deleted: { value: deleted },
    });
    changes.dispatchEvent(event);
  };

  const store = {
    get: (options: string | { name?: string }) => {
      const name = typeof options === "string" ? options : (options.name ?? "");
      return Promise.resolve(cookieJar().find((cookie) => cookie.name === name) ?? null);
    },
    getAll: () => Promise.resolve(cookieJar()),
    set: (options: string | { name: string; value: string }, value?: string) => {
      const cookie = typeof options === "string" ? { name: options, value: value ?? "" } : options;
      document.cookie = `${cookie.name}=${cookie.value}; path=/`;
      announce([cookie], []);
      return Promise.resolve();
    },
    delete: (options: string | { name: string }) => {
      const name = typeof options === "string" ? options : options.name;
      document.cookie = `${name}=; path=/; expires=Thu, 01 Jan 1970 00:00:00 GMT`;
      announce([], [{ name }]);
      return Promise.resolve();
    },
    addEventListener: changes.addEventListener.bind(changes),
    removeEventListener: changes.removeEventListener.bind(changes),
    dispatchEvent: changes.dispatchEvent.bind(changes),
    onchange: null,
  };

  Object.defineProperty(window, "cookieStore", { value: store, configurable: true });
}

export const specSetup = {};
