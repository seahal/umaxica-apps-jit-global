# Rails Way Technical Debt Repayment Plan

**Status:** Archived (2026-05-12) — Old premise notes for research only. This is not in line with
the current implementation policy, so it is placed in the archive instead of the backlog.

## background

Six perspectives were raised simultaneously by developers:

1. The routing of CSP violation report is
   `post "/csp-violation-report", to: "/csp_violations#create"` It is duplicated on each surface in
   the form of , which violates Rails' RESTful CRUD convention.
2. There is a `occurred_at` column in Chronicle series tables / `JwtAnomalyEvent` etc., but the
   Rails standard Since it has the same meaning as `created_at`, I would like to use the standard
   timestamp.
3. The class base service object of `app/services/**` is `class` `module` according to the Rails Way
   for stateless ones. I want to change the settings and reconfigure them to the correct location.
4. The existing ERB lacks the WAI-ARIA attributes, and there are many meaningless `<div>` nests.
5. Maintenance of `roots#index` pages for `dev`(`*.dev.localhost`) and `net`(`*.net.localhost`)
   surfaces.
6. Rails' i18n key has been destroyed, and en and ja are not 1:1 compatible. inline to `t()` The
   `default:` literal specification also remains. There is a high possibility that a large number of
   unused keys are lost.

This plan treats the six themes as one repository organization campaign, but each theme will be
pursued independently. The AI ​​in charge of implementation will be responsible for PR on a
theme-by-theme basis.

## Related ADR / Plan

- `adr/three-tier-controller-base.md` — `ApplicationController` / `OpenController` / Three-layer
  base of `PublicController`
- `adr/public-controller-base.md` — public endpoint base for machines
- `adr/csp-and-permissions-policy.md` — CSP Overall policy
- `adr/chronicle-audit-db-consolidation.md` — chronicle system integration and audit contract
- `adr/rails-way-engine-architecture-restoration.md` — Return to the Rails Way
- `plans/backlog/gh645-csp-violation-reporting.md` — Existing CSP report plan (overwritten by this
  plan)
- `plans/backlog/gh231-configure-csp.md` — CSP setting body
- `plans/active/gh789-publish-at-column-rename.md` — Same pattern as renaming another column

---

## 1. Surface independence of CSP violation report (URL remains unchanged)

### Design constraints (determined after discussion)

- **URL remains `/csp-violation-report`** Do not change every word.
  - CSP `report-uri` The value of the directive is cached on the browser side with the length of the
    policy TTL, and the already distributed policy continues to be sent to the old URL until it
    expires. If you change URL on the server side, there will always be a period where reports are
    missed.
  - Also, `/csp-violation-report` (hyphen separated) is CSP Level 2/3 of `report-uri` This is the
    idiomatic form of endpoint, and this repository treats this spelling as "foreign contract."
- **The 13 individual route declarations are also left intact**. Surface × Explicitly writing each
  TLD is consistent with the "surface independence" principle of AGENTS.md, and more is lost by
  organizing.

Therefore, the scope of this task is **Do not reduce the number of routes or URL**. The scope is
“Controller implementation Rails limited to ``Wayization.''

### current situation

- Route definition: `config/routes/acme.rb:15,60,109,157,165`,
  `config/routes/sign.rb:16,185,312,461,473`, All to `config/routes/jump.rb:11,21,31`
  `post "/csp-violation-report", to: "/csp_violations#create"` is described individually (= 13
  locations).
- Controller: `app/controllers/csp_violations_controller.rb` (`ApplicationController` (directly
  below, top level with no namespace).
- Common logic: `app/controllers/concerns/csp_violation_report.rb` (`record_csp_violation!`).
- "URL of existing plan `plans/backlog/gh645-csp-violation-reporting.md` is `/csp-violation-report`
  This plan **inherits** the policy of ``maintaining the same as it is''.

### Problem (= leftover cleanup target)

1. Controller reference `to: "/csp_violations#create"` is written with a leading slash to pass
   through the acme/sign/jump scope. You can turn off this special dispatch by simply placing a
   controller inside each surface.
2. `app/controllers/csp_violations_controller.rb` does not live on any surface and is a top-level
   Inherits from `ApplicationController`. This is based on the “surface independence” principle of
   AGENTS.md and the ADR `three-tier-controller-base.md` (public endpoint is `PublicController`
   (inherited from).
3. The `ACME_NETWORK_URL` / `ACME_DEVELOPER_URL` constraints of `acme.rb:152-170` are
   `constraints host: ENV["ACME_STAFF_URL"]` It is nested within the block, and the host cannot
   reach it unless it matches both STAFF and DEV/NET at the same time (currently the route is almost
   dead). This will be fixed in Task 5, so it is excluded from this task.

### decision

- **Do not change URL**. Leave as `POST /csp-violation-report`.
- Each root line is **relative without leading slash** and dispatch to the controller inside the
  surface. Rails to keep hyphen separated URL Using the `path:` option of `resource` DSL:

  ```ruby
  # In each TLD block (common to acme/sign/jump)
  resource :csp_violation_report, only: :create, path: "csp-violation-report"
  ```

  Now:
  - URL: `POST /csp-violation-report` (word-for-word unchanged)
  - Controller: `Acme::Com::CspViolationReportsController` etc. by scope resolution
  - Path helper: `acme_com_csp_violation_report_path` (generated)
  - Write in one line and use Rails CRUD convention (`#create`)

  Legacy `post "/csp-violation-report", to: "/csp_violations#create"` may maintain its shape. The
  three important points are `URL unchanged'', `elimination of the leading slash'', and ``landing on
  the controller inside the surface'', and the selection of DSL is left to the implementation AI.

- Consolidate the controllers into **one unit at a time per surface (= boundary unit)** and use ADR
  `public-controller-base.md` / `three-tier-controller-base.md` and the "shallow nesting first"
  principle (`PublicController` design time decision: Instead of using 11 per-TLD bases, we used 3
  boundary bases):
  - `Acme::CspViolationReportsController < Acme::PublicController`
  - `Sign::CspViolationReportsController < Sign::PublicController`
  - `Jump::CspViolationReportsController < Jump::PublicController`

  The routing side references the same controller in each TLD scope. Rails scope resolution is I go
  to search for the controller in the **last namespace that overlaps `scope module:`**, but I can't
  specify the controller. Either move the scope back one step and call it like
  `controller: "/acme/csp_violation_reports"`, or
  `resource :csp_violation_report, only: :create, path: "csp-violation-report", module: nil` Use the
  syntax to remove TLD from the namespace, like:

  ```ruby
  # Example: In acme.rb, in each TLD block (com/app/org/dev/net)
  resource :csp_violation_report, only: :create, path: "csp-violation-report",
           controller: "/acme/csp_violation_reports"
  ```

  > **Alternatives (can be determined by the implementation AI)**: ADR `public-controller-base.md`,
  > `HealthController`, etc. If written as **per-TLD**, `Acme::Com::Csp...` to match the current
  > design. You can also align them with per-TLD like this. However, rather than increasing the
  > number of new nests, priority should be given to aligning them to the shallower existing ones.
  > Before implementation `app/controllers/acme/{com,app,org}/health_controller.rb` Check the
  > structure of and keep it consistent whether it is per-boundary or per-TLD.

- Common normalization logic is `app/controllers/concerns/csp_violation_report.rb` , and `include`
  from the new controller group (current concerns will be reused as is).
- Delete the old `app/controllers/csp_violations_controller.rb`.

### Output directory structure (example after implementation — per-boundary proposal)

```
app/controllers/
├── acme/
│   └── csp_violation_reports_controller.rb     (Acme::CspViolationReportsController)
├── sign/
│   └── csp_violation_reports_controller.rb     (Sign::CspViolationReportsController)
└── jump/
    └── csp_violation_reports_controller.rb     (Jump::CspViolationReportsController)
app/controllers/concerns/
└── csp_violation_report.rb (maintain status quo)
config/routes/
├── acme.rb (resource :csp_violation_report for each TLD ...
│                                                 controller: "/acme/csp_violation_reports")
├── sign.rb (same as above)
└── jump.rb (same as above)
```

Total of 3 files (per-boundary). 13 files (current Align to the structure of
`health_controller.rb`).

### Implementation steps

1. Create a new controller, one for each surface (`Acme::CspViolationReportsController`,
   `Sign::CspViolationReportsController`, `Jump::CspViolationReportsController`). correspond to each
   Inherit `<Boundary>::PublicController`, include `CspViolationReport`, and `create` Call
   `record_csp_violation!` and return `head :no_content`.
2. `config/routes/{acme,sign,jump}.rb` `post "/csp-violation-report", to: "/csp_violations#create"`
   in each TLD scope (all 13 locations):

   ```ruby
   resource :csp_violation_report, only: :create, path: "csp-violation-report",
            controller: "/<boundary>/csp_violation_reports"
   ```

3. Delete old `app/controllers/csp_violations_controller.rb`.
4. Test: For per-boundary proposals
   `test/controllers/{acme,sign,jump}/csp_violation_reports_controller_test.rb` Create 3 new files
   to cover 204 returned when executing POST on each TLD host. existing Migrate and integrate
   `test/controllers/csp_violations_controller_test.rb`.
5. `report_uri` values ​​for `config/initializers/content_security_policy.rb` **do not change** (URL
   remains unchanged).
6. `bin/rails routes | grep csp-violation-report` remains at 13 lines and each line is a
   per-boundary controller (e.g. `acme/csp_violation_reports#create`).

### Acceptance conditions

- URL in the output of `bin/rails routes | grep csp-violation-report` **all
  `/csp-violation-report`** As is (not a single word has changed).
- Similarly, in the output, the controller for each row is inside the surface (for per-boundary
  plans, `acme/csp_violation_reports`, per-TLD Alternatives `acme/com/csp_violation_reports`).
  `/csp_violations` with leading slash No inscription remains.
- The old top level `CspViolationsController` has been deleted.
- Existing browsers (those caching the old CSP policy) 204 is still returned (for each combination
  of acme/sign/jump × com/app/org/dev/net).
- Event firing of `Rails.event.record("security.csp_violation", ...)` continues to work.

---

## 2. Unify `occurred_at` to Rails standard `created_at`

### current situation

- `*_chronicles`, `*_audits`, `*_histories` in `db/chronicle_schema.rb` `occurred_at` exists in many
  tables (approximately 30 locations), and `t.timestamps` also exists separately. I have it double
  with `created_at`.
- The same goes for `jwt_anomaly_events.occurred_at` of `db/occurrence_schema.rb:304`.
- `attribute :occurred_at, default: -> { Time.current }` of `app/models/concerns/behavior.rb:13`
  generates app-side defaults.
- In `alias_attribute :timestamp, :occurred_at` of `app/models/{user,staff}_chronicle.rb` Provides
  `timestamp` API.
- The part where `occurred_at: Time.current` is passed in the audit write part is `app/services/**`,
  `app/controllers/concerns/**`, `app/controllers/sign/**` There are many locations (approximately
  25 locations, available at `grep -rn "occurred_at: Time.current"`).
- The display side is `app/controllers/sign/{app,com,org}/settings/activities_controller.rb`.
  `COALESCE(occurred_at, created_at) DESC` and `activity.occurred_at || activity.created_at` This is
  a patchwork implementation of ``Records without occurrence_at fall back to created_at'' (= already
  For operational purposes, it is assumed that `occurred_at` semantically matches created_at).

### problem

- `occurred_at` and `created_at` have duplicate meanings and write codes are redundant.
- The index is also `(occurred_at)` and `(actor_id, occurred_at)` There are many
  `(subject_type, subject_id, occurred_at)`, but `created_at` If you unify it, you can operate it
  with Rails standard knowledge.
- The display logic that uses COALESCE is a liability itself, and it disappears if `created_at` is
  used alone.

### decision

- `occurred_at`, which is used for simple "audit record generation time", should be standardized to
  `created_at`.
- However, `JwtAnomalyEvent` has **detection time (created_at)** and **event occurrence time
  (occurred_at)** may be logically different (anomaly may be added after batch), so this table is
  left as an exception. Exceptions will be clearly indicated in the docstring of the model and this
  plan.
- Candidate exception: `JwtAnomalyEvent` only. All `*Chronicle`, `*Audit`, `*History`, `*Behavior`
  series Contributed to `created_at`.

### Implementation steps (Phase configuration)

#### Phase 1: Leave the writing side to `created_at`

1. All `audit/chronicle/...create!(occurred_at: Time.current, ...)` to `occurred_at` Rewrite by
   removing the argument (Rails automatically assigns `created_at`). subject:
   `app/services/{user,staff}_secrets/*.rb`, `app/services/auth/audit_writer.rb`,
   `app/services/social_auth_service.rb`,
   `app/controllers/concerns/sign/ verification_audit_and_cookie.rb`,
   `app/controllers/concerns/authorization_audit.rb`,
   `app/controllers/concerns/authentication/customer.rb`,
   `app/controllers/concerns/ preference/base.rb`,
   `app/controllers/sign/{com,app}/settings/{telephones,emails}_ controller.rb`,
   `app/controllers/sign/app/in/secrets_controller.rb`.
2. `app/lib/sign/risk/event.rb` and `app/lib/sign/risk/emitter.rb` of `occurred_at` Leave the name
   as the field name of the domain event (CloudEvents style). This is not a DB column.
3. `attribute :occurred_at, default: -> { Time.current }` of `app/models/concerns/behavior.rb`
   Delete.
4. `alias_attribute :timestamp, :occurred_at` of `app/models/{user,staff}_chronicle.rb` Rewrite it
   to refer to `:created_at` (or delete it and align all locations with `created_at`).
5. activities_controller `Arel.sql("COALESCE(occurred_at, created_at) DESC")` Replace
   `created_at: :desc` and `activity_occurred_at` helper with `activity.created_at` Reduce it to one
   line.
6. Test fixture (`test/fixtures/scavenger_*_chronicles.yml`) `occurred_at:` to `created_at:`
   Rewritten to .
7. Confirm that the test set turns green.

#### Phase 2: Schema migration (migration of each chronicle DB)

Each DB (`chronicle`, `occurrence` Create a separate migration file for each data source (except for
Since there are a large number of tables, we will go through the dual write period first.

1. `(actor_id, created_at)`, `(subject_type, subject_id, created_at)`, `(created_at)` **Add** the
   index for `created_at` (`add_index ... if_not_exists: true`).
2. Delete the `occurred_at` column and drop the `(occurred_at)` series index. Exception:
   `JwtAnomalyEvent` is not applicable.
3. Be sure to describe the rollback procedure (using `change_table`, destructive operation, set an
   operation flag for user approval according to the terms of AGENTS.md).

#### Phase 3: Follow model / docstring / ADR

1. Schema of `app/models/*chronicle*.rb` Information Regenerate comment
   (`bundle exec annotaterb models`).
2. Added the section "Timestamps are unified to `created_at`" to
   `adr/chronicle-audit-db-consolidation.md`.
3. `app/models/jwt_anomaly_event.rb` the basis for leaving `occurred_at` of `JwtAnomalyEvent`
   Specify the comment on one line (= to leave the difference between the observation time and the
   occurrence time).

### Acceptance conditions

- The output of `grep -rn "occurred_at" app/ test/ db/` is `JwtAnomalyEvent` Only associations
  (Schema comments, model attributes, test fixtures).
- The chronicle list screen is sorted by `created_at` alone and the display does not change.
- Rollback of existing migration (`bin/rails db:rollback`) is successful.

---

## 3. Service layer refactors for the Rails Way

### current situation

- There are about 20 classes under `app/services/`, breakdown:
  - `ApplicationService` (Single responsibility contract for `call` class methods).
  - By domain such as `auth/`, `dbsc/`, `dpop/`, `oidc/`, `staff_secrets/`, `user_secrets/`.
  - `social_auth_service.rb`, `taxonomy_builder.rb`, `identifier_blind_index.rb`, `cache_aside.rb`,
    `auth_method_guard.rb`, `analytics_consent_guard.rb`, `aws_sms_service.rb` One-off classes such
    as.
- Some of them actually have no state and just bundle pure procedures, and in Ruby terms module +
  module_function is sufficient.
- `app/lib/` includes `core/`, `auth/`, `sign/risk/`, `common/` already exists and is used as a
  repository for purely functional utilities (`app/lib/core/surface.rb` etc.).

### problem

- The name "Service" cannot be used differently depending on whether there is a state or not, and it
  is standardized.
- Example: A pure constant/function class like `Auth::CookieName` should be in
  `app/lib/auth/cookie_name.rb` (actually `app/lib/auth/authorization_header.rb` is already the
  case).
- Example: `UserSecrets::Create` etc. are side effects + Since it performs DB transactions + audit
  writes, it is appropriate as a service (this category is not touched).
- There are mixed classes that do not force inheritance of `ApplicationService` (`AwsSmsService`,
  `SocialAuthService` etc.).

### Decision (Details will be determined by the AI ​​in charge of implementation, this plan is only in principle)

- Judgment axis for classification:
  1. **With side effects + DB write + transaction control** → `class` of `app/services/` , and
     inherits `ApplicationService`. The naming is `<Domain>::<Verb>` (e.g. `UserSecrets::Create`).
  2. **Pure function + constant + format conversion** → `module` + internal method of
     `app/lib/<domain>/<noun>.rb`. Externally published with `module_function` or `class << self`.
  3. **Settings object/value object** → Value Object of `app/lib/core/<concept>.rb` (`Data.define`
     recommended).
- `app/services/` should be **only used for services with side effects**, and pure functions should
  be moved to `app/lib/`.
- Services that do not inherit `ApplicationService` should be inherited, or if they are pure
  functions, move them to `app/lib/`.

### Migration candidate list (individually evaluated by implementation AI)

| File                                     | Current location | Recommendation                               | Reason                   |
| ---------------------------------------- | ---------------- | -------------------------------------------- | ------------------------ |
| `app/services/auth/cookie_name.rb`       | services         | `app/lib/auth/cookie_name.rb` (module)       | Pure function assumption |
| `app/services/auth/token_claims.rb`      | services         | `app/lib/auth/token_claims.rb` (Data)        | Value object assumption  |
| `app/services/dbsc/header_parser.rb`     | services         | `app/lib/dbsc/header_parser.rb` (module)     | Parse only               |
| `app/services/dpop/header_parser` series | services         | `app/lib/dpop/` and below (module)           | Same as above            |
| `app/services/preference/cookie_name.rb` | services         | `app/lib/preference/cookie_name.rb`          | Same as above            |
| `app/services/identifier_blind_index.rb` | services         | `app/lib/identifier_blind_index.rb` (module) | crypto pure function     |
| `app/services/cache_aside.rb`            | services         | `app/lib/cache_aside.rb` (module)            | Cache Read-through       |
| `app/services/aws_sms_service.rb`        | services         | Remain as services (with side effects)       | Call SDK                 |
| `app/services/social_auth_service.rb`    | services         | Remain as services (DB + audit write)        | Side effects             |
| `app/services/staff_secrets/*`           | services         | services remains                             | DB written               |
| `app/services/user_secrets/*`            | services         | services remains                             | DB written               |
| `app/services/auth/audit_writer.rb`      | services         | Leave as services                            | DB write                 |
| `app/services/auth/session_revoker.rb`   | services         | Leave as services                            | DB write                 |

> **Note:** The above "recommendations" are for external evaluation only. The implementation AI
> actually reads the code and understands the internal state/ Make a final decision after checking
> the DB access/transaction boundaries/test format. If it is a reasonable judgment, a conclusion
> that differs from the recommendation is acceptable.

### Implementation steps

- 1 PR = 1 domain (e.g. "Move pure auth functions to lib", "Move pure dbsc functions to lib").
- Leave it to Zeitwerk autoload instead of `require_relative`.
- Keep `# frozen_string_literal: true` and `# typed: false` on the moved side.
- Fixed references for callers (`app/controllers/**`, `app/models/**`, `test/**`).

### Acceptance conditions

- All top-level classes under `app/services/` are `ApplicationService` inherit or are listed in the
  "remain services" list for this plan.
- `bin/rails test` is all green.
- The newly added module under `app/lib/` is written as `module` instead of `class`.

---

## 4. Compatibility of ERB with WAI-ARIA and tag organization

### current situation

- 256 ERB files under `app/views/`. `grep -l "aria-\|role=\""` Only 21 files (about 8%) have the
  ARIA attribute.
- Example: `app/views/sign/app/in/emails/new.html.erb` is nested 4 times with `<div>` and empty
  `<div>` (line 38) and there is no `role="alert"` in the form error area.
- Example: `app/views/sign/app/settingss/show.html.erb` is structurally valid (`<section>` +
  `<h2>` + `<ul>`) However, `<section>` does not have `aria-labelledby`.
- Example: `app/views/sign/app/in/sessions/show.html.erb` (line 105) has a correct list structure,
  but the only representation of "current session" is a visual flag (`<span>(current)</span>`),
  which is suitable for screen readers. `aria-current="true"` is missing.
- As for the layout `<header><nav>...</nav></header><main>...</main><footer><nav>...</nav></footer>`
  and certain semantics are maintained (`app/views/layouts/sign/app/application.html.erb`).
- On the other hand, `app/views/layouts/application.html.erb` (for Inertia demo) is
  `<title>Inertia Rails Example</title>` If there is a possibility that it will be used in the
  production route, it will be organized (although it may be outside the scope of this plan,
  `config/routes.rb:13` FIXME).

### problem

- Form validation errors do not have `role="alert"` or `aria-live`, so they are not read out in AT.
- `aria-describedby`/`aria-invalid` has not been assigned, and form field error handling is not
  connected by ID etc.
- Meaningless nesting of `<div>` exists.
- There are cases where `<style>` is placed inline in the view (`emails/new.html.erb:59-75`) and CSP
  This needs to be sorted out as it conflicts with the nonce allowance.

### decision

- ARIA support is divided into three levels:
  - **Level A (required):** `role="alert"` in form error area, input field Connect the error message
    ID with `aria-invalid="true"` + `aria-describedby`. `aria-busy` on the button Add (sending). Add
    `aria-labelledby` to `<section>`.
  - **Level B (Structure):** `<nav>` to `aria-label`, `<div>` with list nature to `<ul>/<li>` To. It
    will be supported when a UI like breadcrumbs/tabs appears (currently it is on hold as it is
    almost unused).
  - **Level C (Advanced):** Toast notification with live region (`aria-live="polite"`), Navigation
    grant for `aria-current="page"`.
- Unnecessary To flatten `<div>`, follow the principle of "narrowing the change scope" of AGENTS.md
  and put Level A. **Can be touched only within the same PR** Don't touch anything else.
- `<style>` inline is Level A Export to CSS file (`app/assets/stylesheets/sign/...`) when
  supporting.

### Compatible targets (in order of priority)

1. Login/signup system (high frequency): `app/views/sign/{app,com,org}/in/**`,
   `app/views/sign/{app,com,org}/up/**`, `app/views/sign/{app,com,org}/ins/new.html.erb`.
2. Setting system (medium frequency): `app/views/sign/{app,com,org}/settings/**`.
3. Preferences: `app/views/sign/{app,com,org}/preference/**`.
4. Root view: `app/views/sign/{app,com,org}/roots/**`, `app/views/acme/{app,com,org}/roots/**`,
   `app/views/sign/{dev,net}/roots/**` (integrated with task 5).

### ERB helper (new)

- Create a new `app/helpers/aria_helper.rb` to provide one helper for merging form errors:

```ruby
module AriaHelper
  # Example: aria_invalid_attrs(@user_email, :address) ⇒
  #   { "aria-invalid": "true", "aria-describedby": "user_email_address_errors" }
  def aria_invalid_attrs(model, attr)
    return {} unless model && model.errors[attr].any?

    { "aria-invalid": "true", "aria-describedby": "#{model.model_name.param_key}_#{attr}_errors" }
  end
end
```

> **Note:** The final helper API is left to the AI ​​in charge of implementation. You can decide
> whether you want to make it common or not. This plan only contracts for the outcome that ``aria-\*
> will be added in the event of an error in form input.''

### Acceptance conditions

- `role="alert"` in the error area in all forms for target 1 (login/signup type) will be granted.
- In case of error, `aria-invalid="true"` and `aria-describedby` are added to the input field.
- Form submit button communicates busy status to AT via `aria-busy` or `data-turbo-submits-with`.
- Unnecessary `<div>` The display does not change even if you delete the nest (including the empty
  `<div>`).
- Do not write `<style>` directly to ERB.

---

## 5. `roots#index` maintenance of `dev` / `net` surface

### current situation

- `sign` on surfaces `Sign::Dev::RootsController` / `Sign::Net::RootsController` and view
  (`app/views/sign/{dev,net}/roots/index.html.erb`) **already exists** is only a placeholder
  (`<h1>Sign::Dev::Roots#index</h1>`).
- For the `acme` surface:
  - `app/controllers/acme/{dev,net}/roots_controller.rb` **does not exist**.
  - `app/views/acme/{dev,net}/roots/` **does not exist**.
  - `ACME_NETWORK_URL` / `ACME_DEVELOPER_URL` constraints of `config/routes/acme.rb:152-170`
    **Nested** in `constraints host: ENV["ACME_STAFF_URL"]` Written (bug). This will not match
    unless the host matches both STAFF and DEV/NET, so `root to: "roots#index", as: :network_root`
    etc. is effectively a route to death.
  - In addition, `scope module: :dev` / `scope module: :net` is not specified, so the controller
    name is plain. Resolves to `RootsController`.
- `MissionControl::Jobs::Engine` and `RailsDb::Engine` are `acme.rb:167-169` It is mounted on the
  DEVELOPER block, and it is clear that the intention is to consolidate the operational tools on the
  dev surface.

### problem

- Since dev/net root does not work on the acme side, even if you hit `https://www.dev.localhost/`,
  routing error (need to check for error screen/static page/authentication error).
- The sign side moves but remains a placeholder.

### decision

- **Add a new set of `dev` and `net` roots on the acme surface**:
  - `app/controllers/acme/dev/roots_controller.rb` (inherits from Acme::PublicController).
  - `app/controllers/acme/net/roots_controller.rb` (inherits from Acme::PublicController).
  - Newly created `app/views/acme/{dev,net}/roots/index.html.erb`.
- **Fix routing nesting bug in acme** (simultaneous support in task 1):
  - `constraints host: ENV["ACME_NETWORK_URL"]` and `constraints host: ENV["ACME_DEVELOPER_URL"]` to
    the **outside** of the STAFF block, respectively `scope module: :net, as: :net` / Surround with
    `scope module: :dev, as: :dev`.
  - `MissionControl::Jobs::Engine` / `RailsDb::Engine` mount is `acme.dev` Relocated within the new
    scope (functionality remains the same).
- **On the sign side, replace the placeholder ERB with "Purposeful Landing"**:
  - `dev`: Developer portal. The link destination is the development support page provided by `dev`
    surface (`/jobs`, `/db` External links/host help to things mounted on the acme side, such as
    those mounted on the acme side.
  - `net`: Landing for internal networks. `adr/split-into-regional-and-global-repos.md` A page that
    clearly states the policy that ``API/health is mainly for machines, and pages for humans are
    minimal'' in a manner consistent with the above.
  - Both `Acme::PublicController` / `Sign::PublicController` and does not pass the authentication
    stack (conforms to ADR `three-tier-controller-base.md`).

### Minimum requirements for each page (contract to implementation AI)

- HTTP Returns 200.
- There is only one `<h1>`.
- The entire content is placed under `<main>` (`<main>` itself is OK as long as it is on the layout
  side).
- `lang` attribute is in `<html>` (already supported in existing layout).
- `aria-` attribute is given where required (Level A compliance for Task 4).
- Does not include the hard-coded absolute URL (convention of AGENTS.md).

### Implementation steps

1. Move the `ACME_NETWORK_URL` / `ACME_DEVELOPER_URL` constraints in `acme.rb` out of the STAFF
   nesting. Added `scope module: :net` / `scope module: :dev`. `MissionControl` / `RailsDb` mount is
   Maintain under `acme.dev`.
2. Create a new `app/controllers/acme/{dev,net}/roots_controller.rb` (inherited from
   `Acme::PublicController`).
3. Create a new `app/views/acme/{dev,net}/roots/index.html.erb`.
4. Replace `app/views/sign/{dev,net}/roots/index.html.erb` from placeholder to actual content.
5. Added routing tests (`test/integration/acme/dev_routing_test.rb`, etc.).
6. If you have a footer/header in layout sharing, change the acme layout to `dev` / `net` But check
   if it can be shared. If the footer link contains a page that requires authentication,
   `PublicController` Since it cannot be called under the command, consider branching the layout or
   using a dedicated layout.

### Acceptance conditions

- `https://www.dev.localhost/` (= `ACME_DEVELOPER_URL`) and `https://www.net.localhost/` (=
  `ACME_NETWORK_URL`) returns 200 (integration test in test environment).
- `https://id.dev.localhost/` (= `SIGN_DEVELOPER_URL`) and `https://id.net.localhost/` (=
  `SIGN_NETWORK_URL`) returns 200.
- `<h1>` text for each page is provided via translation file (`config/locales/`).
- WAI-ARIA Level A compliant (aligned with Task 4).

---

## 6. 1:1 i18n keys, eradication of inline `default:`, deletion of unused keys

### current situation

- The locale files are `en.yml` / `ja.yml` directly under `config/locales/`,
  `config/locales/jp/{en,ja}.yml` / `config/locales/us/{en,ja}.yml`. The structure in which
  region-specific catalogs are additionally loaded (`config/application.rb:71-73`
  `load_path += ...`).
- `default_locale = :ja` at `config/application.rb:74`.
- `raise_on_missing_translations = true` is in dev / test / Valid in production
  (`config/environments/development.rb:77`, `test.rb:54`, `production.rb:163`). → **If the keys are
  not aligned, an exception will be thrown immediately**.
- `production.rb:108` in `config.i18n.fallbacks = true` (= Fallbacks for en and ja only work in
  production. (doesn't work in dev/test).
- `Gemfile` has `rubocop-i18n`, but `i18n-tasks` gem is not installed and `.i18n-tasks.yml` is also
  missing.
- ADR Note `notes/i18n-inline-default-literal-rule.md` inline `default: "..."` "Literal Prohibition"
  already exists as **Accepted note (2026-04-17)**. Allowed exceptions:
  - `default: :fallback_key` (symbol key specification)
  - `default: nil` (if the caller handles nil)
- Existing plan `plans/backlog/restoration-f3-i18n-inline-default-ban.md` exists as an
  implementation plan for this ADR (= this task will implement the eradication of `default:`).

### Actual situation (survey results as of 2026-05-08)

**Key difference between en and ja:**

| Indicator                                                                       | Number  |
| ------------------------------------------------------------------------------- | ------- |
| Total number of keys for `en.yml` (not including ja.yml and region-specific)    | 1,484   |
| Total number of keys for `ja.yml`                                               | 2,006   |
| Common for en and ja                                                            | 1,128   |
| **Exists only in en** (= missing in ja → exception occurrence candidate)        | **356** |
| **Only exists in ja** (= missing in en → exception candidate for English users) | **878** |
| All definition keys (en ∪ ja)                                                   | 2,362   |

> Examples of keys only found in en: `actions.actions`, `actions.destroy`,
> `acme.com.configurations.title`, `controller.app.preferences.footer.privacy` etc. Key example only
> found in ja: `actions.cancel`, `actions.delete`, `actions.submit`,
> `activerecord.attributes.customer_email.address` etc.

**inline `default: "<literal>"` violation (`grep -rEn 'default:\s*"[^"]+"' app/`):**

| File                                                             | Line                                           | Modification Policy                                                                      |
| ---------------------------------------------------------------- | ---------------------------------------------- | ---------------------------------------------------------------------------------------- |
| `app/controllers/concerns/authentication/base.rb`                | `:57-60` (`SESSION_LIMIT_HARD_REJECT_MESSAGE`) | Add `errors.messages.session_limit_exceeded` to en/ja and remove `default:`              |
| `app/controllers/concerns/authentication/base.rb`                | `:61` (`LOGIN_COOLDOWN_MESSAGE`)               | Add `errors.messages.login_cooldown` to en/ja and remove `default:`                      |
| `app/controllers/sign/app/auth/omniauth_callbacks_controller.rb` | `:161-165`, `:168-172`                         | Add `sign.app.social.sessions.link.{default,success}` to en/ja and remove inline literal |

(The other two are `default: "/"` of the YARD comment and are not arguments of t() → not applicable)

**YAML alias (`<<: *anchor`) in ja.yml:**

- `ja.yml` uses YAML anchor/alias (Psych requires `aliases: true`).
- Using anchors in translation files makes differential review of translations difficult.
  `i18n-tasks` Common i18n tools such as i18n also cannot be read by the standard parser.
- In this task, **expand and abolish the anchor/alias of ja.yml**.

**Unused key candidates (simple grep-based estimation):**

- `*.{rb,erb}` to `t("...")` / `I18n.t("...")` of `app/`, `config/`, `lib/` Extract → Approximately
  958 keys are referenced.
- en ∪ ja definition key 2,362 to Rails-managed namespaces (`actions`, `activemodel`,
  `activerecord`, `errors`, `date`, `datetime`, `time`, `number`, `support`, `helpers`, `languages`,
  `themes`, `models`, `model`, `mail`, `meta`, `test`, `test_data`, `seed`, `seeds`, `scripts`,
  `tasks`, `common`), the remaining unreferenced keys are **approximately 1,264 keys**.
- However, the following are likely to be false positives, so check them before final deletion:
  - Dynamic builds (`t("foo.#{name}")`, `scope: ...`, `t(".#{action}")`) are not caught by static
    grep.
  - Form auto-completion (`form.label :address` at `activerecord.attributes.<model>.<attr>` is
    implicitly referenced) cannot be caught by grep.
  - The same goes for i18n (`activerecord.attributes.<model>.<enum_value>` series) of `enum`.
- For the above reasons, the number of "actual unused keys" is less than 1,264. **Do not delete
  automatically, always `i18n-tasks unused` Use the output as the primary source**.

### decision

- This task has four scopes:
  1. **Make en and ja 1:1**. Enforce CI to have the same key in both.
  2. **Eradicate inline `default: "<literal>"`**. `notes/i18n-inline-default-literal-rule.md` The
     policy is fully applied.
  3. **Remove unused keys**.
  4. **Remove YAML anchor/alias from ja.yml**.
- Tool adopted: **Introducing `i18n-tasks` gem**. This is a Rails community standard, `health`
  (check all missing/unused/inconsistent interpolations), `missing`, `unused`, `normalize` It has
  commands such as Use with `rubocop-i18n` (existing).

### Implementation steps (Phase configuration)

#### Phase 1: Tool implementation and baseline acquisition

1. Add `gem "i18n-tasks", "~> 1.0", group: %i(development test)` to `Gemfile` `bundle install`.
2. Create a new `config/i18n-tasks.yml`. Minimum configuration:

   ```yaml
   base_locale: ja
   locales: [ja, en]
   data:
     read:
       - config/locales/%{locale}.yml
       - config/locales/**/%{locale}.yml
     write:
       - ["{acme,sign,jump,common,actions,errors}.*", "config/locales/%{locale}.yml"]
       - config/locales/%{locale}.yml
   search:
     paths:
       - app/
       - lib/
       - config/
     strict: false
   ignore_unused:
     - "activerecord.*"
     - "activemodel.*"
     - "errors.*"
     - "date.*"
     - "datetime.*"
     - "time.*"
     - "number.*"
     - "support.*"
     - "helpers.*"
     - "languages.*"
     - "themes.*"
   ignore_missing:
     - "errors.messages.*"
   ```

3. `bundle exec i18n-tasks health` Execute to obtain a baseline of real values ​​(the estimated
   values ​​in this plan are just a simple grep standard, so overwrite them with the tool's exact
   values).

#### Phase 2: Eliminating inline `default:` literals

1. `app/controllers/concerns/authentication/base.rb:57-61`:
   - Added keys for `errors.messages.session_limit_exceeded` to both en / ja.
   - Added keys for `errors.messages.login_cooldown` to both en / ja.
   - Removed `default: "..."` from constant definition.
2. `app/controllers/sign/app/auth/omniauth_callbacks_controller.rb:161-172`:
   - `sign.app.social.sessions.link.default` and `sign.app.social.sessions.link.success` en/ Added
     to ja.
   - Removed `default: "%{provider} linked"` and `default: default_notice`.
3. `bundle exec rubocop --only I18n/RailsI18n/DecorateString` (or similar cop) to prevent more
   violations in CI.

#### Phase 3: 1:1 conversion of en ↔ ja

1. `bundle exec i18n-tasks missing` lists bilateral defects. Corresponding to 356 items (en
   missing) + 878 items (ja missing):
   - **Keys that exist only in ja and not in en**: Create an English translation from the existing
     Japanese translation and add it to en.yml. For items that cannot be translated immediately,
     include at least the "English expression equivalent to the English key name" and add the TODO
     comment (= keys should be 1:1, quality will be adjusted later).
   - **Keys that exist only in en and not in ja**: Create a Japanese translation from the existing
     English translation and add it to ja.yml.
   - The implementation AI reads the corresponding screen (ERB) and writes a translation according
     to the context. Word-for-word translation is not possible.
2. region-specific (`config/locales/jp/`, `config/locales/us/`) is also 1:1 using the same
   convention. `i18n-tasks` Set the `data.read` pattern to also detect catalogs by region.
3. `raise_on_missing_translations = true` of `config/environments/development.rb:77` is already
   valid, so Phase During step 3, start the dev server and step on the screen to detect the missing
   exception.

#### Phase 4: YAML anchor/alias expansion

1. Manually expand all `<<: *anchor` / `&anchor` in `config/locales/ja.yml`.
2. `ruby -ryaml -e 'YAML.load_file("config/locales/ja.yml")'` (= `aliases: true` (= parsable as
   plain YAML).
3. Check region-specific files as well.

#### Phase 5: Delete unused keys

1. Execute `bundle exec i18n-tasks unused` to obtain a list of unused keys.
2. Sort the output into the following categories:
   - **Clearly unnecessary** (screens have been deleted, controller list keys disappeared due to
     refactoring, etc.) → Delete as is.
   - **Possibility of dynamic construction** (`t("foo.#{name}")` series) → Check the dynamic
     construction location with grep, and install `i18n-tasks.yml` Leave it in `ignore_unused` with
     regular expression.
   - **Cannot be determined** → Leave it in the `# TODO` section of `ignore_unused` and re-evaluate
     it in another task.
3. Check the deleted results again with `bundle exec i18n-tasks health`.
4. Confirm that no missing exception occurs during test execution (`bin/rails test`).

#### Phase 6: CI Guard

1. Add `bundle exec i18n-tasks health` to `.github/workflows/` (or applicable CI configuration) and
   in PR:
   - 0 missing keys (en/ja irregular)
   - 0 inconsistent interpolations
   - New inline `default: "<literal>"` guarantees 0 (rubocop based).
2. `bundle exec i18n-tasks unused` is also run together. However, it is acceptable (warn only)
   during the deletion process, and Phase 5 Switch to hard fail after finishing.

### Acceptance conditions

- 0 `bundle exec i18n-tasks missing` (exactly 1:1 en and ja).
- 0 `bundle exec i18n-tasks unused` (or described via `ignore_unused`).
- `t()` / `I18n.t()` that appears in `grep -rEn 'default:\s*"[^"]+"' app/` There are 0 related items
  (YARD comments, etc. are not included).
- `ruby -ryaml -e 'YAML.load_file("config/locales/ja.yml")'` can be parsed without `aliases: true`.
- By starting `bin/rails test` and `bin/rails server` and crossing the main screen,
  `I18n::MissingTranslationData` does not appear.
- i18n-tasks health is a PR blocking condition in CI.

### Precautions

- `default_locale = :ja` Therefore, it is natural to treat the translation of ja as a "source" and
  the translation of en as a "derivative." However, there are keys whose UI source is in English and
  derived from Japanese (for example, some system messages), so judge this on a screen-by-screen
  basis.
- Since `raise_on_missing_translations = true` is already enabled, be sure to run Phase before
  releasing to production. 3 It has already been completed (if missing of = ja → en remains, an
  exception will occur during production).
- region-specific catalog (`jp/`, `us/`) is `adr/regional-docs-news-content-model.md` Consistent
  with region conventions such as . In this task, we limit ourselves to
  `1:1 conversion of en and ja'' and `deletion of unused words'', and do not change the translation
  granularity by region.

### connection

- `notes/i18n-inline-default-literal-rule.md` — inline `default:` Forbidden ADR
- `plans/backlog/restoration-f3-i18n-inline-default-ban.md` — Old plan (included by this task)
- `plans/backlog/restoration-h5-japanese-hardcoded-string-sweep.md` — Cleaning hard code Japanese
  text

---

## Overall test policy

- Each task is an **independent PR**. There are dependencies between tasks:
  - `acme.dev` / `acme.net` out of task 1 Adding a new controller fixes the DEV/NET routing nesting
    bug in acme in task 5. I set up `scope module: :dev` / `scope module: :net` **later** conduct.
    Others (11 locations on com/app/org) can be started without waiting for task 5.
  - Phase 2 (inline `default:` eradication) of Task 6 (i18n) is Task 4 (WAI-ARIA) If you finish
    before a new key is referenced, there will be fewer collisions.
- Full test: `bin/rails test`, related individual: `bin/rails test test/controllers/...`,
  `bin/rails test test/integration/...`, Routing: `bin/rails routes`, i18n:
  `bundle exec i18n-tasks health`.
- Follow the rules of AGENTS.md to perform a destructive migration (Task 2 Phase 2) is executed
  after obtaining user approval.

## Merge order (recommended)

1. Task 5 (`acme.dev` / `acme.net` roots maintenance + acme.rb nested bug fix) — Base maintenance
2. Task 1 (Surface independence of CSP report, URL remains unchanged) — Also put it on the DEV/NET
   scope set up in task 5
3. Task 6 Phase 1-2 (i18n-tasks introduction + inline `default:` eradication) — CI guard early
4. Task 4 (WAI-ARIA Level A) — Include views newly created in Task 5.
5. Task 6 Phase 3-6 (en/ja 1:1ization + unused deletion + YAML anchor expansion + CI hard fail)
6. Task 3 (services → lib refactor) — Be careful as the tests have wide dependencies.
7. Task 2 (delete `occurred_at`) — The final step as it includes auditing DB migration.
