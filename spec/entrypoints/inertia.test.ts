import { createInertiaApp } from "@inertiajs/react";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";

import {
  bootSurfaceInertiaApp,
  reportInertiaBootFailure,
  surfaceInertiaDefaults,
  surfacePageResolver,
} from "@/inertia/surface";

import { present } from "../support/present";

vi.mock("@inertiajs/react", () => ({
  createInertiaApp: vi.fn(() => Promise.reject(new Error("test inertia error"))),
  // The entrypoint globs every page of its surface, and the features behind them navigate.
  router: { on: vi.fn(() => () => {}) },
}));

// `createInertiaApp`'s real declaration is a three-overload union keyed on `render`/`setup`, so
// the mock records its argument as the union. Narrowing it with a guard rather than an assertion
// means a change to what an entrypoint actually passes fails here instead of being asserted onto.
type SurfaceInertiaConfig = {
  resolve: (name: string) => { default: { layout?: unknown } };
  strictMode: boolean;
  defaults: typeof surfaceInertiaDefaults;
};

function isSurfaceInertiaConfig(value: unknown): value is SurfaceInertiaConfig {
  if (typeof value !== "object" || value === null) {
    return false;
  }

  return (
    typeof Reflect.get(value, "resolve") === "function" &&
    typeof Reflect.get(value, "strictMode") === "boolean" &&
    typeof Reflect.get(value, "defaults") === "object"
  );
}

/** The options an entrypoint handed `createInertiaApp`, or a failure naming what it handed. */
function capturedConfig(value: unknown): SurfaceInertiaConfig {
  if (!isSurfaceInertiaConfig(value)) {
    throw new Error(`The entrypoint passed createInertiaApp something else: ${String(value)}`);
  }

  return value;
}

type PageModuleFixture = { default: { (): null; layout?: unknown } };

function pageModules(surface: string, names: string[]): Record<string, PageModuleFixture> {
  return Object.fromEntries(
    names.map((name) => [`../../pages/${surface}/${name}.tsx`, { default: () => null }]),
  );
}

const LAYOUT = () => null;

const own = () => null;

describe("surface page resolver", () => {
  test("resolves a page of its own surface from the surface-scoped glob", () => {
    const resolve = surfacePageResolver(
      pageModules("base/app", ["groups/index"]),
      "base/app",
      LAYOUT,
    );

    expect(resolve("base/app/groups/index")).toBeDefined();
  });

  test("attaches the surface layout so no page can render without chrome", () => {
    const resolve = surfacePageResolver(
      pageModules("base/app", ["groups/index"]),
      "base/app",
      LAYOUT,
    );

    expect(resolve("base/app/groups/index").default.layout).toEqual([LAYOUT]);
  });

  test("keeps a layout a page declared for itself", () => {
    const modules = pageModules("base/app", ["groups/index"]);
    present(
      modules["../../pages/base/app/groups/index.tsx"],
      "the globbed groups/index page module",
    ).default.layout = [own];
    const resolve = surfacePageResolver(modules, "base/app", LAYOUT);

    expect(resolve("base/app/groups/index").default.layout).toEqual([own]);
  });

  test("rejects a page belonging to another surface instead of attempting to resolve it", () => {
    const resolve = surfacePageResolver(
      pageModules("base/app", ["groups/index"]),
      "base/app",
      LAYOUT,
    );

    expect(() => resolve("base/com/groups/index")).toThrow(
      /does not belong to the "base\/app" surface/u,
    );
  });

  test("rejects an unqualified page name so a missing prefix is not silently accepted", () => {
    const resolve = surfacePageResolver(
      pageModules("auth/org", ["groups/index"]),
      "auth/org",
      LAYOUT,
    );

    expect(() => resolve("groups/index")).toThrow(/does not belong to the "auth\/org" surface/u);
  });

  test("rejects a globbed file that is not a page module", () => {
    expect(() =>
      surfacePageResolver(
        { "../../pages/base/app/groups/index.tsx": { named: true } },
        "base/app",
        LAYOUT,
      ),
    ).toThrow(/has no default export/u);
  });

  test("fails loudly when the surface has no component for a page the controller rendered", () => {
    const resolve = surfacePageResolver(
      pageModules("base/app", ["groups/index"]),
      "base/app",
      LAYOUT,
    );

    expect(() => resolve("base/app/groups/show")).toThrow(
      /has no component in src\/pages\/base\/app/u,
    );
  });
});

describe("surface inertia defaults", () => {
  test("visits use bracket array syntax so Rack parses array parameters", () => {
    expect(surfaceInertiaDefaults.visitOptions()).toEqual({ queryStringArrayFormat: "brackets" });
  });
});

describe("reportInertiaBootFailure", () => {
  afterEach(() => {
    document.body.innerHTML = "";
  });

  test("rethrows the original error when the Inertia root element is present", () => {
    document.body.innerHTML = '<div id="app"></div>';
    const error = new Error("boot failed for an unrelated reason");

    expect(() => reportInertiaBootFailure(error)).toThrow(error);
  });
});

describe("document theme across visits", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  afterEach(() => {
    document.cookie = "ct=; path=/; max-age=0";
    delete document.documentElement.dataset["theme"];
  });

  test("applies the cookie theme on boot and again whenever the cookie changes", async () => {
    // Without the root element the boot rejection is reported rather than thrown, which is what
    // this test wants: the theme wiring runs before `createInertiaApp` is ever called.
    document.body.innerHTML = "";
    const nonceMeta = document.createElement("meta");
    nonceMeta.setAttribute("property", "csp-nonce");
    nonceMeta.nonce = "test-nonce";
    document.head.append(nonceMeta);
    const errorSpy = vi.spyOn(console, "error").mockImplementation(() => {});
    document.cookie = "ct=dr; path=/";

    await bootSurfaceInertiaApp({}, "base/app");

    // The cookie read is asynchronous through the Cookie Store API, so the attribute is written a
    // tick after boot returns rather than during it.
    await vi.waitFor(() => expect(document.documentElement.dataset["theme"]).toBe("dark"));

    // The theme preference screen writes the cookie server-side, and the cookie store reports that
    // write directly - no visit has to happen for the document to learn its colours changed.
    await cookieStore.set({ name: "ct", value: "li" });

    await vi.waitFor(() => expect(document.documentElement.dataset["theme"]).toBe("light"));

    errorSpy.mockRestore();
    nonceMeta.remove();
  });

  test("omits the nonce when the layout published an empty one", async () => {
    document.body.innerHTML = "";
    for (const meta of document.querySelectorAll('meta[property="csp-nonce"]')) {
      meta.remove();
    }
    const nonceMeta = document.createElement("meta");
    nonceMeta.setAttribute("property", "csp-nonce");
    Object.defineProperty(nonceMeta, "nonce", { configurable: true, get: () => "" });
    document.head.append(nonceMeta);
    const errorSpy = vi.spyOn(console, "error").mockImplementation(() => {});

    await bootSurfaceInertiaApp({}, "base/app");

    expect(createInertiaApp).toHaveBeenCalled();
    expect(vi.mocked(createInertiaApp).mock.calls.at(-1)?.[0]).not.toHaveProperty("nonce");
    errorSpy.mockRestore();
    nonceMeta.remove();
  });

  test("omits the nonce when the layout published none", async () => {
    document.body.innerHTML = "";
    for (const meta of document.querySelectorAll('meta[property="csp-nonce"]')) {
      meta.remove();
    }
    const errorSpy = vi.spyOn(console, "error").mockImplementation(() => {});

    await bootSurfaceInertiaApp({}, "base/app");

    expect(createInertiaApp).toHaveBeenCalled();
    expect(vi.mocked(createInertiaApp).mock.calls.at(-1)?.[0]).not.toHaveProperty("nonce");
    errorSpy.mockRestore();
  });
});

// Importing an entrypoint is genuinely expensive: each one eagerly globs every page module of its
// surface and pulls in SurfaceLayout's whole tree. On a loaded machine that exceeds Vitest's 5s
// default, and a timeout mid-import leaves the *next* test's mocks uninitialised, so it fails too —
// which is why this file failed in pairs under contention. The work is real rather than hung, so
// the budget is raised rather than the import trimmed or the assertion loosened.
const ENTRYPOINT_IMPORT_TIMEOUT_MS = 30_000;

describe("surface inertia entrypoint", () => {
  beforeEach(() => {
    vi.resetModules();
    vi.clearAllMocks();
  });

  test(
    "logs a configuration error when loaded from a layout without the Inertia root element",
    async () => {
      document.body.innerHTML = "";
      const errorSpy = vi.spyOn(console, "error").mockImplementation(() => {});

      await import("../../src/entrypoints/inertia/base_app.tsx");
      await Promise.resolve();

      expect(errorSpy).toHaveBeenCalledWith(
        expect.stringContaining("Missing Inertia root element"),
      );
      errorSpy.mockRestore();
    },
    ENTRYPOINT_IMPORT_TIMEOUT_MS,
  );
});

describe.each([
  ["auth/app", "../../src/entrypoints/inertia/auth_app.tsx"],
  ["auth/com", "../../src/entrypoints/inertia/auth_com.tsx"],
  ["auth/org", "../../src/entrypoints/inertia/auth_org.tsx"],
  ["base/com", "../../src/entrypoints/inertia/base_com.tsx"],
  ["base/org", "../../src/entrypoints/inertia/base_org.tsx"],
  ["palm/app", "../../src/entrypoints/inertia/palm_app.tsx"],
  ["side/app", "../../src/entrypoints/inertia/side_app.tsx"],
  ["side/com", "../../src/entrypoints/inertia/side_com.tsx"],
  ["side/org", "../../src/entrypoints/inertia/side_org.tsx"],
  ["core/app", "../../src/entrypoints/inertia/core_app.tsx"],
  ["core/com", "../../src/entrypoints/inertia/core_com.tsx"],
  ["core/dev", "../../src/entrypoints/inertia/core_dev.tsx"],
  ["core/org", "../../src/entrypoints/inertia/core_org.tsx"],
])("%s inertia entrypoint", (surface, modulePath) => {
  beforeEach(() => {
    vi.resetModules();
    vi.clearAllMocks();
  });

  test(
    "wires createInertiaApp to a resolver scoped to its own surface",
    async () => {
      await import(modulePath);
      await Promise.resolve();

      expect(createInertiaApp).toHaveBeenCalledTimes(1);

      const config = capturedConfig(vi.mocked(createInertiaApp).mock.calls[0]?.[0]);

      expect(config.strictMode).toBe(true);
      expect(config.defaults.visitOptions()).toEqual(surfaceInertiaDefaults.visitOptions());
      // The resolver is built for this surface only, so another surface's page is refused.
      expect(() => config.resolve("other/surface/groups/index")).toThrow(
        new RegExp(`does not belong to the "${surface}" surface`, "u"),
      );
    },
    ENTRYPOINT_IMPORT_TIMEOUT_MS,
  );
});
