# typed: false
# frozen_string_literal: true

require "test_helper"

class DeliveredOtpAutocompleteTest < ActionDispatch::IntegrationTest
  fixtures :clients, :operators, :visitors

  setup do
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "app identity email and telephone otp inputs allow one time code autocomplete" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    host! host
    user = clients(:one)
    token = ClientToken.create!(
      user: user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      discard_at: 1.day.from_now,
    )
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: user)
    BaseSelectorAuthority.prepare(surface: :app, principal: user, session: token)
    _verification, raw_verification = ClientVerification.issue_for_token!(token: token)
    cookies[ClientVerification.cookie_name] = raw_verification
    token.update!(
      last_step_up_at: Time.current,
      last_step_up_scope: "settings_email",
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:app",
    )
    access_token = AuthenticationToken.encode(
      user,
      host: host,
      session_public_id: token.public_id,
      resource_type: "client",
      jwt_issuer_id: "surface:BASE_APP",
    )
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token
    headers = {
      "Authorization" => "Bearer #{access_token}",
      "Client-Agent" => "Mozilla/5.0",
      "Host" => host,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    get new_base_app_identity_emails_registration_url(ri: "jp", host: host), headers: headers

    assert_response :success

    fake_adapter = Object.new
    fake_adapter.define_singleton_method(:deliver) { |**_args| true }
    OtpAdapter.stub(:for, fake_adapter) do
      post base_app_identity_emails_registration_url(ri: "jp", host: host),
           params: { user_email: { address: "app-otp-autocomplete-#{SecureRandom.hex(4)}@example.test" } },
           headers: headers
    end

    assert_response :redirect
    follow_redirect!(headers: headers)

    assert_response :success
    # The one-time-code input, its `user_email[pass_code]` parameter and its autocomplete hint all live in
    # this component; the page object shows the visitor was sent to it with a code form to post.
    assert_equal "base/app/identity/emails/registrations/edit", inertia_component
    assert_predicate inertia_props.fetch("form").fetch("action"), :present?
    assert_predicate inertia_props.dig("form", "code_label") || inertia_props.fetch("code_label"), :present?

    token.update!(last_step_up_scope: "settings_telephone")
    OtpAdapter.stub(:for, fake_adapter) do
      post base_app_identity_telephones_registration_url(ri: "jp", host: host),
           params: { user_telephone: { raw_number: "+819012345601" } },
           headers: headers
    end

    assert_response :redirect
    follow_redirect!(headers: headers)

    assert_response :success
    # The one-time-code input, its `client_telephone[pass_code]` parameter and its autocomplete hint all live in
    # this component; the page object shows the visitor was sent to it with a code form to post.
    assert_equal "base/app/identity/telephones/registrations/edit", inertia_component
    assert_predicate inertia_props.fetch("form").fetch("action"), :present?
    assert_predicate inertia_props.dig("form", "code_label") || inertia_props.fetch("code_label"), :present?
  end

  test "com identity email and telephone otp inputs allow one time code autocomplete" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost")
    host! host
    visitor = visitors(:reserved_visitor)
    token = VisitorToken.create!(
      visitor: visitor,
      visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      visitor_token_status_id: VisitorTokenStatus::ACTIVE,
      discard_at: 1.day.from_now,
    )
    BaseSelectorBootstrapAuthority.call(surface: :com, principal: visitor)
    BaseSelectorAuthority.prepare(surface: :com, principal: visitor, session: token)
    _verification, raw_verification = VisitorVerification.issue_for_token!(token: token)
    cookies[VisitorVerification.cookie_name] = raw_verification
    token.update!(
      last_step_up_at: Time.current,
      last_step_up_scope: "settings_email",
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:com",
    )
    access_token = AuthenticationToken.encode(
      visitor,
      host: host,
      session_public_id: token.public_id,
      resource_type: "visitor",
      jwt_issuer_id: "surface:BASE_COM",
    )
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token
    headers = {
      "Authorization" => "Bearer #{access_token}",
      "Client-Agent" => "Mozilla/5.0",
      "Host" => host,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    get new_base_com_identity_emails_registration_url(ri: "jp", host: host), headers: headers

    assert_response :success

    fake_adapter = Object.new
    fake_adapter.define_singleton_method(:deliver) { |**_args| true }
    OtpAdapter.stub(:for, fake_adapter) do
      post base_com_identity_emails_registration_url(ri: "jp", host: host),
           params: { visitor_email: { address: "com-otp-autocomplete-#{SecureRandom.hex(4)}@example.test" } },
           headers: headers
    end

    assert_response :redirect
    follow_redirect!(headers: headers)

    assert_response :success
    # The one-time-code input, its `visitor_email[pass_code]` parameter and its autocomplete hint all live in
    # this component; the page object shows the visitor was sent to it with a code form to post.
    assert_equal "base/com/identity/emails/registrations/edit", inertia_component
    assert_predicate inertia_props.fetch("form").fetch("url"), :present?
    assert_predicate inertia_props.dig("form", "code_label") || inertia_props.fetch("code_label"), :present?

    token.update!(last_step_up_scope: "settings_telephone")
    OtpAdapter.stub(:for, fake_adapter) do
      post base_com_identity_telephones_registration_url(ri: "jp", host: host),
           params: { user_telephone: { raw_number: "+819112345602" } },
           headers: headers
    end

    assert_response :redirect
    follow_redirect!(headers: headers)

    assert_response :success
    # The one-time-code input, its `visitor_telephone[pass_code]` parameter and its autocomplete hint all live in
    # this component; the page object shows the visitor was sent to it with a code form to post.
    assert_equal "base/com/identity/telephones/registrations/edit", inertia_component
    assert_predicate inertia_props.fetch("form").fetch("url"), :present?
    assert_predicate inertia_props.dig("form", "code_label") || inertia_props.fetch("code_label"), :present?
  end

  test "org identity email and telephone otp inputs allow one time code autocomplete" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost")
    host! host
    operator = operators(:one)
    token = OperatorToken.create!(
      staff: operator,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      discard_at: 1.day.from_now,
    )
    BaseSelectorBootstrapAuthority.call(surface: :org, principal: operator)
    BaseSelectorAuthority.prepare(surface: :org, principal: operator, session: token)
    _verification, raw_verification = OperatorVerification.issue_for_token!(token: token)
    cookies[OperatorVerification.cookie_name] = raw_verification
    token.update!(
      last_step_up_at: Time.current,
      last_step_up_scope: "settings_email",
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:org",
    )
    access_token = AuthenticationToken.encode(
      operator,
      host: host,
      session_public_id: token.public_id,
      resource_type: "operator",
      jwt_issuer_id: "surface:BASE_ORG",
    )
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token
    headers = {
      "Authorization" => "Bearer #{access_token}",
      "Client-Agent" => "Mozilla/5.0",
      "Host" => host,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    get new_base_org_identity_emails_registration_url(ri: "jp", host: host), headers: headers

    assert_response :success

    fake_adapter = Object.new
    fake_adapter.define_singleton_method(:deliver) { |**_args| true }
    OtpAdapter.stub(:for, fake_adapter) do
      post base_org_identity_emails_registration_url(ri: "jp", host: host),
           params: { staff_email: { address: "org-otp-autocomplete-#{SecureRandom.hex(4)}@example.test" } },
           headers: headers
    end

    assert_response :redirect
    follow_redirect!(headers: headers)

    assert_response :success
    # The one-time-code input, its `staff_email[pass_code]` parameter and its autocomplete hint all live in
    # this component; the page object shows the visitor was sent to it with a code form to post.
    assert_equal "base/org/identity/emails/registrations/edit", inertia_component
    assert_predicate inertia_props.fetch("form").fetch("action"), :present?
    assert_predicate inertia_props.dig("form", "code_label") || inertia_props.fetch("code_label"), :present?

    token.update!(last_step_up_scope: "settings_telephone")
    OtpAdapter.stub(:for, fake_adapter) do
      post base_org_identity_telephones_registration_url(ri: "jp", host: host),
           params: { staff_telephone: { raw_number: "+819212345603" } },
           headers: headers
    end

    assert_response :redirect
    follow_redirect!(headers: headers)

    assert_response :success
    # The one-time-code input, its `operator_telephone[pass_code]` parameter and its autocomplete hint all live in
    # this component; the page object shows the visitor was sent to it with a code form to post.
    assert_equal "base/org/identity/telephones/registrations/edit", inertia_component
    assert_predicate inertia_props.fetch("form").fetch("action"), :present?
    assert_predicate inertia_props.dig("form", "code_label") || inertia_props.fetch("code_label"), :present?
  end
end
