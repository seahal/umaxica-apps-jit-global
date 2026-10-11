# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthAppOmniauthCallbacksPrivateCoverageTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  def build_controller
    controller = Auth::App::Omniauth::OmniauthCallbacksController.new
    controller.request = ActionDispatch::TestRequest.create("REQUEST_METHOD" => "GET")
    controller.response = ActionDispatch::TestResponse.new
    session = {}
    redirects = []
    controller.define_singleton_method(:session) { session }
    controller.define_singleton_method(:params) { ActionController::Parameters.new(ri: "jp") }
    controller.define_singleton_method(:redirect_to) { |*args, **kwargs| redirects << [args, kwargs]; nil }
    controller.define_singleton_method(:safe_redirect_to) { |*args, **kwargs| redirects << [:safe, args, kwargs]; nil }
    controller.define_singleton_method(:redirect_to_sign_in_sequence!) { |**kwargs| redirects << [:seq, kwargs]; nil }
    controller.define_singleton_method(:auth_app_sign_in_path) { |**kwargs|
      "/sign/in#{kwargs[:ri] ? "?ri=#{kwargs[:ri]}" : ""}"
    }
    controller.define_singleton_method(:auth_app_settings_path) { "/settings" }
    controller.define_singleton_method(:auth_app_sign_in_session_path) { "/sign/in/session" }
    controller.define_singleton_method(:render_session_limit_hard_reject) { |**kwargs|
      redirects << [:hard, kwargs]; nil
    }
    controller.define_singleton_method(:current_social_auth_ri) { "jp" }
    controller.instance_variable_set(:@redirects_for_test, redirects)
    controller
  end

  test "redirect helpers and success path" do
    c = build_controller

    assert_equal "/settings", c.send(:social_auth_success_redirect_path)
    c.send(:redirect_after_login, "google", true, pt: "/x")
    c.send(:redirect_after_login, "google", false, pt: "/x")
    c.send(:redirect_for_existing_account, "google", pt: "/x")
    c.send(:redirect_for_new_account, "google", pt: "/x")

    assert_operator c.instance_variable_get(:@redirects_for_test).size, :>=, 4
  end

  test "social login audit context and result payload arms" do
    c = build_controller
    auth = Struct.new(:provider).new("google_oauth2")
    c.request.env["omniauth.auth"] = auth
    context = c.send(:social_login_audit_context)

    assert_equal "social", context[:auth_method]
    assert_equal "google", context[:provider]

    assert_equal({ result_class: "String" }, c.send(:social_login_result_log_payload, "x"))
    payload = c.send(
      :social_login_result_log_payload,
      {
        status: :success,
        restricted: false,
        session_management_required: false,
        token_type: "Bearer",
        expires_in: 60,
        dbsc: { binding_method: "cookie", status: "ok", session_id: "abc" },
      },
    )

    assert_equal :success, payload[:status]
    assert payload[:dbsc][:session_id_present]
  end

  test "social_authentication_event_at requires verified callback result" do
    c = build_controller

    assert_nil c.send(:social_authentication_event_at)

    principal = Struct.new(:verified_at).new(Time.zone.parse("2026-01-02 03:04:05"))
    result = Object.new
    result.define_singleton_method(:is_a?) { |klass| klass == ExternalAuthentication::CallbackResult }
    result.define_singleton_method(:verified?) { true }
    result.define_singleton_method(:principal) { principal }
    c.instance_variable_set(:@external_authentication_callback_result, result)

    assert_equal principal.verified_at, c.send(:social_authentication_event_at)
  end

  test "with_social_sign_up_lock yields without identity fields" do
    c = build_controller
    called = false
    c.send(:with_social_sign_up_lock, nil) { called = true }

    assert called

    identity = Object.new
    # no uid/provider -> yield path
    called = false
    c.send(:with_social_sign_up_lock, identity) { called = true }

    assert called
  end

  test "create_social_sign_up_flow! rejects blank collaborators" do
    c = build_controller
    assert_raises(SocialAuth::ProviderError) { c.send(:create_social_sign_up_flow!, nil, nil) }
  end

  test "bind_social_sign_up_flow! validates identity invariants" do
    c = build_controller
    cycle = Struct.new(:social_provider, :public_id).new("google", "cycle-1")
    assert_raises(SocialAuth::ProviderError) { c.send(:bind_social_sign_up_flow!, cycle, Object.new, nil) }

    identity = Object.new
    identity.define_singleton_method(:persisted?) { false }
    identity.define_singleton_method(:id) { nil }
    assert_raises(SocialAuth::ProviderError) { c.send(:bind_social_sign_up_flow!, cycle, Object.new, identity) }
  end

  test "store_social_sign_up_sequence_id writes session" do
    c = build_controller
    cycle = Struct.new(:public_id).new("seq-1")
    c.send(:store_social_sign_up_sequence_id, cycle)

    assert_equal "seq-1", c.session[:auth_app_up_sequence_id]
  end

  test "handle_login_failure covers session limit MFA and unknown arms" do
    c = build_controller
    user = Struct.new(:id).new(42)
    SignRiskEmitter.stub(:emit, true) do
      result = Struct.new(:status, :message, :response_status, :redirect_to).new(
        :session_limit_hard_reject, "no", 429, "/limit",
      )
      c.define_singleton_method(:sign_in_result_from_session_result) { |*_args, **_kwargs| result }
      c.send(:handle_login_failure, { status: :session_limit_hard_reject }, "google", user)

      result = Struct.new(:status, :message, :response_status, :redirect_to).new(
        :session_limit_pending, "wait", 302, "/pending",
      )
      c.define_singleton_method(:sign_in_result_from_session_result) { |*_args, **_kwargs| result }
      c.send(:handle_login_failure, { status: :session_limit_pending }, "google", user)

      result = Struct.new(:status, :message, :response_status, :redirect_to).new(
        :mfa_required, "mfa", 302, "/mfa",
      )
      c.define_singleton_method(:sign_in_result_from_session_result) { |*_args, **_kwargs| result }
      c.send(:handle_login_failure, { status: :mfa_required }, "google", user)

      result = Struct.new(:status, :message, :response_status, :redirect_to).new(
        :mystery, "x", 302, "/x",
      )
      c.define_singleton_method(:sign_in_result_from_session_result) { |*_args, **_kwargs| result }
      c.send(:handle_login_failure, { status: :mystery }, "google", user)
    end

    assert_operator c.instance_variable_get(:@redirects_for_test).size, :>=, 4
  end

  test "sign_in delegates to AuthenticationSessionCommitter" do
    c = build_controller
    user = Struct.new(:id, :public_id).new(1, "u1")
    AuthenticationSessionCommitter.stub(:call, { status: :success }) do
      result = c.send(:sign_in, user, pt: "/home", provider_name: "google")

      assert_equal :success, result[:status]
    end
  end

  test "redirect_pending_social_signup_confirmation builds provider path" do
    c = build_controller
    c.define_singleton_method(:auth_app_sign_up_check_google_confirmation_path) { |**kwargs| kwargs }
    c.send(:redirect_pending_social_signup_confirmation, "google", pt: "/back")
    redirects = c.instance_variable_get(:@redirects_for_test)

    assert_equal([{ ri: "jp", pt: "/back" }], redirects.last.first)
  end

  test "handle_social_sign_up_intent redirects after lock" do
    c = build_controller
    user = Object.new
    identity = Struct.new(:provider, :uid).new("google", "uid-1")
    cycle = Struct.new(:public_id).new("c1")
    c.define_singleton_method(:with_social_sign_up_lock) { |_identity, &block| block.call }
    c.define_singleton_method(:sign_up_flow_locator) do
      locator = Object.new
      locator.define_singleton_method(:current) { cycle }
      locator
    end
    c.define_singleton_method(:bind_social_sign_up_flow!) { |*_args| true }
    c.define_singleton_method(:auth_app_sign_up_guard_google_path) { |**kwargs| kwargs }
    c.send(:handle_social_sign_up_intent, user, "google", identity, pt: "/pt")

    assert_predicate c.instance_variable_get(:@redirects_for_test), :any?
  end
end
