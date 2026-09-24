# frozen_string_literal: true

require "test_helper"

class AuthorityResourceLifecycleBackfillOperationTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    ClientIdentityState.ensure_defaults!
    ClientStatus.ensure_defaults!
    ClientVisibility.ensure_defaults!

    @client = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    @identity = ClientIdentity.create!(
      issuer: "https://id.example.test",
      subject: "lifecycle-backfill-#{SecureRandom.hex(6)}",
      audience: "acme_app",
      source_record_id: @client.id,
      status_id: ClientIdentityState::ACTIVE,
    )
    @persona = ClientPersona.create!(client_identity: @identity, title: "Lifecycle")
  end

  test "requires an explicit reviewed lifecycle state" do
    result = AuthorityResourceLifecycleBackfillOperation.call(
      surface: :app,
      resource_kind: :client_persona,
      resource_public_id: @persona.public_id,
    )

    assert_equal :manual_review, result.status
    assert_equal :explicit_lifecycle_state_required, result.reason
    assert_nil @persona.reload.lifecycle
  end

  test "creates an explicit lifecycle row and is idempotent" do
    first = AuthorityResourceLifecycleBackfillOperation.call(
      surface: :app,
      resource_kind: :client_persona,
      resource_public_id: @persona.public_id,
      state: AuthorityResourceLifecycleStateValue::ACTIVE,
    )
    second = AuthorityResourceLifecycleBackfillOperation.call(
      surface: :app,
      resource_kind: :client_persona,
      resource_public_id: @persona.public_id,
      state: AuthorityResourceLifecycleStateValue::ACTIVE,
    )

    assert_equal :applied, first.status
    assert_equal :already_applied, second.status
    assert_equal AuthorityResourceLifecycleStateValue::ACTIVE, @persona.reload.lifecycle.state
  end

  test "does not replace an existing lifecycle state" do
    ClientPersonaLifecycle.create!(
      client_persona: @persona,
      state: AuthorityResourceLifecycleStateValue::RETAINED,
    )

    assert_raises(AuthorityResourceLifecycleBackfillOperation::LifecycleConflict) do
      AuthorityResourceLifecycleBackfillOperation.call(
        surface: :app,
        resource_kind: :client_persona,
        resource_public_id: @persona.public_id,
        state: AuthorityResourceLifecycleStateValue::ACTIVE,
      )
    end

    assert_equal AuthorityResourceLifecycleStateValue::RETAINED, @persona.reload.lifecycle.state
  end

  test "rejects an unsupported lifecycle state before writing" do
    assert_raises(ArgumentError) do
      AuthorityResourceLifecycleBackfillOperation.call(
        surface: :app,
        resource_kind: :client_persona,
        resource_public_id: @persona.public_id,
        state: "unknown",
      )
    end

    assert_nil @persona.reload.lifecycle
  end
end
