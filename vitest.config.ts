import { fileURLToPath, URL } from "node:url";

import { defaultExclude, defineConfig } from "vitest/config";

const srcRoot = fileURLToPath(new URL("./src", import.meta.url));

// Files whose behavior does not depend on a DOM: pure logic, and React components exercised only
// through `renderToStaticMarkup`. Kept as an explicit list so the unit project stays DOM-free.
const nodeSpecs = [
  "spec/lib/payload.test.ts",
  "spec/entrypoints/application.test.ts",
  "spec/entrypoints/bootstrap_entrypoints.test.ts",
  "spec/controllers/webauthn_utils.test.ts",
  "spec/features/auth/passkeys/messages.test.ts",
  "spec/features/landing/surface_root_landing.test.tsx",
  "spec/pages/base/app/groups/index.test.tsx",
  "spec/features/preferences/preference_index.test.tsx",
  "spec/features/landing/root_landing.test.tsx",
  "spec/features/auth/auth_com_screens.test.tsx",
  "spec/pages/base/app/identity/identity_pages.test.tsx",
  "spec/features/dashboards/side_dashboard.test.tsx",
  "spec/features/base_com/base_com_identity_pages.test.tsx",
  "spec/features/auth/session/sign_out_screens.test.tsx",
  "spec/features/auth/dashboard/surface_dashboard.test.tsx",
  "spec/features/identity/activity_index.test.tsx",
  "spec/pages/auth/app/settings/settings_screens.test.tsx",
  "spec/pages/palm/app/sign_outs/show.test.tsx",
  "spec/features/preferences/preference_screens.test.tsx",
  "spec/features/auth/signin/signin_screens.test.tsx",
  "spec/features/auth/auth_com_signup_screens.test.tsx",
  "spec/features/auth/verification/verification_screens.test.tsx",
].map((path) => fileURLToPath(new URL(`./${path}`, import.meta.url)));

const sharedProjectDefaults = {
  allowOnly: false,
  retry: 0,
  isolate: true,
  fileParallelism: true,
  mockReset: true,
  restoreMocks: true,
  unstubEnvs: true,
  unstubGlobals: true,
  globals: true,
  testTimeout: 5_000,
  hookTimeout: 5_000,
} as const;

export default defineConfig({
  resolve: {
    // Must stay identical to the alias in vite.config.ts and to `paths` in tsconfig.app.json.
    alias: { "@": srcRoot },
  },
  test: {
    // Fail-closed run-level defaults.
    //
    // - passWithNoTests: false -- an empty run (a bad `--project` filter, a typo'd path) fails
    //   instead of reading as a green, zero-test pass.
    // - dangerouslyIgnoreUnhandledErrors: false -- an unhandled rejection or thrown error outside
    //   an assertion fails the run instead of being swallowed.
    // - teardownTimeout -- a hook that never resolves fails fast and names itself, instead of
    //   hanging until CI's own outer timeout kills the whole job with nothing attributed.
    passWithNoTests: false,
    dangerouslyIgnoreUnhandledErrors: false,
    teardownTimeout: 5_000,
    slowTestThreshold: 1_000,
    fileParallelism: true,
    // Two projects: Node for pure/static-markup specs, jsdom for DOM-dependent specs. jsdom is
    // used instead of Vitest Browser Mode because several specs stub `window`/`location`, which
    // are non-configurable in a real Chromium tab. Cookie Store / matchMedia / scrollTo gaps are
    // filled by spec/setup.ts.
    projects: [
      {
        extends: true,
        test: {
          ...sharedProjectDefaults,
          name: "unit",
          environment: "node",
          include: nodeSpecs,
          setupFiles: [],
        },
      },
      {
        extends: true,
        test: {
          ...sharedProjectDefaults,
          name: "component",
          environment: "jsdom",
          include: ["spec/**/*.{test,spec}.{ts,tsx,js,jsx}"],
          exclude: [...defaultExclude, ...nodeSpecs],
          setupFiles: ["./spec/setup.ts"],
        },
      },
    ],
    coverage: {
      provider: "v8",
      reportsDirectory: "coverage/vite",
      // HTML is kept for local debugging; text/lcov/json-summary are the machine-readable formats
      // CI and any future coverage-diff tooling read.
      reporter: ["text", "html", "lcov", "json-summary"],
      include: ["src/**/*.{js,ts,jsx,tsx}"],
      // v8 coverage only sees a file once some project imports it, but with `coverage.include`
      // set (as it is here), Vitest still counts every file matching that glob even when nothing
      // imports it -- an untested source file is a visible 0%-covered file in the report and
      // appears as 0%-covered instead of silently missing from the denominator.
      exclude: [
        "src/**/*.d.ts",
        "src/**/*.stories.{ts,tsx,js,jsx}",
        "src/**/__fixtures__/**",
        "**/node_modules/**",
        "**/dist/**",
        "**/build/**",
        "**/coverage/**",
        "public/vite/**",
      ],
      thresholds: {
        statements: 99,
        branches: 99,
        functions: 99,
        lines: 99,
      },
    },
  },
});
