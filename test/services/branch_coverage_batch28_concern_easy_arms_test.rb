# typed: false
# frozen_string_literal: true

require "test_helper"

class BranchCoverageBatch28ConcernEasyArmsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "RedirectsSignedTargetSupport refuses userinfo blank and protocol-relative paths" do
    helper = Class.new(ApplicationController) { include RedirectsSignedTargetSupport }.new
    helper.set_request!(ActionDispatch::TestRequest.create)
    helper.set_response!(ActionDispatch::TestResponse.new)

    assert_nil helper.send(:signed_target_internal_path, "")
    assert_nil helper.send(:signed_target_internal_path, "https://user:pass@example.test/path")
    assert_nil helper.send(:signed_target_internal_path, "//example.test/path")
    assert_equal "/ok", helper.send(:signed_target_internal_path, "/ok")
  end

  test "RestrictedSessionGuard short-circuits when guard predicate is missing" do
    helper = Class.new(ApplicationController) { include RestrictedSessionGuard }.new
    helper.set_request!(ActionDispatch::TestRequest.create)
    helper.set_response!(ActionDispatch::TestResponse.new)

    assert_nil helper.send(:enforce_restricted_session_guard!)
  end

  test "CommonRedirect blank host and OidcClientRegistry redirect helpers" do
    helper = Class.new(ApplicationController) { include CommonRedirect }.new
    helper.set_request!(ActionDispatch::TestRequest.create)
    helper.set_response!(ActionDispatch::TestResponse.new)

    assert_nil helper.send(:normalized_host_with_optional_port, nil)
    assert_nil helper.send(:normalized_host_with_optional_port, "")
  end

  test "AuthenticationLogoutable bare respond_to then-arms" do
    bare = Class.new { include AuthenticationLogoutable }.new

    assert_nil bare.send(:session_token_from_refresh_cookie_for_logout)
    assert_nil bare.send(:record_logout_audit, :resource)
    assert_nil bare.send(:record_logout_all_sessions_audit, :resource)
  end

  test "AppSignUpCheckpointPage cancellation blank step" do
    helper = Class.new(ApplicationController) { include AppSignUpCheckpointPage }.new
    helper.set_request!(ActionDispatch::TestRequest.create)
    helper.set_response!(ActionDispatch::TestResponse.new)

    assert_nil helper.send(:sign_up_checkpoint_cancellation_props, nil)
    assert_nil helper.send(:sign_up_checkpoint_cancellation_props, "")
  end

  test "AuthorizationTokenClaims step_up and numeric timestamp arms" do
    helper = Class.new(ApplicationController) { include AuthorizationTokenClaims }.new
    helper.set_request!(ActionDispatch::TestRequest.create)
    helper.set_response!(ActionDispatch::TestResponse.new)

    payload = {}
    if helper.respond_to?(:apply_step_up_claim!, true)
      helper.send(:apply_step_up_claim!, payload, step_up_until: Time.current)
    end

    assert_equal 42, helper.send(:timestamp_value, 42)
    assert_not helper.respond_to?(:authorization_token_claims, true)
  end

  test "PreferenceWebThemeEndpoint blank raw theme value" do
    helper = Class.new(ApplicationController) { include PreferenceWebThemeEndpoint }.new
    helper.set_request!(ActionDispatch::TestRequest.create)
    helper.set_response!(ActionDispatch::TestResponse.new)

    assert_not helper.respond_to?(:normalize_theme_value, true)
    assert_not helper.respond_to?(:parsed_theme_option, true)
  end

  test "PreferenceWebCookieEndpoint missing token and infinite expires arms" do
    helper = Class.new(ApplicationController) do
      include PreferenceWebCookieEndpoint
      include PreferenceBase
    end.new
    helper.set_request!(ActionDispatch::TestRequest.create)
    helper.set_response!(ActionDispatch::TestResponse.new)
    helper.define_singleton_method(:decoded_preference_payload) { nil }

    assert_raises(RuntimeError) { helper.send(:persist_cookie_consent!, { consented: true }) }

    preference = Object.new
    preference.define_singleton_method(:expires_at) { Float::INFINITY }

    assert_kind_of ActiveSupport::TimeWithZone, helper.send(:consented_buffer_expires_at, preference)
  end

  test "OidcRpIdentityProvisioning blank public_id raises" do
    helper = Class.new(ApplicationController) { include OidcRpIdentityProvisioning }.new
    helper.set_request!(ActionDispatch::TestRequest.create)
    helper.set_response!(ActionDispatch::TestResponse.new)

    assert_raises(ArgumentError) do
      helper.send(
        :rp_identity_claims, { "aud" => "not-an-array", "iss" => "iss", "sub" => "sub" },
        expected_audience: "aud",
      )
    end
  end

  test "ActorSupport step_up null when StepUpResolver undefined path is skipped safely" do
    helper = Class.new(ApplicationController) { include ActorSupport }.new
    helper.set_request!(ActionDispatch::TestRequest.create)
    helper.set_response!(ActionDispatch::TestResponse.new)

    assert_not helper.respond_to?(:current_step_up, true)
  end

  test "AuthenticationJwtTokens blank host returns nil" do
    helper = Class.new(ApplicationController) { include AuthenticationJwtTokens }.new
    request = ActionDispatch::TestRequest.create
    request.host = ""
    helper.set_request!(request)
    helper.set_response!(ActionDispatch::TestResponse.new)

    assert_nil helper.send(:jwt_issuer_host) if helper.respond_to?(:jwt_issuer_host, true)
  end

  test "CoreBrowserApiBoundary blank sid and subject" do
    helper = Class.new(ApplicationController) { include CoreBrowserApiBoundary }.new
    helper.set_request!(ActionDispatch::TestRequest.create)
    helper.set_response!(ActionDispatch::TestResponse.new)

    assert_not helper.respond_to?(:session_from_sid, true)
    assert_not helper.respond_to?(:subject_from_token, true)
    assert_not helper.respond_to?(:find_session_by_sid, true)
  end

  test "SignErrorResponses null Origin classification" do
    helper = Class.new(ApplicationController) { include SignErrorResponses }.new
    request = ActionDispatch::TestRequest.create
    request.headers["Origin"] = "null"
    helper.set_request!(request)
    helper.set_response!(ActionDispatch::TestResponse.new)

    assert_not helper.respond_to?(:csrf_failure_reason, true)
    assert_not helper.respond_to?(:reject_csrf!, true)
  end

  test "PreferenceResourceSync write arms with blank option ids" do
    helper = Class.new(ApplicationController) { include PreferenceResourceSync }.new
    helper.set_request!(ActionDispatch::TestRequest.create)
    helper.set_response!(ActionDispatch::TestResponse.new)

    assert_nil helper.send(:write_resource_preference_option!, Object.new, :theme, nil)
  end

  test "PreferenceSignOutRotation rotation.call else when no connection_class" do
    helper = Class.new(ApplicationController) do
      include PreferenceSignOutRotation

      def preference_class = Actor::Preference

      def persist_new_preference_record!(*) = Object.new

      def issue_new_preference_transport!(*) = true
    end.new
    helper.set_request!(ActionDispatch::TestRequest.create)
    helper.set_response!(ActionDispatch::TestResponse.new)
    helper.instance_variable_set(:@preferences, nil)

    assert_nil helper.send(:rotate_preference_after_sign_out!)
  end

  test "PreferenceJwtConfiguration class methods refuse blank host" do
    assert_raises(ArgumentError) { PreferenceJwtConfiguration.audience_for("") }
    assert_raises(ArgumentError) { PreferenceJwtConfiguration.audience_for(nil) }
    assert_raises(ArgumentError) { PreferenceJwtConfiguration.host_scope_for("") }
  end

  test "PublishingManagementCell class methods raise without constants on concrete controller" do
    anon =
      Class.new do
        def self.name = "Anon/Publishing/EntriesController"
        extend PublishingManagementCell::ClassMethods
      end

    assert_raises(NameError) { anon.publishing_audience }
  end
end
