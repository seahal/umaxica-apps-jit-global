# Forbidden Rails Methods

This page lists Rails methods that must not be used anywhere in the application codebase.

These rules apply across the `app`, `org`, and `com` surfaces. Do not introduce local exceptions
inside controllers, models, services, concerns, jobs, mailers, views, or tests unless a current ADR
explicitly changes this policy.

## Controllers

### `ActionController::Parameters#permit!`

Do not use `permit!` on controller parameters, including `params.permit!`.

Reason:

- It marks all request parameters as permitted.
- It bypasses strong-parameter allowlisting.
- It can accidentally accept sensitive or unexpected user input when new fields are added.

Use explicit strong parameters instead:

```ruby
params.require(:user).permit(:email, :name)
```

For optional nested parameter roots, permit only the expected keys and keep the fallback empty:

```ruby
params[:user]&.permit(:email, :name) || ActionController::Parameters.new
```

### `skip_before_action`

Do not use `skip_before_action` to remove an authentication, authorization, verification, CSRF,
rate-limit, or sequencing guard.

Reason:

- It can bypass authentication, authorization, verification, CSRF, rate-limit, or sequencing
  protections.
- It changes the controller security pipeline in a way that is easy to miss during review.

If an endpoint needs different protection, place it under the correct public or private controller
boundary and use the established lifecycle for that surface.

Enforced boundary (the only sanctioned exceptions):

- `AuthenticationBase` overrides `skip_before_action` / `skip_action_callback` to **hard-block**
  skipping `:enforce_access_policy!` (raises `SkipNotAllowedError`). The authorization gate can
  never be skipped.
- Skipping `:enforce_verification_if_required`, `:enforce_step_up_prereqs!`, or
  `:authenticate_client!` is permitted only for controllers in the reviewed
  `SENSITIVE_SKIP_ALLOWLIST`, mechanically enforced by
  `test/unit/security/forbidden_rails_patterns_test.rb`. A new file that skips one of these fails
  that test until the boundary change is deliberately reviewed.
- Skipping `:set_region` is permitted only for controllers listed in `RI_SKIP_ALLOWLIST`,
  mechanically enforced by `test/unit/security/ri_routing_contract_test.rb`. The list is compared by
  equality, so both a new skip and a silently removed one fail that test. Every entry must be a
  machine-to-machine endpoint that renders no regional HTML: skipping the callback on a controller
  that renders HTML strips `ri` from every URL that controller generates, because
  `PreferenceGlobal#default_url_options` reads the request params only and has no fallback. That is
  the auth sign-in/sign-up regression recorded in
  `plans/analysis/ri-preference-routing-regression-audit.md`.
- Skipping the remaining non-security context/preference callbacks (for example
  `:set_preferences_cookie`, `:set_color_theme`) is allowed where an endpoint legitimately does not
  participate in that context, and is not a security relaxation.

See `.agents/harnesses/rules/project/regression-guards.mdc` for the same enforced-regression-guard
summary.

### `skip_authorization`

Do not use `skip_authorization`.

Reason:

- It bypasses the Action Policy authorization pipeline.
- It can leave controller actions without an explicit policy decision.

Use the established authorization flow for the surface and policy involved.

### `skip_forgery_protection`

Do not use `skip_forgery_protection`.

Reason:

- It disables CSRF protection.
- It can expose browser-backed endpoints to request forgery.

Use the correct API, JSON, or browser controller boundary instead of disabling protection locally.

## Models

### `belongs_to optional: true` And `required: false`

Do not use `optional: true` or `required: false` on `belongs_to` associations.

Reason:

- It allows Rails validations to pass even when the associated record is absent.
- It can hide a missing required relationship until a database constraint fails, or worse, until
  data with a missing relationship is persisted.
- It weakens the model-layer contract and makes association requirements harder to review.

Model the relationship as required in Rails. If a foreign key is genuinely nullable, handle that
through explicit domain validation or a separate association shape instead of disabling `belongs_to`
presence validation locally.

### `default_scope`

Do not use `default_scope`.

Reason:

- It hides query behavior behind model loading.
- It can change association, validation, authorization, and background-job behavior in surprising
  ways.
- It is easy to forget in security-sensitive reads where explicit filtering matters.

Use named scopes or explicit query methods instead:

```ruby
scope :active, -> { where(active: true) }
```

### `enum`

Do not use Rails `enum`.

Reason:

- It couples persisted values to generated model methods and query helpers.
- It can make authorization, state transitions, and database migrations harder to review.
- It can hide important domain states behind implicit integer or string mappings.

Use explicit constants, validations, and domain methods instead:

```ruby
STATUSES = %w[pending active suspended].freeze

validates :status, inclusion: { in: STATUSES }
```

## Database And Migrations

### `drop_table`

Do not use `drop_table` unless the user has explicitly approved the risk and migration plan.

Reason:

- It is destructive.
- It can permanently remove production data.
- It usually needs a staged, reversible migration plan.

### `remove_column`

Do not use `remove_column` unless the user has explicitly approved the risk and migration plan.

Reason:

- It is destructive.
- It can break older application versions during deployment.
- It can remove data before rollback safety is confirmed.

### `change_column`

Do not use `change_column` unless the user has explicitly approved the risk and migration plan.

Reason:

- It can be difficult or impossible to reverse safely.
- It can lock large tables or rewrite data.
- It can break compatibility across rolling deploys.

### `delete_all`

Do not use `delete_all` unless the user has explicitly approved the risk and migration plan.

Reason:

- It deletes data without callbacks.
- It can bypass domain cleanup, auditing, and authorization expectations.

### `destroy_all`

Do not use `destroy_all` unless the user has explicitly approved the risk and migration plan.

Reason:

- It can delete large amounts of data.
- It can trigger callbacks with production side effects.
- It can be unsafe inside migrations or broad service changes.

### `update_all`

Do not use `update_all` unless the user has explicitly approved the risk and migration plan.

Reason:

- It bypasses validations and callbacks.
- It can silently update large data sets.
- It can skip audit or domain invariants.

### ADR-sanctioned data-retention exceptions

The retention/purge pipeline is the standing, accepted exception to the `delete_all` / `update_all`
rules above, per `adr/retainable-concern-and-retention-purge.md` (Accepted). Set-based `delete_all`
is intentional there: it issues a real connection-local SQL `DELETE` that skips per-row callbacks
and cross-database `dependent:` traversal, which is exactly the property the cross-database child
purge needs.

Sanctioned call sites (do not "fix" these into row-by-row `destroy`):

- `app/jobs/retention_purge_job.rb`, `app/jobs/dpop_proof_state_purge_job.rb`
- `app/services/retention_cross_database_child_purge.rb`
- `app/services/identity_*_ceremony_transaction_purger.rb`
- discard/expiry sweeps such as `acme_refresh_token_service.rb` (`update_all(discarded_at:)`)

New destructive-op call sites still require explicit approval and should reference an Accepted ADR.

### `execute(...)`

Do not use raw SQL through `execute(...)` unless the user has explicitly approved the risk and
migration plan.

Reason:

- It can bypass adapter safety, quoting, and migration reversibility.
- It can hide destructive database behavior from review.

Prefer reversible Rails migration helpers, explicit scopes, and small service-layer data changes
when practical.

## Rendering And Transport Security

### `html_safe`

Do not use `html_safe`.

Reason:

- It disables Rails HTML escaping.
- It can introduce XSS when applied to user-controlled or indirectly user-controlled content.

Use Rails escaping, sanitizers, or safe view helpers that preserve escaping by default.

### `raw(...)`

Do not use `raw(...)`.

Reason:

- It renders unescaped HTML.
- It can introduce XSS when content provenance changes.

Use escaped output or a reviewed sanitizer boundary instead.

### `VERIFY_NONE`

Do not use `VERIFY_NONE`.

Reason:

- It disables TLS certificate verification.
- It can expose outbound requests to interception.

Use verified TLS and configure trusted certificates explicitly when required.

## User-Facing Feedback

### `flash` and `redirect_to(..., notice:/alert:)`

Do not use Rails `flash` in any form: `flash[...]`, `flash.now[...]`, `flash.keep`, `flash.discard`,
`flash.notice`, `flash.alert`, or the `redirect_to(..., notice:)` / `redirect_to(..., alert:)`
shortcuts that write to it.

Reason:

- Toast-style transient banners are easy to miss, cannot be re-read, and tie user-visible feedback
  to session state.
- Flash messages have been removed from this application.

Render feedback inline in the page instead: pass error messages through an instance variable (for
example `@form_error`) and show them in the re-rendered view, and let destination pages express
success directly. See `.agents/harnesses/rules/generic/no-flash-messages.mdc`. Any future
session-backed notice state requires an explicit ADR, consistent with
`adr/logout-completion-boundary.md`.

## Review Rule

When reviewing code, treat any new use of the methods on this page as a blocking issue. Replace the
method with an explicit, locally reviewable implementation before merging.
