# typed: false
# frozen_string_literal: true

require "test_helper"

# The final session issuance boundary (AuthenticationBase#log_in) is shared by app, com, and org.
# Each surface is exercised through its real Base application controller so the surface's own token
# table, limit, and cookies are used (adr/root-login-establishment-boundary.md).
class AuthSessionIssuanceBoundarySurfacesTest < ActiveSupport::TestCase
  SURFACES = {
    app: {
      controller: Base::App::ApplicationController,
      host: "PUBLIC_BASE_SERVICE_URL",
      token_class: ClientToken,
      foreign_key: :user_id,
      limit: ClientToken::MAX_SESSIONS_PER_USER,
      flow_class: ClientSignInFlow,
      resource: -> { Client.create!(status_id: ClientStatus::NOTHING, birthdate: "2000-01-01") },
    },
    com: {
      controller: Base::Com::ApplicationController,
      host: "PUBLIC_BASE_CORPORATE_URL",
      token_class: VisitorToken,
      foreign_key: :visitor_id,
      limit: VisitorToken::MAX_SESSIONS_PER_VISITOR,
      flow_class: VisitorSignInFlow,
      resource: -> { Visitor.create!(status_id: VisitorStatus::NOTHING, visibility_id: VisitorVisibility::VISITOR) },
    },
    org: {
      controller: Base::Org::ApplicationController,
      host: "PUBLIC_BASE_STAFF_URL",
      token_class: OperatorToken,
      foreign_key: :staff_id,
      limit: OperatorToken::MAX_SESSIONS_PER_STAFF,
      flow_class: OperatorSignInFlow,
      resource: -> { Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF) },
    },
  }.freeze

  SURFACES.each do |surface, config|
    test "#{surface}: one below the limit commits one ACTIVE root session with cookies and context" do
      resource = config[:resource].call
      fill_sessions(config, resource, config[:limit] - 1)
      controller = build_controller(config)

      result = nil
      assert_difference(-> { tokens(config, resource).count }, 1) do
        result = controller.log_in(resource, establishment: :root_login)
      end

      assert_equal :success, result.fetch(:status)
      issued = tokens(config, resource).order(:id).last

      assert_predicate issued, :active_status?
      assert_not_nil issued.root_login_established_at
      assert_not_nil issued.device_session_id
      assert_equal resource, controller.current_resource
      assert_predicate controller.request.cookie_jar[AuthenticationBase::ACCESS_COOKIE_KEY].to_s, :present?
    end

    test "#{surface}: at the limit nothing is issued, no cookie is set, and the existing context is kept" do
      resource = config[:resource].call
      existing = fill_sessions(config, resource, config[:limit])
      controller = build_controller(config)
      controller.session[:unrelated_marker] = "kept"

      result = nil
      assert_no_difference(-> { config[:token_class].count }) do
        result = controller.log_in(resource, establishment: :root_login)
      end

      assert_equal :session_limit_pending, result.fetch(:status)
      assert_nil controller.request.cookie_jar[AuthenticationBase::ACCESS_COOKIE_KEY]
      assert_nil controller.request.cookie_jar[AuthenticationBase::REFRESH_COOKIE_KEY]
      assert_equal "kept", controller.session[:unrelated_marker]
      assert(existing.all? { |token| token.reload.active_status? })
      assert_equal 0, config[:token_class].where(config[:foreign_key] => resource.id)
        .where(config[:token_class].token_status_foreign_key => config[:token_class].token_status_model::RESTRICTED)
        .count
    end

    test "#{surface}: a flow that already carries a session is refused at the final boundary" do
      resource = config[:resource].call
      prior = fill_sessions(config, resource, 1).first
      flow = issuance_pending_flow(config, resource, token: prior)

      result = nil
      assert_no_difference(-> { config[:token_class].count }) do
        result = build_controller(config).log_in(resource, establishment: :root_login, sign_in_flow: flow)
      end

      assert_equal :invalid_request, result.fetch(:status)
    end

    test "#{surface}: a flow bound to a different actor is refused at the final boundary" do
      resource = config[:resource].call
      other = config[:resource].call
      flow = issuance_pending_flow(config, other)

      result = nil
      assert_no_difference(-> { config[:token_class].count }) do
        result = build_controller(config).log_in(resource, establishment: :root_login, sign_in_flow: flow)
      end

      assert_equal :invalid_request, result.fetch(:status)
      assert_nil flow.reload.token_id
    end

    test "#{surface}: an issuance-pending flow is completed in the same commit and bound to the session" do
      resource = config[:resource].call
      flow = issuance_pending_flow(config, resource)

      result = build_controller(config).log_in(resource, establishment: :root_login, sign_in_flow: flow)

      assert_equal :success, result.fetch(:status)
      flow.reload

      assert_predicate flow, :sign_in_completed?
      assert_equal tokens(config, resource).order(:id).last.id, flow.token_id
    end

    test "#{surface}: a database failure while creating the device session rolls the token back" do
      resource = config[:resource].call
      controller = build_controller(config)

      controller.stub(:ensure_device_session_for!, ->(*) { raise ActiveRecord::StatementInvalid, "injected" }) do
        assert_no_difference(-> { config[:token_class].count }) do
          assert_raises(ActiveRecord::StatementInvalid) { controller.log_in(resource, establishment: :root_login) }
        end
      end

      assert_nil controller.request.cookie_jar[AuthenticationBase::ACCESS_COOKIE_KEY]
    end

    test "#{surface}: an unknown establishment is refused before any check" do
      resource = config[:resource].call

      assert_raises(ArgumentError) { build_controller(config).log_in(resource, establishment: :bootstrap) }
      assert_raises(ArgumentError) { build_controller(config).log_in(resource, establishment: nil) }
    end
  end

  private

  def tokens(config, resource)
    config[:token_class].where(config[:foreign_key] => resource.id)
  end

  def fill_sessions(config, resource, count)
    Array.new(count) { config[:token_class].create!(config[:foreign_key] => resource.id) }
  end

  def issuance_pending_flow(config, resource, token: nil)
    flow_class = config[:flow_class]
    flow_class.create!(
      principal_id: resource.id,
      token_id: token&.id,
      status_id: flow_class.status_id_for("SESSION_ISSUANCE_PENDING"),
      state: "SESSION_ISSUANCE_PENDING",
      step: "session_issuance",
      nonce_digest: flow_class.digest_nonce(SecureRandom.hex(8)),
    )
  end

  def build_controller(config)
    request = ActionDispatch::TestRequest.create
    request.host = ENV.fetch(config[:host])
    request.session = ActionController::TestSession.new
    controller_class = config[:controller]
    controller = controller_class.new
    controller.set_request!(request)
    controller.set_response!(controller_class.make_response!(request))
    controller
  end
end
