# frozen_string_literal: true

require "test_helper"

class AuthorityOwnerCutoverGuardTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    ClientIdentityState.ensure_defaults!
    ClientStatus.ensure_defaults!
    ClientVisibility.ensure_defaults!
  end

  test "does not authorize a family cutover while the resource lifecycle row is missing" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    identity = ClientIdentity.create!(
      issuer: "https://id.example.test",
      subject: "cutover-gate-client",
      audience: "acme_app",
      source_record_id: client.id,
      status_id: ClientIdentityState::ACTIVE,
    )
    persona = I18n.with_locale(:en) { ClientPersona.create!(client_identity: identity, title: "Cutover") }
    ClientPersonaOwnership.create!(client_persona: persona, client:, ownership_revision: 0)

    result = AuthorityOwnerCutoverGuard.call(surface: :app, resource_kind: :client_persona)

    assert_not result.ready?
    assert_equal :unresolved_resource_lifecycle, result.blocking_reasons.fetch(:resource_lifecycle)
    assert_equal 1, result.resource_count
    assert_equal 1, result.authoritative_owner_count
    assert_equal :missing, result.unresolved_resources.first.fetch(:resource_lifecycle_classification)
  end

  test "authorizes a family cutover only when owner and resource lifecycle are both eligible" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    identity = ClientIdentity.create!(
      issuer: "https://id.example.test",
      subject: "cutover-gate-ready-client",
      audience: "acme_app",
      source_record_id: client.id,
      status_id: ClientIdentityState::ACTIVE,
    )
    persona = I18n.with_locale(:en) { ClientPersona.create!(client_identity: identity, title: "Ready") }
    ClientPersonaLifecycle.create!(
      client_persona: persona,
      state: AuthorityResourceLifecycleStateValue::ACTIVE,
    )
    ClientPersonaOwnership.create!(client_persona: persona, client:, ownership_revision: 0)

    result = AuthorityOwnerCutoverGuard.call(surface: :app, resource_kind: :client_persona)

    assert_predicate result, :ready?
    assert_equal 1, result.resource_count
    assert_equal 1, result.authoritative_owner_count
    assert_empty result.unresolved_resources
    assert_empty result.blocking_reasons
  end

  test "does not authorize an empty family as proof that cutover is complete" do
    result = AuthorityOwnerCutoverGuard.call(surface: :app, resource_kind: :client_persona)

    assert_not result.ready?
    assert_equal 0, result.resource_count
    assert_equal [:empty_resource_family], result.blocking_reasons.fetch(:ownership)
    assert_empty result.unresolved_resources
  end

  test "keeps a family unresolved when one resource is ready and another is not" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    ready_identity = ClientIdentity.create!(
      issuer: "https://id.example.test",
      subject: "cutover-gate-mixed-ready-client",
      audience: "acme_app",
      source_record_id: client.id,
      status_id: ClientIdentityState::ACTIVE,
    )
    ready_persona =
      I18n.with_locale(:en) do
        ClientPersona.create!(client_identity: ready_identity, title: "Ready")
      end
    ClientPersonaLifecycle.create!(
      client_persona: ready_persona,
      state: AuthorityResourceLifecycleStateValue::ACTIVE,
    )
    ClientPersonaOwnership.create!(client_persona: ready_persona, client:, ownership_revision: 0)

    unresolved_persona = ClientPersona.create!(
      client_identity: client_identity_for_missing_principal,
      title: "Unresolved",
    )

    result = AuthorityOwnerCutoverGuard.call(surface: :app, resource_kind: :client_persona)

    assert_not_predicate result, :ready?
    assert_equal 2, result.resource_count
    assert_equal 1, result.authoritative_owner_count
    assert_equal [unresolved_persona.public_id],
                 result.unresolved_resources.map { |resource| resource.fetch(:resource_public_id) }
  end

  test "does not authorize a family cutover with an unresolved owner candidate" do
    identity = ClientIdentity.create!(
      issuer: "https://id.example.test",
      subject: "cutover-gate-missing-principal",
      audience: "acme_app",
      source_record_id: 9_999_999,
      status_id: ClientIdentityState::ACTIVE,
    )
    persona = I18n.with_locale(:en) { ClientPersona.create!(client_identity: identity, title: "Unresolved") }

    result = AuthorityOwnerCutoverGuard.call(surface: :app, resource_kind: :client_persona)

    assert_not result.ready?
    assert_equal 1, result.unresolved_count
    assert_includes result.blocking_reasons.fetch(:ownership), :missing_principal
    assert_equal persona.public_id, result.unresolved_resources.first.fetch(:resource_public_id)
  end

  test "does not treat an ineligible authoritative owner as cutover-ready" do
    client = Client.create!(status_id: ClientStatus::INACTIVE, visibility_id: ClientVisibility::USER)
    identity = ClientIdentity.create!(
      issuer: "https://id.example.test",
      subject: "cutover-gate-inactive-owner",
      audience: "acme_app",
      source_record_id: client.id,
      status_id: ClientIdentityState::ACTIVE,
    )
    persona = I18n.with_locale(:en) { ClientPersona.create!(client_identity: identity, title: "Ineligible") }
    ClientPersonaOwnership.create!(client_persona: persona, client:, ownership_revision: 0)

    result = AuthorityOwnerCutoverGuard.call(surface: :app, resource_kind: :client_persona)

    assert_not result.ready?
    detail = result.unresolved_resources.fetch(0)

    assert_equal :inactive_principal, detail.fetch(:authoritative_owner_classification)
    assert_not detail.fetch(:authoritative_owner_eligible)
    assert_equal :ineligible_authoritative_owner, result.blocking_reasons.fetch(:ownership).fetch(0)
  end

  test "does not require an owner to authorize an explicitly inactive resource" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    identity = ClientIdentity.create!(
      issuer: "https://id.example.test",
      subject: "cutover-gate-inactive-resource",
      audience: "acme_app",
      source_record_id: client.id,
      status_id: ClientIdentityState::ACTIVE,
    )
    persona = I18n.with_locale(:en) { ClientPersona.create!(client_identity: identity, title: "Inactive") }
    ClientPersonaLifecycle.create!(
      client_persona: persona,
      state: AuthorityResourceLifecycleStateValue::INACTIVE,
    )
    ClientPersonaOwnership.create!(client_persona: persona, client:, ownership_revision: 0)

    result = AuthorityOwnerCutoverGuard.call(surface: :app, resource_kind: :client_persona)

    assert_predicate result, :ready?
    assert_empty result.unresolved_resources
    assert_empty result.blocking_reasons
  end

  test "does not require an owner for a discarded resource with explicit lifecycle state" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    identity = ClientIdentity.create!(
      issuer: "https://id.example.test",
      subject: "cutover-gate-discarded-resource",
      audience: "acme_app",
      source_record_id: client.id,
      status_id: ClientIdentityState::ACTIVE,
    )
    persona = I18n.with_locale(:en) { ClientPersona.create!(client_identity: identity, title: "Discarded") }
    ClientPersonaLifecycle.create!(
      client_persona: persona,
      state: AuthorityResourceLifecycleStateValue::DISCARDED,
    )

    result = AuthorityOwnerCutoverGuard.call(surface: :app, resource_kind: :client_persona)

    assert_predicate result, :ready?
    assert_empty result.unresolved_resources
    assert_empty result.blocking_reasons
  end

  private

  def client_identity_for_missing_principal
    ClientIdentity.create!(
      issuer: "https://id.example.test",
      subject: "cutover-gate-mixed-missing-principal",
      audience: "acme_app",
      source_record_id: 9_999_999,
      status_id: ClientIdentityState::ACTIVE,
    )
  end
end
