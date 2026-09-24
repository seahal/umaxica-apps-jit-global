# Regional RP identity audit

- Date: 2026-09-22
- HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`
- Worktree: pre-existing changes were preserved; no source, credential, deployment, or external
  service change was made.

## Current evidence

The current static registry defines seven surface-level first-party browser clients:

```text
core-app, core-com, core-org,
side-app, side-com, side-org,
edit-org
```

`OidcClientStoresStaticClientStore` derives their redirect, post-logout, and backchannel URI
sets from one configured host per surface. `AuthBoundaryAuthorityMap` independently lists the
same seven IDs. No JP/US-specific client IDs, independently configured regional redirect URI sets,
or regional private-key bindings exist in the current registry.

The compatibility client `core-next-rp` remains a live local registry/model boundary and is
currently mapped to the same `CORE_APP` JWT namespace as `core-app`. This is evidence that a
regional-ID change cannot be reduced to renaming registry entries: the independent key binding and
the retirement/migration order for the compatibility client must be decided together. No key
namespace or client mapping was changed during this audit.

The accepted seven-RP ADR explicitly records the JP/US registration conflict as unresolved. The
repository has `ri` request-context handling, but that is not equivalent to an independently bound
OAuth client identity or key. The `core-next-rp` bridge also remains referenced by production model
concerns, so it cannot be removed as a local cleanup.

## Security disposition

This is a Critical architecture/deployment gate, not a safe local refactor. Adding guessed regional
IDs, redirect hosts, key names, or credential material would create a client-registration and
issuer/audience mismatch risk. External registration and key deployment are outside this task's
authority and must not be changed from the repository.

Required next decision/evidence before implementation:

1. approve the regional client-ID and host matrix, including the genuinely global `edit-org` rule;
2. provide the independently bound key/credential mapping for each regional RP;
3. reconcile deployed callers, existing sessions, and the `core-next-rp` migration order;
4. verify Base registry, callback, post-logout, backchannel, audience, and RP-session bindings
   together.

No local regional client was invented, and the seven-client implementation is not reported as
regional-RP complete.
