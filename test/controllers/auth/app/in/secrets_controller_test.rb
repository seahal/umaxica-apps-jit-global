# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::App::Sign::In::SecretsControllerTest < ActionDispatch::IntegrationTest
  test "legacy secret sign-in path is unavailable" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
    host! host

    get "/sign/in/secret"

    assert_response :not_found

    post "/sign/in/secret", params: { secret_credential_login_form: { secret_credential_value: "unused" } }

    assert_response :not_found
  end
end
