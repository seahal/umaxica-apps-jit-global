import { defineConfig, devices } from "playwright/test";

// Host configuration belongs to the process environment, the same contract test/test_helper.rb
// documents for Rails. These are read without defaults so a misconfigured run fails by name instead
// of silently pointing at the wrong origin.
const requiredEnv = (name: string): string => {
  const value = process.env[name];

  if (!value) {
    throw new Error(
      `${name} must be set to run the end-to-end suite. ` +
        "Service workers need a real origin, so there is no usable default.",
    );
  }

  return value;
};

export const baseSurfaceUrl = (): string => requiredEnv("E2E_BASE_SERVICE_URL");
export const authSurfaceUrl = (): string => requiredEnv("E2E_AUTH_SERVICE_URL");

// Optional: run against a system browser instead of the Chromium build Playwright downloads, for
// example the development container's /usr/bin/chromium. Unset means Playwright's own build, which
// is the only one a Playwright release is tested against; nothing is substituted when it is unset.
//
// A system browser runs with Chromium's own sandbox. Playwright launches with `--no-sandbox` unless
// told otherwise, which is tolerable for its disposable build in CI but not for a browser a
// developer also drives by hand against real origins.
const chromiumExecutablePath = process.env["PLAYWRIGHT_CHROMIUM_EXECUTABLE"];

export default defineConfig({
  testDir: "./e2e",
  testIgnore: "**/rails/**",
  // Service worker install and activation are ordered against a single origin's registration, so
  // running these files in parallel against the same browser profile would make them interfere.
  fullyParallel: false,
  workers: 1,
  forbidOnly: true,
  retries: 0,
  reporter: [["list"]],
  use: {
    // Service workers require a secure context. https origins and localhost both qualify, and the
    // development hosts are *.localhost, so no certificate handling is needed here.
    serviceWorkers: "allow",
    trace: "retain-on-failure",
  },
  projects: [
    {
      name: "chromium",
      use: {
        ...devices["Desktop Chrome"],
        ...(chromiumExecutablePath === undefined
          ? {}
          : { launchOptions: { executablePath: chromiumExecutablePath, chromiumSandbox: true } }),
      },
    },
  ],
});
