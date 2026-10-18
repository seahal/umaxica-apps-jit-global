# Dev Container browser desktop (Chromium, Playwright, noVNC)

- Commit: `af5079a67df442ae591492dfa1a974d059fecb61`, with the uncommitted changes that introduce
  the desktop (`Containerfile`, `.devcontainer/compose.yaml`, `podman/core/desktop.sh`,
  `playwright.config.ts`, `.containerignore`, `.dockerignore`).
- Date: 2026-10-10. Host: rootless Podman 6.1.1, netavark + pasta, podman-compose 1.6.0.
- Image: `localhost/umaxicaappsglobaldc_core:latest` rebuilt from the `development` stage; `core`
  recreated with `podman-compose up -d --no-deps core`.
- Versions: Debian 13.7, Chromium 154.0.8037.92 (Debian package), Playwright 1.64.0, Playwright's
  own Chromium build 1248 (156.0.8078.4), Node 24.20.0.

The checks were driven by throwaway scripts under the ignored `tmp/desktop-smoke/`; they are not
part of any test suite (`.agents/harnesses/rules/project/no-environment-tests.mdc`).

## Observed

| Check                             | Result                                                                                                                                                                                                                                                                                                                           |
| --------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Desktop starts with the container | `podman logs` shows Xvfb, openbox, x11vnc, websockify started by `core-desktop exec`; `core-desktop status` reports all four running as `global`.                                                                                                                                                                                |
| Idempotent start                  | Two further `core-desktop start` calls returned 0 and the process count stayed at 4.                                                                                                                                                                                                                                             |
| Container restart                 | After `podman restart global-devcontainer-core` all four parts were running again with new PIDs; stale pidfiles and the X lock did not block the start.                                                                                                                                                                          |
| Listeners in the container        | `127.0.0.1:5900` (and `[::1]:5900`) for x11vnc, `0.0.0.0:6080` for websockify. Xvfb runs with `-nolisten tcp`.                                                                                                                                                                                                                   |
| Host publication                  | Host `ss -ltn` shows only `127.0.0.1:6080`. Host connect to `127.0.0.1:5900` is refused.                                                                                                                                                                                                                                         |
| noVNC over the host port          | From the host: `GET http://127.0.0.1:6080/vnc.html` returned 200; a WebSocket upgrade to `/websockify` returned 101 and the first frame carried `RFB 003.008`.                                                                                                                                                                   |
| VNC authentication                | Through noVNC, a wrong password was rejected ("password check failed"); the generated password connected. The password file is mode `0600`.                                                                                                                                                                                      |
| View and operate through noVNC    | A hand-started Chromium on `:99` was visible in the noVNC canvas (1440x900); a click and keystrokes sent through noVNC filled its text input.                                                                                                                                                                                    |
| Chromium starts, non-root         | `chromium --version` works; all browser processes run as `global`.                                                                                                                                                                                                                                                               |
| Sandbox                           | With `chromiumSandbox: true`, no process carried `--no-sandbox`; renderers ran in user, PID and network namespaces different from the container's init, with `CapEff` 0. Without that option Playwright adds `--no-sandbox` and renderers share the container's namespaces. The hand-started Chromium carried no `--no-sandbox`. |
| Playwright headless               | Passed with `/usr/bin/chromium` and, after `playwright install chromium`, with Playwright's own build.                                                                                                                                                                                                                           |
| Playwright headed                 | Passed with both builds.                                                                                                                                                                                                                                                                                                         |
| Headed run drawn on `:99`         | During a held headed run `xwininfo -root -tree` listed the test window and a capture of the root window showed the page, including Japanese text and a color emoji.                                                                                                                                                              |
| Screenshot and trace              | `smoke.png`, `test-finished-1.png` and `trace.zip` (11 entries) were written. `playwright show-trace` opened a "Playwright Trace Viewer" window on `:99`.                                                                                                                                                                        |
| Codegen                           | `playwright codegen` opened its browser windows on `:99`. Recording itself was not exercised.                                                                                                                                                                                                                                    |
| Existing suite                    | `e2e/ui-presentation.spec.ts`, headed, `PLAYWRIGHT_CHROMIUM_EXECUTABLE=/usr/bin/chromium`, against the Vite presentation fixture: 15 passed.                                                                                                                                                                                     |

## Not verified

- noVNC was driven by a headless Chromium inside the container, and the host leg was checked at the
  HTTP and WebSocket level. A person operating noVNC in a desktop browser on the host was not
  observed; the browser automation extension was not connected.
- No spec that needs a running Rails application was run; the development databases were not
  prepared in this session.
- A full image rebuild from a clean cache and a `devcontainer up` through the Dev Containers CLI
  were not run; the container was created with podman-compose.

## Notes

- Before this work the cache volume held Playwright Chromium builds 1234 and 1243 only, so
  Playwright 1.64.0 could not launch its own build until `playwright install chromium` was run. That
  command also removed the two older builds.
- The first image build failed because `.containerignore` admits files under `podman/core/` by name;
  `desktop.sh` had to be added there and in `.dockerignore`.
