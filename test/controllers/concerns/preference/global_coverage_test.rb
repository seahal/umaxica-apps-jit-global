# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class PreferenceGlobalCoverageTest < ActiveSupport::TestCase
  class Harness < ApplicationController
    include PreferenceGlobal

    attr_accessor :params_hash, :session_hash, :request_obj, :redirected, :cookies_hash

    def initialize
      super
      @params_hash = {}
      @session_hash = {}
      @cookies_hash = {}.with_indifferent_access
      @query_parameters = {}
      @request_obj = Object.new
      request_owner = self

      def @request_obj.host = "localhost"

      def @request_obj.base_url = "http://localhost"

      def @request_obj.path = "/test"

      @request_obj.define_singleton_method(:query_parameters) { request_owner.query_parameters }

      def @request_obj.get? = true

      def @request_obj.head? = false

      def @request_obj.protocol = "http://"

      def @request_obj.port = 80
    end

    def params = ActionController::Parameters.new(@params_hash)

    def query_parameters = @query_parameters

    def query_parameters=(value)
      @query_parameters = value
    end

    def session = @session_hash

    def request = @request_obj

    def cookies = @cookies_hash

    def redirect_to(url, options = {})
      @redirected = [url, options]
    end

    def redirected_to
      @redirected&.first
    end

    def performed?
      false
    end

    def preference_payload_preferences = { "ri" => "us", "lx" => "en", "tz" => "UTC", "ct" => "dr" }

    def preference_prefix(_pref = nil) = "App"

    def preference_prefix_underscore = "app_preference"

    def theme_short_code(_val) = "dr"

    def option_id_to_region(*) = "jp"

    def option_id_to_language(*) = "ja"

    def option_id_to_timezone(*) = "Asia/Tokyo"

    def write_preference_cookie(*) = nil

    def set_timezone_from_session = nil

    def preference_payload_value(_key) = "UTC"
  end

  setup do
    @harness = Harness.new
  end

  test "resolve_param_context returns effective_context" do
    assert @harness.resolve_param_context.key?(:ri)
  end

  test "ensure_required_ri! redirects when ri mismatch" do
    @harness.params_hash = { ri: "jp" }
    # Mock effective_context to return us
    @harness.define_singleton_method(:effective_context) do
      { ri: "us" }
    end
    @harness.ensure_required_ri!

    assert_equal "http://localhost/test?ri=us", @harness.redirected_to
  end

  test "requested_context filters params" do
    @harness.params_hash = { ri: "jp", lx: "ja", other: "value" }
    context = @harness.requested_context

    assert_equal "jp", context[:ri]
    assert_equal "ja", context[:lx]
    assert_not context.key?(:other)
  end

  test "requested_context drops invalid lx" do
    @harness.params_hash = { ri: "jp", lx: "kr" }
    context = @harness.requested_context

    assert_equal "jp", context[:ri]
    assert_not context.key?(:lx)
  end

  test "requested_context drops invalid ct and tz" do
    @harness.params_hash = { ri: "jp", ct: "purple", tz: "Mars/Base" }
    context = @harness.requested_context

    assert_equal "jp", context[:ri]
    assert_not context.key?(:ct)
    assert_not context.key?(:tz)
  end

  test "requested_context drops jst timezone shorthand" do
    @harness.params_hash = { ri: "jp", tz: "jst" }
    context = @harness.requested_context

    assert_equal "jp", context[:ri]
    assert_not context.key?(:tz)
  end

  test "cookie_context returns jwt payload values" do
    context = @harness.cookie_context

    assert_equal "us", context[:ri]
    assert_equal "en", context[:lx]
  end

  test "cookie_context ignores @preferences db record - jwt payload wins" do
    @harness.instance_variable_set(:@preferences, AppPreference.new)
    context = @harness.cookie_context

    assert_equal "us", context[:ri]
    assert_equal "en", context[:lx]
  end

  test "cookie_context returns empty hash when no jwt payload" do
    @harness.define_singleton_method(:preference_payload_preferences) { nil }
    context = @harness.cookie_context

    assert_empty context
  end

  test "default_url_options includes requested context" do
    @harness.params_hash = { ri: "us" }
    opts = @harness.default_url_options

    assert_equal "us", opts[:ri]
  end
end
