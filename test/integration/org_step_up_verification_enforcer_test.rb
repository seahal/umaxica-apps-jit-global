# frozen_string_literal: true

require "test_helper"
require_relative "../support/rp_cell_session_helper"

class OrgStepUpVerificationEnforcerTest < ActionDispatch::IntegrationTest
  include RpCellSessionHelper

  self.fixture_table_names = []

  test "an RP-local Org session without an OP step-up event is challenged before withdrawal" do
    operator = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      status_id: OperatorStatus::ACTIVE,
      visibility_id: OperatorVisibility::STAFF,
    )
    OperatorPasskeyTestSupport.give_two_active_passkeys!(operator)
    root_token = authentication_harness_create_token(operator)
    base_host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    host! base_host
    https!

    as_rp_cell("base-org-ww") do
      _token_response, _payload, rp_session = sign_in_rp_cell("base-org-ww", actor: operator, root_token:)

      get base_org_identity_withdrawal_path(ri: "jp")

      assert_response :redirect
      challenge = URI.parse(response.location)

      assert_equal "/verification", challenge.path
      assert_equal "operator_lifecycle", Rack::Utils.parse_nested_query(challenge.query).fetch("scope")
      assert_equal 0, RpBaseOrgStepUpState.where(rp_session:).count
      assert_predicate root_token.reload, :currently_usable?
    end
  end
end
