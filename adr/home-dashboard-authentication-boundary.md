# Home and Dashboard Authentication Boundary

## Status

Accepted (2026-09-28). Supersedes `adr/base-warp-canonical-root-dashboard.md`.

## Decision

Base and Warp apply the same contract on their app, com, and org hosts:

| Session | `GET /` | `GET /dashboard` |
|---|---|---|
| Anonymous | 200 Home | 404 |
| Authenticated | 404 | 200 Dashboard |

No automatic redirect is performed between `/` and `/dashboard`, or from either page to sign-in. The routes remain registered. A rejected request raises `ActiveRecord::RecordNotFound` so the existing public exception renderer supplies the ordinary 404 representation. Dashboard actions retain their surface authorization checks. Both pages use the validated session state supplied by `logged_in?`.

The Home and Dashboard responses are private and not stored by shared caches. Public HTML 404 responses also carry `Cache-Control: private, no-store`, preventing an authenticated Home miss from poisoning anonymous Home.

Successful sign-in returns to `/dashboard`. Successful sign-out returns to `/`. Authenticated Preference, Switcher, Settings, and related return links target `/dashboard`.

## Consequences

Bookmarks and browser history that revisit a page outside its session state receive 404. The ordinary error representation does not disclose the subject or reason for refusal.
