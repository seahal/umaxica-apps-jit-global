# frozen_string_literal: true

class ValidateNanoidPublicIdLengthComZenith < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    validate_check_constraint(:com_enforcement_appeals, name: "chk_com_enforcement_appeals_pid")
    validate_check_constraint(:companies, name: "chk_companies_pid")
    validate_check_constraint(:company_ownership_transfer_requests, name: "chk_company_ownership_transfer_requests_pid")
    validate_check_constraint(:company_units, name: "chk_company_units_pid")
    validate_check_constraint(:core_com_visitor_bridges, name: "chk_core_com_visitor_bridges_pid")
    validate_check_constraint(:individuals, name: "chk_individuals_pid")
    validate_check_constraint(:individual_assignments, name: "chk_individual_assignments_pid")
    validate_check_constraint(:individual_ownership_transfer_requests, name: "chk_individual_ownership_transfer_requests_pid")
    validate_check_constraint(:visitors, name: "chk_visitors_pid")
    validate_check_constraint(:visitor_accounts, name: "chk_visitor_accounts_pid")
    validate_check_constraint(:visitor_emails, name: "chk_visitor_emails_pid")
    validate_check_constraint(:visitor_enforcement_recovery_ceremonies, name: "chk_visitor_enforcement_recovery_ceremonies_pid")
    validate_check_constraint(:visitor_identities, name: "chk_visitor_identities_pid")
    validate_check_constraint(:visitor_passkeys, name: "chk_visitor_passkeys_pid")
    validate_check_constraint(:visitor_preferences, name: "chk_visitor_preferences_pid")
    validate_check_constraint(:visitor_privacy_requests, name: "chk_visitor_privacy_requests_pid")
    validate_check_constraint(:visitor_processor_erasure_notifications, name: "chk_visitor_processor_erasure_notifications_pid")
    validate_check_constraint(:visitor_retention_holds, name: "chk_visitor_retention_holds_pid")
    validate_check_constraint(:visitor_secret_credentials, name: "chk_visitor_secret_credentials_pid")
    validate_check_constraint(:visitor_telephones, name: "chk_visitor_telephones_pid")
    validate_check_constraint(:visitor_withdrawal_ceremonies, name: "chk_visitor_withdrawal_ceremonies_pid")
    validate_check_constraint(:visitor_withdrawal_flows, name: "chk_visitor_withdrawal_flows_pid")
  end
end
