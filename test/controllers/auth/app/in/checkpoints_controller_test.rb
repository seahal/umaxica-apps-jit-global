# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
require "base64"

class Auth::App::Sign::In::CheckpointsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_tokens

  setup do
    @host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
    @user = clients(:one)
  end

  test "show without login hands off to the Base admission entry" do
    get auth_app_sign_in_check_url(ri: "jp"), headers: host_headers(@host)

    assert_response :redirect
    assert_base_sign_handoff_redirect(response.location, surface: :app)
  end

  test "show without sign in sequence is rejected" do
    get auth_app_sign_in_check_url(ri: "jp"),
        headers: as_user_headers(@user, host: @host)

    assert_response :bad_request
    assert_includes response.body, I18n.t("errors.messages.not_authorized")
  end

  test "update is not routed" do
    patch auth_app_sign_in_check_url(ri: "jp"),
          headers: as_user_headers(@user, host: @host).merge(
            "X-TEST-BULLETIN" => bulletin_json(issued_at: Time.current.to_i, state: "new"),
          )

    assert_response :not_found
  end

  test "destroy is not routed" do
    pt = Base64.urlsafe_encode64("/settings")

    delete auth_app_sign_in_check_url(ri: "jp", pt: pt),
           headers: as_user_headers(@user, host: @host).merge(
             "X-TEST-BULLETIN" => bulletin_json(issued_at: Time.current.to_i, state: "updated"),
           )

    assert_response :not_found
  end

  private

  def bulletin_json(issued_at:, state:)
    { "issued_at" => issued_at, "kind" => "mock", "state" => state }.to_json
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
end

# DAMP auth header helpers for this test class.
class Auth::App::Sign::In::CheckpointsControllerTest
  private

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
