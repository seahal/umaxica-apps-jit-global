# frozen_string_literal: true

require "test_helper"
require "json"

class AuthorityOwnerMigrationInventoryTest < ActiveSupport::TestCase
  setup do
    ClientIdentityState.ensure_defaults!
    PersonaMembershipKind.ensure_defaults! if defined?(PersonaMembershipKind)
    PersonaMembershipState.ensure_defaults! if defined?(PersonaMembershipState)
  end

  test "covers each concrete resource and never treats a legacy binding as an owner" do
    configurations = AuthorityOwnerMigrationInventory::RESOURCE_CONFIGS

    assert_equal %w(agent bureau client_persona company enterprise individual),
                 configurations.map { |configuration| configuration.fetch(:resource_kind).to_s }.sort
    assert_equal %w(app app com com org org),
                 configurations.map { |configuration| configuration.fetch(:surface).to_s }.sort

    configurations.each do |configuration|
      assert_predicate configuration.fetch(:resource_class).name, :present?
      assert_predicate configuration.fetch(:principal_class).name, :present?
      assert_not configuration.fetch(:auto_backfill)
      assert_equal :manual_review, configuration.fetch(:recommended_action)
    end
  end

  test "authority table state is explicit rather than silently treated as ready" do
    expected = %i(not_applied applied)

    assert_equal expected, AuthorityOwnerMigrationInventory::AUTHORITY_SCHEMA_STATES
    assert_raises(KeyError) do
      AuthorityOwnerMigrationInventory::AUTHORITY_TABLES.fetch(:unknown_surface)
    end
  end

  test "call returns a JSON-serializable inventory summary for every resource kind" do
    persona = ClientPersona.create!(client_identity: active_client_identity("inv-persona"), title: "InvP")
    enterprise = Enterprise.create!(name: "Inv Enterprise", title: "InvEnt")

    result = AuthorityOwnerMigrationInventory.call
    payload = JSON.parse(result.to_json)

    assert_includes %w(not_applied applied), payload.fetch("summary").fetch("authority_schema_state")
    assert_operator payload.fetch("summary").fetch("resources_scanned"), :>=, 1
    assert_kind_of Hash, payload.fetch("summary").fetch("classifications")

    persona_detail =
      payload.fetch("details").find do |detail|
        detail.fetch("resource_kind") == "client_persona" &&
          detail.fetch("resource_public_id") == persona.public_id
      end

    assert persona_detail, "expected the inventory to list the created persona"
    assert_not persona_detail.fetch("source_is_authoritative_owner")
    assert_equal "manual_review", persona_detail.fetch("recommended_action")

    enterprise_detail =
      payload.fetch("details").find do |detail|
        detail.fetch("resource_kind") == "enterprise" &&
          detail.fetch("resource_public_id") == enterprise.public_id
      end

    assert enterprise_detail, "expected the inventory to list the created enterprise"
    assert_equal "no_legacy_owner_candidate", enterprise_detail.fetch("classification")
    assert_equal 0, enterprise_detail.fetch("active_membership_count")
  end

  private

  def active_client_identity(label)
    ClientIdentity.create!(
      issuer: "https://id.example.test",
      subject: label,
      audience: "acme_app",
      source_record_id: Zlib.crc32(label),
      status_id: ClientIdentityState::ACTIVE,
    )
  end
end
