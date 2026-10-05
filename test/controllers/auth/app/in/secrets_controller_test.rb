# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::App::Sign::In::SecretsControllerTest < ActionDispatch::IntegrationTest
  test "legacy Secret GET remains absent while canonical actions require browser admission" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! host

    get "/sign/in/secret"

    assert_response :not_found

    assert_no_difference("ClientSecretCredential.count") do
      get new_auth_app_sign_in_secret_path(ri: "jp")

      assert_response :bad_request
    end
    assert_no_difference -> { ClientSecretCredential.where.not(claimed_at: nil).count } do
      assert_no_difference("ClientToken.count") do
        post auth_app_sign_in_secret_path(ri: "jp"), params: { secret: "a" * 32 }

        assert_response :bad_request
      end
    end
  end
end
