# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::Org::Identity::BirthdatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = Rails.configuration.x.boot_config.fetch(:hosts).base_staff.host
    OperatorStatus.find_or_create_by!(id: OperatorStatus::ACTIVE)
    @operator = Operator.create!(status_id: OperatorStatus::ACTIVE)
  end

  test "show reports that a birthdate is not set" do
    get base_org_identity_birthdate_url(ri: "jp", host: @host), headers: org_birthdate_headers

    assert_response :success
    assert_equal "base/org/identity/birthdates/show", inertia_component
    assert_nil inertia_props.fetch("birthdate")
  end

  test "show includes the stored birthdate when one is present" do
    @operator.update!(birthdate: "2000-01-01")

    get base_org_identity_birthdate_url(ri: "jp", host: @host), headers: org_birthdate_headers

    assert_response :success
    assert_equal "2000-01-01", inertia_props.fetch("birthdate")
  end

  private

  def org_birthdate_headers
    headers = as_staff_headers(@operator, host: @host)
    token = authentication_harness_latest_token(@operator)
    token.update_columns(
      last_step_up_at: Time.current,
      last_step_up_scope: "settings_birthdate",
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
      last_step_up_credential_ref: "test-step-up-credential", last_step_up_full_reauthentication: false,
      last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:org",
      updated_at: Time.current,
    )
    _verification, raw_token = OperatorVerification.issue_for_token!(token: token)
    access_token = headers["Cookie"].to_s[/#{Regexp.escape(AuthenticationBase::ACCESS_COOKIE_KEY)}=([^;]+)/, 1]
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token
    cookies[OperatorVerification.cookie_name] = raw_token

    headers.except("Cookie", "HTTP_COOKIE")
  end
end
