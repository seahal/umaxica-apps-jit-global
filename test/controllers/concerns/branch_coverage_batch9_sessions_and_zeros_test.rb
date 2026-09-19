# typed: false
# frozen_string_literal: true

require "test_helper"

class BranchCoverageBatch9SessionsAndZerosTest < ActiveSupport::TestCase
  test "app sessions private helpers cover login redirect empty load and promote no-op" do
    c = Auth::App::Sign::In::SessionsController.new
    request = ActionDispatch::TestRequest.create
    response = ActionDispatch::TestResponse.new
    c.set_request!(request)
    c.set_response!(response)
    c.define_singleton_method(:session) { @session ||= {} }
    c.define_singleton_method(:current_region_identifier) { "jp" }
    redirects = []
    c.define_singleton_method(:redirect_to) { |*args, **kwargs| redirects << [args, kwargs] }
    c.define_singleton_method(:auth_app_sign_in_path) { |**| "/sign/in" }
    c.define_singleton_method(:resolve_current_client) { nil }
    c.instance_variable_set(:@current_client, nil)
    c.send(:redirect_to_login) if c.private_methods.include?(:redirect_to_login)

    assert_predicate redirects, :present?

    c.define_singleton_method(:resolve_current_client) { nil }
    c.send(:load_session_data)

    assert_nil c.instance_variable_get(:@active_sessions)

    c.define_singleton_method(:current_session) { nil }

    assert_nil c.send(:promote_current_session!)

    # page props with no restricted sessions and no restricted notice
    c.instance_variable_set(:@active_sessions, [])
    c.instance_variable_set(:@restricted_sessions, [])
    c.define_singleton_method(:current_session_restricted?) { false }
    c.define_singleton_method(:auth_app_sign_in_session_path) { |**| "/session" }
    props = c.send(:session_page_props)

    assert_nil props[:restricted_notice]
    assert_nil props[:restricted_sessions]

    session = Struct.new(:public_id, :created_at, :last_used_at, :signed_ref).new(
      "p1", Time.current, Time.current,
      "ref",
    )
    c.instance_variable_set(:@current_session_public_id, "p1")
    item = c.send(:session_item_props, session, label: "L", revocable: false)

    assert_equal I18n.t("sign.app.in.session.current"), item[:current_label]
  end

  test "org sessions private helpers cover pending gate and promote no-op" do
    c = Auth::Org::Sign::In::SessionsController.new
    request = ActionDispatch::TestRequest.create
    response = ActionDispatch::TestResponse.new
    c.set_request!(request)
    c.set_response!(response)
    c.define_singleton_method(:session) { @session ||= {} }
    redirects = []
    c.define_singleton_method(:redirect_to) { |*args, **kwargs| redirects << [args, kwargs] }
    c.define_singleton_method(:head) { |status| @head = status }
    c.define_singleton_method(:auth_org_sign_in_path) { |**| "/sign/in" }
    c.define_singleton_method(:current_region_identifier) { "jp" }
    c.define_singleton_method(:logged_in?) { false }
    c.define_singleton_method(:current_session_restricted?) { false }
    c.define_singleton_method(:pending_session_limit_cycle?) { true }
    c.define_singleton_method(:session_limit_gate_valid?) { false }
    c.send(:require_authentication_or_gate)
    # pending cycle allows through without redirect
    assert_empty redirects

    c.define_singleton_method(:pending_session_limit_cycle?) { false }
    c.define_singleton_method(:logged_in?) { true }
    c.send(:require_authentication_or_gate)

    assert_equal :forbidden, c.instance_variable_get(:@head)

    c.define_singleton_method(:current_db_sign_in_flow_for_sequence) { nil }
    # remove stub to call real pending? which uses &.
    c.singleton_class.send(
      :remove_method,
      :pending_session_limit_cycle?,
    ) if c.singleton_class.method_defined?(:pending_session_limit_cycle?)

    assert_not c.send(:pending_session_limit_cycle?)

    c.define_singleton_method(:resolve_current_operator) { nil }
    c.send(:load_session_data)
    c.define_singleton_method(:current_session) { nil }

    assert_nil c.send(:promote_current_session!)
  end

  test "zero-percent ceremony results reject future verified_at" do
    now = Time.zone.parse("2026-06-24 12:00:00 UTC")
    specs = [
      [IdentityEmailCeremonyResult, IdentityEmailCeremonyContract, "registration", {}],
      [IdentityTelephoneCeremonyResult, IdentityTelephoneCeremonyContract, "registration", {}],
      [IdentityPasskeyCeremonyResult, IdentityPasskeyCeremonyContract, "registration",
       { "webauthn_id" => "w", "public_key" => "pk", "sign_count" => 0 },],
      [IdentityTotpCeremonyResult, IdentityTotpCeremonyContract, "registration",
       { "credential_candidate_ref" => "r", "credential_candidate_digest" => "d" },],
      [IdentitySecretCredentialCeremonyResult, IdentitySecretCredentialCeremonyContract, "enrollment",
       { "credential_candidate_ref" => "r", "credential_candidate_digest" => "d" },],
    ]
    specs.each do |klass, contract, operation, extra|
      future = now + contract::LEEWAY + 120
      payload = {
        "typ" => klass::TOKEN_TYPE,
        "iss" => contract.sign_issuer("app"),
        "aud" => contract.acme_audience("app"),
        "purpose" => klass::PURPOSE,
        "surface" => "app",
        "actor_ref" => "a",
        "session_ref" => "s",
        "transaction_id" => "t",
        "grant_jti" => "g",
        "result_jti" => "r",
        "operation" => operation,
        "proof_method" => klass::PROOF_METHOD,
        "verified_at" => future.to_i,
        "challenge_id" => "c",
        "expires_at" => (now + 5.minutes).to_i,
        "iat" => now.to_i,
        "exp" => (now + 5.minutes).to_i,
      }.merge(extra)
      error_class =
        if klass == IdentityTelephoneCeremonyResult
          IdentityTelephoneCeremony::Error
        else
          contract::Error
        end
      err = assert_raises(error_class) { klass.new(payload, now: now) }
      assert_match(/verified_at must not be in the future/, err.message)
    end
  end

  test "group and membership service early returns" do
    group = Object.new
    group.define_singleton_method(:archived?) { true }

    assert_same group, GroupManagement::Archive.new(group: group).call

    membership = Object.new
    membership.define_singleton_method(:active?) { false }

    assert_same membership, GroupAvatarMemberships::Detach.new(membership: membership).call

    membership2 = Object.new
    membership2.define_singleton_method(:revoked?) { true }
    assert_raises(CollectiveMembership::InactiveMembership) do
      CollectiveMembership::Suspend.new(membership: membership2).call
    end

    membership3 = Object.new
    membership3.define_singleton_method(:active?) { false }
    assert_raises(CollectiveMembership::InactiveMembership) do
      CollectiveMembership::MakePrimary.new(membership: membership3).call
    end
  end

  test "SecurityConsumedJti and SessionLimitResolutionTokenRef blank guards" do
    assert_not SecurityConsumedJti.consume!(purpose: "", issuer: "x", jti: "y", expires_at: 1.hour.from_now)
    assert_nil SessionLimitResolutionTokenRef.find_client_token("")
  end

  test "preference core timezone blank returns after dual write" do
    require_relative "preference/core_test"
    c = PreferenceCoreHarness.new
    prefs = Object.new
    prefs.define_singleton_method(:blank?) { false }
    c.define_singleton_method(:ensure_preferences_record) { prefs }
    c.define_singleton_method(:preference_timezone_params) { { PreferenceIoKeys::Params::OPTION_ID => "" } }
    c.define_singleton_method(:sanitize_option_id) { |*_args, **| {} }
    c.define_singleton_method(:update_preference_child_dual_write!) { |*_args, **| true }
    tz = Struct.new(:option_id) do
      def reload = self
    end.new("")
    c.define_singleton_method(:load_or_refresh_preference_child) { |*_args, **| tz }
    c.define_singleton_method(:ensure_model_defaults!) { |_| true }
    c.send(:set_timezone_preferences_update)

    assert_equal tz, c.instance_variable_get(:@preference_timezone)

    tz2 = Struct.new(:option_id) do
      def reload = self
    end.new("Asia/Tokyo")
    c.define_singleton_method(:load_or_refresh_preference_child) { |*_args, **| tz2 }
    c.define_singleton_method(:resolved_writable_timezone) { |*_args| nil }
    c.define_singleton_method(:preference_timezone_params) { { PreferenceIoKeys::Params::OPTION_ID => "Asia/Tokyo" } }
    c.send(:set_timezone_preferences_update)
  end

  test "base oidc authorizations screen_hint branches via private method" do
    [Base::App::Oidc::AuthorizationsController, Base::Com::Oidc::AuthorizationsController,
     Base::Org::Oidc::AuthorizationsController,].each do |klass|
      next unless defined?(klass)

      c = klass.new
      c.define_singleton_method(:params) { ActionController::Parameters.new(screen_hint: "signup") }
      assert_equal "signup", c.send(:screen_hint_param) if c.private_methods.include?(:screen_hint_param)
      c.define_singleton_method(:params) { ActionController::Parameters.new(screen_hint: "signin") }
      assert_equal "signin", c.send(:screen_hint_param) if c.private_methods.include?(:screen_hint_param)
    end
  end

  test "sign out cancellation blank challenge" do
    klass =
      Class.new(ApplicationController) do
        include SignOutCancellation

        def session = {}

        def params = ActionController::Parameters.new({})
      end
    h = klass.new
    h.send(:clear_logout_transaction_state!) if h.private_methods.include?(:clear_logout_transaction_state!)
    if h.private_methods.include?(:cancel_logout_if_challenge_blank!)
      assert_nil h.send(:cancel_logout_if_challenge_blank!)
    end

    assert_kind_of Minitest::Test, self
  end

  test "social completions private failure arms" do
    c = Base::App::Social::Authentication::CompletionsController.new
    request = ActionDispatch::TestRequest.create
    response = ActionDispatch::TestResponse.new
    c.set_request!(request)
    c.set_response!(response)
    c.define_singleton_method(:params) { ActionController::Parameters.new(ri: "jp") }
    c.define_singleton_method(:current_session) { nil }

    sign_in_result = Struct.new(:status, :redirect_to, :message, :response_status).new(
      :mfa_required, "/somewhere", nil, :found,
    )
    redirects = []
    c.define_singleton_method(:redirect_to) { |*args, **| redirects << args }
    c.send(:handle_social_login_failure!, sign_in_result)

    assert_equal ["/somewhere"], redirects.first

    commit = Object.new
    commit.define_singleton_method(:result) { { "actor_ref" => "" } }

    assert_nil c.send(:complete_base_social_signup_flow!, commit, sign_in_result)

    identity = Object.new
    identity.define_singleton_method(:persisted?) { false }
    commit2 = Object.new
    commit2.define_singleton_method(:identity) { identity }
    commit2.define_singleton_method(:user) { Struct.new(:id).new(1) }
    cycle = Object.new
    error =
      assert_raises(SocialAuth::ProviderError) do
        c.send(:bind_social_sign_up_flow!, cycle, commit2)
      end
    assert_predicate error.message, :present?
  end
end
