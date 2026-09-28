# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
require "base64"

class Auth::App::Verification::PasskeysControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients

  setup do
    @host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
    @user = clients(:one)
    ClientEmail.create!(
      user: @user,
      address: "app-passkey-stepup-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    @headers = as_user_headers(@user, host: @host)
    @token = ClientToken.find_by!(public_id: @headers["X-TEST-SESSION-PUBLIC-ID"])
    @user.client_passkeys.create!(
      description: "Test passkey",
      webauthn_id: "test",
      public_key: "public_key",
      sign_count: 0,
      status_id: ClientPasskeyStatus::ACTIVE,
    )
    @step_up_return_to = "/settings/emails?ri=jp"
    @step_up_pt = ActiveSupport::MessageVerifier.new(
      Rails.application.key_generator.generate_key("path_target_token", 32),
      digest: "SHA256", serializer: JSON, url_safe: true,
    ).generate(
      {
        "flow" => "step_up.bootstrap",
        "surface" => "app",
        "session_nonce" => @token.public_id.to_s,
        "pt" => @step_up_return_to,
      },
      purpose: :path_target,
      expires_in: 15.minutes,
    )
  end

  test "creates verification on success" do
    return_to = Base64.urlsafe_encode64("/settings/emails?ri=jp")

    StepUpAvailableMethods.stub(:call, [:passkey]) do
      WebAuthn::Credential.stub(:options_for_get, OpenStruct.new(id: "test")) do
        verification_context = Struct.new(:sign_count, :verified_at).new(1, Time.current)
        Webauthn::AssertionVerifier.stub(:verify!, verification_context) do
          get auth_app_verification_url(scope: "settings_email", return_to: return_to, ri: "jp"),
              headers: @headers

          assert_response :success

          get new_auth_app_verification_passkey_url(
            ri: "jp",
            scope: "settings_email",
            return_to: return_to,
          ), headers: @headers

          assert_response :redirect
          assert_redirected_to auth_app_settings_url(ri: "jp")
        end
      end
    end
  end

  # A Base-initiated Step-Up is cancelled by handing off to Base's fixed cancellation endpoint. The
  # handoff carries no destination: the success continuation is not sent as a return_to.
  test "cancelling a Base-initiated step-up hands off without a return_to" do
    # The Base-initiated state lives in the session cookie, so the cookie jar must use the Auth host.
    host! @headers.fetch("Host")
    grant = IdentityStepUpCeremonyGrantIssuer.issue!(
      surface: "app",
      actor_ref: @user.public_id,
      session_ref: @token.public_id,
      required_scope: "settings_email",
      required_aal: "aal2",
      allowed_methods: %i(passkey),
      return_to: @step_up_return_to,
      expires_at: 15.minutes.from_now,
    ).grant

    StepUpAvailableMethods.stub(:call, [:passkey]) do
      get auth_app_verification_path(
        scope: "settings_email", pt: @step_up_pt, ri: "jp", step_up_ceremony_grant: grant,
        step_up_completion_csrf: "base-csrf",
      ), headers: @headers
    end

    assert_response :success

    StepUpAvailableMethods.stub(:call, [:passkey]) do
      post auth_app_verification_cancellation_path(ri: "jp"),
           params: { return_to: "/sign/in/challenge", pt: @step_up_pt },
           headers: @headers
    end

    assert_response :success
    assert_includes response.body, base_app_verification_cancellation_url(host: ENV.fetch("PUBLIC_BASE_SERVICE_URL"))
    assert_not_includes response.body, 'name="return_to"'
    assert_not_includes response.body, @step_up_return_to
    assert_nil @token.reload.step_up_session
  end

  test "new renders the passkey step-up page with a bound challenge" do
    grant = IdentityStepUpCeremonyGrantIssuer.issue!(
      surface: "app",
      actor_ref: @user.public_id,
      session_ref: @token.public_id,
      required_scope: "settings_email",
      required_aal: "aal2",
      allowed_methods: %i(passkey),
      return_to: @step_up_return_to,
      expires_at: 15.minutes.from_now,
    ).grant

    StepUpAvailableMethods.stub(:call, [:passkey]) do
      WebAuthn::Credential.stub(:options_for_get, OpenStruct.new(id: "test")) do
        get auth_app_verification_url(
          scope: "settings_email", pt: @step_up_pt, ri: "jp", step_up_ceremony_grant: grant,
        ), headers: @headers

        assert_response :success

        get new_auth_app_verification_passkey_url(
          ri: "jp", scope: "settings_email", pt: @step_up_pt,
        ), headers: @headers
      end
    end

    assert_response :success
    assert_equal "auth/app/verification/passkeys/new", inertia_component
    assert_predicate inertia_props.fetch("form").fetch("challenge_id"), :present?
    # Back returns to method selection; Cancel ends the whole Step-Up ceremony.
    assert_equal auth_app_verification_path(ri: "jp", scope: "settings_email", pt: @step_up_pt),
                 inertia_props.fetch("back").fetch("href")
    assert_equal(
      { "label" => I18n.t("actions.cancel"),
        "action" => auth_app_verification_cancellation_path(ri: "jp"),
        "method" => "post", },
      inertia_props.fetch("cancel"),
    )
  end

  test "a rejected assertion re-renders the passkey step-up page without granting freshness" do
    grant = IdentityStepUpCeremonyGrantIssuer.issue!(
      surface: "app",
      actor_ref: @user.public_id,
      session_ref: @token.public_id,
      required_scope: "settings_email",
      required_aal: "aal2",
      allowed_methods: %i(passkey),
      return_to: @step_up_return_to,
      expires_at: 15.minutes.from_now,
    ).grant

    StepUpAvailableMethods.stub(:call, [:passkey]) do
      WebAuthn::Credential.stub(:options_for_get, OpenStruct.new(id: "test")) do
        get auth_app_verification_url(
          scope: "settings_email", pt: @step_up_pt, ri: "jp", step_up_ceremony_grant: grant,
        ), headers: @headers
        get new_auth_app_verification_passkey_url(
          ri: "jp", scope: "settings_email", pt: @step_up_pt,
        ), headers: @headers
        challenge_id = inertia_props.fetch("form").fetch("challenge_id")

        Webauthn::AssertionVerifier.stub(
          :verify!, ->(**_kwargs) { raise Webauthn::AssertionVerifier::VerificationError, "rejected" },
        ) do
          post auth_app_verification_passkey_url(ri: "jp", scope: "settings_email", pt: @step_up_pt), params: {
            challenge_id: challenge_id,
            credential: {
              id: "test",
              rawId: "test",
              type: "public-key",
              response: { clientDataJSON: "e30=", authenticatorData: "e30=", signature: "sig" },
            },
          }, headers: @headers
        end
      end
    end

    assert_response :unprocessable_content
    assert_nil @token.reload.last_step_up_at
  end

  test "new keeps scope and return_to in form hidden fields" do
    return_to = Base64.urlsafe_encode64("/settings/emails?ri=jp")

    StepUpAvailableMethods.stub(:call, [:passkey]) do
      WebAuthn::Credential.stub(:options_for_get, OpenStruct.new(id: "test")) do
        get auth_app_verification_url(scope: "settings_email", return_to: return_to, ri: "jp"),
            headers: @headers

        assert_response :success

        get new_auth_app_verification_passkey_url(
          ri: "jp",
          scope: "settings_email",
          return_to: return_to,
        ), headers: @headers

        assert_response :redirect
        assert_redirected_to auth_app_settings_url(ri: "jp")
      end
    end
  end

  test "new keeps scope and pt in form hidden fields" do
    return_to = Base64.urlsafe_encode64(new_auth_app_settings_passkey_path(ri: "jp"))

    StepUpAvailableMethods.stub(:call, [:passkey]) do
      WebAuthn::Credential.stub(:options_for_get, OpenStruct.new(id: "test")) do
        get auth_app_verification_url(scope: "settings_passkey", return_to: return_to, ri: "jp"),
            headers: @headers

        assert_response :success
        assert_equal "auth/app/verifications/show", inertia_component
        assert(
          inertia_props.fetch("methods").any? do |method|
            method.fetch("href").start_with?(new_auth_app_verification_passkey_path(ri: "jp"))
          end,
        )

        get new_auth_app_verification_passkey_url(
          ri: "jp",
          scope: "settings_passkey",
          pt: return_to,
        ), headers: @headers

        assert_response :redirect
        assert_redirected_to auth_app_settings_url(ri: "jp")
      end
    end
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

    if user.respond_to?(:persisted?) && user.persisted? && user.class.name == "Client"
      token =
        if session_public_id.present?
          ClientToken.find_by(public_id: session_public_id)
        else
          ClientToken.where(user_id: user.id).where("discard_at > ?", Time.current).order(created_at: :desc).first
        end
      token ||= ClientToken.create!(user_id: user.id, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
      base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    end

    if token
      base.merge(
        "Authorization" => "Bearer #{
        jwt_access_token_for(user, host: host, session_public_id: token.public_id, resource_type: "client")
      }",
      )
    else
      base
    end
  end

  def as_staff_headers(staff, host: nil, headers: {}, session_public_id: nil)
    base = host_headers(host).merge(headers).merge("X-TEST-CURRENT-STAFF" => staff.id.to_s)

    if staff.respond_to?(:persisted?) && staff.persisted? && staff.class.name == "Operator"
      token =
        if session_public_id.present?
          OperatorToken.find_by(public_id: session_public_id)
        else
          OperatorToken.where(staff_id: staff.id).where(
            "discard_at > ?",
            Time.current,
          ).order(created_at: :desc).first
        end
      token ||= OperatorToken.create!(staff: staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
      base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    end

    if token
      base.merge(
        "Authorization" => "Bearer #{
        jwt_access_token_for(staff, host: host, session_public_id: token.public_id, resource_type: "operator")
      }",
      )
    else
      base
    end
  end

  def as_visitor_headers(visitor, host: nil, headers: {}, session_public_id: nil)
    VisitorTokenBindingMethod.ensure_defaults! if defined?(VisitorTokenBindingMethod)
    VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::BROWSER_WEB) if defined?(VisitorTokenKind)
    base = host_headers(host).merge(headers).merge("X-TEST-CURRENT-RESOURCE" => visitor.id.to_s)

    if visitor.respond_to?(:persisted?) && visitor.persisted? && visitor.class.name == "Visitor"
      token =
        if session_public_id.present?
          VisitorToken.find_by(public_id: session_public_id)
        else
          VisitorToken.where(visitor_id: visitor.id).where(
            "discard_at > ?",
            Time.current,
          ).order(created_at: :desc).first
        end
      token ||= VisitorToken.create!(visitor_id: visitor.id, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
      base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    end

    if token
      base.merge(
        "Authorization" => "Bearer #{
        jwt_access_token_for(visitor, host: host, session_public_id: token.public_id, resource_type: "visitor")
      }",
      )
    else
      base
    end
  end

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end
end

# DAMP auth header helpers for this test class.
class Auth::App::Verification::PasskeysControllerTest
  private

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
    service = normalized.include?("acme") ? "ACME" : (normalized.include?("core") ? "CORE" : "SIGN")
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
