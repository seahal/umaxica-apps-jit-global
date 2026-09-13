# typed: false
# frozen_string_literal: true

require "test_helper"

# Self-service session management on the app and com browser surfaces:
# listing sessions, revoking one selected session, and revoking every other session.
#
# The org surface runs the same controllers with an operator actor. It is
# covered at the service level in
# `test/services/authentication_other_sessions_revoker_test.rb` instead,
# because org HTML requests without an OIDC RP browser session are answered
# by the SSO initiator before any controller under test runs.
class IdentitySessionRevocationTest < ActionDispatch::IntegrationTest
  fixtures :clients

  setup do
    ensure_token_reference_records!

    @app_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    @com_host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost")
  end

  test "every surface recognizes a token as current through its device session identifier" do
    token = Struct.new(:id, :public_id, :device_session_id).new(41, "token-session", 7)
    current_token = Struct.new(:id, :public_id, :device_session_id).new(42, "rotated-token", 7)

    [
      Base::App::Identity::SessionsController,
      Base::Com::Identity::SessionsController,
      Base::Org::Identity::SessionsController,
    ].each do |controller_class|
      controller = controller_class.new
      controller.stub(:current_session, current_token) do
        controller.stub(:current_session_public_id, "device-session") do
          current = controller.send(:current_session_record?, token)

          assert_predicate current, :itself, controller_class.name
        end
      end
    end
  end

  test "self-service routes cannot revoke every session" do
    {
      @app_host => "/identity/sessions",
      @com_host => "/identity/sessions",
      ENV.fetch("PUBLIC_BASE_STAFF_URL") => "/identity/sessions",
    }.each do |host, path|
      assert_raises(ActionController::RoutingError, host) do
        Rails.application.routes.recognize_path("https://#{host}#{path}", method: :delete)
      end
    end
  end

  # --- app surface -------------------------------------------------------

  test "app session index renders the revoke controls when other sessions exist" do
    host! @app_host
    setup_app_actor!

    get base_app_identity_sessions_url(ri: "jp", host: @app_host), headers: @app_headers

    assert_response :success
    assert_match "/identity/other_sessions", response.body
    assert_match @other_token.public_id, response.body
  end

  test "app revoke selected session revokes only that session" do
    host! @app_host
    setup_app_actor!

    delete base_app_identity_session_url(@other_token.public_id, ri: "jp", host: @app_host), headers: @app_headers

    assert_response :see_other
    assert_not_predicate @other_token.reload, :currently_usable?
    assert_predicate @current_token.reload, :currently_usable?
  end

  test "app revoke selected session refuses to revoke the current session" do
    host! @app_host
    setup_app_actor!

    delete base_app_identity_session_url(@current_token.public_id, ri: "jp", host: @app_host), headers: @app_headers

    assert_response :see_other
    assert_predicate @current_token.reload, :currently_usable?
  end

  test "app revoke other sessions keeps the current session" do
    host! @app_host
    setup_app_actor!

    delete base_app_identity_other_sessions_url(ri: "jp", host: @app_host), headers: @app_headers

    assert_response :see_other
    assert_not_predicate @other_token.reload, :currently_usable?
    assert_predicate @current_token.reload, :currently_usable?
  end

  # --- com surface -------------------------------------------------------

  test "com session index renders the revoke controls when other sessions exist" do
    host! @com_host
    setup_com_actor!

    get base_com_identity_sessions_url(ri: "jp", host: @com_host), headers: @com_headers

    assert_response :success
    assert_match "/identity/other_sessions", response.body
    assert_match @other_token.public_id, response.body
  end

  test "com revoke other sessions keeps the current session" do
    host! @com_host
    setup_com_actor!

    delete base_com_identity_other_sessions_url(ri: "jp", host: @com_host), headers: @com_headers

    assert_response :see_other
    assert_not_predicate @other_token.reload, :currently_usable?
    assert_predicate @current_token.reload, :currently_usable?
  end

  private

  def setup_app_actor!
    @actor = clients(:one)
    @current_token = create_client_token
    @other_token = create_client_token
    @app_headers = bearer_session_headers(@actor, @current_token, host: @app_host, resource_type: "client")
  end

  # Reference rows the token/actor records depend on. Kept local and minimal:
  # only the ids this test actually writes.
  def ensure_token_reference_records!
    ClientTokenKind.find_or_create_by!(id: ClientTokenKind::BROWSER_WEB)
    ClientTokenStatus.find_or_create_by!(id: ClientTokenStatus::NOTHING)
    VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::BROWSER_WEB)
    VisitorTokenStatus.find_or_create_by!(id: VisitorTokenStatus::NOTHING)
    VisitorTokenBindingMethod.ensure_defaults!
    VisitorTokenDbscStatus.find_or_create_by!(id: VisitorTokenDbscStatus::NOTHING)
  end

  def setup_com_actor!
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorMfaLevel.find_or_create_by!(id: VisitorMfaLevel::NOTHING)
    VisitorMfaStatus.find_or_create_by!(id: VisitorMfaStatus::UNCONFIGURED)
    @actor = Visitor.create!(
      status_id: VisitorStatus::NOTHING,
      visibility_id: VisitorVisibility::VISITOR,
      mfa_level_id: VisitorMfaLevel::NOTHING,
      mfa_status_id: VisitorMfaStatus::UNCONFIGURED,
    )
    @current_token = create_visitor_token
    @other_token = create_visitor_token
    @com_headers = bearer_session_headers(@actor, @current_token, host: @com_host, resource_type: "visitor")
  end

  def bearer_session_headers(actor, token, host:, resource_type:)
    bearer_headers(
      jwt_access_token_for(actor, host: host, session_public_id: token.public_id, resource_type: resource_type),
      host: host,
    ).merge("X-TEST-SESSION-PUBLIC-ID" => token.public_id)
  end

  def create_client_token
    token = ClientToken.create!(
      user: @actor,
      user_token_status_id: ClientTokenStatus::NOTHING,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      public_id: "revoke_#{SecureRandom.hex(4)}",
      discarded_at: 1.day.from_now,
    )
    token.update!(created_at: 1.hour.ago)
    token
  end

  def create_visitor_token
    token = VisitorToken.create!(
      visitor: @actor,
      visitor_token_status_id: VisitorTokenStatus::NOTHING,
      visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      public_id: "revoke_#{SecureRandom.hex(4)}",
      discarded_at: 1.day.from_now,
    )
    token.update!(created_at: 1.hour.ago)
    token
  end
end
