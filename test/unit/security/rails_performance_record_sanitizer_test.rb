# typed: false
# frozen_string_literal: true

# rubocop:disable I18n/RailsI18n/DecorateString

require "test_helper"
require_relative "../../../lib/rails_performance_record_sanitizer"

# The performance dashboard persists one record per request into Valkey and keeps it for four
# hours. Three of the fields it stores are free text that a secret can reach, and
# `config.filter_parameters` covers only one of them, partially. This pins what each one is reduced
# to before it is written.
#
# `rails_performance` is a `group :development` gem, so the gem's own classes are absent here. That
# is on purpose: the sanitiser is plain Ruby in lib/ with no dependency on the gem precisely so the
# rule it enforces is testable in the environment the suite actually runs in. The wiring -- that
# `RequestRecordPatch` is prepended to the real class -- is asserted separately by
# Security::Invariants::RailsPerformanceRouteInvariantTest's sibling checks and by the container
# run recorded in evidence/.
class RailsPerformanceRecordSanitizerTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  SECRET = "s3cr3t-authorization-code"

  test "a query string is removed from the path rather than filtered" do
    assert_equal "/oauth/callback",
                 RailsPerformanceRecordSanitizer.sanitize_path("/oauth/callback?code=#{SECRET}&state=xyz")
  end

  test "a fragment is removed from the path" do
    assert_equal "/settings", RailsPerformanceRecordSanitizer.sanitize_path("/settings#token=#{SECRET}")
  end

  test "a path with no query string is stored unchanged" do
    assert_equal "/api/v0/entries", RailsPerformanceRecordSanitizer.sanitize_path("/api/v0/entries")
  end

  test "a referer keeps its origin and path and loses everything after them" do
    assert_equal "https://auth.umaxica.app/oauth/callback",
                 RailsPerformanceRecordSanitizer.sanitize_referer(
                   "https://auth.umaxica.app/oauth/callback?code=#{SECRET}&state=xyz",
                 )
  end

  test "a referer that is not a URL is filtered whole rather than passed through" do
    assert_equal ObservabilityRedactor::REDACTED,
                 RailsPerformanceRecordSanitizer.sanitize_referer("javascript:alert(1)")
  end

  test "an exception is reduced to its class name, dropping the message" do
    assert_equal "ActiveRecord::RecordInvalid",
                 RailsPerformanceRecordSanitizer.sanitize_exception(
                   "ActiveRecord::RecordInvalid Validation failed: token #{SECRET}",
                 )
  end

  test "nil stays nil for every field" do
    assert_nil RailsPerformanceRecordSanitizer.sanitize_path(nil)
    assert_nil RailsPerformanceRecordSanitizer.sanitize_referer(nil)
    assert_nil RailsPerformanceRecordSanitizer.sanitize_exception(nil)
  end

  # The point of the whole file, stated as one assertion: whatever the shape of the input, the
  # secret must not survive into anything handed to the store.
  test "no sanitised field carries a secret through" do
    sanitised = [
      RailsPerformanceRecordSanitizer.sanitize_path("/callback?code=#{SECRET}"),
      RailsPerformanceRecordSanitizer.sanitize_path("/callback?access_token=#{SECRET}"),
      RailsPerformanceRecordSanitizer.sanitize_referer("https://auth.umaxica.app/cb?refresh_token=#{SECRET}"),
      RailsPerformanceRecordSanitizer.sanitize_referer("https://auth.umaxica.app/cb#otp=#{SECRET}"),
      RailsPerformanceRecordSanitizer.sanitize_exception("Net::HTTPError password=#{SECRET}"),
    ]

    sanitised.each do |value|
      assert_not_includes value.to_s, SECRET,
                          "#{value.inspect} still carries the secret. Every one of these values is written " \
                          "to Valkey and kept for four hours, where `redis.keys` and any operator " \
                          "connection can read it."
    end
  end

  # The patch is what puts the sanitiser on the write path. Redacting at read time instead would
  # leave the secret sitting in the store.
  test "the patch sanitises on the way to the store and then delegates" do
    recorder = Class.new do
      attr_accessor :path, :http_referer, :exception
      attr_reader :saved

      def initialize(path:, http_referer:, exception:)
        @path = path
        @http_referer = http_referer
        @exception = exception
        @saved = false
      end

      def save
        @saved = true
      end
    end
    recorder.prepend(RailsPerformanceRecordSanitizer::RequestRecordPatch)

    record = recorder.new(
      path: "/callback?code=#{SECRET}",
      http_referer: "https://auth.umaxica.app/cb?state=#{SECRET}",
      exception: "RuntimeError leaked #{SECRET}",
    )
    record.save

    assert record.saved, "The patch must call super; a patch that swallows the write silently disables " \
                         "the dashboard."
    assert_equal "/callback", record.path
    assert_equal "https://auth.umaxica.app/cb", record.http_referer
    assert_equal "RuntimeError", record.exception
  end
end

# rubocop:enable I18n/RailsI18n/DecorateString
