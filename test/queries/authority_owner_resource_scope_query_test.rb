# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthorityOwnerResourceScopeQueryTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    ClientIdentityState.ensure_defaults!
    ClientStatus.ensure_defaults!
    ClientVisibility.ensure_defaults!
  end

  test "returns only resources from the requested surface-local ownership relation" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    identity = ClientIdentity.create!(
      issuer: "https://id.example.test",
      subject: "owner-scope-#{SecureRandom.hex(6)}",
      audience: "acme_app",
      source_record_id: client.id,
      status_id: ClientIdentityState::ACTIVE,
    )
    owned_persona =
      I18n.with_locale(:en) do
        ClientPersona.create!(client_identity: identity, title: "Owned")
      end
    unowned_client = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    unowned_identity = ClientIdentity.create!(
      issuer: "https://id.example.test",
      subject: "owner-scope-unowned-#{SecureRandom.hex(6)}",
      audience: "acme_app",
      source_record_id: unowned_client.id,
      status_id: ClientIdentityState::ACTIVE,
    )
    unowned_persona =
      I18n.with_locale(:en) do
        ClientPersona.create!(client_identity: unowned_identity, title: "Unowned")
      end
    ClientPersonaOwnership.create!(client_persona: owned_persona, client:, ownership_revision: 0)

    relation = AuthorityOwnerResourceScopeQuery.call(
      surface: :app,
      resource_kind: :client_persona,
      principal: client,
    )

    assert_equal [owned_persona.id], relation.pluck(:id)
    assert_not_includes relation.pluck(:id), unowned_persona.id
  end

  test "rejects a principal from another surface" do
    visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)

    assert_raises(ArgumentError) do
      AuthorityOwnerResourceScopeQuery.call(
        surface: :app,
        resource_kind: :client_persona,
        principal: visitor,
      ).to_a
    end
  end
end
