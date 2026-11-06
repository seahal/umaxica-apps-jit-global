# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "../../../../support/rp_cell_session_helper"

class Base::Org::Identity::BirthdatesControllerTest < ActionDispatch::IntegrationTest
  include RpCellSessionHelper

  self.fixture_table_names = []

  setup do
    @host = Rails.configuration.x.boot_config.fetch(:hosts).base_staff.host
    OperatorStatus.find_or_create_by!(id: OperatorStatus::ACTIVE)
    @operator = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
    OperatorPasskeyTestSupport.give_two_active_passkeys!(@operator)
  end

  test "show reports that a birthdate is not set" do
    host! @host
    headers = as_staff_headers(@operator, host: @host)
    token = OperatorToken.find_by!(public_id: headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
    token.rotate_refresh_token! unless token.device_session_record.current_refresh_token_id
    _, _, rp_session = sign_in_rp_cell_with_step_up_evidence("base-org-ww", actor: @operator, root_token: token)
    access = cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE]
    refresh = cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE]
    browser_cookie = [
      headers.fetch("Cookie"),
      "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(access)}",
      "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(refresh)}",
      "#{OidcRpBrowserCredentialContract::SESSION_COOKIE}=#{Rack::Utils.escape(rp_session.public_id)}",
    ].join("; ")
    browser_headers = headers.merge("Cookie" => browser_cookie, "HTTP_COOKIE" => browser_cookie)
    get base_org_identity_birthdate_url(ri: "jp", host: @host), headers: browser_headers

    assert_response :success
    assert_equal "base/org/identity/birthdates/show", inertia_component
    assert_nil inertia_props.fetch("birthdate")
  end

  test "show includes the stored birthdate when one is present" do
    host! @host
    @operator.update!(birthdate: "1990-01-02")
    headers = as_staff_headers(@operator, host: @host)
    token = OperatorToken.find_by!(public_id: headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
    token.rotate_refresh_token! unless token.device_session_record.current_refresh_token_id
    _, _, rp_session = sign_in_rp_cell_with_step_up_evidence("base-org-ww", actor: @operator, root_token: token)
    access = cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE]
    refresh = cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE]
    browser_cookie = [
      headers.fetch("Cookie"),
      "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(access)}",
      "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(refresh)}",
      "#{OidcRpBrowserCredentialContract::SESSION_COOKIE}=#{Rack::Utils.escape(rp_session.public_id)}",
    ].join("; ")
    browser_headers = headers.merge("Cookie" => browser_cookie, "HTTP_COOKIE" => browser_cookie)
    get base_org_identity_birthdate_url(ri: "jp", host: @host), headers: browser_headers

    assert_response :success
    assert_equal "base/org/identity/birthdates/show", inertia_component
    assert_equal "1990-01-02", inertia_props.fetch("birthdate")
  end

  test "standby session cannot view the step-up protected birthdate" do
    host! @host
    @operator.update!(birthdate: "1990-01-02")
    headers = as_staff_headers(@operator, host: @host)
    token = OperatorToken.find_by!(public_id: headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
    token.update!(authentication_context: AuthenticationContextValue::STANDBY_KEY)
    headers = as_staff_headers(@operator, host: @host, session_public_id: token.public_id)
    token.rotate_refresh_token! unless token.device_session_record.current_refresh_token_id
    _, _, rp_session = sign_in_rp_cell("base-org-ww", actor: @operator, root_token: token)
    access = cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE]
    refresh = cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE]
    browser_cookie = [
      headers.fetch("Cookie"),
      "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(access)}",
      "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(refresh)}",
      "#{OidcRpBrowserCredentialContract::SESSION_COOKIE}=#{Rack::Utils.escape(rp_session.public_id)}",
    ].join("; ")
    browser_headers = headers.merge("Cookie" => browser_cookie, "HTTP_COOKIE" => browser_cookie)

    assert_no_difference("OperatorStepUpCeremonyTransaction.count") do
      get base_org_identity_birthdate_url(ri: "jp", host: @host), headers: browser_headers
    end

    assert_response :forbidden
    assert_equal I18n.t("auth.step_up.emergency_unavailable"), response.body
    assert_not_includes response.body, "1990-01-02"
    assert_equal AuthenticationContextValue::STANDBY_KEY, token.reload.authentication_context
  end

  private
end
