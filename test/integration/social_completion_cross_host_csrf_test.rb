# typed: false
# frozen_string_literal: true

require "test_helper"

# The Auth result is staged behind an opaque reference. Base renders a same-host
# continuation GET and commits only from the receiver-local CSRF-protected POST.
class SocialCompletionCrossHostCsrfTest < ActionDispatch::IntegrationTest
  setup do
    @original_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    @base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    @auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    @result_ref = SecureRandom.uuid
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @original_forgery_protection
  end

  test "result handoff starts with a receiver-local GET form" do
    get base_app_social_authentication_completion_path(id: "google", result_ref: @result_ref, ri: "jp"),
        headers: { "Host" => @base_host }

    assert_response :success
    assert_select "form" do
      assert_select "input[name='result_ref'][value=?]", @result_ref
      assert_select "input[name='authenticity_token']"
    end
  end

  test "a cross-host POST is rejected by standard Rails CSRF protection" do
    token = receiver_csrf_token

    post base_app_social_authentication_completion_path(id: "google"),
         params: { result_ref: @result_ref, authenticity_token: token, ri: "jp" },
         headers: {
           "Host" => @base_host,
           "Origin" => "https://#{@auth_host}",
           "Sec-Fetch-Site" => "cross-site",
         }

    assert_response :unprocessable_content
    assert_not_equal I18n.t("sign.app.social.sessions.create.failure"), response.body
  end

  test "a receiver-local CSRF-protected POST reaches result validation" do
    token = receiver_csrf_token

    post base_app_social_authentication_completion_path(id: "google"),
         params: { result_ref: @result_ref, authenticity_token: token, ri: "jp" },
         headers: {
           "Host" => @base_host,
           "Origin" => "http://#{@base_host}",
           "Sec-Fetch-Site" => "same-origin",
         }

    assert_response :unprocessable_content
    assert_equal "text/plain", response.media_type
    assert_equal I18n.t("sign.app.social.sessions.create.failure"), response.body
  end

  test "a null Origin cannot substitute for the receiver-local CSRF check" do
    token = receiver_csrf_token

    post base_app_social_authentication_completion_path(id: "google"),
         params: { result_ref: @result_ref, authenticity_token: token, ri: "jp" },
         headers: {
           "Host" => @base_host,
           "Origin" => "null",
           "Sec-Fetch-Site" => "same-site",
         }

    assert_response :unprocessable_content
    assert_not_equal I18n.t("sign.app.social.sessions.create.failure"), response.body
  end

  private

  def receiver_csrf_token
    get(
      base_app_social_authentication_completion_path(id: "google", result_ref: @result_ref, ri: "jp"),
      headers: { "Host" => @base_host },
    )

    assert_response :success
    response.parsed_body.at_css("input[name='authenticity_token']")["value"]
  end
end
