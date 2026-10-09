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
    get base_app_social_authentication_completion_path(id: "google", result_ref: @result_ref, ri: "jp"),
        headers: { "Host" => @base_host }

    assert_response :success
    token = response.parsed_body.at_css("input[name='authenticity_token']")["value"]

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
    get base_app_social_authentication_completion_path(id: "google", result_ref: @result_ref, ri: "jp"),
        headers: { "Host" => @base_host }

    assert_response :success
    token = response.parsed_body.at_css("input[name='authenticity_token']")["value"]

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
    get base_app_social_authentication_completion_path(id: "google", result_ref: @result_ref, ri: "jp"),
        headers: { "Host" => @base_host }

    assert_response :success
    token = response.parsed_body.at_css("input[name='authenticity_token']")["value"]

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
  test "another Base browser cannot redeem a signed social result with its own valid CSRF token" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE, birthdate: Date.new(2000, 1, 1))
    subject = "foreign-result-#{SecureRandom.hex(8)}"
    ClientGoogleIdentity.create!(
      user: actor,
      uid: subject,
      provider: "google",
      status_id: ClientGoogleIdentityStatus::ACTIVE,
    )
    grant = IdentitySocialCeremonyGrantIssuer.issue!(
      surface: "app", actor_ref: "anonymous", session_ref: SecureRandom.hex(16), operation: "login", provider: "google",
    )
    callback = ExternalAuthentication::CallbackResult.verified(
      principal: ExternalAuthentication::VerifiedPrincipal.new(
        provider: "google", subject: subject, issuer: "https://accounts.google.com", audience: "test-google-client",
        verified_at: Time.current, verification_authority: "test-provider-contract",
      ), credential_candidate: nil,
    )
    result = IdentitySocialCeremonyResultIssuer.issue!(
      grant_token: grant.grant, callback_result: callback, surface: "app", actor_ref: "anonymous",
      session_ref: grant.transaction.session_ref, operation: "login",
    )
    reference = SocialCeremonyResultAdapter.new.issue!(token: result, expires_at: grant.transaction.expires_at)
    host! @base_host
    https!
    get base_app_social_authentication_completion_path(id: "google", result_ref: reference, ri: "jp")

    assert_response :success
    csrf = response.parsed_body.at_css("input[name='authenticity_token']")["value"]
    assert_no_difference("ClientToken.count") do
      post base_app_social_authentication_completion_path(id: "google"),
           params: { result_ref: reference, authenticity_token: csrf, ri: "jp" },
           headers: { "Origin" => "https://#{@base_host}", "Sec-Fetch-Site" => "same-origin" }
    end
    assert_response :unprocessable_content
    assert_not grant.transaction.reload.consumed?
    assert_equal 1, actor.reload.client_google_identities.length
    assert_not response.cookies.key?(AuthenticationBase::ACCESS_COOKIE_KEY)
  end
end
