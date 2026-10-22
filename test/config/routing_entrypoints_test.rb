# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class RoutingEntrypointsTest < ActiveSupport::TestCase
  test "global routing entrypoints are loaded" do
    assert_nothing_raised { Rails.application.reload_routes! }

    root_route = Rails.application.routes.recognize_path(
      "http://#{ENV.fetch("PRIVATE_BASE_SERVICE_URL", "www.app.localhost")}/",
    )

    assert_equal "base/app/roots", root_route[:controller]
    assert_equal "index", root_route[:action]
  end
end
