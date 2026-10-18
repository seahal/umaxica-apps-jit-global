# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Auth::Org::Sign::In::GuardsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators

  setup do
    @host = ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost")
    @operator = operators(:one)
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

    assert_bound_redirect(controller.redirected_to, "/sign/in/check", cycle, "GUARDRAIL_PENDING")
    assert_equal before_attrs, guarded_cycle_attrs(cycle.reload)
  end

  test "checkpoint state redirects to check" do
    cycle = create_cycle(status: "CHECKPOINT_PENDING")
    before_attrs = guarded_cycle_attrs(cycle.reload)
    controller = build_controller(cycle: cycle)

    controller.show

    assert_bound_redirect(controller.redirected_to, "/sign/in/check", cycle, "CHECKPOINT_PENDING")
    assert_equal before_attrs, guarded_cycle_attrs(cycle.reload)
  end

  test "selector state redirects to selector sequence path" do
    cycle = create_cycle(status: "SELECTOR_PENDING", return_to: "/dashboard")
    controller = build_controller(cycle: cycle)

    controller.show

    assert_bound_redirect(controller.redirected_to, "/sign/in/selector", cycle, "SELECTOR_PENDING", pt: "/dashboard")
  end

  test "session issuance state redirects to welcome sequence path" do
    cycle = create_cycle(status: "SESSION_ISSUANCE_PENDING", return_to: "/dashboard")
    controller = build_controller(cycle: cycle)

    controller.show

    assert_bound_redirect(
      controller.redirected_to, "/sign/in/welcome", cycle, "SESSION_ISSUANCE_PENDING", pt: "/dashboard",
    )
  end

  test "unsafe path target redirects to sign in entry without flash" do
    cycle = create_cycle(status: "CHECKPOINT_PENDING")
    controller = build_controller(cycle: cycle, path_target: "/account", signed_pt: nil)

    controller.show

    assert_equal "/sign/in?ri=jp", controller.redirected_to
    assert_equal "CHECKPOINT_PENDING", cycle.reload.state_name_for(cycle.state_id)
  end

  test "unsafe return target redirects to sign in entry without flash" do
    cycle = create_cycle(status: "CHECKPOINT_PENDING", return_to: "https://evil.example.test")
    controller = build_controller(cycle: cycle, signed_token: nil)

    controller.show

    assert_equal "/sign/in?ri=jp", controller.redirected_to
    assert_equal "CHECKPOINT_PENDING", cycle.reload.state_name_for(cycle.state_id)
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
      state_id: OperatorSignInFlow.state_id_for(status),
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
    controller.define_singleton_method(:auth_org_sign_in_check_path) { |ri: nil, pt: nil, fb: nil|
      query = { ri: ri, pt: pt, fb: fb }.compact.to_query
      "/sign/in/check?#{query}"
    }
    controller.define_singleton_method(:sign_in_selector_path) { |pt: nil, **options|
      query = {
        pt: pt,
        fb: SignInFlowBindingCodec.encode(
          flow: options.fetch(:cycle), surface: "org", phase: "SELECTOR_PENDING",
        ),
      }.compact
        .to_query
      "/sign/in/selector?#{query}"
    }
    controller.define_singleton_method(:sign_in_welcome_path) { |pt: nil, **options|
      query = {
        pt: pt,
        fb: SignInFlowBindingCodec.encode(
          flow: options.fetch(:cycle), surface: "org", phase: "SESSION_ISSUANCE_PENDING",
        ),
      }.compact.to_query
      "/sign/in/welcome?#{query}"
    }
    controller.define_singleton_method(:redirect_to) { |path, **_options| @redirected_to = path }
    controller.define_singleton_method(:redirected_to) { @redirected_to }
    controller
  end

  def guarded_cycle_attrs(cycle)
    cycle.attributes.slice("state_id", "token_id", "completed_at", "session_issued_at")
  end

  def assert_bound_redirect(location, path, cycle, phase, pt: nil)
    uri = URI.parse(location)

    assert_equal path, uri.path
    query = Rack::Utils.parse_nested_query(uri.query.to_s)
    assert_equal "jp", query.fetch("ri", "jp") if path.end_with?("/check")
    assert_equal pt, query["pt"] if pt
    binding = SignInFlowBindingCodec.decode(query.fetch("fb"))

    assert_equal cycle.public_id, binding.flow_public_id
    assert_equal phase, binding.phase
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

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end

  def jwt_issuer_id_for_test_host(host, resource_type)
    normalized = host.to_s
    service = normalized.include?("acme") ? "ACME" : (normalized.include?("core") ? "CORE" : "AUTH")
    surface =
      if service == "AUTH"
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
