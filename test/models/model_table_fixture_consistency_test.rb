# typed: false
# frozen_string_literal: true

require "test_helper"

class ModelTableFixtureConsistencyTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  # Concrete model renames that intentionally keep their existing physical tables.
  # Renaming these tables requires a separate data migration.
  RETAINED_TABLE_NAMES = {
    "ClientPersona" => "personas",
    "OperatorOrganization" => "organizations",
    "AppIdentityAuthenticationEvent" => "identity_authentication_events",
    "ComIdentityAuthenticationEvent" => "identity_authentication_events",
    "OrgIdentityAuthenticationEvent" => "identity_authentication_events",
    "OpAppConsumedJti" => "op_consumed_jtis",
    "OpComConsumedJti" => "op_consumed_jtis",
    "OpOrgConsumedJti" => "op_consumed_jtis",
    "OpAppLogoutFlow" => "logout_flows",
    "OpAppLogoutFlowParticipant" => "logout_flow_participants",
    "OpAppLogoutReceipt" => "logout_receipts",
    "OpAppOutboxEvent" => "op_outbox_events",
    "OpAppInboundEventReceipt" => "op_inbound_event_receipts",
    "OpComLogoutFlow" => "logout_flows",
    "OpComLogoutFlowParticipant" => "logout_flow_participants",
    "OpComLogoutReceipt" => "logout_receipts",
    "OpComOutboxEvent" => "op_outbox_events",
    "OpComInboundEventReceipt" => "op_inbound_event_receipts",
    "OpOrgLogoutFlow" => "logout_flows",
    "OpOrgLogoutFlowParticipant" => "logout_flow_participants",
    "OpOrgLogoutReceipt" => "logout_receipts",
    "OpOrgOutboxEvent" => "op_outbox_events",
    "OpOrgInboundEventReceipt" => "op_inbound_event_receipts",
  }.merge(
    RpCellBinding::CELLS.values.each_with_object({}) do |cell, mapping|
      {
        "#{cell.record_prefix}Principal" => "rp_principals",
        "#{cell.record_prefix}IdentityBinding" => "rp_identity_bindings",
        "#{cell.record_prefix}OpSessionBinding" => "rp_op_session_bindings",
        "#{cell.record_prefix}Session" => "rp_sessions",
        "#{cell.record_prefix}CallbackState" => "rp_callback_states",
        "#{cell.record_prefix}RefreshAttempt" => "rp_refresh_attempts",
        "#{cell.record_prefix}EventReceipt" => "rp_event_receipts",
      }.each { |model, table| mapping[model] = table }
    end,
  ).freeze

  test "application record table names follow model tableize convention" do
    Rails.application.eager_load!

    mismatches =
      application_record_models.filter_map do |model|
        expected = RETAINED_TABLE_NAMES.fetch(model.name) { model.name.tableize }
        actual = model.table_name
        "#{model.name}: expected #{expected}, got #{actual}" unless expected == actual
      end

    assert_empty mismatches.sort, "Model/table naming mismatches remain:\n#{mismatches.sort.join("\n")}"
  end

  test "fixture file names map to active record table names" do
    Rails.application.eager_load!

    table_names = application_record_models.map(&:table_name).to_set
    fixture_names = Rails.root.glob("test/fixtures/*.yml").map { |path| path.basename(".yml").to_s }
    missing_tables = fixture_names.reject { |fixture_name| table_names.include?(fixture_name) }

    assert_empty missing_tables.sort,
                 "Fixture files without matching model tables remain:\n#{missing_tables.sort.join("\n")}"
  end

  private

  def application_record_models
    ApplicationRecord.descendants.reject do |model|
      model.abstract_class? || model.name.blank? || model.name.include?("::")
    end
  end
end
