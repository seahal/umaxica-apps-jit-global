# Design Philosophy

This file is a shorter colour-role sketch. Canonical UI primitives and tokens are in
`docs/design.md`. External implementation reading for UI work is the Digital Agency of Japan
Design System introduction: `docs/reference/digital-agency-design-system.md` and
<https://design.digital.go.jp/dads/introduction/>.

## 1. Color Roles

Colors are defined by their meaning (role) rather than their appearance. This ensures consistency
across different components and themes.

- `bg`: Main background color
- `fg`: Main foreground (text) color
- `muted`: Muted background for secondary elements
- `muted-fg`: Text color for muted elements
- `card`: Background color for card-like containers
- `card-fg`: Text color for elements inside cards
- `border`: Color for borders and dividers
- `primary`: Background color for primary actions
- `primary-fg`: Text color for primary actions
- `danger`: Background color for destructive actions
- `danger-fg`: Text color for destructive actions
- `ring`: Color for focus rings

## 2. Page Hierarchy

We do not use breadcrumbs. Each page follows a strict hierarchy:

1. **Up**: Link to the parent page or back in history.
2. **Title**: The main heading of the page.
3. **Description**: 1-2 lines explaining the page's purpose.
4. **Body**: The main content (forms, lists, etc.).

## 3. Up Navigation

- If `up_to` is provided, it links to that specific path.
- If `up_to` is not provided, it attempts `history.back()`.
- A fallback is provided for cases where history is unavailable or JS is disabled.
- The label should be "To [Parent Page Name]" (e.g., "To Settings").

## 4. UI Density & Layout

- **Mobile-First**: Designed primarily for mobile screens, scaling up for desktop.
- **Max Width**: The main content area is capped at `max-w-screen-sm` (approx. 640px) to maintain
  readability and mobile-like experience on large screens.
- **Touch Targets**: All interactive elements have a minimum size of 44x44px.
- **Vertical Stack**: Forms and lists are stacked vertically with ample whitespace.

## 5. Dark Mode

- Supports system preferences by default.
- Controlled via the `.dark` class on the `<html>` element.
- State is persisted in `localStorage`.
