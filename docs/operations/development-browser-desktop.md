# Development Browser Desktop

The Dev Container's `core` service carries a virtual desktop so a headed Chromium, whether driven by
hand or by Playwright, can be watched and operated from the developer's own browser. Nothing here
exists in the production image stages.

```text
Chromium / Playwright -> Xvfb :99 -> x11vnc (127.0.0.1:5900, container only)
                      -> websockify + noVNC (:6080) -> host 127.0.0.1:6080
```

## Parts

| Part       | Setting                                                              |
| ---------- | -------------------------------------------------------------------- |
| Xvfb       | display `:99`, `1440x900x24`, `-nolisten tcp`                        |
| openbox    | window manager, so browser windows can be moved and resized          |
| x11vnc     | RFB on container loopback `5900`, password required, never published |
| websockify | serves `/usr/share/novnc` and proxies `6080` to `127.0.0.1:5900`     |
| Chromium   | Debian package `chromium`, `/usr/bin/chromium`, runs as `global`     |

`podman/core/desktop.sh` is baked into the image as `/usr/local/bin/core-desktop`. The `core`
command is `core-desktop exec sleep infinity`, so starting the container starts the desktop. A part
that fails to start is logged and the container continues without it.

```sh
core-desktop status      # one line per part
core-desktop start       # idempotent; starts only what is not running
core-desktop stop
core-desktop password    # prints the VNC password
```

State, pidfiles and one log per part live in `~/.local/state/desktop/`. Read the logs there when a
part reports `stopped`.

`DISPLAY=:99` is set for the whole container, so a headed browser started from any shell is drawn on
the shared display.

## Connecting

Open `http://localhost:6080/vnc.html` on the machine that runs the container and enter the password
from `core-desktop password`.

The password is generated on first start into `~/.local/state/desktop/vnc-password` (mode `0600`).
It is not in the repository or the image, and it is replaced whenever the container is recreated. To
rotate it: `core-desktop stop`, delete the file, `core-desktop start`.

The password is not what protects the desktop. RFB authentication is weak and noVNC is served over
plain HTTP; the boundary is the loopback-only publication described in
`docs/operations/development-host-port-exposure.md`. From another machine, reach it through an SSH
tunnel (`ssh -L 6080:127.0.0.1:6080 <host>`), never by widening the `ports:` entry.

## Chromium Sandbox

`core` runs with `no-new-privileges`, which makes a setuid sandbox helper inert, so
`chromium-sandbox` is not installed. Chromium uses its user-namespace sandbox instead. Do not pass
`--no-sandbox`.

Playwright passes `--no-sandbox` by default. `playwright.config.ts` sets `chromiumSandbox: true`
whenever `PLAYWRIGHT_CHROMIUM_EXECUTABLE` selects a system browser.

## Playwright

Two Chromium builds are available, and they are different versions:

- Playwright's own build, downloaded by `node_modules/.bin/playwright install chromium` into the
  `~/.cache` volume. This is the default and the only build a Playwright release is tested against.
  `playwright show-trace` and `playwright codegen` always use it.
- The Debian package, selected with `PLAYWRIGHT_CHROMIUM_EXECUTABLE=/usr/bin/chromium`. It follows
  Debian security updates and may be ahead of or behind what Playwright expects; a protocol mismatch
  shows up as launch or command errors, and the remedy is to drop the variable.

```sh
node_modules/.bin/playwright test                       # headless
node_modules/.bin/playwright test --headed              # drawn on :99, visible in noVNC
PLAYWRIGHT_CHROMIUM_EXECUTABLE=/usr/bin/chromium node_modules/.bin/playwright test --headed
node_modules/.bin/playwright show-trace <trace.zip>     # viewer window on :99
node_modules/.bin/playwright codegen <url>              # recorder windows on :99
```

Playwright launches every test browser with a temporary profile. Start a hand-driven browser with
its own profile directory so the two never share state:

```sh
chromium --user-data-dir="$HOME/.local/state/desktop/chromium-profile"
```

## Updating

Chromium and the desktop packages come from Debian `trixie` through the `development` stage of
`Containerfile` and are unpinned; rebuilding the image picks up the current package versions.
Playwright's own build follows the `playwright` version in `package.json`; run
`playwright install chromium` after that version changes.
