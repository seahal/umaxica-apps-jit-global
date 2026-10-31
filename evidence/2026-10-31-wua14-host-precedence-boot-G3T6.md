# Development host precedence at boot

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had extensive uncommitted changes, including `lib/config_values_host_family_values.rb` and the devcontainer environment; the observations describe that worktree.

Two local development `bin/rails runner` processes printed only selected configured host names after boot. With the current shell and the required COM Preference JWT settings exported, the observed values were `acme_service=base.app.localhost`, `base_service=www.umaxica.app`, `palm_service=palm-jp.umaxica.app`. With the same invocation and `BASE_SERVICE_URL=base.app.localhost` supplied for that process, the observed values were `acme_service=base.app.localhost`, `base_service=base.app.localhost`, `palm_service=palm-jp.umaxica.app`.

Thus setting the missing ACME key also changes the Base service origin in this local boot; preserving the previous ACME value alone is insufficient to preserve Base routing. The devcontainer file was not loaded wholesale by these commands, and these observations do not establish its deployed values. No environment or implementation changes were made.
