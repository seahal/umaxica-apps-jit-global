import { randomBytes, randomUUID } from "node:crypto";

import { defineConfig, devices } from "playwright/test";

import { railsOrigin } from "./e2e/rails/settings";

const inheritedEnvironment = process.env["RAILS_ENV"];
if (inheritedEnvironment !== undefined && inheritedEnvironment !== "test") {
  throw new Error("Rails E2E refuses RAILS_ENV other than test");
}
const runId = `rails-e2e-${randomUUID()}`;
const chromiumExecutablePath = process.env["PLAYWRIGHT_CHROMIUM_EXECUTABLE"];

export default defineConfig({
  testDir: "./e2e/rails",
  fullyParallel: false,
  workers: 1,
  forbidOnly: true,
  retries: 0,
  reporter: [["list"]],
  outputDir: "tmp/e2e-rails/results",
  use: {
    baseURL: railsOrigin,
    headless: true,
    serviceWorkers: "block",
    screenshot: "only-on-failure",
    trace: "retain-on-failure",
  },
  projects: [
    {
      name: "rails-chromium",
      use: {
        ...devices["Desktop Chrome"],
        launchOptions: {
          args: ["--host-resolver-rules=MAP auth.app.localhost 127.0.0.1"],
          ...(chromiumExecutablePath === undefined
            ? {}
            : {
                executablePath: chromiumExecutablePath,
                chromiumSandbox: true,
              }),
        },
      },
    },
  ],
  webServer: {
    command: "bundle exec ruby scripts/e2e/server.rb",
    wait: { stdout: /Rails E2E: ready/u },
    reuseExistingServer: false,
    timeout: 240_000,
    gracefulShutdown: { signal: "SIGTERM", timeout: 30_000 },
    stdout: "pipe",
    stderr: "pipe",
    env: {
      RAILS_ENV: "test",
      RACK_ENV: "test",
      RAILS_BROWSER_E2E: "1",
      UMAXICA_RUNTIME_ROLE: "shared",
      SECRET_KEY_BASE: randomBytes(64).toString("hex"),
      VITE_RUBY_MODE: "test",
      VITE_RUBY_PUBLIC_OUTPUT_DIR: "vite-e2e-test",
      VITE_RUBY_BUILD_CACHE_DIR: "tmp/cache/vite-e2e",
      VITE_RUBY_ASSET_HOST: "",
      VITE_RUBY_SKIP_PROXY: "true",
      VALKEY_NAMESPACE_RUN_ID: runId,
      VALKEY_NAMESPACE_WORKER_ID: "browser",
      PARALLEL_WORKERS: "1",
    },
  },
});
