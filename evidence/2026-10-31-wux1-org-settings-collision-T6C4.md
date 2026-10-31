# ORG settings route collision

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained extensive uncommitted changes affecting this inspection.
- Ran `RAILS_ENV=test bin/rails routes -g 'auth_org_(configuration|settings)|base_org_(configuration|settings)'`. The current route table contains `base_org_configuration GET /configuration`, `auth_org_configuration GET /configuration`, and `auth_org_settings GET /settings`; Auth also has `GET /settings/entra` and its edit route.
- Source inspection shows `Auth::Org::ConfigurationsController#show` redirects `/configuration` to the Base authority, whereas `Auth::Org::SettingsController#show` authenticates an operator and redirects to Base identity. Therefore a mechanical rename of the Auth ORG configuration endpoint to `/settings` would collide with an existing, different endpoint and helper. No route or endpoint was changed in this check. The applicable reconciliation and client impact remain unresolved.
