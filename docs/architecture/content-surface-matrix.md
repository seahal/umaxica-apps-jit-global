# Content Surface Matrix (3 × 4)

Authoritative inventory of the twelve logical content interfaces:

```text
          info   docs   news   help

app
com
org
```

Rails owns content authority and the read API. Public HTML for these surfaces belongs to Edge,
not Rails. Current Edge runtime for the twelve content packages is TanStack Start on Cloudflare
Workers. `adr/015-public-content-surfaces-astro.md` in the Edge repository accepts an Astro
migration that is in progress and not deployed. Historical Rails ADRs still say Next.js; that is
not current implementation truth.

Public hostname spelling is not fully aligned: Rails route contracts use regional public hosts such
as `docs.jp.umaxica.app`, while the Edge README lists `docs.umaxica.app`. Do not pick a winner in
this phase.

## Shared contract

| Concern | Current truth |
| --- | --- |
| Persistence | Central `publishing` database via `PublishingRecord`. Twelve interfaces, one database. Persistence polymorphism is prohibited; see `docs/architecture/publishing-persistence.md`. |
| Public read API | `GET /api/v0/entries` and `GET /api/v0/entries/:slug` on each of the twelve hosts |
| Rails HTML | Thin root and health only; no article index/detail, sitemap, or RSS |
| Edge CMS consumption | **Not implemented.** Rails CMS API exists; Edge does not yet fetch `/api/v0/entries` for list/detail pages |
| Region | Unresolved product semantics. Editions store optional `region_code`. Database CHECK requires a two-letter code for docs/news/help and forbids it for info. Uniqueness remains `(audience, surface, locale)` and does **not** include `region_code`. Do not change this without an architecture decision |

## Cell records

Audience maps to public registrable domain: `app` → `umaxica.app`, `com` → `umaxica.com`,
`org` → `umaxica.org`. Private Rails origins in this repository are `*.localhost` Host-Authorization
targets, not public DNS.

### app × info

| Field | Value |
| --- | --- |
| Edge unit | `app/info` in umaxica-apps-edge (TanStack Start runtime; Astro juxtaposed, not deployed) |
| Rails namespace/controller | `Info::App::*` (`info/app/roots`, `info/app/healths`, `info/app/api/v0/entries`) |
| Public host | `info.umaxica.app` |
| Private Rails host | `info.app.localhost` |
| Audience | End-user application (`app`) |
| Surface | `info` |
| Current implementation status | Rails thin root, health, and CMS read API implemented |
| CMS integration status | Rails API present; Edge does not consume it yet |

### com × info

| Field | Value |
| --- | --- |
| Edge unit | `com/info` in umaxica-apps-edge |
| Rails namespace/controller | `Info::Com::*` |
| Public host | `info.umaxica.com` |
| Private Rails host | `info.com.localhost` |
| Audience | Public / corporate (`com`) |
| Surface | `info` |
| Current implementation status | Rails thin root, health, and CMS read API implemented |
| CMS integration status | Rails API present; Edge does not consume it yet |

### org × info

| Field | Value |
| --- | --- |
| Edge unit | `org/info` in umaxica-apps-edge |
| Rails namespace/controller | `Info::Org::*` |
| Public host | `info.umaxica.org` |
| Private Rails host | `info.org.localhost` |
| Audience | Staff / organization (`org`) |
| Surface | `info` |
| Current implementation status | Rails thin root, health, and CMS read API implemented |
| CMS integration status | Rails API present; Edge does not consume it yet |

### app × docs

| Field | Value |
| --- | --- |
| Edge unit | `app/docs` in umaxica-apps-edge |
| Rails namespace/controller | `Docs::App::*` |
| Public host | `docs.jp.umaxica.app` |
| Private Rails host | `docs.app.localhost` |
| Audience | End-user application (`app`) |
| Surface | `docs` |
| Current implementation status | Rails thin root, health, and CMS read API implemented |
| CMS integration status | Rails API present; Edge does not consume it yet |

### com × docs

| Field | Value |
| --- | --- |
| Edge unit | `com/docs` in umaxica-apps-edge |
| Rails namespace/controller | `Docs::Com::*` |
| Public host | `docs.jp.umaxica.com` |
| Private Rails host | `docs.com.localhost` |
| Audience | Public / corporate (`com`) |
| Surface | `docs` |
| Current implementation status | Rails thin root, health, and CMS read API implemented |
| CMS integration status | Rails API present; Edge does not consume it yet |

### org × docs

| Field | Value |
| --- | --- |
| Edge unit | `org/docs` in umaxica-apps-edge |
| Rails namespace/controller | `Docs::Org::*` |
| Public host | `docs.jp.umaxica.org` |
| Private Rails host | `docs.org.localhost` |
| Audience | Staff / organization (`org`) |
| Surface | `docs` |
| Current implementation status | Rails thin root, health, and CMS read API implemented |
| CMS integration status | Rails API present; Edge does not consume it yet |

### app × news

| Field | Value |
| --- | --- |
| Edge unit | `app/news` in umaxica-apps-edge |
| Rails namespace/controller | `News::App::*` |
| Public host | `news.jp.umaxica.app` |
| Private Rails host | `news.app.localhost` |
| Audience | End-user application (`app`) |
| Surface | `news` |
| Current implementation status | Rails thin root, health, and CMS read API implemented |
| CMS integration status | Rails API present; Edge does not consume it yet |

### com × news

| Field | Value |
| --- | --- |
| Edge unit | `com/news` in umaxica-apps-edge |
| Rails namespace/controller | `News::Com::*` |
| Public host | `news.jp.umaxica.com` |
| Private Rails host | `news.com.localhost` |
| Audience | Public / corporate (`com`) |
| Surface | `news` |
| Current implementation status | Rails thin root, health, and CMS read API implemented |
| CMS integration status | Rails API present; Edge does not consume it yet |

### org × news

| Field | Value |
| --- | --- |
| Edge unit | `org/news` in umaxica-apps-edge |
| Rails namespace/controller | `News::Org::*` |
| Public host | `news.jp.umaxica.org` |
| Private Rails host | `news.org.localhost` |
| Audience | Staff / organization (`org`) |
| Surface | `news` |
| Current implementation status | Rails thin root, health, and CMS read API implemented |
| CMS integration status | Rails API present; Edge does not consume it yet |

### app × help

| Field | Value |
| --- | --- |
| Edge unit | `app/help` in umaxica-apps-edge |
| Rails namespace/controller | `Help::App::*` |
| Public host | `help.jp.umaxica.app` |
| Private Rails host | `help.app.localhost` |
| Audience | End-user application (`app`) |
| Surface | `help` |
| Current implementation status | Rails thin root, health, and CMS read API implemented |
| CMS integration status | Rails API present; Edge does not consume it yet |

### com × help

| Field | Value |
| --- | --- |
| Edge unit | `com/help` in umaxica-apps-edge |
| Rails namespace/controller | `Help::Com::*` |
| Public host | `help.jp.umaxica.com` |
| Private Rails host | `help.com.localhost` |
| Audience | Public / corporate (`com`) |
| Surface | `help` |
| Current implementation status | Rails thin root, health, and CMS read API implemented |
| CMS integration status | Rails API present; Edge does not consume it yet |

### org × help

| Field | Value |
| --- | --- |
| Edge unit | `org/help` in umaxica-apps-edge |
| Rails namespace/controller | `Help::Org::*` |
| Public host | `help.jp.umaxica.org` |
| Private Rails host | `help.org.localhost` |
| Audience | Staff / organization (`org`) |
| Surface | `help` |
| Current implementation status | Rails thin root, health, and CMS read API implemented |
| CMS integration status | Rails API present; Edge does not consume it yet |

## Related

- `adr/publishing-db-content-authority.md`
- `docs/architecture/docs-help-news-content-boundary.md`
- `docs/architecture/regional-content.md`
