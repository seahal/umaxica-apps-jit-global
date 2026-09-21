# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class AuthInSessionCancellationsControllerTest < ActiveSupport::TestCase
  test "app cancellation fails pending DB cycle and clears legacy state before token issuance" do
    actor = Client.create!(public_id: "u_#{SecureRandom.hex(6)}", status_id: ClientStatus::ACTIVE)
    cycle = create_session_limit_cycle(ClientSignInFlow, actor)

    assert_cancels_pending_cycle(
      Auth::App::Sign::In::Session::CancellationsController.new,
      actor: actor,
      cycle: cycle,
      pending_key: :pending_login_user_id,
      sign_in_path: "/sign/in?ri=jp",
    )
  end

  test "com cancellation fails pending DB cycle and clears legacy state before token issuance" do
    actor = Visitor.create!(public_id: "v_#{SecureRandom.hex(6)}", status_id: VisitorStatus::ACTIVE)
    cycle = create_session_limit_cycle(VisitorSignInFlow, actor)

    assert_cancels_pending_cycle(
      Auth::Com::Sign::In::Session::CancellationsController.new,
      actor: actor,
      cycle: cycle,
      pending_key: :pending_login_visitor_id,
      sign_in_path: "/sign/in?ri=jp",
    )
  end

  test "org cancellation fails pending DB cycle and clears legacy state before token issuance" do
    actor = Operator.create!(status_id: OperatorStatus::ACTIVE)
    cycle = create_session_limit_cycle(OperatorSignInFlow, actor)

    assert_cancels_pending_cycle(
      Auth::Org::Sign::In::Session::CancellationsController.new,
      actor: actor,
      cycle: cycle,
      pending_key: :pending_login_staff_id,
      sign_in_path: "/sign/in?ri=jp",
    )
  end

  test "app cancellation with pending OIDC login_challenge includes it in redirect path" do
    actor = Client.create!(public_id: "u_#{SecureRandom.hex(6)}", status_id: ClientStatus::ACTIVE)
    cycle = create_session_limit_cycle(ClientSignInFlow, actor)
    challenge = "test_login_challenge_abc"

    session_hash = {
      :pending_login_user_id => actor.id,
      SessionLimitGate::GATE_SESSION_KEY => {
        "nonce" => "legacy",
        "issued_at" => Time.current.to_i,
        "pt" => "/dashboard",
        "flow" => "in.session",
      },
    }
    redirects = []
    controller = Auth::App::Sign::In::Session::CancellationsController.new
    controller.define_singleton_method(:session) { session_hash }
    controller.define_singleton_method(:params) { ActionController::Parameters.new(ri: "jp") }
    controller.define_singleton_method(:current_resource) { nil }
    controller.define_singleton_method(:current_session) { nil }
    controller.define_singleton_method(:current_db_sign_in_flow_for_sequence) { cycle.reload }
    controller.define_singleton_method(:consume_session_limit_gate!) { session.delete(SessionLimitGate::GATE_SESSION_KEY) }
    controller.define_singleton_method(:log_out) { nil }
    controller.define_singleton_method(:redirect_to) { |path| redirects << path }
    controller.define_singleton_method(:resolve_session_limit_cancellation_actor) { actor }
    controller.define_singleton_method(:oidc_authorization_login_challenge) { challenge }
    controller.define_singleton_method(:url_options) { { host: "auth.app.localhost" } }

    controller.create

    assert_includes redirects.first, "login_challenge=#{challenge}"
    assert_includes redirects.first, "ri=jp"
  end

  test "org cancellation with pending OIDC login_challenge includes it in redirect path" do
    actor = Operator.create!(status_id: OperatorStatus::ACTIVE)
    cycle = create_session_limit_cycle(OperatorSignInFlow, actor)
    challenge = "org_login_challenge_abc"

    session_hash = {
      :pending_login_staff_id => actor.id,
      SessionLimitGate::GATE_SESSION_KEY => {
        "nonce" => "legacy",
        "issued_at" => Time.current.to_i,
        "pt" => "/dashboard",
        "flow" => "in.session",
      },
    }
    redirects = []
    controller = Auth::Org::Sign::In::Session::CancellationsController.new
    controller.define_singleton_method(:session) { session_hash }
    controller.define_singleton_method(:params) { ActionController::Parameters.new(ri: "jp") }
    controller.define_singleton_method(:current_region_identifier) { "jp" }
    controller.define_singleton_method(:current_resource) { nil }
    controller.define_singleton_method(:current_session) { nil }
    controller.define_singleton_method(:current_db_sign_in_flow_for_sequence) { cycle.reload }
    controller.define_singleton_method(:consume_session_limit_gate!) { session.delete(SessionLimitGate::GATE_SESSION_KEY) }
    controller.define_singleton_method(:log_out) { nil }
    controller.define_singleton_method(:redirect_to) { |path| redirects << path }
    controller.define_singleton_method(:resolve_session_limit_cancellation_actor) { actor }
    controller.define_singleton_method(:oidc_authorization_login_challenge) { challenge }
    controller.define_singleton_method(:url_options) {
      { host: ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost") }
    }

    controller.create

    assert_includes redirects.first, "login_challenge=#{challenge}"
    assert_includes redirects.first, "ri=jp"
  end

  test "org cancellation without pending OIDC login_challenge redirects to plain sign-in path" do
    actor = Operator.create!(status_id: OperatorStatus::ACTIVE)
    cycle = create_session_limit_cycle(OperatorSignInFlow, actor)

    session_hash = {
      :pending_login_staff_id => actor.id,
      SessionLimitGate::GATE_SESSION_KEY => {
        "nonce" => "legacy",
        "issued_at" => Time.current.to_i,
        "pt" => "/dashboard",
        "flow" => "in.session",
      },
    }
    redirects = []
    controller = Auth::Org::Sign::In::Session::CancellationsController.new
    controller.define_singleton_method(:session) { session_hash }
    controller.define_singleton_method(:params) { ActionController::Parameters.new(ri: "jp") }
    controller.define_singleton_method(:current_region_identifier) { "jp" }
    controller.define_singleton_method(:current_resource) { nil }
    controller.define_singleton_method(:current_session) { nil }
    controller.define_singleton_method(:current_db_sign_in_flow_for_sequence) { cycle.reload }
    controller.define_singleton_method(:consume_session_limit_gate!) { session.delete(SessionLimitGate::GATE_SESSION_KEY) }
    controller.define_singleton_method(:log_out) { nil }
    controller.define_singleton_method(:redirect_to) { |path| redirects << path }
    controller.define_singleton_method(:resolve_session_limit_cancellation_actor) { actor }
    controller.define_singleton_method(:url_options) {
      { host: ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost") }
    }

    controller.create

    assert_equal 1, redirects.size
    assert_includes redirects.first, "ri=jp"
    assert_not_includes redirects.first, "login_challenge="
  end

  test "app cancellation without pending OIDC login_challenge redirects to plain sign-in path" do
    actor = Client.create!(public_id: "u_#{SecureRandom.hex(6)}", status_id: ClientStatus::ACTIVE)
    cycle = create_session_limit_cycle(ClientSignInFlow, actor)

    session_hash = {
      :pending_login_user_id => actor.id,
      SessionLimitGate::GATE_SESSION_KEY => {
        "nonce" => "legacy",
        "issued_at" => Time.current.to_i,
        "pt" => "/dashboard",
        "flow" => "in.session",
      },
    }
    redirects = []
    controller = Auth::App::Sign::In::Session::CancellationsController.new
    controller.define_singleton_method(:session) { session_hash }
    controller.define_singleton_method(:params) { ActionController::Parameters.new(ri: "jp") }
    controller.define_singleton_method(:current_resource) { nil }
    controller.define_singleton_method(:current_session) { nil }
    controller.define_singleton_method(:current_db_sign_in_flow_for_sequence) { cycle.reload }
    controller.define_singleton_method(:consume_session_limit_gate!) { session.delete(SessionLimitGate::GATE_SESSION_KEY) }
    controller.define_singleton_method(:log_out) { nil }
    controller.define_singleton_method(:redirect_to) { |path| redirects << path }
    controller.define_singleton_method(:resolve_session_limit_cancellation_actor) { actor }
    controller.define_singleton_method(:url_options) { { host: "auth.app.localhost" } }

    controller.create

    assert_equal ["/sign/in?ri=jp"], redirects
  end

  test "cancellation with mismatched bound token does not mutate the DB cycle or token" do
    actor = Client.create!(public_id: "u_#{SecureRandom.hex(6)}", status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(
      user: actor,
      user_token_status_id: ClientTokenStatus::RESTRICTED,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
    )
    token.rotate_refresh_token!
    cycle = create_session_limit_cycle(ClientSignInFlow, actor)
    cycle.update!(token: token)

    session_hash = {
      :pending_login_user_id => actor.id,
      SessionLimitGate::GATE_SESSION_KEY => {
        "nonce" => "legacy",
        "issued_at" => Time.current.to_i,
        "pt" => "/dashboard",
        "flow" => "in.session",
      },
    }
    redirects = []
    controller = Auth::App::Sign::In::Session::CancellationsController.new
    controller.define_singleton_method(:session) { session_hash }
    controller.define_singleton_method(:params) { ActionController::Parameters.new(ri: "jp") }
    controller.define_singleton_method(:current_resource) { nil }
    controller.define_singleton_method(:current_session) { nil }
    controller.define_singleton_method(:current_db_sign_in_flow_for_sequence) { cycle.reload }
    controller.define_singleton_method(:redirect_to) { |path| redirects << path }
    controller.define_singleton_method(:session_limit_sign_in_path) { "/sign/in?ri=jp" }
    controller.define_singleton_method(:resolve_session_limit_cancellation_actor) { actor }

    controller.create

    assert_predicate cycle.reload, :sign_in_session_limit_pending?
    assert_predicate token.reload, :restricted?
    assert_predicate token, :currently_usable?
    assert session_hash[SessionLimitGate::GATE_SESSION_KEY]
    assert_equal actor.id, session_hash[:pending_login_user_id]
    assert_equal ["/sign/in?ri=jp"], redirects
  end

  private

  def assert_cancels_pending_cycle(controller, actor:, cycle:, pending_key:, sign_in_path:)
    session_hash = {
      pending_key => actor.id,
      SessionLimitGate::GATE_SESSION_KEY => {
        "nonce" => "legacy",
        "issued_at" => Time.current.to_i,
        "pt" => "/dashboard",
        "flow" => "in.session",
      },
    }
    redirects = []
    logged_out = false

    controller.define_singleton_method(:session) { session_hash }
    controller.define_singleton_method(:params) { ActionController::Parameters.new(ri: "jp") }
    controller.define_singleton_method(:current_resource) { nil }
    controller.define_singleton_method(:current_session) { nil }
    controller.define_singleton_method(:current_db_sign_in_flow_for_sequence) { cycle.reload }
    controller.define_singleton_method(:consume_session_limit_gate!) { session.delete(SessionLimitGate::GATE_SESSION_KEY) }
    controller.define_singleton_method(:log_out) { logged_out = true }
    controller.define_singleton_method(:redirect_to) { |path| redirects << path }
    controller.define_singleton_method(:session_limit_sign_in_path) { sign_in_path }
    controller.define_singleton_method(:resolve_session_limit_cancellation_actor) { actor }

    controller.create

    assert_predicate cycle.reload, :sign_in_failed?
    assert_nil session_hash[SessionLimitGate::GATE_SESSION_KEY]
    assert_nil session_hash[pending_key]
    assert logged_out
    assert_equal [sign_in_path], redirects
  end

  def create_session_limit_cycle(cycle_class, actor)
    cycle_class.create!(
      principal_id: actor.id,
      status_id: cycle_class.status_id_for("SESSION_LIMIT_PENDING"),
      state: "SESSION_LIMIT_PENDING",
      step: "session_limit",
      return_to: "/dashboard",
      nonce_digest: cycle_class.digest_nonce("unused"),
      issued_at: Time.current,
      expires_at: 15.minutes.from_now,
    )
  end
end
