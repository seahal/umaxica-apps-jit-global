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

  test "direct bindings classify missing inactive and legacy candidates" do
    inventory = AuthorityOwnerMigrationInventory.new
    configuration =
      AuthorityOwnerMigrationInventory::RESOURCE_CONFIGS.find do |entry|
        entry.fetch(:resource_kind) == :client_persona
      end

    missing =
      inventory.send(
        :direct_detail,
        configuration,
        Struct.new(:public_id).new("res_missing"),
        nil,
        nil,
      )

    assert_equal :missing_identity_binding, missing.fetch(:classification)

    inactive_identity =
      Struct.new(:public_id, :status_id, :source_record_id).new(
        "id_inactive",
        configuration.fetch(:identity_active_status_id) + 1,
        1,
      )
    inactive =
      inventory.send(
        :direct_detail,
        configuration,
        Struct.new(:public_id).new("res_inactive"),
        inactive_identity,
        nil,
      )

    assert_equal :inactive_identity_binding, inactive.fetch(:classification)

    active_identity =
      Struct.new(:public_id, :status_id, :source_record_id).new(
        "id_active",
        configuration.fetch(:identity_active_status_id),
        42,
      )
    missing_principal =
      inventory.send(
        :direct_detail,
        configuration,
        Struct.new(:public_id).new("res_no_principal"),
        active_identity,
        nil,
      )

    assert_equal :missing_principal, missing_principal.fetch(:classification)

    inactive_principal =
      Struct.new(:public_id, :status_id, :login_allowed?, :access_enabled?).new(
        "prin_inactive",
        configuration.fetch(:principal_active_status_id) + 1,
        true,
        true,
      )
    inactive_p =
      inventory.send(
        :direct_detail,
        configuration,
        Struct.new(:public_id).new("res_inactive_p"),
        active_identity,
        inactive_principal,
      )

    assert_equal :inactive_principal, inactive_p.fetch(:classification)

    blocked_login =
      Struct.new(:public_id, :status_id, :login_allowed?, :access_enabled?).new(
        "prin_blocked",
        configuration.fetch(:principal_active_status_id),
        false,
        true,
      )
    blocked =
      inventory.send(
        :direct_detail,
        configuration,
        Struct.new(:public_id).new("res_blocked"),
        active_identity,
        blocked_login,
      )

    assert_equal :inactive_principal, blocked.fetch(:classification)

    active_principal =
      Struct.new(:public_id, :status_id, :login_allowed?, :access_enabled?).new(
        "prin_active",
        configuration.fetch(:principal_active_status_id),
        true,
        true,
      )
    candidate =
      inventory.send(
        :direct_detail,
        configuration,
        Struct.new(:public_id).new("res_ok"),
        active_identity,
        active_principal,
      )

    assert_equal :legacy_binding_candidate, candidate.fetch(:classification)
  end

  test "organization details classify empty memberships and membership-not-ownership" do
    inventory = AuthorityOwnerMigrationInventory.new
    configuration =
      AuthorityOwnerMigrationInventory::RESOURCE_CONFIGS.find do |entry|
        entry.fetch(:resource_kind) == :enterprise
      end
    resource = Struct.new(:public_id, :id).new("ent_empty", 1)

    empty = inventory.send(:organization_detail, configuration, resource, [], {})

    assert_equal :no_legacy_owner_candidate, empty.fetch(:classification)
    assert_equal 0, empty.fetch(:active_membership_count)

    identity =
      Struct.new(:public_id, :status_id, :source_record_id).new(
        "id_m",
        configuration.fetch(:identity_active_status_id),
        7,
      )
    persona = Struct.new(:public_id).new("persona_m")
    persona.define_singleton_method(configuration.fetch(:identity_association)) { identity }
    membership = Object.new
    membership.define_singleton_method(configuration.fetch(:membership_principal_association)) { persona }
    principal =
      Struct.new(:public_id, :status_id, :login_allowed?, :access_enabled?).new(
        "prin_m",
        configuration.fetch(:principal_active_status_id),
        true,
        true,
      )

    populated =
      inventory.send(
        :organization_detail,
        configuration,
        resource,
        [membership],
        { 7 => principal },
      )

    assert_equal :membership_not_ownership, populated.fetch(:classification)
    assert_equal 1, populated.fetch(:active_membership_count)
    assert_equal 1, populated.fetch(:candidate_principals).length
  end

  test "incomplete authority schema raises instead of pretending the surface is ready" do
    inventory = AuthorityOwnerMigrationInventory.new
    seen = 0
    connection = Object.new
    connection.define_singleton_method(:data_source_exists?) do |_table|
      seen += 1
      seen == 1
    end

    resource_classes =
      AuthorityOwnerMigrationInventory::RESOURCE_CONFIGS
        .map { |configuration| configuration.fetch(:resource_class) }
        .uniq
    originals = resource_classes.index_with { |klass| klass.method(:connection) }

    begin
      resource_classes.each do |klass|
        klass.define_singleton_method(:connection) { connection }
      end

      error =
        assert_raises(AuthorityOwnerMigrationInventory::IncompleteAuthoritySchema) do
          inventory.send(:authority_schema_state)
        end
      assert_match(/partially applied/, error.message)
    ensure
      originals.each do |klass, method|
        klass.define_singleton_method(:connection, method)
      end
    end
  end

  test "public identifier collapses blank and unknown records" do
    inventory = AuthorityOwnerMigrationInventory.new

    assert_nil inventory.send(:public_identifier, nil)
    assert_nil inventory.send(:public_identifier, Object.new)
    assert_nil inventory.send(:public_identifier, Struct.new(:public_id).new(""))
    assert_equal "pub_1", inventory.send(:public_identifier, Struct.new(:public_id).new("pub_1"))
  end

  test "candidate detail is omitted when every identity is absent" do
    inventory = AuthorityOwnerMigrationInventory.new
    configuration =
      AuthorityOwnerMigrationInventory::RESOURCE_CONFIGS.find do |entry|
        entry.fetch(:resource_kind) == :client_persona
      end

    assert_nil inventory.send(:candidate_detail, configuration, nil, nil)
  end

  test "reports not_applied when no authority tables exist" do
    inventory = AuthorityOwnerMigrationInventory.new
    connection = Object.new
    connection.define_singleton_method(:data_source_exists?) { |_table| false }

    resource_classes =
      AuthorityOwnerMigrationInventory::RESOURCE_CONFIGS
        .map { |configuration| configuration.fetch(:resource_class) }
        .uniq
    originals = resource_classes.index_with { |klass| klass.method(:connection) }

    begin
      resource_classes.each do |klass|
        klass.define_singleton_method(:connection) { connection }
      end

      assert_equal :not_applied, inventory.send(:authority_schema_state)
    ensure
      originals.each do |klass, method|
        klass.define_singleton_method(:connection, method)
      end
    end
  end

  test "organization inventory tolerates a membership without a principal" do
    inventory = AuthorityOwnerMigrationInventory.new
    configuration =
      AuthorityOwnerMigrationInventory::RESOURCE_CONFIGS.find do |entry|
        entry.fetch(:resource_kind) == :enterprise
      end
    membership = Object.new
    membership.define_singleton_method(configuration.fetch(:membership_principal_association)) { nil }
    resource = Struct.new(:public_id, :id).new("ent_orphan", 2)

    detail = inventory.send(:organization_detail, configuration, resource, [membership], {})

    assert_equal :membership_not_ownership, detail.fetch(:classification)
    assert_equal 1, detail.fetch(:active_membership_count)
    assert_empty detail.fetch(:candidate_principals)
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
