# frozen_string_literal: true

require "test_helper"

class AuthorityOwnerFamilyBackfillOperationTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    ClientIdentityState.ensure_defaults!
    ClientStatus.ensure_defaults!
    ClientVisibility.ensure_defaults!
  end

  test "applies a complete reviewed family atomically and replays idempotently" do
    first_owner = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    first_identity = ClientIdentity.create!(
      issuer: "https://id.example.test",
      subject: "family-backfill-first",
      audience: "acme_app",
      source_record_id: first_owner.id,
      status_id: ClientIdentityState::ACTIVE,
    )
    first_persona =
      I18n.with_locale(:en) do
        ClientPersona.create!(client_identity: first_identity, title: "First")
      end

    second_owner = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    second_identity = ClientIdentity.create!(
      issuer: "https://id.example.test",
      subject: "family-backfill-second",
      audience: "acme_app",
      source_record_id: second_owner.id,
      status_id: ClientIdentityState::ACTIVE,
    )
    second_persona =
      I18n.with_locale(:en) do
        ClientPersona.create!(client_identity: second_identity, title: "Second")
      end

    mappings = [
      {
        resource_public_id: first_persona.public_id,
        owner_public_id: first_owner.public_id,
        lifecycle_state: "active",
      },
      {
        resource_public_id: second_persona.public_id,
        owner_public_id: second_owner.public_id,
        lifecycle_state: "active",
      },
    ]

    first = AuthorityOwnerFamilyBackfillOperation.call(
      surface: :app,
      resource_kind: :client_persona,
      mappings:,
    )
    second = AuthorityOwnerFamilyBackfillOperation.call(
      surface: :app,
      resource_kind: :client_persona,
      mappings:,
    )

    assert_equal :applied, first.status
    assert_equal :already_applied, second.status
    assert_equal 2, first.results.length
    assert_equal [first_owner.id, second_owner.id],
                 [first_persona.reload.ownership.client_id, second_persona.reload.ownership.client_id]
    assert_equal ["active", "active"],
                 [first_persona.lifecycle.state, second_persona.lifecycle.state]
  end

  test "rolls back every family row when a later reviewed row is rejected" do
    first_owner = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    first_identity = ClientIdentity.create!(
      issuer: "https://id.example.test",
      subject: "family-backfill-rollback-first",
      audience: "acme_app",
      source_record_id: first_owner.id,
      status_id: ClientIdentityState::ACTIVE,
    )
    first_persona =
      I18n.with_locale(:en) do
        ClientPersona.create!(client_identity: first_identity, title: "First")
      end

    second_owner = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    second_identity = ClientIdentity.create!(
      issuer: "https://id.example.test",
      subject: "family-backfill-rollback-second",
      audience: "acme_app",
      source_record_id: second_owner.id,
      status_id: ClientIdentityState::ACTIVE,
    )
    second_persona =
      I18n.with_locale(:en) do
        ClientPersona.create!(client_identity: second_identity, title: "Second")
      end
    ClientPersonaLifecycle.create!(
      client_persona: second_persona,
      state: AuthorityResourceLifecycleStateValue::INACTIVE,
    )

    result = AuthorityOwnerFamilyBackfillOperation.call(
      surface: :app,
      resource_kind: :client_persona,
      mappings: [
        {
          resource_public_id: first_persona.public_id,
          owner_public_id: first_owner.public_id,
          lifecycle_state: "active",
        },
        {
          resource_public_id: second_persona.public_id,
          owner_public_id: second_owner.public_id,
          lifecycle_state: "active",
        },
      ],
    )

    assert_equal :manual_review, result.status
    assert_equal :lifecycle_conflict, result.reason
    assert_not ClientPersonaOwnership.exists?(client_persona_id: first_persona.id)
    assert_not ClientPersonaOwnership.exists?(client_persona_id: second_persona.id)
    assert_equal "inactive", second_persona.reload.lifecycle.state
  end

  test "rejects duplicate resources before applying any reviewed mapping" do
    owner = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    identity = ClientIdentity.create!(
      issuer: "https://id.example.test",
      subject: "family-backfill-duplicate",
      audience: "acme_app",
      source_record_id: owner.id,
      status_id: ClientIdentityState::ACTIVE,
    )
    persona = I18n.with_locale(:en) { ClientPersona.create!(client_identity: identity, title: "Duplicate") }
    mapping = {
      resource_public_id: persona.public_id,
      owner_public_id: owner.public_id,
      lifecycle_state: "active",
    }

    result = AuthorityOwnerFamilyBackfillOperation.call(
      surface: :app,
      resource_kind: :client_persona,
      mappings: [mapping, mapping.dup],
    )

    assert_equal :manual_review, result.status
    assert_equal :duplicate_resource_mapping, result.reason
    assert_not ClientPersonaOwnership.exists?(client_persona_id: persona.id)
    assert_not ClientPersonaLifecycle.exists?(client_persona_id: persona.id)
  end

  test "rejects a partial family mapping before applying any reviewed row" do
    first_owner = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    first_identity = ClientIdentity.create!(
      issuer: "https://id.example.test",
      subject: "family-backfill-partial-first",
      audience: "acme_app",
      source_record_id: first_owner.id,
      status_id: ClientIdentityState::ACTIVE,
    )
    first_persona =
      I18n.with_locale(:en) do
        ClientPersona.create!(client_identity: first_identity, title: "First")
      end

    second_owner = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    second_identity = ClientIdentity.create!(
      issuer: "https://id.example.test",
      subject: "family-backfill-partial-second",
      audience: "acme_app",
      source_record_id: second_owner.id,
      status_id: ClientIdentityState::ACTIVE,
    )
    second_persona =
      I18n.with_locale(:en) do
        ClientPersona.create!(client_identity: second_identity, title: "Second")
      end

    result = AuthorityOwnerFamilyBackfillOperation.call(
      surface: :app,
      resource_kind: :client_persona,
      mappings: [
        {
          resource_public_id: first_persona.public_id,
          owner_public_id: first_owner.public_id,
          lifecycle_state: "active",
        },
      ],
    )

    assert_equal :manual_review, result.status
    assert_equal :family_mapping_incomplete, result.reason
    assert_not ClientPersonaOwnership.exists?(client_persona_id: first_persona.id)
    assert_not ClientPersonaLifecycle.exists?(client_persona_id: first_persona.id)
    assert_not ClientPersonaOwnership.exists?(client_persona_id: second_persona.id)
    assert_not ClientPersonaLifecycle.exists?(client_persona_id: second_persona.id)
  end

  test "rejects an empty reviewed mapping instead of treating it as cutover evidence" do
    result = AuthorityOwnerFamilyBackfillOperation.call(
      surface: :app,
      resource_kind: :client_persona,
      mappings: [],
    )

    assert_equal :manual_review, result.status
    assert_equal :empty_reviewed_mapping, result.reason
  end
end
