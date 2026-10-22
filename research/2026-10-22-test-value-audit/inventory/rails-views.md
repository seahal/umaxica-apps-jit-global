# rails-views: per-definition ledger

15 source definitions. [Audit scope and status legend](../README.md). Generated loops/each tables are represented once per source definition, not once per runtime case. Production links are static candidates, not verified call traces. Oracle excerpts are truncated; use the linked source for complete setup and assertions.

## `test/views/cloudflare_turnstile_stealth_partial_test.rb`

[test/views/cloudflare_turnstile_stealth_partial_test.rb](../../../test/views/cloudflare_turnstile_stealth_partial_test.rb); SHA-256: `daa594277b697915d1a9728967e191b1567a5dbf9fad83e01a1f36a8f0561485`.

File-level implementation candidates (including setup/import context): unresolved by static constant/import matching.

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-13645"></a>T-13645 / [7](../../../test/views/cloudflare_turnstile_stealth_partial_test.rb#L7) | "renders widget controls without loading the api script"<br>Owner: `CloudflareTurnstileStealthPartialTest` | `assert_select "[data-controller='turnstile'][data-turnstile-mode-value='execute']"`; `assert_select ".cf-turnstile[data-sitekey]"`; `assert_select "input[name='cf-turnstile-response'][type='hidden']"`; +1 further assertion lines | unresolved | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/views/cloudflare_turnstile_visible_partial_test.rb`

[test/views/cloudflare_turnstile_visible_partial_test.rb](../../../test/views/cloudflare_turnstile_visible_partial_test.rb); SHA-256: `e2e70b1d37c400859a8a3349c0b64a84b185f50fac43317ffe60e695024e194e`.

File-level implementation candidates (including setup/import context): unresolved by static constant/import matching.

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-13646"></a>T-13646 / [7](../../../test/views/cloudflare_turnstile_visible_partial_test.rb#L7) | "renders optional ceremony binding attributes"<br>Owner: `CloudflareTurnstileVisiblePartialTest` | `assert_select "[data-controller='turnstile'][data-turnstile-mode-value='render']"`; `assert_select "[data-turnstile-action-value='social_signup_confirmation']"`; `assert_select "[data-turnstile-cdata-value='cycle-public-id']"`; +2 further assertion lines | unresolved | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-13647"></a>T-13647 / [23](../../../test/views/cloudflare_turnstile_visible_partial_test.rb#L23) | "omits ceremony binding attributes by default"<br>Owner: `CloudflareTurnstileVisiblePartialTest` | `assert_select "[data-controller='turnstile'][data-turnstile-mode-value='render']"`; `assert_select "[data-turnstile-action-value]", false`; `assert_select "[data-turnstile-cdata-value]", false`; +1 further assertion lines | unresolved | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/views/layouts/shared/banner_partial_test.rb`

[test/views/layouts/shared/banner_partial_test.rb](../../../test/views/layouts/shared/banner_partial_test.rb); SHA-256: `1e391ea59ee124cce5539f90e3bcbdacb1acb523bc224755f0fd166c1760e99b`.

File-level implementation candidates (including setup/import context): [app/models/client.rb:76](../../../app/models/client.rb#L76); [app/models/visitor.rb:63](../../../app/models/visitor.rb#L63).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-13648"></a>T-13648 / [11](../../../test/views/layouts/shared/banner_partial_test.rb#L11) | "renders title and body when title is present"<br>Owner: `BannerPartialTest` | `assert_includes rendered, "Client current banner"`; `assert_includes rendered, "Client current banner body"` | [Client](../../../app/models/client.rb#L76) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-13649"></a>T-13649 / [18](../../../test/views/layouts/shared/banner_partial_test.rb#L18) | "renders body without title heading when title is blank"<br>Owner: `BannerPartialTest` | `assert_includes rendered, "Visitor untitled banner body"`; `assert_not_includes rendered, "&lt;h2&gt;"` | [Visitor](../../../app/models/visitor.rb#L63) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/views/shared/current_banner_partial_test.rb`

[test/views/shared/current_banner_partial_test.rb](../../../test/views/shared/current_banner_partial_test.rb); SHA-256: `3134fa89130196f7fa90b05b29eebbd3a06ed43495af7e41f7a71869c2d33880`.

File-level implementation candidates (including setup/import context): [app/models/client.rb:76](../../../app/models/client.rb#L76); [app/models/visitor.rb:63](../../../app/models/visitor.rb#L63); [app/models/visitor_banner.rb:27](../../../app/models/visitor_banner.rb#L27).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-13650"></a>T-13650 / [14](../../../test/views/shared/current_banner_partial_test.rb#L14) | "renders the current banner for a surface"<br>Owner: `CurrentBannerPartialTest` | `assert_includes rendered, "Client newer banner"`; `assert_includes rendered, "Client newer banner body"` | [Client](../../../app/models/client.rb#L76) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-13651"></a>T-13651 / [23](../../../test/views/shared/current_banner_partial_test.rb#L23) | "renders the current banner for sign domain with ww region"<br>Owner: `CurrentBannerPartialTest` | `assert_includes rendered, "Staff current banner"`; `assert_includes rendered, "Staff current banner body"` | [Client](../../../app/models/client.rb#L76); [Visitor](../../../app/models/visitor.rb#L63) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-13652"></a>T-13652 / [32](../../../test/views/shared/current_banner_partial_test.rb#L32) | "renders the current banner for sign domain with global region (normalized to ww)"<br>Owner: `CurrentBannerPartialTest` | `assert_includes rendered, "Staff current banner"`; `assert_includes rendered, "Staff current banner body"` | [Client](../../../app/models/client.rb#L76); [Visitor](../../../app/models/visitor.rb#L63) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-13653"></a>T-13653 / [41](../../../test/views/shared/current_banner_partial_test.rb#L41) | "renders the current banner for help domain with jp region"<br>Owner: `CurrentBannerPartialTest` | `assert_includes rendered, "Visitor current banner"`; `assert_includes rendered, "Visitor current banner body"` | [Visitor](../../../app/models/visitor.rb#L63) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-13654"></a>T-13654 / [50](../../../test/views/shared/current_banner_partial_test.rb#L50) | "raises error when mandatory arguments are missing"<br>Owner: `CurrentBannerPartialTest` | `assert_raises ActionView::Template::Error do` | [Client](../../../app/models/client.rb#L76); [Visitor](../../../app/models/visitor.rb#L63) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-13655"></a>T-13655 / [56](../../../test/views/shared/current_banner_partial_test.rb#L56) | "raises error when invalid tld is provided"<br>Owner: `CurrentBannerPartialTest` | `assert_raises ActionView::Template::Error do`; `assert_raises ActionView::Template::Error do` | [Client](../../../app/models/client.rb#L76); [Visitor](../../../app/models/visitor.rb#L63) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-13656"></a>T-13656 / [65](../../../test/views/shared/current_banner_partial_test.rb#L65) | "raises error when invalid domain is provided"<br>Owner: `CurrentBannerPartialTest` | `assert_raises ActionView::Template::Error do` | [Client](../../../app/models/client.rb#L76); [Visitor](../../../app/models/visitor.rb#L63) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-13657"></a>T-13657 / [71](../../../test/views/shared/current_banner_partial_test.rb#L71) | "raises error when invalid region is provided"<br>Owner: `CurrentBannerPartialTest` | `assert_raises ActionView::Template::Error do`; `assert_raises ActionView::Template::Error do` | [Client](../../../app/models/client.rb#L76); [Visitor](../../../app/models/visitor.rb#L63) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-13658"></a>T-13658 / [81](../../../test/views/shared/current_banner_partial_test.rb#L81) | "raises error when invalid region for domain is provided"<br>Owner: `CurrentBannerPartialTest` | `assert_raises ActionView::Template::Error do`; `assert_raises ActionView::Template::Error do`; `assert_raises ActionView::Template::Error do` | [Client](../../../app/models/client.rb#L76); [Visitor](../../../app/models/visitor.rb#L63) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-13659"></a>T-13659 / [96](../../../test/views/shared/current_banner_partial_test.rb#L96) | "renders nothing when the current banner is missing"<br>Owner: `CurrentBannerPartialTest` | `assert_empty rendered.strip` | [VisitorBanner](../../../app/models/visitor_banner.rb#L27) | S: static inventory; individual semantic review open | stubbed-boundary |
