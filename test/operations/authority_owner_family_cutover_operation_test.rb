# frozen_string_literal: true

require "test_helper"

class AuthorityOwnerFamilyCutoverOperationTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    ClientIdentityState.ensure_defaults!
    ClientStatus.ensure_defaults!
    ClientVisibility.ensure_defaults!
  end

  test "establishes one family marker only after every resource is ready" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    identity = ClientIdentity.create!(
      issuer: "https://id.example.test",
      subject: "cutover-operation-ready",
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

    result = AuthorityOwnerFamilyCutoverOperation.call(
      surface: :app,
      resource_kind: :client_persona,
    )

    assert_equal :established, result.status
    assert_predicate result.cutover_at, :present?
    assert_predicate ClientPersonaAuthorityCutover, :established?
    assert_equal 1, ClientPersonaAuthorityCutover.count
  end

  test "does not create a marker for an unresolved family" do
    result = AuthorityOwnerFamilyCutoverOperation.call(
      surface: :app,
      resource_kind: :client_persona,
    )

    assert_equal :manual_review, result.status
    assert_equal :family_not_ready, result.reason
    assert_not ClientPersonaAuthorityCutover.established?
  end

  test "replays an established family without creating a second marker" do
    establish_ready_persona_family!

    first = AuthorityOwnerFamilyCutoverOperation.call(surface: :app, resource_kind: :client_persona)
    second = AuthorityOwnerFamilyCutoverOperation.call(surface: :app, resource_kind: :client_persona)

    assert_equal :established, first.status
    assert_equal :already_cut_over, second.status
    assert_equal first.cutover_at, second.cutover_at
    assert_equal 1, ClientPersonaAuthorityCutover.count
  end

  test "rejects reviewed backfill after the family point of no return" do
    client, persona = establish_ready_persona_family!
    result = AuthorityOwnerFamilyCutoverOperation.call(surface: :app, resource_kind: :client_persona)
    assert_equal :established, result.status

    result = AuthorityOwnerDirectBindingBackfillOperation.call(
      surface: :app,
      resource_kind: :client_persona,
      resource_public_id: persona.public_id,
      owner_public_id: client.public_id,
    )

    assert_equal :manual_review, result.status
    assert_equal :family_already_cut_over, result.reason
  end

  test "a persisted marker cannot be updated or destroyed through its model" do
    establish_ready_persona_family!
    AuthorityOwnerFamilyCutoverOperation.call(surface: :app, resource_kind: :client_persona)
    marker = ClientPersonaAuthorityCutover.find(1)

    assert_raises(ActiveRecord::ReadOnlyRecord) { marker.update!(cutover_at: 1.minute.from_now) }
    assert_raises(ActiveRecord::ReadOnlyRecord) { marker.destroy! }
    assert ClientPersonaAuthorityCutover.exists?(id: 1)
  end

  private

  def establish_ready_persona_family!
    client = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    identity = ClientIdentity.create!(
      issuer: "https://id.example.test",
      subject: "cutover-operation-#{SecureRandom.hex(6)}",
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
    [client, persona]
  end
end
