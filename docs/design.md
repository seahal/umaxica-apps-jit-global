# Design Philosophy

The design system is small on purpose. Every screen in the application is one of a handful of shapes
— a ceremony, a form, a list, a detail view — so the system is the set of primitives those shapes
are built from, plus one token layer they all draw their colours from. There is no visual decision
left to an individual page.

The primitives live in `src/components/ui/`. The token layer lives in `src/styles/theme.css`. A page
that needs a colour, a width or a spacing step takes it from one of those two places and never
writes a literal.

`core/dev` renders every primitive on one page (`src/features/ui_gallery/UiGallery.tsx`). That is
where the visual states no unit test can assert — the focus ring, the dark palette, contrast, the
overlay's position — get checked in a real browser.

Before inventing a screen pattern, read the Digital Agency of Japan Design System introduction as
implementation guidance: `docs/reference/digital-agency-design-system.md` and
<https://design.digital.go.jp/dads/introduction/>. That site is an external accessibility-first
rule set, not this application's component library.

## 1. Color Roles

Colours are named by their role, never by their appearance, so one name has a light value and a dark
value and a component never has to know which it is looking at. The `--ui-*` custom properties in
`src/styles/theme.css` hold the pair; `@theme inline` publishes them as Tailwind utilities.

| Utility            | Role                                                                |
| ------------------ | ------------------------------------------------------------------- |
| `bg-canvas`        | The page floor, mixed from the surface's own `--ui-tint`            |
| `bg-surface`       | Cards, panels, controls — what sits on the canvas                   |
| `bg-surface-muted` | A second step: table headers, banner bands, hover fills             |
| `text-fg`          | Primary text                                                        |
| `text-fg-muted`    | Secondary text: descriptions, captions, timestamps, disabled labels |
| `border-line`      | Every border and divider                                            |
| `bg-accent`        | Primary actions, with `text-accent-fg` on top                       |
| `bg-danger`        | Destructive actions, with `text-danger-fg` on top                   |

`--ui-tint` is the per-edition identity hue and the only token a surface stylesheet overrides. Both
the light and the dark canvas are mixed from it, so the two modes cannot drift apart.

The focus ring is not a role a component reaches for: `theme.css` paints one `:focus-visible`
outline for the whole document, so every focusable element agrees without restating it.

## 2. Page Hierarchy

We do not use breadcrumbs. Every page follows the same hierarchy, and `Page` is that hierarchy:

1. **Up** — the link to the parent screen, above the title.
2. **Title** — the page's `<h1>`. There is exactly one per page.
3. **Description** — one or two lines saying what the page is for.
4. **Body** — the form, list or panels.

A page renders `<Page title=… description=… up=… />` and nothing about its own width or gutter.
Page-level controls — "add a passkey", "revoke every session" — go in `actions`, which renders them
opposite the title.

## 3. Up Navigation

- `up` takes the server-resolved link. Rails decides where the parent is; the page never guesses.
- `upVisit` decides how it is followed. The default, `document`, is correct for the common case: a
  ceremony's parent usually sits on another surface, and an Inertia visit to another origin is an
  XHR that CORS rejects. `upVisit="inertia"` is for a parent that genuinely lives on this surface.
- The arrow beside the label is decorative and hidden from assistive technology; the label alone is
  the link's accessible name.

## 4. UI Density & Layout

- **Mobile-first**, scaling up for desktop.
- **The gutter is owned by `SurfaceLayout`.** Header, main column and footer share one `SHELL`
  class, so the brand, the page title and the footer links sit on one vertical line at every width.
- **Content width is a scale of three**, chosen by what the page holds rather than by how much copy
  it has today:
  - `narrow` — a single-purpose ceremony: one field, one button, one decision
  - `default` — the ordinary page: a form, a short list, a settings panel
  - `wide` — tabular data and multi-column content
- **Vertical stack.** Forms and lists stack with a uniform gap; `Page` spaces its own children.
- **Touch targets.** Controls come from the primitives, which carry the size.

## 5. Primitives

| Primitive         | What it is                                                             |
| ----------------- | ---------------------------------------------------------------------- |
| `Page`            | The page shell: up, title, description, actions, body, width           |
| `Card`            | A bordered surface panel with the section heading it usually carries   |
| `Button`          | The one button. React Aria owns activation                             |
| `ButtonLink`      | A destination wearing `Button`'s appearance, from the same source      |
| `TextLink`        | The one inline link, in a default and a muted tone                     |
| `NavList`         | A vertical list of destinations; a row without a URL renders as text   |
| `Table`           | The one data table, scrolling inside its own container                 |
| `DescriptionList` | Term-and-value detail, stacked on a phone and side-by-side above it    |
| `ErrorList`       | The server's validation messages, as one `role="alert"` block          |
| `TextField`       | A labelled input with its error bound to it through `aria-describedby` |
| `Select`          | A labelled select with the same label, description and error wiring    |
| `Checkbox`        | A labelled checkbox over a real `<input type="checkbox">`              |
| `RadioGroup`      | A labelled radio group                                                 |
| `Dialog`          | A modal that traps focus and returns it to the control that opened it  |

Validation is the server's decision in every case. A field component never decides whether a value
is valid and never authors visitor-facing copy: the message arrives already translated in the page
props.

`ErrorList` is the only summary treatment. It replaced `FormErrors` and `VerificationErrors`, which
rendered the same decision three ways — a bulleted danger panel on the identity forms, a
comma-joined muted panel on the verification ceremonies — so which screen a visitor happened to be
on decided how a rejection looked. A screen that needs a heading above the messages passes `header`;
a screen with nothing to say passes an empty array and the component renders nothing.

## 6. Dark Mode

The theme lives on `<html data-theme>`, written by the server from the `ct` cookie and kept in sync
by `src/lib/theme.ts`. The attribute is always `light`, `dark` or `system`:

- `dark` — always dark, whatever the operating system says
- `system` — dark only while the operating system is dark
- `light` — stays light under a dark operating system

Keying on the attribute rather than on `prefers-color-scheme` alone is what makes that last case
work, and rendering it on the server means the first paint is already correct.
