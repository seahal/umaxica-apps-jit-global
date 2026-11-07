# frozen_string_literal: true

require "test_helper"

class PublicMethodContractValuesTest < ActiveSupport::TestCase
  test "a blank public identifier error names its record without substituting an internal id" do
    error = BlankPublicIdentifierError.new(record_class: Client)

    assert_equal "Client", error.record_class
    assert_equal "Client has a blank public_id and cannot be exposed to a client", error.message
  end

  test "resource lifecycle predicates distinguish active and inactive state in every family" do
    active = AuthorityResourceLifecycleStateValue::ACTIVE
    inactive = AuthorityResourceLifecycleStateValue::INACTIVE
    lifecycles = [AgentLifecycle, BureauLifecycle, EnterpriseLifecycle]

    lifecycles.each do |lifecycle_class|
      assert_predicate lifecycle_class.new(state: active), :active?
      assert_not_predicate lifecycle_class.new(state: inactive), :active?
    end
  end

  test "persisted owner cutover markers are readonly in each owner family" do
    [AgentAuthorityCutover, BureauAuthorityCutover, EnterpriseAuthorityCutover].each do |cutover_class|
      cutover = cutover_class.establish!

      assert_predicate cutover, :readonly?, cutover_class.name
    end
  end

  test "taxonomy assignment structural kinds follow their declared vocabulary kind" do
    single = Publishing::Info::App::RevisionSingleTaxonomyAssignment.new(
      vocabulary_kind: Publishing::TaxonomyKind::SINGLE_HIERARCHICAL,
    )
    multiple = Publishing::Info::App::RevisionMultipleTaxonomyAssignment.new(
      vocabulary_kind: Publishing::TaxonomyKind::MULTIPLE_ORDERED_FLAT,
    )

    assert_equal Publishing::TaxonomyKind::SINGLE_HIERARCHICAL, single.structural_kind.key
    assert_equal Publishing::TaxonomyKind::MULTIPLE_ORDERED_FLAT, multiple.structural_kind.key
  end

  test "publishing revision and version classes map back to their own entry family" do
    revision = Publishing::Info::App::EntryRevision.new
    version = Publishing::Info::App::EntryVersion.new

    assert_equal Publishing::Info::App::Entry, Publishing::ContentFamilies.entry_class_for_revision(revision)
    assert_equal Publishing::Info::App::Entry, Publishing::ContentFamilies.entry_class_for_version(version)
  end

  test "passkey result candidate initializes metadata as an empty object by default" do
    candidate = IdentityPasskeyCeremonyResultIssuer::Candidate.new(
      webauthn_id: "credential-id",
      public_key: "public-key",
      sign_count: 0,
      description: "Security key",
      transports: ["internal"],
    )

    assert_equal({}, candidate.metadata)
  end

  test "social ceremony grant exposes its validated expiry as UTC time" do
    now = Time.current.change(usec: 0)
    expires_at = now + 5.minutes
    issuer_id = IdentitySocialCeremonyContract.acme_issuer_id("app")
    attributes = {
      surface: "app",
      actor_ref: "actor-reference",
      session_ref: "session-reference",
      transaction_id: "transaction-reference",
      jti: SecureRandom.uuid,
      operation: "link",
      provider: "google",
      exp: expires_at.to_i,
    }
    payload = attributes.merge(
      IdentitySocialCeremonyGrant.default_claims(attributes, issuer_id:, now:),
    )
    grant = IdentitySocialCeremonyGrant.new(payload, issuer_id:, now:)

    assert_equal Time.zone.at(expires_at.to_i), grant.expires_at
  end

  test "identifier inventory result serializes its stable public shape" do
    connections = [{ name: "primary", tables: [] }]
    result = IdentifierContractInventoryQuery::Result.new(
      version: IdentifierContractInventoryQuery::VERSION,
      generated_at: "2026-11-06T00:00:00Z",
      connections: connections,
    )

    assert_equal(
      { version: IdentifierContractInventoryQuery::VERSION, generated_at: "2026-11-06T00:00:00Z", connections: },
      result.to_h,
    )
    assert_equal result.to_h, JSON.parse(result.to_json, symbolize_names: true)
  end

  test "inventory results serialize summary and details without changing their shape" do
    summary = { selection_complete: true, avatars_requested: 0 }
    details = []
    avatar_result = AvatarOwnershipTransitionInventoryQuery::Result.new(summary:, details:)
    group_result = AvatarGroupOwnershipTransitionInventoryQuery::Result.new(summary:, details:)
    backfill_result = AvatarConcreteOwnershipBackfillOperation::Result.new(summary:, details:)
    group_backfill_result = AvatarGroupConcreteOwnershipBackfillOperation::Result.new(summary:, details:)
    cutover_result = AvatarOwnershipCutoverOperation::Result.new(
      status: "established",
      summary:,
      inventory: avatar_result,
      group_inventory: group_result,
    )

    assert_predicate avatar_result, :selection_complete?
    assert_equal({ summary:, details: }, group_result.to_h)
    assert_equal({ summary:, details: }, backfill_result.to_h)
    assert_equal({ summary:, details: }, group_backfill_result.to_h)
    assert_equal(
      { status: "established", summary:, inventory: avatar_result.to_h, group_inventory: group_result.to_h },
      cutover_result.to_h,
    )
    assert_equal cutover_result.to_h, JSON.parse(cutover_result.to_json, symbolize_names: true)
    assert_equal({ summary:, details: }, JSON.parse(avatar_result.to_json, symbolize_names: true))
    assert_equal({ summary:, details: }, JSON.parse(group_result.to_json, symbolize_names: true))
    assert_equal({ summary:, details: }, JSON.parse(backfill_result.to_json, symbolize_names: true))
    assert_equal({ summary:, details: }, JSON.parse(group_backfill_result.to_json, symbolize_names: true))
  end

  test "published entries query returns an empty relation when locale is absent" do
    query = PublishingPublishedEntriesQuery.new(entry_class: Publishing::Info::App::Entry, locale: " ")

    assert_empty query.call
  end
end
