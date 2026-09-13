# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class OidcCallbackTestController < ApplicationController
  class << self
    # rubocop:disable ThreadSafety/ClassAndModuleAttributes
    attr_accessor :login_result_for_test, :last_login_kwargs, :last_session_limit_gate_pt, :hard_reject_payload
    # rubocop:enable ThreadSafety/ClassAndModuleAttributes
  end

  def self.declare_authentication_mode!(*)
  end

  include OidcCallback

  def seed
    session[:oidc_code_verifier] = params[:code_verifier] if params.key?(:code_verifier)
    session[:oidc_state] = params[:state] if params.key?(:state)
    session[:oidc_nonce] = params[:nonce] if params.key?(:nonce)
    session[:oidc_pt] = params[:pt] if params.key?(:pt)
    if params[:pending_state].present?
      session["oidc_pending_flows"] ||= {}
      session["oidc_pending_flows"][params[:pending_state]] = {
        "code_verifier" => params[:pending_code_verifier],
        "nonce" => params[:pending_nonce],
        "pt" => params[:pending_pt],
        "created_at" => params.fetch(:pending_created_at, Time.current.to_i),
      }
    end

    head :no_content
  end

  def snapshot
    render json: {
      oidc_code_verifier: session[:oidc_code_verifier],
      oidc_state: session[:oidc_state],
      oidc_nonce: session[:oidc_nonce],
      oidc_pt: session[:oidc_pt],
      oidc_pending_flows: session["oidc_pending_flows"],
    }
  end

  def oidc_client_id
    "base-rails-rp"
  end

  def oidc_client_secret
    OidcClientRegistry.find!("base-rails-rp").client_secret
  end

  def oidc_token_url
    host = Rails.configuration.x.boot_config.fetch(:hosts).base_service.host
    "http://#{host}:3000/oauth/token"
  end

  def oidc_callback_url
    OidcClientRegistry.find!("base-rails-rp").redirect_uris.first
  end

  def oidc_resource_type
    "client"
  end

  def sign_in_url_with_pt(_return_to)
    "https://#{Rails.configuration.x.boot_config.fetch(:hosts).sign_service.host}/sign/in"
  end

  def sign_app_sign_in_session_path
    "/sign/in/session"
  end

  def provision_rp_account_from_id_token_payload!(payload, _canonical_audience)
    claim_payload = payload.respond_to?(:payload) ? payload.payload : payload
    Struct.new(:id).new(claim_payload.fetch("sub"))
  end

  def log_in(resource, **kwargs)
    @logged_in_resource = resource
    @login_kwargs = kwargs
    self.class.last_login_kwargs = kwargs
    self.class.last_session_limit_gate_pt = send(:session_limit_gate_pt)
    self.class.login_result_for_test || { status: :success }
  end

  def render_session_limit_hard_reject(message: nil, http_status: nil)
    self.class.hard_reject_payload = { message: message, http_status: http_status }
    render plain: message, status: http_status
  end
end

class OidcCallbackTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  setup do
    OidcCallbackTestController.login_result_for_test = nil
    OidcCallbackTestController.last_login_kwargs = nil
    OidcCallbackTestController.last_session_limit_gate_pt = nil
    OidcCallbackTestController.hard_reject_payload = nil

    Rails.application.routes.draw do
      get "/oidc/callback/session" => "oidc_callback_test#seed"
      get "/oidc/callback/snapshot" => "oidc_callback_test#snapshot"
      get "/oidc/callback" => "oidc_callback_test#show"
    end
  end

  teardown do
    Rails.application.reload_routes!
  end

  Result = Struct.new(:success?, :token_response, :error, :error_description, keyword_init: true)

  test "show redirects to pt on successful exchange" do
    get "/oidc/callback/session",
        params: { code_verifier: "verifier", state: "state", nonce: "nonce", pt: "/after" }

    result = Result.new(
      success?: true,
      token_response: { access_token: "access", refresh_token: "refresh", id_token: "id-token" },
      error: nil,
      error_description: nil,
    )
    id_token_result = Struct.new(:success?, :payload, :error, keyword_init: true).new(
      success?: true,
      payload: { "sub" => "42", "nonce" => "nonce" },
      error: nil,
    )

    OidcRpTokenClient.stub(:call, result) do
      OidcIdTokenVerifier.stub(:call, id_token_result) do
        get "/oidc/callback", params: { code: "abc", state: "state" }
      end
    end

    assert_response :redirect
    assert_redirected_to "/after"
    assert_not OidcCallbackTestController.last_login_kwargs.fetch(:bootstrap_actor, false)
    assert OidcCallbackTestController.last_login_kwargs.fetch(:skip_login_cooldown)
  end

  test "show consumes the matching pending flow instead of the latest legacy flow" do
    get "/oidc/callback/session",
        params: {
          code_verifier: "newer-verifier",
          state: "newer-state",
          nonce: "newer-nonce",
          pt: "/",
          pending_state: "older-state",
          pending_code_verifier: "older-verifier",
          pending_nonce: "older-nonce",
          pending_pt: "/settings?ri=jp",
        }

    result = Result.new(
      success?: true,
      token_response: { access_token: "access", refresh_token: "refresh", id_token: "id-token" },
      error: nil,
      error_description: nil,
    )
    id_token_result = Struct.new(:success?, :payload, :error, keyword_init: true).new(
      success?: true,
      payload: { "sub" => "42", "nonce" => "older-nonce" },
      error: nil,
    )
    token_call = nil

    OidcRpTokenClient.stub(:call, ->(**kwargs) { token_call = kwargs; result }) do
      OidcIdTokenVerifier.stub(:call, id_token_result) do
        get "/oidc/callback", params: { code: "abc", state: "older-state" }
      end
    end

    assert_response :redirect
    assert_redirected_to "/settings?ri=jp"
    assert_equal "older-verifier", token_call.fetch(:code_verifier)
    assert_not token_call.fetch(:require_https)
  end

  test "show rejects expired pending state before token exchange and preserves other pending flows" do
    get "/oidc/callback/session",
        params: {
          pending_state: "expired-state",
          pending_code_verifier: "expired-verifier",
          pending_nonce: "expired-nonce",
          pending_pt: "/expired",
          pending_created_at: 11.minutes.ago.to_i,
        }
    get "/oidc/callback/session",
        params: {
          pending_state: "valid-state",
          pending_code_verifier: "valid-verifier",
          pending_nonce: "valid-nonce",
          pending_pt: "/valid",
          pending_created_at: 1.minute.ago.to_i,
        }

    OidcRpTokenClient.stub(:call, ->(**) { flunk("token exchange should not run for expired state") }) do
      get "/oidc/callback", params: { code: "abc", state: "expired-state" }
    end

    assert_response :unprocessable_content

    get "/oidc/callback/snapshot"
    snapshot = response.parsed_body

    assert_nil snapshot["oidc_code_verifier"]
    assert_nil snapshot["oidc_state"]
    assert_nil snapshot["oidc_nonce"]
    assert_nil snapshot["oidc_pt"]
    assert_includes snapshot.fetch("oidc_pending_flows").keys, "valid-state"
    assert_not_includes snapshot.fetch("oidc_pending_flows").keys, "expired-state"
  end

  test "show deletes consumed pending state without disturbing other pending flows" do
    get "/oidc/callback/session",
        params: {
          pending_state: "consumed-state",
          pending_code_verifier: "consumed-verifier",
          pending_nonce: "consumed-nonce",
          pending_pt: "/consumed",
          pending_created_at: 1.minute.ago.to_i,
        }
    get "/oidc/callback/session",
        params: {
          pending_state: "other-state",
          pending_code_verifier: "other-verifier",
          pending_nonce: "other-nonce",
          pending_pt: "/other",
          pending_created_at: 1.minute.ago.to_i,
        }

    result = Result.new(
      success?: true,
      token_response: { access_token: "access", refresh_token: "refresh", id_token: "id-token" },
      error: nil,
      error_description: nil,
    )
    id_token_result = Struct.new(:success?, :payload, :error, keyword_init: true).new(
      success?: true,
      payload: { "sub" => "42", "nonce" => "consumed-nonce" },
      error: nil,
    )

    OidcRpTokenClient.stub(:call, result) do
      OidcIdTokenVerifier.stub(:call, id_token_result) do
        get "/oidc/callback", params: { code: "abc", state: "consumed-state" }
      end
    end

    assert_response :redirect

    get "/oidc/callback/snapshot"
    snapshot = response.parsed_body

    assert_nil snapshot["oidc_code_verifier"]
    assert_nil snapshot["oidc_state"]
    assert_nil snapshot["oidc_nonce"]
    assert_nil snapshot["oidc_pt"]
    assert_includes snapshot.fetch("oidc_pending_flows").keys, "other-state"
    assert_not_includes snapshot.fetch("oidc_pending_flows").keys, "consumed-state"
  end

  test "show deletes pending flow session key after consuming the last pending flow" do
    get "/oidc/callback/session",
        params: {
          pending_state: "consumed-state",
          pending_code_verifier: "consumed-verifier",
          pending_nonce: "consumed-nonce",
          pending_pt: "/consumed",
          pending_created_at: 1.minute.ago.to_i,
        }

    result = Result.new(
      success?: true,
      token_response: { access_token: "access", refresh_token: "refresh", id_token: "id-token" },
      error: nil,
      error_description: nil,
    )
    id_token_result = Struct.new(:success?, :payload, :error, keyword_init: true).new(
      success?: true,
      payload: { "sub" => "42", "nonce" => "consumed-nonce" },
      error: nil,
    )

    OidcRpTokenClient.stub(:call, result) do
      OidcIdTokenVerifier.stub(:call, id_token_result) do
        get "/oidc/callback", params: { code: "abc", state: "consumed-state" }
      end
    end

    assert_response :redirect

    get "/oidc/callback/snapshot"
    snapshot = response.parsed_body

    assert_nil snapshot["oidc_pending_flows"]
  end

  test "show deletes pending flow session key after the last pending flow expires" do
    get "/oidc/callback/session",
        params: {
          pending_state: "expired-state",
          pending_code_verifier: "expired-verifier",
          pending_nonce: "expired-nonce",
          pending_pt: "/expired",
          pending_created_at: 11.minutes.ago.to_i,
        }

    OidcRpTokenClient.stub(:call, ->(**) { flunk("token exchange should not run for expired state") }) do
      get "/oidc/callback", params: { code: "abc", state: "expired-state" }
    end

    assert_response :unprocessable_content

    get "/oidc/callback/snapshot"
    snapshot = response.parsed_body

    assert_nil snapshot["oidc_pending_flows"]
  end

  test "show redirects to sign in on failed exchange" do
    get "/oidc/callback/session", params: { code_verifier: "verifier", state: "state" }

    result = Result.new(
      success?: false,
      token_response: nil,
      error: "bad",
      error_description: "bad",
    )
    logged = []

    OidcRpTokenClient.stub(:call, result) do
      Rails.logger.stub(
        :info, ->(message = nil, &block) {
                 message = block.call if message.nil? && block
                 logged << JSON.parse(message, symbolize_names: true) if message.to_s.start_with?("{")
               },
      ) do
        get "/oidc/callback", params: { code: "abc", state: "state" }
      end
    end

    assert_response :redirect
    assert_redirected_to "https://#{configured_host(:sign_service)}/sign/in"
    assert_equal 1, logged.count { |entry| entry[:event] == "oidc.rp.callback.failed" }
  end

  test "show redirects session-limit pending callbacks to session management without restarting oidc" do
    get "/oidc/callback/session",
        params: { code_verifier: "verifier", state: "state", nonce: "nonce", pt: "/settings?ri=jp" }

    result = Result.new(
      success?: true,
      token_response: { access_token: "access", refresh_token: "refresh", id_token: "id-token" },
      error: nil,
      error_description: nil,
    )
    id_token_result = Struct.new(:success?, :payload, :error, keyword_init: true).new(
      success?: true,
      payload: { "sub" => "42", "nonce" => "nonce" },
      error: nil,
    )
    OidcCallbackTestController.login_result_for_test = {
      status: :success,
      session_management_required: true,
    }

    OidcRpTokenClient.stub(:call, result) do
      OidcIdTokenVerifier.stub(:call, id_token_result) do
        get "/oidc/callback", params: { code: "abc", state: "state" }
      end
    end

    assert_response :redirect
    assert_redirected_to "/sign/in/session"
    assert_equal "/settings?ri=jp", OidcCallbackTestController.last_session_limit_gate_pt
    assert OidcCallbackTestController.last_login_kwargs.fetch(:skip_login_cooldown)
    assert_not OidcCallbackTestController.last_login_kwargs.fetch(:bootstrap_actor, false)
  end

  test "show renders hard reject instead of restarting oidc when restricted session already exists" do
    get "/oidc/callback/session", params: { code_verifier: "verifier", state: "state", nonce: "nonce" }

    result = Result.new(
      success?: true,
      token_response: { access_token: "access", refresh_token: "refresh", id_token: "id-token" },
      error: nil,
      error_description: nil,
    )
    id_token_result = Struct.new(:success?, :payload, :error, keyword_init: true).new(
      success?: true,
      payload: { "sub" => "42", "nonce" => "nonce" },
      error: nil,
    )
    OidcCallbackTestController.login_result_for_test = {
      status: :session_limit_hard_reject,
      message: "too many sessions",
      http_status: :forbidden,
    }

    OidcRpTokenClient.stub(:call, result) do
      OidcIdTokenVerifier.stub(:call, id_token_result) do
        get "/oidc/callback", params: { code: "abc", state: "state" }
      end
    end

    assert_response :forbidden
    assert_equal "too many sessions", response.body
    assert_equal(
      { message: "too many sessions", http_status: :forbidden },
      OidcCallbackTestController.hard_reject_payload,
    )
  end

  test "show rejects mismatched state before token exchange" do
    get "/oidc/callback/session",
        params: {
          state: "expected",
          pending_state: "pending-state",
          pending_code_verifier: "pending-verifier",
          pending_nonce: "pending-nonce",
          pending_pt: "/pending",
        }
    logged = []

    OidcRpTokenClient.stub(:call, ->(**) { flunk("token exchange should not run for state mismatch") }) do
      Rails.logger.stub(
        :info, ->(message = nil, &block) {
                 message = block.call if message.nil? && block
                 logged << JSON.parse(message, symbolize_names: true) if message.to_s.start_with?("{")
               },
      ) do
        get "/oidc/callback", params: { code: "abc", state: "wrong" }
      end
    end

    assert_response :unprocessable_content
    event = logged.find { |entry| entry[:event] == "oidc.rp.callback.invalid_state" }

    assert_equal "OIDC state mismatch", event.dig(:data, :reason)
    assert event.dig(:data, :grant_present)
    assert event.dig(:data, :csrf_present)
    assert event.dig(:data, :expected_state_present)
    assert event.dig(:data, :actual_state_present)
    assert_predicate event.dig(:data, :expected_state_digest12), :present?
    assert_predicate event.dig(:data, :actual_state_digest12), :present?
    assert_not_equal "state", event.dig(:data, :expected_state_digest12)
    assert_not_equal "wrong", event.dig(:data, :actual_state_digest12)

    get "/oidc/callback/snapshot"
    snapshot = response.parsed_body

    assert_nil snapshot["oidc_pending_flows"]
  end

  test "show raises unexpected provisioning errors" do
    get "/oidc/callback/session",
        params: { code_verifier: "verifier", state: "state", nonce: "nonce" }

    result = Result.new(
      success?: true,
      token_response: { access_token: "access", refresh_token: "refresh", id_token: "id-token" },
      error: nil,
      error_description: nil,
    )
    id_token_result = Struct.new(:success?, :payload, :error, keyword_init: true).new(
      success?: true,
      payload: { "nonce" => "nonce" },
      error: nil,
    )

    OidcRpTokenClient.stub(:call, result) do
      OidcIdTokenVerifier.stub(:call, id_token_result) do
        assert_raises(KeyError) do
          get "/oidc/callback", params: { code: "abc", state: "state" }
        end
      end
    end
  end

  test "default provision_rp_account_from_id_token_payload! raises NotImplementedError" do
    dummy_class =
      Class.new(ApplicationController) do
        def self.declare_authentication_mode!(*)
        end

        include OidcCallback
      end

    assert_raises(NotImplementedError) do
      dummy_class.new.send(:provision_rp_account_from_id_token_payload!, {}, "aud")
    end
  end

  # The legacy single-flow session keys are only cleared when the callback that
  # arrived is the one they belong to; a callback for some other state must leave
  # another tab's in-flight flow alone.
  test "clear_legacy_oidc_flow_if_current! only clears the flow it matches" do
    dummy_class =
      Class.new(ApplicationController) do
        def self.declare_authentication_mode!(*)
        end

        include OidcCallback

        attr_writer :fake_session

        def session = @fake_session
      end

    controller = dummy_class.new
    controller.fake_session = {
      oidc_state: "state-a", oidc_code_verifier: "verifier", oidc_nonce: "nonce", oidc_pt: "/after",
    }

    controller.send(:clear_legacy_oidc_flow_if_current!, "state-b")

    assert_equal "state-a", controller.session[:oidc_state]

    controller.send(:clear_legacy_oidc_flow_if_current!, "state-a")

    assert_empty controller.session
  end

  # The RP logout sid is written onto the session row so a later back-channel logout
  # can find it. A non-UUID sid, a session that cannot take column writes, or a token
  # row with neither column must all leave the row alone.
  test "bind_oidc_rp_logout_session! writes the sid only onto a session row that can take it" do
    dummy_class =
      Class.new(ApplicationController) do
        def self.declare_authentication_mode!(*)
        end

        include OidcCallback

        attr_writer :session_record

        def oidc_client_id = "test-client"

        def token_record_connection_owner(_klass) = ActiveRecord::Base
      end

    controller = dummy_class.new
    writable = Class.new do
      attr_reader :updated

      def has_attribute?(name) = %i(oidc_sid oidc_client_id).include?(name.to_sym)

      def respond_to_missing?(name, include_private = false)
        name.to_sym == :update_columns || super
      end

      def update_columns(*) = nil

      def update!(**attributes) = @updated = attributes
    end.new
    controller.instance_variable_set(:@current_session, writable)

    controller.send(:bind_oidc_rp_logout_session!, { "sid" => "not-a-uuid" })

    assert_nil writable.updated

    sid = SecureRandom.uuid
    controller.send(:bind_oidc_rp_logout_session!, { "sid" => sid })

    assert_equal({ oidc_sid: sid, oidc_client_id: "test-client" }, writable.updated)

    controller.instance_variable_set(:@current_session, nil)

    assert_nil controller.send(:bind_oidc_rp_logout_session!, { "sid" => SecureRandom.uuid })
  end

  test "default oidc_client_id raises NotImplementedError" do
    # create a dummy controller without overriding
    dummy_class =
      Class.new(ApplicationController) do
        def self.declare_authentication_mode!(*)
        end

        include OidcCallback
      end

    assert_raises(NotImplementedError) do
      dummy_class.new.send(:oidc_client_id)
    end
  end

  test "oidc_client_secret_credential uses ClientRegistry" do
    dummy_class =
      Class.new(ApplicationController) do
        def self.declare_authentication_mode!(*)
        end

        include OidcCallback

        define_method(:oidc_client_id) do
          "test-client"
        end
      end

    client_mock = Struct.new(:client_secret).new("mock_secret_credential")

    OidcClientRegistry.stub(:find, client_mock) do
      assert_equal "mock_secret_credential", dummy_class.new.send(:oidc_client_secret)
    end
  end
end

# DAMP local helper copy for former shared test support.
class OidcCallbackTestController
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
class OidcCallbackTestController
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
class OidcCallbackTest
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
