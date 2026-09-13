# typed: false
# frozen_string_literal: true

require "test_helper"

class BranchCoverageBatch2Test < ActiveSupport::TestCase
  class SocialGuardHarness
    include SocialCallbackGuard

    attr_accessor :params_hash, :request_value

    def initialize
      @params_hash = {}
      @request_value = ActionDispatch::TestRequest.create
    end

    def params = ActionController::Parameters.new(params_hash)

    def request = request_value

    def session = {}
  end

  class ActorHarness
    include ActorSupport

    attr_accessor :session_hash

    def initialize
      @session_hash = {}
    end

    def session = session_hash
  end

  test "SocialCallbackGuard covers apple capture and host/origin normalization" do
    h = SocialGuardHarness.new
    h.define_singleton_method(:provider) { "apple" }
    env = { "omniauth.auth" => { "provider" => "apple" } }
    h.send(:capture_request_state!, env)

    assert_nil h.send(:normalize_host_port, "https://")
    assert_nil h.send(:normalize_origin, "/relative")
    assert_nil h.send(:normalize_origin, ":::bad")

    bare = SocialGuardHarness.new
    def bare.respond_to?(name, include_all = false)
      return false if name.to_sym == :params

      super
    end
    bare.request_value = ActionDispatch::TestRequest.create
    bare.send(:load_callback_state_data, "google")

    req = ActionDispatch::TestRequest.create
    req.set_header("HTTP_REFERER", "https://www.umaxica.app/path")
    kind, = SocialCallbackGuard.normalized_request_source(req)

    assert_equal :referer, kind
  end

  test "ActorSupport covers missing current_resource and preference association skips" do
    h = ActorHarness.new
    def h.respond_to?(name, include_all = false)
      return false if name.to_sym == :current_resource

      super
    end

    assert_nil h.send(:safe_current_resource)

    h2 = ActorHarness.new
    h2.define_singleton_method(:current_resource) { raise StandardError, "boom" }
    h2.define_singleton_method(:authentication_credentials_invalid?) { true }

    assert_nil h2.send(:safe_current_resource)

    h3 = ActorHarness.new
    def h3.respond_to?(name, include_all = false)
      return false if name.to_sym == :session

      super
    end

    assert_nil h3.send(:resolved_active_sign_sequence_id)

    resource = Object.new
    def resource.respond_to?(*) = false

    assert_nil h2.send(:resolved_resource_preference, resource)
  end

  test "SignEmailRegistrable covers cooldown and blank digest paths" do
    klass =
      Class.new do
        include SignEmailRegistrable

        attr_accessor :user_email

        def verified_email_status_id = 1

        def email_class = ClientEmail

        def user_class = Client
      end
    h = klass.new
    h.user_email = Struct.new(:address_digest, :errors).new("digest", ActiveModel::Errors.new(ClientEmail.new))

    SignUpEmailPendingGuard.stub(:with_lock, ->(**) { { status: :ok, cooldown: true } }) do
      assert_equal :cooldown, h.send(:create_and_send_verified_email!, false)
    end
    SignUpEmailPendingGuard.stub(:with_lock, ->(**) { { status: :fail, cooldown: false } }) do
      assert_not h.send(:create_and_send_verified_email!, false)
    end

    h.user_email = Struct.new(:address_digest).new(nil)

    assert_nil h.send(:remove_existing_unverified_emails!)

    email = ClientEmail.new
    email.errors.add(:address, :taken)
    email.errors.add(:address, :invalid)

    assert_not h.send(:email_uniqueness_only_error?, email)
    only = ClientEmail.new
    only.errors.add(:address, :taken)

    assert h.send(:email_uniqueness_only_error?, only)
  end

  test "JumpRtIssuer covers invalid ttl and non-https URL rejection" do
    namespace = JitSecurityJwtRegistry::SURFACE_NAMESPACES.first
    issuer = JumpRtIssuer.new(namespace: namespace, url: "https://www.umaxica.app/x", ttl: 0)

    assert_nil issuer.call

    issuer2 = JumpRtIssuer.new(namespace: namespace, url: "https://www.umaxica.app/x", ttl: 30)

    assert_nil issuer2.send(:normalize_url, "")
    assert_nil issuer2.send(:normalize_url, "http://example.com/x")
    assert_nil issuer2.send(:normalize_url, "https:///nohost")
    Rails.env.stub(:local?, false) do
      assert_not issuer2.send(:local_http_allowed?, URI.parse("http://app.localhost/"))
    end
  end

  test "AvatarProvisioning::Create validates required inputs" do
    assert_raises(ArgumentError) do
      AvatarProvisioning::Create.new(
        actor: nil, subject_type: "persona", subject: Object.new, avatar_params: {},
      ).send(:validate_inputs!)
    end
    assert_raises(ArgumentError) do
      AvatarProvisioning::Create.new(
        actor: Client.new, subject_type: "nope", subject: Object.new, avatar_params: {},
      ).send(:validate_inputs!)
    end
    assert_raises(ArgumentError) do
      AvatarProvisioning::Create.new(
        actor: Client.new, subject_type: "persona", subject: nil, avatar_params: {},
      ).send(:validate_inputs!)
    end
    assert_raises(ArgumentError) do
      AvatarProvisioning::Create.new(
        actor: Client.new, subject_type: "persona", subject: Object.new, avatar_params: {}, assignment_role: "",
      ).send(:validate_inputs!)
    end
  end

  test "SignUpStepGate unsafe ticket arms" do
    controller = Object.new
    gate = SignUpStepGate.new(controller: controller, surface: :app, family: "email", step: :otp, mode: :page)
    ticket = Object.new
    ticket.define_singleton_method(:expired?) { true }
    ticket.define_singleton_method(:respond_to?) do |name, include_all = false|
      return true if %i(expired? lapsed? sign_up_terminal?).include?(name.to_sym)

      super(name, include_all)
    end
    ticket.define_singleton_method(:lapsed?) { false }
    ticket.define_singleton_method(:sign_up_terminal?) { false }

    assert gate.send(:unsafe_ticket?, ticket)

    ticket2 = Object.new
    ticket2.define_singleton_method(:expired?) { false }
    ticket2.define_singleton_method(:respond_to?) do |name, include_all = false|
      return true if %i(expired? lapsed? sign_up_terminal?).include?(name.to_sym)

      super(name, include_all)
    end
    ticket2.define_singleton_method(:lapsed?) { false }
    ticket2.define_singleton_method(:sign_up_terminal?) { true }

    assert gate.send(:unsafe_ticket?, ticket2)
  end

  test "TokenStatusManagement currently_usable discarded and scheduled revocation" do
    token = ClientToken.new
    if token.has_attribute?(:discarded_at)
      token.discarded_at = 1.minute.ago

      assert_not token.currently_usable?
    end

    token2 = ClientToken.new(user_token_status_id: ClientTokenStatus::ACTIVE)
    token2.define_singleton_method(:scheduled_revocation_due?) { true }

    assert_predicate token2, :expired?
  end

  test "Avatar current binding nil for unpersisted records" do
    avatar = Avatar.new

    assert_nil avatar.current_avatar_persona_binding
  end

  test "OidcTokenExchangeCoordinator authentication guards reject blanks" do
    coordinator = OidcTokenExchangeCoordinator.new(
      grant_type: "authorization_code",
      code: "x",
      redirect_uri: "https://example.test/cb",
      client_id: "",
      code_verifier: "v",
    )

    assert_not coordinator.send(:authenticated_client?)

    coordinator2 = OidcTokenExchangeCoordinator.new(
      grant_type: "authorization_code",
      code: "x",
      redirect_uri: "https://example.test/cb",
      client_id: "base-rails-rp",
      code_verifier: "v",
      client_assertion: "assert",
      client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
      token_endpoint_uri: nil,
    )

    assert_not coordinator2.send(:authenticated_client_assertion?)
  end

  test "PreferenceCore blank locale and timezone early returns" do
    require_relative "preference/core_test"
    c = PreferenceCoreHarness.new
    c.define_singleton_method(:option_id_to_language) { |*_args| nil }
    pref = Struct.new(:option_id).new("xx")

    assert_nil c.send(:pin_locale_to_saved_language, pref)

    c.instance_variable_set(:@preference_language, Struct.new(:option_id).new(nil))
    c.send(:apply_language_preference_to_session)

    c.instance_variable_set(
      :@preference_timezone, Struct.new(:option_id, :reload) do
                               def reload = self
                             end.new(""),
    )
    c.define_singleton_method(:resolved_writable_timezone) { |*_args| nil }
    c.send(:set_timezone_preferences_update) if c.private_methods.include?(:set_timezone_preferences_update)

    c.define_singleton_method(:respond_to?) do |name, include_all = false|
      return false if name.to_sym == :current_resource

      super(name, include_all)
    end

    assert_nil c.send(:existing_resource_preference_for_reset)
  end
end
