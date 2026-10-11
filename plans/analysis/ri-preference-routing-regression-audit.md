# RI Preference Routing Regression Audit

**Date:** 2026-08-13 **Baseline commit:** `39b6cafbd` (branch `develop`) **Scope:** the `ri`
request-context mechanism across the `auth`, `base`, `side`, `core`, and `palm` surfaces (13 routing
targets) **Type:** investigation only. No production code was changed by this audit.

## Evidence classification

Every claim in this report carries one of four labels. They are not interchangeable.

| Label          | Meaning                                                                         |
| -------------- | ------------------------------------------------------------------------------- |
| **Fact**       | Read directly from source, configuration, or git object at the cited location.  |
| **Inference**  | Follows from cited facts by direct reasoning, with no independent confirmation. |
| **Hypothesis** | Plausible, consistent with the evidence, not established.                       |
| **Unverified** | Not established in this session. Not executed, not observed.                    |

**Method limitation, stated up front:** no runtime reproduction was performed. `bin/rails` does not
boot in the audit shell — `config/application.rb:27` raises
`Missing required configuration: TRUSTED_PROXIES` — and running the suite requires the compose
environment. The user elected static analysis only. **No test was executed and no HTTP request was
issued during this audit.** Every dynamic behavior claim is therefore either static inference from
`preference_global.rb` or marked Unverified.

A second method note: `git log -S … --all` in this repository triggers a `rails credentials diff`
textconv driver that pollutes output and can abort the revision walk. All git evidence below was
produced with `git -c diff.rails_credentials.textconv=cat` and an explicit pathspec.

---

## 1. Executive Summary

The reported `auth` failure is real, is present in the committed tree at `39b6cafbd`, and has a
single identified cause.

**Direct cause (Fact).** Six leaf controllers on the `auth` surface carry
`skip_before_action :set_region, raise: false`:

```
app/controllers/auth/{app,com,org}/sign/{ins,ups}_controller.rb
```

These are the sign-in and sign-up entry pages — the most-trafficked HTML entry points on the
surface. With the callback skipped, `ri` is never normalized into `params`, and because
`PreferenceGlobal#default_url_options` reads **params only**, every URL generated on those pages is
built without a region.

**Regression-introducing commit (Fact).** `f0cbba2b51ca85e5e8e738fa20cdba71b7a06f98`, 2026-06-12
15:38:31 +0900, subject `[CheckPoint] ..........`, 36 files, no body, no issue or ADR reference. Its
parent `f0cbba2b51^` is the last known good state; `f0cbba2b51` is the first known bad state. The
boundary was verified by counting occurrences in both revisions.

**Why `base` was unaffected (Fact).** `base` has no sign-in or sign-up controllers at all —
`app/controllers/base/*/sign*/` contains only `sign_outs`, `sign_outs/completions`, and
`base/app/sign/in/limitations`. There was never an equivalent line to add. The `auth`/`base`
asymmetry is structural, not a deliberate policy split. Both surfaces' `ApplicationController`s are
equivalent with respect to `ri`.

**Why it went undetected for two months (Fact).** Every existing callback-chain test asserts
`set_region` on the **`ApplicationController`**, which was always correct. No test asserted the
effective callback chain of the leaf controllers where the skip lived. `raise: false` suppressed the
one runtime signal. And `docs/reference/forbidden-rails-methods.md:57-59` explicitly classifies
skipping `:set_region` as permitted and "not a security relaxation", which is why the mechanical
guard `test/unit/security/forbidden_rails_patterns_test.rb` does not flag it.

**Two further defects of the same class, found during the audit and not scoped out.**

- `palm/app` — target 13 of 13 — has no `ri` mechanism whatsoever. It renders HTML and never
  attaches or enforces a region.
- Nine `auth` HTML routes inherit `Auth::RedirectOnlyController`, which descends from the bare root
  `::ApplicationController` and therefore has no `ri` mechanism either.

**A fix is already in progress in the working tree, uncommitted, and was not authored by this
audit.** It removes all six skips and adds `test/integration/auth_region_contract_test.rb`. See §17.

---

## 2. Definition of the RI Contract

**Fact.** `ri` is the **region identifier**. It is not a locale. Language is a separate key, `lx`.

| Property           | Value                           | Source                                                           |
| ------------------ | ------------------------------- | ---------------------------------------------------------------- |
| Internal name      | `region`                        | `app/services/request_context_contract.rb:30` (`INTERNAL_NAMES`) |
| Allowed values     | `jp`, `us`                      | `app/services/request_context_contract.rb:9` (`ALLOWED_REGIONS`) |
| Default            | `jp`                            | `app/services/request_context_contract.rb:10` (`DEFAULT_REGION`) |
| Family             | required (not optional overlay) | `request_context_contract.rb:5` (`REQUIRED_KEYS = %i(ri)`)       |
| Normalization      | downcased                       | `request_context_contract.rb:100-103` (`normalize_region`)       |
| Preference default | `"ri" => "jp"`                  | `app/models/concerns/preference_constants.rb:16`                 |

The full public request-context vocabulary is `ri` (required), `pt`/`nt` (return targets, excluded
from URL propagation), and the optional overlays `lx ct tz cu df tf mo dn ps`
(`request_context_contract.rb:5-8`).

### Normative statement

`docs/architecture/preference.md:197` is the canonical specification:

> `ri` is mandatory request context. Current sign `app`, `org`, and `com` routes must carry a valid
> `ri`. If `ri` is missing or invalid on a GET or HEAD request, the controller redirects to the same
> route with a valid `ri` value. `ri` is request context, not a preference write path.

`adr/localization-preference-flow.md:37-41` fixes precedence:

> An explicit valid `ri` request parameter wins… The system must not rewrite an explicit `?ri=us` to
> the persisted value.

### Resolution order

**Fact**, `app/controllers/concerns/preference_global.rb:61-63`:

```ruby
def effective_context
  default_context.merge(cookie_context).merge(requested_context)
end
```

Lowest to highest precedence: **built-in defaults → preference cookie/JWT `prf` claim → request
params**. A request param only participates if it survives validation
(`preference_global.rb:100-111`); an invalid value is dropped entirely rather than clamped, so an
invalid `ri` falls through to the cookie value and then to `jp`.

### The two halves of the mechanism

**Fact.** The contract is implemented by one concern, `PreferenceGlobal`, in two cooperating parts.

**(a) Enforcement — `set_region`** (`preference_global.rb:202-219`), registered as a
`before_action`:

```ruby
def set_region
  return if request_format_json?

  normalized_ri = normalized_param_ri
  redirect_params = sanitized_context_query_parameters
  query_changed = redirect_params != request.query_parameters

  if valid_ri_value?(normalized_ri)
    return unless query_changed && (request.get? || request.head?)
    return redirect_to_context_query(redirect_params)
  end

  return unless request.get? || request.head? || params[:ri].present?

  redirect_params = redirect_params.merge("ri" => get_region)
  redirect_to_context_query(redirect_params)
end
```

**(b) Propagation — `default_url_options`** (`preference_global.rb:69-73`):

```ruby
def default_url_options
  base_options = super || {}
  context = requested_context.slice(*PARAM_CONTEXT_KEYS)
  context.present? ? base_options.merge(context) : base_options
end
```

### The critical asymmetry

**Inference, from `preference_global.rb:43-45, 61-73`.** `default_url_options` merges
`requested_context`, which is derived from **`params` only** — not from `effective_context`, and so
not from the cookie or the defaults. Propagation therefore depends entirely on enforcement having
already run: `set_region` redirects the browser to a URL that _contains_ `ri`, and only on that
second request does `params[:ri]` exist for `default_url_options` to propagate.

**Consequence: if `set_region` does not run, nothing else puts `ri` into generated URLs.** There is
no fallback path. This single design property converts one skipped callback into surface-wide region
loss, and it is the mechanism by which the regression in §11 produced the reported symptom.

### Redirect construction

**Fact**, `preference_global.rb:230-242` and `:171-176`. Redirect URLs are built as
`request.base_url + request.path`, with the query taken from
`request.query_parameters.merge("ri" => value)`. The code comment at `:231-236` records why the path
is taken from the request rather than regenerated from controller/action: acme routes every
preference screen through a single `screens` controller, so `url_for(controller:, action:)` would
collapse to the first screen route.

Status codes (`preference_global.rb:178-180`): `302 Found` for GET/HEAD, `303 See Other` otherwise.

---

## 3. Surface Inventory

**Terminology.** Two orthogonal axes are both called "surface" in this repository. `AGENTS.md:37-41`
uses it for the **edition / trust boundary** (`app`, `org`, `com`). The user's list (`auth`, `base`,
`side`, `core`, `palm`) is the **service family**. This report says _family_ and _edition_ to keep
them apart. The real unit is family × edition.

**Fact.** `config/routes.rb:4-31` draws **nine** families, not five. Counting `constraints host:`
blocks across all nine route files gives **29** distinct host-constrained routing targets:

| Route file              | Edition blocks                                           | Count  |
| ----------------------- | -------------------------------------------------------- | ------ |
| `config/routes/auth.rb` | app `:9`, com `:230`, org `:386`                         | 3      |
| `config/routes/base.rb` | app `:8`, com `:253`, org `:423`, net `:609`, dev `:626` | 5      |
| `config/routes/core.rb` | app `:7`, com `:89`, org `:171`, net `:256`, dev `:278`  | 5      |
| `config/routes/side.rb` | app `:7`, com `:74`, org `:142`                          | 3      |
| `config/routes/palm.rb` | app `:7`                                                 | 1      |
| `config/routes/info.rb` | app `:7`, com `:35`, org `:63`                           | 3      |
| `config/routes/help.rb` | app `:7`, com `:50`, org `:93`                           | 3      |
| `config/routes/docs.rb` | app `:7`, com `:47`, org `:86`                           | 3      |
| `config/routes/news.rb` | app `:7`, com `:47`, org `:87`                           | 3      |
|                         |                                                          | **29** |

**The count of 13 is confirmed** as exactly the five named families restricted to the three
user-facing editions: `{auth, base, core, side} × {app, com, org}` + `palm/app`. It is a correct and
coherent slice, not an approximation.

### Inheritance shape

**Fact.** Every per-family `ApplicationController` inherits `ActionController::Base` **directly**,
not the root `ApplicationController`. There are 16 files named `application_controller.rb`. They are
sibling roots that share behavior only through `app/controllers/concerns/`. This is the deliberate
surface isolation `AGENTS.md:100` requires, and it means there is no single place where the `ri`
contract can be centrally guaranteed.

---

## 4. 13-Target Verification Matrix

Structural columns are **Fact** (read at `39b6cafbd`). Behavioral verification is **Unverified** —
see the method limitation above.

| #   | Family | Edition | Representative route     | ApplicationController                  | HTML UI            | `include ::PreferenceGlobal` | `before_action :set_region` | RI status                         |
| --- | ------ | ------- | ------------------------ | -------------------------------------- | ------------------ | ---------------------------- | --------------------------- | --------------------------------- |
| 1   | auth   | app     | `routes/auth.rb:9-13`    | `auth/app/application_controller.rb:6` | Yes (50 templates) | `:14`                        | `:78`                       | **Broken at leaves** (§5.1)       |
| 2   | auth   | com     | `routes/auth.rb:230-234` | `auth/com/application_controller.rb:6` | Yes (31)           | `:13`                        | `:70`                       | **Broken at leaves** (§5.1)       |
| 3   | auth   | org     | `routes/auth.rb:386-390` | `auth/org/application_controller.rb:6` | Yes (29)           | `:13`                        | `:74`                       | **Broken at leaves** (§5.1, §5.3) |
| 4   | base   | app     | `routes/base.rb:8-12`    | `base/app/application_controller.rb:6` | Yes (50)           | `:13`                        | `:75`                       | Wired                             |
| 5   | base   | com     | `routes/base.rb:253-257` | `base/com/application_controller.rb:6` | Yes (36)           | `:13`                        | `:73`                       | Wired                             |
| 6   | base   | org     | `routes/base.rb:423-427` | `base/org/application_controller.rb:6` | Yes (34)           | `:13`                        | `:74`                       | Wired                             |
| 7   | core   | app     | `routes/core.rb:7`       | `core/app/application_controller.rb:6` | Inertia + 2        | `:11`                        | `:65`                       | Wired                             |
| 8   | core   | com     | `routes/core.rb:89`      | `core/com/application_controller.rb:6` | Inertia + 2        | `:11`                        | `:65`                       | Wired                             |
| 9   | core   | org     | `routes/core.rb:171`     | `core/org/application_controller.rb:6` | Inertia + 2        | `:11`                        | `:65`                       | Wired                             |
| 10  | side   | app     | `routes/side.rb:7`       | `side/app/application_controller.rb:6` | Inertia + 2        | `:11`                        | `:60`                       | Wired                             |
| 11  | side   | com     | `routes/side.rb:74`      | `side/com/application_controller.rb:6` | Inertia + 2        | `:11`                        | `:59`                       | Wired                             |
| 12  | side   | org     | `routes/side.rb:142`     | `side/org/application_controller.rb:6` | Inertia + 2        | `:11`                        | `:60`                       | Wired                             |
| 13  | palm   | app     | `routes/palm.rb:7`       | `palm/app/application_controller.rb:6` | Yes (2)            | **none**                     | **none**                    | **Absent** (§5.2)                 |

### Cases A–I

Cases D, E, F and H are settled by reading `preference_global.rb` and are labelled **static
inference**. Cases A, B, C, G and I require execution and are **Unverified** for all 13 targets.

| Case | Description                                       | Status                                                                                                                                                                                                                                                                                  | Basis                                                                                                                  |
| ---- | ------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| A    | `/path` — is `ri` auto-attached?                  | **Unverified** on all 13                                                                                                                                                                                                                                                                | Requires a request. Statically, targets 1–3 and 13 have no code path that would attach it on the affected controllers. |
| B    | `/path?ri=jp` — is the value preserved?           | **Unverified**                                                                                                                                                                                                                                                                          | `set_region:209-212` returns without redirecting when the value is valid and the query is unchanged.                   |
| C    | `/path?ri=us` — alternate valid value             | **Unverified**                                                                                                                                                                                                                                                                          | `ALLOWED_REGIONS = %w(jp us)`, `request_context_contract.rb:9`.                                                        |
| D    | `/path?ri=INVALID`                                | **Static inference: dropped, then re-derived.** `request_context_value:107-110` returns `nil` when `valid_requested_context_value?` fails, so the invalid value never enters `requested_context`; `set_region:215-218` then redirects with `get_region`, i.e. the cookie value or `jp`. | `preference_global.rb:100-111, 119-121, 190-192, 215-218`                                                              |
| E    | `/path?foo=bar` — existing query preserved?       | **Static inference: yes.** The redirect query is `request.query_parameters.merge("ri" => …)`, which preserves unrelated keys.                                                                                                                                                           | `preference_global.rb:217, 237-239`                                                                                    |
| F    | `?ri=jp&ri=jp` — duplicate produced?              | **Static inference: no.** `merge` on a Hash cannot yield a duplicate key, and `to_query` emits one pair per key.                                                                                                                                                                        | `preference_global.rb:172, 217, 238`                                                                                   |
| G    | Redirect chain A→B→A                              | **Unverified.** Statically, `set_region:210` guards with `query_changed`, so a request whose sanitized query already equals the request query does not redirect again. Whether this holds under `RegionalRootRedirect` and `RootSignInRedirect` interaction is **not established**.     | `preference_global.rb:207, 210`                                                                                        |
| H    | Preference precedence                             | **Static inference: params > cookie > default**, and an explicit valid `ri` is never rewritten.                                                                                                                                                                                         | `preference_global.rb:61-63`; `adr/localization-preference-flow.md:37-41`                                              |
| I    | HTML entry point actually exercises the mechanism | **Unverified by execution.** Structurally established for the 12 wired targets and structurally _disproven_ for targets 1–3 at `/sign/in` and `/sign/up` (§5.1) and for target 13 (§5.2).                                                                                               | §5                                                                                                                     |

**This matrix is incomplete by design of the agreed scope.** Anyone acting on it should run the A–I
cases under compose before treating the "Wired" rows as verified working.

---

## 5. Current Failures

All findings are at `39b6cafbd`. The uncommitted working-tree fix is covered separately in §17.

### 5.1 Primary — six `auth` HTML entry controllers skip `set_region` (Fact)

```
$ git grep -c "skip_before_action :set_region" HEAD -- app/controllers | wc -l
53
```

53 controllers skip the callback at HEAD. **52 of them are protocol endpoints where skipping is
legitimate** — `oidc/authorizations`, `oidc/callbacks`, `edge/v0/{cookies,dbsc,token/*}`,
`omniauth/omniauth_callbacks`, present symmetrically across `auth`, `base`, `core`, and `side`.
These serve JSON or perform protocol redirects and do not render regional HTML.

**Six are different.** They are HTML entry pages:

| Controller                                        | Line  | Class declaration                                                 |
| ------------------------------------------------- | ----- | ----------------------------------------------------------------- |
| `app/controllers/auth/app/sign/ins_controller.rb` | `:10` | `class InsController < ::Auth::App::ApplicationController` (`:7`) |
| `app/controllers/auth/app/sign/ups_controller.rb` | `:10` | ditto                                                             |
| `app/controllers/auth/com/sign/ins_controller.rb` | `:10` | `< ::Auth::Com::ApplicationController`                            |
| `app/controllers/auth/com/sign/ups_controller.rb` | `:10` | ditto                                                             |
| `app/controllers/auth/org/sign/ins_controller.rb` | `:10` | `< ::Auth::Org::ApplicationController`                            |
| `app/controllers/auth/org/sign/ups_controller.rb` | `:10` | ditto                                                             |

Routed at `config/routes/auth.rb:49-52` as the canonical ceremony entry points:

```ruby
namespace :sign do
  resource :registration, only: :show, path: "up", controller: :ups, as: :up
  resource :session,      only: :show, path: "in", controller: :ins, as: :in
```

**Impact (Inference from §2's asymmetry).** On `/sign/in` and `/sign/up` across all three `auth`
editions:

- A request without `ri` is **not** redirected to add one. The page renders with no region in the
  request context, and every link built by a URL helper on that page is region-less.
- A request with an unrecognized `ri` is **not** normalized. `set_region` is the only validator on
  this path, so the raw value propagates.

These are the highest-traffic pages on the surface, and they are the funnel into the entire
credential ceremony — so region loss here propagates into every page reached from them.

### 5.2 `palm/app` has no RI mechanism at all (Fact) — target 13 of 13

`app/controllers/palm/app/application_controller.rb` is twelve lines in full:

```ruby
module Palm
  module App
    class ApplicationController < ActionController::Base
      AUTHENTICATION_MODE = :bare

      layout "palm/app/application"
    end
  end
end
```

No `include ::PreferenceGlobal`, no `set_region`, no `default_url_options` override.

It renders HTML — `app/views/palm/app/roots/index.html.erb` and
`app/views/palm/app/sign_outs/show.html.erb` — and the rest of the system already builds
region-carrying links into it: `test/integration/html_title_contract_test.rb:92` uses
`palm_app_sign_out_path(ri: "jp")`, and `app/services/palm_logout_coordinator.rb:15,74,120` handles
`ri`. So `palm` participates in region-bearing URLs but neither attaches nor validates one itself.

**Hypothesis, not established:** this may be intentional, since `config/routes.rb:24` describes palm
as "the native RP and bearer-token API surface" and `AUTHENTICATION_MODE = :bare` suggests a
deliberately minimal stack. **No ADR, comment, or documentation states this exemption**, which is
itself the problem — an undocumented exemption is indistinguishable from an oversight. See §16 for
the recommended remedy (explicit, documented exemption in a registry).

### 5.3 Nine `auth` routes bypass the mechanism via `Auth::RedirectOnlyController` (Fact)

`app/controllers/auth/redirect_only_controller.rb:5-6`:

```ruby
# FIXME: I want to delete this file.
module Auth
  class RedirectOnlyController < ApplicationController
```

Inside `module Auth` with no `Auth::ApplicationController` defined, this constant resolves to the
**root** `::ApplicationController` — `app/controllers/application_controller.rb:4-13`, a bare
`ActionController::Base` subclass with no `PreferenceGlobal`, no `set_region`, no
`default_url_options` override.

Nine controllers inherit it, and the class exists **only** under `auth`:

- `auth/org/{accounts,system,iam,billing,audit,configurations,support}_controller.rb:6`
- `auth/app/billings_controller.rb:6`

Routed at `config/routes/auth.rb:420-424` (`configuration`, `iam`, `system`, `audit`) among others.

Each action calls `redirect_to_acme_authority!(path)`. The query builder
`app/controllers/concerns/sign_acme_authority_redirect.rb:22-29` forwards `ri` **only if
`params[:ri]` is already populated**:

```ruby
def base_authority_query(query_params = nil)
  return query_params.to_query if query_params.present?

  ri = params[:ri].presence
  return if ri.blank?

  { ri: ri }.to_query
end
```

**Inference.** Because `set_region` never runs on these controllers, a request to e.g.
`https://auth.umaxica.org/system` with no `ri` is not redirected to `…/system?ri=jp`; it is
redirected cross-host to base with the region **dropped**. Base then applies its own `set_region`
and re-derives a region from _its own_ cookie context, so the user's region on the `auth` host is
silently discarded and an extra redirect hop is added. Whether the re-derived region differs in
practice is **Unverified**.

### 5.4 Outside the 13 — `base/{net,dev}` and `core/{net,dev}` (Fact)

`grep -rn "PreferenceGlobal\|set_region" app/controllers/{base,core}/{net,dev}` returns nothing.
These four editions are genuine routing targets (`routes/base.rb:609,626`, `routes/core.rb:256,278`)
with real controllers and endpoints. They serve health probes, CSP violation reports, and root pages
— most plausibly outside the region contract, but again **undocumented**.

---

## 6. auth vs base Differential Analysis

This is the chapter that corrects the natural hypothesis. The obvious theory — _"a concern is loaded
on `base` but not on `auth`"_ — is **false**.

### 6.1 The ApplicationControllers are equivalent for `ri` (Fact)

Comparing `app/controllers/auth/app/application_controller.rb` and
`app/controllers/base/app/application_controller.rb` line by line across the dimensions requested:

| Dimension                                    | `auth/app`                                                                   | `base/app`                    | Differs for `ri`? |
| -------------------------------------------- | ---------------------------------------------------------------------------- | ----------------------------- | ----------------- |
| Superclass                                   | `ActionController::Base` `:6`                                                | `ActionController::Base` `:6` | No                |
| `include ::PreferenceGlobal`                 | `:13`                                                                        | `:12`                         | No                |
| `include ::PreferenceAdoption`               | `:15`                                                                        | `:14`                         | No                |
| `include ::Session`                          | `:12`                                                                        | `:10`                         | No                |
| `before_action :set_preferences_cookie`      | `:75`                                                                        | `:72`                         | No                |
| `before_action :resolve_param_context`       | `:76`                                                                        | `:73`                         | No                |
| `before_action :set_region`                  | `:77`                                                                        | `:74`                         | No                |
| Relative order of the three above            | identical                                                                    | identical                     | No                |
| Preceding callbacks                          | `verify_jump_return_rt!`, `rate_limit`, `set_current_context`, `reset_flash` | same set, same order          | No                |
| `default_url_options` override in class body | none                                                                         | none                          | No                |
| Route defaults / constraints                 | `constraints host:` only, no `defaults`                                      | same shape                    | No                |
| Initializers                                 | shared; none surface-specific for `ri`                                       | shared                        | No                |

Differences that do exist — `WebauthnSurfaceDeclarable`, `SignSignupObservability`,
`AuthenticationCredentialInventoryReader`, `enforce_sign_in_selector_gate!`,
`TrustedOriginForgeryProtection` vs an inline `protect_from_forgery`, and the position of the
`protect_from_forgery` declaration — are all unrelated to region handling.

**Conclusion (Fact): the divergence is not at the ApplicationController layer.**

### 6.2 The divergence is below them, in leaf controllers `base` does not have (Fact)

`base` has no sign-in or sign-up entrance controllers. The complete list of `sign`-related
controllers under `app/controllers/base/`:

```
base/app/sign/in/limitations_controller.rb
base/app/sign_outs_controller.rb
base/app/sign_outs/completions_controller.rb
base/com/sign_outs_controller.rb
base/com/sign_outs/completions_controller.rb
base/org/sign_outs_controller.rb
base/org/sign_outs/completions_controller.rb
```

Sign-_out_ only. The credential gateway lives entirely on `auth` — by design; `config/routes.rb:7`
states "Auth owns the credential gateway for sign-in/sign-up ceremonies."

**So there was never a `base` counterpart to the six skipped controllers.** `base` did not "keep"
the mechanism through better discipline; it was never exposed to the change. This matters for §18:
common-ization would not have prevented this, because there is nothing to share — the failure is in
code that exists on exactly one surface.

### 6.3 Controllers that look suspicious but are innocent (Fact)

- `auth/{app,com,org}/verification/base_controller.rb` include `::PreferenceGlobal` a second time
  (`:11`, `:9`, `:9`) with no `before_action :set_region` of their own. This is a harmless no-op
  re-include: they inherit from the surface `ApplicationController`, so `set_region` is already in
  the chain, and they add `before_action :require_ri!` (`:27`, `:27`, `:25`) — which calls
  `params.require(:ri)` (`app/controllers/concerns/sign_verification_common_base.rb:9-11`), a
  _stricter_ guard.
- `auth/{app,com,org}/bare_controller.rb` bypass `ApplicationController` deliberately and say so:
  _"Intentionally bypasses ApplicationController and its app-wide callbacks. Do not normalize this
  inheritance."_ They serve robots.txt, sitemaps, health, JWKS, revisions — no regional HTML.
- `auth/org/sign/up/base_controller.rb:14,29` re-declares `include ::PreferenceGlobal` and
  `before_action :set_region` explicitly. Redundant but correct.

---

## 7. Existing Test Coverage

**Fact.** Minitest only for Ruby; 1481 `*_test.rb` files. There is no `test/system/` and no
`test/routing/`. `spec/` and `e2e/` are frontend and Playwright.

The `ri` contract is asserted in exactly four places.

| #   | File                                                                                             | Classification | What it covers                                                                                                                                                                         | Blind spot                                                                                                                                           |
| --- | ------------------------------------------------------------------------------------------------ | -------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | `test/integration/preference_global_param_context_test.rb`                                       | integration    | `DOMAINS` at `:13-23`: missing-`ri` redirect `:31`, `ri` in `default_url_options` `:96`, existing query preserved `:297`, invalid overlays stripped `:247`                             | **`base_app` / `base_org` / `base_com` only.** No auth, side, core, palm. `:96` inspects only Inertia `screens[].href` on the base preference index. |
| 2   | `test/integration/auth_region_contract_test.rb`                                                  | integration    | auth app/com/org (`SURFACES` `:14-18`): missing region normalized `:22`, unrecognized region normalized `:34`, handoff carries region `:51`, every generated link carries region `:64` | `ENTRY_PATHS = %w(/sign/in /sign/up)` at `:20` **only**. And see §17 — this file is **uncommitted**; it did not exist during the regression window.  |
| 3   | `test/controllers/concerns/preference/global_test.rb:223-228`, `global_coverage_test.rb:161-165` | unit           | `default_url_options` merges requested context; `get_region` precedence `:231-246`; `ensure_required_ri!` redirect `:249-263`                                                          | Runs against a **bare harness controller**. Proves the concern works; can never prove a surface includes it or that a leaf does not skip it.         |
| 4   | `test/helpers/sign/org/sign_ups_helper_test.rb:42-47`                                            | helper         | `ri` appears in generated markup `:59`                                                                                                                                                 | **Stubs `default_url_options` itself.** Cannot detect the real mechanism failing.                                                                    |

### Callback-chain tests — the near miss (Fact)

`test/controllers/{base/app,base/com,base/org}/application_controller_test.rb` assert
`assert_includes before_filters, :set_region`, and the `auth` equivalents assert the same ordered
list. **These tests exist, they pass, and they were always going to pass** — they test the
`ApplicationController`, which was never broken. No test walks `_process_action_callbacks` on a
_leaf_ controller.

### Structural gaps (Fact)

- `test/controllers/auth/app/default_url_options_test.rb` and
  `test/controllers/auth/org/default_url_options_test.rb` are **empty stubs**. Their entire content
  is a comment: _"This test file has been removed as preferences functionality has been moved to
  Peak::App"_ (resp. `Peak::Org`). `Peak` no longer exists — it was renamed away in `1c71dbc649`
  ("renamed routing: auth -> sign, peak -> apex"). The two files whose names promise exactly this
  coverage deliver none, and their names actively suggest the area is covered.
- `side`, `core`, and `palm` tests pass `ri:` explicitly on **both** the request and the expected
  URL — e.g. `test/controllers/side/com/dashboards_controller_test.rb:25-28`:
  `assert_select "a[href=?]", side_com_root_path(ri: "jp")`. Such an assertion cannot fail if
  `default_url_options` stops injecting `ri`.
- All 14 `test/integration/routes/*_route_contract_test.rb` files contain **zero** `ri:` references,
  including `side_route_contract_test.rb`, `core_route_contract_test.rb`,
  `palm_route_contract_test.rb`.
- **No test iterates `%w(auth base side core palm)`.** There is no shared-example mechanism and no
  global surface constant. `test/support/preference_lifecycle_surfaces.rb:32-66` is the one
  deliberate cross-surface adapter, and its own header (`:4-14`) states the correct doctrine — _"the
  behavioral assertions must be shared code exercised once per surface, not three copy-pasted test
  files"_ — but its axis is app/com/org and it has **no routing or URL dimension**.
- `test/controllers/concerns/dbsc_canonical_url_test.rb:70` carries the comment _"DAMP local route
  helper aliases for former shared test support"_ — evidence that a shared support module once
  existed and was inlined away.

### Test environment (Fact)

- `config/environments/test.rb:58` sets `action_mailer.default_url_options` only. Nothing configures
  controller or router `default_url_options` in test.
- `test.rb` has **no `config.hosts` entry**, so Host Authorization is inert in test and host-
  dependent region routing cannot fail the way it does in dev/prod.
- `test_helper.rb:14-21` deliberately sets no default host, and `:45-50` `host_headers` sets only
  the `Host` header — **nothing in the harness injects `ri` automatically.** The "fixture hides the
  bug" hypothesis is **disproven**.
- `test.rb:82` `raise_on_missing_callback_actions = true` would catch a callback naming a
  nonexistent action, but not a surface that never registers one.

---

## 8. Why CI Failed to Detect the Regression

Five independent failures, all Fact unless noted.

**8.1 The assertion was aimed one level too high.** Callback-chain tests asserted `set_region` on
`ApplicationController`. The skip was on the leaf. The test that would have caught it — walking
`_process_action_callbacks` on `Auth::App::Sign::InsController` — does not exist.

**8.2 `raise: false` suppressed the runtime signal.** `skip_before_action :set_region` without
`raise: false` would raise if the callback were ever renamed or removed. With it, the skip is silent
in every direction.

**8.3 Policy explicitly permitted the change.** `docs/reference/forbidden-rails-methods.md:57-59`:

> Skipping non-security context/preference callbacks (for example `:set_region`,
> `:set_preferences_cookie`, `:set_color_theme`) is allowed where an endpoint legitimately does not
> participate in that context, and is not a security relaxation.

`:53-56` shows the contrast: `enforce_verification_if_required`, `enforce_step_up_prereqs!` and
`authenticate_client!` are gated by a reviewed `SENSITIVE_SKIP_ALLOWLIST`, mechanically enforced by
`test/unit/security/forbidden_rails_patterns_test.rb`, so _"a new file that skips one of these fails
that test until the boundary change is deliberately reviewed."_ `set_region` was placed outside that
regime. **The mechanical guard that exists was configured not to look.** A reviewer consulting the
policy would have found the change explicitly sanctioned.

**8.4 The commit shipped with zero guarding coverage — twice.** `f0cbba2b51` touched 36 files, of
which 10 were tests:

```
M test/controllers/sign/oidc_entrances_test.rb
M test/controllers/sign/org/{accounts,audit,billing,iam,support,system}_controller_test.rb
M test/integration/core_rp_browser_flow_test.rb
M test/integration/oidc_rp_browser_flow_test.rb
M test/unit/jit/security/jwt/registry_test.rb
```

All **modified**, none added, **not one asserting region behavior**. The follow-up rename
`94a0b44e03` modified 9 more test files, all mechanical path swaps.

**8.5 The commit was unreviewable by construction.** Subject `[CheckPoint] ..........`, no body, 36
files, mixing a behavioral change (`normalize_to_acme_authorize!`), a callback skip, and unrelated
edits. **Hypothesis:** no pull-request review occurred; the repository's commit-message pattern
(`[CheckPoint] .`, `[update] ..`, `[xxx] .`, and seven commits whose entire subject is a bare SHA)
is consistent with direct-to-branch checkpoint commits. Not established — no PR metadata was
retrieved.

**Additionally**, the coverage gaps in §7 meant that even a correct suite run proved nothing about
`auth` HTML entry points: at the time of the regression, no test asserted region behavior on any
`auth` page. `auth_region_contract_test.rb` — the test that covers exactly this — is **uncommitted
today** (§17) and therefore did not exist in the regression window.

---

## 9. Git History Investigation

Commands used (all read-only; the textconv workaround is required):

```bash
git -c diff.rails_credentials.textconv=cat log --follow -p -- <path>
git -c diff.rails_credentials.textconv=cat log -S'skip_before_action :set_region' -- <path>
git show <rev>:<path>
git show --stat <rev>
git grep -c "skip_before_action :set_region" HEAD -- app/controllers
```

**Renames are the central obstacle (Fact).** `git log --follow` on today's
`app/controllers/auth/app/sign/ins_controller.rb` reports only `94a0b44e03` and **hides the true
origin**, because two renames sit between them. The origin was recovered by walking the pre-rename
path `app/controllers/sign/app/sign/in/entrances_controller.rb` explicitly.

The rename chain: `sign/*/sign/in/entrances_controller.rb` → (`94a0b44e03`, 2026-06-16) →
`sign/*/sign/ins_controller.rb` → (`3683d7aecb`, 2026-06-27, surface-wide `sign/` → `auth/`) →
`auth/*/sign/ins_controller.rb`. Earlier renames in the repository's history include `peak → apex`,
`top → apex`, and `acme → base`.

### Commits touching the `ri` mechanism

| Hash             | Date           | Subject                                                    | What changed                                                                                                                                             | Confidence |
| ---------------- | -------------- | ---------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------- |
| `2f7ccd2cfa`     | 2025-05-03     | `[CHECK POINT] ....`                                       | Earliest `--follow` ancestor of `preference_global.rb`                                                                                                   | Fact       |
| `d277886e4`      | 2026-01-11     | `[misc] trying to rewrite defalut url options.`            | `default_url_options` rework — establishes "`ri` rides on every URL helper"                                                                              | Fact       |
| `b5c65d9e7`      | 2026-01-13     | `[update] implemented get paramater inherinece.`           | Param inheritance across generated URLs                                                                                                                  | Fact       |
| `9c2164d31e`     | 2026-01-28     | `[xxx] .`                                                  | Concern re-created at current path after rename churn                                                                                                    | Fact       |
| `8426371e9`      | 2026-02-24     | `[check point] trying to drop 3 tables.`                   | Only commit changing the `set_region` count in `auth/app` + `auth/org` ApplicationController                                                             | Fact       |
| `e2dc86edc`      | 2026-03-31     | `[check point] .`                                          | Same for `auth/com`                                                                                                                                      | Fact       |
| `5716a1e2c`      | 2026-05-09     | `[update] complete Rails app separation…`                  | Adds `adr/public-controller-base.md`, which names `skip_before_action :set_region, raise: false` as a fragile pattern (`:21`, `:27`)                     | Fact       |
| `f4d1f701d`      | 2026-05-28     | `[CheckPoint] trying to refactor of preference functions.` | Only commit changing the `set_region` count in all three `base` ApplicationControllers; part of the `Preference::Global` → `PreferenceGlobal` flattening | Fact       |
| `3c6c2e95e`      | 2026-06-03     | `[CheckPoint] ready to check those changes.`               | `auth/redirect_only_controller.rb` created (§5.3)                                                                                                        | Fact       |
| **`f0cbba2b51`** | **2026-06-12** | **`[CheckPoint] ..........`**                              | **Adds `skip_before_action :set_region, raise: false` to all six sign entrance controllers**                                                             | **Fact**   |
| `94a0b44e03`     | 2026-06-16     | `[update] ..........`                                      | Rename; skip carried forward verbatim                                                                                                                    | Fact       |
| `3683d7aecb`     | 2026-06-27     | `[update] huge meteor attack to our repos.`                | `sign/` → `auth/` rename; skip carried forward again                                                                                                     | Fact       |

The `Preference::Global` → `PreferenceGlobal` flattening ran across `97b0241aba` (05-15),
`1b39753a00` (05-20), `0b65920519` (05-25), `f4d1f701d2` (05-28), `5e4f086ffb` (05-29), `4fe7a99441`
(05-31), `500c67de30` (06-06). **None of these is the cause** — the concern retained `set_region`
and `default_url_options` throughout, and the ApplicationControllers retained their `before_action`
lines.

**Note on ordering:** `auth` received `set_region` on its ApplicationControllers in February,
_before_ `base` did in May. The idea that `auth` was left behind during a `base`-first rollout is
**disproven**.

---

## 10. Last Known Good / First Known Bad

**Fact**, verified by counting `skip_before_action :set_region` occurrences in each revision:

| Path (pre-rename)                                          | `f0cbba2b51^` | `f0cbba2b51` |
| ---------------------------------------------------------- | ------------- | ------------ |
| `app/controllers/sign/app/sign/in/entrances_controller.rb` | 0             | 1            |
| `app/controllers/sign/app/sign/up/entrances_controller.rb` | 0             | 1            |

- **Last known good: `f0cbba2b51^`** (parent of the commit below).
- **First known bad: `f0cbba2b51ca85e5e8e738fa20cdba71b7a06f98`, 2026-06-12 15:38:31 +0900.**
- **Still bad at the audit baseline `39b6cafbd`** (2026-08-13) — verified:

```
app/controllers/auth/app/sign/ins_controller.rb   HEAD:1  worktree:0
app/controllers/auth/app/sign/ups_controller.rb   HEAD:1  worktree:0
app/controllers/auth/com/sign/ins_controller.rb   HEAD:1  worktree:0
app/controllers/auth/com/sign/ups_controller.rb   HEAD:1  worktree:0
app/controllers/auth/org/sign/ins_controller.rb   HEAD:1  worktree:0
app/controllers/auth/org/sign/ups_controller.rb   HEAD:1  worktree:0
```

**Exposure window: 2026-06-12 → present, approximately two months.**

`git bisect` was **not** run. It was unnecessary — the boundary is a single-commit transition
verified directly by `git show` on both revisions — and it would have required a booting
application, which this environment does not provide.

For §5.2 (`palm`) and §5.3 (`RedirectOnlyController`) there is **no last-known-good**: `palm/app`
appears never to have had the mechanism, and `Auth::RedirectOnlyController` was created already
inheriting the bare root controller (`3c6c2e95e`, 2026-06-03). These are **latent gaps, not
regressions**. Distinguishing "never worked" from "regressed" for `palm` would need a full-history
walk that was not performed — **Unproven**.

---

## 11. Regression-Introducing Change

`f0cbba2b51`, diff on `sign/app/sign/in/entrances_controller.rb` (representative of all six):

```ruby
 class EntrancesController < ::Sign::App::SignInsController
   AUTHENTICATION_MODE = :guest
   declare_authentication_mode! :guest
+  skip_before_action :set_region, raise: false

   def show
-    if params[:login_challenge].present?
+    return normalize_to_acme_authorize! if params[:login_challenge].blank?
...
+  def normalize_to_acme_authorize!
+    url = initiate_oidc_session!(pt: sign_app_root_path(ri: params[:ri]), screen_hint: "signin")
+    redirect_to_oidc_authorization_url(url)
+  end
```

**Purpose of the change (Inference, from code adjacency only).** The skip was added in the **same
hunk** as `normalize_to_acme_authorize!`, which performs an unconditional OIDC redirect when
`login_challenge` is blank. The plausible motive is that `set_region`'s own redirect would preempt
the OIDC handoff — two `before_action`-driven redirects competing for the same request — so
`set_region` was disabled and the region was threaded manually instead.

**This is inference, not fact.** The commit message is literally `[CheckPoint] ..........` with no
body, and there is no ADR, issue, or code comment stating the intent. **Marked Unproven.**

**Why the manual threading did not compensate (Fact + Inference).** The replacement threads
`ri: params[:ri]` — the **raw, unvalidated** param — not `required_ri`
(`preference_global.rb:65-67`) and not `current_region_identifier` (`preference_global.rb:194-196`,
which routes through `RequestContextContract.normalize_region` and clamps to `jp`/`us`).
Consequently:

- a blank `ri` propagated as blank into the OIDC `pt`, and thence into every URL built downstream;
- an unrecognized `ri=xx` propagated **verbatim**, since the only validator on this path had just
  been removed.

So the change substituted a validated, surface-wide mechanism with an unvalidated, single-call-site
one — and did so on the two pages that funnel the entire credential ceremony.

---

## 12. Timeline of the Regression

| #      | Date                    | Commit                   | Event                                                                                                                                                                                                                                                                                  | Impact                                                               | Confidence                                |
| ------ | ----------------------- | ------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------- | ----------------------------------------- |
| T0     | 2026-01-11/13           | `d277886e4`, `b5c65d9e7` | `default_url_options` reworked; the "`ri` rides on every URL helper" mechanism is established, reading **params only**                                                                                                                                                                 | Creates the structural dependency of propagation on enforcement (§2) | Fact                                      |
| T1     | 2026-02-24              | `8426371e9`              | `auth/app` + `auth/org` ApplicationControllers gain `set_region`                                                                                                                                                                                                                       | `auth` correct at surface level                                      | Fact                                      |
| T2     | 2026-03-31              | `e2dc86edc`              | `auth/com` aligned                                                                                                                                                                                                                                                                     | All three `auth` editions correct                                    | Fact                                      |
| T3     | 2026-05-09              | `5716a1e2c`              | `adr/public-controller-base.md` added. `:20-21` names `skip_before_action :set_region, raise: false` as the fragile pattern; `:27`: _"`raise: false` hides the case where a previously-skipped callback was removed or renamed, so the endpoint quietly starts running new behavior."_ | **The failure mode is documented in advance**                        | Fact                                      |
| T4     | 2026-05-24              | —                        | That ADR is marked **"Status: Historical (superseded)"**. Its warning is retired along with its proposed `PublicController` hierarchy                                                                                                                                                  | The institutional memory of the hazard is filed away                 | Fact                                      |
| T5     | 2026-05-28              | `f4d1f701d`              | `base` ApplicationControllers gain `set_region` during the `Preference::Global` → `PreferenceGlobal` flattening                                                                                                                                                                        | `base` correct; note `base` is _later_ than `auth`, not earlier      | Fact                                      |
| T6     | 2026-06-03              | `3c6c2e95e`              | `auth/redirect_only_controller.rb` created inheriting the bare root `::ApplicationController`                                                                                                                                                                                          | Latent gap §5.3 introduced                                           | Fact                                      |
| **T7** | **2026-06-12**          | **`f0cbba2b51`**         | **The exact pattern the ADR warned about is reintroduced on six HTML entry controllers, 19 days after the ADR was superseded.** Bundled with `normalize_to_acme_authorize!` in a 36-file commit titled `[CheckPoint] ..........`                                                       | **Regression begins**                                                | Fact (the change); Inference (the motive) |
| T8     | 2026-06-12              | `f0cbba2b51`             | 10 test files touched, all modified, none added, none asserting region behavior                                                                                                                                                                                                        | Ships with zero guarding coverage                                    | Fact                                      |
| T9     | 2026-06-16              | `94a0b44e03`             | `entrances_controller.rb` → `{ins,ups}_controller.rb`. Skip carried forward verbatim; 9 test files updated, all mechanical path swaps                                                                                                                                                  | Provenance obscured; `--follow` now stops here                       | Fact                                      |
| T10    | 2026-06-27              | `3683d7aecb`             | Surface-wide `sign/` → `auth/`. Skip carried forward again                                                                                                                                                                                                                             | Provenance obscured a second time                                    | Fact                                      |
| T11    | 2026-06-12 → 2026-08-13 | —                        | CI green throughout. `base`-only `DOMAINS`, no auth region test in the tree, ApplicationController-level callback assertions all passing, `forbidden_rails_patterns_test` configured to ignore `:set_region`                                                                           | Two months of undetected breakage                                    | Fact                                      |
| T12    | ~2026-08                | uncommitted              | Discovered in real use. Working-tree fix removes all six skips and adds `test/integration/auth_region_contract_test.rb`                                                                                                                                                                | Fix in progress, not committed                                       | Fact                                      |

The shape of this timeline is the finding: **the hazard was correctly identified and documented at
T3, retired at T4, and realized at T7 nineteen days later.**

---

## 13. Root Cause Analysis

There is no single root cause. Four independent causes had to hold simultaneously.

### Direct cause

`skip_before_action :set_region, raise: false` on the six `auth` sign-in/sign-up controllers
(`f0cbba2b51`), replacing validated region normalization with a hand-threaded, unvalidated
`ri: params[:ri]` at one call site.

### Architectural cause — propagation depends on enforcement, with no fallback

`PreferenceGlobal#default_url_options` (`:69-73`) reads `requested_context`, which is params-only,
while `effective_context` (`:61-63`) resolves defaults → cookie → params. Had `default_url_options`
merged `effective_context` instead, a skipped `set_region` would have degraded to _"no redirect, but
URLs still carry the cookie/default region"_ rather than _"no region anywhere."_

**This is the single highest-leverage design fact in the report.** It is what converts one skipped
callback into surface-wide region loss. Whether the current behavior is deliberate — a redirect-only
canonicalization model — is **Unproven**; no ADR discusses the choice.

### Detection cause

Callback-chain assertions were placed on `ApplicationController` instead of on the effective chain
of the controllers that actually serve requests. That level is not where skips live.

### Process cause

A change that removes a request-context invariant was (a) sanctioned by
`docs/reference/forbidden-rails-methods.md:57-59`, (b) shielded from mechanical detection by
`raise: false`, (c) bundled into a 36-file commit with a contentless message, and (d) merged with no
new test. Each of these alone is survivable; together they remove every barrier.

---

## 14. Contributing Factors

1. **Structural asymmetry between surfaces.** The credential gateway exists only on `auth`, so
   `base` had no analogous controller and no analogous exposure. Reasoning by analogy from `base`
   was guaranteed to miss it.
2. **Sixteen sibling root controllers.** Every surface `ApplicationController` inherits
   `ActionController::Base` directly, so there is no place where the `ri` contract can be centrally
   guaranteed. This isolation is deliberate (`AGENTS.md:100`) and should not be undone — but it
   means the contract must be enforced by _test_, since it cannot be enforced by _inheritance_.
3. **Skip-list normalization.** 53 controllers skip `set_region` at HEAD. 52 are legitimate protocol
   endpoints. When a pattern appears 52 times legitimately, the 53rd is invisible in review.
4. **`raise: false` used reflexively.** Present on 52 of the 53 skips; carried into the six
   regressed files as boilerplate.
5. **Two renames across the regression window.** `git log --follow` on the current path reports only
   the 2026-06-16 rename and hides the 2026-06-12 origin. Any investigator using the obvious command
   reaches the wrong commit.
6. **Commit hygiene.** `[CheckPoint] ..........`, 36 files, no body. Seven commits in this history
   have a bare SHA as their entire subject. Neither review nor archaeology is practical against
   this.
7. **Documentation drift.** `docs/reference/forbidden-rails-methods.md:57` permits precisely what
   `adr/public-controller-base.md:20-27` warns against. Two authoritative documents in direct
   conflict, with the permissive one wired into the mechanical guard.
8. **Dead test files that advertise coverage.** The two `default_url_options_test.rb` stubs
   reference `Peak::App`/`Peak::Org`, namespaces removed long ago. They read, from a file listing,
   as coverage.
9. **Assertion style that cannot fail.** side/core/palm tests pass `ri:` on both sides of the
   assertion, testing string formatting rather than the mechanism.

---

## 15. Detection and Process Failures

Assessed against the specific hypotheses posed in the request:

| Hypothesis                                  | Verdict                     | Evidence                                                                                                                                                                  |
| ------------------------------------------- | --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Only `base` was tested                      | **Partly true**             | `preference_global_param_context_test.rb:13-23` is base-only. But `auth_region_contract_test.rb` covers auth — and is uncommitted, so it did not exist during the window. |
| Shared examples not applied to all surfaces | **True, stronger form**     | No shared-example mechanism exists. No test iterates the five families.                                                                                                   |
| Only helper units tested                    | **True and material**       | `preference/global_test.rb` runs against a bare harness; `sign_ups_helper_test.rb:42-47` stubs `default_url_options`.                                                     |
| Controller inheritance stubbed              | **False**                   | Integration tests issue real requests through the real stack.                                                                                                             |
| Real hosts not used                         | **Partly true**             | `config/environments/test.rb` has no `config.hosts`, so Host Authorization is inert in test. Not causal here.                                                             |
| Query string not asserted                   | **True for side/core/palm** | `test/integration/routes/*` contain zero `ri:` references.                                                                                                                |
| Only redirect path compared                 | **False**                   | `preference_global_param_context_test.rb:306-309` asserts on the full location including query.                                                                           |
| Matchers omitting `ri`                      | **True for side/core**      | `ri:` passed on both sides of the assertion.                                                                                                                              |
| Only response status checked                | **False**                   | Real content assertions exist.                                                                                                                                            |
| auth controllers outside coverage           | **True at the leaf level**  | ApplicationControllers are covered; the six leaves are not.                                                                                                               |
| Fixtures/helpers pre-added `ri`, hiding it  | **False — disproven**       | `test_helper.rb` sets no `ri` and no default host; `:14-21` documents the choice. No factories (`fixtures :all`, `:265`).                                                 |
| test vs prod configuration differ           | **True but not causal**     | No `config.hosts` and no controller `default_url_options` in test; the regression is host-independent.                                                                    |

**The dominant failure is none of the listed hypotheses.** It is that the invariant was asserted at
the wrong level of the class hierarchy, and that the one mechanical guard capable of catching it was
explicitly configured to exclude `:set_region`.

---

## 16. Proposed Regression Tests

**Proposal.** Not implemented. Thirteen copied test files are explicitly rejected: they would not
have caught this regression (the surfaces were correct; the leaves were not), and they reintroduce
the drift the repository's own doctrine warns against —
`test/support/preference_lifecycle_surfaces.rb:4-14`:

> the behavioral assertions … must be shared code exercised once per surface — not three copy-pasted
> test files … it supplies the class/constant that differs … never the assertions themselves.

### 16.1 State the invariant

Derived from `docs/architecture/preference.md:197` and `preference_global.rb`:

> Every controller that renders HTML on a routing target participating in RI preference routing MUST
> have `set_region` in its effective `_process_action_callbacks` chain, and MUST attach or preserve
> the effective `ri` per the common preference contract — unless it is listed as an explicit,
> documented exemption.

The clause that matters is **"effective chain"**, and **"exemption must be explicit"**.

### 16.2 Test 1 — effective-callback-chain invariant (highest value; catches this exact bug)

For every controller class rendering HTML on a participating target, assert `:set_region` is present
in the effective chain:

```ruby
klass._process_action_callbacks.select { it.kind == :before }.map(&:filter)
```

This walks the _resolved_ chain, so a `skip_before_action` on a leaf makes it fail — which the
existing ApplicationController-level tests cannot. It requires no HTTP request, is fast, and would
have failed on `f0cbba2b51` immediately.

Discover the class list by enumerating `Rails.application.routes.routes` and mapping each route to
its controller, so new controllers are covered automatically.

### 16.3 Test 2 — behavioral contract, once per surface

One parameterized suite covering cases A–I, driven by a registry (16.4), asserting on **generated**
URLs from requests that did **not** supply `ri` — never by passing `ri:` on both sides. Model it on
the two existing suites, unifying `preference_global_param_context_test.rb` and
`auth_region_contract_test.rb`, and extend `ENTRY_PATHS` beyond `/sign/in` and `/sign/up` to at
least one representative HTML entry point per target.

### 16.4 Test 3 — completeness guard (prevents the 14th-surface problem)

The question posed — _"a 14th surface is added and someone forgets to add it to the tests"_ — is
answered by inverting control: the test list must be **derived**, and every derived target must be
**classified**.

Compared options:

| Option                                                       | Catches a new surface? | Cost   | Assessment                                                                                                        |
| ------------------------------------------------------------ | ---------------------- | ------ | ----------------------------------------------------------------------------------------------------------------- |
| Hand-written surface list                                    | No                     | Low    | This is the status quo. Rejected.                                                                                 |
| Enumerate `Rails.application.routes.routes` host constraints | Yes, automatically     | Medium | **Recommended.** The router is the authority; a new `constraints host:` block appears without anyone remembering. |
| Central registry (`test/support/ri_routing_surfaces.rb`)     | Only if updated        | Low    | Useful as the _classification_ layer, not the discovery layer.                                                    |
| Both — enumerate, then require classification                | Yes                    | Medium | **Recommended combination.**                                                                                      |

Concretely: enumerate host-constrained targets from the router; require each to appear in
`test/support/ri_routing_surfaces.rb` as either `participating` or `exempt(reason:)`; fail the suite
on any unclassified target. A 14th surface then fails CI until someone consciously decides which it
is — and `palm` (§5.2) and `base/core {net,dev}` (§5.4) get their currently-undocumented status
written down as a side effect.

### 16.5 Test 4 — tighten the policy that permitted the change

Change `docs/reference/forbidden-rails-methods.md:57-59` from a blanket permission to a named,
reviewed allowlist, and extend `test/unit/security/forbidden_rails_patterns_test.rb` to cover
`:set_region` under the same `SENSITIVE_SKIP_ALLOWLIST` regime that already governs
`enforce_verification_if_required`. The 52 legitimate protocol endpoints are enumerable and stable,
so the allowlist is small and its diff is meaningful. Also ban bare `raise: false` on context
callbacks, per `adr/public-controller-base.md:27`.

This is the change that makes the class of failure mechanically impossible rather than merely
covered.

### 16.6 Housekeeping

Delete or implement `test/controllers/auth/{app,org}/default_url_options_test.rb`. Files that
promise coverage and deliver a comment about a namespace removed two renames ago are a hazard in
themselves.

---

## 17. Proposed Implementation Fix

**Implementation status (added after the audit, at the user's direction).** The audit itself changed
no production code. A follow-up implementation pass then landed the following, with tests executed:

| Change                                                         | File                                                                                                            | Closes              |
| -------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- | ------------------- |
| Region normalized instead of dropped on the hop to Base        | `app/controllers/concerns/sign_acme_authority_redirect.rb:22-31`                                                | §5.3                |
| Raw `params[:ri]` → `current_region_identifier`                | `auth/app/sign/{ins,ups}_controller.rb`, `palm/app/sign/outs_controller.rb`                                     | §11                 |
| Palm gains the RI mechanism; HTML controllers reparented to it | `palm/app/application_controller.rb`, `palm/app/roots_controller.rb`, `palm/app/sign/outs_controller.rb`        | §5.2                |
| Three-part contract guard                                      | `test/unit/security/ri_routing_contract_test.rb`                                                                | §16.2, §16.4, §16.5 |
| Region coverage for the redirect-only path and palm            | `test/controllers/auth/org/system_controller_test.rb`, `test/controllers/palm/app/sign/outs_controller_test.rb` | §7                  |

Verified: `ri_routing_contract_test` 3 runs / 0 failures; palm + auth redirect-only + inheritance +
title suites 33 runs / 0 failures; preference and auth sign suites 347 runs / 0 failures;
`forbidden_rails_patterns_test` green; RuboCop clean on all changed files. The completeness guard
was confirmed to fail on an unclassified surface, and the skip allowlist was observed failing on
exactly the six regressed sign controllers.

### 17.0.1 Completion pass, 2026-08-13 (full-suite run)

That pass verified narrow suites only. Running the whole suite afterwards showed the palm change had
broken three tests elsewhere, which is recorded here because it is the same failure mode the audit
is about: a change verified against the tests aimed at it, not against the tests aimed at everything
else.

| Change                                                                                                 | File                                                            | Cause                                                                                                                            |
| ------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| Palm root now redirects to add `ri`; test requests the canonical URL and expects region-carrying links | `test/integration/base_palm_auth_entrypoints_test.rb`           | Palm joined the RI contract (§5.2)                                                                                               |
| `palm/app` gains the surface-wide `default_web` rate limit                                             | `app/controllers/palm/app/application_controller.rb`            | `DefaultWebRateLimitTest` requires every `ApplicationController` including `RateLimit` to declare one; palm started including it |
| Cross-host redirect allowlist entries re-matched to the reformatted redirects                          | `test/security/invariants/forbidden_patterns_invariant_test.rb` | `params[:ri]` → `current_region_identifier` moved `allow_other_host: true` onto its own line                                     |

Two further items were closed in the same pass:

- **§16.2 — effective-callback-chain guard, the audit's highest-value recommendation.** Added as the
  fourth test in `test/unit/security/ri_routing_contract_test.rb`. It resolves the real controller
  classes for every routed controller on a participating target that owns an HTML template (121 of
  541 routed controllers) and asserts `:set_region` is in the resolved `before` chain. Tests 1–3
  scan source text and therefore cannot see a leaf that loses the mechanism through _inheritance_ —
  the `Auth::RedirectOnlyController` shape of §5.3. This one can. It found three such controllers,
  `base/{app,com,org}/preference/emails`, which inherit `BareController`; they are token-URL
  unsubscribe pages reached from an email, generate no regional link, and are pinned as a stated
  exemption rather than changed. Verified in both directions: reparenting `palm/app/roots` back to
  `BareController` makes it fail with `added: ["palm/app/roots"]`.
- **§16.5 — the policy that permitted the regression.** `docs/reference/forbidden-rails-methods.md`
  no longer grants blanket permission to skip `:set_region`; it now points at `RI_SKIP_ALLOWLIST`
  and its mechanical guard, and `.agents/harnesses/rules/project/regression-guards.mdc` documents
  that guard alongside the existing ones.

Unrelated defect found by the same full-suite run and fixed: `EmailVerificationFlowTest` set
`TurnstileVerifierStub.challenge_enabled = true` in `setup` and never reset it. The stub slots are
process-wide, so every later test in that worker got a stubbed Turnstile success — which is how
`Jit::Security::TurnstileVerifierTest` failed on one seed and passed on the next.

Full suite after the fixes: `bin/rails test` 10107 runs / 0 failures / 0 errors / 1 skip;
`pnpm test` 310 tests / 22 files passing.

Still open: the six skip removals in `auth/*/sign/{ins,ups}_controller.rb` remain **uncommitted**
worktree changes authored before this audit (§17.0); the `default_url_options` design question
(§17.2) is unresolved; §16.3 (unifying the two `ri` suites) and §16.6 (the two dead
`default_url_options_test.rb` stubs) are not done.

The remainder of this chapter is the original proposal.

### 17.0 Work already in the working tree — not authored by this audit

**Fact.** At the time of the audit the working tree already contained an uncommitted, partial fix.
It predates this investigation:

- `skip_before_action :set_region, raise: false` **removed from all six** of
  `app/controllers/auth/{app,com,org}/sign/{ins,ups}_controller.rb` (staged).
- New `app/controllers/concerns/regional_root_redirect.rb` and
  `app/controllers/concerns/root_sign_in_redirect.rb`, both documented as running ahead of
  `PreferenceGlobal#set_region`.
- New `app/values/regional_root_url_registry.rb` + `test/values/regional_root_url_registry_test.rb`.
- New `test/integration/auth_region_contract_test.rb` (status `AM`, **uncommitted**). Its header is
  the clearest statement of the bug anywhere in the repository:

  > The sign-in and sign-up pages used to skip `PreferenceGlobal#set_region`. A request without `ri`
  > therefore rendered with no region in the request context and produced region-less links, and a
  > request with an unrecognized `ri` propagated that unvalidated value into every generated URL.

  Its third test flags a **second, still-open** issue: the authorize endpoint legitimately skips
  region normalization, so `ri` must ride on the authorize URL itself — _"It used to be absent,
  which sent the whole ceremony — and every URL built from it inside the credential gateway — into
  the default region."_

**This work is uncommitted and therefore unprotected.** Committing it is the first action item.

### 17.1 Minimal fix

Commit the six skip removals. This closes §5.1. It is the entire fix for the reported bug.

Before committing, resolve the question the skip was presumably added to answer (§11): does
`set_region`'s redirect interfere with `normalize_to_acme_authorize!`'s OIDC handoff? If it does,
the correct resolution is to order the callbacks so region normalization completes first — the shape
the new `RootSignInRedirect` and `RegionalRootRedirect` concerns already adopt — **not** to skip the
callback. Any remaining hand-threaded region must use `current_region_identifier`
(`preference_global.rb:194-196`), never raw `params[:ri]`.

### 17.2 Structural fixes

- **§5.3 — `Auth::RedirectOnlyController`.** The file carries `# FIXME: I want to delete this file.`
  Deleting it and rehoming its nine actions onto the surface `ApplicationController` closes the gap
  with no new abstraction. If it must survive, it should inherit the surface
  `ApplicationController`, and `SignAcmeAuthorityRedirect#base_authority_query`
  (`sign_acme_authority_redirect.rb:22-29`) should fall back to `current_region_identifier` rather
  than dropping the region when `params[:ri]` is blank.
- **§5.2 — `palm/app`.** Decide and **document**. Either include `::PreferenceGlobal` +
  `set_region`, or record an explicit exemption in the registry from 16.4 with a stated reason. The
  status quo — an undocumented absence — is the worst of the three.
- **§13, architectural.** Evaluate whether `default_url_options` should merge `effective_context`
  rather than `requested_context`, so a missing enforcement degrades to the cookie/default region
  instead of to nothing. **This changes canonicalization behavior and needs an ADR** — it would mean
  generated URLs carry a region that the current URL does not, which may conflict with the
  redirect-canonicalization model. Raised as a question, not a recommendation.

### 17.3 Test fixes

§16.2 and §16.4 first — they are cheap, fast, and would have caught this. §16.5 next. §16.3 and
§16.6 after.

### 17.4 Sequencing

1. Commit the working-tree fix (17.0/17.1).
2. Add the effective-callback-chain test (16.2) — proves the fix and prevents recurrence.
3. Tighten the skip policy and its mechanical guard (16.5).
4. Classify every routing target; resolve `palm` and net/dev (16.4, 17.2).
5. Unify the two `ri` contract suites and broaden entry-point coverage (16.3).
6. Address `RedirectOnlyController` (17.2).
7. Open an ADR for the `default_url_options` question (17.2).

---

## 18. Architecture / Maintainability Recommendations

**On common-ization — the question posed directly.** _Does `auth` and `base` holding similar code
separately cause this failure?_ **No (Fact, §6.2).** `base` has no sign-in/sign-up controllers at
all. There was nothing to share and no duplicate to drift. Merging the two `ApplicationController`s
would not have prevented this regression, and it would violate the surface isolation `AGENTS.md:100`
requires. **Common-ization is not recommended.**

What _is_ duplicated is the wiring — twelve near-identical `include ::PreferenceGlobal` +
`before_action :set_region` pairs. But that duplication is **visible and asserted**; it is not where
the failure occurred. Replacing it with a mixin would move the declaration further from the
controller and make skips _less_ visible.

**The real lesson: when a contract cannot be enforced by inheritance, it must be enforced by test.**
The repository has consciously chosen sibling-root isolation. That choice is sound and should stand.
Its unavoidable cost is that cross-surface invariants have no structural home — so they need a
mechanical one. That is §16.2 and §16.4, and it is the single most valuable change proposed here.

Further recommendations:

1. **Reconcile the two conflicting documents.** `docs/reference/forbidden-rails-methods.md:57` and
   `adr/public-controller-base.md:20-27` give opposite guidance on the same line of code. The ADR is
   marked superseded, but its _warning_ about `raise: false` was never wrong and should be extracted
   into live documentation rather than retired with the hierarchy proposal it accompanied.
   Superseding an ADR should not silently retire its hazard analysis.
2. **Treat `skip_before_action` on context callbacks as a reviewed boundary change**, matching the
   existing treatment of authorization callbacks.
3. **Commit hygiene is a correctness control, not a style preference.** `[CheckPoint] ..........`
   across 36 files defeats review and archaeology simultaneously; recovering this cause required
   walking pre-rename paths by hand because the obvious command returns the wrong commit.
4. **Renames should be isolated commits.** The two renames after `f0cbba2b51` each carried the
   defect forward invisibly and each added a layer that `--follow` cannot see through.
5. **Delete dead test files.** A file named `default_url_options_test.rb` containing only a comment
   about a namespace removed two renames ago is worse than no file.

---

## 19. Risks and Open Questions

**Unverified — must be closed before relying on this report's behavioral claims:**

1. **No runtime verification was performed at all.** Cases A, B, C, G, I are unverified for all 13
   targets. The "Wired" rows in §4 are structural findings, not observed behavior.
2. **The scope of §5.1's impact is unmeasured.** That region-less URLs are generated follows from
   §2; _which_ links, and whether any downstream flow breaks outright versus silently defaulting to
   `jp`, is unknown.
3. **Case G (redirect loops) is unverified**, particularly the interaction between `set_region` and
   the new uncommitted `RegionalRootRedirect` / `RootSignInRedirect` concerns, which by their own
   comments run ahead of it.
4. **§5.3's real-world effect is unverified.** The double-hop is established statically; whether the
   region actually changes across the hop depends on cookie state on both hosts.

**Unproven:**

5. **The motive for `f0cbba2b51`.** Inferred from code adjacency only. No ADR, issue, or comment.
6. **Whether `f0cbba2b51` was reviewed.** No PR metadata retrieved. GitHub CLI was not used.
7. **Whether `palm/app`'s omission is intentional.** No documentation either way.
8. **Whether `palm/app` ever had the mechanism.** A full-history walk was not performed, so "never
   had it" versus "lost it" is undetermined.
9. **Whether the params-only `default_url_options` is a deliberate design choice.** No ADR discusses
   it.

**Risks:**

10. **The fix is uncommitted.** Six staged skip removals and a new contract test exist only in the
    working tree, alongside ~537 dirty paths. They can be lost.
11. **`auth_region_contract_test.rb` covers only `/sign/in` and `/sign/up`.** Committing it fixes
    the reported bug's coverage but leaves the rest of the `auth` surface, and all of
    side/core/palm, unguarded.
12. **The skip policy remains permissive.** Until §16.5 lands, an identical regression can be
    introduced tomorrow with full documentary sanction.
13. **Two further routing-target defects exist outside the 13** (`base/{net,dev}`, `core/{net,dev}`)
    and are unclassified.
14. Ancillary, noted in passing and outside this audit's scope: `production.rb:182-183` lists
    `palm_corporate` / `palm_staff` in `config.hosts`, but `config/routes/palm.rb` constrains only
    `palm_service`, and `lib/config_values_host_family_values.rb:215` uses `env.fetch` with no
    fallback — hosts admitted with no routes behind them, and a possible boot-time `KeyError`.
    Unverified.

---

## 20. Evidence Appendix

### A. Commands

```bash
# textconv workaround is REQUIRED; without it the walk aborts
git -c diff.rails_credentials.textconv=cat log --follow -p -- <path>
git -c diff.rails_credentials.textconv=cat log -S'skip_before_action :set_region' -- <path>

git rev-parse --short HEAD                                    # 39b6cafbd
git show f0cbba2b51^:app/controllers/sign/app/sign/in/entrances_controller.rb | grep -c 'skip_before_action :set_region'   # 0
git show f0cbba2b51:app/controllers/sign/app/sign/in/entrances_controller.rb  | grep -c 'skip_before_action :set_region'   # 1
git grep -c "skip_before_action :set_region" HEAD -- app/controllers          # 53 files
git show --stat f0cbba2b51
find app/controllers/base -path '*sign*' -name '*.rb'          # sign_outs only
```

### B. Key source locations

| Claim                                                | Location                                                                                                                   |
| ---------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| `ri` = region; allowed `jp`/`us`; default `jp`       | `app/services/request_context_contract.rb:5-10, 30, 100-103`                                                               |
| Preference defaults                                  | `app/models/concerns/preference_constants.rb:9-16`                                                                         |
| `default_url_options` merges params-only context     | `app/controllers/concerns/preference_global.rb:69-73`, with `requested_context` `:43-45`                                   |
| `effective_context` precedence                       | `app/controllers/concerns/preference_global.rb:61-63`                                                                      |
| `set_region` enforcement                             | `app/controllers/concerns/preference_global.rb:202-219`                                                                    |
| Redirect construction preserves query, no duplicates | `app/controllers/concerns/preference_global.rb:171-176, 230-242`                                                           |
| Redirect status 302/303                              | `app/controllers/concerns/preference_global.rb:178-180`                                                                    |
| Invalid values dropped, not clamped                  | `app/controllers/concerns/preference_global.rb:100-111, 119-121`                                                           |
| `current_region_identifier` normalizes               | `app/controllers/concerns/preference_global.rb:194-196`                                                                    |
| Normative spec                                       | `docs/architecture/preference.md:189-208`                                                                                  |
| Precedence ADR                                       | `adr/localization-preference-flow.md:37-41`                                                                                |
| The six skips                                        | `app/controllers/auth/{app,com,org}/sign/{ins,ups}_controller.rb:10`                                                       |
| Ceremony routes                                      | `config/routes/auth.rb:49-52`                                                                                              |
| `palm/app` has no mechanism                          | `app/controllers/palm/app/application_controller.rb:1-12`                                                                  |
| Root `ApplicationController` is bare                 | `app/controllers/application_controller.rb:4-13`                                                                           |
| `Auth::RedirectOnlyController` inherits it           | `app/controllers/auth/redirect_only_controller.rb:5-6`                                                                     |
| Its nine consumers                                   | `auth/org/{accounts,system,iam,billing,audit,configurations,support}_controller.rb:6`; `auth/app/billings_controller.rb:6` |
| Region dropped when `params[:ri]` blank              | `app/controllers/concerns/sign_acme_authority_redirect.rb:22-29`                                                           |
| Policy permitting the skip                           | `docs/reference/forbidden-rails-methods.md:57-59` (contrast `:53-56`)                                                      |
| ADR warning about `raise: false`                     | `adr/public-controller-base.md:20-21, 27, 139`; status line `:3`                                                           |
| Auth ApplicationController wiring                    | `app/controllers/auth/app/application_controller.rb:13, 75-77`                                                             |
| Base ApplicationController wiring                    | `app/controllers/base/app/application_controller.rb:12, 72-74`                                                             |
| `require_ri!` (stricter guard)                       | `app/controllers/concerns/sign_verification_common_base.rb:9-11`                                                           |

### C. Test evidence

| Claim                                                      | Location                                                                                         |
| ---------------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| base-only `DOMAINS`                                        | `test/integration/preference_global_param_context_test.rb:13-23`                                 |
| `ri` in `default_url_options` (base preference index only) | `…:96-107`                                                                                       |
| Existing query preserved on redirect                       | `…:297-309`                                                                                      |
| auth surfaces, two entry paths only                        | `test/integration/auth_region_contract_test.rb:14-20`                                            |
| Unit tests use a bare harness                              | `test/controllers/concerns/preference/global_test.rb:223-263`; `global_coverage_test.rb:161-165` |
| Helper test stubs `default_url_options`                    | `test/helpers/sign/org/sign_ups_helper_test.rb:42-47`                                            |
| `ri:` on both sides of assertion                           | `test/controllers/side/com/dashboards_controller_test.rb:25-28`                                  |
| Empty stub files                                           | `test/controllers/auth/{app,org}/default_url_options_test.rb`                                    |
| Shared-test doctrine, no routing axis                      | `test/support/preference_lifecycle_surfaces.rb:4-14, 32-66`                                      |
| No auto-injected `ri`, no default host                     | `test/test_helper.rb:14-21, 45-50, 265`                                                          |
| No `config.hosts` in test                                  | `config/environments/test.rb` (absent; contrast `production.rb:150-188`)                         |
| Evidence a shared support module was removed               | `test/controllers/concerns/dbsc_canonical_url_test.rb:70`                                        |

### D. Commit reference

| Hash                                       | Date                    | Role                                   |
| ------------------------------------------ | ----------------------- | -------------------------------------- |
| `39b6cafbd`                                | 2026-08-13              | Audit baseline                         |
| `f0cbba2b51ca85e5e8e738fa20cdba71b7a06f98` | 2026-06-12              | **Regression-introducing commit**      |
| `f0cbba2b51^`                              | 2026-06-12              | **Last known good**                    |
| `94a0b44e03`                               | 2026-06-16              | Rename 1 — obscures provenance         |
| `3683d7aecb`                               | 2026-06-27              | Rename 2 — obscures provenance         |
| `5716a1e2cf`                               | 2026-05-09              | ADR that predicted the failure mode    |
| `3c6c2e95e5`                               | 2026-06-03              | `Auth::RedirectOnlyController` created |
| `8426371e9c` / `e2dc86edc9`                | 2026-02-24 / 2026-03-31 | `auth` gains `set_region`              |
| `f4d1f701d2`                               | 2026-05-28              | `base` gains `set_region`              |

### E. Test results

**None.** No test was executed during this audit. `bin/rails` does not boot in the audit environment
(`config/application.rb:27` — `Missing required configuration: TRUSTED_PROXIES`), and the user
scoped the audit to static analysis. Every behavioral claim in this report is either static
inference from cited source or explicitly marked Unverified.
