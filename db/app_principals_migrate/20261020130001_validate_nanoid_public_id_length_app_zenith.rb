# frozen_string_literal: true

class ValidateNanoidPublicIdLengthAppZenith < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    validate_check_constraint(:app_enforcement_appeals, name: "chk_app_enforcement_appeals_pid")
    validate_check_constraint(:clients, name: "chk_clients_pid")
    validate_check_constraint(:client_accounts, name: "chk_client_accounts_pid")
    validate_check_constraint(:client_bulletins, name: "chk_client_bulletins_pid")
    validate_check_constraint(:client_emails, name: "chk_client_emails_pid")
    validate_check_constraint(:client_enforcement_recovery_ceremonies, name: "chk_client_enforcement_recovery_ceremonies_pid")
    validate_check_constraint(:client_identities, name: "chk_client_identities_pid")
    validate_check_constraint(:client_passkeys, name: "chk_client_passkeys_pid")
    validate_check_constraint(:personas, name: "chk_personas_pid")
    validate_check_constraint(:client_persona_ownership_transfer_requests, name: "chk_client_persona_ownership_transfer_requests_pid")
    validate_check_constraint(:client_preferences, name: "chk_client_preferences_pid")
    validate_check_constraint(:client_privacy_requests, name: "chk_client_privacy_requests_pid")
    validate_check_constraint(:client_processor_erasure_notifications, name: "chk_client_processor_erasure_notifications_pid")
    validate_check_constraint(:client_profiles, name: "chk_client_profiles_pid")
    validate_check_constraint(:client_retention_holds, name: "chk_client_retention_holds_pid")
    validate_check_constraint(:client_secret_credentials, name: "chk_client_secret_credentials_pid")
    validate_check_constraint(:client_secret_issuances, name: "chk_client_secret_issuances_pid")
    validate_check_constraint(:client_telephones, name: "chk_client_telephones_pid")
    validate_check_constraint(:client_totp_credentials, name: "chk_client_totp_credentials_pid")
    validate_check_constraint(:client_withdrawal_ceremonies, name: "chk_client_withdrawal_ceremonies_pid")
    validate_check_constraint(:client_withdrawal_flows, name: "chk_client_withdrawal_flows_pid")
    validate_check_constraint(:core_app_client_bridges, name: "chk_core_app_client_bridges_pid")
    validate_check_constraint(:enterprises, name: "chk_enterprises_pid")
    validate_check_constraint(:enterprise_ownership_transfer_requests, name: "chk_enterprise_ownership_transfer_requests_pid")
    validate_check_constraint(:enterprise_units, name: "chk_enterprise_units_pid")
    validate_check_constraint(:persona_assignments, name: "chk_persona_assignments_pid")
  end
end
