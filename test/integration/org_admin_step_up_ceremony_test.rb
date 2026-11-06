# frozen_string_literal: true

require "test_helper"
require_relative "../support/rp_cell_session_helper"

# The owner API and RP session enforce the Support gate. The signed OIDC callback and evidence
# validation are covered by the RP callback operation tests; this file exercises the Base consumer.
class OrgAdminStepUpCeremonyTest < ActionDispatch::IntegrationTest
  include RpCellSessionHelper

  self.fixture_table_names = []

  setup do
    https!
    @base_host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    @operator = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      status_id: OperatorStatus::ACTIVE,
      visibility_id: OperatorVisibility::STAFF,
    )
    OperatorPasskeyTestSupport.give_two_active_passkeys!(@operator)
    @root_token = authentication_harness_create_token(@operator)
    @client = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    [OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_APP,
     OperatorCapabilityGrant::SUPPORT_SESSION_REVOKE_APP,].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator, origin: "bootstrap", capability: capability,
        reason_code: "bootstrap", starts_at: 1.minute.ago, expires_at: 1.day.from_now,
      )
    end
    ChronicleRetentionPolicy.find_or_create_by!(code: "compliance") do |policy|
      policy.name = "Compliance"
      policy.duration_days = 365
      policy.permanent = false
    end
  end

  test "Support revocation requires recent proof in this RP session" do
    host! @base_host

    as_rp_cell("base-org-ww") do
      _token_response, _payload, rp_session = sign_in_rp_cell(
        "base-org-ww", actor: @operator, root_token: @root_token,
      )

      get new_base_org_support_client_revocation_path(@client.public_id, ri: "jp")

      assert_response :unauthorized
      assert_includes response.headers.fetch("WWW-Authenticate"), 'error="insufficient_user_authentication"'
      assert_equal 0, RpBaseOrgStepUpState.where(rp_session:).count
    end
  end

  test "Support revocation page accepts a current OP event installed in its RP session" do
    host! @base_host

    as_rp_cell("base-org-ww") do
      _token_response, _payload, rp_session = sign_in_rp_cell_with_step_up_evidence(
        "base-org-ww", actor: @operator, root_token: @root_token,
      )

      get new_base_org_support_client_revocation_path(@client.public_id, ri: "jp")

      assert_response :success
      assert_equal rp_session.public_id, cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE]
    end
  end
end
