# Publishing CMS Lifecycle and Authentication Implementation Notes

## Context

- Original plan/spec: conversation request to close the gaps found in the 2026-09-06 CMS audit -- no
  publish path, no authentication or authorization, no operator provenance, no entry creation, no
  archive, and an unbounded management index.
- Related decisions/docs/plans: `notes/implementation/2026-09-04-publishing-management-ui.md` (which
  recorded the unauthenticated alpha posture and named this follow-up),
  `docs/architecture/publishing-persistence.md`, `docs/security/public-entrypoints.md`,
  `adr/application-logging-boundary.md`, `db/migration_support/publishing_schema.rb`.
- Implementation date: 2026-09-06.

## Decisions Made During Implementation

- Decision: the twelve entries controllers now inherit `Base::Org::ApplicationController` with
  `AUTHENTICATION_MODE = :private` and `before_action :authenticate_operator!`.
  - Why: they read and write unpublished content -- drafts never published, bodies of archived
    entries, the revision history behind a live page. `project/controller-inheritance.mdc` names a
    surface-local `ApplicationController` as the parent for authentication-aware endpoints; this is
    not a normalization of `BareController`, it is a move off it.
  - Alternatives considered: keeping `BareController` and relying on Cloudflare Access. Rejected:
    that gate is a deployment fact this repository cannot verify, and every comparable staff area
    (`accounts`, `audit`, `iam`, `support`) is `:private`.
  - Follow-up needed: the CMS pages now require the `ri` region parameter like every other Base.Org
    page, because the full lifecycle runs. `url_for` carries it, so generated hrefs are unaffected.

- Decision: `PublishingEntryPolicy` answers with `user.is_a?(Operator) && user.active?`.
  - Why: `active?` is the predicate `AuthenticationOperator#active_operator?` already uses. A
    withdrawn, closing, suspended, or terminated operator keeps a valid session until it expires;
    publishing with it would put content in front of readers on the authority of an account that is
    no longer in force.
  - Alternatives considered: per-cell policies, or the `has_role?` helpers on `ApplicationPolicy`.
    Rejected: cell separation is already enforced by routing and by the per-controller
    `ENTRY_CLASS`, and no operator role data exists to key an editor/publisher split on. When roles
    arrive, this policy is the one place that changes.
  - Follow-up needed: an editor/publisher distinction, if the product wants one.

- Decision: publishing and archiving are nested resources (`publications`, `archive`), not verbs.
  - Why: `generic/routing.mdc` forbids `publish`, `unpublish`, `archive`, and `restore` as
    controller actions and asks for a noun resource. A publication is a real row with its own
    lifecycle, and an entry has exactly one archive state, so plural and singular resources
    respectively. Nesting is expressed with `scope module: :entries`, a pre-approved wrapper.
  - Alternatives considered: flat `publications` controllers alongside `entries`. Rejected: the URL
    and the controller namespace should agree.

- Decision: `EndPublicationOperation` decides between cancelling and terminating from the row, not
  from the caller.
  - Why: `chk_<cell>_pub_cancel` requires `cancelled_at < effective_from` and `chk_<cell>_pub_term`
    requires `terminated_at >= effective_from` with `effective_until = terminated_at`. The database
    has already decided which ending is legal for a given window; a caller-supplied mode could only
    disagree with it.
  - Follow-up needed: none.

- Decision: a new migration adds `archived_by_operator_public_id` to the twelve entries tables and
  `ended_by_operator_public_id` to the twelve publications tables.
  - Why: revisions, versions, and publications already carry `created_by_operator_public_id`, so
    every appearance of content named its author. The two transitions that make content _disappear_
    named nobody, and `adr/application-logging-boundary.md` forbids using logs as the authoritative
    record for that.
  - Alternatives considered: separate cancelled-by and terminated-by columns. Rejected: which ending
    applies is already decided by the two check constraints; the operator is the same fact either
    way.
  - Follow-up needed: `development_publishing_db` needs `bin/rails db:migrate:publishing` (or the
    reset the 2026-09-05 evidence already calls for).

- Decision: `PublishEntryForm` parses `effective_from` with `Time.zone.iso8601`, not
  `Time.zone.parse`.
  - Why: `Time.zone.parse("next tuesday-ish")` returns a time. A publication window opened at a
    moment nobody chose is worse than a rejected form. The CMS field is `datetime-local`, whose
    value is already ISO 8601. This was found by a test that expected a rejection and got a
    publication.

- Decision: the management index uses offset paging, while the public read path keeps its cursor.
  - Why: this list is ordered by `updated_at`, which moves under the reader as entries are edited,
    so a cursor would claim a stability the ordering does not have.

- Decision: archiving a published entry is refused rather than performed.
  - Why: the public read path filters `archived_at IS NULL`, so archiving alone would drop a live
    URL while an active publication row still claimed the entry was published -- two answers to one
    question. The operator ends the publication first, which is the order a reader sees.

## Deviations From Plan

- Change: taxonomy assignment editing, vocabulary and term management, and media upload were not
  implemented.
  - Why: each is a feature of its own rather than a gap in this one. Taxonomy terms need a term CRUD
    surface before an assignment picker has anything to pick; media needs a Shrine uploader, storage
    configuration, and a decision about direct-to-S3 uploads that is not verifiable from this
    container. Revisions still carry their taxonomy and media forward unchanged, so nothing
    regressed.
  - Risk: the CMS can create, revise, publish, schedule, unpublish, and archive content, but cannot
    classify it or attach an image. Content created here inherits no taxonomy, so it is invisible to
    the category and tag filters on the public read path.
  - Follow-up: promote both into the planning system as their own tasks.

- Change: `PUBLIC_PUBLISHING_CMS` was removed from `docs/security/public-entrypoints.md` and from
  `test/unit/security/public_entrypoint_inventory_test.rb`.
  - Why: the category described routes that are no longer public. Leaving it would have made the
    inventory test fail on its own "private routes must not match public categories" assertion.
  - Risk: none; the routes are now covered by the document's default rule.

## Review Notes

- Tests run: the full Ruby suite; `pnpm test`; `pnpm run format`, `lint`, `typecheck`, `deadcode`;
  RuboCop over every changed Ruby file. Results are recorded in
  `evidence/2026-09-06-publishing-cms-lifecycle.md`.
- Tests not run: Playwright (`pnpm run test:e2e`), which needs a running application; the
  `openapi:*` checks, which cover the public content API this change does not touch.
- Documentation promotion needed: the publish/schedule/unpublish/archive lifecycle belongs in
  `docs/architecture/publishing-persistence.md` once it settles.
