# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class PreferenceBoosterTest < ActionDispatch::IntegrationTest
  class DummyPreferenceController < ApplicationController
    include PreferenceBase
    include PreferenceCore

    before_action :set_preferences_cookie

    def preference_class
      AppPreference
    end

    def test_action
      render plain: {
        cookies: cookies.to_h,
        pref: @preferences&.id,
        error: @preference_refresh_failed,
      }.to_json
    end
  end

  setup do
    Rails.application.routes.draw do
      get "test_preference" => "preference_booster_test/dummy_preference#test_action"
    end
  end

  teardown do
    Rails.application.reload_routes!
  end

  test "GET request does not create preference state or cookies" do
    preference_count = AppPreference.count
    get "/test_preference", env: { "HTTP_HOST" => "localhost" }

    assert_response :success
    assert_equal preference_count, AppPreference.count
    assert_nil cookies[PreferenceCookieName.access(surface: :app)]
    assert_nil cookies[PreferenceCookieName.refresh(surface: :app)]
  end
end
