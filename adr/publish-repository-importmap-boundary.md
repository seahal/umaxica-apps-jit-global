# ADR: Publish Repository Uses Rails-Standard Importmap, Not a JS Bundler

## Status

Accepted (2026-09-14)

## Date

2026-09-14

## Context

`adr/split-into-regional-and-global-repos.md` split this codebase into a global repository (IdP +
primary RP) and a regional repository (region/locale-specific RP delivery). Independently,
`adr/publishing-db-content-authority.md` and `docs/architecture/docs-help-news-content-boundary.md`
centralized `info`, `docs`, `news`, and `help` content authority in the `publishing` database inside
this repository, with public article HTML explicitly assigned to Edge (`umaxica-apps-edge`, TanStack
Start on Cloudflare Workers, Astro migration in progress) rather than to Rails. Rails' role for those
four surfaces is deliberately thin: root and health endpoints plus the `GET /api/v0/entries` read
API, with no article index/detail, sitemap, or RSS rendering.

The codebase is converging toward three or more independent Rails repositories:

- **global** — the IdP + primary RP (`adr/split-into-regional-and-global-repos.md`).
- **regional** — region-owned RP delivery (`core`, `side`, `palm`; same ADR).
- **publish** (new, this decision) — the `info`/`docs`/`news`/`help` thin root+API surfaces
  currently under `Info::*`, `Docs::*`, `News::*`, `Help::*`, plus the `edit.*.org` staff publishing
  CMS currently under `Edit::Org::*`.

Global and regional both render real, interactive application UI and already use `vite_rails` with
Inertia Rails + React for that purpose; that pairing is settled and out of scope for this decision.

The publish surfaces are different in kind:

- `info`/`docs`/`news`/`help` root endpoints are, by the accepted content boundary above, permanently
  thin — Edge owns the actual article screens. The current Rails views for these are single
  placeholder pages with no interactivity.
- `edit.*.org` (`Edit::Org::*`) is today a real Inertia + React CMS. `Edit::Org::ApplicationController`
  itself defaults to a plain ERB layout (`edit/org/application`), but every screen a staff user
  actually operates renders Inertia: `Edit::Org::DashboardsController#show`
  (`app/controllers/edit/org/dashboards_controller.rb`), and — via the shared
  `PublishingManagementEntriesActions` and `PublishingManagementCell` concerns
  (`app/controllers/concerns/publishing_management_entries_actions.rb`,
  `app/controllers/concerns/publishing_management_cell.rb`) — the `index`/`show`/`new`/`create`/
  `edit`/`update` actions of all twelve `Edit::Org::Publishing::{Docs,Help,Info,News}::{App,Com,Org}
  ::EntriesController` classes (four content families × three audiences), plus their nested
  publication/archive failure re-renders. `SurfaceInertiaPage` is the marker concern that switches a
  controller's layout to `"#{family}/#{surface}/inertia"`; it is present on all of the above. Per
  this decision, `edit` is intended to
  follow `info`/`docs`/`news`/`help` into the same Edge-owns-the-screen model: Edge will eventually
  own the editing UI as well, extending the existing 3×4 (`app`/`com`/`org` × `info`/`docs`/`news`/
  `help`) content surface matrix (`docs/architecture/content-surface-matrix.md`) with an equivalent
  publish-repo/Edge split for `edit`. Rails' role in `edit` converges on the same shape as the other
  four: authority, persistence, and a read/write API, not the interactive screen.

Because none of the publish repository's surfaces are meant to own real client-side application UI
long-term, there is no reason for it to carry a JS bundler, a Node/Bun toolchain, or a
React/Inertia runtime. `importmap-rails` (already a dependency of this repository; see
`config/importmap.rb`) serves Turbo/Stimulus-class JavaScript directly through Propshaft with no
build step and no JS runtime dependency, which is a better fit for a repository whose HTML is either
a thin placeholder or destined to be replaced by Edge-owned screens.

## Decision

1. **The publish repository renders with Rails-standard importmap (`importmap-rails` +
   Turbo/Stimulus + Propshaft), not `vite_rails`, not Inertia Rails, and not React.** This applies to
   all surfaces that move into the publish repository: the `info`/`docs`/`news`/`help` thin
   root+API surfaces and the `edit.*.org` publishing CMS.
2. **No React or Inertia dependency remains in the publish repository's JavaScript.**
   `@inertiajs/*`, `react`, and `react-dom` are not carried into that repository's `package.json`.
   Server-rendered pages use Turbo/Stimulus via `importmap-rails`. CSS may still be built by Vite
   (`@tailwindcss/vite`, `vite_stylesheet_tag`) where a page wants Tailwind utility classes — as
   `info`/`docs`/`news`/`help` already did before this decision, and as `edit` does after its
   migration (see Implementation Status) — or by the `tailwindcss-rails` gem (a vendored native CLI
   binary, no Node/Bun required) where even the CSS build is meant to drop Node/Bun. This decision
   fixes the JS runtime/framework choice (no bundler-shipped JS framework), not the CSS build tool.
3. **`edit`'s current Inertia + React CMS UI is retired as part of the publish repository split**,
   not preserved. That UI is not one screen: it is the dashboard plus the full entries/publication/
   archive CRUD surface for all twelve content-family × audience combinations, all rendered through
   `SurfaceInertiaPage`. The interactive editing behavior it provides is rebuilt on Turbo/Stimulus +
   ERB (or handed to Edge, per the extended 3×4 matrix in the Context section) before or at the
   point `edit` moves into the publish repository. This is a materially larger migration than the
   `info`/`docs`/`news`/`help` root pages, which already match the target shape today.
4. **Global and regional are unaffected.** They keep `vite_rails` + Inertia Rails + React for their
   real application UI; this decision does not generalize the importmap choice beyond the publish
   repository.

## Implementation Status

`edit`'s Inertia + React removal (point 3) landed 2026-09-14, ahead of and independent of the
repository split itself: `Edit::Org::DashboardsController` and the `PublishingManagementCell`/
`PublishingManagementEntriesActions`/`PublishingManagementPublicationsActions`/
`PublishingManagementArchivesActions` concerns now render plain ERB (`app/views/edit/org/dashboards/
show.html.erb`, `app/views/edit/org/publishing/entries/{index,show,new,edit}.html.erb` — one shared
set of four templates for all twelve content-family × audience cells) instead of
`render inertia: true`. `SurfaceInertiaPage`/`SurfaceChrome` are no longer included by any `edit`
controller. The `edit/org/application` layout keeps `vite_stylesheet_tag` against
`src/styles/surfaces/edit_org.css` for Tailwind CSS and `javascript_importmap_tags` for Turbo/
Stimulus JS; `config/frontend_stacks.yml` reflects this as a `vite:`-CSS, non-Inertia entry. The
retired React sources (`src/entrypoints/inertia/edit_org.tsx`, `src/pages/edit/org/**`,
`src/features/publishing/Management{Index,Show,New,Edit}.tsx`) and the Inertia layout
(`app/views/layouts/edit/org/inertia.html.erb`) were deleted rather than left as dead code.

## Consequences

- The `info`/`docs`/`news`/`help` root pages can move to importmap essentially as-is: swap
  `vite_stylesheet_tag` for `stylesheet_link_tag` (or a `tailwindcss-rails` build), drop
  `src/styles/surfaces/{info,docs,news,help}_*.css` from the Vite graph, and drop those four
  surfaces from the `vite:` list in `config/frontend_stacks.yml`. No JS/React work is required
  because none of these pages use React or Inertia today.
- `edit`'s migration is not a rename; it requires re-implementing the entries/archives/
  publications/revisions/dashboards editing flows without Inertia and React before the surface can
  join the publish repository on this ADR's terms. Until that reimplementation lands, `edit` stays on
  its current Inertia + React stack in whatever repository hosts it.
- This ADR only fixes the *frontend rendering strategy* for the future publish repository. It does
  not itself perform the repository split, and it does not change which database or process
  currently serves these controllers — see `adr/split-into-regional-and-global-repos.md` and
  `adr/publishing-db-content-authority.md` for those boundaries.
- `docs/architecture/docs-help-news-content-boundary.md` and
  `docs/architecture/content-surface-matrix.md` are updated to cross-reference this decision.

## Related

- `adr/split-into-regional-and-global-repos.md`
- `adr/publishing-db-content-authority.md`
- `docs/architecture/docs-help-news-content-boundary.md`
- `docs/architecture/content-surface-matrix.md`
- `config/frontend_stacks.yml`
