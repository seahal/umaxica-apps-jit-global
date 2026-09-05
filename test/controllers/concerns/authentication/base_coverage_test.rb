# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class AuthenticationBaseTestController < ApplicationController
  include AuthenticationBase

  coverage_methods = %i(
    load_session_record redirect_with_pt_handling peek_pt epoch_seconds issue_bulletin!
    handle_auth_required_json handle_guest_only_json load_authentication_session
    store_authentication_session clear_authentication_session validate_session_expiry
    redirect_to_pt_or_default! refresh_failure_status refresh_failure_code cookie_options
    cookie_deletion_options clear_auth_cookies! occurrence_model_class normalize_amr
    session_management_path after_login_path default_after_login_path max_sessions_for_resource
    store_pending_login_resource token_expiry_column access_token_expires_at_for
    refresh_cookie_expires_at_for expires_in_for mfa_bypassed_for_auth_method?
    resolve_mfa_pt decode_base64_urlsafe mfa_entry_path handle_auth_required_html
    handle_guest_only_with_status_checks handle_guest_only_html current_session_restricted?
    current_account transparent_refresh_access_token authenticate! bulletin_association_for_resource
    withdrawal_gate_redirect_path handle_missing_refresh_token handle_inactive_resource
    handle_administrative_access_locked_refresh handle_refresh_error resolve_token_kind_id enforce_authentication_open!
    policy_for_authentication_mode find_restricted_sessions_scope dbsc_route_helper
    default_status_token_attributes login_token_reference_models
    count_active_sessions best_effort_refresh_side_effect token_class_for_resource
    enforce_authentication_private! enforce_authentication_guest! resolve_access_policy_for
    refresh_dbsc_allowed? refresh_dbsc_source refresh_binding_source
    token_kind_model set_pending_mfa! pending_mfa pending_mfa_valid? clear_pending_mfa!
    session_limit_gate_pt session_limit_gate_flow reissue_access_token!
    log_in populate_current_attributes! path_from_signed_pt signed_pt_token
    issue_dbsc_challenge_for! legacy_unbound_refresh_allowed? dbsc_registration_challenge_expired?
    downgrade_pending_dbsc_to_nothing! dbsc_registration_eligible_kind? default_dbsc_token_attributes
    refresh_dpop_allowed? refresh_idle_allowed? handle_refresh_idle_timeout
    detect_session_network_change!
    resource_class token_class audit_class resource_type resource_foreign_key
    sign_in_url_with_pt am_i_user? am_i_operator? am_i_owner?
    network_hmac_for_request device_session_refresh_allowed?
    revoke_refresh_session_after_dbsc_failure! token_expired_or_revoked?
    withdrawal_required_session_entry_path
    actor_current_resource
  )

  def index
    render plain: "ok"
  end

  def current_region_identifier
    params[:ri].to_s
  end

  coverage_methods.each do |method_name|
    next unless method_defined?(method_name) || private_method_defined?(method_name)

    send(:public, method_name)
  end
end

class AuthenticationBaseFakeModel
  class << self
    def record=(val)
      @record = val
    end

    def record
      @record
    end
  end

  class << self
    def find_by(id:)
      record if record&.id == id
    end
  end
end

class AuthenticationBaseFakeTokenWithLapsesAt
  def self.name = "AuthenticationBaseFakeTokenWithLapsesAt"

  def self.column_names = %w(discarded_at)
end

class AuthenticationBaseFakeTokenWithoutExpiry
  def self.name = "AuthenticationBaseFakeTokenWithoutExpiry"

  def self.column_names = []
end

class AuthenticationBaseCoverageTest < ActionDispatch::IntegrationTest
  setup do
    @original_login_cooldown = login_cooldown
    self.login_cooldown = 0.seconds
    @controller = AuthenticationBaseTestController.new
    @user = clients(:one)

    # Mock request
    @request = ActionDispatch::TestRequest.create
    @controller.request = @request
    @controller.response = ActionDispatch::TestResponse.new
    @session_hash = {}
    @controller.define_singleton_method(:session) { @session_hash }
    @controller.instance_variable_set(:@session_hash, @session_hash)
  end

  teardown do
    self.login_cooldown = @original_login_cooldown
  end

  test "redirect_with_pt_handling hits branches" do
    @controller.stub(:session, { "pt" => "/foo" }) do
      @controller.stub(:redirect_to, true) do
        @controller.redirect_with_pt_handling("/", :notice, "msg", "pt")
        @controller.redirect_with_pt_handling("/", :alert, "msg", "pt")
      end
    end

    assert_not_nil @controller
  end

  test "peek_pt" do
    token = @controller.signed_pt_token("/foo")

    @controller.stub(:session, { "pt" => token }) do
      assert_equal token, @controller.peek_pt("pt")
    end
  end

  test "epoch_seconds" do
    assert_equal 100, @controller.epoch_seconds(100)
    assert_equal 0, @controller.epoch_seconds(nil)
  end

  test "populate_current_attributes replaces stale Actor authentication when payload is nil" do
    Actor.install_context!(authn: Actor::Authentication.new(access_claims: { "sid" => "stale" }))
    @controller.define_singleton_method(:resource_type) { "client" }

    @controller.populate_current_attributes!(@user, nil)

    assert_nil Actor.authn.access_claims
    assert_equal @user, Actor.actor
    assert_equal :client, Actor.actor_type
  ensure
    Actor.reset
  end

  test "authentication readers prefer Actor snapshot after authentication" do
    @controller.define_singleton_method(:resource_type) { "client" }
    @controller.define_singleton_method(:resource_class) { Client }
    Actor.install_context!(
      actor: @user,
      actor_type: :client,
      authn: Actor::Authentication.new(
        login_public_id: "actor-session",
        actor_type: :client,
        actor_id: @user.id,
        restricted: true,
      ),
    )
    @controller.instance_variable_set(:@current_resource, nil)
    @controller.instance_variable_set(:@current_session_public_id, "ivar-session")

    assert_equal @user, @controller.current_resource
    assert_equal "actor-session", @controller.current_session_public_id
    assert_predicate @controller, :current_session_restricted?
  ensure
    Actor.reset
  end

  test "clearing auth cookies clears Actor snapshot and memoized authentication readers" do
    @controller.define_singleton_method(:cookie_deletion_options) { {} }
    @controller.define_singleton_method(:clear_dbsc_cookie!) { nil }
    cookie_store =
      Class.new(Hash) do
        def delete(key, _options = nil)
          super(key)
        end
      end
    @controller.define_singleton_method(:cookies) { @cookies ||= cookie_store.new }
    @controller.cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = "access"
    @controller.cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = "refresh"
    Actor.install_context!(
      actor: @user,
      actor_type: :client,
      authn: Actor::Authentication.new(
        login_public_id: "actor-session",
        actor_type: :client,
        actor_id: @user.id,
      ),
    )
    @controller.instance_variable_set(:@current_resource, @user)
    @controller.instance_variable_set(:@current_session, Object.new)
    @controller.instance_variable_set(:@current_session_public_id, "actor-session")

    @controller.clear_auth_cookies!

    assert_same Unauthenticated.instance, Actor.actor
    assert_equal Actor::Authentication::NULL, Actor.authn
    assert_nil @controller.instance_variable_get(:@current_resource)
    assert_nil @controller.instance_variable_get(:@current_session)
    assert_nil @controller.instance_variable_get(:@current_session_public_id)
  ensure
    Actor.reset
  end

  test "issue_bulletin! hits branches" do
    @controller.stub(:current_resource, @user) do
      @controller.issue_bulletin!
    end

    assert_not_nil @controller
  end

  test "Token.encode with all params" do
    host = "app.localhost"
    token = AuthenticationToken.encode(
      @user,
      host: host,
      resource_type: "client",
      session_public_id: "sid",
      acr: "aal1",
      amr: ["email"],
      expires_at: 1.hour.from_now.to_i,
    )

    assert_not_nil token
  end

  test "authentication session helpers handle valid missing and invalid records" do
    record = Struct.new(:id).new(123)
    AuthenticationBaseFakeModel.record = record

    @controller.store_authentication_session(:auth_id, 123)

    assert_equal record,
                 @controller.load_authentication_session(:auth_id, AuthenticationBaseFakeModel, "/expired", "expired")

    @controller.clear_authentication_session(:auth_id)

    assert_nil @controller.session[:auth_id]

    redirects = []
    @controller.define_singleton_method(:handle_session_expiry) do |path, message|
      redirects << [path, message]
    end

    assert_nil @controller.load_authentication_session(:missing, AuthenticationBaseFakeModel, "/expired", "expired")
    assert_equal [["/expired", "expired"]], redirects

    @controller.session[:auth_id] = 123

    assert_nil @controller.load_authentication_session(:auth_id, AuthenticationBaseFakeModel, "/expired", "expired") {
      false
    }
    assert_equal [["/expired", "expired"], ["/expired", "expired"]], redirects
  ensure
    AuthenticationBaseFakeModel.record = nil
  end

  test "session expiry validations cover edge cases" do
    assert_not @controller.validate_session_expiry(nil)
    assert_not @controller.validate_session_expiry({})
    assert @controller.validate_session_expiry({ "expires_at" => 5.minutes.from_now.to_i })
    assert_not @controller.validate_session_expiry({ "expires_at" => 1.minute.ago.to_i })
  end

  test "session record validations cover edge cases" do
    record = Struct.new(:id, :expired, :user_email_status_id) do
      define_method(:otp_expired?) do
        expired
      end
    end.new(7, false, 1)
    AuthenticationBaseFakeModel.record = record

    assert_nil @controller.load_session_record(:email_id, AuthenticationBaseFakeModel)

    @controller.session[:email_id] = 7

    assert_equal record, @controller.load_session_record(:email_id, AuthenticationBaseFakeModel)
    assert_equal record, @controller.load_session_record(:email_id, AuthenticationBaseFakeModel, check_otp_expiry: true)
    assert_equal record, @controller.load_session_record(:email_id, AuthenticationBaseFakeModel, status_id: 1)
    assert_equal record, @controller.load_session_record(
      :email_id, AuthenticationBaseFakeModel, custom: ->(candidate) { candidate.id == 7 },
    )

    record.expired = true

    assert_nil @controller.load_session_record(:email_id, AuthenticationBaseFakeModel, check_otp_expiry: true)
    record.expired = false

    assert_nil @controller.load_session_record(:email_id, AuthenticationBaseFakeModel, status_id: 2)
    assert_nil @controller.load_session_record(:email_id, AuthenticationBaseFakeModel, custom: ->(*) { false })
  ensure
    AuthenticationBaseFakeModel.record = nil
  end

  test "redirect refresh failure helpers cover branches" do
    redirects = []
    @controller.define_singleton_method(:jump_to_generated_url) { |pt, fallback:| redirects << [:jump, pt, fallback] }
    @controller.define_singleton_method(:redirect_to) { |path, **| redirects << [:redirect, path] }
    @controller.define_singleton_method(:render_invalid_return_target!) { redirects << [:invalid_rt] }

    @controller.redirect_to_pt_or_default!("encoded-pt", default_path: "/default")
    @controller.redirect_to_pt_or_default!(nil, default_path: "/default")

    assert_equal [[:invalid_rt], [:redirect, "/default"]], redirects
    assert_equal :unauthorized, @controller.refresh_failure_status
    assert_equal "invalid_refresh_token", @controller.refresh_failure_code

    @controller.instance_variable_set(:@refresh_failure_status, :forbidden)
    @controller.instance_variable_set(:@refresh_failure_code, "withdrawal_required")

    assert_equal :forbidden, @controller.refresh_failure_status
    assert_equal "withdrawal_required", @controller.refresh_failure_code
  end

  test "cookie helpers cover branches" do
    @controller.send(:cookies)[AuthenticationBase::ACCESS_COOKIE_KEY] = "access"
    @controller.send(:cookies)[AuthenticationBase::REFRESH_COOKIE_KEY] = "refresh"
    @controller.send(:cookies)[AuthenticationBase::DBSC_COOKIE_KEY] = "dbsc"
    @controller.clear_auth_cookies!

    assert_nil @controller.instance_variable_get(:@current_resource)
    assert_nil @controller.send(:cookies)[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil @controller.send(:cookies)[AuthenticationBase::REFRESH_COOKIE_KEY]
    assert_nil @controller.send(:cookies)[AuthenticationBase::DBSC_COOKIE_KEY]
    assert_not @controller.cookie_deletion_options.key?(:expires)
    assert_not @controller.cookie_options.key?(:domain)
    assert_not @controller.cookie_deletion_options.key?(:domain)
    assert_equal :strict, @controller.cookie_options[:same_site]
  end

  test "cookie deletion options preserve secure attributes for host-prefixed production cookies" do
    env = ActiveSupport::EnvironmentInquirer.new("production")

    Rails.stub(:env, env) do
      options = @controller.cookie_deletion_options

      assert_equal "/", options[:path]
      assert_equal :strict, options[:same_site]
      assert options[:secure]
      assert options[:partitioned]
      assert_not options.key?(:domain)
      assert_not options.key?(:httponly)
      assert_not options.key?(:expires)
    end
  end

  test "cookie deletion options work for non host-prefixed test cookies" do
    env = ActiveSupport::EnvironmentInquirer.new("test")

    Rails.stub(:env, env) do
      options = @controller.cookie_deletion_options

      assert_equal "auth_access", AuthenticationCookieName.access
      assert_equal "auth_refresh", AuthenticationCookieName.refresh
      assert_equal "auth_dbsc", AuthenticationCookieName.dbsc
      assert_equal "/", options[:path]
      assert_equal :strict, options[:same_site]
      assert_not options[:secure]
      assert_not options.key?(:partitioned)
      assert_not options.key?(:domain)
      assert_not options.key?(:httponly)
      assert_not options.key?(:expires)
    end
  end

  test "cookie deletion options work for non host-prefixed development cookies" do
    env = ActiveSupport::EnvironmentInquirer.new("development")

    Rails.stub(:env, env) do
      options = @controller.cookie_deletion_options

      assert_equal "auth_access", AuthenticationCookieName.access
      assert_equal "auth_refresh", AuthenticationCookieName.refresh
      assert_equal "auth_dbsc", AuthenticationCookieName.dbsc
      assert_equal "/", options[:path]
      assert_equal :strict, options[:same_site]
      assert_not options[:secure]
      assert_not options.key?(:partitioned)
      assert_not options.key?(:domain)
      assert_not options.key?(:httponly)
      assert_not options.key?(:expires)
    end
  end

  test "occurrence model and amr helpers" do
    @controller.define_singleton_method(:resource_type) { "client" }

    assert_equal ClientOccurrence, @controller.occurrence_model_class

    @controller.define_singleton_method(:resource_type) { "operator" }

    assert_equal OperatorOccurrence, @controller.occurrence_model_class

    @controller.define_singleton_method(:resource_type) { "visitor" }

    assert_equal VisitorOccurrence, @controller.occurrence_model_class

    assert_equal ["email_otp"], @controller.normalize_amr("email")
    assert_equal ["passkey"], @controller.normalize_amr("passkey")
    assert_equal ["google"], @controller.normalize_amr("google")
    assert_equal ["apple"], @controller.normalize_amr("apple")
    assert_equal ["passcode"], @controller.normalize_amr("secret_credential")
    assert_equal [], @controller.normalize_amr("unknown")
  end

  test "normalize_amr prefers established_authentication_method on the token record" do
    @controller.define_singleton_method(:resource_type) { "client" }

    token_record = Struct.new(:established_authentication_method).new("telephone")

    assert_equal ["sms"], @controller.normalize_amr("BROWSER_WEB", token_record: token_record)

    token_record = Struct.new(:established_authentication_method).new("totp")

    assert_equal ["otp"], @controller.normalize_amr("BROWSER_WEB", token_record: token_record)

    token_record = Struct.new(:established_authentication_method).new("entra")

    assert_equal ["entra_id"], @controller.normalize_amr("BROWSER_WEB", token_record: token_record)

    token_record = Struct.new(:established_authentication_method).new("secret")

    assert_equal ["passcode"], @controller.normalize_amr("BROWSER_WEB", token_record: token_record)
  end

  test "normalize_amr falls back to token_kind_id when the token record has no recorded method" do
    @controller.define_singleton_method(:resource_type) { "client" }

    token_record = Struct.new(:established_authentication_method).new(nil)

    assert_equal ["email_otp"], @controller.normalize_amr("email", token_record: token_record)
    assert_equal [], @controller.normalize_amr("BROWSER_WEB", token_record: token_record)
    assert_equal ["passkey"], @controller.normalize_amr("passkey", token_record: nil)
  end

  test "path and token expiry helpers" do
    @controller.define_singleton_method(:resource_type) { "client" }

    assert_equal "/sign/in/session", @controller.session_management_path
    assert_equal "/", @controller.after_login_path
    assert_equal "/", @controller.default_after_login_path

    assert_equal :discarded_at, @controller.token_expiry_column(AuthenticationBaseFakeTokenWithLapsesAt)
    assert_raises(ArgumentError) { @controller.token_expiry_column(AuthenticationBaseFakeTokenWithoutExpiry) }

    now = Time.current
    token = Struct.new(:discarded_at, :refresh_expires_at).new(now + 30.minutes, now + 2.hours)

    assert_equal (now + AuthenticationBase::ACCESS_TOKEN_TTL).to_i,
                 @controller.access_token_expires_at_for(token, now: now).to_i
    assert_equal (now + 30.minutes).to_i, @controller.refresh_cookie_expires_at_for(token).to_i
    assert_equal 60, @controller.expires_in_for(now + 60.seconds, now: now)
    assert_equal 0, @controller.expires_in_for(now - 1.second, now: now)
  end

  test "session management path raises route helper errors" do
    @controller.define_singleton_method(:sign_app_sign_in_session_path) do
      raise StandardError, "route missing"
    end

    error =
      assert_raises(StandardError) do
        @controller.session_management_path
      end

    assert_equal "route missing", error.message
  end

  test "session_management_path and default_after_login_path prefer org/com surface helpers" do
    # The real route helper module resolves sign_app_sign_in_session_path/auth_app_root_path
    # dynamically (respond_to_missing?), so it can't be undef'd; stub respond_to? instead to
    # exercise the org/com fallback branches the same way a Sign::Org/Sign::Com controller would.
    hidden = %i(sign_app_sign_in_session_path auth_app_root_path)
    @controller.define_singleton_method(:respond_to?) do |name, include_private = false|
      return false if hidden.include?(name.to_sym)

      super(name, include_private)
    end
    @controller.define_singleton_method(:sign_org_sign_in_session_path) { "/org/sign/in/session" }

    assert_equal "/org/sign/in/session", @controller.session_management_path

    @controller.define_singleton_method(:respond_to?) do |name, include_private = false|
      return false if (hidden + [:sign_org_sign_in_session_path]).include?(name.to_sym)

      super(name, include_private)
    end
    @controller.define_singleton_method(:sign_com_sign_in_session_path) { "/com/sign/in/session" }

    assert_equal "/com/sign/in/session", @controller.session_management_path

    @controller.define_singleton_method(:auth_org_root_path) { "/org/root" }

    assert_equal "/org/root", @controller.default_after_login_path
  end

  test "session limit gate flow raises resource type errors" do
    original_respond_to = @controller.method(:respond_to?)
    @controller.define_singleton_method(:respond_to?) do |name, include_private = false|
      (name == :controller_path) ? false : original_respond_to.call(name, include_private)
    end
    @controller.define_singleton_method(:resource_type) do
      raise StandardError, "resource type missing"
    end

    error =
      assert_raises(StandardError) do
        @controller.session_limit_gate_flow
      end

    assert_equal "resource type missing", error.message
  end

  test "issue_dbsc_challenge_for raises persistence errors" do
    token = Struct.new(:id).new(123)
    token.define_singleton_method(:update!) do |**|
      raise StandardError, "db write failed"
    end
    token.class.define_singleton_method(:find) do |id|
      token if id == token.id
    end

    error =
      assert_raises(StandardError) do
        @controller.issue_dbsc_challenge_for!(token)
      end

    assert_equal "db write failed", error.message
  end

  test "mfa and base64 helpers" do
    assert @controller.mfa_bypassed_for_auth_method?("passkey")
    assert_not @controller.mfa_bypassed_for_auth_method?(:google)
    assert_not @controller.mfa_bypassed_for_auth_method?(:social)
    assert_not @controller.mfa_bypassed_for_auth_method?(:apple)
    assert_not @controller.mfa_bypassed_for_auth_method?("email")

    assert_equal "/safe/path", @controller.resolve_mfa_pt(Base64.urlsafe_encode64("/safe/path"))
    assert_nil @controller.resolve_mfa_pt(Base64.urlsafe_encode64("http://test.host/safe/path?ri=jp"))
    assert_nil @controller.resolve_mfa_pt(Base64.urlsafe_encode64("https://evil.example"))
    assert_nil @controller.resolve_mfa_pt("")

    assert_equal "decoded", @controller.decode_base64_urlsafe(Base64.urlsafe_encode64("decoded"))
    assert_nil @controller.decode_base64_urlsafe("%%%")

    assert_equal "/sign/in/challenge?ri=jp", @controller.mfa_entry_path(ri: "jp")
  end

  test "mfa_entry_path falls back to org helper then the literal path" do
    @controller.define_singleton_method(:respond_to?) do |name, include_private = false|
      return false if name.to_sym == :sign_app_sign_in_challenge_path

      super(name, include_private)
    end
    @controller.define_singleton_method(:sign_org_sign_in_challenge_path) { |ri:| "/org/sign/in/challenge?ri=#{ri}" }

    assert_equal "/org/sign/in/challenge?ri=jp", @controller.mfa_entry_path(ri: "jp")

    @controller.define_singleton_method(:respond_to?) do |name, include_private = false|
      return false if %i(sign_app_sign_in_challenge_path sign_org_sign_in_challenge_path).include?(name.to_sym)

      super(name, include_private)
    end

    assert_equal "/sign/in/challenge", @controller.mfa_entry_path(ri: "jp")
  end

  test "withdrawal_required_session_entry_path resolves per controller surface" do
    @controller.define_singleton_method(:controller_path) { "base/app/identity/removals" }

    assert_match %r{\A/}, @controller.withdrawal_required_session_entry_path

    @controller.define_singleton_method(:controller_path) { "base/com/identity/removals" }

    assert_match %r{\A/}, @controller.withdrawal_required_session_entry_path

    @controller.define_singleton_method(:controller_path) { "auth/com/settings/removals" }

    assert_match %r{\A/}, @controller.withdrawal_required_session_entry_path

    @controller.define_singleton_method(:controller_path) { "some/unrelated/controller" }

    assert_match %r{\A/}, @controller.withdrawal_required_session_entry_path
  end

  test "policy response helpers render and redirect expected shapes" do
    @request.set_header("REQUEST_METHOD", "GET")
    rendered = []
    redirected = []
    @controller.define_singleton_method(:render) { |*args, **kwargs| rendered << [args, kwargs] }
    @controller.define_singleton_method(:redirect_to) { |*args, **kwargs| redirected << [args, kwargs] }
    @controller.define_singleton_method(:main_app) {
      Struct.new(:sign_in_path, :after_login_path).new("/main/sign_in", "/main/after")
    }
    @controller.define_singleton_method(:sign_in_url_with_pt) do |pt|
      raise RuntimeError, "return target must not be carried in sign-in URL" if pt.present?

      "/in"
    end

    @controller.handle_auth_required_json(message: "login", status: :forbidden)
    @controller.handle_guest_only_json(message: "guest", status: :unauthorized)
    @controller.handle_auth_required_html(message: "login html")
    @controller.handle_guest_only_with_status_checks(status: :unauthorized, message: "nope")
    @controller.handle_guest_only_with_status_checks(status: :bad_request, message: "bad")
    @controller.handle_guest_only_html(message: "already")

    assert_equal [{ error: "login" }, { error: "guest" }], rendered.first(2).map { |r| r.last[:json] }
    assert_equal [:forbidden, :unauthorized], rendered.first(2).map { |r| r.last[:status] }
    assert_equal "/in", redirected.first.first.first
    assert_predicate @session_hash[AuthenticationBase::DEFAULT_PT_SESSION_KEY], :present?
    assert_equal ["/"], redirected.last.first
    assert_equal 2, rendered.size
    assert_equal 4, redirected.size
  end

  test "guest only no redirect renders plain text for signed in entry attempts" do
    @request.set_header("REQUEST_METHOD", "GET")
    rendered = []
    redirected = []
    @controller.define_singleton_method(:render) { |*args, **kwargs| rendered << [args, kwargs] }
    @controller.define_singleton_method(:redirect_to) { |*args, **kwargs| redirected << [args, kwargs] }

    @controller.handle_guest_only_with_status_checks(
      status: :unauthorized,
      message: "already signed in",
      no_redirect: true,
    )

    assert_empty redirected
    assert_equal "already signed in", rendered.last.last[:plain]
    assert_equal :unauthorized, rendered.last.last[:status]
  end

  test "reject logged in session renders plain text without redirect" do
    rendered = []
    redirected = []
    @controller.define_singleton_method(:logged_in?) { true }
    @controller.define_singleton_method(:render) { |*args, **kwargs| rendered << [args, kwargs] }
    @controller.define_singleton_method(:redirect_to) { |*args, **kwargs| redirected << [args, kwargs] }

    @controller.reject_logged_in_session

    assert_empty redirected
    assert_equal I18n.t("errors.messages.already_authenticated"), rendered.last.last[:plain]
    assert_equal :unauthorized, rendered.last.last[:status]
  end

  test "resource session helpers handle supported and fallback resources" do
    staff = operators(:one)
    VisitorStatus.find_or_create_by!(id: VisitorStatus::ACTIVE)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)

    assert_equal ClientToken::MAX_SESSIONS_PER_USER, @controller.max_sessions_for_resource(@user)
    assert_equal OperatorToken::MAX_SESSIONS_PER_STAFF, @controller.max_sessions_for_resource(staff)
    assert_equal VisitorToken::MAX_SESSIONS_PER_VISITOR, @controller.max_sessions_for_resource(visitor)
    assert_equal 2, @controller.max_sessions_for_resource(Object.new)

    @controller.store_pending_login_resource(@user)
    @controller.store_pending_login_resource(staff)
    @controller.store_pending_login_resource(visitor)

    assert_equal @user.id, @controller.session[:pending_login_user_id]
    assert_equal staff.id, @controller.session[:pending_login_staff_id]
    assert_equal visitor.id, @controller.session[:pending_login_visitor_id]
    assert_nil @controller.current_session_restricted?
  end

  test "current account and bulletin association cover user and empty branches" do
    staff = operators(:one)

    @controller.define_singleton_method(:current_resource) { @current_resource_for_test }
    @controller.instance_variable_set(:@current_resource_for_test, @user)
    begin
      assert_equal @user, @controller.current_account
      @controller.instance_variable_set(:@current_resource_for_test, staff)

      assert_equal staff.staff_bulletins, @controller.bulletin_association_for_resource

      @controller.instance_variable_set(:@current_resource_for_test, nil)

      assert_nil @controller.bulletin_association_for_resource
    end
  end

  test "transparent refresh and authenticate cover failure and json branches" do
    @controller.define_singleton_method(:logged_in?) { false }
    @controller.define_singleton_method(:refresh_access_token) { |_| nil }
    @controller.define_singleton_method(:clear_auth_cookies!) { @cleared = true }
    @controller.send(:cookies)[AuthenticationBase::REFRESH_COOKIE_KEY] = "refresh-token"

    @controller.transparent_refresh_access_token

    assert @controller.instance_variable_get(:@cleared)
    assert @request.env[AuthIoKeys::Env::AUTH_REFRESHED_FLAG]

    rendered = []
    @request = ActionDispatch::TestRequest.create
    @request.set_header("HTTP_ACCEPT", "application/json")
    @controller.request = @request
    @controller.define_singleton_method(:render) { |**kwargs| rendered << kwargs }

    @controller.authenticate!

    assert_equal({ error: "Unauthorized" }, rendered.last[:json])
    assert_equal :unauthorized, rendered.last[:status]
  end

  test "withdrawal and refresh error helpers cover status branches" do
    @controller.define_singleton_method(:resource_type) { "client" }
    @controller.define_singleton_method(:request_ip_address) { "127.0.0.1" }
    @controller.define_singleton_method(:risk_actor_payload) { |_| {} }
    @controller.request.request_id = "request-1"

    @controller.define_singleton_method(:controller_path) { "base/app/identity/sessions" }

    assert_equal "/identity/withdrawal/edit", @controller.withdrawal_gate_redirect_path
    assert_nil @controller.handle_missing_refresh_token("missing-public-id")
    assert_equal :unauthorized, @controller.refresh_failure_status

    deactivated = Struct.new(:id) do
      define_method(:deactivated?) do
        true
      end
    end.new(7)
    active = Struct.new(:id) do
      define_method(:deactivated?) do
        false
      end
    end.new(8)
    token = nil

    assert_nil @controller.handle_inactive_resource(deactivated, "refresh-public", token)
    assert_equal :forbidden, @controller.refresh_failure_status
    assert_equal "withdrawal_required", @controller.refresh_failure_code

    assert_nil @controller.handle_inactive_resource(active, "refresh-public", token)
    assert_equal :unauthorized, @controller.refresh_failure_status

    assert_nil @controller.handle_refresh_error(StandardError.new("boom"), "refresh-public", active)
    assert_equal "invalid_refresh_token", @controller.refresh_failure_code
  end

  test "administrative access lock guards login and refresh" do
    @controller.define_singleton_method(:resource_type) { "client" }
    @controller.define_singleton_method(:request_ip_address) { "127.0.0.1" }
    @controller.define_singleton_method(:risk_actor_payload) { |_| {} }
    @controller.request.request_id = "request-1"

    locked = Struct.new(:id) do
      define_method(:admin_locked?) { true }
    end.new(123)
    token = Struct.new(:revoked) do
      def revoke!
        self.revoked = true
      end

      def revoked?
        revoked
      end
    end.new(false)

    assert_equal({ status: :access_locked }, @controller.log_in(locked))

    @controller.stub(:notify_inactive_resource_refresh_failed, true) do
      @controller.stub(:emit_inactive_resource_refresh_failed, true) do
        @controller.stub(:revoke_inactive_refresh_token_family!, ->(record) { record.revoke! }) do
          assert_nil @controller.handle_administrative_access_locked_refresh(locked, "refresh-public", token)
        end
      end
    end

    assert_equal :forbidden, @controller.refresh_failure_status
    assert_equal "administrative_access_locked", @controller.refresh_failure_code
    assert_predicate token, :revoked?
  end

  test "policy and token kind helpers cover fallback branches" do
    assert @controller.enforce_authentication_open!

    @controller.define_singleton_method(:logged_in?) { false }
    @controller.request.set_header("HTTP_ACCEPT", "application/json")
    rendered = []
    @controller.define_singleton_method(:render) { |**kwargs| rendered << kwargs }
    @controller.enforce_authentication_private!(request_format: :json, message: "login")

    assert_equal({ error: "login" }, rendered.last[:json])

    @controller.define_singleton_method(:logged_in?) { true }
    resource = Struct.new(:deactivated?).new(true)
    @controller.define_singleton_method(:current_resource) { resource }

    assert @controller.enforce_authentication_guest!

    klass = Class.new
    klass.define_singleton_method(:access_policy_rules) { [{ policy: :public, only: ["index"] }] }
    @controller.define_singleton_method(:action_name) { "show" }
    @controller.define_singleton_method(:class) { klass }

    assert_nil @controller.resolve_access_policy_for("show")

    @controller.define_singleton_method(:resource_type) { "operator" }
    token_class = Class.new
    token_class.define_singleton_method(:columns_hash) { { "staff_token_kind_id" => Struct.new(:type).new(:string) } }
    @controller.define_singleton_method(:token_class) { token_class }

    assert_equal "BROWSER_WEB", @controller.resolve_token_kind_id("BROWSER_WEB")
  end

  # Native app sign-ins arrive with a string token kind and an integer kind column.
  # The mapping falls through to a per-surface table when the kind model carries no
  # `code` column; only the browser rows of that table were reached before.
  test "resolve_token_kind_id maps native client kinds on every surface" do
    codeless_kind_model =
      Class.new do
        def self.column_names = []

        def self.name = "CodelessTokenKind"
      end

    [
      ["operator", "staff", OperatorTokenKind::CLIENT_IOS, OperatorTokenKind::CLIENT_ANDROID],
      ["client", "user", ClientTokenKind::CLIENT_IOS, ClientTokenKind::CLIENT_ANDROID],
      ["visitor", "visitor", VisitorTokenKind::CLIENT_IOS, VisitorTokenKind::CLIENT_ANDROID],
    ].each do |surface, prefix, ios_kind, android_kind|
      token_class = Class.new
      token_class.define_singleton_method(:columns_hash) do
        { "#{prefix}_token_kind_id" => Struct.new(:type).new(:integer) }
      end
      @controller.define_singleton_method(:resource_type) { surface }
      @controller.define_singleton_method(:token_class) { token_class }
      @controller.define_singleton_method(:token_kind_model) { codeless_kind_model }

      assert_equal ios_kind, @controller.resolve_token_kind_id("CLIENT_IOS"), surface
      assert_equal android_kind, @controller.resolve_token_kind_id("CLIENT_ANDROID"), surface
    end
  end

  test "resolve_token_kind_id refuses a kind the surface table does not name" do
    codeless_kind_model =
      Class.new do
        def self.column_names = []

        def self.name = "CodelessTokenKind"
      end
    token_class = Class.new
    token_class.define_singleton_method(:columns_hash) do
      { "user_token_kind_id" => Struct.new(:type).new(:integer) }
    end
    @controller.define_singleton_method(:resource_type) { "client" }
    @controller.define_singleton_method(:token_class) { token_class }
    @controller.define_singleton_method(:token_kind_model) { codeless_kind_model }

    error =
      assert_raises(ActiveRecord::RecordNotFound) do
        @controller.resolve_token_kind_id("CLIENT_TOASTER")
      end

    assert_match(/CLIENT_TOASTER/, error.message)
  end

  test "refresh_dbsc_source names which DBSC header arrived" do
    assert_equal "none", @controller.refresh_dbsc_source

    @request.headers[AuthIoKeys::Headers::DBSC_RESPONSE] = "proof"

    assert_equal "response", @controller.refresh_dbsc_source

    @request.headers[AuthIoKeys::Headers::DBSC_SESSION_ID] = "session-id"

    assert_equal "both", @controller.refresh_dbsc_source
  end

  test "policy_for_authentication_mode refuses a mode the policy table does not name" do
    error =
      assert_raises(AuthenticationBase::InvalidPolicyError) do
        @controller.policy_for_authentication_mode(:nonsense)
      end

    assert_match(/nonsense/, error.message)
  end

  test "resolve_access_policy_for honours an except list" do
    klass = Class.new
    klass.define_singleton_method(:access_policy_rules) do
      [{ policy: :public, except: ["destroy"] }]
    end
    @controller.define_singleton_method(:class) { klass }

    assert_equal :public, @controller.resolve_access_policy_for("index")&.fetch(:policy)
    assert_nil @controller.resolve_access_policy_for("destroy")
  end

  test "find_restricted_sessions_scope picks the token table that belongs to the actor" do
    assert_nil @controller.find_restricted_sessions_scope(Object.new)

    visitor = Visitor.new
    visitor.id = 4_242
    scope = @controller.find_restricted_sessions_scope(visitor)

    assert_equal VisitorToken, scope.klass
    assert_equal 4_242, scope.where_values_hash["visitor_id"]
  end

  test "dbsc_route_helper says which surface has no route helper" do
    @controller.define_singleton_method(:resource_type) { "visitor" }

    error =
      assert_raises(NoMethodError) do
        @controller.dbsc_route_helper(:no_such_primary_url, :no_such_compatibility_url)
      end

    assert_match(/visitor/, error.message)
  end

  # Every per-surface attribute table has an `else` arm. Nothing reached them, so a
  # resource type outside the three surfaces would have gone unnoticed until it
  # produced an empty attribute set somewhere far away from here.
  test "the per-surface token attribute tables fall back to empty for an unknown surface" do
    @controller.define_singleton_method(:resource_type) { "martian" }

    assert_empty @controller.default_dbsc_token_attributes(nil)
    assert_empty @controller.default_status_token_attributes(nil)
    assert_empty @controller.login_token_reference_models
    assert_not @controller.dbsc_registration_eligible_kind?(ClientTokenKind::BROWSER_WEB)
  end

  test "best_effort_refresh_side_effect swallows a failing side effect and answers nil" do
    assert_equal :done, @controller.best_effort_refresh_side_effect { :done }
    assert_nil(@controller.best_effort_refresh_side_effect { raise StandardError, "boom" })
  end

  test "session_limit_gate_pt falls back to a root path when the request cannot answer" do
    @controller.define_singleton_method(:request) { raise StandardError, "no request" }

    assert_equal "/", @controller.session_limit_gate_pt
  end

  test "refresh dbsc allowed helper covers missing mismatch and success" do
    dbsc_token =
      Struct.new(:dbsc_status, :dbsc_session_id) do
        define_method(:dbsc_status_active?) do
          dbsc_status == :active
        end

        define_method(:binding_method_dbsc?) do
          true
        end
      end

    assert @controller.refresh_dbsc_allowed?(nil)

    token = dbsc_token.new(:pending, "session-1")

    assert_not @controller.refresh_dbsc_allowed?(token)

    token.dbsc_status = :active

    assert_not @controller.refresh_dbsc_allowed?(token)
    assert_equal "missing_bound_cookie", @controller.instance_variable_get(:@refresh_dbsc_reason)

    @controller.send(:cookies)[AuthenticationBase::DBSC_COOKIE_KEY] = "wrong"

    assert_not @controller.refresh_dbsc_allowed?(token)
    assert_equal "session_id_mismatch", @controller.instance_variable_get(:@refresh_dbsc_reason)

    @controller.send(:cookies)[AuthenticationBase::DBSC_COOKIE_KEY] = "session-1"

    assert @controller.refresh_dbsc_allowed?(token)
  end

  test "device_session_refresh_allowed? verifies a DBSC-bound device session" do
    @controller.define_singleton_method(:resource_type) { "client" }
    user = clients(:one)
    token_record = ClientToken.create!(user: user)
    token_record.device_session.bind_dbsc!(session_id: "session-1")

    # No session id/proof headers presented: rejected before calling the verification service.
    assert_not @controller.device_session_refresh_allowed?(token_record)
    assert_equal "missing_proof", @controller.instance_variable_get(:@refresh_dbsc_reason)

    @request.headers[AuthIoKeys::Headers::DBSC_SESSION_ID] = "wrong-session"
    @request.headers[AuthIoKeys::Headers::DBSC_RESPONSE] = "proof"

    # Presented session id digest does not match the bound device session: rejected.
    assert_not @controller.device_session_refresh_allowed?(token_record)
    assert_equal "session_id_mismatch", @controller.instance_variable_get(:@refresh_dbsc_reason)

    @request.headers[AuthIoKeys::Headers::DBSC_SESSION_ID] = "session-1"

    DbscVerificationService.stub(:call, { ok: false, error_code: "invalid_signature" }) do
      assert_not @controller.device_session_refresh_allowed?(token_record)
      assert_equal "invalid_signature", @controller.instance_variable_get(:@refresh_dbsc_reason)
    end

    DbscVerificationService.stub(:call, { ok: true }) do
      assert @controller.device_session_refresh_allowed?(token_record)
    end

    assert_nil token_record.reload.dbsc_challenge
    assert_nil token_record.dbsc_challenge_issued_at
  end

  test "revoke_refresh_session_after_dbsc_failure! revokes the device session and its tokens" do
    user = clients(:one)
    token_record = ClientToken.create!(user: user)
    device_session = token_record.device_session

    @controller.revoke_refresh_session_after_dbsc_failure!(token_record)

    assert_predicate device_session.reload, :revoked?
    assert_predicate token_record.reload, :revoked?
  end

  test "token_expired_or_revoked? covers nil, infinite, and future/past expiry branches" do
    record = Struct.new(:expiry).new(nil)

    assert @controller.token_expired_or_revoked?(record, :expiry)

    record.expiry = Float::INFINITY

    assert_not @controller.token_expired_or_revoked?(record, :expiry)

    record.expiry = 1.hour.from_now

    assert_not @controller.token_expired_or_revoked?(record, :expiry)

    record.expiry = 1.hour.ago

    assert @controller.token_expired_or_revoked?(record, :expiry)
  end

  test "refresh source helpers cover dbsc branches" do
    token = Struct.new(:binding_method_dbsc?).new(true)
    @request.headers[AuthIoKeys::Headers::DBSC_SESSION_ID] = "session"

    assert_equal "session_id", @controller.refresh_dbsc_source
    @request.headers[AuthIoKeys::Headers::DBSC_RESPONSE] = "proof"

    assert_equal "both", @controller.refresh_dbsc_source
    assert_equal "both", @controller.refresh_binding_source(token)
  end

  test "mfa pending helpers and gate helpers cover expiry branches" do
    @controller.define_singleton_method(:resource_type) { "client" }
    @controller.define_singleton_method(:controller_path) { "sign/app/in" }

    @controller.set_pending_mfa!(
      resource: @user, primary: "email", pt: "/after", ri: "jp",
      auth_method: "secret_credential",
    )

    assert_equal @user.id, @controller.session[:mfa_user_id]
    assert_predicate @controller, :pending_mfa_valid?
    assert_equal "secret_credential", @controller.pending_mfa[:auth_method]

    @controller.session[:pending_mfa][:expires_at] = 1.minute.ago.to_i

    assert_not @controller.pending_mfa_valid?

    @controller.session[:pending_mfa].delete(:expires_at)
    @controller.session[:pending_mfa].delete("expires_at")
    @controller.session[:pending_mfa][:issued_at] = 1.minute.ago.to_i

    assert_predicate @controller, :pending_mfa_valid?

    @controller.session[:pending_mfa][:issued_at] = 20.minutes.ago.to_i

    assert_not @controller.pending_mfa_valid?

    @controller.clear_pending_mfa!

    assert_nil @controller.session[:pending_mfa]
    assert_nil @controller.session[:mfa_user_id]

    assert_equal "/", @controller.session_limit_gate_pt
    assert_equal "sign/app/in.session", @controller.session_limit_gate_flow
  end

  test "token kind model and literal kind resolution cover mappings" do
    token_class = Class.new
    token_class.define_singleton_method(:columns_hash) { { "staff_token_kind_id" => Struct.new(:type).new(:integer) } }
    @controller.define_singleton_method(:token_class) { token_class }
    @controller.define_singleton_method(:resource_type) { "operator" }
    @controller.define_singleton_method(:token_kind_model) do
      Class.new do
        define_singleton_method(:name) do
          "InlineOperatorTokenKind"
        end

        define_singleton_method(:column_names) do
          []
        end
      end
    end

    assert_equal OperatorTokenKind::BROWSER_WEB, @controller.resolve_token_kind_id("BROWSER_WEB")
    assert_equal OperatorTokenKind::CLIENT_IOS, @controller.resolve_token_kind_id("CLIENT_IOS")
    assert_equal OperatorTokenKind::CLIENT_ANDROID, @controller.resolve_token_kind_id("CLIENT_ANDROID")
    assert_raises(ActiveRecord::RecordNotFound) { @controller.resolve_token_kind_id("MISSING") }

    @controller.define_singleton_method(:resource_type) { "none" }
    assert_raises(ActiveRecord::RecordNotFound) { AuthenticationBase.instance_method(:token_kind_model).bind_call(@controller) }
  end

  test "token reference contracts remain distinct for every actor type" do
    {
      "client" => {
        prefix: "user",
        kind_column: "user_token_kind_id",
        kinds: {
          "BROWSER_WEB" => ClientTokenKind::BROWSER_WEB,
          "CLIENT_IOS" => ClientTokenKind::CLIENT_IOS,
          "CLIENT_ANDROID" => ClientTokenKind::CLIENT_ANDROID,
        },
        status_key: :user_token_status_id,
        active_status: ClientTokenStatus::ACTIVE,
        reference_keys: %i(
          user_token_binding_method_id
          user_token_dbsc_status_id
          user_token_kind_id
          user_token_status_id
        ),
      },
      "operator" => {
        prefix: "staff",
        kind_column: "staff_token_kind_id",
        kinds: {
          "BROWSER_WEB" => OperatorTokenKind::BROWSER_WEB,
          "CLIENT_IOS" => OperatorTokenKind::CLIENT_IOS,
          "CLIENT_ANDROID" => OperatorTokenKind::CLIENT_ANDROID,
        },
        status_key: :staff_token_status_id,
        active_status: OperatorTokenStatus::ACTIVE,
        reference_keys: %i(
          staff_token_binding_method_id
          staff_token_dbsc_status_id
          staff_token_kind_id
          staff_token_status_id
        ),
      },
      "visitor" => {
        prefix: "visitor",
        kind_column: "visitor_token_kind_id",
        kinds: {
          "BROWSER_WEB" => VisitorTokenKind::BROWSER_WEB,
          "CLIENT_IOS" => VisitorTokenKind::CLIENT_IOS,
          "CLIENT_ANDROID" => VisitorTokenKind::CLIENT_ANDROID,
        },
        status_key: :visitor_token_status_id,
        active_status: VisitorTokenStatus::ACTIVE,
        reference_keys: %i(
          visitor_token_binding_method_id
          visitor_token_dbsc_status_id
          visitor_token_kind_id
          visitor_token_status_id
        ),
      },
    }.each do |resource_type, contract|
      token_class = Class.new
      token_class.define_singleton_method(:columns_hash) do
        { contract.fetch(:kind_column) => Struct.new(:type).new(:integer) }
      end
      kind_model =
        Class.new do
          define_singleton_method(:name) { "InlineTokenKind" }
          define_singleton_method(:column_names) { [] }
        end
      @controller.define_singleton_method(:resource_type) { resource_type }
      @controller.define_singleton_method(:token_class) { token_class }
      @controller.define_singleton_method(:token_kind_model) { kind_model }

      contract.fetch(:kinds).each do |code, expected_id|
        assert_equal expected_id, @controller.resolve_token_kind_id(code), "#{resource_type}: #{code}"
      end
      assert_equal contract.fetch(:prefix),
                   AuthenticationBase.instance_method(:token_resource_prefix).bind_call(@controller)
      assert_equal contract.fetch(:active_status),
                   AuthenticationBase.instance_method(:default_status_token_attributes)
                     .bind_call(@controller).fetch(contract.fetch(:status_key))
      assert_equal 99,
                   AuthenticationBase.instance_method(:default_status_token_attributes)
                     .bind_call(@controller, 99).fetch(contract.fetch(:status_key))
      assert_equal contract.fetch(:reference_keys),
                   AuthenticationBase.instance_method(:login_token_reference_models)
                     .bind_call(@controller).keys
    end

    @controller.define_singleton_method(:resource_type) { "unknown" }

    assert_empty @controller.default_dbsc_token_attributes
    assert_empty AuthenticationBase.instance_method(:default_status_token_attributes).bind_call(@controller)
    assert_empty AuthenticationBase.instance_method(:login_token_reference_models).bind_call(@controller)
    assert_equal "unknown", AuthenticationBase.instance_method(:token_resource_prefix).bind_call(@controller)
    assert_not @controller.dbsc_registration_eligible_kind?(1)
  end

  test "ensure_token_kind_exists creates missing fixed id" do
    ClientToken.where(user_token_kind_id: ClientTokenKind::BROWSER_WEB).delete_all
    ClientTokenKind.where(id: ClientTokenKind::BROWSER_WEB).delete_all

    @controller.define_singleton_method(:resource_type) { "client" }
    @controller.define_singleton_method(:token_kind_model) { ClientTokenKind }

    assert_difference -> { ClientTokenKind.where(id: ClientTokenKind::BROWSER_WEB).count }, 1 do
      @controller.send(:ensure_token_kind_exists!, ClientTokenKind::BROWSER_WEB)
    end
  end

  test "ensure_login_token_reference_data creates missing user token references" do
    ClientToken.delete_all
    ClientTokenKind.where(id: ClientTokenKind::BROWSER_WEB).delete_all
    ClientTokenBindingMethod.where(id: ClientTokenBindingMethod::LEGACY).delete_all
    ClientTokenDbscStatus.where(id: ClientTokenDbscStatus::NOTHING).delete_all
    ClientTokenStatus.where(id: ClientTokenStatus::NOTHING).delete_all

    @controller.define_singleton_method(:resource_type) { "client" }

    @controller.send(
      :ensure_login_token_reference_data!,
      {
        user_token_kind_id: ClientTokenKind::BROWSER_WEB,
        user_token_binding_method_id: ClientTokenBindingMethod::LEGACY,
        user_token_dbsc_status_id: ClientTokenDbscStatus::NOTHING,
        user_token_status_id: ClientTokenStatus::NOTHING,
      },
    )

    assert ClientTokenKind.exists?(id: ClientTokenKind::BROWSER_WEB)
    assert ClientTokenBindingMethod.exists?(id: ClientTokenBindingMethod::LEGACY)
    assert ClientTokenBindingMethod.exists?(id: ClientTokenBindingMethod::DBSC)
    assert ClientTokenDbscStatus.exists?(id: ClientTokenDbscStatus::NOTHING)
    assert ClientTokenStatus.exists?(id: ClientTokenStatus::NOTHING)
  end

  test "reissue access token covers early returns and success without preference claim" do
    @controller.define_singleton_method(:current_resource) { nil }

    assert_nil @controller.reissue_access_token!

    session_record = Struct.new(:public_id, :revoked_at).new("session-public", 10.minutes.from_now)
    @controller.define_singleton_method(:current_resource) { @user }
    @controller.define_singleton_method(:current_session) { session_record }
    @controller.define_singleton_method(:resource_type) { "client" }

    assert_nil @controller.reissue_access_token!
  end

  test "log_in binds access token to valid DPoP proof" do
    private_key, jwk = generate_dpop_jwk
    @request.host = "id.app.localhost"
    @request.headers["DPoP"] = build_dpop_proof(
      private_key,
      jwk,
      method: "GET",
      uri: "http://id.app.localhost/",
    )
    @controller.define_singleton_method(:resource_type) { "client" }
    @controller.define_singleton_method(:resource_foreign_key) { :user_id }
    @controller.define_singleton_method(:resource_class) { Client }
    @controller.define_singleton_method(:token_class) { ClientToken }
    @controller.define_singleton_method(:token_kind_model) { ClientTokenKind }
    @controller.define_singleton_method(:session_limit_state_for) { |_| :within_limit }
    @controller.define_singleton_method(:record_audit) { |*| nil }

    result = @controller.log_in(@user, record_login_audit: false, require_totp_check: false)

    assert_equal :success, result[:status]
    assert_equal "DPoP", result[:token_type]

    payload = AuthenticationToken.decode(
      result[:access_token],
      host: "id.app.localhost",
      resource_type: "client",
    )
    expected_jkt = JitSecurityJwtThumbprintCalculator.calculate(jwk)
    token = ClientToken.order(created_at: :desc).first
    device_session = token.device_session

    assert_equal expected_jkt, payload.dig("cnf", "jkt")
    assert_equal device_session.public_id, payload["sid"]
    assert_not_equal token.public_id, payload["sid"]
    assert_equal expected_jkt, token.dpop_jkt
    assert_equal expected_jkt, device_session.dpop_jkt
  end

  test "log_in issues dbsc registration headers on browser success" do
    @controller.define_singleton_method(:resource_type) { "client" }
    @controller.define_singleton_method(:resource_foreign_key) { :user_id }
    @controller.define_singleton_method(:resource_class) { Client }
    @controller.define_singleton_method(:token_class) { ClientToken }
    @controller.define_singleton_method(:token_kind_model) { ClientTokenKind }
    @controller.define_singleton_method(:session_limit_state_for) { |_| :within_limit }
    @controller.define_singleton_method(:record_audit) { |*| nil }

    result = @controller.log_in(@user, record_login_audit: false, require_totp_check: false)

    assert_equal :success, result[:status]
    assert_predicate @controller.response.headers[AuthIoKeys::Headers::DBSC_REGISTRATION], :present?
    assert_equal @controller.response.headers[AuthIoKeys::Headers::DBSC_REGISTRATION],
                 @controller.response.headers[AuthIoKeys::Headers::SECURE_DBSC_REGISTRATION]
  end

  test "log_in sets visitor token status reference ids" do
    visitor = create_verified_visitor_with_email(email_address: "visitor-login@example.com")

    @controller.define_singleton_method(:resource_type) { "visitor" }
    @controller.define_singleton_method(:resource_foreign_key) { :visitor_id }
    @controller.define_singleton_method(:resource_class) { Visitor }
    @controller.define_singleton_method(:token_class) { VisitorToken }
    @controller.define_singleton_method(:token_kind_model) { VisitorTokenKind }
    @controller.define_singleton_method(:session_limit_state_for) { |_| :within_limit }
    @controller.define_singleton_method(:record_audit) { |*| nil }

    assert_difference("VisitorToken.count", 1) do
      result = @controller.log_in(visitor, record_login_audit: false, require_totp_check: false)

      assert_equal :success, result[:status]
    end

    token = VisitorToken.order(created_at: :desc).first

    assert_equal VisitorTokenStatus::ACTIVE, token.visitor_token_status_id
  end

  # Regression: log_in must NOT rotate the Rails session id when MFA is
  # still pending. The privilege transition (= access-token issuance)
  # happens at MFA completion, which re-enters log_in via
  # finalize_mfa_login! with require_totp_check: false and triggers
  # reset_session there. Resetting too early disposes pre-login session
  # state for no security benefit (the post-MFA log_in will reset again).
  test "log_in does not reset session or clear cookies when MFA is required" do
    reset_count = 0
    clear_count = 0

    @controller.define_singleton_method(:reset_session) { reset_count += 1 }
    @controller.define_singleton_method(:clear_previous_login_cookies!) { clear_count += 1 }
    @controller.define_singleton_method(:resource_type) { "client" }
    @controller.define_singleton_method(:resource_foreign_key) { :user_id }
    @controller.define_singleton_method(:resource_class) { Client }
    @controller.define_singleton_method(:token_class) { ClientToken }
    # Force the MFA branch: report MFA required for this resource.
    @controller.define_singleton_method(:mfa_required_for?) { |_| true }

    result = @controller.log_in(@user, record_login_audit: false, require_totp_check: true)

    assert_equal :mfa_required, result[:status]
    assert_equal 0, reset_count,
                 "reset_session must NOT run while MFA is still pending; " \
                 "it runs at MFA completion via finalize_mfa_login!"
    assert_equal 0, clear_count,
                 "clear_previous_login_cookies! must NOT run while MFA " \
                 "is still pending; it runs at the actual session-issuance step"
  end

  # Regression: when no MFA is required (or already satisfied), log_in
  # *must* rotate the Rails session id and clear the prior auth cookies
  # before it issues the new session. This is the canonical
  # session-fixation defense chokepoint.
  test "log_in resets session and clears cookies once when MFA check is bypassed" do
    reset_count = 0
    clear_count = 0

    @controller.define_singleton_method(:reset_session) { reset_count += 1 }
    @controller.define_singleton_method(:clear_previous_login_cookies!) { clear_count += 1 }
    @controller.define_singleton_method(:resource_type) { "client" }
    @controller.define_singleton_method(:resource_foreign_key) { :user_id }
    @controller.define_singleton_method(:resource_class) { Client }
    @controller.define_singleton_method(:token_class) { ClientToken }
    @controller.define_singleton_method(:token_kind_model) { ClientTokenKind }
    @controller.define_singleton_method(:session_limit_state_for) { |_| :within_limit }
    @controller.define_singleton_method(:record_audit) { |*| nil }

    result = @controller.log_in(@user, record_login_audit: false, require_totp_check: false)

    assert_equal :success, result[:status]
    assert_equal 1, reset_count,
                 "reset_session must run exactly once at the privilege transition"
    assert_equal 1, clear_count,
                 "clear_previous_login_cookies! must run exactly once at the privilege transition"
  end

  test "log_in preserves pending oidc rp callback state across session rotation" do
    @session_hash[:oidc_code_verifier] = "verifier"
    @session_hash[:oidc_state] = "state"
    @session_hash[:oidc_nonce] = "nonce"
    @session_hash[:oidc_pt] = "/dashboard?ri=jp"
    @session_hash[:unrelated_pre_login_state] = "drop-me"

    @controller.define_singleton_method(:reset_session) { @session_hash.clear }
    @controller.define_singleton_method(:resource_type) { "client" }
    @controller.define_singleton_method(:resource_foreign_key) { :user_id }
    @controller.define_singleton_method(:resource_class) { Client }
    @controller.define_singleton_method(:token_class) { ClientToken }
    @controller.define_singleton_method(:token_kind_model) { ClientTokenKind }
    @controller.define_singleton_method(:session_limit_state_for) { |_| :within_limit }
    @controller.define_singleton_method(:record_audit) { |*| nil }

    result = @controller.log_in(@user, record_login_audit: false, require_totp_check: false)

    assert_equal :success, result[:status]
    assert_equal "verifier", @session_hash[:oidc_code_verifier]
    assert_equal "state", @session_hash[:oidc_state]
    assert_equal "nonce", @session_hash[:oidc_nonce]
    assert_equal "/dashboard?ri=jp", @session_hash[:oidc_pt]
    assert_nil @session_hash[:unrelated_pre_login_state]
  end

  # Regression: ordering invariant -- when log_in is called with MFA
  # *not* required (or `require_totp_check: false`), reset_session must
  # happen BEFORE create_login_token_record, so the new token is issued
  # against the rotated session. Currently we observe this indirectly by
  # ensuring reset_session ran exactly once on the success path; if a
  # future refactor calls reset_session zero times on success, S-1
  # silently regresses.
  test "log_in reset_session happens before token issuance on success path" do
    order = []

    @controller.define_singleton_method(:reset_session) { order << :reset_session }
    @controller.define_singleton_method(:resource_type) { "client" }
    @controller.define_singleton_method(:resource_foreign_key) { :user_id }
    @controller.define_singleton_method(:resource_class) { Client }
    @controller.define_singleton_method(:token_class) { ClientToken }
    @controller.define_singleton_method(:token_kind_model) { ClientTokenKind }
    @controller.define_singleton_method(:session_limit_state_for) { |_| :within_limit }
    @controller.define_singleton_method(:record_audit) { |*| nil }
    @controller.define_singleton_method(:create_login_token_record) do |*args, **kwargs|
      order << :create_login_token_record
      # Delegate back to the real implementation by calling super through
      # a small bound trick: invoke the method body via UnboundMethod.
      AuthenticationBase.instance_method(:create_login_token_record).bind_call(self, *args, **kwargs)
    end

    @controller.log_in(@user, record_login_audit: false, require_totp_check: false)

    assert_equal %i(reset_session create_login_token_record), order,
                 "reset_session must precede create_login_token_record"
  end

  # ---------------------------------------------------------------
  # path_from_signed_pt regression coverage (S-7)
  # ---------------------------------------------------------------
  # The `pt` parameter must be a signed return-target token. Base64
  # encoding alone is not accepted as redirect authority.

  test "path_from_signed_pt accepts a signed internal non-welcome path" do
    encoded = @controller.signed_pt_token("/settings?x=1")

    assert_equal "/settings?x=1",
                 @controller.path_from_signed_pt(encoded)
  end

  test "path_from_signed_pt rejects welcome return targets after URI normalization" do
    @request.host = "log.umaxica.app"
    encoded_internal = @controller.signed_pt_token("/welcome?ri=jp")
    encoded_absolute = @controller.signed_pt_token("https://log.umaxica.app/welcome?ri=jp")

    assert_nil @controller.path_from_signed_pt(encoded_internal)
    assert_nil @controller.path_from_signed_pt(encoded_absolute)
    assert_nil @controller.path_from_signed_pt("/welcome?ri=jp")
    assert_equal "/dashboard?ri=jp",
                 @controller.path_from_signed_pt(@controller.signed_pt_token("/dashboard?ri=jp"))
  end

  test "path_from_signed_pt rejects an unencoded external URL" do
    raw_external = "https://evil.example.test/pwn"

    assert_nil @controller.path_from_signed_pt(raw_external)
  end

  test "path_from_signed_pt rejects a tampered signed token" do
    encoded_external = @controller.signed_pt_token("/settings?x=1")
    tampered = encoded_external.sub(/.\z/, encoded_external.end_with?("A") ? "B" : "A")

    assert_nil @controller.path_from_signed_pt(tampered)
  end

  test "path_from_signed_pt rejects malformed input" do
    encoded_bad = "!!!not-a-token!!!"

    assert_nil @controller.path_from_signed_pt(encoded_bad)
  end

  test "path_from_signed_pt returns nil for blank pt" do
    assert_nil @controller.path_from_signed_pt(nil)
    assert_nil @controller.path_from_signed_pt("")
  end

  test "path_from_signed_pt returns nil for malformed token" do
    assert_nil @controller.path_from_signed_pt("not-a-token")
  end

  test "path_from_signed_pt rejects legacy base64 return targets" do
    legacy = Base64.urlsafe_encode64("/settings?x=1")

    assert_nil @controller.path_from_signed_pt(legacy)
  end

  test "signed_pt_token returns signed values and refuses unsafe destinations" do
    safe_encoded = @controller.signed_pt_token("/settings?x=1")

    assert_equal safe_encoded, @controller.signed_pt_token(safe_encoded)
    assert_nil @controller.signed_pt_token("/welcome?x=1")
    assert_equal "/dashboard?x=1",
                 @controller.path_from_signed_pt(@controller.signed_pt_token("/dashboard?x=1"))
    assert_nil @controller.signed_pt_token("https://evil.example.test")
    assert_nil @controller.signed_pt_token(Base64.urlsafe_encode64("/settings"))
    assert_nil @controller.signed_pt_token("not-base64-and-not-internal")
    assert_nil @controller.signed_pt_token(nil)
  end

  # ---------------------------------------------------------------
  # DBSC preferred-when-supported (token-theft hardening, Phase A)
  # ---------------------------------------------------------------
  # Browser-login tokens are issued LEGACY + PENDING so a capable browser is
  # nudged to bind via DBSC, while a browser that never registers is downgraded
  # to an explicit NOTHING fallback on its first refresh after the challenge
  # expires. Native-app and OIDC tokens stay NOTHING.

  test "default_dbsc_token_attributes issues PENDING only for browser-web logins" do
    {
      "client" => [ClientTokenKind, ClientTokenDbscStatus, ClientTokenBindingMethod,
                   :user_token_dbsc_status_id, :user_token_binding_method_id,],
      "operator" => [OperatorTokenKind, OperatorTokenDbscStatus, OperatorTokenBindingMethod,
                     :staff_token_dbsc_status_id, :staff_token_binding_method_id,],
      "visitor" => [VisitorTokenKind, VisitorTokenDbscStatus, VisitorTokenBindingMethod,
                    :visitor_token_dbsc_status_id, :visitor_token_binding_method_id,],
    }.each do |surface, (kind, status, binding, status_key, binding_key)|
      @controller.define_singleton_method(:resource_type) { surface }

      browser = @controller.default_dbsc_token_attributes(kind::BROWSER_WEB)
      native = @controller.default_dbsc_token_attributes(kind::CLIENT_IOS)
      unknown = @controller.default_dbsc_token_attributes(nil)

      assert_equal binding::LEGACY, browser[binding_key], "#{surface}: browser binding stays LEGACY"
      assert_equal status::PENDING, browser[status_key], "#{surface}: browser session is PENDING"
      assert_equal status::NOTHING, native[status_key], "#{surface}: native session stays NOTHING"
      assert_equal status::NOTHING, unknown[status_key], "#{surface}: unknown kind stays NOTHING"
    end
  end

  test "log_in issues a browser session as LEGACY + PENDING DBSC" do
    @controller.define_singleton_method(:resource_type) { "client" }
    @controller.define_singleton_method(:resource_foreign_key) { :user_id }
    @controller.define_singleton_method(:resource_class) { Client }
    @controller.define_singleton_method(:token_class) { ClientToken }
    @controller.define_singleton_method(:token_kind_model) { ClientTokenKind }
    @controller.define_singleton_method(:session_limit_state_for) { |_| :within_limit }
    @controller.define_singleton_method(:record_audit) { |*| nil }

    result = @controller.log_in(@user, record_login_audit: false, require_totp_check: false)

    assert_equal :success, result[:status]
    token = ClientToken.order(created_at: :desc).first

    assert_predicate token, :binding_method_legacy?
    assert_predicate token, :dbsc_status_pending?
  end

  test "legacy_unbound_refresh_allowed? accepts an explicit non-DBSC fallback token" do
    assert @controller.legacy_unbound_refresh_allowed?(build_legacy_client_token(ClientTokenDbscStatus::NOTHING))
  end

  test "legacy_unbound_refresh_allowed? rejects a non-DBSC token in an inconsistent DBSC lifecycle state" do
    assert_not @controller.legacy_unbound_refresh_allowed?(build_legacy_client_token(ClientTokenDbscStatus::ACTIVE))
  end

  test "legacy_unbound_refresh_allowed? keeps a within-grace PENDING token pending and allows refresh" do
    token = build_legacy_client_token(ClientTokenDbscStatus::PENDING, challenge_issued_at: Time.current)

    assert @controller.legacy_unbound_refresh_allowed?(token)
    assert_predicate token.reload, :dbsc_status_pending?
  end

  test "legacy_unbound_refresh_allowed? downgrades an expired PENDING token to a NOTHING fallback" do
    token = build_legacy_client_token(ClientTokenDbscStatus::PENDING, challenge_issued_at: 11.minutes.ago)

    assert @controller.legacy_unbound_refresh_allowed?(token)
    assert_predicate token.reload, :dbsc_status_nothing?
    assert_predicate token, :binding_method_legacy?
  end

  test "legacy_unbound_refresh_allowed? downgrades a PENDING token with no challenge timestamp" do
    token = build_legacy_client_token(ClientTokenDbscStatus::PENDING, challenge_issued_at: nil)

    assert @controller.legacy_unbound_refresh_allowed?(token)
    assert_predicate token.reload, :dbsc_status_nothing?
  end

  test "dbsc_registration_challenge_expired? respects DBSC_COOKIE_TTL" do
    # Read-only over dbsc_challenge_issued_at; unsaved records keep the test
    # clear of the per-user concurrent-session limit.
    assert_not @controller.dbsc_registration_challenge_expired?(ClientToken.new(dbsc_challenge_issued_at: Time.current))
    assert @controller.dbsc_registration_challenge_expired?(ClientToken.new(dbsc_challenge_issued_at: 11.minutes.ago))
    assert @controller.dbsc_registration_challenge_expired?(ClientToken.new(dbsc_challenge_issued_at: nil))
  end

  test "expired PENDING downgrade applies to operator and visitor tokens too" do
    operator = OperatorToken.create!(
      staff: operators(:one),
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::NOTHING,
      staff_token_binding_method_id: OperatorTokenBindingMethod::LEGACY,
      staff_token_dbsc_status_id: OperatorTokenDbscStatus::PENDING,
      discarded_at: 1.day.from_now, purged_at: 1.day.from_now,
      dbsc_challenge_issued_at: 11.minutes.ago,
    )
    visitor_token = VisitorToken.create!(
      visitor: create_verified_visitor_with_email(email_address: "phase-a-visitor@example.com"),
      visitor_token_binding_method_id: VisitorTokenBindingMethod::LEGACY,
      visitor_token_dbsc_status_id: VisitorTokenDbscStatus::PENDING,
      discarded_at: 1.day.from_now, purged_at: 1.day.from_now,
      dbsc_challenge_issued_at: 11.minutes.ago,
    )

    assert @controller.legacy_unbound_refresh_allowed?(operator)
    assert @controller.legacy_unbound_refresh_allowed?(visitor_token)
    assert_predicate operator.reload, :dbsc_status_nothing?
    assert_predicate visitor_token.reload, :dbsc_status_nothing?
  end

  # A3: DPoP sender-constraint stays enforced on the refresh path. A jkt-bound
  # token must present a valid DPoP proof for the matching key; the OIDC bearer
  # path is covered separately in access_token_authenticator_dpop_test.
  test "refresh_dpop_allowed? enforces the sender-constraint on jkt-bound tokens" do
    @controller.define_singleton_method(:resource_type) { "client" }
    @request.host = "id.app.localhost"
    private_key, jwk = generate_dpop_jwk
    expected_jkt = JitSecurityJwtThumbprintCalculator.calculate(jwk)
    bound = ClientToken.new(dpop_jkt: expected_jkt)

    # Unbound token: nothing to enforce.
    assert @controller.refresh_dpop_allowed?(ClientToken.new(dpop_jkt: nil))

    # jkt-bound token presented with no DPoP proof is refused (none set yet).
    assert_not @controller.refresh_dpop_allowed?(bound)

    # jkt-bound token with a valid proof for the matching key is allowed.
    @request.headers["DPoP"] = build_dpop_proof(
      private_key, jwk, method: @request.request_method, uri: @request.original_url,
    )

    assert @controller.refresh_dpop_allowed?(bound)

    # jkt-bound token with a proof for a different key is refused (jkt mismatch).
    other_key, other_jwk = generate_dpop_jwk
    @request.headers["DPoP"] = build_dpop_proof(
      other_key, other_jwk, method: @request.request_method, uri: @request.original_url,
    )

    assert_not @controller.refresh_dpop_allowed?(bound)

    # jkt-bound token with a structurally invalid DPoP proof is refused (validator error).
    @request.headers["DPoP"] = "not-a-valid-jwt"

    assert_not @controller.refresh_dpop_allowed?(bound)
    assert_equal "malformed_proof", @controller.instance_variable_get(:@refresh_dpop_reason)
  end

  # ---------------------------------------------------------------
  # Idle timeout on the refresh path (token-theft hardening, Phase B)
  # ---------------------------------------------------------------

  test "refresh_idle_allowed? denies a session idle beyond the surface window" do
    @controller.define_singleton_method(:resource_type) { "client" }

    assert @controller.refresh_idle_allowed?(nil)
    assert @controller.refresh_idle_allowed?(ClientToken.new(last_used_at: 1.hour.ago))
    assert_not @controller.refresh_idle_allowed?(ClientToken.new(last_used_at: 9.hours.ago))
  end

  test "refresh_idle_allowed? falls back to created_at when last_used_at is missing" do
    @controller.define_singleton_method(:resource_type) { "client" }

    assert @controller.refresh_idle_allowed?(ClientToken.new(last_used_at: nil, created_at: 1.hour.ago))
    assert_not @controller.refresh_idle_allowed?(ClientToken.new(last_used_at: nil, created_at: 9.hours.ago))
  end

  test "refresh_idle_allowed? uses the tighter operator window" do
    @controller.define_singleton_method(:resource_type) { "operator" }

    # 1h idle is within the client window but past the 30-minute operator window.
    assert_not @controller.refresh_idle_allowed?(OperatorToken.new(last_used_at: 1.hour.ago))
    assert @controller.refresh_idle_allowed?(OperatorToken.new(last_used_at: 5.minutes.ago))
  end

  test "handle_refresh_idle_timeout fails the refresh and clears auth state" do
    @controller.define_singleton_method(:resource_type) { "client" }
    cleared = false
    @controller.define_singleton_method(:destroy_refresh_token_from_cookie) { nil }
    @controller.define_singleton_method(:clear_auth_cookies!) { cleared = true }

    SignRiskEmitter.stub(:emit, nil) do
      assert_nil @controller.handle_refresh_idle_timeout(ClientToken.new(last_used_at: 9.hours.ago), "rt-public")
    end

    assert_equal :unauthorized, @controller.refresh_failure_status
    assert_equal "invalid_refresh_token", @controller.refresh_failure_code
    assert cleared, "auth cookies must be cleared on idle timeout"
  end

  # ---------------------------------------------------------------
  # IP/ASN-anomaly network-change detection (token-theft hardening, Phase C)
  # ---------------------------------------------------------------

  test "detect_session_network_change! emits ip_change_detected when the coarse network changes" do
    @controller.define_singleton_method(:resource_type) { "client" }
    device = fake_device_session(last_network_hmac: "old-network")
    token = Struct.new(:device_session, :public_id).new(device, "tok-1")
    resource = Struct.new(:id).new(@user.id)

    emitted = []
    OccurrenceHmac.stub(:network_hmac, ->(_ip) { "new-network" }) do
      SignRiskEmitter.stub(:emit, ->(name, **kwargs) { emitted << [name, kwargs] }) do
        @controller.detect_session_network_change!(token, resource)
      end
    end

    assert_equal "new-network", device.last_network_hmac, "stored fingerprint is refreshed"
    assert_equal 1, emitted.size
    assert_equal "ip_change_detected", emitted.first[0]
    assert_equal @user.id, emitted.first[1][:user_id]
  end

  test "detect_session_network_change! stays quiet within the same coarse network" do
    @controller.define_singleton_method(:resource_type) { "client" }
    device = fake_device_session(last_network_hmac: "same-network")
    token = Struct.new(:device_session, :public_id).new(device, "tok-1")
    resource = Struct.new(:id).new(@user.id)

    emitted = []
    OccurrenceHmac.stub(:network_hmac, ->(_ip) { "same-network" }) do
      SignRiskEmitter.stub(:emit, ->(name, **kwargs) { emitted << [name, kwargs] }) do
        @controller.detect_session_network_change!(token, resource)
      end
    end

    assert_empty emitted
  end

  test "detect_session_network_change! records a baseline without emitting on first observation" do
    @controller.define_singleton_method(:resource_type) { "client" }
    device = fake_device_session(last_network_hmac: nil)
    token = Struct.new(:device_session, :public_id).new(device, "tok-1")
    resource = Struct.new(:id).new(@user.id)

    emitted = []
    OccurrenceHmac.stub(:network_hmac, ->(_ip) { "first-network" }) do
      SignRiskEmitter.stub(:emit, ->(name, **kwargs) { emitted << [name, kwargs] }) do
        @controller.detect_session_network_change!(token, resource)
      end
    end

    assert_equal "first-network", device.last_network_hmac
    assert_empty emitted
  end

  # Regression: the fingerprint UPDATE runs inside the transparent-refresh GET path
  # where the default connection role is :reading. It must be wrapped in the :writing
  # role, otherwise it raises ActiveRecord::ReadOnlyError and the fingerprint never
  # refreshes (so ip_change_detected would re-fire every request).
  test "detect_session_network_change! wraps the fingerprint write in the :writing role" do
    @controller.define_singleton_method(:resource_type) { "client" }
    device = fake_device_session(last_network_hmac: "old-network")
    token = Struct.new(:device_session, :public_id).new(device, "tok-1")
    resource = Struct.new(:id).new(@user.id)

    roles = []
    connected_to =
      lambda do |role:, **_kwargs, &block|
        roles << role
        block.call
      end

    ActiveRecord::Base.stub(:connected_to, connected_to) do
      OccurrenceHmac.stub(:network_hmac, ->(_ip) { "new-network" }) do
        SignRiskEmitter.stub(:emit, ->(*) { }) do
          @controller.detect_session_network_change!(token, resource)
        end
      end
    end

    assert_includes roles, :writing, "fingerprint UPDATE must run under the :writing role"
    assert_equal "new-network", device.last_network_hmac, "stored fingerprint is refreshed"
  end

  # Stronger companion to the stub-based test above: drive the write through a
  # real read-only connection (mirroring SignUpCycleLocatorTest) instead of
  # stubbing connected_to. If a regression drops the :writing wrapper, this
  # surfaces as a genuine ActiveRecord::ReadOnlyError rather than only a missing
  # stub call, so it also guards the connection semantics, not just the API call.
  test "detect_session_network_change! persists the fingerprint under a real read-only connection" do
    @controller.define_singleton_method(:resource_type) { "client" }
    refresh_token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    device = ClientDeviceSession.create!(
      user: @user,
      current_refresh_token: refresh_token,
      status_id: DeviceSessionable::STATUS_ACTIVE,
      last_network_hmac: "old-network",
    )
    token = Struct.new(:device_session, :public_id).new(device, "tok-1")
    resource = Struct.new(:id).new(@user.id)

    OccurrenceHmac.stub(:network_hmac, ->(_ip) { "new-network" }) do
      SignRiskEmitter.stub(:emit, ->(*) { }) do
        ActiveRecord::Base.connected_to(role: :reading, prevent_writes: true) do
          @controller.detect_session_network_change!(token, resource)
        end
      end
    end

    assert_equal "new-network", device.reload.last_network_hmac,
                 "fingerprint write must succeed despite the request defaulting to the reading role"
  end

  def fake_device_session(last_network_hmac:)
    Struct.new(:last_network_hmac) do
      def has_attribute?(attribute)
        attribute.to_sym == :last_network_hmac
      end

      def update_columns(attrs)
        attrs.each { |key, value| self[key] = value }
        true
      end
    end.new(last_network_hmac)
  end

  def build_legacy_client_token(dbsc_status_id, challenge_issued_at: Time.current)
    ClientToken.create!(
      user: @user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::NOTHING,
      user_token_binding_method_id: ClientTokenBindingMethod::LEGACY,
      user_token_dbsc_status_id: dbsc_status_id,
      discarded_at: 1.day.from_now,
      purged_at: 1.day.from_now,
      dbsc_challenge: challenge_issued_at && SecureRandom.hex(16),
      dbsc_challenge_issued_at: challenge_issued_at,
    )
  end

  def generate_dpop_jwk
    ec = OpenSSL::PKey::EC.generate("prime256v1")
    jwk = JWT::JWK.new(ec).export
    [ec, jwk]
  end

  def build_dpop_proof(private_key, jwk, method:, uri:)
    payload = {
      "htm" => method,
      "htu" => uri,
      "iat" => Time.current.to_i,
      "jti" => SecureRandom.uuid,
    }
    JWT.encode(payload, private_key, "ES256", { "typ" => "dpop+jwt", "jwk" => jwk })
  end

  test "request guard helpers cover anonymous and logged in branches" do
    rendered = []
    redirected = []
    @controller.define_singleton_method(:render) { |*args, **kwargs| rendered << [args, kwargs] }
    @controller.define_singleton_method(:redirect_to) { |*args, **kwargs| redirected << [args, kwargs] }

    @controller.define_singleton_method(:logged_in?) { false }

    assert_nil @controller.ensure_not_logged_in
    assert_nil @controller.ensure_not_logged_in_for_registration
    assert_not @controller.reject_if_logged_in("errors.messages.not_authorized")
    assert_nil @controller.reject_logged_in_session

    @controller.define_singleton_method(:logged_in?) { true }
    @controller.request.format = Struct.new(:json?).new(true)
    @controller.ensure_not_logged_in(message_key: "errors.messages.not_authorized")

    assert_equal :unauthorized, rendered.last.last[:status]

    @controller.request.format = Struct.new(:json?).new(false)
    @controller.ensure_not_logged_in_for_registration(redirect_path: "/signup")

    assert_equal [["/signup"], { alert: I18n.t("errors.messages.not_authorized") }], redirected.last

    @controller.reject_if_logged_in("errors.messages.not_authorized")

    assert_equal :bad_request, rendered.last.last[:status]

    @controller.reject_logged_in_session

    assert_equal :unauthorized, rendered.last.last[:status]
  end

  test "authentication mode DSL and guardrail methods cover class branches" do
    controller_class = Class.new(AuthenticationBaseTestController)
    controller_class.define_singleton_method(:name) { "AuthenticationBasePolicyHarness" }

    assert_raises(AuthenticationBase::InvalidPolicyError) do
      controller_class.access_policy(:bogus)
    end

    controller_class.access_policy(:public_strict, only: :index, flag: true)
    controller_class.declare_authentication_mode!(:guest, only: :show)

    assert_equal :guest, controller_class.authentication_mode_for(:show)
    assert_equal :deny_all, controller_class.authentication_mode_for(:edit)
    assert_equal(
      { policy: :public_strict, only: ["index"], except: nil, options: { flag: true } },
      controller_class.access_policy_rules.last,
    )
    assert_equal(
      { mode: :guest, only: ["show"], except: nil, options: {} },
      controller_class.authentication_mode_rules.last,
    )

    assert_raises(AuthenticationBase::SkipNotAllowedError) do
      controller_class.skip_before_action(:enforce_access_policy!)
    end

    assert_raises(AuthenticationBase::SkipNotAllowedError) do
      controller_class.skip_action_callback(:process_action, :before, :enforce_access_policy!)
    end

    controller_class.define_method(:noop_before_action) { nil }
    controller_class.before_action(:noop_before_action)
    assert_nothing_raised { controller_class.skip_before_action(:noop_before_action) }
  end

  test "abstract contract methods raise NotImplementedError until a surface overrides them" do
    assert_raises(NotImplementedError) { @controller.resource_class }
    assert_raises(NotImplementedError) { @controller.token_class }
    assert_raises(NotImplementedError) { @controller.audit_class }
    assert_raises(NotImplementedError) { @controller.resource_type }
    assert_raises(NotImplementedError) { @controller.resource_foreign_key }
    assert_raises(NotImplementedError) { @controller.sign_in_url_with_pt("/return") }
    assert_raises(NotImplementedError) { @controller.am_i_user? }
    assert_raises(NotImplementedError) { @controller.am_i_operator? }
    assert_raises(NotImplementedError) { @controller.am_i_owner? }
  end

  test "occurrence_model_class returns nil for an unknown resource type" do
    @controller.define_singleton_method(:resource_type) { "unknown" }

    assert_nil @controller.occurrence_model_class
  end

  test "network_hmac_for_request returns nil when the HMAC secret credential is missing" do
    OccurrenceHmac.stub(:secret_credential, -> { raise OccurrenceHmac::MissingSecretError }) do
      assert_nil @controller.network_hmac_for_request
    end
  end

  test "refresh_access_token logs and delegates to handle_refresh_error when parsing the token raises" do
    @controller.define_singleton_method(:resource_type) { "client" }
    failing_token_class =
      Class.new do
        def self.parse_refresh_token(_plain)
          raise StandardError, "boom"
        end
      end
    @controller.define_singleton_method(:token_class) { failing_token_class }

    result = @controller.refresh_access_token("whatever")

    assert_nil result
    assert_equal :unauthorized, @controller.refresh_failure_status
    assert_equal "invalid_refresh_token", @controller.refresh_failure_code
  end

  test "authenticate! redirects through the oidc authorization url when the controller supports it" do
    @controller.define_singleton_method(:logged_in?) { false }
    @controller.request.set_header("HTTP_ACCEPT", "text/html")
    @controller.define_singleton_method(:sign_in_url_with_pt) { |pt| "/in?pt=#{pt}" }
    @controller.define_singleton_method(:encoded_pt) { |target| "encoded-#{target}" }
    calls = []
    @controller.define_singleton_method(:redirect_to_oidc_authorization_url) { |url, **opts| calls << [url, opts] }

    @controller.authenticate!

    assert_equal 1, calls.size
    assert_equal "/in?pt=encoded-#{@request.fullpath}", calls.first.first
    assert_nil @controller.session[AuthenticationBase::DEFAULT_PT_SESSION_KEY],
               "store_authentication_return_target! must be skipped when the oidc redirect owns the return target"
  end

  test "skip_action_callback delegates to the framework implementation for unrelated filters" do
    assert_raises(NoMethodError) do
      AuthenticationBaseTestController.skip_action_callback(:process_action, :before, :noop_before_action)
    end
  end

  test "revoke_inactive_refresh_token_family! updates a lone token record with no family id" do
    token = ClientToken.create!(
      user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB, discarded_at: 1.day.from_now,
    )

    @controller.send(:revoke_inactive_refresh_token_family!, token)

    assert_operator token.reload.discarded_at, :<=, Time.current
  end

  test "handle_invalid_refresh_token_reason records a refresh_reuse_detected occurrence when reuse is flagged" do
    @controller.define_singleton_method(:resource_type) { "client" }
    @controller.define_singleton_method(:request_ip_address) { "127.0.0.1" }
    @controller.request.request_id = "request-reuse"
    token = ClientToken.create!(
      user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB, discarded_at: 1.day.from_now,
    )

    assert_difference("ClientOccurrence.count", 1) do
      SignRiskEmitter.stub(:emit, nil) do
        assert_nil @controller.send(
          :handle_invalid_refresh_token_reason, "refresh_token_reuse_detected",
          token.public_id, token,
        )
      end
    end

    occurrence = ClientOccurrence.order(created_at: :desc).first

    assert_equal "refresh_reuse_detected", occurrence.event_type
    assert_equal "reuse", occurrence.context["reason"]
  end

  test "handle_refresh_binding_denied records a dpop denial reason" do
    @controller.define_singleton_method(:resource_type) { "client" }
    @controller.define_singleton_method(:request_ip_address) { "127.0.0.1" }
    @controller.instance_variable_set(:@refresh_dpop_reason, "missing")
    token = ClientToken.create!(
      user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB, discarded_at: 1.day.from_now,
    )

    assert_difference("ClientOccurrence.count", 1) do
      SignRiskEmitter.stub(:emit, nil) do
        @controller.send(:handle_refresh_binding_denied, token, token.public_id)
      end
    end

    occurrence = ClientOccurrence.order(created_at: :desc).first

    assert_equal "refresh_dpop_denied", occurrence.event_type
  end

  test "handle_refresh_binding_denied records a dbsc denial reason when the token is dbsc bound" do
    @controller.define_singleton_method(:resource_type) { "client" }
    @controller.define_singleton_method(:request_ip_address) { "127.0.0.1" }
    token = ClientToken.create!(
      user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB, discarded_at: 1.day.from_now,
      user_token_binding_method_id: ClientTokenBindingMethod::DBSC,
    )

    assert_difference("ClientOccurrence.count", 1) do
      SignRiskEmitter.stub(:emit, nil) do
        @controller.send(:handle_refresh_binding_denied, token, token.public_id)
      end
    end

    occurrence = ClientOccurrence.order(created_at: :desc).first

    assert_equal "refresh_dbsc_denied", occurrence.event_type
  end

  test "revoke_refresh_session_after_dbsc_failure! revokes a standalone token without a device session" do
    token = ClientToken.create!(
      user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB, discarded_at: 1.day.from_now,
    )

    @controller.revoke_refresh_session_after_dbsc_failure!(token)

    assert_predicate token.reload, :revoked?
  end

  test "revoke_refresh_session_after_dbsc_failure! logs and swallows ActiveRecord errors" do
    token = ClientToken.create!(
      user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB, discarded_at: 1.day.from_now,
    )
    token.define_singleton_method(:revoke!) { raise ActiveRecord::RecordInvalid, token }

    assert_nothing_raised { @controller.revoke_refresh_session_after_dbsc_failure!(token) }
  end

  test "refresh_dbsc_source reports the response-only and no-header branches" do
    assert_equal "none", @controller.refresh_dbsc_source

    @request.headers[AuthIoKeys::Headers::DBSC_RESPONSE] = "proof"

    assert_equal "response", @controller.refresh_dbsc_source
  end

  test "emit_actor_mismatch_event logs and emits a risk signal for the mismatch" do
    @controller.define_singleton_method(:resource_type) { "client" }
    @controller.define_singleton_method(:request_ip_address) { "127.0.0.1" }
    payload = { "act" => "operator", "sub" => "actor-42" }

    emitted = []
    SignRiskEmitter.stub(:emit, ->(name, **kwargs) { emitted << [name, kwargs] }) do
      @controller.send(:emit_actor_mismatch_event, payload)
    end

    assert_equal 1, emitted.size
    assert_equal "actor_mismatch", emitted.first[0]
    assert_equal({ expected: "client", actual: "operator" }, emitted.first[1][:meta])
  end

  test "destroy_refresh_token_from_cookie logs when the session cannot be destroyed" do
    @controller.send(:cookies)[AuthenticationBase::REFRESH_COOKIE_KEY] = "refresh-plain"
    fake_token_class =
      Class.new do
        def self.parse_refresh_token(_plain)
          ["public-id-1"]
        end
      end
    @controller.define_singleton_method(:token_class) { fake_token_class }
    @controller.define_singleton_method(:resource_type) { "client" }

    AuthenticationLogoutCurrentSession.stub(:call, ->(**) { raise ActiveRecord::RecordNotDestroyed, "boom" }) do
      assert_nothing_raised { @controller.send(:destroy_refresh_token_from_cookie) }
    end
  end

  test "enforce_access_policy! dispatches the bare mode policy without side effects" do
    controller_class = Class.new(AuthenticationBaseTestController)
    controller_class.define_singleton_method(:name) { "AuthenticationBaseBarePolicyHarness" }
    controller_class.declare_authentication_mode!(:bare, only: :index)
    controller = controller_class.new
    controller.request = @request
    controller.response = ActionDispatch::TestResponse.new
    controller.define_singleton_method(:session) { @session_hash }
    controller.instance_variable_set(:@session_hash, @session_hash)
    controller.define_singleton_method(:action_name) { "index" }
    controller.define_singleton_method(:logged_in?) { false }
    controller.define_singleton_method(:current_resource) { nil }
    controller.define_singleton_method(:current_user) { nil }

    assert controller.send(:enforce_access_policy!)
  end

  test "policy_for_authentication_mode raises InvalidPolicyError for unsupported modes" do
    assert_raises(AuthenticationBase::InvalidPolicyError) do
      @controller.send(:policy_for_authentication_mode, :bogus)
    end
  end

  test "resolve_authentication_mode_rule_for skips only/except mismatches before returning the matching rule" do
    controller_class = Class.new(AuthenticationBaseTestController)
    controller_class.define_singleton_method(:name) { "AuthenticationBaseModeRuleSkipHarness" }
    controller_class.declare_authentication_mode!(:guest)
    controller_class.declare_authentication_mode!(:private, except: :edit)
    controller_class.declare_authentication_mode!(:open, only: :show)

    matched = controller_class.new.send(:resolve_authentication_mode_rule_for, "edit")

    assert_equal :guest, matched[:mode]
  end

  test "resolve_access_policy_for skips only/except mismatches before returning the matching rule" do
    klass = Class.new
    klass.define_singleton_method(:access_policy_rules) do
      [
        { policy: :guest_only, only: nil, except: nil, options: { matched: true } },
        { policy: :auth_required, only: nil, except: ["destroy"], options: {} },
        { policy: :deny_all, only: ["show"], except: nil, options: {} },
      ]
    end
    @controller.define_singleton_method(:class) { klass }

    matched = @controller.resolve_access_policy_for("destroy")

    assert_equal({ policy: :guest_only, only: nil, except: nil, options: { matched: true } }, matched)
  end

  test "access_policy_options_for falls back to access_policy_rules options when no mode rule matches" do
    controller_class = Class.new(AuthenticationBaseTestController)
    controller_class.define_singleton_method(:name) { "AuthenticationBaseOptionsFallbackHarness" }
    controller_class.define_singleton_method(:access_policy_rules) do
      [{ policy: :auth_required, only: ["edit"], except: nil, options: { custom: true } }]
    end
    instance = controller_class.new

    assert_equal({ custom: true }, instance.send(:access_policy_options_for, "edit"))
    assert_equal({}, instance.send(:access_policy_options_for, "unmatched"))
  end

  test "enforce_authentication_guest! renders json when json format is requested" do
    @controller.define_singleton_method(:logged_in?) { true }
    resource = Struct.new(:deactivated?).new(false)
    @controller.define_singleton_method(:current_resource) { resource }
    @controller.request.set_header("HTTP_ACCEPT", "application/json")
    rendered = []
    @controller.define_singleton_method(:render) { |**kwargs| rendered << kwargs }

    @controller.enforce_authentication_guest!

    assert_equal :forbidden, rendered.last[:status]
    assert_equal({ error: "already_authenticated" }, rendered.last[:json])
  end

  test "resolve_token_kind_id resolves a coded kind through the reference model" do
    @controller.define_singleton_method(:resource_type) { "operator" }
    token_class = Class.new
    token_class.define_singleton_method(:columns_hash) { { "staff_token_kind_id" => Struct.new(:type).new(:integer) } }
    @controller.define_singleton_method(:token_class) { token_class }
    kind_model =
      Class.new do
        define_singleton_method(:name) { "InlineCodedKind" }
        define_singleton_method(:column_names) { %w(code) }
        define_singleton_method(:find_by!) { |code:| Struct.new(:id).new(77) if code == "BROWSER_WEB" }
      end
    @controller.define_singleton_method(:token_kind_model) { kind_model }

    assert_equal 77, @controller.resolve_token_kind_id("BROWSER_WEB")
  end

  test "resolve_token_kind_id logs and reraises when the coded kind is missing" do
    @controller.define_singleton_method(:resource_type) { "operator" }
    token_class = Class.new
    token_class.define_singleton_method(:columns_hash) { { "staff_token_kind_id" => Struct.new(:type).new(:integer) } }
    @controller.define_singleton_method(:token_class) { token_class }
    kind_model =
      Class.new do
        define_singleton_method(:name) { "InlineCodedKind" }
        define_singleton_method(:column_names) { %w(code) }
        define_singleton_method(:find_by!) { |**| raise ActiveRecord::RecordNotFound, "not found" }
      end
    @controller.define_singleton_method(:token_kind_model) { kind_model }

    error = assert_raises(ActiveRecord::RecordNotFound) { @controller.resolve_token_kind_id("MISSING") }

    assert_match "InlineCodedKind", error.message
  end

  test "ensure_token_kind_exists! logs and reraises when the reference row cannot be created" do
    @controller.define_singleton_method(:resource_type) { "client" }
    kind_model =
      Class.new do
        define_singleton_method(:name) { "InlineFailingKind" }
        define_singleton_method(:find_or_create_by!) { |**| raise ActiveRecord::RecordNotFound, "boom" }
      end
    @controller.define_singleton_method(:token_kind_model) { kind_model }

    error =
      assert_raises(ActiveRecord::RecordNotFound) do
        @controller.send(:ensure_token_kind_exists!, ClientTokenKind::BROWSER_WEB)
      end

    assert_match "InlineFailingKind", error.message
  end

  test "finalize_mfa_login! returns a hard reject payload when the session limit is exceeded" do
    @controller.session[:pending_mfa] = { "pt" => "/after", "auth_method" => "email" }
    @controller.define_singleton_method(:pending_mfa_sign_in_flow_for) { |_user| nil }
    @controller.define_singleton_method(:pending_sign_in_result_after_primary!) do |*, **|
      { status: :session_limit_hard_reject, message: "too many sessions", http_status: :forbidden }
    end

    result = @controller.send(:finalize_mfa_login!, @user)

    assert_equal(
      { status: :session_limit_hard_reject, message: "too many sessions", http_status: :forbidden },
      result,
    )
    assert_nil @controller.session[:pending_mfa]
  end

  test "finalize_mfa_login! returns the raw result for unrecognized statuses" do
    @controller.session[:pending_mfa] = { "pt" => "/after", "auth_method" => "email" }
    @controller.define_singleton_method(:pending_mfa_sign_in_flow_for) { |_user| nil }
    @controller.define_singleton_method(:pending_sign_in_result_after_primary!) do |*, **|
      { status: :login_forbidden }
    end

    result = @controller.send(:finalize_mfa_login!, @user)

    assert_equal({ status: :login_forbidden }, result)
  end

  test "session_limit_gate_pt falls back to / when reading the request raises" do
    @controller.define_singleton_method(:request) { raise StandardError, "boom" }

    assert_equal "/", @controller.send(:session_limit_gate_pt)
  end

  test "count_active_sessions returns zero for unsupported resource types" do
    @controller.define_singleton_method(:token_class) { ClientToken }

    assert_equal 0, @controller.send(:count_active_sessions, Object.new)
  end

  test "find_restricted_sessions_scope resolves the visitor restricted-status scope" do
    visitor = create_verified_visitor_with_email(email_address: "restricted-scope@example.com")
    restricted_token = VisitorToken.create!(
      visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      visitor_token_status_id: VisitorTokenStatus::RESTRICTED, discarded_at: 1.day.from_now,
    )
    active_token = VisitorToken.create!(
      visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      visitor_token_status_id: VisitorTokenStatus::ACTIVE, discarded_at: 1.day.from_now,
    )

    scope = @controller.send(:find_restricted_sessions_scope, visitor)

    assert_includes scope, restricted_token
    assert_not_includes scope, active_token
  end

  test "token_class_for_resource falls back to token_class for unsupported resources" do
    @controller.define_singleton_method(:token_class) { ClientToken }

    assert_equal ClientToken, @controller.send(:token_class_for_resource, Object.new)
  end

  test "find_token_record_by_session_identifier matches by oidc_sid for uuid identifiers" do
    @controller.define_singleton_method(:resource_type) { "client" }
    @controller.define_singleton_method(:token_class) { ClientToken }
    token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    sid = SecureRandom.uuid
    token.update_columns(oidc_sid: sid)

    found = @controller.send(:find_token_record_by_session_identifier, sid)

    assert_equal token, found
  end

  test "best_effort_refresh_side_effect swallows errors and logs a warning" do
    result = @controller.send(:best_effort_refresh_side_effect) { raise StandardError, "boom" }

    assert_nil result
  end

  test "token_dbsc_url resolves an absolute url for the operator and visitor surfaces" do
    @controller.define_singleton_method(:resource_type) { "operator" }

    assert_match %r{\Ahttps?://}, @controller.send(:token_dbsc_url)

    @controller.define_singleton_method(:resource_type) { "visitor" }

    assert_match %r{\Ahttps?://}, @controller.send(:token_dbsc_url)
  end

  test "dbsc_route_helper raises when no route helper is available for the current surface" do
    @controller.define_singleton_method(:resource_type) { "operator" }
    @controller.define_singleton_method(:respond_to?) do |name, include_private = false|
      next false if name.to_s.include?("edge_v0_token_dbsc")

      super(name, include_private)
    end

    assert_raises(NoMethodError) { @controller.send(:token_dbsc_path) }
  end

  test "mfa_required_for? falls back to mfa_level_enabled? when mfa_level_required? is unavailable" do
    resource = Client.new
    resource.singleton_class.send(:undef_method, :mfa_level_required?)
    resource.define_singleton_method(:mfa_level_enabled?) { true }

    assert @controller.send(:mfa_required_for?, resource)
  end

  test "mfa_entry_path recovers to the literal path when the route helper raises" do
    @controller.define_singleton_method(:sign_app_sign_in_challenge_path) do |**|
      raise StandardError, "route boom"
    end

    assert_equal "/sign/in/challenge", @controller.mfa_entry_path(ri: "jp")
  end

  test "handle_auth_required_html falls back to main_app.sign_in_path when no sign_in_url_with_pt is defined" do
    @controller.define_singleton_method(:respond_to?) do |name, include_private = false|
      next false if name.to_sym == :sign_in_url_with_pt

      super(name, include_private)
    end
    @controller.define_singleton_method(:main_app) { Struct.new(:sign_in_path).new("/main/sign_in") }
    redirected = []
    @controller.define_singleton_method(:redirect_to) { |*args, **kwargs| redirected << [args, kwargs] }

    @controller.send(:handle_auth_required_html, {})

    assert_equal "/main/sign_in", redirected.first.first.first
  end

  test "handle_auth_required_html falls back to the literal sign in path when nothing else resolves" do
    @controller.define_singleton_method(:respond_to?) do |name, include_private = false|
      next false if name.to_sym == :sign_in_url_with_pt

      super(name, include_private)
    end
    @controller.define_singleton_method(:main_app) { Object.new }
    redirected = []
    @controller.define_singleton_method(:redirect_to) { |*args, **kwargs| redirected << [args, kwargs] }

    @controller.send(:handle_auth_required_html, {})

    assert_equal "/sign/in", redirected.first.first.first
  end

  test "handle_auth_required_html routes absolute sign-in urls through the jump gateway when oidc is unavailable" do
    @controller.define_singleton_method(:sign_in_url_with_pt) { |_pt| "https://sign.example.com/in" }
    jumps = []
    @controller.define_singleton_method(:redirect_to_jump_url) { |path, **opts| jumps << [path, opts] }

    @controller.send(:handle_auth_required_html, {})

    assert_equal [["https://sign.example.com/in", { alert: I18n.t("errors.messages.login_required") }]], jumps
  end

  test "handle_guest_only_with_status_checks renders inline for non-GET unauthorized and bad_request statuses" do
    @request.set_header("REQUEST_METHOD", "POST")
    rendered = []
    @controller.define_singleton_method(:render) { |**kwargs| rendered << kwargs }

    @controller.handle_guest_only_with_status_checks(status: :unauthorized, message: "no dice")

    assert_equal "no dice", rendered.last[:plain]
    assert_equal :unauthorized, rendered.last[:status]

    @controller.handle_guest_only_with_status_checks(status: :bad_request, message: "bad")

    assert_equal "bad", rendered.last[:plain]
    assert_equal :bad_request, rendered.last[:status]
  end

  test "handle_guest_only_html falls back to main_app.after_login_path when the surface helper is hidden" do
    @controller.define_singleton_method(:respond_to?) do |name, include_private = false|
      next false if name.to_sym == :after_login_path

      super(name, include_private)
    end
    @controller.define_singleton_method(:main_app) { Struct.new(:after_login_path).new("/main/after") }
    redirected = []
    @controller.define_singleton_method(:redirect_to) { |*args, **kwargs| redirected << [args, kwargs] }

    @controller.handle_guest_only_html({})

    assert_equal "/main/after", redirected.first.first.first
  end

  test "handle_guest_only_html falls back to / when no after_login_path helper is available anywhere" do
    @controller.define_singleton_method(:respond_to?) do |name, include_private = false|
      next false if name.to_sym == :after_login_path

      super(name, include_private)
    end
    @controller.define_singleton_method(:main_app) { Object.new }
    redirected = []
    @controller.define_singleton_method(:redirect_to) { |*args, **kwargs| redirected << [args, kwargs] }

    @controller.handle_guest_only_html({})

    assert_equal "/", redirected.first.first.first
  end
end

# DAMP local helper copy for former shared test support.
class AuthenticationBaseTestController
  TEST_BROWSER_USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
  TEST_VERIFICATION_COOKIE_PREFIX = "test_verified:"

  private

  def configured_host(surface_name)
    Rails.configuration.x.boot_config.fetch(:hosts).public_send(surface_name).host
  end

  def host_headers(host = nil)
    host_value = host || (respond_to?(:request, true) ? request&.host : nil) || ENV["DEFAULT_URL_HOST"]
    headers = { "Client-Agent" => TEST_BROWSER_USER_AGENT }
    headers["Host"] = host_value if host_value.present?
    headers
  end

  def browser_headers
    csrf_token = csrf_token_value
    headers = {
      "Client-Agent" => TEST_BROWSER_USER_AGENT,
      "Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
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

    ensure_user_token_reference_records!
    token = session_public_id.present? ? ClientToken.find_by(public_id: session_public_id) : nil
    token ||= ClientToken.where(user_id: user.id).where("discarded_at > ?", Time.current).order(created_at: :desc).first
    token ||= ClientToken.create!(
      user_id: user.id,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      user_token_binding_method_id: ClientTokenBindingMethod::LEGACY,
      user_token_dbsc_status_id: ClientTokenDbscStatus::NOTHING,
    )
    base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    base
  end

  def as_staff_headers(staff, host: nil, headers: {}, session_public_id: nil)
    base = host_headers(host).merge(headers).merge("X-TEST-CURRENT-STAFF" => staff.id.to_s)
    return base unless staff.respond_to?(:persisted?) && staff.persisted? && staff.class.name == "Operator"

    ensure_staff_token_reference_records!
    token = session_public_id.present? ? OperatorToken.find_by(public_id: session_public_id) : nil
    token ||= OperatorToken.where(staff_id: staff.id).where(
      "discarded_at > ?",
      Time.current,
    ).order(created_at: :desc).first
    token ||= OperatorToken.create!(
      staff_id: staff.id,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      staff_token_binding_method_id: OperatorTokenBindingMethod::LEGACY,
      staff_token_dbsc_status_id: OperatorTokenDbscStatus::NOTHING,
    )
    base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    base
  end

  def as_visitor_headers(visitor, host: nil, headers: {}, session_public_id: nil)
    base = host_headers(host).merge(headers).merge("X-TEST-CURRENT-RESOURCE" => visitor.id.to_s)
    return base unless visitor.respond_to?(:persisted?) && visitor.persisted? && visitor.class.name == "Visitor"

    ensure_visitor_token_reference_records!
    token = session_public_id.present? ? VisitorToken.find_by(public_id: session_public_id) : nil
    token ||= VisitorToken.where(visitor_id: visitor.id).where(
      "discarded_at > ?",
      Time.current,
    ).order(created_at: :desc).first
    token ||= VisitorToken.create!(
      visitor_id: visitor.id,
      visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      visitor_token_status_id: VisitorTokenStatus::ACTIVE,
      visitor_token_binding_method_id: VisitorTokenBindingMethod::LEGACY,
      visitor_token_dbsc_status_id: VisitorTokenDbscStatus::NOTHING,
    )
    base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    base
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

  def ensure_user_reference_records!
    ClientStatus.find_or_create_by!(id: ClientStatus::NOTHING)
    ClientVisibility.find_or_create_by!(id: ClientVisibility::USER)
    ClientMfaLevel.find_or_create_by!(id: ClientMfaLevel::NOTHING)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::NOTHING)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::ACTIVE)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::UNCONFIGURED)
    ClientEmailStatus.find_or_create_by!(id: ClientEmailStatus::VERIFIED)
    ClientTelephoneStatus.find_or_create_by!(id: ClientTelephoneStatus::VERIFIED)
    ClientPasskeyStatus.find_or_create_by!(id: ClientPasskeyStatus::ACTIVE)
  end

  def ensure_visitor_reference_records!
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorMfaLevel.find_or_create_by!(id: VisitorMfaLevel::NOTHING)
    VisitorMfaStatus.find_or_create_by!(id: VisitorMfaStatus::UNCONFIGURED)
    VisitorEmailStatus.find_or_create_by!(id: VisitorEmailStatus::VERIFIED)
    VisitorTelephoneStatus.find_or_create_by!(id: VisitorTelephoneStatus::VERIFIED)
    VisitorPasskeyStatus.find_or_create_by!(id: VisitorPasskeyStatus::ACTIVE)
    if defined?(VisitorSecretCredentialStatus)
      [
        VisitorSecretCredentialStatus::ACTIVE,
        VisitorSecretCredentialStatus::EXPIRED,
        VisitorSecretCredentialStatus::REVOKED,
        VisitorSecretCredentialStatus::USED,
        VisitorSecretCredentialStatus::DELETED,
        VisitorSecretCredentialStatus::NOTHING,
      ].each do |id|
        VisitorSecretCredentialStatus.find_or_create_by!(id: id)
      end
    end
    return unless defined?(VisitorSecretCredentialKind)

    [VisitorSecretCredentialKind::LOGIN, VisitorSecretCredentialKind::RECOVERY,
     VisitorSecretCredentialKind::API,].each do |id|
      VisitorSecretCredentialKind.find_or_create_by!(id: id)
    end

  end

  def ensure_user_token_reference_records!
    ClientTokenKind.find_or_create_by!(id: ClientTokenKind::BROWSER_WEB)
    ClientTokenStatus.find_or_create_by!(id: ClientTokenStatus::ACTIVE)
    ClientTokenBindingMethod.find_or_create_by!(id: ClientTokenBindingMethod::LEGACY)
    ClientTokenDbscStatus.find_or_create_by!(id: ClientTokenDbscStatus::NOTHING)
  end

  def ensure_staff_token_reference_records!
    OperatorTokenKind.find_or_create_by!(id: OperatorTokenKind::BROWSER_WEB)
    OperatorTokenStatus.find_or_create_by!(id: OperatorTokenStatus::ACTIVE)
    OperatorTokenBindingMethod.find_or_create_by!(id: OperatorTokenBindingMethod::LEGACY)
    OperatorTokenDbscStatus.find_or_create_by!(id: OperatorTokenDbscStatus::NOTHING)
  end

  def ensure_visitor_token_reference_records!
    VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::BROWSER_WEB)
    VisitorTokenStatus.find_or_create_by!(id: VisitorTokenStatus::ACTIVE)
    VisitorTokenBindingMethod.find_or_create_by!(id: VisitorTokenBindingMethod::LEGACY)
    VisitorTokenDbscStatus.find_or_create_by!(id: VisitorTokenDbscStatus::NOTHING)
  end

  def create_verified_user_with_email(email_address: "user-#{SecureRandom.hex(4)}@example.com")
    ensure_user_reference_records!
    user = Client.create!(status_id: ClientStatus::NOTHING, visibility_id: ClientVisibility::USER)
    insert_verified_user_email!(user_id: user.id, address: email_address)
    user.reload
  end

  def create_verified_visitor_with_email(email_address: "visitor-#{SecureRandom.hex(4)}@example.com")
    ensure_visitor_reference_records!
    visitor = Visitor.create!(status_id: VisitorStatus::NOTHING, visibility_id: VisitorVisibility::VISITOR)
    insert_verified_visitor_email!(visitor_id: visitor.id, address: email_address)
    visitor.refresh_mfa_status! if visitor.respond_to?(:refresh_mfa_status!)
    visitor.reload
  end

  def insert_verified_user_email!(user_id:, address:)
    ClientEmail.create!(
      user_id: user_id,
      address: address,
      address_digest: IdentifierBlindIndex.bidx_for_email(address),
      user_email_status_id: ClientEmailStatus::VERIFIED,
      otp_private_key: SecureRandom.base64(24),
      otp_counter: "",
      otp_attempts_count: 0,
      public_id: SecureRandom.alphanumeric(21),
    )
  end

  def insert_verified_visitor_email!(visitor_id:, address:)
    VisitorEmail.insert_all(
      [
        {
          visitor_id: visitor_id,
          address: address,
          address_digest: IdentifierBlindIndex.bidx_for_email(address),
          visitor_email_status_id: VisitorEmailStatus::VERIFIED,
          otp_private_key: SecureRandom.base64(24),
          otp_counter: "",
          otp_attempts_count: 0,
          public_id: SecureRandom.alphanumeric(21),
          created_at: Time.current,
          updated_at: Time.current,
        },
      ],
    )
  end

  def satisfy_user_verification(token, scope: nil)
    _verification, raw_token = ClientVerification.issue_for_token!(token: token)
    cookies[ClientVerification.cookie_name] = raw_token
    mark_token_step_up_satisfied_for_test(token, scope: scope)
    true
  end

  def satisfy_staff_verification(token, scope: nil)
    _verification, raw_token = OperatorVerification.issue_for_token!(token: token)
    cookies[OperatorVerification.cookie_name] = raw_token
    mark_token_step_up_satisfied_for_test(token, scope: scope)
    true
  end

  def satisfy_visitor_verification(token, scope: nil)
    _verification, raw_token = VisitorVerification.issue_for_token!(token: token)
    cookies[VisitorVerification.cookie_name] = raw_token
    mark_token_step_up_satisfied_for_test(token, scope: scope)
    true
  end

  def mark_token_step_up_satisfied_for_test(token, scope: nil, at: Time.current)
    return unless token.respond_to?(:update_columns)

    attrs = {
      last_step_up_at: at,
      last_step_up_scope: scope.presence || token.try(:last_step_up_scope).presence || "verification",
      last_step_up_aal: ("aal2" if token.respond_to?(:last_step_up_aal)),
      last_step_up_method: ("passkey" if token.respond_to?(:last_step_up_method)),
      last_step_up_session_public_id: (token.public_id if token.respond_to?(:last_step_up_session_public_id)),
      last_step_up_purpose: ("step_up" if token.respond_to?(:last_step_up_purpose)),
      last_step_up_audience: (step_up_test_audience_for_token(token) if token.respond_to?(:last_step_up_audience)),
      updated_at: Time.current,
    }.compact
    token.update_columns(attrs)
  end

  def step_up_test_audience_for_token(token)
    case token.class.name
    when "OperatorToken" then "step_up:org"
    when "VisitorToken" then "step_up:com"
    else "step_up:app"
    end
  end

  def signed_step_up_pt_for(path, surface:, session_nonce:)
    safe_path = path.to_s
    return nil if safe_path.blank? || !safe_path.start_with?("/") || safe_path.match?(/[\x00-\x1F\x7F]/)

    verifier = ActiveSupport::MessageVerifier.new(
      Rails.application.key_generator.generate_key("path_target_token", 32),
      digest: "SHA256",
      serializer: JSON,
      url_safe: true,
    )
    verifier.generate(
      { "flow" => "step_up.bootstrap",
        "surface" => surface.to_s,
        "session_nonce" => session_nonce.to_s,
        "pt" => safe_path, },
      purpose: :path_target,
      expires_in: 15.minutes,
    )
  end

  def signed_step_up_grant_for(actor:, token:, scope:, return_to:, surface:, methods: %i(email_otp totp passkey),
                               aal: "aal2")
    IdentityStepUpCeremonyGrantIssuer.issue!(
      surface: surface.to_s,
      actor_ref: actor.public_id,
      session_ref: token.public_id,
      required_scope: scope.to_s,
      required_aal: aal,
      allowed_methods: methods,
      return_to: return_to,
      expires_at: 15.minutes.from_now,
    ).grant
  end

  def load_jump_rt_env!
    @jump_rt_env_originals ||= {}
    jump_rt_key = Base64.strict_encode64(OpenSSL::PKey::EC.generate("secp384r1").to_der)
    {
      "JUMP_GATEWAY_URL" => "https://jump.umaxica.net",
      "JWT_SIGN_APP_ACTIVE_KID" => "sign-app-test",
      "JWT_SIGN_APP_PRIVATE_KEY" => jump_rt_key,
      "JWT_SIGN_ORG_ACTIVE_KID" => "sign-org-test",
      "JWT_SIGN_ORG_PRIVATE_KEY" => jump_rt_key,
      "JWT_SIGN_COM_ACTIVE_KID" => "sign-com-test",
      "JWT_SIGN_COM_PRIVATE_KEY" => jump_rt_key,
      "JWT_ACME_APP_ACTIVE_KID" => "acme-app-test",
      "JWT_ACME_APP_PRIVATE_KEY" => jump_rt_key,
      "JWT_ACME_ORG_ACTIVE_KID" => "acme-org-test",
      "JWT_ACME_ORG_PRIVATE_KEY" => jump_rt_key,
      "JWT_ACME_COM_ACTIVE_KID" => "acme-com-test",
      "JWT_ACME_COM_PRIVATE_KEY" => jump_rt_key,
      "JWT_CORE_APP_ACTIVE_KID" => "core-app-test",
      "JWT_CORE_APP_PRIVATE_KEY" => jump_rt_key,
      "JWT_CORE_ORG_ACTIVE_KID" => "core-org-test",
      "JWT_CORE_ORG_PRIVATE_KEY" => jump_rt_key,
      "JWT_CORE_COM_ACTIVE_KID" => "core-com-test",
      "JWT_CORE_COM_PRIVATE_KEY" => jump_rt_key,
      "JWT_BASE_APP_ACTIVE_KID" => "base-app-test",
      "JWT_BASE_APP_PRIVATE_KEY" => jump_rt_key,
      "JWT_BASE_ORG_ACTIVE_KID" => "base-org-test",
      "JWT_BASE_ORG_PRIVATE_KEY" => jump_rt_key,
      "JWT_BASE_COM_ACTIVE_KID" => "base-com-test",
      "JWT_BASE_COM_PRIVATE_KEY" => jump_rt_key,
    }.each do |key, value|
      @jump_rt_env_originals[key] = ENV[key] unless @jump_rt_env_originals.key?(key)
      ENV[key] = value
    end
    JitSecurityJwtRegistry.reload! if defined?(JitSecurityJwtRegistry)
  end

  def with_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
  ensure
    # Restore the environment default, not the value observed on entry: if the flag was
    # already leaked as true, restoring the observation would pin the leak for the rest
    # of the process and every later test expecting protection off would fail.
    ActionController::Base.allow_forgery_protection =
      Rails.configuration.action_controller.allow_forgery_protection
  end

  def csrf_token_value
    "test-csrf-token"
  end

  def csrf_headers(token)
    { "X-CSRF-Token" => token }
  end

  def fetch_csrf_token(path)
    get(path)
    response.body[/name="authenticity_token" value="([^"]+)"/, 1] || response.body
  end

  def social_callback_headers(host)
    scheme = host.to_s.include?("localhost") ? "http" : "https"
    origin = "#{scheme}://#{host}"
    cookies["csrf_token"] = csrf_token_value if respond_to?(:cookies)
    {
      "Host" => host,
      "Origin" => origin,
      "Referer" => "#{origin}/",
      "Sec-Fetch-Site" => "same-origin",
      "X-STRICT-SOCIAL-STATE" => "1",
      "X-CSRF-Token" => csrf_token_value,
    }
  end

  def social_auth_state_from_response
    session[:social_auth_state].presence || begin
      uri = URI.parse(response.location.to_s)
      Rack::Utils.parse_nested_query(uri.query.to_s)["state"].presence
    rescue URI::InvalidURIError
      nil
    end
  end

  def seed_social_auth_session(provider:, intent: "login", user: nil, entry: nil, ri: "jp", rt: nil, referer: nil)
    host = configured_host(:sign_service)
    host!(host) if respond_to?(:host!)
    normalized_provider = SocialIdentifiable.normalize_provider(provider)
    continue_path =
      if intent.to_s == "link"
        public_send(:"auth_app_settings_#{normalized_provider}_path", ri: ri)
      elsif entry.to_s == "sign_up"
        public_send(:"auth_app_social_#{normalized_provider}_registration_path", ri: ri, rt: rt)
      else
        public_send(:"auth_app_social_#{normalized_provider}_session_path", ri: ri, rt: rt)
      end
    headers = social_callback_headers(host)
    headers["Referer"] = referer if referer.present?
    if user
      user_headers = as_user_headers(user, host: host)
      token = ClientToken.find_by(public_id: user_headers["X-TEST-SESSION-PUBLIC-ID"])
      mark_token_step_up_satisfied_for_test(
        token,
        scope: SocialAuth::SOCIAL_LINK_SCOPE,
      ) if intent.to_s == "link" && token
      headers = headers.merge(user_headers)
    end
    post(continue_path, headers: headers)
    social_auth_state_from_response
  end

  def response_set_cookie_lines
    raw = response.headers["Set-Cookie"] || response.headers["set-cookie"]
    lines =
      case raw
      when Array then raw
      when String then raw.split("\n")
      else []
      end
    lines.flat_map { |line| line.to_s.split("\n") }.compact_blank
  end

  def assert_oidc_authorize_redirect(location, host:, client_id: "base-rails-rp")
    uri = URI.parse(location)
    query = Rack::Utils.parse_nested_query(uri.query.to_s)

    assert_equal host, uri.host
    assert_equal "/oauth/authorize", uri.path
    assert_equal client_id, query["client_id"]
    assert_predicate query["state"], :present?
  end
end

# DAMP local route helper aliases for former shared test support.
class AuthenticationBaseTestController
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

# DAMP local helper copy on the test class.
class AuthenticationBaseCoverageTest
  TEST_BROWSER_USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" unless const_defined?(
      :TEST_BROWSER_USER_AGENT, false,
    )
  PREFERENCE_JWT_KEY = OpenSSL::PKey::EC.generate("secp384r1") unless const_defined?(:PREFERENCE_JWT_KEY, false)

  private

  def configured_host(surface_name)
    Rails.configuration.x.boot_config.fetch(:hosts).public_send(surface_name).host
  end

  def set_access_cookie(token)
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = token
  end

  def set_refresh_cookie(token)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token
  end

  def jump_rt_url_from_location(location)
    uri = URI.parse(location.to_s)
    return location unless uri.host == "jump.umaxica.net"

    token = Rack::Utils.parse_nested_query(uri.query.to_s)["rt"]
    return location if token.blank?

    payload, = JWT.decode(token, nil, false)
    payload["url"].presence || location
  rescue JWT::DecodeError, URI::InvalidURIError
    location
  end

  def with_preference_jwt_keys(host: nil)
    audiences = host ? [host] : PreferenceJwtConfiguration.audiences
    pub_key_for_stub = ->(_kid, **_options) { self.class::PREFERENCE_JWT_KEY }
    PreferenceJwtConfiguration.stub(:private_key, self.class::PREFERENCE_JWT_KEY) do
      PreferenceJwtConfiguration.stub(:public_key, self.class::PREFERENCE_JWT_KEY) do
        PreferenceJwtConfiguration.stub(:private_key_for_active, self.class::PREFERENCE_JWT_KEY) do
          PreferenceJwtConfiguration.stub(:public_key_for, pub_key_for_stub) do
            PreferenceJwtConfiguration.stub(:active_kid, "default") do
              PreferenceJwtConfiguration.stub(:issuer, "jit-preference") do
                PreferenceJwtConfiguration.stub(:audiences, audiences) { yield }
              end
            end
          end
        end
      end
    end
  end

  def host_headers(host = nil)
    host_value = host || (respond_to?(:request, true) ? request&.host : nil) || ENV["DEFAULT_URL_HOST"]
    headers = { "Client-Agent" => self.class::TEST_BROWSER_USER_AGENT }
    headers["Host"] = host_value if host_value.present?
    headers
  end

  def browser_headers
    csrf_token = csrf_token_value
    cookies["csrf_token"] = csrf_token if respond_to?(:cookies, true)
    host_headers.merge("X-CSRF-Token" => csrf_token)
  end

  def as_user_headers(user, host: nil, headers: {}, session_public_id: nil)
    base = host_headers(host).merge(headers).merge("X-TEST-CURRENT-USER" => user.id.to_s)
    return base unless user.respond_to?(:persisted?) && user.persisted? && user.class.name == "Client"

    ensure_user_token_reference_records!
    token = session_public_id.present? ? ClientToken.find_by(public_id: session_public_id) : nil
    token ||= ClientToken.where(user_id: user.id).where("discarded_at > ?", Time.current).order(created_at: :desc).first
    token ||= ClientToken.create!(
      user_id: user.id, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      user_token_binding_method_id: ClientTokenBindingMethod::LEGACY,
      user_token_dbsc_status_id: ClientTokenDbscStatus::NOTHING,
    )
    base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    base
  end

  def as_staff_headers(staff, host: nil, headers: {}, session_public_id: nil)
    base = host_headers(host).merge(headers).merge("X-TEST-CURRENT-STAFF" => staff.id.to_s)
    return base unless staff.respond_to?(:persisted?) && staff.persisted? && staff.class.name == "Operator"

    ensure_staff_token_reference_records!
    token = session_public_id.present? ? OperatorToken.find_by(public_id: session_public_id) : nil
    token ||= OperatorToken.where(staff_id: staff.id).where(
      "discarded_at > ?",
      Time.current,
    ).order(created_at: :desc).first
    token ||= OperatorToken.create!(
      staff_id: staff.id, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      staff_token_binding_method_id: OperatorTokenBindingMethod::LEGACY,
      staff_token_dbsc_status_id: OperatorTokenDbscStatus::NOTHING,
    )
    base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    base
  end

  def as_visitor_headers(visitor, host: nil, headers: {}, session_public_id: nil)
    base = host_headers(host).merge(headers).merge("X-TEST-CURRENT-RESOURCE" => visitor.id.to_s)
    return base unless visitor.respond_to?(:persisted?) && visitor.persisted? && visitor.class.name == "Visitor"

    ensure_visitor_token_reference_records!
    token = session_public_id.present? ? VisitorToken.find_by(public_id: session_public_id) : nil
    token ||= VisitorToken.where(visitor_id: visitor.id).where(
      "discarded_at > ?",
      Time.current,
    ).order(created_at: :desc).first
    token ||= VisitorToken.create!(
      visitor_id: visitor.id, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      visitor_token_status_id: VisitorTokenStatus::ACTIVE,
      visitor_token_binding_method_id: VisitorTokenBindingMethod::LEGACY,
      visitor_token_dbsc_status_id: VisitorTokenDbscStatus::NOTHING,
    )
    base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    base
  end

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end

  def ensure_user_reference_records!
    ClientStatus.find_or_create_by!(id: ClientStatus::NOTHING)
    ClientVisibility.find_or_create_by!(id: ClientVisibility::USER)
    ClientMfaLevel.find_or_create_by!(id: ClientMfaLevel::NOTHING)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::NOTHING)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::ACTIVE)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::UNCONFIGURED)
    ClientEmailStatus.find_or_create_by!(id: ClientEmailStatus::VERIFIED)
    ClientTelephoneStatus.find_or_create_by!(id: ClientTelephoneStatus::VERIFIED)
    ClientPasskeyStatus.find_or_create_by!(id: ClientPasskeyStatus::ACTIVE)
  end

  def ensure_visitor_reference_records!
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorMfaLevel.find_or_create_by!(id: VisitorMfaLevel::NOTHING)
    VisitorMfaStatus.find_or_create_by!(id: VisitorMfaStatus::UNCONFIGURED)
    VisitorEmailStatus.find_or_create_by!(id: VisitorEmailStatus::VERIFIED)
    VisitorTelephoneStatus.find_or_create_by!(id: VisitorTelephoneStatus::VERIFIED)
    VisitorPasskeyStatus.find_or_create_by!(id: VisitorPasskeyStatus::ACTIVE)
  end

  def ensure_user_token_reference_records!
    ClientTokenKind.find_or_create_by!(id: ClientTokenKind::BROWSER_WEB)
    ClientTokenStatus.find_or_create_by!(id: ClientTokenStatus::ACTIVE)
    ClientTokenBindingMethod.find_or_create_by!(id: ClientTokenBindingMethod::LEGACY)
    ClientTokenDbscStatus.find_or_create_by!(id: ClientTokenDbscStatus::NOTHING)
  end

  def ensure_staff_token_reference_records!
    OperatorTokenKind.find_or_create_by!(id: OperatorTokenKind::BROWSER_WEB)
    OperatorTokenStatus.find_or_create_by!(id: OperatorTokenStatus::ACTIVE)
    OperatorTokenBindingMethod.find_or_create_by!(id: OperatorTokenBindingMethod::LEGACY)
    OperatorTokenDbscStatus.find_or_create_by!(id: OperatorTokenDbscStatus::NOTHING)
  end

  def ensure_visitor_token_reference_records!
    VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::BROWSER_WEB)
    VisitorTokenStatus.find_or_create_by!(id: VisitorTokenStatus::ACTIVE)
    VisitorTokenBindingMethod.find_or_create_by!(id: VisitorTokenBindingMethod::LEGACY)
    VisitorTokenDbscStatus.find_or_create_by!(id: VisitorTokenDbscStatus::NOTHING)
  end

  def create_verified_visitor_with_email(email_address: "visitor-#{SecureRandom.hex(4)}@example.com")
    ensure_visitor_reference_records!
    visitor = Visitor.create!(status_id: VisitorStatus::NOTHING, visibility_id: VisitorVisibility::VISITOR)
    VisitorEmail.create!(
      visitor_id: visitor.id, address: email_address,
      address_digest: IdentifierBlindIndex.bidx_for_email(email_address),
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
      otp_private_key: SecureRandom.base64(24),
      otp_counter: "",
      otp_attempts_count: 0,
      public_id: SecureRandom.alphanumeric(21),
    )
    visitor.reload
  end

  def satisfy_user_verification(token, scope: nil)
    _verification, raw_token = ClientVerification.issue_for_token!(token: token)
    cookies[ClientVerification.cookie_name] = raw_token
    mark_token_step_up_satisfied_for_test(token, scope: scope)
    true
  end

  def satisfy_staff_verification(token, scope: nil)
    _verification, raw_token = OperatorVerification.issue_for_token!(token: token)
    cookies[OperatorVerification.cookie_name] = raw_token
    mark_token_step_up_satisfied_for_test(token, scope: scope)
    true
  end

  def satisfy_visitor_verification(token, scope: nil)
    _verification, raw_token = VisitorVerification.issue_for_token!(token: token)
    cookies[VisitorVerification.cookie_name] = raw_token
    mark_token_step_up_satisfied_for_test(token, scope: scope)
    true
  end

  def mark_token_step_up_satisfied_for_test(token, scope: nil, at: Time.current)
    return unless token.respond_to?(:update_columns)

    token.update_columns(
      { last_step_up_at: at,
        last_step_up_scope: scope.presence || token.try(:last_step_up_scope).presence || "verification",
        updated_at: Time.current, }.compact,
    )
  end

  def load_jump_rt_env!
    @jump_rt_env_originals ||= {}
    jump_rt_key = Base64.strict_encode64(OpenSSL::PKey::EC.generate("secp384r1").to_der)
    %w(SIGN_APP SIGN_ORG SIGN_COM ACME_APP ACME_ORG ACME_COM CORE_APP CORE_ORG CORE_COM BASE_APP BASE_ORG
       BASE_COM).each do |namespace|
      ENV["JWT_#{namespace}_ACTIVE_KID"] = "#{namespace.downcase.tr("_", "-")}-test"
      ENV["JWT_#{namespace}_PRIVATE_KEY"] = jump_rt_key
    end
    ENV["JUMP_GATEWAY_URL"] = "https://jump.umaxica.net"
    JitSecurityJwtRegistry.reload! if defined?(JitSecurityJwtRegistry)
  end

  def with_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
  ensure
    # Restore the environment default, not the value observed on entry: if the flag was
    # already leaked as true, restoring the observation would pin the leak for the rest
    # of the process and every later test expecting protection off would fail.
    ActionController::Base.allow_forgery_protection =
      Rails.configuration.action_controller.allow_forgery_protection
  end

  def csrf_token_value
    "test-csrf-token"
  end

  def response_set_cookie_lines
    raw = response.headers["Set-Cookie"] || response.headers["set-cookie"]
    lines = raw.is_a?(Array) ? raw : raw.to_s.split("\n")
    lines.flat_map { |line| line.to_s.split("\n") }.compact_blank
  end

  def extract_cookies_from_response
    response_set_cookie_lines.each_with_object({}) do |line, parsed|
      pair = line.to_s.split(";", 2).first
      name, value = pair.to_s.split("=", 2)
      parsed[name] = CGI.unescape(value.to_s) if name.present?
    end
  end

  def state_changing_application_route_targets
    Rails.application.routes.routes.filter_map do |route|
      verbs = route.verb.to_s.delete("^A-Z|").split("|")
      next if verbs.empty? || (verbs - %w(GET HEAD)).empty?

      controller = route.required_defaults[:controller].to_s
      action = route.required_defaults[:action].to_s
      next if controller.blank? || action.blank?

      controller_class_name = "#{controller.camelize}Controller"
      next unless Rails.root.join("app/controllers/#{controller}_controller.rb").exist?

      { verb: verbs.join("|"),
        path: route.path.spec.to_s,
        controller: controller,
        action: action,
        controller_class: Object.const_get(controller_class_name), }
    rescue NameError
      nil
    end
  end

  def setup_google_mock_auth(uid: "google_uid_123", email: "google@example.com")
    OmniAuth.config.mock_auth[:google_app] =
      OmniAuth::AuthHash.new(
        provider: "google_app", uid: uid, info: { email: email, name: "Google Client" },
        credentials: { token: "google_token", expires_at: 1.hour.from_now.to_i },
      )
  end
end

# `actor_current_resource` is the bridge from the installed Actor snapshot to the controller's own
# resource. Every guard in it is a boundary: the actor_type check keeps an operator's snapshot from
# resolving on a client surface, the `is_a?(resource_class)` check keeps a resolved subject of the
# wrong class from being returned as this surface's resource, and the actor_id check refuses a
# snapshot whose claimed id disagrees with the subject it carries. None of the guards had a test,
# so a snapshot from another surface would have been returned without one failing.
class AuthenticationBaseActorCurrentResourceTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  ClientResource = Struct.new(:id)
  OperatorResource = Struct.new(:id)

  setup do
    @controller = harness_class.new
    Actor.clear
  end

  teardown { Actor.clear }

  test "a signed-in client snapshot of the right type and class resolves" do
    install(actor_type: :client, actor_id: 7, subject: ClientResource.new(7))

    assert_equal 7, @controller.actor_current_resource.id
  end

  test "an unauthenticated snapshot resolves nothing" do
    Actor.clear

    assert_nil @controller.actor_current_resource
  end

  test "a snapshot for another actor type does not resolve on this surface" do
    install(actor_type: :operator, actor_id: 7, subject: OperatorResource.new(7))

    assert_nil @controller.actor_current_resource
  end

  test "the unauthenticated singleton is never returned as a resource" do
    install(actor_type: :client, actor_id: 7, subject: Unauthenticated.instance)

    assert_nil @controller.actor_current_resource
  end

  test "a blank subject resolves nothing" do
    install(actor_type: :client, actor_id: 7, subject: nil)

    assert_nil @controller.actor_current_resource
  end

  test "a subject of the wrong class does not resolve as this surface's resource" do
    install(actor_type: :client, actor_id: 7, subject: OperatorResource.new(7))

    assert_nil @controller.actor_current_resource
  end

  test "a snapshot whose claimed actor id disagrees with its subject is refused" do
    install(actor_type: :client, actor_id: 9, subject: ClientResource.new(7))

    assert_nil @controller.actor_current_resource
  end

  # A snapshot that carries no actor_id at all is accepted: the id is optional metadata, and the
  # subject it carries has already been resolved by the pipeline that installed it.
  test "a snapshot with no claimed actor id still resolves its subject" do
    install(actor_type: :client, actor_id: nil, subject: ClientResource.new(7))

    assert_equal 7, @controller.actor_current_resource.id
  end

  private

  def harness_class
    @harness_class ||=
      Class.new(AuthenticationBaseTestController) do
        def self.name = "AuthenticationBaseActorResourceHarness"

        def resource_type = "client"

        def resource_class = AuthenticationBaseActorCurrentResourceTest::ClientResource
      end
  end

  def install(actor_type:, actor_id:, subject:)
    Actor.authn = Actor::Authentication.new(
      login_public_id: "login-public-id",
      actor_type: actor_type,
      actor_id: actor_id,
    )
    Actor.subject = subject
  end
end
