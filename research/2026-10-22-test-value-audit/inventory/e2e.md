# e2e: per-definition ledger

33 source definitions. [Audit scope and status legend](../README.md). Generated loops/each tables are represented once per source definition, not once per runtime case. Production links are static candidates, not verified call traces. Oracle excerpts are truncated; use the linked source for complete setup and assertions.

## `e2e/app-secret-delivery.spec.ts`

[e2e/app-secret-delivery.spec.ts](../../../e2e/app-secret-delivery.spec.ts); SHA-256: `0b3029fa21b713e0bab6370c2fe86ce176556e0b8c5e8b0a0393b12382e459ab`.

File-level implementation candidates (including setup/import context): unresolved by static constant/import matching.

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-13660"></a>T-13660 / [65](../../../e2e/app-secret-delivery.spec.ts#L65) | "Rails delivery leaves no plaintext in history or storage and does not restore it on back"<br>Owner: `` | `await expect(page.locator("form button[type=submit]").first()).toBeVisible();`; `await expect(page).toHaveURL(/\/secret_issuances\//u);`; `expect(delivered.request().method()).toBe("POST");`; +11 further assertion lines | unresolved; `await page.goto('${origin}/secrets/new?ri=jp');` | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-13661"></a>T-13661 / [133](../../../e2e/app-secret-delivery.spec.ts#L133) | "reload and another tab cannot reveal or confirm an unconfirmed Rails presentation"<br>Owner: `` | `await expect(page).toHaveURL(/\/secret_issuances\//u);`; `await expect(page.locator("[data-secret-value] code")).toHaveCount(1);`; `expect(raw.length).toBe(32);`; +7 further assertion lines | unresolved; `await page.goto('${origin}/secrets/new?ri=jp');` | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-13662"></a>T-13662 / [180](../../../e2e/app-secret-delivery.spec.ts#L180) | "active Rails Service Worker never caches delivered values and offline fallback has no plaintext"<br>Owner: `` | `await expect`; `await expect(page).toHaveURL(/\/secret_issuances\//u);`; `await expect(page.locator("[data-secret-value] code")).toHaveCount(1);`; +8 further assertion lines | unresolved; `await page.goto('${origin}/secrets/new?ri=jp'); / const offline = await page.goto(locator);` | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-13663"></a>T-13663 / [231](../../../e2e/app-secret-delivery.spec.ts#L231) | "losing the committed delivery response leaves one unconfirmed batch without redisplay"<br>Owner: `` | `await expect(page).toHaveURL(/\/secret_issuances\//u);`; `expect(delivered.status()).toBe(200);`; `expect(String(error).includes("net::ERR_FAILED")).toBe(true);`; +9 further assertion lines | unresolved; `await page.goto('${origin}/secrets/new?ri=jp'); / await page.route("**/secret_issuances/*/presentation*", async (route) =&gt; {` | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `e2e/app-secret-sign-in-entry.spec.ts`

[e2e/app-secret-sign-in-entry.spec.ts](../../../e2e/app-secret-sign-in-entry.spec.ts); SHA-256: `51f76db56b58fd30df8740abddd11d4ba61db1b51ec313139be615d1e8753323`.

File-level implementation candidates (including setup/import context): unresolved by static constant/import matching.

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-13664"></a>T-13664 / [33](../../../e2e/app-secret-sign-in-entry.spec.ts#L33) | `server-issued browser admission reaches the sixth Secret entry for ri=${region}`<br>Owner: `` | `await expect`; `await expect(page.locator('a[href*="/sign/in/email"]')).toBeVisible();`; `await expect(page.locator('a[href*="/sign/in/passkey"]')).toBeVisible();`; +9 further assertion lines | unresolved; `await page.goto('https://${baseHost}/sign?ri=${region}');` | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-13665"></a>T-13665 / [63](../../../e2e/app-secret-sign-in-entry.spec.ts#L63) | "a browser-saved manual Secret establishes one normal root login and rejects reuse"<br>Owner: `` | `assert.ok(typeof fixture === "object");`; `assert.ok(fixture !== null);`; `assert.ok("cookie" in fixture);`; +18 further assertion lines | unresolved; `await page.goto('https://${baseHost}/secrets/new?ri=jp'); / await page.goto('https://${baseHost}/sign?ri=jp');` | S: static inventory; individual semantic review open | source-text-oracle, environment-reference |

## `e2e/rails/auth-public.spec.ts`

[e2e/rails/auth-public.spec.ts](../../../e2e/rails/auth-public.spec.ts); SHA-256: `452dc4ff3971361b9259d76381306601246d7370230e872026a12f575332c5cc`.

File-level implementation candidates (including setup/import context): unresolved by static constant/import matching.

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-13666"></a>T-13666 / [3](../../../e2e/rails/auth-public.spec.ts#L3) | "Auth public landing mounts its Inertia React page"<br>Owner: `` | `expect(response?.status()).toBe(200);`; `await expect(page.getByRole("heading", { name: "Sign App", exact: true })).toBeVisible();`; `await expect(page.getByRole("navigation", { name: "Authentication", exact: true })).toBeVisible();`; +4 further assertion lines | unresolved; `const response = await page.goto("/?ri=jp");` | R: retained; A live Rails page must mount visible React roles and a CSRF meta token; this differs from static markup fixtures. | none detected (not a quality approval) |

## `e2e/secret-presentation.spec.ts`

[e2e/secret-presentation.spec.ts](../../../e2e/secret-presentation.spec.ts); SHA-256: `abf50438ed7055096579409556ff41200edefedf8e94dadbcf315eac31b82449`.

File-level implementation candidates (including setup/import context): unresolved by static constant/import matching.

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-13667"></a>T-13667 / [22](../../../e2e/secret-presentation.spec.ts#L22) | "pagehide removes every value before a document can enter the back-forward cache"<br>Owner: `` | `await expect(page.locator("[data-secret-value]")).toHaveText(["", ""]);`; `expect(await page.content()).not.toContain(values[0]);`; `expect(await page.content()).not.toContain(values[1]);` | unresolved | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-13668"></a>T-13668 / [33](../../../e2e/secret-presentation.spec.ts#L33) | "persisted pageshow clears restored values while initial pageshow preserves delivery"<br>Owner: `` | `await expect(page.locator("[data-secret-value]")).toHaveText(values);`; `await expect(page.locator("[data-secret-value]")).toHaveText(["", ""]);` | unresolved | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-13669"></a>T-13669 / [46](../../../e2e/secret-presentation.spec.ts#L46) | "native validation preserves unsaved values and accepted submission clears them"<br>Owner: `` | `await expect(page.locator("[data-secret-value]")).toHaveText(values);`; `await expect(page.locator("[data-secret-value]")).toHaveText(["", ""]);`; `expect(await page.evaluate(() =&gt; JSON.stringify(history.state))).not.toContain(values[0]);`; +1 further assertion lines | unresolved | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `e2e/ui-application.spec.ts`

[e2e/ui-application.spec.ts](../../../e2e/ui-application.spec.ts); SHA-256: `55bd29231b03c41e88d5b35d3f3131fe2fcc8f6ac7e883b173156dac5da3823c`.

File-level implementation candidates (including setup/import context): unresolved by static constant/import matching.

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-13670"></a>T-13670 / [12](../../../e2e/ui-application.spec.ts#L12) | `${surface} anonymous entry in ${language} at ${width}px`<br>Owner: `` | `expect(response?.status()).toBe(200);`; `await expect(page.getByRole("main").getByRole("heading", { level: 1 })).toBeVisible();`; `expect(await page.evaluate(() =&gt; document.documentElement.scrollWidth)).toBeLessThanOrEqual(`; +5 further assertion lines | unresolved; `await page.route("**/*", (route) =&gt; { / const response = await page.goto(url.toString());` | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-13671"></a>T-13671 / [45](../../../e2e/ui-application.spec.ts#L45) | "the existing neutral sign-entry form retains its POST contract and readable submit target"<br>Owner: `` | `expect((await page.goto(url.toString()))?.status()).toBe(200);`; `await expect(form).toHaveAttribute("method", "post");`; `await expect(submit).toHaveAccessibleName("Continue");`; +2 further assertion lines | unresolved; `await page.route("**/*", (route) =&gt; { / expect((await page.goto(url.toString()))?.status()).toBe(200);` | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-13672"></a>T-13672 / [71](../../../e2e/ui-application.spec.ts#L71) | "offline recovery preserves its native retry without an application runtime"<br>Owner: `` | `expect((await page.goto(url.toString()))?.status()).toBe(200);`; `await expect(page.getByRole("main").getByRole("heading", { level: 1 })).toBeVisible();`; `await expect(page.getByRole("form")).toHaveAttribute("method", "get");`; +3 further assertion lines | unresolved; `expect((await page.goto(url.toString()))?.status()).toBe(200);` | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `e2e/ui-authenticated-presentation.spec.ts`

[e2e/ui-authenticated-presentation.spec.ts](../../../e2e/ui-authenticated-presentation.spec.ts); SHA-256: `1f1c26035e379d6d8a94dddbd4a96d7821da3addb802ca9fbb114a2ec61c7ac6`.

File-level implementation candidates (including setup/import context): unresolved by static constant/import matching.

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-13673"></a>T-13673 / [147](../../../e2e/ui-authenticated-presentation.spec.ts#L147) | `${journey.host}${journey.path} has readable authenticated presentation at ${width}px in ${language}/${theme}/OS-${os}`<br>Owner: `` | `expect(response?.status()).toBe(200);`; `await expect(title).toBeVisible();`; `await expect(page.locator("html")).toHaveAttribute("data-theme", theme);`; +5 further assertion lines | unresolved; `await page.route("**/*", (route) =&gt; { / const response = await page.goto(` | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `e2e/ui-ceremony-presentation.spec.ts`

[e2e/ui-ceremony-presentation.spec.ts](../../../e2e/ui-ceremony-presentation.spec.ts); SHA-256: `b53f7677b6489b99dfc250565cffc7a434bbabdd553f2debe9172ab97511e86c`.

File-level implementation candidates (including setup/import context): unresolved by static constant/import matching.

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-13674"></a>T-13674 / [7](../../../e2e/ui-ceremony-presentation.spec.ts#L7) | `${screen} ceremony composition reflows at ${width}px`<br>Owner: `` | `await expect(page.getByRole("main").getByRole("heading", { level: 1 })).toBeVisible();`; `expect(await page.evaluate(() =&gt; document.documentElement.scrollWidth)).toBeLessThanOrEqual(`; `expect(`; +1 further assertion lines | unresolved; `await page.route("**/synthetic/**", (route) =&gt; route.abort()); / await page.goto('http://127.0.0.1:3190/ceremony.html?screen=${screen}');` | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-13675"></a>T-13675 / [36](../../../e2e/ui-ceremony-presentation.spec.ts#L36) | "Secret native validity preserves the exact 32-character boundary and accepted alphabet"<br>Owner: `` | `expect((await control.boundingBox())?.height).toBeGreaterThanOrEqual(44);`; `expect(`; `await expect(control).toHaveAttribute("autocomplete", "current-password");`; +2 further assertion lines | unresolved; `await page.goto("http://127.0.0.1:3190/ceremony.html?screen=secret");` | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `e2e/ui-components-acceptance.spec.ts`

[e2e/ui-components-acceptance.spec.ts](../../../e2e/ui-components-acceptance.spec.ts); SHA-256: `f58771e907536545c6dc2d60de10b4d73465314441cf1f443ff2ab831fecc8be`.

File-level implementation candidates (including setup/import context): unresolved by static constant/import matching.

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-13676"></a>T-13676 / [5](../../../e2e/ui-components-acceptance.spec.ts#L5) | `ordinary table and opaque pressed buttons in ${theme}`<br>Owner: `` | `expect(await cell.evaluate((node) =&gt; getComputedStyle(node).fontSize)).toBe("16px");` | unresolved; `await page.goto("http://127.0.0.1:3190/");` | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-13677"></a>T-13677 / [11](../../../e2e/ui-components-acceptance.spec.ts#L11) | `pressed buttons keep full foreground and fill contrast in ${theme}`<br>Owner: `` | `expect(` | unresolved; `await page.goto("http://127.0.0.1:3190/");` | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-13678"></a>T-13678 / [28](../../../e2e/ui-components-acceptance.spec.ts#L28) | "native selection uses the OS picker and retains the chosen value"<br>Owner: `` | `await expect(select).toHaveValue("light");`; `await expect(select).toBeVisible();` | unresolved; `await page.goto("http://127.0.0.1:3190/");` | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-13679"></a>T-13679 / [36](../../../e2e/ui-components-acceptance.spec.ts#L36) | "a wide table exposes a local scroll affordance and scrolls from the keyboard"<br>Owner: `` | `expect(await region.evaluate((node) =&gt; getComputedStyle(node).backgroundImage)).toContain(`; `expect(await region.evaluate((node) =&gt; node.scrollWidth)).toBeGreaterThan(`; `await expect.poll(() =&gt; region.evaluate((node) =&gt; node.scrollLeft)).toBeGreaterThan(0);`; +1 further assertion lines | unresolved; `await page.goto("http://127.0.0.1:3190/");` | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-13680"></a>T-13680 / [57](../../../e2e/ui-components-acceptance.spec.ts#L57) | `conditions, density and native birthdate reflow in ${edition}/${lang} at ${width}px`<br>Owner: `` | `await expect(page.locator("[data-locale]")).toHaveText(lang);`; `await expect(choice).toHaveValue("0");`; `await expect(choice).toHaveAccessibleDescription("Choose an available option.");`; +8 further assertion lines | unresolved; `await page.goto('http://127.0.0.1:3190/components.html?edition=${edition}&lang=${lang}');` | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-13681"></a>T-13681 / [115](../../../e2e/ui-components-acceptance.spec.ts#L115) | `${variant} text contrast remains readable at rest, hover and press in ${theme}`<br>Owner: `` | `expect(ratio).toBeGreaterThanOrEqual(4.5);` | unresolved; `await page.goto("http://127.0.0.1:3190/");` | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `e2e/ui-erb-presentation.spec.ts`

[e2e/ui-erb-presentation.spec.ts](../../../e2e/ui-erb-presentation.spec.ts); SHA-256: `a25525a42253480abf0e444893e266ac1252f8f6a5c18aec685498c9f743bdb8`.

File-level implementation candidates (including setup/import context): unresolved by static constant/import matching.

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-13682"></a>T-13682 / [27](../../../e2e/ui-erb-presentation.spec.ts#L27) | `ERB confirmation reflows at ${width}px in ${theme}`<br>Owner: `` | `await expect(page.getByRole("main").getByRole("heading", { level: 1 })).toBeVisible();`; `expect(await page.evaluate(() =&gt; document.documentElement.scrollWidth)).toBeLessThanOrEqual(`; `expect(size?.width).toBeGreaterThanOrEqual(44);`; +4 further assertion lines | unresolved; `await page.route("**/*", (route) =&gt; route.abort());` | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `e2e/ui-foundations.spec.ts`

[e2e/ui-foundations.spec.ts](../../../e2e/ui-foundations.spec.ts); SHA-256: `00c7930997161bed169127bb2eeaa967960f1c735930cfe526f005244ad5fa8a`.

File-level implementation candidates (including setup/import context): unresolved by static constant/import matching.

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-13683"></a>T-13683 / [6](../../../e2e/ui-foundations.spec.ts#L6) | `keyboard focus, link feedback and dialog boundary in ${theme}`<br>Owner: `` | `expect(focus.outline).toBe("rgb(0, 0, 0)");`; `expect(focus.width).toBe("4px");`; `expect(focus.shadow).toContain("rgb(255, 212, 61)");`; +4 further assertion lines | unresolved; `await page.goto("http://127.0.0.1:3190/");` | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-13684"></a>T-13684 / [76](../../../e2e/ui-foundations.spec.ts#L76) | "notification explanations are readable and described by their checkbox"<br>Owner: `` | `expect(await description.evaluate((node) =&gt; getComputedStyle(node).fontSize)).toBe("16px");`; `await expect(checkbox).toHaveAccessibleDescription(`; `expect(`; +3 further assertion lines | unresolved; `await page.route("**/*", (route) =&gt; / await page.goto("http://127.0.0.1:3190/foundations.html?screen=preferences");` | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-13685"></a>T-13685 / [121](../../../e2e/ui-foundations.spec.ts#L121) | `reading paragraphs keep their relationship at ${width}px in ${lang}`<br>Owner: `` | `expect(geometry.gap).toBeGreaterThanOrEqual(geometry.line * 1.5 - 1);`; `expect(geometry.width).toBeLessThanOrEqual(geometry.font * 40);`; `expect(await page.evaluate(() =&gt; document.documentElement.scrollWidth)).toBeLessThanOrEqual(`; +1 further assertion lines | unresolved; `await page.route("**/synthetic/**", (route) =&gt; route.abort()); / await page.goto('http://127.0.0.1:3190/foundations.html?lang=${lang}');` | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-13686"></a>T-13686 / [167](../../../e2e/ui-foundations.spec.ts#L167) | "navigation icons stay decorative and focus survives forced colors"<br>Owner: `` | `await expect(row.locator('[aria-hidden="true"]')).toHaveText("→");`; `expect(await row.evaluate((node) =&gt; getComputedStyle(node).borderRadius)).toBe("6px");`; `expect(await row.evaluate((node) =&gt; getComputedStyle(node).outlineStyle)).toBe("solid");`; +2 further assertion lines | unresolved; `await page.goto("http://127.0.0.1:3190/");` | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `e2e/ui-native-preferences.spec.ts`

[e2e/ui-native-preferences.spec.ts](../../../e2e/ui-native-preferences.spec.ts); SHA-256: `b09951ce8315626f17811a5327b35715078f41586a574bd6492b2cc94422c4ad`.

File-level implementation candidates (including setup/import context): unresolved by static constant/import matching.

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-13687"></a>T-13687 / [7](../../../e2e/ui-native-preferences.spec.ts#L7) | `native preference selection retains its Rails payload on ${edition}/${language}`<br>Owner: `` | `expect(`; `await expect(page.locator("html")).toHaveAttribute("lang", language);`; `await expect(page.getByRole("main").getByRole("heading", { level: 1 })).toBeVisible();`; +8 further assertion lines | unresolved; `await page.route("**/*", (route) =&gt; { / await page.goto('http://${host}:3188/preference/language/edit?ri=jp&lx=${language}')` | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `e2e/ui-presentation.spec.ts`

[e2e/ui-presentation.spec.ts](../../../e2e/ui-presentation.spec.ts); SHA-256: `379a608b18b97931c1d82d79e1f47a93825054a27239df1d525d1d91c7251bdc`.

File-level implementation candidates (including setup/import context): unresolved by static constant/import matching.

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-13688"></a>T-13688 / [10](../../../e2e/ui-presentation.spec.ts#L10) | `primitives reflow at ${width}px in ${theme} mode`<br>Owner: `` | `await expect(page.getByRole("heading", { name: "UI primitives", exact: true })).toBeVisible();`; `expect(await page.evaluate(() =&gt; document.documentElement.scrollWidth)).toBeLessThanOrEqual(`; `expect(metrics.width).toBeGreaterThanOrEqual(44);`; +4 further assertion lines | unresolved; `await page.goto(fixtureUrl);` | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-13689"></a>T-13689 / [47](../../../e2e/ui-presentation.spec.ts#L47) | "checkbox label participates in its target and native form state"<br>Owner: `` | `expect((await label.boundingBox())?.height).toBeGreaterThanOrEqual(44);`; `await expect(checkbox).toBeChecked();` | unresolved; `await page.goto(fixtureUrl);` | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-13690"></a>T-13690 / [56](../../../e2e/ui-presentation.spec.ts#L56) | "dialog traps keyboard focus and returns it on Escape"<br>Owner: `` | `await expect(dialog).toBeVisible();`; `expect(await dialog.evaluate((node) =&gt; node.contains(document.activeElement))).toBe(true);`; `await expect(dialog).not.toBeVisible();`; +1 further assertion lines | unresolved; `await page.goto(fixtureUrl);` | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-13691"></a>T-13691 / [69](../../../e2e/ui-presentation.spec.ts#L69) | "long text and 200 percent text sizing reflow at 320px"<br>Owner: `` | `expect(await page.evaluate(() =&gt; document.documentElement.scrollWidth)).toBeLessThanOrEqual(320);` | unresolved; `await page.goto(fixtureUrl);` | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `e2e/ui-secret-reveal-presentation.spec.ts`

[e2e/ui-secret-reveal-presentation.spec.ts](../../../e2e/ui-secret-reveal-presentation.spec.ts); SHA-256: `e67c8f4d70c4545418f9ab83f62ca840312cee9b6ae65dd993f585cabbf835a5`.

File-level implementation candidates (including setup/import context): unresolved by static constant/import matching.

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-13692"></a>T-13692 / [31](../../../e2e/ui-secret-reveal-presentation.spec.ts#L31) | `one-time reveal display preserves readable acknowledgement and cancellation at ${width}px`<br>Owner: `` | `await expect(page.getByRole("main").getByRole("heading", { level: 1 })).toBeVisible();`; `expect((await label.boundingBox())?.height).toBeGreaterThanOrEqual(44);`; `await expect(stored).toBeChecked();`; +6 further assertion lines | unresolved; `await page.route("**/*", (route) =&gt; route.abort());` | R: retained; Explicit synthetic renderer fixture verifies browser layout/focus/semantics; it is scoped presentation coverage, not login issuance evidence. | none detected (not a quality approval) |
