# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Auth::Org::Sign::In::GuardsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators

  setup do
    @host = ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost")
    @operator = operators(:one)
    OperatorSignInFlowStatus.ensure_defaults!
  end

  test "route resolves to guard controller" do
    route = Rails.application.routes.recognize_path("https://#{@host}/sign/in/guard", method: :get)

    assert_equal "auth/org/sign/in/guards", route.fetch(:controller)
    assert_equal "show", route.fetch(:action)
  end

  test "guard state redirects to check without mutating durable rows or cycle state" do
    cycle = create_cycle(status: "GUARDRAIL_PENDING")
    before_attrs = guarded_cycle_attrs(cycle.reload)
    controller = build_controller(cycle: cycle)

    assert_no_sign_in_guard_durable_changes do
      controller.show
    end

    assert_equal "/sign/in/check?ri=jp", controller.redirected_to
    assert_equal before_attrs, guarded_cycle_attrs(cycle.reload)
  end

  test "checkpoint state redirects to check" do
    cycle = create_cycle(status: "CHECKPOINT_PENDING")
    before_attrs = guarded_cycle_attrs(cycle.reload)
    controller = build_controller(cycle: cycle)

    controller.show

    assert_equal "/sign/in/check?ri=jp", controller.redirected_to
    assert_equal before_attrs, guarded_cycle_attrs(cycle.reload)
  end

  test "session limit state redirects to session" do
    cycle = create_cycle(status: "SESSION_LIMIT_PENDING")
    before_attrs = guarded_cycle_attrs(cycle.reload)
    controller = build_controller(cycle: cycle)

    controller.show

    assert_equal "/sign/in/session?ri=jp", controller.redirected_to
    assert_equal before_attrs, guarded_cycle_attrs(cycle.reload)
  end

  test "selector state redirects to selector sequence path" do
    cycle = create_cycle(status: "SELECTOR_PENDING", return_to: "/dashboard")
    controller = build_controller(cycle: cycle)

    controller.show

    assert_equal "/sign/in/selector?pt=/dashboard", controller.redirected_to
  end

  test "later state redirects to welcome sequence path" do
    cycle = create_cycle(status: "DASHBOARD_PENDING", return_to: "/dashboard")
    controller = build_controller(cycle: cycle)

    controller.show

    assert_equal "/sign/in/welcome?pt=/dashboard", controller.redirected_to
  end

  test "unsafe path target redirects to sign in entry without flash" do
    cycle = create_cycle(status: "CHECKPOINT_PENDING")
    controller = build_controller(cycle: cycle, path_target: "/account", signed_pt: nil)

    controller.show

    assert_equal "/sign/in?ri=jp", controller.redirected_to
    assert_equal "CHECKPOINT_PENDING", cycle.reload.state
  end

  test "unsafe return target redirects to sign in entry without flash" do
    cycle = create_cycle(status: "CHECKPOINT_PENDING", return_to: "https://evil.example.test")
    controller = build_controller(cycle: cycle, signed_token: nil)

    controller.show

    assert_equal "/sign/in?ri=jp", controller.redirected_to
    assert_equal "CHECKPOINT_PENDING", cycle.reload.state
  end

  test "missing or expired cycle redirects to sign in entry without flash" do
    get auth_org_sign_in_guard_url(ri: "jp"), headers: host_headers(@host)

    assert_redirected_to auth_org_sign_in_url(ri: "jp")
    assert_empty flash.to_hash
  end

  private

  def create_cycle(status:, issued_at: Time.current, expires_at: 15.minutes.from_now, return_to: nil)
    OperatorSignInFlow.create!(
      principal_id: @operator.id,
      status_id: OperatorSignInFlow.status_id_for(status),
      state: status,
      step: step_for(status),
      nonce_digest: OperatorSignInFlow.digest_nonce("pending-test-nonce"),
      issued_at: issued_at,
      expires_at: expires_at,
      return_to: return_to,
    )
  end

  def build_controller(cycle:, path_target: nil, signed_pt: nil, signed_token: "signed-pt")
    controller = Auth::Org::Sign::In::GuardsController.new
    controller.define_singleton_method(:params) { ActionController::Parameters.new(ri: "jp") }
    controller.define_singleton_method(:path_target_value) { path_target }
    controller.define_singleton_method(:signed_pt_param) { signed_pt }
    controller.define_singleton_method(:signed_pt_token) { |path| path.presence && signed_token }
    controller.define_singleton_method(:path_from_signed_pt) { |_| path_target }
    controller.define_singleton_method(:current_db_sign_in_flow_for_sequence) { cycle }
    controller.define_singleton_method(:sign_in_flow_actor) { |_| @operator }
    controller.define_singleton_method(:auth_org_sign_in_path) { |ri: nil| "/sign/in?ri=#{ri}" }
    controller.define_singleton_method(:auth_org_sign_in_check_path) { |ri: nil, pt: nil|
      "/sign/in/check?ri=#{ri}#{pt ? "&pt=#{pt}" : ""}"
    }
    controller.define_singleton_method(:auth_org_sign_in_session_path) { |ri: nil, pt: nil|
      "/sign/in/session?ri=#{ri}#{pt ? "&pt=#{pt}" : ""}"
    }
    controller.define_singleton_method(:sign_in_selector_path) { |pt: nil| "/sign/in/selector?pt=#{pt}" }
    controller.define_singleton_method(:sign_in_welcome_path) { |pt: nil| "/sign/in/welcome?pt=#{pt}" }
    controller.define_singleton_method(:redirect_to) { |path, **_options| @redirected_to = path }
    controller.define_singleton_method(:redirected_to) { @redirected_to }
    controller
  end

  def step_for(status)
    OperatorSignInFlow::STEP_BY_STATUS_ID.fetch(OperatorSignInFlow.status_id_for(status))
  end

  def guarded_cycle_attrs(cycle)
    cycle.attributes.slice("status_id", "state", "step", "token_id", "completed_at", "session_issued_at")
  end

  def assert_no_sign_in_guard_durable_changes(&)
    assert_no_difference("Operator.count") do
      assert_no_difference("OperatorAccount.count") do
        assert_no_difference("OperatorWorkspaceAccount.count") do
          assert_no_difference("OperatorOrganization.count") do
            assert_no_difference("Avatar.count") do
              assert_no_difference("OperatorToken.count", &)
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

    base.merge(
      "Authorization" => "Bearer #{
        jwt_access_token_for(user, host: host, session_public_id: token.public_id, resource_type: "client")
      }",
    )
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

    base.merge(
      "Authorization" => "Bearer #{
        jwt_access_token_for(staff, host: host, session_public_id: token.public_id, resource_type: "operator")
      }",
    )
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

    base.merge(
      "Authorization" => "Bearer #{
        jwt_access_token_for(visitor, host: host, session_public_id: token.public_id, resource_type: "visitor")
      }",
    )
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
end

# DAMP auth header helpers for this test class.
class Auth::Org::Sign::In::GuardsControllerTest
  private
end
