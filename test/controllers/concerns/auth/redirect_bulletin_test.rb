# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class AuthRedirectBulletinTest < ActiveSupport::TestCase
  class RedirectHarness
    include AuthenticationBase

    attr_accessor :session_data, :params_data, :request_obj, :performed

    def initialize
      @session_data = {}
      @params_data = {}
      @request_obj = MockRequest.new
      @performed = false
    end

    def session
      @session_data
    end

    def params
      @params_data
    end

    def request
      @request_obj
    end

    def performed?
      @performed
    end

    def redirect_to(*_args)
      @performed = true
    end

    def render(*_args)
      @performed = true
    end

    def resource_type
      "user"
    end

    def resource_class
      Client
    end

    def token_class
      ClientToken
    end

    def audit_class
      ClientChronicle
    end

    def resource_foreign_key
      :user_id
    end

    def sign_in_url_with_pt(_return_to)
      "/sign/in"
    end

    def current_region_identifier
      params[:ri].to_s
    end

    def am_i_user?
      false
    end

    def am_i_staff?
      false
    end

    def am_i_owner?
      false
    end
  end

  class MockRequest
    attr_accessor :host, :host_with_port, :remote_ip, :user_agent, :request_id, :fullpath

    def initialize
      @host = "example.com"
      @host_with_port = "example.com"
      @remote_ip = "127.0.0.1"
      @user_agent = "TestAgent"
      @request_id = "test-123"
      @fullpath = "/test"
    end

    def format
      MockFormat.new
    end

    def headers
      {}
    end
  end

  class MockFormat
    def json?
      false
    end

    def html?
      true
    end
  end

  setup do
    @harness = RedirectHarness.new
  end

  test "DEFAULT_PT_SESSION_KEY is defined" do
    assert_includes AuthenticationBase::DEFAULT_PT_SESSION_KEY.to_s, "pt"
  end

  test "BULLETIN_SESSION_KEY is defined" do
    assert_equal :sign_in_checkpoint, AuthenticationBase::BULLETIN_SESSION_KEY
  end

  test "BULLETIN_TIMEOUT is 2 hours" do
    assert_equal 2.hours, AuthenticationBase::BULLETIN_TIMEOUT
  end

  test "preserve_pt stores pt in session" do
    @harness.params_data[AuthIoKeys::Params::PT] = @harness.signed_pt_token("/dashboard")
    result = @harness.preserve_pt

    assert_match(/--/, result)
    assert_equal result, @harness.session[AuthenticationBase::DEFAULT_PT_SESSION_KEY]
  end

  test "preserve_pt rejects unsigned pt param" do
    @harness.params_data[AuthIoKeys::Params::PT] = "/dashboard"
    result = @harness.preserve_pt

    assert_nil result
    assert_nil @harness.session[AuthenticationBase::DEFAULT_PT_SESSION_KEY]
  end

  test "preserve_pt returns nil when no pt param" do
    result = @harness.preserve_pt

    assert_nil result
    assert_nil @harness.session[AuthenticationBase::DEFAULT_PT_SESSION_KEY]
  end

  test "retrieve_pt returns and clears session value" do
    @harness.session[AuthenticationBase::DEFAULT_PT_SESSION_KEY] = @harness.signed_pt_token("/dashboard")
    result = @harness.retrieve_pt

    assert_match(/--/, result)
    assert_nil @harness.session[AuthenticationBase::DEFAULT_PT_SESSION_KEY]
    assert_not_includes @harness.session.keys, AuthenticationBase::DEFAULT_PT_SESSION_KEY
  end

  test "retrieve_pt falls back to params" do
    @harness.params_data[AuthIoKeys::Params::PT] = @harness.signed_pt_token("/dashboard")
    result = @harness.retrieve_pt

    assert_match(/--/, result)
  end

  test "peek_pt returns without clearing" do
    @harness.session[AuthenticationBase::DEFAULT_PT_SESSION_KEY] = @harness.signed_pt_token("/dashboard")
    result = @harness.peek_pt

    assert_match(/--/, result)
    assert_equal result, @harness.session[AuthenticationBase::DEFAULT_PT_SESSION_KEY]
  end

  test "build_redirect_params includes pt when present" do
    @harness.session[AuthenticationBase::DEFAULT_PT_SESSION_KEY] = @harness.signed_pt_token("/dashboard")
    result = @harness.build_redirect_params(:notice, "Success")

    assert_equal "Success", result[:notice]
    assert_match(/--/, result[AuthIoKeys::Params::PT])
  end

  test "build_notice_params creates notice hash" do
    result = @harness.build_notice_params("Success")

    assert_equal "Success", result[:notice]
  end

  test "build_alert_params creates alert hash" do
    result = @harness.build_alert_params("Warning")

    assert_equal "Warning", result[:alert]
  end

  test "Auth controllers resolve welcome URLs on their Base surface" do
    expectations = {
      Auth::App::ApplicationController => ["PUBLIC_BASE_SERVICE_URL", "www.umaxica.app"],
      Auth::Com::ApplicationController => ["PUBLIC_BASE_CORPORATE_URL", "www.umaxica.com"],
      Auth::Org::ApplicationController => ["PUBLIC_BASE_STAFF_URL", "www.umaxica.org"],
    }

    expectations.each do |controller_class, (environment_key, expected_host)|
      controller = controller_class.new
      controller.set_request!(ActionController::TestRequest.create(controller_class))
      controller.define_singleton_method(:current_region_identifier) { "jp" }
      controller.define_singleton_method(:params) { {} }

      original_fetch = ENV.method(:fetch)

      ENV.stub(
        :fetch, ->(key, *args, &block) {
          (key == environment_key) ? expected_host : original_fetch.call(key, *args, &block)
        },
      ) do
        assert_equal "https://#{expected_host}/welcome?ri=jp", controller.sign_in_welcome_path
      end
    end
  end

  test "issue_bulletin! sets bulletin in session when unread bulletin exists" do
    mock_bulletin = Minitest::Mock.new
    mock_bulletin.expect(:id, 42)

    freeze_time do
      @harness.stub(:find_unread_bulletin, mock_bulletin) do
        result = @harness.issue_bulletin!(kind: "mfa", state: "pending")

        assert result
        bulletin = @harness.session[AuthenticationBase::BULLETIN_SESSION_KEY]

        assert_equal "mfa", bulletin["kind"]
        assert_equal "pending", bulletin["state"]
        assert_equal Time.current.to_i, bulletin["issued_at"]
        assert_equal 42, bulletin["bulletin_id"]
      end
    end
  end

  test "issue_bulletin! returns false when no unread bulletin" do
    @harness.stub(:find_unread_bulletin, nil) do
      result = @harness.issue_bulletin!(kind: "mfa", state: "pending")

      assert_not result
      assert_nil @harness.session[AuthenticationBase::BULLETIN_SESSION_KEY]
    end
  end

  test "bulletin_state returns nil when no bulletin" do
    assert_nil @harness.bulletin_state
  end

  test "bulletin_state returns hash with indifferent access" do
    @harness.session[AuthenticationBase::BULLETIN_SESSION_KEY] = { "kind" => "mfa", "state" => "pending" }
    result = @harness.bulletin_state

    assert_equal "mfa", result[:kind]
    assert_equal "pending", result[:state]
  end

  test "bulletin_active? returns false when no bulletin" do
    assert_not @harness.bulletin_active?
  end

  test "bulletin_expired? returns true for old bulletin" do
    old_time = 3.hours.ago.to_i
    @harness.session[AuthenticationBase::BULLETIN_SESSION_KEY] = {
      "issued_at" => old_time,
      "kind" => "mfa",
      "state" => "pending",
    }

    assert_predicate @harness, :bulletin_expired?
  end

  test "consume_bulletin! removes bulletin from session" do
    @harness.session[AuthenticationBase::BULLETIN_SESSION_KEY] = { "kind" => "mfa" }
    @harness.consume_bulletin!

    assert_nil @harness.session[AuthenticationBase::BULLETIN_SESSION_KEY]
  end

  test "refresh_bulletin_dimension! updates issued_at and state" do
    old_time = 1.hour.ago.to_i
    @harness.session[AuthenticationBase::BULLETIN_SESSION_KEY] = {
      "issued_at" => old_time,
      "kind" => "mfa",
      "state" => "pending",
    }

    travel_to(1.second.from_now)
    @harness.refresh_bulletin_dimension!(state: "updated")
    bulletin = @harness.session[AuthenticationBase::BULLETIN_SESSION_KEY]

    assert_operator bulletin["issued_at"], :>, old_time
    assert_equal "updated", bulletin["state"]
  end
end
