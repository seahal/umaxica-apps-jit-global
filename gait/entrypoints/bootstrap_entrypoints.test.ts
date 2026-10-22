import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

// These entrypoints are thin bootstrap wrappers: each either imports the shared "../application"
// module (which wires Turbo, Stimulus controllers, and React islands) and/or registers the offline
// service worker for its origin. Importing them here verifies the wiring itself - that each
// surface entrypoint actually calls the registration functions it depends on - without exercising
// the real Turbo/service-worker machinery, which is unit-tested independently elsewhere (see
// gait/pwa/register.test.ts, gait/controllers/index.test.js, gait/entrypoints/react_islands.test.ts).

const registerOfflineServiceWorker = vi.fn();
const sharedApplicationLoaded = vi.fn();

vi.mock("../../src/pwa/register", () => ({
  registerOfflineServiceWorker,
}));

// Registered per test: `vi.resetModules()` keeps a hoisted mock's evaluated module, so only a fresh
// `doMock` re-runs the factory and lets each import report whether it loaded the shared bootstrap.
beforeEach(() => {
  vi.doMock("../../src/entrypoints/application", () => {
    sharedApplicationLoaded();
    return {};
  });
});

afterEach(() => {
  vi.resetModules();
  registerOfflineServiceWorker.mockClear();
  sharedApplicationLoaded.mockClear();
});

describe.each([
  ["base/app", "../../src/entrypoints/base/app.ts"],
  ["base/com", "../../src/entrypoints/base/com.ts"],
  ["base/org", "../../src/entrypoints/base/org.ts"],
  ["sign/app", "../../src/entrypoints/sign/app.ts"],
  ["sign/com", "../../src/entrypoints/sign/com.ts"],
  ["sign/org", "../../src/entrypoints/sign/org.ts"],
])("%s entrypoint", (_surface, modulePath) => {
  it("imports the shared application bootstrap and registers the offline service worker", async () => {
    await import(modulePath);

    expect(sharedApplicationLoaded).toHaveBeenCalledTimes(1);
    expect(registerOfflineServiceWorker).toHaveBeenCalledTimes(1);
  });
});

describe.each([
  ["warp/app", "../../src/entrypoints/warp/app.ts"],
  ["warp/com", "../../src/entrypoints/warp/com.ts"],
  ["warp/org", "../../src/entrypoints/warp/org.ts"],
  ["palm/app", "../../src/entrypoints/palm/app.ts"],
])("%s entrypoint", (_surface, modulePath) => {
  it("registers the offline service worker without pulling in the Turbo application bundle", async () => {
    await import(modulePath);

    expect(sharedApplicationLoaded).not.toHaveBeenCalled();
    expect(registerOfflineServiceWorker).toHaveBeenCalledTimes(1);
  });
});

describe("core/dev entrypoint", () => {
  it("imports the shared application bootstrap without registering an offline service worker", async () => {
    await import("../../src/entrypoints/core/dev.ts");

    expect(sharedApplicationLoaded).toHaveBeenCalledTimes(1);
    expect(registerOfflineServiceWorker).not.toHaveBeenCalled();
  });
});
