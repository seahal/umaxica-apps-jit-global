# typed: false
# frozen_string_literal: true

require "test_helper"

# The com and org Welcome pages apply the same return-target contract as app
# (test/controllers/base/app/welcomes_controller_test.rb), each for its own surface only.
class Base::Com::WelcomeReturnTargetControllerTest < ActionController::TestCase
  tests Base::Com::WelcomesController

  setup do
    @host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    @visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
    @token = VisitorToken.create!(visitor: @visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    BaseSelectorBootstrapAuthority.call(surface: :com, principal: @visitor)
    BaseSelectorAuthority.prepare(surface: :com, principal: @visitor, session: @token)
    @request.host = @host
    browser_rp_cookie_pairs(
      client_id: "base-com-ww", surface: "com", host: @host, actor: @visitor, token: @token,
    ).each do |pair|
      name, value = pair.split("=", 2)
      @request.cookies[name] = Rack::Utils.unescape(value)
    end
    @request.session[:com_sign_in_welcome] = {
      "remaining" => 5,
      "issued_at" => Time.current.to_i,
      "expires_at" => 10.minutes.from_now.to_i,
      "sequence_id" => nil,
    }
    @request.session[:authentication_pt_nonce] = "com-welcome-nonce"
    @request.headers["X-Inertia"] = "true"
    @request.headers["X-Inertia-Version"] = InertiaRails.configuration.version
  end

  test "com Next returns to the verified pre-sign-in page" do
    get :show, params: { ri: "jp", pt: path_target("/identity?ri=jp", surface: "com") }

    assert_response :success
    assert_equal "/identity?ri=jp", response.parsed_body.dig("props", "next_link", "href")
  end

  test "com ignores a return target issued for the app surface" do
    get :show, params: { ri: "jp", pt: path_target("/identity?ri=jp", surface: "app") }

    assert_equal "/dashboard?ri=jp", response.parsed_body.dig("props", "next_link", "href")
  end

  test "com skips the page without its own gate even when the app gate is present" do
    @request.session[:app_sign_in_welcome] = @request.session.delete(:com_sign_in_welcome)

    get :show, params: { ri: "jp", pt: path_target("/identity?ri=jp", surface: "com") }

    assert_redirected_to "/dashboard?ri=jp"
  end

  private

  def path_target(destination, surface:)
    ActiveSupport::MessageVerifier.new(
      Rails.application.key_generator.generate_key(AuthenticationRedirects::PATH_TARGET_TOKEN_SALT, 32),
      digest: "SHA256", serializer: JSON, url_safe: true,
    ).generate(
      { "flow" => "authentication",
        "surface" => surface,
        "session_nonce" => "com-welcome-nonce",
        "pt" => destination, },
      purpose: AuthenticationRedirects::PATH_TARGET_TOKEN_PURPOSE, expires_in: 5.minutes,
    )
  end
end

class Base::Org::WelcomeReturnTargetControllerTest < ActionController::TestCase
  tests Base::Org::WelcomesController

  setup do
    @host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    @operator = Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
    @token = OperatorToken.create!(staff: @operator, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    BaseSelectorBootstrapAuthority.call(surface: :org, principal: @operator)
    BaseSelectorAuthority.prepare(surface: :org, principal: @operator, session: @token)
    @request.host = @host
    browser_rp_cookie_pairs(
      client_id: "base-org-ww", surface: "org", host: @host, actor: @operator, token: @token,
    ).each do |pair|
      name, value = pair.split("=", 2)
      @request.cookies[name] = Rack::Utils.unescape(value)
    end
    @request.session[:org_sign_in_welcome] = {
      "remaining" => 5,
      "issued_at" => Time.current.to_i,
      "expires_at" => 10.minutes.from_now.to_i,
      "sequence_id" => nil,
    }
    @request.session[:authentication_pt_nonce] = "org-welcome-nonce"
    @request.headers["X-Inertia"] = "true"
    @request.headers["X-Inertia-Version"] = InertiaRails.configuration.version
  end

  test "org Next returns to the verified pre-sign-in page" do
    get :show, params: { ri: "jp", pt: path_target("/identity?ri=jp", surface: "org") }

    assert_response :success
    assert_equal "/identity?ri=jp", response.parsed_body.dig("props", "next_link", "href")
  end

  test "org ignores a return target issued for the com surface" do
    get :show, params: { ri: "jp", pt: path_target("/identity?ri=jp", surface: "com") }

    assert_equal "/dashboard?ri=jp", response.parsed_body.dig("props", "next_link", "href")
  end

  test "org skips the page without its own gate even when the com gate is present" do
    @request.session[:com_sign_in_welcome] = @request.session.delete(:org_sign_in_welcome)

    get :show, params: { ri: "jp", pt: path_target("/identity?ri=jp", surface: "org") }

    assert_redirected_to "/dashboard?ri=jp"
  end

  private

  def path_target(destination, surface:)
    ActiveSupport::MessageVerifier.new(
      Rails.application.key_generator.generate_key(AuthenticationRedirects::PATH_TARGET_TOKEN_SALT, 32),
      digest: "SHA256", serializer: JSON, url_safe: true,
    ).generate(
      { "flow" => "authentication",
        "surface" => surface,
        "session_nonce" => "org-welcome-nonce",
        "pt" => destination, },
      purpose: AuthenticationRedirects::PATH_TARGET_TOKEN_PURPOSE, expires_in: 5.minutes,
    )
  end
end
