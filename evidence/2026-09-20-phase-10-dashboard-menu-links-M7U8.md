# Phase 10 dashboard menu links

- Date: 2026-09-20
- Scope: Base app/com/org signed-in dashboard presentation only

The Base dashboard controllers now emit `Menu links` before `Primary links`. App uses the existing
Switcher route; com and org retain their existing Selector routes. Preference and Logout were moved
to the menu section on all three surfaces. Other primary, publishing, and protocol content was not
invented or reordered. Rails route helpers continue to build the URLs and preserve the request
context parameters tested here.

Focused Rails verification:

```text
PARALLEL_WORKERS=1 bin/rails test test/controllers/base/app/welcome_dashboard_authority_slice_1c_test.rb test/controllers/base/com/welcome_dashboard_authority_slice_1c_test.rb test/controllers/base/org/welcome_dashboard_authority_slice_1c_test.rb
19 runs, 267 assertions, 0 failures, 0 errors, 0 skips
```

The three surface tests verify section order, intended menu destinations, no duplication in Primary
links, preservation of the other dashboard links, and propagation of `ri`, `ct`, `lx`, and `tz`.

Frontend verification:

```text
bun run test -- spec/features/auth/dashboard/surface_dashboard.test.tsx
1 file, 8 tests passed
```

The Rails Core `/dashboard` route was not added or changed by this slice.
