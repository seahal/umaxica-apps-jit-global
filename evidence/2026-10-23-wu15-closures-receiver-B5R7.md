# WU-15 (receiver part): `POST /oidc/closures`

- Date: 2026-10-23. Base commit `6e4d70d0b0799a4ef9bd9fc4cea2c21d4b3eca72`; change uncommitted.
- Decisions: D-31, D-32 (signature-only trust), D-118. The sender part waits for WU-16.

## Change

- All 12 RPs: `resources :closures, only: :create` replaces `resource :backchannel_logout`
  (`/oidc/backchannel-logout`), no compatibility route; controllers renamed to
  `<Surface>::Oidc::ClosuresController`, still `< ActionController::API` (D-118).
- Each receiver adds an explicit IP rate limit (60/min, the rate-limit store) and answers only on the
  RP's registered host (otherwise 404); `Cache-Control: no-store` and the 200/400/503 classes stay.
- `OidcClientStoresStaticClientStore::RP_BACKCHANNEL_LOGOUT_PATH = "/oidc/closures"`, so every
  registered `backchannel_logout_uri` and the OP's participant targets move with it.
- Runtime-role route ownership and test references updated.

## Verification

- `test/integration/oidc_closures_receiver_gating_test.rb` (new): old path not routable; a request
  without a browser User-Agent or cookies reaches the token check (400, `no-store`) (A15-4 part).
- BCL receiver end to end, route guards, ownership, no-store and CSRF route coverage, discovery,
  client registry, logout committer, `test/security`, `test/unit/security`: 830 runs, 0 failures after
  the reference updates.
- Not run: A15-1 … A15-3, A15-6 … A15-11 (sender, WU-16), rate-limit boundary.
