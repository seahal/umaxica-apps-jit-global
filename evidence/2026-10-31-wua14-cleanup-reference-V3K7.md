# R-AU-46 development cleanup-status references

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting this observation.
- A read-only `RAILS_ENV=development bin/rails runner` query first failed to boot because the required com Preference JWT issuer was missing from the invoked environment. The query was repeated with the issuer, audience and revoked-kid settings loaded from `.env.container.devcontainer`; the configured local development `ClientSignUpFlowCleanupStatus` IDs were `[0, 10, 20, 30, 40]`, matching `DEFAULTS`.
- No database records were modified. This snapshot does not prove database reset reproducibility, other reference tables, or end-to-end signup.
