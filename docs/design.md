# UMAXICA presentation design

This is the canonical specification for human-facing Rails HTML and React/Inertia UI.
Implementation ownership remains defined by `config/frontend_stacks.yml` and
[the accepted frontend-stack ADR](../adr/20260907-frontend-stack-importmap-vite-bun.md).
Independent trust boundaries and delivery stacks implement the same presentation rules;
they do not share authorization, sessions, server props, or a new cross-stack component runtime.

Start here, then follow the [host/view inventory](reference/ui-view-inventory.md),
[DADS source ledger](reference/digital-agency-design-system.md), and
[implementation/deviation record](reference/ui-normalization-ledger.md).
The historical `DESIGN.md` and `docs/architecture/design.md` remain archival material.
DADS beta v2.18.0 informs these decisions; it is neither an installed library nor a product brand.

## Decision rules

A visitor should understand the purpose, current location, and next permitted action. Place
purpose and the primary task before secondary explanations. Give related information smaller
spacing than independent sections. Preserve visible labels and destinations; do not hide
requirements solely in placeholders. Keep actions available when titles are absent or long.

Use the following small model without a configuration engine:

| Layer | Rule | Existing implementation |
| --- | --- | --- |
| Global invariants | Legible text, underlined text links, visible focus, coherent fields and actions | UI primitives and each stack's stylesheet |
| Page archetype | Single-decision ceremonies/results are narrow; forms/hubs/details default; data lists wide | `Page.width`; ERB `.ui-page` variants or equivalent Vite utilities |
| Surface profile | Show the existing role and only the links allowed by existing data | Existing `SurfaceLayout` and surface-local layouts |
| Edition identity | Preserve formal names and app/com/org tint; never infer permissions from TLD | Existing edition stylesheet; ERB `data-edition` |
| Documented exception | Preserve special rendering and behavior when ordinary chrome is inappropriate | Plain responses, offline, relay, vendor UI, provider buttons |

Identity, Preference, Switcher, Logout is the authenticated menu ordering when existing data
provides those destinations. This presentation work does not create absent props, fetch identity,
add authentication options, or move ceremony cancellation into generic navigation.

## Layout and typography

The shell owns outer gutters: 16px on small screens, 24px from 640px, and the main vertical
space. Content does not add another full shell gutter. Content widths are maximums, not fixed
widths: narrow 28rem, default 42rem, wide 56rem. Wide data must still fit its shell or scroll
locally. Equality of a wide maximum and its shell maximum is intentional, not evidence of failure.

Ordinary body text, labels, navigation and action labels are 16px at the default root size.
Input conditions, error messages and decision explanations are also 16px. Dense administrative
table cells, JSON/monospace editors and supplementary metadata may use 14px where their limited
role is explicit. Ordinary human-readable content does not use 12px; the decorative checkbox
tick is a glyph, not small instructional text.
These are density decisions, not WCAG font-size thresholds. Never shrink primary instructions
or controls to fit a layout. System fonts remain local; Japanese text uses strict line breaking,
normal word breaking, and 1.7 body line height, with Latin body text at 1.5.

Ordinary page titles are 24px on small screens and 30px from 640px. Landing titles are 30/36px.
Section headings are 20px. Semantic levels follow document structure; visual scale does not
justify skipped levels. Long headings, URLs and display values can wrap without page overflow.
Page descriptions follow titles; actions wrap alongside them or onto the next line. Default
page section spacing is 32px in both stacks; internal relationships use 4/8px, action groups
8/12px, panels 16/24px. Field groups use 8px between label, control and support. Description
lists use a 32px horizontal gutter in their two-column arrangement, with natural wrapping.

## Color, boundaries and shape

React uses `src/styles/theme.css`, imported within its own surface stack. Propshaft uses
`app/assets/stylesheets/application.css`, independently encoding the same installed palette
values and roles. Existing per-edition tints remain red-500, indigo-500 and green-500; text names
identify editions too. Xper retains its established placeholder stylesheet.

| Role | React utility / ERB variable | Use |
| --- | --- | --- |
| Canvas / surface / muted surface | `bg-canvas`, `bg-surface`, `bg-surface-muted` | Background hierarchy; canvas tint mixes 15% in light and 8% in dark |
| Primary / secondary text | `text-fg`, `text-fg-muted` | Body, descriptions and supporting information |
| Decorative separator | `border-line` / `--ui-line` | Nonessential dividers; no blanket 3:1 demand |
| Necessary control boundary | `border-control` / `--ui-control` | Inputs and secondary buttons; distinct from decorative separators |
| Text link | `text-link` / `--ui-link` | Blue-700 in light / blue-400 in dark, readable on tinted canvas |
| Action / hover / foreground | `bg-accent`, `bg-accent-hover`, `text-accent-fg` | Primary executable or destination action |
| Destructive fill / foreground | `bg-danger`, `bg-danger-hover`, `text-danger-fg` | Existing destructive actions |
| Error text | `text-error` / `--ui-error` | Readable rejection text; separate from destructive fill |
| Overlay boundary | `border-overlay` / `--ui-overlay-border` (React overlays) | Dialog/popover edges; distinct from control borders and decorative separators |
| Focus | `--ui-focus-inner`, `--ui-focus-outer` | Yellow-300 (#ffd43d) 2px inner band, black 4px outline with 2px offset |
| Visited / active text link | `--ui-link-visited`, `--ui-link-active` | Purple-800 / orange-800 in light; purple-300 / orange-300 in dark |

Measure actual foreground/background states, including tinted canvas, hover and opacity.
Disabled controls keep native disabled behavior; opacity is not a substitute for that behavior.
Most panels have borders and no shadow. Small controls and navigation rows use 6px corners;
dialogs retain 8px; subject cards/table containers retain 12px. Avatars retain their existing
silhouette, and compact cookie dismissal retains its circular target. These role differences
are intentional. Do not turn every section into a card.

Theme remains the server-rendered `data-theme` from the existing cookie: light, dark or system.
Explicit light overrides an OS dark preference; system follows the OS. No new persistence is
introduced. Preserve reduced-motion rules and forced-color boundaries.

## Interaction and accessibility

Text links are underlined at rest (1px, 0.2em offset); hover strengthens the underline to 2px
without changing text geometry. Native `:visited` and `:active` provide additional state cues;
no application history store or persistence is introduced. Navigation arrows stay outside the
underlined label, inside the same link. Text links have meaningful existing labels. The existing typographic brand link keeps its wordmark treatment and visible focus. Destinations remain
anchors or existing Inertia links; commands remain buttons. Button-like links share appearance
within the React stack, without changing document/Inertia/cross-origin navigation.

Ordinary buttons have a 44px minimum width and height; default controls are 48px tall. Small
buttons are 44px tall. Checkbox/radio labels include a real 44px-high clickable row; their marks
can remain 16px. Targets wrap and grow without overlapping invisible hit regions. This adopts
DADS's button recommendation. WCAG 2.2 AA 2.5.8 has a separate 24px target/spacing criterion with
exceptions; 44px is also the stricter AAA 2.5.5 size criterion, not the AA threshold.

Fields retain native type, name, value, autocomplete, constraints, disabled, submitter and form
membership. React Aria connects labels/descriptions/errors. ERB uses explicit labels referencing
existing generated input IDs and describes field errors by ID. Do not invent required flags,
validation, limits or empty choices. Field errors are not live regions. Initial server summaries
are ordinary readable content; `ErrorList announce` is reserved for existing asynchronous form
failures. Existing service/banner and asynchronous notifications retain their contextual semantics.
A form-wide conflict is different from an error attached to one input. Existing asynchronous
passkey process messages use a persistent native `output` (implicit status role) without moving
focus; rejection remains separate. Output does not change the submitted payload.

A first keyboard-reachable skip link targets `main#main[tabindex=-1]` without adding it to normal
Tab order. Header and cookie controls remain in document flow, reducing focus obstruction.
Dialogs retain React Aria focus containment and return to their trigger, with bounded vertical
scrolling. Tables scroll in a focusable local container and use a region name when the existing
page title is available. Table headings use `scope` in ERB; data order remains unchanged.

The engineering quality target is WCAG 2.2 A/AA, while existing stricter requirements remain.
Visible focus (2.4.7 AA), focus not obscured (2.4.11 AA), and enhanced focus appearance (2.4.13 AAA)
are separate checks. JIS X 8341-3:2016 maps to WCAG 2.0; the source ledger records newer criteria
separately. Representative axe/DOM/keyboard checks do not establish full conformance or actual
screen-reader usability. Assistive technology and complete authenticated state coverage remain explicit
verification limits in the implementation record.

## Exceptions and extending the system

Plain-text authentication/network errors, API responses, mailer documents, noscript fallbacks,
OIDC auto-submitting relay and offline documents keep their contracts. Offline retains its native retry and gains a main landmark. Its existing inline styling is
blocked by the PWA controller CSP; changing its nonce/cache delivery needs a separate task. Content roots remain thin Rails pages; Edge
article HTML and regional repositories are not reconstructed here. Provider buttons retain their
existing official branding implementations and assets; ordinary button rules must not silently
recolor or transform them. Ordinary single-choice fields use native select/option behavior; React Aria remains in
existing controls that need its interaction and focus management.

Before adding a new variant, demonstrate an existing task that needs it. Reuse within each stack;
implement the same specification separately across stacks. Record applicability and reasons for
exceptions in the deviation ledger, along with rendered evidence and verification limits.

## Foundations acceptance refinement (2026-10-05)

Reading content uses `.ui-prose`, independently implemented in each stack: maximum 65ch for
Latin text and 40em for Japanese, within the existing Page maximum. Paragraph/list/quotation
separation is 1.5 times the line height (`1.5lh`, with an em fallback); body line heights remain
1.5 / 1.7. InfoPage, Page descriptions and shared article bodies use this treatment. Forms,
metadata and data lists keep their own useful widths and relationships. The DADS 768px example
does not require changing every layout at that width. DOM reading and focus order remain natural.

Focus appears immediately, without interpolating outline color. Hidden native choice inputs
retain keyboard/form semantics; their visible enclosing labels show focus. Forced colors use
the system Highlight outline and no box shadow. The existing Apple appearance/logo/size
contract is retained while focus gets the same indicator; no provider artwork was changed.

Icons accompany visible labels where possible. Decorative navigation arrows/check marks are
hidden from assistive technology and get no separate accessible name or link. Existing icon-only
cookie dismissal keeps its translated accessible name and a minimum 44px target. Inline icons
use text colors with a 4.5:1 design target; 3:1 is reserved for guaranteed non-text usage, distinct
from WCAG's necessary-information criterion. No new icon library or product function is added.

Dialog borders must be distinguishable against the surface and composited backdrop, measured
separately. Ordinary selects now use the native OS option UI; they introduce no app-owned popover. Shadows are not the necessary boundary. Dark-mode treatment
is a UMAXICA decision because DADS supplies no direct dark-mode examples.

The [acceptance ledger](reference/ui-normalization-ledger.md#foundations-acceptance-refinement)
records the eight decisions and their verification limits. Representative tests establish their
stated scopes, not whole-product WCAG/JIS conformance.


## Components acceptance specification (2026-10-05)

- Ordinary single choice uses a native `select`, including the existing disabled stored option,
  names, values and required/disabled states. The parent retains Inertia transport. Do not invent
  an empty choice, radio choices or new validation; variable preferences retain their select.
- Labels precede persistent conditions, then the control, then static field errors. Existing
  moniker grapheme/UTF-8 limits are displayed from supplied translations. Birthdate keeps its
  number types, min/max, autocomplete, required, IDs and data hooks, with visible examples.
- Ordinary tables use 16px text. Explicit administrative/editorial Dense tables use 14px;
  dense does not apply to page instructions or shrink action targets. Header boundaries are
  stronger than decorative row lines. Local focusable scrolling has edge cues and native
  scrollbars; forced colors uses native scrollbars/borders rather than gradient cues.
- A subject card has its supplied heading as a semantic region name and a control-strength
  boundary. A plain grouping panel remains a div with a decorative line. Existing callers
  without headings are not given invented headings or whole-card links.
- Landmark names are translated by Rails views. Inertia layouts render presentation-only meta
  labels without altering page/chrome props. React Aria follows document language through
  `DocumentLocale`; it does not write locale, cookie or theme state. A later document-lang
  change is observed; end-to-end language preference transitions remain separately verified.
- Pressed ordinary buttons keep opaque text/fill and use the existing hover palette; disabled
  remains genuinely disabled. A disabled administrative confirmation explains its existing
  acknowledgement/processing reason, using translated view metadata. Provider buttons retain
  their independent requirements.
- Administration notices form one live group with the highest existing urgency, avoiding
  competing status/alert regions. Visible tone markers are decorative beside unchanged text.
  Static field errors and service banners retain their own contexts; no blanket role policy.

See [the component acceptance ledger](reference/ui-normalization-ledger.md#components-acceptance-refinement)
for evidence, implementation coverage, deliberate differences and remaining verification.
