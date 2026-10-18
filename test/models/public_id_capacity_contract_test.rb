# frozen_string_literal: true

require "test_helper"

class PublicIdCapacityContractTest < ActiveSupport::TestCase
  TARGETS = [
    [Client, "clients", "clients_public_id_max_length"],
    [Visitor, "visitors", "visitors_public_id_max_length"],
    [AppPreference, "app_preferences", "app_preferences_public_id_max_length"],
    [ComPreference, "com_preferences", "com_preferences_public_id_max_length"],
    [OrgPreference, "org_preferences", "org_preferences_public_id_max_length"],
  ].freeze

  CAPACITY_TABLES = {
    AppZenithRecord => %w(
      app_enforcement_appeals
      client_accounts
      client_identities
      client_persona_ownership_transfer_requests
      client_profiles
      core_app_client_bridges
      enterprise_ownership_transfer_requests
      enterprise_units
      enterprises
      members
      persona_assignments
      personas
    ),
    ComZenithRecord => %w(
      com_enforcement_appeals
      companies
      company_ownership_transfer_requests
      company_units
      core_com_visitor_bridges
      individual_assignments
      individual_ownership_transfer_requests
      individuals
      visitor_accounts
      visitor_identities
    ),
    OrgZenithRecord => %w(
      agent_assignments
      agent_ownership_transfer_requests
      agents
      bureau_ownership_transfer_requests
      bureau_units
      bureaus
      core_org_operator_bridges
      operator_accounts
      operator_identities
      operator_workspace_accounts
      org_enforcement_appeals
    ),
    OpBaseAppRecord => %w(acme_logout_transactions logout_transactions),
    AppSignalRecord => %w(client_notification_records member_notifications),
    ComSignalRecord => %w(visitor_notification_records),
    OrgSignalRecord => %w(operator_notification_records operator_notifications),
    AvatarRecord => %w(avatar_groups avatars group_avatar_memberships handles post_versions posts),
  }.freeze

  setup do
    AppPreferenceStatus.ensure_defaults!
    ComPreferenceStatus.ensure_defaults!
    OrgPreferenceStatus.ensure_defaults!
  end

  TARGETS.each do |model, table, constraint_name|
    test "#{model.name} has a database public identity capacity constraint" do
      model.connection_pool.with_connection do |connection|
        constraint = connection.check_constraints(table).find { |item| item.name == constraint_name }

        assert constraint, "#{constraint_name} must be registered on #{table}"
        assert_match(/char_length\(public_id(?:::text)?\) <= 25/, constraint.expression)

        record = model.create!
        long_value = "a" * 26

        assert_raises(ActiveRecord::StatementInvalid) do
          connection.transaction(requires_new: true) do
            connection.execute(
              "UPDATE #{connection.quote_table_name(table)} " \
              "SET public_id = #{connection.quote(long_value)} " \
              "WHERE id = #{record.id}",
            )
          end
        end
      end
    end
  end

  CAPACITY_TABLES.each do |record_class, tables|
    tables.each do |table|
      test "#{table} has a database public identity capacity constraint" do
        record_class.connection_pool.with_connection do |connection|
          constraint_name = "#{table}_public_id_max_length"
          constraint = connection.check_constraints(table).find { |item| item.name == constraint_name }

          assert constraint, "#{constraint_name} must be registered on #{table}"
          assert_match(/char_length\(public_id(?:::text)?\) <= 25/, constraint.expression)
        end
      end
    end
  end
end
