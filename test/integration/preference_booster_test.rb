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

    def edit_region
      set_region_preferences_edit
      render plain: "ok"
    end

    def update_region
      set_region_preferences_update
      render json: preference_response_payload
    end

    def edit_language
      set_language_preferences_edit
      render plain: "ok"
    end

    def update_language
      set_language_preferences_update
      render json: preference_response_payload
    end

    def edit_timezone
      set_timezone_preferences_edit
      render plain: "ok"
    end

    def update_timezone
      set_timezone_preferences_update
      render json: preference_response_payload
    end

    def edit_theme
      set_theme_preferences_edit
      render plain: "ok"
    end

    def update_theme
      set_theme_preferences_update
      render json: preference_response_payload
    end

    def edit_cookie
      set_cookie_preferences_edit
      render plain: "ok"
    end

    def update_cookie
      set_cookie_preferences_update
      render json: preference_response_payload
    end

    def delete_cookie
      delete_preference_cookie
      render plain: "ok"
    end

    def reset_defaults
      reset_preference_to_defaults!
      render plain: "ok"
    end
  end

  setup do
    Rails.application.routes.draw do
      get "test_preference" => "preference_booster_test/dummy_preference#test_action"

      get "test_region_edit" => "preference_booster_test/dummy_preference#edit_region"
      post "test_region_update" => "preference_booster_test/dummy_preference#update_region"

      get "test_language_edit" => "preference_booster_test/dummy_preference#edit_language"
      post "test_language_update" => "preference_booster_test/dummy_preference#update_language"

      get "test_timezone_edit" => "preference_booster_test/dummy_preference#edit_timezone"
      post "test_timezone_update" => "preference_booster_test/dummy_preference#update_timezone"

      get "test_theme_edit" => "preference_booster_test/dummy_preference#edit_theme"
      post "test_theme_update" => "preference_booster_test/dummy_preference#update_theme"

      get "test_cookie_edit" => "preference_booster_test/dummy_preference#edit_cookie"
      post "test_cookie_update" => "preference_booster_test/dummy_preference#update_cookie"

      delete "test_cookie_delete" => "preference_booster_test/dummy_preference#delete_cookie"
      post "test_reset_defaults" => "preference_booster_test/dummy_preference#reset_defaults"
    end
  end

  teardown do
    Rails.application.reload_routes!
  end

  test "sets preference cookie on request" do
    get "/test_preference", env: { "HTTP_HOST" => "localhost" }

    assert_response :success
    assert_not_nil cookies[PreferenceCookieName.access(surface: :app)]
    assert_not_nil cookies[PreferenceCookieName.refresh(surface: :app)]
  end

  test "edits and updates region" do
    get "/test_region_edit", env: { "HTTP_HOST" => "localhost" }

    assert_response :success

    post "/test_region_update", params: { preference_region: { option_id: 1 } }, env: { "HTTP_HOST" => "localhost" }

    assert_response :success
  end

  test "edits and updates language" do
    get "/test_language_edit", env: { "HTTP_HOST" => "localhost" }

    assert_response :success

    post "/test_language_update", params: { preference_language: { option_id: 1 } }, env: { "HTTP_HOST" => "localhost" }

    assert_response :success
  end

  test "edits and updates timezone" do
    get "/test_timezone_edit", env: { "HTTP_HOST" => "localhost" }

    assert_response :success

    post "/test_timezone_update", params: { preference_timezone: { option_id: 1 } }, env: { "HTTP_HOST" => "localhost" }

    assert_response :success
  end

  test "edits and updates theme" do
    get "/test_theme_edit", env: { "HTTP_HOST" => "localhost" }

    assert_response :success

    post "/test_theme_update", params: { preference_theme: { option_id: 1 } },
                               env: { "HTTP_HOST" => "localhost" }

    assert_response :success
  end

  test "edits and updates cookie consent" do
    get "/test_cookie_edit", env: { "HTTP_HOST" => "localhost" }

    assert_response :success

    post "/test_cookie_update",
         params: { preference_cookie: { consented: true, functional: true, performant: true, targetable: true } },
         env: { "HTTP_HOST" => "localhost" }

    assert_response :success
  end
end
