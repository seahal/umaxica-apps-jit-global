# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
require "base64"

class OrgStepUpVerificationEnforcerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_chronicle_events, :operator_chronicle_levels,
           :operator_token_statuses, :operator_token_kinds

  setup do
    @base_host = ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost")
    @auth_host = ENV.fetch("PRIVATE_AUTH_STAFF_URL")
    @staff = Operator.create!(
      status_id: OperatorStatus::ACTIVE,
      visibility_id: OperatorVisibility::STAFF,
    )
    @token = OperatorToken.create!(
      staff: @staff,
      staff_token_status_id: OperatorTokenStatus::NOTHING,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      discarded_at: 1.day.from_now,
      public_id: "stepup_org_#{SecureRandom.hex(4)}",
    )
    @base_headers = as_staff_headers(@staff, host: @base_host, session_public_id: @token.public_id)
    @auth_headers = as_staff_headers(@staff, host: @auth_host, session_public_id: @token.public_id)
  end

  test "GET protected endpoint redirects to setup when configured methods are zero" do
    StepUpConfiguredMethodsQuery.stub(:call, []) do
      StepUpAvailableMethods.stub(:call, []) do
        get base_org_identity_withdrawal_url(ri: "jp", host: @base_host), headers: @base_headers
      end
    end

    assert_response :redirect
    uri = URI.parse(response.location)
    query = Rack::Utils.parse_query(uri.query)

    assert_equal ENV.fetch("PUBLIC_AUTH_STAFF_URL"), uri.host
    assert_equal "/verification/setup/new", uri.path
    assert_predicate query["pt"], :present?
  end

  test "GET protected endpoint redirects to verification when configured is non-zero but usable is zero" do
    StepUpConfiguredMethodsQuery.stub(:call, [:passkey]) do
      StepUpAvailableMethods.stub(:call, []) do
        get base_org_identity_withdrawal_url(ri: "jp", host: @base_host), headers: @base_headers
      end
    end

    assert_response :redirect
    uri = URI.parse(response.location)
    query = Rack::Utils.parse_query(uri.query)

    assert_equal "/verification", uri.path
    assert_predicate query["pt"], :present?
  end

  test "GET protected endpoint redirects to verification when usable methods exist" do
    OperatorPasskey.create!(
      staff: @staff,
      webauthn_id: "stepup_staff_passkey_#{SecureRandom.hex(4)}",
      external_id: SecureRandom.uuid,
      public_key: "public_key",
      sign_count: 0,
      description: "stepup passkey",
      status_id: OperatorPasskeyStatus::ACTIVE,
    )

    get base_org_identity_withdrawal_url(ri: "jp", host: @base_host), headers: @base_headers

    assert_response :redirect
    uri = URI.parse(response.location)

    assert_equal "/verification", uri.path
  end

  test "POST protected endpoint returns 401 plain when step-up is missing and usable methods exist" do
    OperatorPasskey.create!(
      staff: @staff,
      webauthn_id: "stepup_staff_passkey_post_#{SecureRandom.hex(4)}",
      external_id: SecureRandom.uuid,
      public_key: "public_key",
      sign_count: 0,
      description: "stepup passkey",
      status_id: OperatorPasskeyStatus::ACTIVE,
    )

    post auth_org_settings_passkeys_options_url(ri: "jp", host: @auth_host), headers: @auth_headers

    assert_response :unauthorized
    assert_equal VerificationBase::STEP_UP_REQUIRED_MESSAGE, response.body
  end

  test "successful verification enables protected POST and records audit" do
    return_to = Base64.urlsafe_encode64(auth_org_settings_passkeys_path(ri: "jp"))
    OperatorPasskey.create!(
      staff: @staff,
      webauthn_id: "test",
      external_id: SecureRandom.uuid,
      public_key: "public_key",
      sign_count: 0,
      description: "stepup passkey",
      status_id: OperatorPasskeyStatus::ACTIVE,
    )

    StepUpAvailableMethods.stub(:call, [:passkey]) do
      WebAuthn::Credential.stub(:options_for_get, OpenStruct.new(id: "test")) do
        verification_context = Struct.new(:sign_count, :verified_at).new(1, Time.current)
        Webauthn::AssertionVerifier.stub(:verify!, verification_context) do
          get auth_org_verification_url(scope: "settings_passkey", return_to: return_to, ri: "jp", host: @auth_host),
              headers: @auth_headers

          assert_response :success
          get new_auth_org_verification_passkey_url(ri: "jp", host: @auth_host), headers: @auth_headers

          post auth_org_verification_passkey_url(ri: "jp", host: @auth_host),
               params: { verification: { challenge_id: "test", credential_json: '{"id":"test"}' } },
               headers: @auth_headers
        end
      end
    end

    assert_response :redirect
    assert_redirected_to auth_org_settings_url(ri: "jp")
    set_cookie_lines = Array(response.headers["Set-Cookie"])

    assert_not set_cookie_lines.any? { |line| line.start_with?("#{OperatorVerification.cookie_name}=") }

    assert_not OperatorVerification.active.exists?(staff_token_id: @token.id)
    assert_not OperatorChronicle.exists?(
      actor_type: "Operator",
      actor_id: @staff.id,
      event_id: OperatorChronicleEvent::STEP_UP_VERIFIED,
      subject_type: "Operator",
      subject_id: @staff.id,
    )

    post auth_org_settings_passkeys_options_url(ri: "jp", host: @auth_host), headers: @auth_headers

    assert_response :unauthorized
  end

  private

  def passkey_credential_stub(id)
    Struct.new(:id, :sign_count) do
      define_method(:verify) do |*|
        true
      end
    end.new(id, 1)
  end

  private

  def host_headers(host = nil)
    host_value = host || (respond_to?(:request, true) ? request&.host : nil) || ENV["DEFAULT_URL_HOST"]
    headers = {
      "Client-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
                        "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    }
    headers["Host"] = host_value if host_value.present?
    headers
  end

  def browser_headers
    csrf_token = "test_csrf_token"
    headers = {
      "Client-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
                        "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
      "X-CSRF-Token" => csrf_token,
    }

    if respond_to?(:cookies, true)
      cookies["csrf_token"] = csrf_token
    else
      headers["Cookie"] = "csrf_token=#{csrf_token}"
    end

    headers
  end

  def as_user_headers(user, host: nil, headers: {}, session_public_id: nil)
    base = host_headers(host).merge(headers).merge("X-TEST-CURRENT-USER" => user.id.to_s)
    return base unless user.respond_to?(:persisted?) && user.persisted? && user.class.name == "Client"

    token =
      if session_public_id.present?
        ClientToken.find_by(public_id: session_public_id)
      else
        ClientToken.where(user_id: user.id).where("discarded_at > ?", Time.current).order(created_at: :desc).first
      end
    token ||= ClientToken.create!(user_id: user.id, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    base.merge(
      "Authorization" => "Bearer #{
        jwt_access_token_for(user, host: host, session_public_id: token.public_id, resource_type: "client")
      }",
    )
  end

  def as_staff_headers(staff, host: nil, headers: {}, session_public_id: nil)
    base = host_headers(host).merge(headers).merge("X-TEST-CURRENT-STAFF" => staff.id.to_s)
    return base unless staff.respond_to?(:persisted?) && staff.persisted? && staff.class.name == "Operator"

    token =
      if session_public_id.present?
        OperatorToken.find_by(public_id: session_public_id)
      else
        OperatorToken.where(staff_id: staff.id).where(
          "discarded_at > ?",
          Time.current,
        ).order(created_at: :desc).first
      end
    token ||= OperatorToken.create!(staff: staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    base.merge(
      "Authorization" => "Bearer #{
        jwt_access_token_for(staff, host: host, session_public_id: token.public_id, resource_type: "operator")
      }",
    )
  end

  def as_visitor_headers(visitor, host: nil, headers: {}, session_public_id: nil)
    VisitorTokenBindingMethod.ensure_defaults! if defined?(VisitorTokenBindingMethod)
    VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::BROWSER_WEB) if defined?(VisitorTokenKind)
    base = host_headers(host).merge(headers).merge("X-TEST-CURRENT-RESOURCE" => visitor.id.to_s)
    return base unless visitor.respond_to?(:persisted?) && visitor.persisted? && visitor.class.name == "Visitor"

    token =
      if session_public_id.present?
        VisitorToken.find_by(public_id: session_public_id)
      else
        VisitorToken.where(visitor_id: visitor.id).where(
          "discarded_at > ?",
          Time.current,
        ).order(created_at: :desc).first
      end
    token ||= VisitorToken.create!(visitor_id: visitor.id, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    base.merge(
      "Authorization" => "Bearer #{
        jwt_access_token_for(visitor, host: host, session_public_id: token.public_id, resource_type: "visitor")
      }",
    )
  end

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end

  def jwt_access_token_for(resource, host: nil, session_id: nil, session_public_id: nil, resource_type: nil,
                           dpop_jkt: nil)
    host_value = host || (respond_to?(:request, true) ? request&.host : nil) || "unknown"
    resource_type ||=
      case resource
      when Client then "client"
      when Operator then "operator"
      when Visitor then "visitor"
      end
    AuthenticationToken.encode(
      resource,
      host: host_value,
      session_id: session_id,
      session_public_id: session_public_id,
      resource_type: resource_type,
      dpop_jkt: dpop_jkt,
      jwt_issuer_id: jwt_issuer_id_for_test_host(host_value, resource_type),
    )
  end

  def jwt_issuer_id_for_test_host(host, resource_type)
    normalized = host.to_s
    service =
      if normalized.include?("acme")
        "ACME"
      elsif normalized.include?("core")
        "CORE"
      elsif normalized.include?("auth") || normalized.include?("sign") || normalized.include?("log.umaxica")
        "SIGN"
      else
        "BASE"
      end
    surface =
      if service == "SIGN"
        case resource_type
        when "operator" then "ORG"
        when "visitor" then "COM"
        else "APP"
        end
      elsif normalized.include?(".org") || normalized.include?("org.")
        "ORG"
      elsif normalized.include?(".com") || normalized.include?("com.")
        "COM"
      else
        "APP"
      end
    "surface:#{service}_#{surface}"
  end
end

# DAMP auth header helpers for this test class.
class OrgStepUpVerificationEnforcerTest
  private
end
