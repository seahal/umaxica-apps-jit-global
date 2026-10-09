import { beforeEach, describe, expect, test, vi } from "vitest";

describe("Stimulus application bootstrap", () => {
  beforeEach(() => {
    vi.stubGlobal("window", { location: { hostname: "www.umaxica.app" } });
    vi.resetModules();
  });

  test("exports the Stimulus application and exposes it on window", async () => {
    const { application } = await import("../../src/controllers/application.js");

    expect(application).toBeDefined();
    expect(window.Stimulus).toBe(application);
  });

  test("enables debug mode on localhost", async () => {
    vi.stubGlobal("window", { location: { hostname: "localhost" } });

    const { application } = await import("../../src/controllers/application.js");

    expect(application.debug).toBe(true);
  });

  test("enables debug mode on 127.0.0.1", async () => {
    vi.stubGlobal("window", { location: { hostname: "127.0.0.1" } });

    const { application } = await import("../../src/controllers/application.js");

    expect(application.debug).toBe(true);
  });

  test("disables debug mode on production hosts", async () => {
    vi.stubGlobal("window", { location: { hostname: "www.umaxica.app" } });

    const { application } = await import("../../src/controllers/application.js");

    expect(application.debug).toBe(false);
  });
});
