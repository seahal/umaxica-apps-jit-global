# Components acceptance handoff

The nine accepted proposals are specified in [docs/design.md](../../docs/design.md) and
[UI-30–38](../../docs/reference/ui-normalization-ledger.md#components-acceptance-refinement).
This note records implementation interpretation; the guide remains authoritative.

- The earlier retained React Aria Select exception was superseded after native-selection
  regression tests covered preference transport and disabled stored choices. Other Aria
  components remain. A small-choice radio replacement was considered but not applied to
  variable server option sets; no empty option or new preference semantics was invented.
- Administration notices can arrive through Inertia. Removing every live role would lose
  async result announcements, so they now share one region at the highest existing urgency.
  Actual screen-reader speech remains unverified; DOM role tests are narrower evidence.
- Translation authority stays Rails-owned. Display-only meta labels avoid an unauthorized
  server-prop addition. These labels describe existing navigation and disabled states only.
  Base deliberately has no footer navigation; no links were added to make test fixtures match
  other surfaces. DocumentLocale observes language, and never changes persistence.
- Final image review found a nested fieldset overflow at 200% root font despite no page-level
  overflow. A failing containment test reproduced the 297px versus 247px right edge, followed
  by min-width/wrapping correction. This is why page overflow alone was insufficient.
- Test processes must finish before starting the browser server: Rails preparation and asset
  rebuilds can conflict with open DB connections or cached manifest names. Stop only owned
  processes, retain database guards, and restart after the completed build. The interrupted
  authenticated attempt and subsequent successful rerun are recorded in evidence.

Current-session checks and explicit coverage limits are in
[evidence](../../evidence/2026-10-05-ui-components-T8D2.md). Complete locale preference journeys,
real assistive technology, actual mobile OS pickers and protected ceremony mutations remain
outside the verified representative set. No authentication or asset contract was relaxed.
