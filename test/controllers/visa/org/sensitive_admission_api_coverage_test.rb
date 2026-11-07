# frozen_string_literal: true

require "test_helper"
require_relative "../../../support/rp_cell_session_helper"

class Visa::Org::SensitiveAdmissionApiCoverageTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  include RpCellSessionHelper

  setup do
    @operator = Operator.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: OperatorStatus::ACTIVE,
      visibility_id: OperatorVisibility::STAFF,
    )
    @root_token = OperatorToken.create!(
      authentication_epoch: 0,
      staff: @operator,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      discard_at: 1.hour.from_now,
      root_login_established_at: Time.current,
      established_authentication_method: "passkey",
    )
    @token_response =
      as_rp_cell("base-org-ww") do
        sign_in_rp_cell("base-org-ww", actor: @operator, root_token: @root_token).first
      end
    @host = visa_host_for_test_surface(:org)
    https!
    host! @host
  end

  test "ORG admission creation reaches its validation boundary for an authenticated Base caller" do
    before = [OperatorVisaSensitiveAdmission.count, OperatorAuthAdmissionBinding.count]

    post "/api/v0/sensitive_admissions", params: {}, headers: authenticated_headers_for(
      "/api/v0/sensitive_admissions",
    )

    assert_response :bad_request
    assert_equal "invalid_request", response.parsed_body.fetch("error")
    assert_equal before, [OperatorVisaSensitiveAdmission.count, OperatorAuthAdmissionBinding.count]
  end

  test "ORG browser confirmation rejects missing binding evidence without changing the admission" do
    before = [OperatorVisaSensitiveAdmission.count, OperatorAuthAdmissionBinding.count]

    post "/api/v0/sensitive_admission_confirmation", params: {}, headers: authenticated_headers_for(
      "/api/v0/sensitive_admission_confirmation",
    )

    assert_response :bad_request
    assert_equal "invalid_request", response.parsed_body.fetch("error")
    assert_equal before, [OperatorVisaSensitiveAdmission.count, OperatorAuthAdmissionBinding.count]
  end

  private

  def authenticated_headers_for(path)
    {
      "Authorization" => "Bearer #{@token_response.fetch(:access_token)}",
      "X-Client-Assertion" => OidcClientAssertionJwt.issue(
        client_id: "base-org-ww",
        token_url: "https://#{@host}#{path}",
      ),
    }
  end
end
