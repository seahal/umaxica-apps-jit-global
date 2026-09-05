# typed: false
# frozen_string_literal: true

require "test_helper"
require "support/external_identity_test_helper"
# require "helpers/global_test_support"

class Auth::App::Omniauth::OmniauthCallbacksControllerTest < ActiveSupport::TestCase
  counts_rate_limits!
  include ExternalIdentityTestHelper

  test "callback routes accept GET only" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
    google_route = Rails.application.routes.recognize_path(
      "http://#{host}/social/google/callback",
      method: :get,
    )
    apple_get_route = Rails.application.routes.recognize_path(
      "http://#{host}/social/apple/callback",
      method: :get,
    )

    assert_equal "auth/app/omniauth/omniauth_callbacks", google_route[:controller]
    assert_equal "omniauth", google_route[:action]
    assert_equal "google", google_route[:provider]
    assert_equal "auth/app/omniauth/omniauth_callbacks", apple_get_route[:controller]
    assert_equal "omniauth", apple_get_route[:action]
    assert_equal "apple", apple_get_route[:provider]

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{host}/social/google/callback", method: :post)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{host}/social/apple/callback", method: :post)
    end
  end

  test "direct success and failure branches" do
    controller = Auth::App::Omniauth::OmniauthCallbacksController.new
    session_hash = {}
    redirects = []
    safe_redirects = []
    hard_rejects = []

    request = ActionDispatch::TestRequest.create(
      "REQUEST_METHOD" => "GET",
      "HTTP_HOST" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"),
      "REMOTE_ADDR" => "127.0.0.1",
    )
    controller.request = request
    controller.response = ActionDispatch::TestResponse.new

    controller.define_singleton_method(:session) { session_hash }
    controller.define_singleton_method(:params) { ActionController::Parameters.new(ri: "jp", provider: "apple") }
    controller.define_singleton_method(:redirect_to) { |*args, **kwargs| redirects << [args, kwargs] }
    controller.define_singleton_method(:redirect_to_jump_url) { |url, **kwargs| redirects << [[url], kwargs] }
    controller.define_singleton_method(:safe_redirect_to) { |*args, **kwargs| safe_redirects << [args, kwargs] }
    controller.define_singleton_method(:render_session_limit_hard_reject) { |**kwargs| hard_rejects << kwargs }
    controller.define_singleton_method(:auth_app_sign_in_path) { |ri: nil|
      "/sign/in#{ri ? "?ri=#{ri}" : ""}"
    }
    controller.define_singleton_method(:auth_app_sign_up_path) { |ri: nil|
      "/sign/up#{ri ? "?ri=#{ri}" : ""}"
    }
    controller.define_singleton_method(:auth_app_settings_path) { |ri: nil| "/settings?ri=#{ri}" }
    controller.define_singleton_method(:auth_app_dashboard_path) { |ri: nil, pt: nil|
      "/dashboard?ri=#{ri}#{pt ? "&pt=#{pt}" : ""}"
    }
    controller.define_singleton_method(:auth_app_sign_in_session_path) { "/sign/in/session" }
    controller.define_singleton_method(:auth_app_sign_in_check_path) do |ri: nil, pt: nil|
      "/sign/in/check?ri=#{ri}#{pt ? "&pt=#{pt}" : ""}"
    end
    sign_in_sequence_redirects = []
    controller.define_singleton_method(:redirect_to_sign_in_sequence!) do |**kwargs|
      sign_in_sequence_redirects << kwargs
      "/dashboard"
    end
    controller.define_singleton_method(:social_auth_success_redirect_path) { "/settings" }
    controller.define_singleton_method(:issue_bulletin!) { @issue_bulletin_for_test }
    controller.define_singleton_method(:logged_in?) { @logged_in_for_test }
    controller.define_singleton_method(:current_resource) { @resource_for_test }
    controller.define_singleton_method(:establish_signed_in_session!) { |*| @login_result_for_test }

    user = Client.create!(status_id: ClientStatus::NOTHING)

    controller.send(:handle_link_intent, "Apple")

    assert_match "/settings", redirects.last.first.first

    controller.instance_variable_set(:@issue_bulletin_for_test, true)

    assert_equal "/dashboard", controller.send(:redirect_for_existing_account, "Apple")

    controller.instance_variable_set(:@issue_bulletin_for_test, false)

    assert_equal "/dashboard", controller.send(:redirect_for_new_account, "Apple")
    assert_equal({ pt: nil }, sign_in_sequence_redirects.last)

    controller.instance_variable_set(:@login_result_for_test, { status: :success, restricted: true })
    controller.send(:handle_login_intent, user, "Apple", false)

    assert_match "/sign/in/session", redirects.last.first.first

    controller.instance_variable_set(:@login_result_for_test, true)
    controller.send(:handle_login_intent, user, "Apple", true)

    assert_match "/sign/in?ri=jp", redirects.last.first.first

    controller.send(
      :handle_login_failure,
      { status: :session_limit_hard_reject, message: "full", http_status: :too_many_requests }, "Apple", user,
    )

    assert_equal({ message: "full", http_status: :too_many_requests }, hard_rejects.last)

    controller.send(:handle_login_failure, { status: :mfa_required, redirect_path: "/mfa" }, "Apple", user)

    assert_equal [["/mfa"], { fallback: "/sign/in" }], safe_redirects.last

    controller.send(:handle_login_failure, { status: :unknown }, "Apple", user)

    assert_match "/sign/in", redirects.last.first.first

    auth = OpenStruct.new(provider: "apple")
    controller.define_singleton_method(:clear_social_auth_intent!) { @cleared_for_test = true }
    error = StandardError.new("boom")

    assert_raises(StandardError) do
      controller.send(:handle_unexpected_error, error, auth)
    end

    assert controller.instance_variable_get(:@cleared_for_test)
    session_hash[SocialAuth::SOCIAL_ENTRY_SESSION_KEY] = "sign_up"
    session_hash[SocialAuth::SOCIAL_RI_SESSION_KEY] = "jp"

    assert_raises(StandardError) do
      controller.send(:handle_unexpected_error, error, auth)
    end
  end

  test "current social auth intent requires explicit server-side link state" do
    controller = Auth::App::Omniauth::OmniauthCallbacksController.new
    session_hash = {}
    user = Client.create!(status_id: ClientStatus::NOTHING)
    request = ActionDispatch::TestRequest.create(
      "REQUEST_METHOD" => "GET",
    )
    controller.request = request
    controller.response = ActionDispatch::TestResponse.new

    controller.define_singleton_method(:session) { session_hash }
    controller.define_singleton_method(:params) { ActionController::Parameters.new(provider: "apple") }
    controller.define_singleton_method(:logged_in?) { @logged_in_for_test }
    controller.define_singleton_method(:current_resource) { @resource_for_test }

    controller.instance_variable_set(:@logged_in_for_test, true)
    controller.instance_variable_set(:@resource_for_test, user)

    assert_equal "login", controller.send(:current_social_auth_intent)
    assert_nil session_hash[SocialAuth::SOCIAL_USER_ID_SESSION_KEY]

    session_hash[SocialAuth::SOCIAL_INTENT_SESSION_KEY] = "link"

    assert_equal "link", controller.send(:current_social_auth_intent)
  end

  test "new social login records provider in audit context" do
    controller = Auth::App::Omniauth::OmniauthCallbacksController.new
    redirects = []

    request = ActionDispatch::TestRequest.create(
      "REQUEST_METHOD" => "GET",
      "HTTP_HOST" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"),
    )
    request.env["omniauth.auth"] = OpenStruct.new(provider: "google")
    controller.request = request
    controller.response = ActionDispatch::TestResponse.new

    session_hash = {}
    controller.define_singleton_method(:session) { session_hash }
    controller.define_singleton_method(:params) { ActionController::Parameters.new(ri: "jp", provider: "google") }
    controller.define_singleton_method(:redirect_to) { |*args, **kwargs| redirects << [args, kwargs] }
    sign_in_sequence_redirects = []
    controller.define_singleton_method(:redirect_to_sign_in_sequence!) do |**kwargs|
      sign_in_sequence_redirects << kwargs
      "/dashboard"
    end
    controller.define_singleton_method(:issue_bulletin!) { false }
    controller.define_singleton_method(:auth_app_settings_path) { |ri: nil| "/settings?ri=#{ri}" }
    controller.define_singleton_method(:auth_app_dashboard_path) { |ri: nil, pt: nil|
      "/dashboard?ri=#{ri}#{pt ? "&pt=#{pt}" : ""}"
    }
    controller.define_singleton_method(:establish_signed_in_session!) do |*args, **kwargs|
      @complete_sign_in_args_for_test = args
      @complete_sign_in_kwargs_for_test = kwargs
      { status: :success }
    end

    user = Client.create!(status_id: ClientStatus::NOTHING)
    return_to = "/after-social"

    assert_equal "/dashboard", controller.send(:handle_login_intent, user, "Google", false, pt: return_to)
    assert_equal({ pt: return_to }, sign_in_sequence_redirects.last)

    kwargs = controller.instance_variable_get(:@complete_sign_in_kwargs_for_test)

    assert_equal return_to, kwargs[:pt]
    assert_equal "social", kwargs[:auth_method]
    assert_equal({ auth_method: "social", provider: "google" }, kwargs[:audit_context])
  end

  test "grantless established google login does not create sign session" do
    assert_grantless_established_social_login_rejected(provider: "google", provider_name: "Google")
  end

  test "grantless established apple login does not create sign session" do
    assert_grantless_established_social_login_rejected(provider: "apple", provider_name: "Apple")
  end

  test "login is rejected when google is locked by an in-force method_protection case" do
    assert_locked_authentication_method_login_rejected(provider: "google", provider_name: "Google", effect: "unusable")
  end

  test "login is rejected when apple is locked by an in-force method_protection case" do
    assert_locked_authentication_method_login_rejected(provider: "apple", provider_name: "Apple", effect: "unusable")
  end

  test "login proceeds when the locked method_protection case targets a different provider" do
    controller = Auth::App::Omniauth::OmniauthCallbacksController.new
    redirects = []
    sign_in_sequence_redirects = []

    user = Client.create!(status_id: ClientStatus::ACTIVE, birthdate: "2000-02-03")
    admin_operator = operators(:one)
    the_case = AppEnforcementCase.new(
      kind: "method_protection",
      duration_mode: "indefinite",
      visibility: "visible",
      release_mode: "operator",
      effective_at: Time.current,
      reason_code: "security_incident",
      principal_public_id: user.public_id,
      applied_by_operator_public_id: admin_operator.public_id,
    )
    the_case.authentication_method_effects.build(
      principal_public_id: user.public_id,
      authentication_method: "apple",
      effect: "unusable",
      effective_at: Time.current,
    )
    EnforcementCaseApplyOperation.call(enforcement_case: the_case)

    request = ActionDispatch::TestRequest.create(
      "REQUEST_METHOD" => "GET",
      "HTTP_HOST" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"),
    )
    request.env["omniauth.auth"] = OpenStruct.new(provider: "google")
    controller.request = request
    controller.response = ActionDispatch::TestResponse.new

    session_hash = {}
    controller.define_singleton_method(:session) { session_hash }
    controller.define_singleton_method(:params) { ActionController::Parameters.new(ri: "jp", provider: "google") }
    controller.define_singleton_method(:redirect_to) { |*args, **kwargs| redirects << [args, kwargs] }
    controller.define_singleton_method(:auth_app_sign_in_path) { |ri: nil| "/sign/in#{ri ? "?ri=#{ri}" : ""}" }
    controller.define_singleton_method(:redirect_to_sign_in_sequence!) do |**kwargs|
      sign_in_sequence_redirects << kwargs
      "/dashboard"
    end
    controller.define_singleton_method(:establish_signed_in_session!) { |*, **| { status: :success } }

    assert_equal "/dashboard", controller.send(:handle_login_intent, user, "Google", false, pt: "/after-social")
    assert_equal({ pt: "/after-social" }, sign_in_sequence_redirects.last)
    assert_empty redirects
  end

  test "social login result log payload excludes bearer credentials" do
    controller = Auth::App::Omniauth::OmniauthCallbacksController.new
    payload = controller.send(
      :social_login_result_log_payload,
      {
        status: :success,
        access_token: "access-secret_credential",
        refresh_token: "refresh-secret_credential",
        token_type: "Bearer",
        expires_in: 3600,
        dbsc: {
          binding_method: "legacy",
          status: "nothing",
          session_id: "session-secret_credential",
          registration_url: "/edge/v0/token/dbsc",
        },
      },
    )

    assert_equal :success, payload[:status]
    assert_equal "Bearer", payload[:token_type]
    assert_equal 3600, payload[:expires_in]
    assert_equal({ binding_method: "legacy", status: "nothing", session_id_present: true }, payload[:dbsc])
    assert_not_includes payload.keys, :access_token
    assert_not_includes payload.keys, :refresh_token
    assert_not_includes payload[:dbsc].keys, :session_id
    assert_not_includes payload[:dbsc].keys, :registration_url
  end

  test "social login success forwards slim session state into authenticated login" do
    controller = Auth::App::Omniauth::OmniauthCallbacksController.new
    session_hash = { "legacy_anonymous_key" => "legacy-value" }
    session_snapshots = []
    login_resource = nil
    login_kwargs = nil
    user = Client.create!(status_id: ClientStatus::NOTHING)

    request = ActionDispatch::TestRequest.create(
      "REQUEST_METHOD" => "GET",
      "HTTP_HOST" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"),
    )
    request.env["omniauth.auth"] = OpenStruct.new(provider: "google")
    controller.request = request
    controller.response = ActionDispatch::TestResponse.new

    controller.define_singleton_method(:session) { session_hash }
    controller.define_singleton_method(:params) { ActionController::Parameters.new(ri: "jp", provider: "google") }
    controller.define_singleton_method(:redirect_to) { |*args, **kwargs|
      session_snapshots << [:redirect_to, args, kwargs]
    }
    controller.define_singleton_method(:redirect_to_sign_in_sequence!) { |**_kwargs| "/dashboard" }
    controller.define_singleton_method(:issue_bulletin!) { false }
    controller.define_singleton_method(:auth_app_dashboard_path) { |ri: nil, pt: nil|
      "/dashboard?ri=#{ri}#{pt ? "&pt=#{pt}" : ""}"
    }
    controller.define_singleton_method(:auth_app_sign_in_path) { |ri: nil| "/sign/in#{ri ? "?ri=#{ri}" : ""}" }
    controller.define_singleton_method(:establish_signed_in_session!) do |resource, **kwargs|
      login_resource = resource
      login_kwargs = kwargs
      session_snapshots << [:establish_signed_in_session, kwargs, session_hash.dup]
      { status: :success }
    end

    assert_equal "/dashboard", controller.send(
      :handle_login_intent,
      user,
      "Google",
      false,
      pt: "/after-social",
    )

    assert_equal user, login_resource
    assert_equal "/after-social", login_kwargs[:pt]
    assert_equal "jp", login_kwargs[:ri]
    assert_equal "social", login_kwargs[:auth_method]
    assert_equal({ auth_method: "social", provider: "google" }, login_kwargs[:audit_context])
    assert_equal "legacy-value", session_snapshots.dig(0, 2, "legacy_anonymous_key")
    assert_equal "legacy-value", session_hash["legacy_anonymous_key"]
    assert session_snapshots.any? { |kind, *| kind == :establish_signed_in_session }
  end

  test "social auth intent stores only slim session keys" do
    controller = Auth::App::Omniauth::OmniauthCallbacksController.new
    session_hash = {}

    request = ActionDispatch::TestRequest.create(
      "REQUEST_METHOD" => "GET",
      "HTTP_HOST" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"),
    )
    controller.request = request
    controller.response = ActionDispatch::TestResponse.new

    controller.define_singleton_method(:session) { session_hash }
    controller.define_singleton_method(:params) { ActionController::Parameters.new(ri: "jp", provider: "google") }
    controller.define_singleton_method(:issue_bulletin!) { false }

    state = controller.send(
      :prepare_social_auth_intent!,
      "login",
      provider: "google",
      pt: "encoded-pt-that-should-not-be-stored",
      entry: "sign_up",
      ri: "jp",
    )

    assert_predicate state, :present?
    assert_nil session_hash[SocialAuth::SOCIAL_INTENT_SESSION_KEY]
    assert_nil session_hash[SocialAuth::SOCIAL_PROVIDER_SESSION_KEY]
    assert_equal "jp", session_hash[SocialAuth::SOCIAL_RI_SESSION_KEY]
    assert_equal "sign_up", session_hash[SocialAuth::SOCIAL_ENTRY_SESSION_KEY]
    assert_nil session_hash[SocialAuth::SOCIAL_PT_SESSION_KEY]
    assert_nil session_hash[:omniauth]
    assert_nil session_hash[:auth_hash]
    assert_nil session_hash[:raw_info]
    assert_nil session_hash[:access_token]
    assert_nil session_hash[:refresh_token]
    assert_nil session_hash[:id_token]

    serialized_size = Marshal.dump(session_hash).bytesize

    assert_operator serialized_size, :<, 512
  end

  test "social sign up entry routes new identity to sign up guardrail without signing in" do
    ClientSignUpFlowStatus.ensure_defaults!
    ClientSignUpFlowCleanupStatus.ensure_defaults!
    user = Client.create!(status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    identity = create_active_external_identity(client: user, provider: "google", subject: "social-signup-guardrail")
    cycle = ClientSignUpFlow.create!(
      principal_id: nil,
      status_id: ClientSignUpFlowStatus::SOCIAL_CALLBACK_PENDING,
      step: "social_callback",
      nonce_digest: ClientSignUpFlow.digest_nonce("nonce"),
      issued_at: Time.current,
      expires_at: 15.minutes.from_now,
      cleanup_status_id: ClientSignUpFlowCleanupStatus::IDLE,
      entry_method: "google",
      social_provider: "google",
    )
    locator = Struct.new(:current).new(cycle)
    controller = Auth::App::Omniauth::OmniauthCallbacksController.new
    redirects = []

    request = ActionDispatch::TestRequest.create(
      "REQUEST_METHOD" => "GET",
      "HTTP_HOST" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"),
    )
    request.env["omniauth.auth"] = OpenStruct.new(provider: "google")
    controller.request = request
    controller.response = ActionDispatch::TestResponse.new

    session_hash = {}
    controller.define_singleton_method(:session) { session_hash }
    controller.define_singleton_method(:params) { ActionController::Parameters.new(ri: "jp", provider: "google") }
    controller.define_singleton_method(:redirect_to) { |*args, **kwargs| redirects << [args, kwargs] }
    controller.define_singleton_method(:auth_app_sign_up_guard_path) { |ri: nil, pt: nil|
      "/sign/up/guard?ri=#{ri}#{pt ? "&pt=#{pt}" : ""}"
    }
    controller.define_singleton_method(:sign_up_flow_locator) { locator }
    controller.define_singleton_method(:establish_signed_in_session!) { raise StandardError, "should not sign in" }

    controller.send(
      :handle_successful_auth,
      user,
      "login",
      "Google",
      identity,
      existing_account: false,
      pt: "encoded-pt",
    )

    assert_match %r{/sign/up/guard/google\?(pt=encoded-pt&ri=jp|ri=jp&pt=encoded-pt)}, redirects.last.first.first

    assert_equal user.id, cycle.reload.principal_id
    assert_equal "social_identity", cycle.pending_contact_type
    assert_equal identity.id, cycle.pending_contact_id
    assert_equal "checkpoint", cycle.step
  end

  test "social callback sign up cycle stores decoded pt as return_to" do
    ClientSignUpFlowStatus.ensure_defaults!
    ClientSignUpFlowCleanupStatus.ensure_defaults!
    user = Client.create!(status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    identity = create_active_external_identity(client: user, provider: "google", subject: "social-signup-return-to")
    issued_cycles = []
    controller = Auth::App::Omniauth::OmniauthCallbacksController.new
    session_hash = {}

    controller.define_singleton_method(:session) { session_hash }
    controller.define_singleton_method(:signed_pt_token) { |value| "signed:#{value}" }
    controller.define_singleton_method(:path_from_signed_pt) do |value|
      (value == "signed:/after-social") ? "/after-social" : nil
    end
    controller.define_singleton_method(:sign_up_flow_locator) do
      Struct.new(:issued_cycles) do
        def issue!(cycle)
          issued_cycles << cycle
        end
      end.new(issued_cycles)
    end

    cycle = controller.send(:create_social_sign_up_flow!, user, identity, pt: "/after-social")

    assert_equal "/after-social", cycle.return_to
    assert_equal [cycle], issued_cycles
    assert_equal cycle.public_id, session_hash[:auth_app_up_sequence_id]
  end

  test "social sign up entry with existing identity rejects sign-side session creation" do
    controller = Auth::App::Omniauth::OmniauthCallbacksController.new
    redirects = []

    request = ActionDispatch::TestRequest.create(
      "REQUEST_METHOD" => "GET",
      "HTTP_HOST" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"),
    )
    request.env["omniauth.auth"] = OpenStruct.new(provider: "google")
    controller.request = request
    controller.response = ActionDispatch::TestResponse.new

    session_hash = {}
    controller.define_singleton_method(:session) { session_hash }
    controller.define_singleton_method(:params) { ActionController::Parameters.new(ri: "jp", provider: "google") }
    controller.define_singleton_method(:redirect_to) { |*args, **kwargs| redirects << [args, kwargs] }
    controller.define_singleton_method(:issue_bulletin!) { false }
    controller.define_singleton_method(:auth_app_sign_in_path) { |ri: nil|
      "/sign/in#{ri ? "?ri=#{ri}" : ""}"
    }
    sign_in_sequence_redirects = []
    controller.define_singleton_method(:redirect_to_sign_in_sequence!) do |**kwargs|
      sign_in_sequence_redirects << kwargs
      "/dashboard"
    end
    controller.define_singleton_method(:auth_app_sign_up_guard_path) {
      raise StandardError, "should not continue sign up"
    }
    controller.define_singleton_method(:establish_signed_in_session!) { raise StandardError, "should not sign in" }

    user = Client.create!(status_id: ClientStatus::ACTIVE, birthdate: "2000-02-03")
    identity = create_active_external_identity(client: user, provider: "google", subject: "social-signup-existing")

    controller.send(
      :handle_successful_auth,
      user,
      "login",
      "Google",
      identity,
      existing_account: true,
      pt: "encoded-pt",
    )

    assert_match "/sign/in?ri=jp", redirects.last.first.first
  end

  test "rejected established social sign in keeps account records" do
    controller = Auth::App::Omniauth::OmniauthCallbacksController.new
    user = Client.create!(status_id: ClientStatus::ACTIVE, birthdate: "2000-02-03")
    identity = create_active_external_identity(client: user, provider: "google", subject: "social-signin-keep-existing")
    controller.define_singleton_method(:params) { ActionController::Parameters.new(ri: "jp", provider: "google") }
    controller.define_singleton_method(:auth_app_sign_in_path) { |ri: nil|
      "/sign/in#{ri ? "?ri=#{ri}" : ""}"
    }
    controller.define_singleton_method(:redirect_to) { |*| nil }
    controller.define_singleton_method(:sign_in) { raise StandardError, "should not sign in" }

    controller.send(:handle_login_intent, user, "Google", true)

    assert Client.exists?(user.id)
    assert ClientExternalIdentity.exists?(identity.id)
  end

  # GET /social/failure is directly reachable and unauthenticated, so the
  # `message`/`strategy` parameters must be reduced to an allowlisted
  # classification before they reach the log (adr/application-logging-boundary.md).
  test "failure classification allowlists the message parameter" do
    controller = Auth::App::Omniauth::OmniauthCallbacksController.new

    assert_equal "invalid_credentials", controller.send(:classified_failure_message, "invalid_credentials")
    assert_equal "access_denied", controller.send(:classified_failure_message, "access_denied")
    assert_equal "other", controller.send(:classified_failure_message, "attacker-supplied-marker-9f3c")
    assert_equal "other", controller.send(:classified_failure_message, nil)
    assert_equal "other", controller.send(:classified_failure_message, "a" * 10_000)
  end

  test "failure classification allowlists the strategy parameter against the provider registry" do
    controller = Auth::App::Omniauth::OmniauthCallbacksController.new

    ExternalAuthentication::ProviderRegistry.providers.each do |provider|
      assert_equal provider.to_s, controller.send(:classified_failure_strategy, provider.to_s)
    end

    # google_oauth2 is the OmniAuth strategy name; SocialIdentifiable normalizes
    # it to the registered "google" provider rather than discarding it.
    assert_equal "google", controller.send(:classified_failure_strategy, "google_oauth2")
    assert_equal "other", controller.send(:classified_failure_strategy, "attacker-supplied-strategy")
    assert_equal "other", controller.send(:classified_failure_strategy, nil)
  end

  test "failure logs the classification and never the raw parameters" do
    controller = Auth::App::Omniauth::OmniauthCallbacksController.new
    injected_message = "attacker-supplied-marker-9f3c"
    injected_strategy = "attacker-supplied-strategy-7b1d"
    session_hash = {}

    controller.request = ActionDispatch::TestRequest.create("REQUEST_METHOD" => "GET")
    controller.response = ActionDispatch::TestResponse.new
    controller.define_singleton_method(:session) { session_hash }
    controller.define_singleton_method(:params) {
      ActionController::Parameters.new(message: injected_message, strategy: injected_strategy)
    }
    controller.define_singleton_method(:redirect_to) { |*, **| nil }
    controller.define_singleton_method(:auth_app_sign_in_path) { |**| "/sign/in" }
    controller.define_singleton_method(:auth_app_sign_up_path) { |**| "/sign/up" }
    controller.define_singleton_method(:clear_social_auth_intent!) { nil }
    controller.define_singleton_method(:logged_in?) { false }

    buffer = StringIO.new
    previous_logger = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(buffer)
    Rails.logger.level = Logger::DEBUG

    begin
      controller.failure
    ensure
      Rails.logger = previous_logger
    end

    logs = buffer.string

    assert_not_includes logs, injected_message
    assert_not_includes logs, injected_strategy
    assert_includes logs, "sign.social.omniauth_failure"
    assert_includes logs, %("message":"other")
    assert_includes logs, %("strategy":"other")
  end

  test "direct action early exits and csrf helpers" do
    controller = Auth::App::Omniauth::OmniauthCallbacksController.new
    session_hash = {}
    redirects = []

    request = ActionDispatch::TestRequest.create("REQUEST_METHOD" => "GET")
    controller.request = request
    controller.response = ActionDispatch::TestResponse.new
    controller.define_singleton_method(:session) { session_hash }
    controller.define_singleton_method(:params) { ActionController::Parameters.new(provider: "apple", message: "cancelled", strategy: "apple") }
    controller.define_singleton_method(:redirect_to) { |*args, **kwargs| redirects << [args, kwargs] }
    controller.define_singleton_method(:auth_app_sign_in_path) { |ri: nil|
      "/sign/in#{ri ? "?ri=#{ri}" : ""}"
    }
    controller.define_singleton_method(:auth_app_sign_up_path) { |ri: nil|
      "/sign/up#{ri ? "?ri=#{ri}" : ""}"
    }
    controller.define_singleton_method(:clear_social_auth_intent!) { @cleared_for_test = true }
    controller.define_singleton_method(:action_name) { @action_name_for_test }
    controller.define_singleton_method(:verified_social_callback_request?) { @verified_social_for_test }
    controller.define_singleton_method(:reject_social_callback!) { |**kwargs| @rejection_for_test = kwargs }
    controller.define_singleton_method(:test_mode_omniauth_auth_hash) { nil }

    controller.omniauth

    assert_match "/sign/in", redirects.last.first.first

    controller.failure

    assert controller.instance_variable_get(:@cleared_for_test)
    assert_match "/sign/in", redirects.last.first.first

    controller.instance_variable_set(:@action_name_for_test, "omniauth")
    controller.instance_variable_set(:@verified_social_for_test, true)

    assert controller.send(:verified_request?)

    request.env["social_callback_guard.rejection"] =
      { reason: "bad_state", provider: "apple", details: { state_reason: "missing" } }
    controller.send(:handle_unverified_request)

    assert_equal "bad_state", controller.instance_variable_get(:@rejection_for_test)[:reason]

    assert_equal "/sign/in", controller.send(:social_auth_failure_redirect_path)

    session_hash[SocialAuth::SOCIAL_ENTRY_SESSION_KEY] = "sign_up"
    session_hash[SocialAuth::SOCIAL_RI_SESSION_KEY] = "jp"

    assert_equal "/sign/up?ri=jp", controller.send(:social_auth_failure_redirect_path)

    session_hash[SocialAuth::SOCIAL_ENTRY_SESSION_KEY] = "sign_in"

    assert_equal "/sign/in?ri=jp", controller.send(:social_auth_failure_redirect_path)
  end

  test "pending social signup failure is logged with state machine details" do
    controller = Auth::App::Omniauth::OmniauthCallbacksController.new
    cycle = ClientSignUpFlow.create!(
      principal_id: nil,
      status_id: ClientSignUpFlowStatus::SOCIAL_CALLBACK_PENDING,
      step: "social_callback",
      nonce_digest: ClientSignUpFlow.digest_nonce("nonce"),
      issued_at: Time.current,
      expires_at: 15.minutes.from_now,
      entry_method: "google",
      social_provider: "google",
    )
    result = SignUpResult.build(
      status: :invalid_transition,
      ticket: cycle,
      errors: ["terminal ticket cannot transition"],
    )
    logged = []

    controller.define_singleton_method(:logger) { Rails.logger }
    Rails.logger.stub(:warn, ->(message) { logged << message }) do
      SignUpStateMachine.stub(:call, result) do
        assert_raises(SocialAuth::ProviderError) do
          controller.send(:advance_pending_social_sign_up_flow!, cycle)
        end
      end
    end

    assert_predicate logged.first, :present?
    assert_includes logged.first, "sign.social.omniauth.pending_social_signup_failed"
    assert_includes logged.first, "invalid_transition"
    assert_includes logged.first, "terminal ticket cannot transition"
  end

  test "pending social signup invalid transition uses a specific error message" do
    controller = Auth::App::Omniauth::OmniauthCallbacksController.new
    cycle = ClientSignUpFlow.create!(
      principal_id: nil,
      status_id: ClientSignUpFlowStatus::CHECKPOINT_PENDING,
      step: "checkpoint",
      nonce_digest: ClientSignUpFlow.digest_nonce("nonce"),
      issued_at: Time.current,
      expires_at: 15.minutes.from_now,
      entry_method: "apple",
      social_provider: "apple",
    )
    result = SignUpResult.build(
      status: :invalid_transition,
      ticket: cycle,
      errors: ["invalid transition from 40 to 40"],
    )

    controller.define_singleton_method(:logger) { Rails.logger }

    SignUpStateMachine.stub(:call, result) do
      error =
        assert_raises(SocialAuth::ProviderError) do
          controller.send(:advance_pending_social_sign_up_flow!, cycle)
        end

      assert_equal "errors.social_auth.pending_social_signup_invalid_state", error.i18n_key
    end
  end

  test "pending social signup at checkpoint redirects to confirmation instead of re-advancing" do
    controller = Auth::App::Omniauth::OmniauthCallbacksController.new
    cycle = ClientSignUpFlow.create!(
      principal_id: nil,
      status_id: ClientSignUpFlowStatus::CHECKPOINT_PENDING,
      step: "checkpoint",
      nonce_digest: ClientSignUpFlow.digest_nonce("nonce"),
      issued_at: Time.current,
      expires_at: 15.minutes.from_now,
      entry_method: "apple",
      social_provider: "apple",
    )
    auth = OpenStruct.new(provider: "apple", uid: "apple_uid")
    redirects = []

    controller.request = ActionDispatch::TestRequest.create("HTTP_HOST" => "log.umaxica.app")
    controller.response = ActionDispatch::TestResponse.new
    controller.request.env["omniauth.auth"] = auth
    controller.instance_variable_set(
      :@external_authentication_callback_result,
      ExternalAuthentication::CallbackResult.verified(
        principal: ExternalAuthentication::VerifiedPrincipal.new(
          provider: "apple",
          subject: auth.uid,
          issuer: "https://appleid.apple.com",
          audience: "apple-client-id",
          verified_at: Time.current,
          verification_authority: "omniauth-apple/contract",
        ),
        credential_candidate: nil,
      ),
    )
    controller.define_singleton_method(:params) { ActionController::Parameters.new(ri: "jp") }
    controller.define_singleton_method(:session) { {} }
    controller.define_singleton_method(:auth_app_up_sequence_id) { cycle.public_id }
    controller.define_singleton_method(:auth_app_sign_up_check_apple_confirmation_path) do |**kwargs|
      "/sign/up/check/apple/confirmation?#{kwargs.compact.to_query}"
    end
    controller.define_singleton_method(:sign_up_flow_locator) do
      locator = Minitest::Mock.new
      locator.expect(:current, cycle)
      locator
    end
    controller.define_singleton_method(:redirect_to) { |path| redirects << path }
    controller.define_singleton_method(:store_pending_social_signup_evidence!) do |_cycle, _auth|
      true
    end
    controller.define_singleton_method(:advance_pending_social_sign_up_flow!) do |_cycle|
      raise RuntimeError, "should not advance checkpoint ticket"
    end

    controller.send(:handle_pending_social_sign_up_intent, "Apple", pt: nil)

    assert_equal 1, redirects.length
    assert_match %r{/sign/up/check/apple/confirmation}, redirects.first
  end

  private

  def assert_locked_authentication_method_login_rejected(provider:, provider_name:, effect:)
    controller = Auth::App::Omniauth::OmniauthCallbacksController.new
    redirects = []

    request = ActionDispatch::TestRequest.create(
      "REQUEST_METHOD" => "GET",
      "HTTP_HOST" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"),
    )
    request.env["omniauth.auth"] = OpenStruct.new(provider: provider)
    controller.request = request
    controller.response = ActionDispatch::TestResponse.new

    session_hash = {}
    controller.define_singleton_method(:session) { session_hash }
    controller.define_singleton_method(:params) { ActionController::Parameters.new(ri: "jp", provider: provider) }
    controller.define_singleton_method(:redirect_to) { |*args, **kwargs| redirects << [args, kwargs] }
    controller.define_singleton_method(:auth_app_sign_in_path) { |ri: nil|
      "/sign/in#{ri ? "?ri=#{ri}" : ""}"
    }
    controller.define_singleton_method(:redirect_to_sign_in_sequence!) { |**_kwargs| "/dashboard" }
    controller.define_singleton_method(:establish_signed_in_session!) { raise StandardError, "should not sign in" }

    user = Client.create!(status_id: ClientStatus::ACTIVE, birthdate: "2000-02-03")
    admin_operator = operators(:one)
    the_case = AppEnforcementCase.new(
      kind: "method_protection",
      duration_mode: "indefinite",
      visibility: "visible",
      release_mode: "operator",
      effective_at: Time.current,
      reason_code: "security_incident",
      principal_public_id: user.public_id,
      applied_by_operator_public_id: admin_operator.public_id,
    )
    the_case.authentication_method_effects.build(
      principal_public_id: user.public_id,
      authentication_method: provider,
      effect: effect,
      effective_at: Time.current,
    )
    EnforcementCaseApplyOperation.call(enforcement_case: the_case)

    controller.send(:handle_login_intent, user, provider_name, false, pt: "encoded-pt")

    assert_match "/sign/in", redirects.last.first.first
  end

  def assert_grantless_established_social_login_rejected(provider:, provider_name:)
    controller = Auth::App::Omniauth::OmniauthCallbacksController.new
    redirects = []

    request = ActionDispatch::TestRequest.create(
      "REQUEST_METHOD" => "GET",
      "HTTP_HOST" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"),
    )
    request.env["omniauth.auth"] = OpenStruct.new(provider: provider)
    controller.request = request
    controller.response = ActionDispatch::TestResponse.new

    session_hash = {}
    controller.define_singleton_method(:session) { session_hash }
    controller.define_singleton_method(:params) { ActionController::Parameters.new(ri: "jp", provider: provider) }
    controller.define_singleton_method(:redirect_to) { |*args, **kwargs| redirects << [args, kwargs] }
    controller.define_singleton_method(:auth_app_sign_in_path) { |ri: nil|
      "/sign/in#{ri ? "?ri=#{ri}" : ""}"
    }
    sign_in_sequence_redirects = []
    controller.define_singleton_method(:redirect_to_sign_in_sequence!) do |**kwargs|
      sign_in_sequence_redirects << kwargs
      "/dashboard"
    end
    controller.define_singleton_method(:establish_signed_in_session!) { raise StandardError, "should not sign in" }

    user = Client.create!(status_id: ClientStatus::ACTIVE, birthdate: "2000-02-03")

    controller.send(
      :handle_successful_auth,
      user,
      "login",
      provider_name,
      nil,
      existing_account: true,
      pt: "encoded-pt",
    )

    assert_match "/sign/in?ri=jp", redirects.last.first.first
  end
end
