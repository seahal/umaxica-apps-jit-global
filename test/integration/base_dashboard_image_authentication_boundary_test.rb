# frozen_string_literal: true

require "test_helper"

class BaseDashboardImageAuthenticationBoundaryTest < ActionDispatch::IntegrationTest
  [
    ["app", "PUBLIC_BASE_SERVICE_URL", ClientSignInFlow, ClientToken],
    ["org", "PUBLIC_BASE_STAFF_URL", OperatorSignInFlow, OperatorToken],
  ].each do |surface, host_key, flow_model, token_model|
    test "#{surface} anonymous image GET and HEAD refuse without interactive Sign for every representation" do
      host! ENV.fetch(host_key)
      path =
        case surface
        when "app" then base_app_dashboard_avatar_image_path(ri: "jp")
        when "org" then base_org_dashboard_avatar_image_path(ri: "jp")
        end

      [
        { "Accept" => "image/avif,image/webp,image/png,*/*;q=0.8", "Sec-Fetch-Dest" => "image" },
        { "Accept" => "text/html", "Sec-Fetch-Dest" => "document" },
        { "Accept" => "text/html",
          "X-Inertia" => "true",
          "X-Inertia-Version" => InertiaRails.configuration.version,
          "Sec-Fetch-Dest" => "empty", },
      ].each do |headers|
        assert_no_difference(-> { flow_model.count }) do
          assert_no_difference(-> { token_model.count }) do
            get path, headers: headers

            assert_response :unauthorized
            assert_empty response.body
            assert_nil response.location
            assert_nil response.headers["X-Inertia-Location"]
            assert_nil response.headers["WWW-Authenticate"]
            head path, headers: headers

            assert_response :unauthorized
            assert_empty response.body
            assert_nil response.location
            assert_nil response.headers["X-Inertia-Location"]
          end
        end
      end
      get path, headers: { "Accept" => "application/json" }

      assert_response :unauthorized
      assert_equal({ "error" => "unauthorized" }, response.parsed_body)
      assert_nil response.location
      head path, headers: { "Accept" => "application/json" }

      assert_response :unauthorized
      assert_empty response.body
      assert_no_difference(-> { flow_model.count }) do
        get path, headers: {
          "X-Inertia" => "true", "X-Inertia-Version" => "deliberately-mismatched-version",
        }

        assert_response :conflict
        assert_empty response.body
        reload_destination = URI.parse(response.headers.fetch("X-Inertia-Location"))

        assert_equal "/dashboard/avatar_image", reload_destination.path
        assert_nil response.location
      end
    end
  end

  test "com has no dashboard Avatar image endpoint" do
    assert_not Rails.application.routes.named_routes.key?(:base_com_dashboard_avatar_image)
  end
end
