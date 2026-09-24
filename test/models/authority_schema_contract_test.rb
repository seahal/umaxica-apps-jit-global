# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthoritySchemaContractTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  EXPECTED_TABLES = {
    app: %w(
      client_authority_locks
      client_persona_ownerships
      client_persona_administration_grants
      client_persona_delegation_grants
      client_persona_usage_grants
      client_persona_view_grants
      enterprise_ownerships
      enterprise_administration_grants
      enterprise_delegation_grants
      enterprise_view_grants
      client_persona_ownership_transfer_requests
      enterprise_ownership_transfer_requests
    ),
    com: %w(
      visitor_authority_locks
      individual_ownerships
      individual_administration_grants
      individual_delegation_grants
      individual_usage_grants
      individual_view_grants
      company_ownerships
      company_administration_grants
      company_delegation_grants
      company_view_grants
      individual_ownership_transfer_requests
      company_ownership_transfer_requests
    ),
    org: %w(
      operator_authority_locks
      agent_ownerships
      agent_administration_grants
      agent_delegation_grants
      agent_usage_grants
      agent_view_grants
      bureau_ownerships
      bureau_administration_grants
      bureau_delegation_grants
      bureau_view_grants
      agent_ownership_transfer_requests
      bureau_ownership_transfer_requests
    ),
  }.freeze

  MIGRATIONS = {
    app: "db/app_zenith_migrate/20260917120000_create_app_authority_relations.rb",
    com: "db/com_zenith_migrate/20260917120001_create_com_authority_relations.rb",
    org: "db/org_zenith_migrate/20260917120002_create_org_authority_relations.rb",
  }.freeze

  LIFECYCLE_MIGRATIONS = {
    app: "db/app_zenith_migrate/20260923170000_create_app_authority_resource_lifecycles.rb",
    com: "db/com_zenith_migrate/20260923170001_create_com_authority_resource_lifecycles.rb",
    org: "db/org_zenith_migrate/20260923170002_create_org_authority_resource_lifecycles.rb",
  }.freeze

  EXPECTED_LIFECYCLE_TABLES = {
    app: %w(client_persona_lifecycles enterprise_lifecycles),
    com: %w(individual_lifecycles company_lifecycles),
    org: %w(agent_lifecycles bureau_lifecycles),
  }.freeze

  CUTOVER_MIGRATIONS = {
    app: "db/app_zenith_migrate/20260923180000_create_app_authority_cutovers.rb",
    com: "db/com_zenith_migrate/20260923180001_create_com_authority_cutovers.rb",
    org: "db/org_zenith_migrate/20260923180002_create_org_authority_cutovers.rb",
  }.freeze

  EXPECTED_CUTOVER_TABLES = {
    app: %w(client_persona_authority_cutovers enterprise_authority_cutovers),
    com: %w(individual_authority_cutovers company_authority_cutovers),
    org: %w(agent_authority_cutovers bureau_authority_cutovers),
  }.freeze

  test "each surface migration explicitly enumerates its authority tables" do
    MIGRATIONS.each do |surface, relative_path|
      source = Rails.root.join(relative_path).read
      actual = source.scan(/create_table\(:([a-z0-9_]+), id: :bigserial\)/).flatten

      assert_equal EXPECTED_TABLES.fetch(surface), actual, "#{surface} migration table inventory changed"
      assert_no_match(/resource_type|identity_type|merge\s*:/, source)
    end
  end

  test "each surface lifecycle migration explicitly enumerates concrete lifecycle tables" do
    LIFECYCLE_MIGRATIONS.each do |surface, relative_path|
      source = Rails.root.join(relative_path).read
      actual = source.scan(/create_table\(:([a-z0-9_]+), id: :bigserial\)/).flatten

      assert_equal EXPECTED_LIFECYCLE_TABLES.fetch(surface), actual,
                   "#{surface} lifecycle migration table inventory changed"
      assert_no_match(/resource_type|identity_type|merge\s*:/, source)
    end
  end

  test "each surface cutover migration enumerates only singleton marker tables" do
    CUTOVER_MIGRATIONS.each do |surface, relative_path|
      source = Rails.root.join(relative_path).read
      actual = source.scan(/create_table\(:([a-z0-9_]+), id: :bigint\)/).flatten

      assert_equal EXPECTED_CUTOVER_TABLES.fetch(surface), actual,
                   "#{surface} cutover migration table inventory changed"
      assert_equal EXPECTED_CUTOVER_TABLES.fetch(surface).length,
                   source.scan(/id = 1/).length,
                   "#{surface} cutover tables must be singleton rows"
      assert_equal EXPECTED_CUTOVER_TABLES.fetch(surface).length,
                   source.scan(/isfinite\(cutover_at\)/).length,
                   "#{surface} cutover timestamps must be finite"
      assert_no_match(/resource_type|identity_type|polymorphic|STI/i, source)
    end
  end

  test "authority references do not create redundant automatic indexes" do
    MIGRATIONS.each_value do |relative_path|
      references = Rails.root.join(relative_path).read.lines.grep(/t\.references\(/)

      assert_operator references.length, :>, 0
      references.each do |reference|
        assert_match(
          /index:\s*false/,
          reference,
          "authority reference must opt out of Rails' default index: #{reference}",
        )
      end
    end
  end

  test "transfer request public identifiers do not default to an empty value" do
    MIGRATIONS.each_value do |relative_path|
      source = Rails.root.join(relative_path).read

      assert_no_match(
        /t\.string\(:public_id, null: false, default: \"\"\)/,
        source,
        "transfer request identifiers must be generated by the model, not defaulted to empty",
      )
    end
  end

  test "authority tables are surface-local concrete classes" do
    assert_operator ClientPersonaOwnership, :<, AppRpRecord
    assert_operator IndividualOwnership, :<, ComRpRecord
    assert_operator AgentOwnership, :<, OrgRpRecord
    assert_equal "personas", ClientPersona.table_name
    assert_equal "individuals", Individual.table_name
    assert_equal "agents", Agent.table_name
    [ClientPersonaLifecycle, EnterpriseLifecycle].each do |lifecycle_class|
      assert_operator lifecycle_class, :<, AppRpRecord
    end
    [IndividualLifecycle, CompanyLifecycle].each do |lifecycle_class|
      assert_operator lifecycle_class, :<, ComRpRecord
    end
    [AgentLifecycle, BureauLifecycle].each do |lifecycle_class|
      assert_operator lifecycle_class, :<, OrgRpRecord
    end

    assert_operator ClientPersonaAuthorityCutover, :<, AppRpRecord
    assert_operator EnterpriseAuthorityCutover, :<, AppRpRecord
    assert_operator IndividualAuthorityCutover, :<, ComRpRecord
    assert_operator CompanyAuthorityCutover, :<, ComRpRecord
    assert_operator AgentAuthorityCutover, :<, OrgRpRecord
    assert_operator BureauAuthorityCutover, :<, OrgRpRecord
  end

  test "lifecycle migrations use explicit finite states and restrictive resource references" do
    LIFECYCLE_MIGRATIONS.each_value do |relative_path|
      source = Rails.root.join(relative_path).read

      assert_match(/t\.string\(:state, null: false\)/, source)
      assert_match(/state_changed_at, null: false, default: -> \{ "clock_timestamp\(\)" \}/, source)
      assert_match(/on_delete: :restrict/, source)
      assert_match(/state IN \(#{Regexp.escape("'active', 'inactive', 'discarded', 'deleted', 'retained'")}\)/, source)
    end
  end

  test "ownership rows cannot be destroyed independently" do
    [
      ClientPersonaOwnership,
      EnterpriseOwnership,
      IndividualOwnership,
      CompanyOwnership,
      AgentOwnership,
      BureauOwnership,
    ].each do |ownership_class|
      ownership = ownership_class.new

      assert_not ownership.destroy
      error_message =
        ownership.errors.full_messages.find do |message|
          message.include?("ownership rows cannot be deleted independently")
        end

      assert_predicate error_message, :present?
    end
  end
end
