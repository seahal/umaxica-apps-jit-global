# typed: false
# frozen_string_literal: true

# rubocop:disable I18n/RailsI18n/DecorateString

require "test_helper"
# require "helpers/global_test_support"

module Auth
  class BaseTest < ActiveSupport::TestCase
    self.fixture_table_names = []

    class HeaderKeyHarness
      class MockCookies
        delegate :[], to: :@store

        def initialize(store)
          @store = store
        end

        def []=(key, value)
          @store[key] = value
          HeaderKeyHarness.encrypted_cookies[key] = value
        end

        def delete(key, _options = nil)
          @store.delete(key)
        end
      end

      include AuthenticationBase

      attr_accessor :actor_type, :checkpoint_participant, :dashboard_participant
      attr_writer :resource, :logged_in, :current_session_record, :allowed_policy

      def resource_type
        actor_type
      end

      def resource_class = Client

      def token_class = ClientToken

      def audit_class = ClientChronicle

      def resource_foreign_key = :user_id

      def sign_in_url_with_pt(_return_to) = "/sign/in"

      def am_i_user? = false

      def am_i_staff? = false

      def am_i_owner? = false

      def initialize
        @params_hash = {}
        @session_hash = {}
        @flash_hash = {}
        @logged_in = false
        @request_stub = Struct.new(:format, :host, :request_id, :remote_ip, :headers).new(
          Struct.new(:json?).new(false),
          "app.localhost", "req-123", "127.0.0.1", {},
        )
        @cookies = MockCookies.new(self.class.encrypted_cookies)
      end

      def cookies
        @cookies
      end

      def self.encrypted_cookies
        Thread.current[:auth_base_test_encrypted_cookies] ||= {}.with_indifferent_access
      end

      def current_resource
        return @resource if defined?(@resource)

        @logged_in ? Object.new : nil
      end

      def current_session
        @current_session_record
      end

      def params
        @params_hash.with_indifferent_access
      end

      def params=(value)
        @params_hash = value
      end

      def session
        @session_hash
      end

      def flash
        @flash_hash
      end

      def request
        @request_stub
      end

      def json_request!
        @request_stub = Struct.new(:format, :headers).new(Struct.new(:json?).new(true), {})
      end

      def html_request!
        @request_stub = Struct.new(:format, :headers).new(Struct.new(:json?).new(false), {})
      end

      def render(**kwargs)
        @rendered = kwargs
      end

      def rendered
        @rendered
      end

      def redirect_to(path, **kwargs)
        @redirected = [path, kwargs]
      end

      def redirected
        @redirected
      end

      def sign_in_sequence_surface
        :app
      end

      def sign_app_dashboard_path(ri: nil, pt: nil)
        path = "/dashboard"
        query = []
        query << "ri=#{ri}" if ri.present?
        query << "pt=#{pt}" if pt.present?
        query.any? ? "#{path}?#{query.join("&")}" : path
      end

      def sign_app_welcome_path(_id = "post_auth", ri: nil, pt: nil)
        path = "/welcome"
        query = []
        query << "ri=#{ri}" if ri.present?
        query << "pt=#{pt}" if pt.present?
        query.any? ? "#{path}?#{query.join("&")}" : path
      end

      def auth_app_settings_path(ri: nil)
        ri.present? ? "/settings?ri=#{ri}" : "/settings"
      end

      def auth_app_sign_in_check_path(ri: nil, pt: nil)
        path = "/sign/in/check"
        query = []
        query << "ri=#{ri}" if ri.present?
        query << "pt=#{pt}" if pt.present?
        query.any? ? "#{path}?#{query.join("&")}" : path
      end

      def allowed_to?(rule = nil, *)
        if defined?(@allowed_policy) && @allowed_policy.is_a?(Hash)
          return @allowed_policy.fetch(rule)
        end

        return true unless defined?(@allowed_policy)

        @allowed_policy
      end

      def sign_in_checkpoint_participant(cycle)
        checkpoint_participant || super
      end

      def sign_in_dashboard_participant(cycle)
        dashboard_participant || super
      end

      def jump_to_generated_url(url, fallback:)
        @jumped = [url, fallback]
      end

      def jumped
        @jumped
      end

      def t(key)
        "translated:#{key}"
      end

      def current_region_identifier
        "jp"
      end
    end

    ResourceStub = Struct.new(:id)
    BlockingParticipant =
      Struct.new(:cycle) do
        def advance_if_clear!
          SignInParticipantResult.new(
            participant: :checkpoint,
            stack: [SignInParticipantItem.new(key: :blocked_for_test, blocking: true, cleared: false)],
            next_status: "DASHBOARD_PENDING",
          )
        end
      end

    test "VALID_POLICIES constant is defined" do
      assert_equal %i(deny_all public_strict auth_required guest_only), AuthenticationBase::VALID_POLICIES
    end

    test "AUDIT_EVENTS constant is defined" do
      assert AuthenticationBase::AUDIT_EVENTS.key?(:logged_in)
      assert AuthenticationBase::AUDIT_EVENTS.key?(:logged_out)
      assert AuthenticationBase::AUDIT_EVENTS.key?(:login_failed)
      assert AuthenticationBase::AUDIT_EVENTS.key?(:token_refreshed)
    end

    test "ACCESS_COOKIE_KEY is defined" do
      assert_kind_of String, AuthenticationBase::ACCESS_COOKIE_KEY
      assert_equal "auth_access", AuthenticationBase::ACCESS_COOKIE_KEY
    end

    test "REFRESH_COOKIE_KEY is defined" do
      assert_kind_of String, AuthenticationBase::REFRESH_COOKIE_KEY
      assert_equal "auth_refresh", AuthenticationBase::REFRESH_COOKIE_KEY
    end

    test "ACCESS_TOKEN_TTL is defined" do
      assert_kind_of ActiveSupport::Duration, AuthenticationBase::ACCESS_TOKEN_TTL
    end

    test "REFRESH_TOKEN_TTL is defined" do
      assert_kind_of ActiveSupport::Duration, AuthenticationBase::REFRESH_TOKEN_TTL
    end

    test "Token class has JWT_ALGORITHM constant" do
      assert_equal "ES384", AuthenticationToken::JWT_ALGORITHM
    end

    test "Token.extract_subject returns nil for nil payload" do
      assert_nil AuthenticationToken.extract_subject(nil)
    end

    test "VALID_ACTOR_TYPES constant is defined" do
      assert_equal %w(client operator visitor), AuthenticationBase::VALID_ACTOR_TYPES
    end

    test "Token.extract_resource_type returns nil for nil payload" do
      assert_nil AuthenticationToken.extract_resource_type(nil)
    end

    test "begin_sign_in_sequence stores only safe encoded return paths" do
      harness = HeaderKeyHarness.new
      harness.resource = ResourceStub.new(42)
      Actor.tld = :app
      Actor.install_context!(authn: Actor::Authentication.new(amr: ["email_otp"]))

      unsafe_result = harness.send(
        :begin_sign_in_sequence!,
        pt: "https://evil.example/phish",
        checkpoint_required: true,
      )

      assert_equal :success, unsafe_result.status
      assert_nil harness.session.fetch(:app_sign_in_sequence).fetch("pt")
      assert_nil harness.session.fetch(:app_sign_in_sequence).fetch("safe_return_path")

      safe_result = harness.send(:begin_sign_in_sequence!, pt: "/settings", checkpoint_required: true)

      assert_equal :success, safe_result.status
      stored_rt = harness.session.fetch(:app_sign_in_sequence).fetch("pt")
      stored_safe_return_path = harness.session.fetch(:app_sign_in_sequence).fetch("safe_return_path")

      assert_equal "/settings", harness.path_from_signed_pt(stored_rt)
      assert_equal "/settings", harness.path_from_signed_pt(stored_safe_return_path)

      welcome_rt = "/welcome?ri=jp"
      welcome_result = harness.send(:begin_sign_in_sequence!, pt: welcome_rt, checkpoint_required: true)

      assert_equal :success, welcome_result.status
      assert_nil harness.session.fetch(:app_sign_in_sequence).fetch("pt")
      assert_nil harness.session.fetch(:app_sign_in_sequence).fetch("safe_return_path")
    ensure
      Actor.reset
    end

    test "checkpoint continuation uses db-backed sign-in cycle when locator is present" do
      user = create_db_sequence_client
      token = ClientToken.create!(user: user)
      cycle = db_sign_in_flow(user, token, status_name: "CHECKPOINT_PENDING", step: "checkpoint")
      harness = db_sequence_harness(user, token)
      SignInCycleLocator.new(harness.session, surface: :app, actor: user, token: token).issue!(cycle, nonce: "nonce")

      harness.send(:continue_checkpoint_sequence_without_content!)

      assert_predicate cycle.reload, :sign_in_dashboard_pending?
      redirected = URI.parse(harness.redirected.first)

      assert_equal "/welcome", redirected.path
      assert_equal "/after",
                   harness.path_from_signed_pt(Rack::Utils.parse_query(redirected.query).fetch("pt"))
      assert_equal 5, harness.session[:app_sign_in_welcome]["remaining"]
    end

    test "checkpoint continuation advances db-backed cycle while request is readonly" do
      user = create_db_sequence_client
      token = ClientToken.create!(user: user)
      cycle = db_sign_in_flow(user, token, status_name: "CHECKPOINT_PENDING", step: "checkpoint")
      harness = db_sequence_harness(user, token)
      SignInCycleLocator.new(harness.session, surface: :app, actor: user, token: token).issue!(cycle, nonce: "nonce")

      ActiveRecord::Base.connected_to(role: :reading, prevent_writes: true) do
        harness.send(:continue_checkpoint_sequence_without_content!)
      end

      assert_predicate cycle.reload, :sign_in_dashboard_pending?
      assert_equal "/welcome", URI.parse(harness.redirected.first).path
    end

    test "checkpoint continuation can carry dashboard as pt" do
      user = create_db_sequence_client
      token = ClientToken.create!(user: user)
      cycle = db_sign_in_flow(user, token, status_name: "CHECKPOINT_PENDING", step: "checkpoint")
      cycle.update!(return_to: "/dashboard?ri=jp")
      harness = db_sequence_harness(user, token)
      SignInCycleLocator.new(harness.session, surface: :app, actor: user, token: token).issue!(cycle, nonce: "nonce")

      harness.send(:continue_checkpoint_sequence_without_content!)

      assert_predicate cycle.reload, :sign_in_dashboard_pending?
      redirected = URI.parse(harness.redirected.first)

      assert_equal "/welcome", redirected.path
      assert_equal "/dashboard?ri=jp",
                   harness.path_from_signed_pt(Rack::Utils.parse_query(redirected.query).fetch("pt"))
    end

    test "checkpoint continuation keeps blocking db-backed cycle at checkpoint" do
      user = create_db_sequence_client
      token = ClientToken.create!(user: user)
      cycle = db_sign_in_flow(user, token, status_name: "CHECKPOINT_PENDING", step: "checkpoint")
      harness = db_sequence_harness(user, token)
      harness.checkpoint_participant = BlockingParticipant.new(cycle)
      SignInCycleLocator.new(harness.session, surface: :app, actor: user, token: token).issue!(cycle, nonce: "nonce")

      harness.send(:continue_checkpoint_sequence_without_content!)

      assert_nil harness.redirected
      assert_nil harness.rendered
      assert_predicate cycle.reload, :sign_in_checkpoint_pending?
    end

    test "dashboard continuation consumes db-backed return path before rendering welcome page" do
      user = create_db_sequence_client
      token = ClientToken.create!(user: user)
      cycle = db_sign_in_flow(user, token, status_name: "DASHBOARD_PENDING", step: "dashboard")
      harness = db_sequence_harness(user, token)
      SignInCycleLocator.new(harness.session, surface: :app, actor: user, token: token).issue!(cycle, nonce: "nonce")
      harness.send(:issue_welcome_gate_and_path, pt: "/after", sequence_id: cycle.public_id)

      harness.send(:continue_dashboard_sequence_without_content!)

      assert_nil harness.redirected
      assert_equal "/after", harness.instance_variable_get(:@welcome_next_path)
      assert_predicate cycle.reload, :sign_in_completed?
      assert_nil cycle.return_to
      assert_nil harness.session[:app_sign_in_welcome]
      assert_nil harness.session[:app_sign_in_flow_locator]
    end

    test "dashboard continuation binds current session before dashboard policy" do
      user = create_db_sequence_client
      token = ClientToken.create!(user: user)
      cycle = ClientSignInFlow.create!(
        principal_id: user.id,
        status_id: ClientSignInFlow.status_id_for("DASHBOARD_PENDING"),
        step: "dashboard",
        return_to: "/after",
        nonce_digest: ClientSignInFlow.digest_nonce("nonce"),
        issued_at: Time.current,
        expires_at: 15.minutes.from_now,
      )
      harness = db_sequence_harness(user, token)
      SignInCycleLocator.new(harness.session, surface: :app, actor: user, token: token).issue!(cycle, nonce: "nonce")
      harness.send(:issue_welcome_gate_and_path, pt: "/after", sequence_id: cycle.public_id)

      harness.send(:continue_dashboard_sequence_without_content!)

      assert_nil harness.redirected
      assert_equal token.id, cycle.reload.token_id
      assert_predicate cycle, :sign_in_completed?
      assert_equal "/after", harness.instance_variable_get(:@welcome_next_path)
    end

    test "dashboard continuation falls back when persisted return path points to dashboard" do
      user = create_db_sequence_client
      token = ClientToken.create!(user: user)
      cycle = db_sign_in_flow(user, token, status_name: "DASHBOARD_PENDING", step: "dashboard")
      cycle.update!(return_to: "/dashboard?ri=jp")
      harness = db_sequence_harness(user, token)
      SignInCycleLocator.new(harness.session, surface: :app, actor: user, token: token).issue!(cycle, nonce: "nonce")
      harness.send(:issue_welcome_gate_and_path, pt: cycle.return_to, sequence_id: cycle.public_id)

      harness.send(:continue_dashboard_sequence_without_content!)

      assert_nil harness.redirected
      assert_equal "/dashboard?ri=jp", harness.instance_variable_get(:@welcome_next_path)
      assert_predicate cycle.reload, :sign_in_completed?
      assert_nil cycle.return_to
    end

    test "dashboard continuation falls back when resolved return path is welcome" do
      user = create_db_sequence_client
      token = ClientToken.create!(user: user)
      cycle = db_sign_in_flow(user, token, status_name: "DASHBOARD_PENDING", step: "dashboard")
      cycle.update!(return_to: "/welcome?ri=jp")
      harness = db_sequence_harness(user, token)
      SignInCycleLocator.new(harness.session, surface: :app, actor: user, token: token).issue!(cycle, nonce: "nonce")
      harness.send(:issue_welcome_gate_and_path, pt: cycle.return_to, sequence_id: cycle.public_id)

      harness.send(:continue_dashboard_sequence_without_content!)

      assert_nil harness.redirected
      assert_equal "/dashboard", harness.instance_variable_get(:@welcome_next_path)
      assert_predicate cycle.reload, :sign_in_completed?
      assert_nil cycle.return_to
    end

    test "dashboard continuation redirects checkpoint-pending cycle back to checkpoint" do
      user = create_db_sequence_client
      token = ClientToken.create!(user: user)
      cycle = db_sign_in_flow(user, token, status_name: "CHECKPOINT_PENDING", step: "checkpoint")
      harness = db_sequence_harness(user, token)
      SignInCycleLocator.new(harness.session, surface: :app, actor: user, token: token).issue!(cycle, nonce: "nonce")

      harness.send(:continue_dashboard_sequence_without_content!)

      redirected = URI.parse(harness.redirected.first)

      assert_equal "/sign/in/check", redirected.path
      assert_equal "/after",
                   harness.path_from_signed_pt(Rack::Utils.parse_query(redirected.query).fetch("pt"))
      assert_predicate cycle.reload, :sign_in_checkpoint_pending?
    end

    test "dashboard continuation requires dashboard policy before advancing" do
      user = create_db_sequence_client
      token = ClientToken.create!(user: user)
      cycle = db_sign_in_flow(user, token, status_name: "DASHBOARD_PENDING", step: "dashboard")
      harness = db_sequence_harness(user, token)
      harness.allowed_policy = { show_dashboard?: false }
      SignInCycleLocator.new(harness.session, surface: :app, actor: user, token: token).issue!(cycle, nonce: "nonce")
      harness.send(:issue_welcome_gate_and_path, pt: cycle.return_to, sequence_id: cycle.public_id)

      assert_not harness.send(:continue_dashboard_sequence_without_content!)

      assert_equal({ plain: I18n.t("errors.messages.not_authorized"), status: :bad_request }, harness.rendered)
      assert_predicate cycle.reload, :sign_in_dashboard_pending?
      assert_equal "/after", cycle.return_to
    end

    test "db-backed sequence rejects wrong participant without advancing" do
      user = create_db_sequence_client
      token = ClientToken.create!(user: user)
      cycle = db_sign_in_flow(user, token, status_name: "DASHBOARD_PENDING", step: "dashboard")
      harness = db_sequence_harness(user, token)
      SignInCycleLocator.new(harness.session, surface: :app, actor: user, token: token).issue!(cycle, nonce: "nonce")

      assert_not harness.send(:continue_checkpoint_sequence_without_content!)

      assert_equal({ plain: I18n.t("errors.messages.not_authorized"), status: :bad_request }, harness.rendered)
      assert_predicate cycle.reload, :sign_in_dashboard_pending?
    end

    test "checkpoint sequence participant rejects stale bulletin without sequence state" do
      harness = HeaderKeyHarness.new
      harness.allowed_policy = { show_checkpoint?: false }
      harness.session[AuthenticationBase::BULLETIN_SESSION_KEY] = {
        "issued_at" => Time.current.to_i,
        "kind" => "checkpoint",
        "state" => "new",
        "bulletin_id" => 123,
      }

      assert_not harness.send(
        :require_sign_in_sequence_participant!,
        participant: :checkpoint,
        policy_rule: :show_checkpoint?,
      )

      assert_equal({ plain: I18n.t("errors.messages.not_authorized"), status: :bad_request }, harness.rendered)
    end

    test "Token.extract_session_id returns nil for nil payload" do
      assert_nil AuthenticationToken.extract_session_id(nil)
    end

    test "Token.extract_jti returns nil for nil payload" do
      assert_nil AuthenticationToken.extract_jti(nil)
    end

    test "JwtConfiguration.issuer returns string" do
      issuer = AuthenticationJwtConfiguration.issuer

      assert_kind_of String, issuer
    end

    test "JwtConfiguration.audiences requires a resource type" do
      assert_raises(ArgumentError) { AuthenticationJwtConfiguration.audiences }
    end

    test "JwtConfiguration.leeway_seconds returns integer" do
      assert_kind_of Integer, AuthenticationJwtConfiguration.leeway_seconds
    end

    test "MissingPolicyError is a StandardError" do
      assert_operator AuthenticationBase::MissingPolicyError, :<, StandardError
    end

    test "InvalidPolicyError is a StandardError" do
      assert_operator AuthenticationBase::InvalidPolicyError, :<, StandardError
    end

    test "SkipNotAllowedError is a StandardError" do
      assert_operator AuthenticationBase::SkipNotAllowedError, :<, StandardError
    end

    test "request guard helpers render or redirect when already logged in" do
      harness = HeaderKeyHarness.new
      harness.logged_in = true

      harness.ensure_not_logged_in

      assert_equal "この操作を行う権限がありません。", harness.rendered[:plain]
      assert_equal :unauthorized, harness.rendered[:status]

      harness.ensure_not_logged_in(message_key: "auth.denied")

      assert_equal "translated:auth.denied", harness.rendered[:plain]

      assert harness.reject_if_logged_in("auth.bad_request")
      assert_equal "translated:auth.bad_request", harness.rendered[:plain]
      assert_equal :bad_request, harness.rendered[:status]

      harness.json_request!
      harness.ensure_not_logged_in_for_registration(redirect_path: "/dashboard", message_key: "auth.denied")

      assert_equal :unauthorized, harness.rendered[:status]

      harness.html_request!
      harness.ensure_not_logged_in_for_registration(redirect_path: "/dashboard", message_key: "auth.denied")

      assert_equal ["/dashboard", { alert: "translated:auth.denied" }], harness.redirected
    end

    test "request guard helpers no-op when not logged in" do
      harness = HeaderKeyHarness.new

      assert_nil harness.ensure_not_logged_in
      assert_not harness.reject_if_logged_in("auth.bad_request")
      assert_nil harness.ensure_not_logged_in_for_registration
      assert_nil harness.rendered
      assert_nil harness.redirected
    end

    test "redirect parameter helpers preserve peek retrieve and build params" do
      harness = HeaderKeyHarness.new
      harness.params = { pt: harness.signed_pt_token("/target") }

      result = harness.preserve_pt

      assert_equal "/target", harness.path_from_signed_pt(result)
      assert_equal result, harness.session[AuthenticationBase::DEFAULT_PT_SESSION_KEY]
      assert_equal "/target", harness.path_from_signed_pt(harness.peek_pt)
      assert_equal "/target", harness.path_from_signed_pt(harness.build_notice_params("ok")[:pt])
      assert_equal "/target", harness.path_from_signed_pt(harness.build_alert_params("ng")[:pt])
      assert_equal "/target", harness.path_from_signed_pt(harness.retrieve_pt)
      assert_nil harness.session[AuthenticationBase::DEFAULT_PT_SESSION_KEY]
    end

    test "redirect parameter helpers reject unsigned pt params" do
      harness = HeaderKeyHarness.new
      harness.params = { pt: "/target" }

      assert_nil harness.preserve_pt
      assert_nil harness.peek_pt
      assert_nil harness.retrieve_pt
      assert_nil harness.session[AuthenticationBase::DEFAULT_PT_SESSION_KEY]
    end

    test "redirect_with_pt_handling uses pt jump when present and fallback redirect otherwise" do
      harness = HeaderKeyHarness.new
      pt = harness.signed_pt_token("/dashboard")
      harness.session[AuthenticationBase::DEFAULT_PT_SESSION_KEY] = pt

      harness.redirect_with_pt_handling("/default", :notice, "done")

      assert_empty harness.flash
      assert_equal [harness.path_from_signed_pt(pt), { allow_other_host: false }],
                   harness.redirected

      harness.redirect_with_pt_handling("/default", :alert, "warn")

      assert_empty harness.flash
      assert_equal ["/default", {}], harness.redirected
    end

    test "JwtConfiguration.issuer is the test-environment authorization-server identity" do
      assert_equal "urn:umaxica:test:auth", AuthenticationJwtConfiguration.issuer
    end

    test "JwtConfiguration.audiences requires distinct resource-specific env" do
      with_env(
        "AUTH_JWT_CLIENT_AUDIENCES" => "u1,u2",
        "AUTH_JWT_VISITOR_AUDIENCES" => "v1",
        "AUTH_JWT_OPERATOR_AUDIENCES" => "o1",
      ) do
        assert_equal %w(u1 u2), AuthenticationJwtConfiguration.audiences("client")
        assert_equal %w(o1), AuthenticationJwtConfiguration.audiences("operator")
      end
    end

    test "JwtConfiguration.audiences rejects missing blank and overlapping values" do
      with_env("AUTH_JWT_CLIENT_AUDIENCES" => nil) do
        assert_raises(KeyError) { AuthenticationJwtConfiguration.audiences("client") }
      end
      with_env("AUTH_JWT_CLIENT_AUDIENCES" => "  ") do
        assert_raises(KeyError) { AuthenticationJwtConfiguration.audiences("client") }
      end
      with_env(
        "AUTH_JWT_CLIENT_AUDIENCES" => "shared",
        "AUTH_JWT_VISITOR_AUDIENCES" => "shared",
        "AUTH_JWT_OPERATOR_AUDIENCES" => "operator-only",
      ) do
        assert_raises(ArgumentError) { AuthenticationJwtConfiguration.audiences("client") }
      end
    end

    private

    def create_db_sequence_client
      ClientStatus.ensure_defaults!
      ClientVisibility.ensure_defaults!
      ClientMfaLevel.ensure_defaults!
      ClientMfaStatus.ensure_defaults!
      ClientTokenBindingMethod.ensure_defaults!
      ClientTokenDbscStatus.ensure_defaults!
      ClientTokenKind.ensure_defaults!
      ClientTokenStatus.ensure_defaults!

      Client.create!(
        public_id: "u_#{SecureRandom.hex(8)}",
        status_id: ClientStatus::ACTIVE,
        visibility_id: ClientVisibility::USER,
        mfa_level_id: ClientMfaLevel::NOTHING,
        mfa_status_id: ClientMfaStatus::UNCONFIGURED,
      )
    end

    def db_sequence_harness(user, token)
      HeaderKeyHarness.new.tap do |harness|
        harness.actor_type = "client"
        harness.resource = user
        harness.current_session_record = token
      end
    end

    def db_sign_in_flow(user, token, status_name:, step:)
      ClientSignInFlow.create!(
        principal_id: user.id,
        token: token,
        status_id: ClientSignInFlow.status_id_for(status_name),
        step: step,
        return_to: "/after",
        nonce_digest: ClientSignInFlow.digest_nonce("nonce"),
        issued_at: Time.current,
        expires_at: 15.minutes.from_now,
      )
    end

    def with_env(vars)
      original = vars.keys.index_with { |k| ENV[k] }
      vars.each { |k, v| ENV[k] = v }
      yield
    ensure
      original.each { |k, v| ENV[k] = v }
    end
  end
end

# rubocop:enable I18n/RailsI18n/DecorateString

# DAMP local route helper aliases for former shared test support.
class Auth::BaseTest
  SURFACE_ROUTE_PREFIX_MAP = {
    "sign_app_" => "auth_app_",
    "sign_org_" => "auth_org_",
    "sign_com_" => "auth_com_",
    "acme_app_" => "base_app_",
    "acme_org_" => "base_org_",
    "acme_com_" => "base_com_",
  }.freeze unless const_defined?(:SURFACE_ROUTE_PREFIX_MAP, false)

  private

  def method_missing(name, ...)
    aliased_name = aliased_surface_route_helper_name(name)
    return public_send(aliased_name, ...) if aliased_name && respond_to?(aliased_name, true)

    super
  end

  def respond_to_missing?(name, include_private = false)
    aliased_name = aliased_surface_route_helper_name(name)
    (aliased_name && respond_to?(aliased_name, include_private)) || super
  end

  def aliased_surface_route_helper_name(name)
    helper_name = name.to_s
    self.class::SURFACE_ROUTE_PREFIX_MAP.each do |source_prefix, target_prefix|
      return helper_name.sub(source_prefix, target_prefix).to_sym if helper_name.start_with?(source_prefix)
    end
    nil
  end
end
