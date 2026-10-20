# frozen_string_literal: true

require "test_helper"

class PublicIdCapacityContractTest < ActiveSupport::TestCase
  TARGETS = [
    [Client, "clients", "chk_clients_pid"],
    [Visitor, "visitors", "chk_visitors_pid"],
    [AppPreference, "app_preferences", "chk_app_preferences_pid"],
    [ComPreference, "com_preferences", "chk_com_preferences_pid"],
    [OrgPreference, "org_preferences", "chk_org_preferences_pid"],
  ].freeze

  # These tables are not written through the PublicId NanoID concern, so adr/identifier-contract.md's
  # fixed 21-character storage does not apply yet; they keep the earlier 25-character capacity check.
  NON_NANOID_CAPACITY_TABLES = %w(logout_transactions members post_versions posts).freeze
  LEGACY_CAPACITY = /char_length\(public_id(?:::text)?\) <= 25/
  FIXED_LENGTH = /char_length\(\(?public_id\)?(?:::text)?\) = 21/

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
    test "#{model.name} has the fixed-length public identity constraint" do
      model.connection_pool.with_connection do |connection|
        constraint = connection.check_constraints(table).find { |item| item.name == constraint_name }

        assert constraint, "#{constraint_name} must be registered on #{table}"
        assert_match(/char_length\(\(?public_id\)?(?:::text)?\) = 21/, constraint.expression)

        record = model.create!
        long_value = "a" * 22

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
      test "#{table} has its public identity length constraint" do
        record_class.connection_pool.with_connection do |connection|
          legacy = NON_NANOID_CAPACITY_TABLES.include?(table)
          constraint_name = legacy ? "#{table}_public_id_max_length" : "chk_#{table}_pid"
          constraint = connection.check_constraints(table).find { |item| item.name == constraint_name }

          assert constraint, "#{constraint_name} must be registered on #{table}"
          expected = legacy ? LEGACY_CAPACITY : FIXED_LENGTH

          assert_match(expected, constraint.expression)
        end
      end
    end
  end
end
