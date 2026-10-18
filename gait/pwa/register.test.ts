import { type MockInstance, afterEach, beforeEach, describe, expect, it, vi } from "vitest";

// Each test re-imports the module so the memoised registration promise starts empty.
const loadRegister = async () => {
  vi.resetModules();
  return import("../../src/pwa/register");
};

const setServiceWorkerContainer = (container: unknown) => {
  if (container === undefined) {
    Reflect.deleteProperty(navigator, "serviceWorker");
    return;
  }

  Object.defineProperty(navigator, "serviceWorker", {
    configurable: true,
    value: container,
    writable: true,
  });
};

const setSecureContext = (secure: boolean) => {
  Object.defineProperty(window, "isSecureContext", {
    configurable: true,
    value: secure,
    writable: true,
  });
};

describe("registerOfflineServiceWorker", () => {
  let consoleError: MockInstance<typeof console.error>;

  beforeEach(() => {
    consoleError = vi.spyOn(console, "error").mockImplementation(() => {});
    setSecureContext(true);
  });

  afterEach(() => {
    consoleError.mockRestore();
    setServiceWorkerContainer(undefined);
  });

  it("resolves to null without reporting an error when the browser has no service worker support", async () => {
    setServiceWorkerContainer(undefined);

    const { registerOfflineServiceWorker } = await loadRegister();

    await expect(registerOfflineServiceWorker()).resolves.toBeNull();
    expect(consoleError).not.toHaveBeenCalled();
  });

  it("registers the root-scoped worker and bypasses the http cache for the script", async () => {
    const registration = { scope: "https://base.app.localhost/" };
    const register = vi.fn().mockResolvedValue(registration);
    setServiceWorkerContainer({ register });

    const { registerOfflineServiceWorker } = await loadRegister();

    await expect(registerOfflineServiceWorker()).resolves.toBe(registration);
    expect(register).toHaveBeenCalledWith("/service-worker", {
      scope: "/",
      updateViaCache: "none",
    });
  });

  it("registers once per document even when called repeatedly", async () => {
    const register = vi.fn().mockResolvedValue({});
    setServiceWorkerContainer({ register });

    const { registerOfflineServiceWorker } = await loadRegister();

    const first = registerOfflineServiceWorker();
    const second = registerOfflineServiceWorker();

    await Promise.all([first, second]);

    expect(first).toBe(second);
    expect(register).toHaveBeenCalledTimes(1);
  });

  it("reports a failed registration instead of swallowing it, and does not rethrow", async () => {
    const failure = new Error("SecurityError");
    const register = vi.fn().mockRejectedValue(failure);
    setServiceWorkerContainer({ register });

    const { registerOfflineServiceWorker } = await loadRegister();

    await expect(registerOfflineServiceWorker()).resolves.toBeNull();
    expect(consoleError).toHaveBeenCalledWith(expect.stringContaining("/service-worker"), failure);
  });

  it("reports rather than attempts registration outside a secure context", async () => {
    const register = vi.fn();
    setServiceWorkerContainer({ register });
    setSecureContext(false);

    const { registerOfflineServiceWorker } = await loadRegister();

    await expect(registerOfflineServiceWorker()).resolves.toBeNull();
    expect(register).not.toHaveBeenCalled();
    expect(consoleError).toHaveBeenCalledWith(expect.stringContaining("not a secure context"));
  });

  it("does not touch the document, so it is safe on pages with no Inertia root", async () => {
    document.body.innerHTML = "<p>plain server rendered page</p>";
    const register = vi.fn().mockResolvedValue({});
    setServiceWorkerContainer({ register });

    const { registerOfflineServiceWorker } = await loadRegister();

    await registerOfflineServiceWorker();

    expect(document.querySelector("#app")).toBeNull();
    expect(document.body.innerHTML).toBe("<p>plain server rendered page</p>");
  });
});
