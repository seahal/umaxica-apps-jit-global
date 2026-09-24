# frozen_string_literal: true

require "test_helper"

class AuthorityOwnerDirectBindingBackfillOperationTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    ClientIdentityState.ensure_defaults!
    ClientStatus.ensure_defaults!
    ClientVisibility.ensure_defaults!
    VisitorStatus.ensure_defaults!
    VisitorVisibility.ensure_defaults!
    OperatorStatus.ensure_defaults!
    OperatorVisibility.ensure_defaults!
  end

  test "refuses to backfill before the authority schema is applied" do
    result =
      AuthorityOwnerMigrationInventory.stub(:authority_schema_state, :not_applied) do
        AuthorityOwnerDirectBindingBackfillOperation.call(
          surface: :app,
          resource_kind: :client_persona,
          resource_public_id: "not-looked-up",
          owner_public_id: "not-looked-up",
        )
      end

    assert_equal :manual_review, result.status
    assert_equal :authority_schema_not_applied, result.reason
  end

  test "does not promote a legacy identity binding without an explicit reviewed owner" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    identity = ClientIdentity.create!(
      issuer: "https://id.example.test",
      subject: "direct-backfill-client",
      audience: "acme_app",
      source_record_id: client.id,
      status_id: ClientIdentityState::ACTIVE,
    )
    persona =
      I18n.with_locale(:en) do
        ClientPersona.create!(client_identity: identity, title: "DirectOwn")
      end

    result = AuthorityOwnerDirectBindingBackfillOperation.call(
      surface: :app,
      resource_kind: :client_persona,
      resource_public_id: persona.public_id,
    )

    assert_equal :manual_review, result.status
    assert_equal :explicit_owner_required, result.reason
    assert_not ClientPersonaOwnership.exists?(client_persona_id: persona.id)
  end

  test "backfills one explicitly reviewed direct identity candidate and is idempotent" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    identity = ClientIdentity.create!(
      issuer: "https://id.example.test",
      subject: "direct-backfill-client-reviewed",
      audience: "acme_app",
      source_record_id: client.id,
      status_id: ClientIdentityState::ACTIVE,
    )
    persona =
      I18n.with_locale(:en) do
        ClientPersona.create!(client_identity: identity, title: "Reviewed")
      end

    first = AuthorityOwnerDirectBindingBackfillOperation.call(
      surface: :app,
      resource_kind: :client_persona,
      resource_public_id: persona.public_id,
      owner_public_id: client.public_id,
    )
    second = AuthorityOwnerDirectBindingBackfillOperation.call(
      surface: :app,
      resource_kind: :client_persona,
      resource_public_id: persona.public_id,
      owner_public_id: client.public_id,
    )

    assert_equal :applied, first.status
    assert_equal client.public_id, first.owner_public_id
    assert_equal :already_applied, second.status
    assert_equal 1, ClientPersonaOwnership.where(client_persona_id: persona.id).count
    assert_equal client.id, persona.reload.ownership.client_id

    detail =
      AuthorityOwnerMigrationInventory.call.details.find do |entry|
        entry.fetch(:resource_kind) == :client_persona &&
          entry.fetch(:resource_public_id) == persona.public_id
      end

    assert_equal :ineligible_authoritative_resource, detail.fetch(:classification)
    assert_equal client.public_id, detail.fetch(:authoritative_owner_public_id)
    assert detail.fetch(:source_is_authoritative_owner)
  end

  test "does not backfill an inactive principal" do
    client = Client.create!(status_id: ClientStatus::INACTIVE, visibility_id: ClientVisibility::USER)
    identity = ClientIdentity.create!(
      issuer: "https://id.example.test",
      subject: "inactive-backfill-client",
      audience: "acme_app",
      source_record_id: client.id,
      status_id: ClientIdentityState::ACTIVE,
    )
    persona =
      I18n.with_locale(:en) do
        ClientPersona.create!(client_identity: identity, title: "Inactive")
      end

    result = AuthorityOwnerDirectBindingBackfillOperation.call(
      surface: :app,
      resource_kind: :client_persona,
      resource_public_id: persona.public_id,
      owner_public_id: client.public_id,
    )

    assert_equal :manual_review, result.status
    assert_equal :inactive_principal, result.reason
    assert_not ClientPersonaOwnership.exists?(client_persona_id: persona.id)
  end

  test "does not backfill a suspended principal" do
    client = Client.create!(
      status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
      access_state: AdministrativeAccessLockable::ACCESS_STATE_ADMIN_LOCKED,
      admin_locked_at: Time.current,
      # This cross-surface audit reference is intentionally not a local FK. The
      # backfill contract only needs a present lock authority to classify the
      # principal as suspended.
      admin_locked_by_operator_id: 1,
      admin_locked_reason_code: "security_incident",
    )
    identity = ClientIdentity.create!(
      issuer: "https://id.example.test",
      subject: "suspended-backfill-client",
      audience: "acme_app",
      source_record_id: client.id,
      status_id: ClientIdentityState::ACTIVE,
    )
    persona = I18n.with_locale(:en) { ClientPersona.create!(client_identity: identity, title: "Suspended") }

    result = AuthorityOwnerDirectBindingBackfillOperation.call(
      surface: :app,
      resource_kind: :client_persona,
      resource_public_id: persona.public_id,
      owner_public_id: client.public_id,
    )

    assert_equal :manual_review, result.status
    assert_equal :suspended_principal, result.reason
    assert_not ClientPersonaOwnership.exists?(client_persona_id: persona.id)
  end

  test "does not infer ownership from a collective membership" do
    enterprise =
      I18n.with_locale(:en) do
        Enterprise.create!(name: "Legacy Enterprise", title: "Legacy")
      end

    result = AuthorityOwnerDirectBindingBackfillOperation.call(
      surface: :app,
      resource_kind: :enterprise,
      resource_public_id: enterprise.public_id,
    )

    assert_equal :manual_review, result.status
    assert_equal :membership_not_ownership, result.reason
    assert_not EnterpriseOwnership.exists?(enterprise_id: enterprise.id)
  end

  test "accepts an explicit reviewed owner for an organization without inferring membership" do
    owner = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    enterprise = I18n.with_locale(:en) { Enterprise.create!(name: "Reviewed Enterprise", title: "Reviewed") }

    result = AuthorityOwnerDirectBindingBackfillOperation.call(
      surface: :app,
      resource_kind: :enterprise,
      resource_public_id: enterprise.public_id,
      owner_public_id: owner.public_id,
    )

    assert_equal :applied, result.status
    assert_equal owner.public_id, result.owner_public_id
    assert_equal owner.id, enterprise.reload.ownership.client_id
  end

  test "rejects an explicit owner from another surface" do
    visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
    enterprise = I18n.with_locale(:en) { Enterprise.create!(name: "Cross Surface", title: "Cross") }

    result = AuthorityOwnerDirectBindingBackfillOperation.call(
      surface: :app,
      resource_kind: :enterprise,
      resource_public_id: enterprise.public_id,
      owner_public_id: visitor.public_id,
    )

    assert_equal :manual_review, result.status
    assert_equal :cross_surface_owner_candidate, result.reason
    assert_not EnterpriseOwnership.exists?(enterprise_id: enterprise.id)
  end

  test "rejects an owner identifier that collides across principal surfaces" do
    shared_public_id = "cross-surface-owner"
    Client.create!(
      public_id: shared_public_id,
      status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    Visitor.create!(
      public_id: shared_public_id,
      status_id: VisitorStatus::ACTIVE,
      visibility_id: VisitorVisibility::VISITOR,
    )
    enterprise = I18n.with_locale(:en) { Enterprise.create!(name: "Collision", title: "Collision") }

    result = AuthorityOwnerDirectBindingBackfillOperation.call(
      surface: :app,
      resource_kind: :enterprise,
      resource_public_id: enterprise.public_id,
      owner_public_id: shared_public_id,
    )

    assert_equal :manual_review, result.status
    assert_equal :cross_surface_owner_candidate, result.reason
    assert_not EnterpriseOwnership.exists?(enterprise_id: enterprise.id)
  end

  test "rejects a conflicting explicit owner instead of replacing it" do
    owner = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    conflicting_owner = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    identity = ClientIdentity.create!(
      issuer: "https://id.example.test",
      subject: "conflict-backfill-client",
      audience: "acme_app",
      source_record_id: owner.id,
      status_id: ClientIdentityState::ACTIVE,
    )
    persona =
      I18n.with_locale(:en) do
        ClientPersona.create!(client_identity: identity, title: "Conflict")
      end
    ClientPersonaOwnership.create!(client_persona: persona, client: conflicting_owner, ownership_revision: 0)

    error =
      assert_raises(AuthorityOwnerDirectBindingBackfillOperation::OwnershipConflict) do
        AuthorityOwnerDirectBindingBackfillOperation.call(
          surface: :app,
          resource_kind: :client_persona,
          resource_public_id: persona.public_id,
          owner_public_id: owner.public_id,
        )
      end

    assert_match(/already has a different explicit owner/, error.message)
    assert_equal conflicting_owner.id, persona.reload.ownership.client_id
  end
end
