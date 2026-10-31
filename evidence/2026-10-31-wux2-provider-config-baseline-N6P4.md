# Historical A02-15: provider callback source comparison

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had extensive uncommitted changes; this comparison includes the current worktree.

The D-34 baseline object `b6e7871073bdc43a55fc5f05e8476de8ee71252f` exists locally. `git diff b6e7871073bdc43a55fc5f05e8476de8ee71252f -- config/initializers/omniauth.rb lib/omniauth/strategies/umaxica_entra.rb app/services/external_authentication_entra_redirect_uri.rb` produced no diff. In these files the APP OmniAuth callback origin reads `PUBLIC_AUTH_SERVICE_URL`, while Entra uses the configured Auth staff origin and `/social/entra/callback`.

Current local authorization redirect tests are recorded in `evidence/2026-10-31-wux2-app-provider-callbacks-W6J4.md` and `evidence/2026-10-31-wux2-entra-authorize-callback-B9H3.md`. The D-34 baseline is not established here as the state before each historical realm unit; runtime environment values and deployed provider registrations may differ. Historical equivalence and complete A02-15 acceptance remain unverified. No provider connection was made.
