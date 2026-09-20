# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class PreferenceGlobalTestController < ApplicationController
  def set_color_theme
  end

  def set_preferences_cookie
  end

  def set_locale_from_params
  end

  def set_timezone_from_session
  end

  def preference_payload_value(_)
    nil
  end

  def write_preference_cookie(_, _)
  end

  include PreferenceGlobal

  def index
    render plain: "ok"
  end
end

class PreferenceGlobalTest < ActiveSupport::TestCase
  test "requested_context normalizes params and ignores invalid ri" do
    controller = PreferenceGlobalTestController.new
    controller.request = ActionDispatch::TestRequest.create
    controller.params = ActionController::Parameters.new(ri: "US", lx: "EN", ct: "DR", tz: "UTC", bad: "value")

    context = controller.requested_context

    assert_equal({ ri: "us", lx: "en", ct: "dr", tz: "utc" }, context)
  end

  test "requested_context ignores unsupported lx values" do
    controller = PreferenceGlobalTestController.new
    controller.request = ActionDispatch::TestRequest.create
    controller.params = ActionController::Parameters.new(ri: "jp", lx: "kr")

    context = controller.requested_context

    assert_equal({ ri: "jp" }, context)
  end

  test "requested_context ignores unsupported ct and tz values" do
    controller = PreferenceGlobalTestController.new
    controller.request = ActionDispatch::TestRequest.create
    controller.params = ActionController::Parameters.new(ri: "jp", ct: "purple", tz: "Mars/Base")

    context = controller.requested_context

    assert_equal({ ri: "jp" }, context)
  end

  test "requested_context keeps supported ct and tz aliases" do
    controller = PreferenceGlobalTestController.new
    controller.request = ActionDispatch::TestRequest.create
    controller.params = ActionController::Parameters.new(ri: "jp", ct: "DR", tz: "UTC")

    context = controller.requested_context

    assert_equal({ ri: "jp", ct: "dr", tz: "utc" }, context)
  end

  test "requested_context drops jst timezone shorthand" do
    controller = PreferenceGlobalTestController.new
    controller.request = ActionDispatch::TestRequest.create
    controller.params = ActionController::Parameters.new(ri: "jp", tz: "jst")

    context = controller.requested_context

    assert_equal({ ri: "jp" }, context)
  end

  test "effective_context lets get parameters override jwt preference values" do
    controller = PreferenceGlobalTestController.new
    controller.request = ActionDispatch::TestRequest.create
    controller.params = ActionController::Parameters.new(
      ri: "jp",
      lx: "en",
      tz: "Etc/UTC",
      ct: "dr",
      cu: "usd",
      df: "us",
      tf: "hour_12",
      mo: "reduced",
      dn: "compact",
      ps: "50",
    )
    controller.define_singleton_method(:preference_payload_preferences) do
      {
        "ri" => "us",
        "lx" => "ja",
        "tz" => "Asia/Tokyo",
        "ct" => "sy",
        "cu" => "jpy",
        "df" => "iso",
        "tf" => "hour_24",
        "mo" => "standard",
        "dn" => "standard",
        "ps" => "20",
      }
    end

    assert_equal(
      {
        ri: "jp",
        lx: "en",
        tz: "etc/utc",
        ct: "dr",
        cu: "usd",
        df: "us",
        tf: "12",
        mo: "rd",
        dn: "cp",
        ps: "50",
      },
      controller.effective_context.slice(:ri, :lx, :tz, :ct, :cu, :df, :tf, :mo, :dn, :ps),
    )
  end

  test "request_context omits invalid public request context values" do
    controller = PreferenceGlobalTestController.new
    controller.request = ActionDispatch::TestRequest.create
    controller.params = ActionController::Parameters.new(ri: "ca", lx: "kr", ct: "purple", tz: "Mars/Base", pt: "")

    assert_empty controller.request_context
  end

  test "effective_context re-reads preference context after payload changes" do
    controller = PreferenceGlobalTestController.new
    controller.request = ActionDispatch::TestRequest.create
    controller.params = ActionController::Parameters.new
    preferences = { "lx" => "ja" }
    controller.define_singleton_method(:preference_payload_preferences) { preferences }

    assert_equal "ja", controller.effective_context[:lx]

    preferences = { "lx" => "en" }

    assert_equal "en", controller.effective_context[:lx]
  end

  test "default_url_options merges requested context" do
    controller = PreferenceGlobalTestController.new
    controller.request = ActionDispatch::TestRequest.create
    controller.params = ActionController::Parameters.new(ri: "us", lx: "EN", ct: "DR", tz: "UTC")

    assert_equal({ ri: "us", lx: "en", ct: "dr", tz: "utc" }, controller.default_url_options)
  end

  test "ensure_required_ri! redirects when required ri differs" do
    controller = PreferenceGlobalTestController.new
    controller.request = ActionDispatch::TestRequest.create(
      "HTTP_HOST" => "example.com", "PATH_INFO" => "/prefs",
      "QUERY_STRING" => "lx=en",
    )
    controller.response = ActionDispatch::TestResponse.new
    controller.params = ActionController::Parameters.new(ri: "jp", lx: "en")
    controller.define_singleton_method(:required_ri) { "us" }
    controller.define_singleton_method(:performed?) { false }
    controller.define_singleton_method(:redirect_to) do |url, allow_other_host:, status:|
      @redirect_args = [url, allow_other_host, status].freeze
    end

    controller.ensure_required_ri!

    assert_equal ["http://example.com/prefs?lx=en&ri=us", false, :found],
                 controller.instance_variable_get(:@redirect_args)
  end
end
