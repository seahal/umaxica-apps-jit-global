# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class OrgSocialLoginBlockedTest < ActionDispatch::IntegrationTest
  setup do
    @staff_host = ENV.fetch("PRIVATE_AUTH_STAFF_URL")
    @service_host = ENV.fetch("PRIVATE_AUTH_SERVICE_URL")
  end

  test "app Google provider request on staff host redirects to callback" do
    host! @staff_host

    post "/social/google"

    assert_includes [404, 302], response.status
    assert_equal "http://#{@staff_host}/social/google/callback", response.location if response.redirect?
  end

  test "staff Google provider request on staff host returns 404" do
    host! @staff_host

    post "/social/google_#{"org"}"

    assert_response :not_found
  end

  test "Apple provider request on staff host redirects to callback" do
    host! @staff_host

    post "/social/apple"

    assert_includes [404, 302], response.status
    assert_equal "http://#{@staff_host}/social/apple/callback", response.location if response.redirect?
  end

  test "staff sign-in page does not contain social login buttons" do
    host! @staff_host

    get "/sign/in", params: { ri: "jp", admission: login_challenge_for("org") }

    assert_response :see_other
    follow_redirect!

    assert_response :success
    assert_not_includes response.body, "/auth/google_app"
    assert_not_includes response.body, "/auth/google_#{"org"}"
    assert_not_includes response.body, "/auth/google_#{"com"}"
    assert_not_includes response.body, "/auth/apple"
    assert_not_includes response.body, "/social/google"
    assert_not_includes response.body, "/social/apple"
  end

  test "legacy staff Google flag does not enable social auth" do
    host! @staff_host

    with_env("ORG_#{"GOOGLE"}_SIGNIN_ENABLED" => "true", "ORG_#{"GOOGLE"}_SIGNUP_ENABLED" => "true") do
      post "/social/google_#{"org"}"
    end

    assert_response :not_found
  end

  test "app social route remains available on app host" do
    host! @service_host

    post "/social/google"

    assert_not_equal 404, response.status
  end

  private

  def login_challenge_for(surface)
    transaction = OidcAuthorizationTransactionCoordinator.issue!(
      surface: surface,
      intent: "sign_in",
      params: {
        response_type: "code",
        client_id: "core-next-rp",
        redirect_uri: OidcClientRegistry.find!("core-next-rp").redirect_uris.first,
        code_challenge: SecureRandom.urlsafe_base64(32),
        code_challenge_method: "S256",
        state: SecureRandom.urlsafe_base64(16),
        nonce: SecureRandom.urlsafe_base64(16),
        scope: "openid profile",
      },
    ).transaction
    BaseAuthAdmissionCoordinator.issue_handoff!(transaction: transaction).code
  end

  def with_env(values)
    original = values.keys.index_with { |key| ENV[key] }
    values.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    yield
  ensure
    original.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end
