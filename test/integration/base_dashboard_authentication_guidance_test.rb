# frozen_string_literal: true

require "test_helper"

class BaseDashboardAuthenticationGuidanceTest < ActionDispatch::IntegrationTest
  [
    ["app", "PUBLIC_BASE_SERVICE_URL", ClientSignInFlow],
    ["com", "PUBLIC_BASE_CORPORATE_URL", VisitorSignInFlow],
    ["org", "PUBLIC_BASE_STAFF_URL", OperatorSignInFlow],
  ].each do |surface, host_key, flow_model|
    test "#{surface} anonymous HTML Dashboard reaches passive Sign without issuing an admission" do
      host! ENV.fetch(host_key)
      assert_no_difference(-> { flow_model.count }) do
        get "/dashboard", params: { ri: "jp" }

        assert_response :redirect
        destination = URI.parse(response.location)

        assert_equal "/sign", destination.path
        assert_includes [nil, ENV.fetch(host_key)], destination.host
        assert_equal "jp", Rack::Utils.parse_query(destination.query).fetch("ri")
        assert_not_includes destination.query.to_s, "entry_ref"
        follow_redirect!

        assert_response :success
        assert_select "form[method=post]"
      end
    end

    test "#{surface} anonymous JSON Dashboard refuses access without login HTML" do
      host! ENV.fetch(host_key)
      assert_no_difference(-> { flow_model.count }) do
        get "/dashboard", params: { ri: "jp" }, headers: { "Accept" => "application/json" }

        assert_response :unauthorized
        assert_nil response.location
        assert_equal "application/json", response.media_type
      end
    end

    test "#{surface} anonymous Inertia Dashboard uses the existing location response" do
      host! ENV.fetch(host_key)
      assert_no_difference(-> { flow_model.count }) do
        get "/dashboard", params: { ri: "jp" }, headers: {
          "X-Inertia" => "true", "X-Inertia-Version" => InertiaRails.configuration.version,
        }

        assert_response :conflict
        assert_equal "/sign", URI.parse(response.headers.fetch("X-Inertia-Location")).path
      end
    end

    test "#{surface} anonymous HEAD Dashboard has no body and starts no admission" do
      host! ENV.fetch(host_key)
      assert_no_difference(-> { flow_model.count }) do
        head "/dashboard", params: { ri: "jp" }

        assert_response :redirect
        assert_equal "/sign", URI.parse(response.location).path
        assert_empty response.body
      end
    end
  end
end
