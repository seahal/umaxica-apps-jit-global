# Subdomain Map

Subdomain labels are entry points. They are not Rails Engine boundaries.

## Current Public Surfaces

Local hosts are labelled `<service>.<surface>.localhost`. The `base.*` label carries the product,
staff, and corporate surfaces:

| Surface | Default local host   | Purpose                        |
| ------- | -------------------- | ------------------------------ |
| `app`   | `base.app.localhost` | End-user product surface       |
| `org`   | `base.org.localhost` | Staff and organization surface |
| `com`   | `base.com.localhost` | Public and corporate surface   |

The credential gateway uses the `auth.*` label for the app and org audience families. The
corporate (`com`) hosts are anonymous: they serve the public preference entry and public read-only
pages, so `auth.com.localhost` has no credential route.

| Audience | Default local host   |
| -------- | -------------------- |
| `app`    | `auth.app.localhost` |
| `org`    | `auth.org.localhost` |

The gateway also answers on `sign.*.localhost`, which is the boot-config default that applies when
`AUTH_*_URL` and `PUBLIC_AUTH_*_URL` are unset.

Development and network-only hosts may exist for operational endpoints, but they are not separate
Rails Engines.

## Canonical ENV Naming

URL environment variables should use the smallest boundary name that makes the ownership clear.

- `PUBLIC_*` means a browser-visible or externally reachable URL.
- `PRIVATE_*` means a Rails-internal, pod-internal, or service-internal URL.

Current runtime code still contains surface/service names for compatibility, but new docs and new
runtime config should prefer the public/private boundary language instead of inventing another
surface-prefixed URL family.

Examples of the older compatibility style that still exists in code:

- `ACME_SERVICE_URL`
- `ACME_STAFF_URL`
- `ACME_CORPORATE_URL`
- `ACME_DEVELOPER_URL`
- `ACME_NETWORK_URL`

Do not introduce engine-prefixed URL names such as `IDENTITY_SIGN_APP_URL`,
`FOUNDATION_BASE_ORG_URL`, or `DISTRIBUTOR_POST_APP_URL` for new runtime code in this repository.
