# Intentional Dashboard Navigation

The dashboard is a human-facing entry point, not a route catalog or a QA sitemap. A dashboard link
must answer both of these questions:

1. Is the destination an implemented GET page that a person can inspect or use?
2. Is the destination not already reachable through an intentional domain hub?

The preferred navigation shape is:

```text
Dashboard -> domain hub -> child functionality
```

## Current surface hubs

The app dashboard links to its existing top-level account, organization, Avatar, switcher, and
Identity hubs, plus Preference, Billings, Groups, and the safe PWA offline page. The com and org
dashboards retain their existing top-level hubs and link to Preference and the safe PWA offline
page. Identity remains a dashboard-level hub where the surface exposes it; its human-facing child
pages are linked from the Identity index, not repeated on the dashboard.

Preference is the settings hub. Where the surface implements them, its index links to Calendar,
Clock, and Currency in addition to the existing Region, Timezone, Language, Motion, Density,
Pagination, Theme, Cookie, and customization/reset pages. Existing route helpers carry the supported
`ri`, `lx`, `ct`, and `tz` context; a navigation change must preserve that behavior.

The org Avatar show page exposes its existing edit page through a normal GET navigation action. This
is a navigation-only reachability link: it does not add Avatar lifecycle, ownership, RBAC, or create
behavior. The app Avatar create decision remains unchanged.

## Exclusions from normal navigation

The following are not dashboard or hub destinations:

- callback and OAuth/OIDC ceremony intermediates;
- POST/PATCH/PUT/DELETE-only mutations;
- machine, health, JSON-only, service-worker, `robots.txt`, and `sitemap.xml` endpoints;
- state-dependent remediation and step-up intermediates;
- session-limit or other screens that require a specific transient state;
- resource-specific routes without a selected resource;
- bearer-capability URLs, including tokenized promotional-email unsubscribe URLs.

The promotional unsubscribe flow uses a real bearer capability. Until the repository has an existing
safe preview mechanism that renders the page without minting or accepting a real token, the
dashboard must not embed a tokenized unsubscribe URL. QA should exercise the existing controlled
flow or a future development/test mailer preview; a dashboard link is not a reason to weaken the
production contract.

The PWA offline page is an exception because it is a safe human-facing GET page that is otherwise
normally reached only as a service-worker fallback. Link the page, never the service worker itself.

## Review rule

Before adding a dashboard link, trace the existing route, controller, authorization boundary, and
parent hub. If the parent hub can intentionally reach the page, improve that hub instead. After a
change, inspect the rendered props and route helpers for each surface and check that the dashboard
has not accumulated child links that duplicate Preference or Identity navigation.
