# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Auth::App::Sign::In::GuardsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_tokens

  setup do
    @host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
    @user = clients(:one)
    ClientSignInFlowStatus.ensure_defaults!
  end

  test "route resolves to guard controller" do
    route = Rails.application.routes.recognize_path("https://#{@host}/sign/in/guard", method: :get)

    assert_equal "auth/app/sign/in/guards", route.fetch(:controller)
    assert_equal "show", route.fetch(:action)
  end

  test "missing cycle redirects to sign in entry without flash" do
    get auth_app_sign_in_guard_url(ri: "jp"), headers: host_headers(@host)

    assert_redirected_to auth_app_sign_in_url(ri: "jp")
    assert_empty flash.to_hash
  end

  test "guard state redirects to check without mutating durable rows or cycle state" do
    cycle = create_cycle(status: "GUARDRAIL_PENDING")
    before_attrs = guarded_cycle_attrs(cycle.reload)
    controller = build_controller(cycle: cycle, actor: @user)

    assert_no_sign_in_guard_durable_changes do
      controller.show
    end

    assert_equal "/sign/in/check?ri=jp", controller.redirected_to
    assert_equal before_attrs, guarded_cycle_attrs(cycle.reload)
  end

  test "blocked guard state returns generic forbidden without mutating cycle" do
    blocked_user = Client.create!(status_id: ClientStatus::RESERVED, public_id: "blocked_#{SecureRandom.hex(4)}")
    cycle = create_cycle(actor: blocked_user, status: "GUARDRAIL_PENDING")
    before_attrs = guarded_cycle_attrs(cycle.reload)
    controller = build_controller(cycle: cycle, actor: blocked_user)

    assert_no_sign_in_guard_durable_changes do
      controller.show
    end

    assert_equal({ plain: I18n.t("errors.messages.not_authorized"), status: :forbidden }, controller.rendered)
    assert_equal before_attrs, guarded_cycle_attrs(cycle.reload)
  end

  test "checkpoint state redirects to check" do
    cycle = create_cycle(status: "CHECKPOINT_PENDING")
    before_attrs = guarded_cycle_attrs(cycle.reload)
    controller = build_controller(cycle: cycle, actor: @user)

    controller.show

    assert_equal "/sign/in/check?ri=jp", controller.redirected_to
    assert_equal before_attrs, guarded_cycle_attrs(cycle.reload)
  end

  test "session limit state redirects to session" do
    cycle = create_cycle(status: "SESSION_LIMIT_PENDING")
    before_attrs = guarded_cycle_attrs(cycle.reload)
    controller = build_controller(cycle: cycle, actor: @user)

    controller.show

    assert_equal "/sign/in/session?ri=jp", controller.redirected_to
    assert_equal before_attrs, guarded_cycle_attrs(cycle.reload)
  end

  test "selector state redirects to selector sequence path" do
    cycle = create_cycle(status: "SELECTOR_PENDING", return_to: "/dashboard")
    controller = build_controller(cycle: cycle, actor: @user)

    controller.show

    assert_equal "/sign/in/selector?pt=/dashboard", controller.redirected_to
  end

  test "later state redirects to welcome sequence path" do
    cycle = create_cycle(status: "DASHBOARD_PENDING", return_to: "/dashboard")
    controller = build_controller(cycle: cycle, actor: @user)

    controller.show

    assert_equal "/sign/in/welcome?pt=/dashboard", controller.redirected_to
  end

  test "unsafe path target redirects to sign in entry without flash" do
    cycle = create_cycle(status: "CHECKPOINT_PENDING")
    controller = build_controller(cycle: cycle, actor: @user, path_target: "/account", signed_pt: nil)

    controller.show

    assert_equal "/sign/in?ri=jp", controller.redirected_to
    assert_equal "CHECKPOINT_PENDING", cycle.reload.state
  end

  test "unsafe return target redirects to sign in entry without flash" do
    cycle = create_cycle(status: "CHECKPOINT_PENDING", return_to: "https://evil.example.test")
    controller = build_controller(cycle: cycle, actor: @user, signed_token: nil)

    controller.show

    assert_equal "/sign/in?ri=jp", controller.redirected_to
    assert_equal "CHECKPOINT_PENDING", cycle.reload.state
  end

  test "expired cycle redirects to sign in entry without flash" do
    controller = build_controller(cycle: nil, actor: nil)
    controller.show

    assert_equal "/sign/in?ri=jp", controller.redirected_to
  end

  test "surface mismatch redirects to sign in entry without flash" do
    controller = build_controller(cycle: nil, actor: @user)
    controller.show

    assert_equal "/sign/in?ri=jp", controller.redirected_to
  end

  private

  def create_cycle(actor: @user, status:, issued_at: Time.current, expires_at: 15.minutes.from_now, return_to: nil)
    ClientSignInFlow.create!(
      principal_id: actor.id,
      status_id: ClientSignInFlow.status_id_for(status),
      state: status,
      step: step_for(status),
      nonce_digest: ClientSignInFlow.digest_nonce("pending-test-nonce"),
      issued_at: issued_at,
      expires_at: expires_at,
      return_to: return_to,
    )
  end

  def build_controller(cycle:, actor:, path_target: nil, signed_pt: nil, signed_token: "signed-pt")
    controller = Auth::App::Sign::In::GuardsController.new
    controller.define_singleton_method(:params) { ActionController::Parameters.new(ri: "jp") }
    controller.define_singleton_method(:path_target_value) { path_target }
    controller.define_singleton_method(:signed_pt_param) { signed_pt }
    controller.define_singleton_method(:signed_pt_token) { |path| path.presence && signed_token }
    controller.define_singleton_method(:path_from_signed_pt) { |_| path_target }
    controller.define_singleton_method(:current_db_sign_in_flow_for_sequence) { cycle }
    controller.define_singleton_method(:sign_in_flow_actor) { |_| actor }
    controller.define_singleton_method(:auth_app_sign_in_path) { |ri: nil| "/sign/in?ri=#{ri}" }
    controller.define_singleton_method(:auth_app_sign_in_check_path) { |ri: nil, pt: nil|
      "/sign/in/check?ri=#{ri}#{pt ? "&pt=#{pt}" : ""}"
    }
    controller.define_singleton_method(:auth_app_sign_in_session_path) { |ri: nil, pt: nil|
      "/sign/in/session?ri=#{ri}#{pt ? "&pt=#{pt}" : ""}"
    }
    controller.define_singleton_method(:sign_in_selector_path) { |pt: nil| "/sign/in/selector?pt=#{pt}" }
    controller.define_singleton_method(:sign_in_welcome_path) { |pt: nil| "/sign/in/welcome?pt=#{pt}" }
    controller.define_singleton_method(:redirect_to) { |path, **_options| @redirected_to = path }
    controller.define_singleton_method(:render) { |**options| @rendered = options }
    controller.define_singleton_method(:redirected_to) { @redirected_to }
    controller.define_singleton_method(:rendered) { @rendered }
    controller
  end

  def step_for(status)
    ClientSignInFlow::STEP_BY_STATUS_ID.fetch(ClientSignInFlow.status_id_for(status))
  end

  def guarded_cycle_attrs(cycle)
    cycle.attributes.slice("status_id", "state", "step", "token_id", "completed_at", "session_issued_at")
  end

  def assert_no_sign_in_guard_durable_changes(&)
    assert_no_difference("Client.count") do
      assert_no_difference("ClientGoogleIdentity.count") do
        assert_no_difference("ClientAppleIdentity.count") do
          assert_no_difference("ClientAccount.count") do
            assert_no_difference("OperatorOrganization.count") do
              assert_no_difference("Avatar.count") do
                assert_no_difference("ClientToken.count") do
                  assert_no_difference("ClientSignUpFlow.count", &)
                end
              end
            end
          end
        end
      end
    end
  end
  private

  def host_headers(host = nil)
    host_value = host || (respond_to?(:request, true) ? request&.host : nil) || ENV["DEFAULT_URL_HOST"]
    headers = {
      "Client-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
                        "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    }
    headers["Host"] = host_value if host_value.present?
    headers
  end

  def browser_headers
    csrf_token = "test_csrf_token"
    headers = {
      "Client-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
                        "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
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

    if user.respond_to?(:persisted?) && user.persisted? && user.class.name == "Client"
      token =
        if session_public_id.present?
          ClientToken.find_by(public_id: session_public_id)
        else
          ClientToken.where(user_id: user.id).where("discarded_at > ?", Time.current).order(created_at: :desc).first
        end
      token ||= ClientToken.create!(user_id: user.id, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
      base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    end

    if token
      base.merge(
        "Authorization" => "Bearer #{
        jwt_access_token_for(user, host: host, session_public_id: token.public_id, resource_type: "client")
      }",
      )
    else
      base
    end
  end

  def as_staff_headers(staff, host: nil, headers: {}, session_public_id: nil)
    base = host_headers(host).merge(headers).merge("X-TEST-CURRENT-STAFF" => staff.id.to_s)

    if staff.respond_to?(:persisted?) && staff.persisted? && staff.class.name == "Operator"
      token =
        if session_public_id.present?
          OperatorToken.find_by(public_id: session_public_id)
        else
          OperatorToken.where(staff_id: staff.id).where(
            "discarded_at > ?",
            Time.current,
          ).order(created_at: :desc).first
        end
      token ||= OperatorToken.create!(staff: staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
      base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    end

    if token
      base.merge(
        "Authorization" => "Bearer #{
        jwt_access_token_for(staff, host: host, session_public_id: token.public_id, resource_type: "operator")
      }",
      )
    else
      base
    end
  end

  def as_visitor_headers(visitor, host: nil, headers: {}, session_public_id: nil)
    VisitorTokenBindingMethod.ensure_defaults! if defined?(VisitorTokenBindingMethod)
    VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::BROWSER_WEB) if defined?(VisitorTokenKind)
    base = host_headers(host).merge(headers).merge("X-TEST-CURRENT-RESOURCE" => visitor.id.to_s)

    if visitor.respond_to?(:persisted?) && visitor.persisted? && visitor.class.name == "Visitor"
      token =
        if session_public_id.present?
          VisitorToken.find_by(public_id: session_public_id)
        else
          VisitorToken.where(visitor_id: visitor.id).where(
            "discarded_at > ?",
            Time.current,
          ).order(created_at: :desc).first
        end
      token ||= VisitorToken.create!(visitor_id: visitor.id, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
      base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    end

    if token
      base.merge(
        "Authorization" => "Bearer #{
        jwt_access_token_for(visitor, host: host, session_public_id: token.public_id, resource_type: "visitor")
      }",
      )
    else
      base
    end
  end

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end
end

# DAMP auth header helpers for this test class.
class Auth::App::Sign::In::GuardsControllerTest
  private

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
end
