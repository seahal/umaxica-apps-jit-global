# typed: false
# frozen_string_literal: true

require "test_helper"

class PreferenceCurrencyAssociationDestroyTest < ActiveSupport::TestCase
  CLIENT_DESTROY_ASSOCIATIONS = %i(
    client_external_identities client_apple_notification_events client_emails client_telephones
    client_totp_credentials client_passkeys client_withdrawal_ceremonies client_tokens client_device_sessions
    oidc_connections client_memberships clients client_banners client_members client_member_discoveries
    client_member_observations client_member_revocations client_member_impersonations client_member_suspensions
    client_member_deletions owned_members client_bulletins rp_account authority_lock core_app_client_bridge
  ).freeze
  VISITOR_DESTROY_ASSOCIATIONS = %i(
    visitor_emails visitor_withdrawal_ceremonies visitor_telephones visitor_secret_credentials visitor_passkeys
    visitor_tokens visitor_device_sessions authority_lock visitor_banners oidc_connections rp_account
    core_com_visitor_bridge
  ).freeze
  OPERATOR_DESTROY_ASSOCIATIONS = %i(
    staff_passkeys staff_tokens operator_device_sessions staff_secret_credentials oidc_connections staff_operators
    operator_workspace_accounts staff_bulletins staff_banners rp_account authority_lock core_org_operator_bridge
  ).freeze

  self.fixture_table_names = []

  setup do
    ensure_reference_defaults!
  end

  test "destroying client destroys currency preference child" do
    client = Client.create!
    preference = ClientPreference.create!(user: client)
    currency = ClientPreferenceCurrency.create!(preference: preference)

    # An Identity is physically erased only once it has lapsed and is purgeable.
    client.reload.update!(discard_at: client.created_at, purge_eligible_at: client.created_at)
    client = Client.includes(*CLIENT_DESTROY_ASSOCIATIONS, :user_preference).find(client.id)
    client.destroy!

    assert_not ClientPreference.exists?(preference.id)
    assert_not ClientPreferenceCurrency.exists?(currency.id)
  end

  test "destroying visitor destroys currency preference child" do
    visitor = Visitor.create!
    preference = VisitorPreference.create!(visitor: visitor)
    currency = VisitorPreferenceCurrency.create!(preference: preference)

    # An Identity is physically erased only once it has lapsed and is purgeable.
    visitor.reload.update!(discard_at: visitor.created_at, purge_eligible_at: visitor.created_at)
    visitor = Visitor.includes(*VISITOR_DESTROY_ASSOCIATIONS, :visitor_preference).find(visitor.id)
    visitor.destroy!

    assert_not VisitorPreference.exists?(preference.id)
    assert_not VisitorPreferenceCurrency.exists?(currency.id)
  end

  test "destroying operator destroys currency preference child" do
    operator = Operator.create!
    preference = OperatorPreference.create!(staff: operator)
    currency = OperatorPreferenceCurrency.create!(preference: preference)

    operator = Operator.includes(*OPERATOR_DESTROY_ASSOCIATIONS, :staff_preference).find(operator.id)
    operator.destroy!

    assert_not OperatorPreference.exists?(preference.id)
    assert_not OperatorPreferenceCurrency.exists?(currency.id)
  end

  private

  def ensure_reference_defaults!
    [
      ClientStatus,
      ClientVisibility,
      ClientMfaLevel,
      ClientMfaStatus,
      ClientPreferenceCurrencyOption,
      VisitorStatus,
      VisitorVisibility,
      VisitorMfaLevel,
      VisitorMfaStatus,
      VisitorPreferenceCurrencyOption,
      OperatorStatus,
      OperatorVisibility,
      OperatorMfaLevel,
      OperatorMfaStatus,
      OperatorPreferenceCurrencyOption,
    ].each(&:ensure_defaults!)
  end
end
