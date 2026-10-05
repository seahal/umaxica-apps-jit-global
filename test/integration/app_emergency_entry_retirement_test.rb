# frozen_string_literal: true

require "test_helper"

class AppEmergencyEntryRetirementTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "retired app Emergency placeholder has no browser or mutation endpoint" do
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    get "/sign/in/emergency", params: { ri: "jp" }

    assert_response :not_found
    post "/sign/in/emergency", params: { ri: "jp" }

    assert_response :not_found
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}/sign/in/emergency", method: :get,
      )
    end
  end
end
