# typed: false
# frozen_string_literal: true

require "test_helper"

class PreferenceBootstrapIdempotencyTest < ActionDispatch::IntegrationTest
  test "cookie-less preference GET does not bootstrap or persist a preference" do
    host! "base.app.localhost"

    assert_no_difference -> { AppPreference.count } do
      get "/preference?ri=jp"
    end
    assert_response :success

    assert_no_difference -> { AppPreference.count } do
      get "/preference?ri=jp"
    end
    assert_response :success
  end
end
