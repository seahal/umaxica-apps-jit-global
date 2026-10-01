# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class AuthenticationBaseExtraCoverageTest < ActiveSupport::TestCase
  class FakeRequest
    attr_accessor :headers, :format, :host, :original_url, :remote_ip, :user_agent, :request_id, :fullpath,
                  :request_method

    def get?
      request_method == "GET"
    end

    def filtered_parameters
      {}
    end

    def parameters
      {}
    end

    def optional_port
      nil
    end

    def protocol
      "http://"
    end

    def path_parameters
      {}
    end

    def script_name
      ""
    end

    def routes
      Rails.application.routes
    end
  end

  class Harness < ApplicationController
    include AuthenticationBase

    attr_accessor :session_hash, :request_obj, :rendered, :redirected, :marked_as_read

    def initialize
      super
      @session_hash = {}
      @headers = {}
      @request_obj = FakeRequest.new
      @request_obj.headers = @headers
      @request_obj.format = Struct.new(:json?).new(false)
      @request_obj.host = "localhost"
      @request_obj.original_url = "http://localhost"
      @request_obj.remote_ip = "127.0.0.1"
      @request_obj.user_agent = "TestAgent"
      @request_obj.request_id = "req-1"
      @request_obj.fullpath = "/test"
      @request_obj.request_method = "GET"
      @response_obj = Struct.new(:headers).new({})
    end

    def t(key)
      "translated:#{key}"
    end

    def epoch_seconds(time)
      time.to_i
    end

    def bulletin_association_for_resource
      return nil unless current_resource

      obj = Object.new

      def obj.unread
        @unread ||= Struct.new(:oldest_first).new(
          Struct.new(:first).new(
            Struct.new(:id, :mark_as_read!).new(1, true),
          ),
        )
      end

      def obj.find_by(id:)
        Struct.new(:id, :mark_as_read!).new(id, true)
      end

      obj
    end

    def session
      @session_hash
    end

    def request
      @request_obj
    end

    def render(args)
      @rendered = args
    end

    def redirect_to(path, options = {})
      @redirected = [path, options]
    end

    # Abstract methods implementation
    def resource_class
      Client
    end

    def token_class
      ClientToken
    end

    def audit_class
      ClientChronicle
    end

    def resource_type
      "user"
    end

    def resource_foreign_key
      :user_id
    end

    def sign_in_url_with_pt(pt)
      "/sign_in?pt=#{pt}"
    end

    def current_region_identifier
      params[:ri].to_s
    end

    def am_i_user?
      true
    end

    def am_i_staff?
      false
    end

    def am_i_owner?
      false
    end

    def current_resource
      @current_resource
    end

    def current_resource=(res)
      @current_resource = res
    end

    private

    def jump_rt_issuer_namespace
      "BASE_APP"
    end
  end

  setup do
    @harness = Harness.new
  end

  test "bulletin_active? and bulletin_expired?" do
    @harness.session[AuthenticationBase::BULLETIN_SESSION_KEY] = {
      "issued_at" => Time.current.to_i,
      "bulletin_id" => 1,
    }

    assert_predicate @harness, :bulletin_active?
    assert_not @harness.bulletin_expired?

    @harness.session[AuthenticationBase::BULLETIN_SESSION_KEY]["issued_at"] = 3.hours.ago.to_i

    assert_predicate @harness, :bulletin_expired?
  end

  test "issue_bulletin! sets session" do
    @harness.current_resource = Client.new

    assert @harness.issue_bulletin!(kind: "welcome")
    assert_equal "welcome", @harness.session[AuthenticationBase::BULLETIN_SESSION_KEY]["kind"]
  end

  test "refresh_bulletin_dimension! updates issued_at" do
    @harness.session[AuthenticationBase::BULLETIN_SESSION_KEY] = { "issued_at" => 1.hour.ago.to_i }
    @harness.refresh_bulletin_dimension!(state: "refreshed")

    assert_operator @harness.session[AuthenticationBase::BULLETIN_SESSION_KEY]["issued_at"], :>, 1.minute.ago.to_i
    assert_equal "refreshed", @harness.session[AuthenticationBase::BULLETIN_SESSION_KEY]["state"]
  end

  test "consume_bulletin! clears session" do
    @harness.session[AuthenticationBase::BULLETIN_SESSION_KEY] = { "bulletin_id" => 1 }
    @harness.current_resource = Client.new
    @harness.consume_bulletin!

    assert_nil @harness.session[AuthenticationBase::BULLETIN_SESSION_KEY]
  end

  test "session_limit_hard_reject_result returns forbidden payload" do
    resource = Client.new(id: 123)

    result = @harness.send(:session_limit_hard_reject_result, resource)

    assert_equal :session_limit_hard_reject, result[:status]
    assert_equal :forbidden, result[:http_status]
    assert_equal AuthenticationBase::SESSION_LIMIT_HARD_REJECT_MESSAGE, result[:message]
  end

  test "validate_login_dpop_proof returns success when proof is blank" do
    @harness.request.headers["DPoP"] = nil

    assert_equal({ status: :success, jkt: nil }, @harness.send(:validate_login_dpop_proof))
  end

  test "validate_login_dpop_proof returns error for invalid proof" do
    Object.new
    result = Struct.new(:valid?, :error, :jkt).new(false, "bad-proof", nil)
    validator = Struct.new(:call).new(result)
    @harness.request.headers["DPoP"] = "proof"
    @harness.request.request_method = "POST"
    @harness.request.original_url = "http://localhost/test"

    DpopProofVerifier.stub(:new, ->(**) { validator }) do
      assert_equal({ status: :dpop_proof_invalid, error: "bad-proof" }, @harness.send(:validate_login_dpop_proof))
    end
  end

  test "redirect_to_pt_or_default! jumps to pt" do
    token = @harness.send(:issue_authentication_path_target_token, "/target")

    @harness.redirect_to_pt_or_default!(token, default_path: "/default")

    assert_equal ["/target", { allow_other_host: false }], @harness.redirected
  end

  test "current_session_public_id returns extracted session id and memoizes it" do
    calls = 0
    @harness.define_singleton_method(:extract_access_token) do |_cookie_key|
      calls += 1
      "access-token"
    end
    @harness.request.host = "localhost"

    AuthenticationToken.stub(
      :extract_session_id_allow_expired,
      ->(token, host:, resource_type:, issuer: nil, audiences: nil, jwt_issuer_id: nil) {
        assert_equal "access-token", token
        assert_equal "localhost", host
        assert_equal "user", resource_type
        assert_nil issuer
        assert_nil audiences
        assert_equal "surface:AUTH_APP", jwt_issuer_id
        "session-public-id"
      },
    ) do
      assert_equal "session-public-id", @harness.current_session_public_id
      assert_equal "session-public-id", @harness.current_session_public_id
    end

    assert_equal 1, calls
  end

  test "current_session_public_id returns nil when access token is missing" do
    @harness.define_singleton_method(:extract_access_token) do |_cookie_key|
      nil
    end

    assert_nil @harness.current_session_public_id
  end

  test "current_session_public_id uses Actor authn first" do
    authn = Struct.new(:login_public_id).new("actor-session-id")

    Actor.stub(:authn, authn) do
      assert_equal "actor-session-id", @harness.current_session_public_id
    end
  end

  test "authenticate! redirects for html" do
    @harness.authenticate!

    uri = URI.parse(@harness.redirected.first)
    query = Rack::Utils.parse_nested_query(uri.query)

    assert_equal "/sign_in", uri.path
    assert_equal "", query["pt"]
  end

  test "authenticate! renders for json" do
    req = @harness.request
    req.define_singleton_method(:format) do
      Struct.new(:json?).new(true)
    end
    @harness.authenticate!

    assert_equal :unauthorized, @harness.rendered[:status]
  end

  test "authenticate! short-circuits when already logged in" do
    @harness.current_resource = Client.new

    SignRiskEnforcer.stub(:call, nil) do
      @harness.authenticate!
    end

    assert_nil @harness.rendered
    assert_nil @harness.redirected
  end

  test "log_out clears session and cookies" do
    @harness.current_resource = Client.new
    @harness.define_singleton_method(:current_session) do
      Struct.new(:public_id).new("session-public-id")
    end
    @harness.define_singleton_method(:current_session_public_id) do
      "session-public-id"
    end
    # Mock clear_auth_cookies! and destroy_refresh_token_from_cookie
    @harness.define_singleton_method(:clear_auth_cookies!) do
      nil
    end

    @harness.define_singleton_method(:destroy_refresh_token_from_cookie) do
      nil
    end

    @harness.define_singleton_method(:reset_session) do
      @session_hash.clear
    end
    @harness.session["user_id"] = 1
    @harness.log_out

    # Nothing of the signed-out principal survives; the only entry is the instruction for the
    # next page on this origin to clear the encrypted Inertia history.
    assert_equal({ inertia_clear_history: true }, @harness.session.to_h.symbolize_keys)
  end

  test "login_cooldown reads the configured window" do
    with_login_cooldown(45.seconds) do
      assert_equal 45.seconds, AuthenticationBase.login_cooldown
    end
  end
end
