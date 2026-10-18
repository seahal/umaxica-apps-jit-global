# Digital Agency Design System: source ledger

UMAXICA's authoritative specification is [the design guide](../design.md). DADS is
external guidance, not an installed component library or an automatic specification.
Preserve the independent frontend stacks and existing behavior when applying it.

Official material below was actually read on **2026-10-05**. The website displayed
**beta v2.18.0**, with its latest release notice dated **2026-09-09**. Individual page
update dates are listed below. No Figma assets, code snippets, fonts, or Markdown
archive were imported. Reading documents establishes no UMAXICA conformance claim.

Source: [Digital Agency Design System](https://design.digital.go.jp/dads/).
These English summaries were prepared and adapted by UMAXICA from Japanese guidance;
they are not Digital Agency authored product specifications.

## Reading ledger

**Confirmed** means the overview and the usage/accessibility pages exposed by that
item's current navigation were read. Some items contain guidance in the overview;
they do not expose separate usage/accessibility pages. Those absences are explicit.
**No applicability** is a product decision recorded in the implementation ledger.
**Inaccessible** means a requested source could not be retrieved; none listed below
was inaccessible. Applicability, adoption, rendered observations, and tests belong
in the implementation/deviation ledger, independently of this reading status.

All linked pages are official sources. Section names identify the content read.

| Item | Source and sections read | Displayed update | Status and relevant finding |
| --- | --- | --- | --- |
| Icons | [Overview](https://design.digital.go.jp/dads/foundations/icon/): front/lead/tail/end placement; [accessibility](https://design.digital.go.jp/dads/foundations/icon/accessibility/): labels, decorative alternatives, link containment, icon-only targets, contrast | 2025-07-30 | Confirmed in the acceptance reread. Pair icons with visible labels; icon-only exceptions need an equivalent name and 44px target. Use 4.5:1 normally; 3:1 only for guaranteed non-text usage. |
| Layout | [Overview](https://design.digital.go.jp/dads/foundations/layout/): grid, breakpoint, columns; [accessibility](https://design.digital.go.jp/dads/foundations/layout/accessibility/): liquid layout, reading order | 2024-07-31 | Confirmed. Choose columns for content; 768px is an example breakpoint. Keep overflow discoverable and DOM/focus order coherent. |
| Typography | [Overview](https://design.digital.go.jp/dads/foundations/typography/): family, size, line height, Standard/Dense/Oneline/Mono, decoration; [accessibility](https://design.digital.go.jp/dads/foundations/typography/accessibility/): user fonts, italics, presentation | 2026-08-05 | Confirmed. System fonts are allowed. Body/UI baseline is 16px; 14px is restricted to supplementary information or constrained density. Dense concerns administration/data. Preserve resize tolerance. |
| Color | [Overview](https://design.digital.go.jp/dads/foundations/color/): key/common/functional/accent/semantic colors; [accessibility](https://design.digital.go.jp/dads/foundations/color/accessibility/): contrast, brand, foreground/background, color diversity | 2026-08-05 | Confirmed. Assign color by role and measure actual backgrounds. DADS uses 4.5:1 even for large text. Its yellow/black focus palette is a DADS specification, not a WCAG color mandate. |
| Spacing | [Overview](https://design.digital.go.jp/dads/foundations/spacing/): function, scale, relationships/hierarchy; [accessibility](https://design.digital.go.jp/dads/foundations/spacing/accessibility/): whitespace/justification | 2024-05-30 | Confirmed. Related content gets closer spacing; use a purposeful scale. Do not align labels with inserted spaces or forced justification. |
| Link text | [Overview](https://design.digital.go.jp/dads/foundations/link-text/): structure, color, states, new tabs/files; [accessibility](https://design.digital.go.jp/dads/foundations/link-text/accessibility/): purpose, labels, targets | 2025-10-29 | Confirmed. Distinguish beyond color, normally with underlines. State destinations clearly; explain existing new-tab behavior without changing navigation. |
| Corner shapes | [Overview](https://design.digital.go.jp/dads/foundations/corner-shapes/): size, emphasis, whole/partial corners | 2024-05-30 | Confirmed; no separate usage/accessibility page exposed. Radius can differ by size and role to preserve perceived consistency. |
| Elevation | [Overview](https://design.digital.go.jp/dads/foundations/elevation/): shadows, levels, overlays; [accessibility](https://design.digital.go.jp/dads/foundations/elevation/accessibility/): dark mode, borders, dismissal | 2025-10-29 | Confirmed. Most content has no elevation. Shadows do not replace necessary boundaries. Preserve borders for forced colors. DADS explicitly provides no direct dark-mode style examples. |
| Button | [Overview/usage](https://design.digital.go.jp/dads/components/button/): dimensions, hierarchy, placement, disabled; [accessibility](https://design.digital.go.jp/dads/components/button/accessibility/): contrast, names, disabled, order, targets | 2024-09-10 | Confirmed. Actual targets are at least 44×44px without overlap. Labels wrap and height grows. Explain necessary disabled states. |
| Input | [Overview](https://design.digital.go.jp/dads/components/input-text/), [usage](https://design.digital.go.jp/dads/components/input-text/usage/): label/support/error, width, alignment; [accessibility](https://design.digital.go.jp/dads/components/input-text/accessibility/): placeholder, disabled/readonly, maxlength, paste, changes, errors | 2025-08-20 | Confirmed. Persistent support text explains existing conditions. Field errors use relationships rather than interrupting live regions. Validation/disabled recommendations require separate contract assessment. |
| Textarea | [Overview/usage](https://design.digital.go.jp/dads/components/textarea/): parts, response burden, limits/counter | 2025-12-24 | Confirmed; no separate accessibility page exposed. Explain existing limits before failure; do not invent limits. |
| Select | [Overview/usage](https://design.digital.go.jp/dads/components/select/): parts, native options, choice count | 2025-01-09 | Confirmed; no separate accessibility page exposed. Native option UI is specified. Five-or-fewer choices favor radio; changing existing controls needs contract assessment. |
| Checkbox | [Overview/usage](https://design.digital.go.jp/dads/components/checkbox/): parts, multiple choice/on-off, placement | 2025-09-10 | Confirmed; no separate accessibility page exposed. Control goes left of label. Assess label-inclusive hit area, not mark size alone. |
| Radio | [Overview/usage](https://design.digital.go.jp/dads/components/radio/): parts, single choice, optional selection | 2025-09-10 | Confirmed; no separate accessibility page exposed. Optional groups need a legitimate empty choice; do not fabricate server options. |
| Heading | [Overview](https://design.digital.go.jp/dads/components/heading/), [usage](https://design.digital.go.jp/dads/components/heading/usage/): structure/style/subtitle; [accessibility](https://design.digital.go.jp/dads/components/heading/accessibility/): levels, lists, dynamic insertion | 2026-02-26 | Confirmed. Separate semantic level from visual size; maintain meaningful hierarchy. Name/value lists are not automatically headings. |
| Table | [Overview](https://design.digital.go.jp/dads/components/table/), [usage](https://design.digital.go.jp/dads/components/table/usage/): density, headers, alignment, scrolling, links/actions; [accessibility](https://design.digital.go.jp/dads/components/table/accessibility/): simple structure | 2025-06-25 | Confirmed. Dense can harm touch operation. Prefer simple header relationships and local mobile scrolling. A row-wide link is not the DADS pattern. |
| Card | [Overview](https://design.digital.go.jp/dads/components/card/), [usage](https://design.digital.go.jp/dads/components/card/usage/): parts, border, hierarchy, clickable areas | 2025-07-10 | Confirmed; no separate accessibility page exposed. Group one subject; use tables for comparison. DADS requires visible boundaries; whole-card links cannot contain other controls. |
| Notification | [Overview/usage](https://design.digital.go.jp/dads/components/notification-banner/): types, parts, actions, placement, contrast | 2025-01-09 | Confirmed; no separate accessibility page exposed. Match importance/context. Distinguish service banners, field errors, and asynchronous status. |
| Header | [Overview/specification](https://design.digital.go.jp/dads/components/header-container/): wide/medium/compact, logo, utilities/navigation | 2026-05-27 | Confirmed; no separate usage/accessibility page exposed. Group for available width. Sample code was marked planned, not a verified UMAXICA implementation. |
| Navigation | [Horizontal menu overview](https://design.digital.go.jp/dads/components/horizontal-menu/): use cases, mobile, destination names, tabs | 2026-09-09 | Confirmed; no separate usage/accessibility page exposed. Formerly global menu. Keep consistent destinations; avoid abstract labels and excess items. Navigation differs from tab switching. |
| Mobile menu | [Overview/usage](https://design.digital.go.jp/dads/components/mobile-menu/): type, hierarchy, link/disclosure, sections | 2025-01-09 | Confirmed; no separate accessibility page exposed. Distinguish navigation from expansion. Preserve legitimate narrow-screen links. |
| Dialog | [Modal dialog overview](https://design.digital.go.jp/dads/components/modal-dialog/): use cases/cautions | 2026-09-09 | Confirmed; no separate usage/accessibility page exposed. Modal context limits operation to dialog. Avoid unexpected opening, routine-status dialogs, or decisions requiring inaccessible background. |

## Guidance and licensing

- [Style guides](https://design.digital.go.jp/dads/guidance/style-guides/), updated
  2024-05-30: confirmed. DADS is a platform design system; products define their own
  brand, information architecture, and adaptations.
- [Accessibility policy](https://design.digital.go.jp/dads/webaccessibility/), updated
  2025-12-10: confirmed. Its scope/JIS claim apply to the documentation website;
  Storybook samples are excluded. Neither claim transfers to UMAXICA.
- [Notices](https://design.digital.go.jp/dads/introduction/notices/), updated
  2026-08-05: confirmed, system content, Figma, snippets, and third-party terms.
  Website/Markdown content needs attribution; adaptations must be identified and
  not presented as Digital Agency authored work. Figma uses CC BY 4.0 with applicable
  material-specific terms; snippets use MIT. The notices distinguish edited screen
  parts from unedited redistribution. Preserve licenses if importing later; this
  change imports no assets or source code.

## WCAG distinctions

The engineering target is WCAG 2.2 A and AA; stronger accepted product requirements
remain in force. The [WCAG Recommendation](https://www.w3.org/TR/WCAG22/) and linked
Understanding sections below were checked on 2026-10-05. Understanding documents are
informative; success criteria in the Recommendation are normative.

- [2.5.8 Target Size, AA](https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html):
  24×24 CSS px, with spacing, equivalent, inline, unmodified-user-agent, and essential
  exceptions. Spacing tests 24px circles centered on undersized bounding boxes for
  intersections. Visible glyph/mark size alone does not establish actual target size.
- [2.5.5 Target Size, AAA](https://www.w3.org/WAI/WCAG22/Understanding/target-size-enhanced.html):
  44×44 CSS px, with equivalent, inline, user-agent, and essential exceptions; it has
  no AA-style spacing exception. DADS independently specifies 44×44px for buttons.
  Report a DADS departure separately from an AA failure.
- DADS's 16px baseline and restricted 14px usage are design specifications. WCAG has
  no universal 16px minimum. Resize, reflow, contrast, and spacing are separate tests.
- [1.4.11 Non-text Contrast, AA](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html):
  3:1 applies to information needed to identify controls/states or understand graphics,
  not every decorative divider or control border. DADS boundary rules can be stricter.
- [2.4.7 Focus Visible, AA](https://www.w3.org/WAI/WCAG22/Understanding/focus-visible.html)
  requires visible keyboard focus. [2.4.11 Focus Not Obscured, AA](https://www.w3.org/WAI/WCAG22/Understanding/focus-not-obscured-minimum.html)
  requires focused components not be entirely hidden by authored content. Assess
  sticky headers and cookie banners. [2.4.13 Focus Appearance, AAA](https://www.w3.org/WAI/WCAG22/Understanding/focus-appearance.html)
  separately specifies area and focused/unfocused pixel contrast; these are not AA.
- [4.1.3 Status Messages, AA](https://www.w3.org/WAI/WCAG22/Understanding/status-messages.html):
  qualifying dynamic status without context change needs programmatic exposure without
  focus. Initial content and context changes require different assessment. Missing
  literal `role="status"` proves no failure. DADS Input forbids `aria-live` and
  implicit-live `alert` on field errors; use relationships and assess asynchronous
  form status independently, avoiding duplicate announcements.

JIS X 8341-3:2016 corresponds to WCAG 2.0, as noted by
[DADS criteria notation](https://design.digital.go.jp/dads/foundations/). Track WCAG
2.2 additions such as 1.4.11, 2.4.11, 2.5.8, and 4.1.3 separately from JIS2016
coverage. This is a mapping note, not a JIS test result.

## Native asynchronous status source

Read on 2026-10-05: [WHATWG output element](https://html.spec.whatwg.org/multipage/form-elements.html#the-output-element),
Living Standard displayed update 2026-10-04, defines output for a calculation or user-action
result and excludes its value from form submission. This supports the existing async passkey
process display, without changing handlers or payload. The informative
[WCAG 2.2 status-message understanding](https://www.w3.org/WAI/WCAG22/Understanding/status-messages.html)
was read for dynamic progress/result context; it is distinct from the normative 4.1.3 criterion.
Native status semantics are DOM-verified; screen-reader delivery remains unverified.

## Foundations acceptance reread

The eight items at [Foundations](https://design.digital.go.jp/dads/foundations/) were reread
on 2026-10-05 against beta v2.18.0: Color, Typography, Icons, Layout, Link text, Spacing,
Corner shapes and Elevation. Icons were missing from the original reading ledger; the row
above records the actual additional reading, rather than implying they were read earlier.
Typography's [text styles](https://design.digital.go.jp/dads/foundations/typography/text-style/)
and Color's [palette](https://design.digital.go.jp/dads/foundations/color/color-palette/) were also
examined. The typography specification restricts 14px to supplementary or constrained content
and principally excludes smaller readable text; that is separate from WCAG resize/reflow tests.

The official website stylesheet [BovAeSFI.css](https://design.digital.go.jp/dads/assets/BovAeSFI.css)
was inspected to resolve the actual Yellow-300 value (#ffd43d) and yellow/black focus treatment.
The asset filename identifies the inspected resource, not a guaranteed permanent publication URL.
UMAXICA implements its own local rules; no official CSS, component code, font or image was
imported. Attribution/adaptation and license distinctions above continue to apply. Adoption
decisions are separately recorded as UI-22 through UI-29 in the implementation ledger.


## Components acceptance reading (2026-10-05)

Read the [component index](https://design.digital.go.jp/dads/components/) and all **49** listed
overviews, all **18** linked usage/accessibility pages, the Card example page and all **49**
changelogs: **117 component pages**, plus the index. Site version remains beta v2.18.0.
The displayed dates below refer to each overview, not a claim that every related page shares it.
No source archive, Figma, Storybook or provider assets were imported or verified by this reading.
Each row lists the sections actually read; absent separate usage/accessibility pages are not
invented. All source retrievals succeeded. Relevance and adoption are separate decisions in
[UI-30–38](ui-normalization-ledger.md#components-acceptance-refinement).

| Component | Official sections read | Overview update | Reading status / applicability |
| --- | --- | --- | --- |
| accordion | [Overview](https://design.digital.go.jp/dads/components/accordion/), [usage](https://design.digital.go.jp/dads/components/accordion/usage/), [changelog](https://design.digital.go.jp/dads/components/accordion/changelog/) | 2026-07-22 | Confirmed; No new product feature added; no implementation target identified in this change |
| image-slider | [Overview](https://design.digital.go.jp/dads/components/image-slider/), [changelog](https://design.digital.go.jp/dads/components/image-slider/changelog/) | 2026-02-04 | Confirmed; No new product feature added; no implementation target identified in this change |
| input-text | [Overview](https://design.digital.go.jp/dads/components/input-text/), [usage](https://design.digital.go.jp/dads/components/input-text/usage/), [accessibility](https://design.digital.go.jp/dads/components/input-text/accessibility/), [changelog](https://design.digital.go.jp/dads/components/input-text/changelog/) | 2025-08-20 | Confirmed; Existing control/content or navigation pattern |
| blockquote | [Overview](https://design.digital.go.jp/dads/components/blockquote/), [changelog](https://design.digital.go.jp/dads/components/blockquote/changelog/) | 2026-09-09 | Confirmed; No new product feature added; no implementation target identified in this change |
| card | [Overview](https://design.digital.go.jp/dads/components/card/), [usage](https://design.digital.go.jp/dads/components/card/usage/), [changelog](https://design.digital.go.jp/dads/components/card/changelog/), [example](https://design.digital.go.jp/dads/components/card/example/) | 2025-07-10 | Confirmed; Existing control/content or navigation pattern |
| list | [Overview](https://design.digital.go.jp/dads/components/list/), [usage](https://design.digital.go.jp/dads/components/list/usage/), [accessibility](https://design.digital.go.jp/dads/components/list/accessibility/), [changelog](https://design.digital.go.jp/dads/components/list/changelog/) | 2026-02-04 | Confirmed; Existing control/content or navigation pattern |
| image | [Overview](https://design.digital.go.jp/dads/components/image/), [changelog](https://design.digital.go.jp/dads/components/image/changelog/) | 2026-09-09 | Confirmed; Existing control/content or navigation pattern |
| carousel | [Overview](https://design.digital.go.jp/dads/components/carousel/), [usage](https://design.digital.go.jp/dads/components/carousel/usage/), [accessibility](https://design.digital.go.jp/dads/components/carousel/accessibility/), [changelog](https://design.digital.go.jp/dads/components/carousel/changelog/) | 2026-02-04 | Confirmed; No new product feature added; no implementation target identified in this change |
| emergency-banner | [Overview](https://design.digital.go.jp/dads/components/emergency-banner/), [changelog](https://design.digital.go.jp/dads/components/emergency-banner/changelog/) | 2025-01-21 | Confirmed; No new product feature added; no implementation target identified in this change |
| search-box | [Overview](https://design.digital.go.jp/dads/components/search-box/), [changelog](https://design.digital.go.jp/dads/components/search-box/changelog/) | 2026-09-09 | Confirmed; Existing control/content or navigation pattern |
| combobox | [Overview](https://design.digital.go.jp/dads/components/combobox/), [changelog](https://design.digital.go.jp/dads/components/combobox/changelog/) | 2026-09-09 | Confirmed; No new product feature added; no implementation target identified in this change |
| switch | [Overview](https://design.digital.go.jp/dads/components/switch/), [changelog](https://design.digital.go.jp/dads/components/switch/changelog/) | 2026-09-09 | Confirmed; No new product feature added; no implementation target identified in this change |
| horizontal-menu | [Overview](https://design.digital.go.jp/dads/components/horizontal-menu/), [changelog](https://design.digital.go.jp/dads/components/horizontal-menu/changelog/) | 2026-09-09 | Confirmed; Existing control/content or navigation pattern |
| scroll-top-button | [Overview](https://design.digital.go.jp/dads/components/scroll-top-button/), [changelog](https://design.digital.go.jp/dads/components/scroll-top-button/changelog/) | 2026-09-09 | Confirmed; Deprecated 2026-09-09; no new implementation |
| step-navigation | [Overview](https://design.digital.go.jp/dads/components/step-navigation/), [changelog](https://design.digital.go.jp/dads/components/step-navigation/changelog/) | 2026-09-09 | Confirmed; No new product feature added; no implementation target identified in this change |
| description-list | [Overview](https://design.digital.go.jp/dads/components/description-list/), [changelog](https://design.digital.go.jp/dads/components/description-list/changelog/) | 2026-09-09 | Confirmed; Existing control/content or navigation pattern |
| select | [Overview](https://design.digital.go.jp/dads/components/select/), [changelog](https://design.digital.go.jp/dads/components/select/changelog/) | 2025-01-09 | Confirmed; Existing control/content or navigation pattern |
| tab | [Overview](https://design.digital.go.jp/dads/components/tab/), [changelog](https://design.digital.go.jp/dads/components/tab/changelog/) | 2026-09-09 | Confirmed; No new product feature added; no implementation target identified in this change |
| checkbox | [Overview](https://design.digital.go.jp/dads/components/checkbox/), [changelog](https://design.digital.go.jp/dads/components/checkbox/changelog/) | 2025-09-10 | Confirmed; Existing control/content or navigation pattern |
| chip-tag | [Overview](https://design.digital.go.jp/dads/components/chip-tag/), [changelog](https://design.digital.go.jp/dads/components/chip-tag/changelog/) | 2026-09-09 | Confirmed; No new product feature added; no implementation target identified in this change |
| chip-label | [Overview](https://design.digital.go.jp/dads/components/chip-label/), [changelog](https://design.digital.go.jp/dads/components/chip-label/changelog/) | 2026-09-09 | Confirmed; No new product feature added; no implementation target identified in this change |
| notice-block | [Overview](https://design.digital.go.jp/dads/components/notice-block/), [changelog](https://design.digital.go.jp/dads/components/notice-block/changelog/) | 2026-09-09 | Confirmed; Existing control/content or navigation pattern |
| disclosure | [Overview](https://design.digital.go.jp/dads/components/disclosure/), [usage](https://design.digital.go.jp/dads/components/disclosure/usage/), [changelog](https://design.digital.go.jp/dads/components/disclosure/changelog/) | 2026-07-22 | Confirmed; No new product feature added; no implementation target identified in this change |
| divider | [Overview](https://design.digital.go.jp/dads/components/divider/), [changelog](https://design.digital.go.jp/dads/components/divider/changelog/) | 2025-01-09 | Confirmed; Existing control/content or navigation pattern |
| table-control | [Overview](https://design.digital.go.jp/dads/components/table-control/), [changelog](https://design.digital.go.jp/dads/components/table-control/changelog/) | 2026-09-09 | Confirmed; No new product feature added; no implementation target identified in this change |
| table | [Overview](https://design.digital.go.jp/dads/components/table/), [usage](https://design.digital.go.jp/dads/components/table/usage/), [accessibility](https://design.digital.go.jp/dads/components/table/accessibility/), [changelog](https://design.digital.go.jp/dads/components/table/changelog/) | 2025-06-25 | Confirmed; Existing control/content or navigation pattern |
| textarea | [Overview](https://design.digital.go.jp/dads/components/textarea/), [changelog](https://design.digital.go.jp/dads/components/textarea/changelog/) | 2025-12-24 | Confirmed; Existing control/content or navigation pattern |
| drawer | [Overview](https://design.digital.go.jp/dads/components/drawer/), [changelog](https://design.digital.go.jp/dads/components/drawer/changelog/) | 2025-01-15 | Confirmed; No new product feature added; no implementation target identified in this change |
| notification-banner | [Overview](https://design.digital.go.jp/dads/components/notification-banner/), [changelog](https://design.digital.go.jp/dads/components/notification-banner/changelog/) | 2025-01-09 | Confirmed; Existing control/content or navigation pattern |
| breadcrumb | [Overview](https://design.digital.go.jp/dads/components/breadcrumb/), [changelog](https://design.digital.go.jp/dads/components/breadcrumb/changelog/) | 2026-08-19 | Confirmed; No new product feature added; no implementation target identified in this change |
| hamburger-menu-button | [Overview](https://design.digital.go.jp/dads/components/hamburger-menu-button/), [changelog](https://design.digital.go.jp/dads/components/hamburger-menu-button/changelog/) | 2025-01-09 | Confirmed; No new product feature added; no implementation target identified in this change |
| date-picker | [Overview](https://design.digital.go.jp/dads/components/date-picker/), [usage](https://design.digital.go.jp/dads/components/date-picker/usage/), [accessibility](https://design.digital.go.jp/dads/components/date-picker/accessibility/), [changelog](https://design.digital.go.jp/dads/components/date-picker/changelog/) | 2025-10-29 | Confirmed; No new product feature added; no implementation target identified in this change |
| file-upload | [Overview](https://design.digital.go.jp/dads/components/file-upload/), [usage](https://design.digital.go.jp/dads/components/file-upload/usage/), [accessibility](https://design.digital.go.jp/dads/components/file-upload/accessibility/), [changelog](https://design.digital.go.jp/dads/components/file-upload/changelog/) | 2026-01-22 | Confirmed; No new product feature added; no implementation target identified in this change |
| progress-indicator | [Overview](https://design.digital.go.jp/dads/components/progress-indicator/), [changelog](https://design.digital.go.jp/dads/components/progress-indicator/changelog/) | 2026-09-09 | Confirmed; Existing control/content or navigation pattern |
| page-navigation | [Overview](https://design.digital.go.jp/dads/components/page-navigation/), [changelog](https://design.digital.go.jp/dads/components/page-navigation/changelog/) | 2026-09-09 | Confirmed; Existing control/content or navigation pattern |
| header-container | [Overview](https://design.digital.go.jp/dads/components/header-container/), [changelog](https://design.digital.go.jp/dads/components/header-container/changelog/) | 2026-05-27 | Confirmed; Existing control/content or navigation pattern |
| button | [Overview](https://design.digital.go.jp/dads/components/button/), [accessibility](https://design.digital.go.jp/dads/components/button/accessibility/), [changelog](https://design.digital.go.jp/dads/components/button/changelog/) | 2024-09-10 | Confirmed; Existing control/content or navigation pattern |
| bottom-navigation | [Overview](https://design.digital.go.jp/dads/components/bottom-navigation/), [changelog](https://design.digital.go.jp/dads/components/bottom-navigation/changelog/) | 2026-09-09 | Confirmed; Deprecated 2026-09-09; no new implementation |
| heading | [Overview](https://design.digital.go.jp/dads/components/heading/), [usage](https://design.digital.go.jp/dads/components/heading/usage/), [accessibility](https://design.digital.go.jp/dads/components/heading/accessibility/), [changelog](https://design.digital.go.jp/dads/components/heading/changelog/) | 2026-02-26 | Confirmed; Existing control/content or navigation pattern |
| mega-menu | [Overview](https://design.digital.go.jp/dads/components/mega-menu/), [changelog](https://design.digital.go.jp/dads/components/mega-menu/changelog/) | 2026-09-09 | Confirmed; No new product feature added; no implementation target identified in this change |
| menu-list | [Overview](https://design.digital.go.jp/dads/components/menu-list/), [changelog](https://design.digital.go.jp/dads/components/menu-list/changelog/) | 2025-01-09 | Confirmed; No new product feature added; no implementation target identified in this change |
| menu-list-box | [Overview](https://design.digital.go.jp/dads/components/menu-list-box/), [changelog](https://design.digital.go.jp/dads/components/menu-list-box/changelog/) | 2025-01-09 | Confirmed; No new product feature added; no implementation target identified in this change |
| modal-dialog | [Overview](https://design.digital.go.jp/dads/components/modal-dialog/), [changelog](https://design.digital.go.jp/dads/components/modal-dialog/changelog/) | 2026-09-09 | Confirmed; Existing control/content or navigation pattern |
| toc | [Overview](https://design.digital.go.jp/dads/components/toc/), [changelog](https://design.digital.go.jp/dads/components/toc/changelog/) | 2026-09-09 | Confirmed; No new product feature added; no implementation target identified in this change |
| mobile-menu | [Overview](https://design.digital.go.jp/dads/components/mobile-menu/), [changelog](https://design.digital.go.jp/dads/components/mobile-menu/changelog/) | 2025-01-09 | Confirmed; No new product feature added; no implementation target identified in this change |
| utility-link | [Overview](https://design.digital.go.jp/dads/components/utility-link/), [changelog](https://design.digital.go.jp/dads/components/utility-link/changelog/) | 2025-01-09 | Confirmed; Existing control/content or navigation pattern |
| radio | [Overview](https://design.digital.go.jp/dads/components/radio/), [changelog](https://design.digital.go.jp/dads/components/radio/changelog/) | 2025-09-10 | Confirmed; Existing control/content or navigation pattern |
| language-selector | [Overview](https://design.digital.go.jp/dads/components/language-selector/), [changelog](https://design.digital.go.jp/dads/components/language-selector/changelog/) | 2025-01-09 | Confirmed; Existing control/content or navigation pattern |
| resource-list | [Overview](https://design.digital.go.jp/dads/components/resource-list/), [changelog](https://design.digital.go.jp/dads/components/resource-list/changelog/) | 2026-09-09 | Confirmed; Existing control/content or navigation pattern |


Native HTML is preferred for ordinary selection and existing direct date entry. React Aria
remains responsible for existing buttons, text fields, choices and modal interactions where it
adds keyboard/focus behavior. Adobe's [quality guidance](https://react-aria.adobe.com/quality)
was checked; library validation does not establish application accessibility. The existing
`I18nProvider` public API now follows Rails `html[lang]`. No new library or production dependency
is introduced in this acceptance change. ERB retains Rails FormTagHelper/form_with and native
controls; [Rails FormTagHelper](https://api.rubyonrails.org/classes/ActionView/Helpers/FormTagHelper.html)
was consulted for labels, descriptions and unchanged field submission.
