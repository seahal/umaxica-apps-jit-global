# Digital Agency Design System (implementation reading)

When implementing or changing user-facing UI, read the Digital Agency of Japan's Design System
introduction as an external implementation pointer. It is not this application's component library
and does not replace `docs/design.md`; it is the public, accessibility-first rule set we consult
before inventing screen patterns.

- Introduction index: <https://design.digital.go.jp/dads/introduction/>
- First-time readers: <https://design.digital.go.jp/dads/introduction/about/>
- Notices and licensing: <https://design.digital.go.jp/dads/introduction/notices/>
- Site root: <https://design.digital.go.jp/dads/>

The introduction is written in Japanese. The pages above are the source; this file only records
that we treat them as implementation guidance.

What to take from those pages:

- A design system is a set of rules for appearance and interaction, not a catalog of one-off
  decorations.
- Accessibility notes on components and templates are meant to be used during design and
  development, not after the fact.
- Designers, developers, and information architects are the intended readers; guidance after the
  introduction is specialist documentation.
- Using a design system does not remove design work. It moves effort onto screen structure and
  quality instead of reinventing parts.

This application still owns its primitives in `src/components/ui/` and its token layer in
`src/styles/theme.css`. Do not copy Digital Agency Figma files or code snippets into this
repository without following the notices page (source attribution for unedited content; edited
content must not be presented as Digital Agency work).

Source: Digital Agency Design System website <https://design.digital.go.jp/dads/>
