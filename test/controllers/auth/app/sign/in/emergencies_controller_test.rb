# frozen_string_literal: true

require "test_helper"

class Auth::App::Sign::In::EmergenciesControllerTest < ActionDispatch::IntegrationTest
  test "retired Emergency path cannot mutate credentials or issue sessions" do
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    assert_no_difference ["ClientToken.count", "ClientDeviceSession.count", "ClientSecretCredential.count"] do
      get "/sign/in/emergency", params: { ri: "jp" }

      assert_response :not_found
    end
  end
end
