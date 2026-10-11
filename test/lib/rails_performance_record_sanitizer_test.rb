# frozen_string_literal: true

require "test_helper"

class RailsPerformanceRecordSanitizerTest < ActiveSupport::TestCase
  test "sanitize_path strips query strings and fragments" do
    assert_nil RailsPerformanceRecordSanitizer.sanitize_path(nil)
    assert_equal "/sign/in", RailsPerformanceRecordSanitizer.sanitize_path("/sign/in?code=secret&state=1")
    assert_equal "/sign/in", RailsPerformanceRecordSanitizer.sanitize_path("/sign/in#frag")
  end

  test "sanitize_referer reduces a referer to origin and path" do
    assert_nil RailsPerformanceRecordSanitizer.sanitize_referer(nil)
    scrubbed = RailsPerformanceRecordSanitizer.sanitize_referer("https://auth.example/callback?code=abc")

    assert_kind_of String, scrubbed
    assert_not_includes scrubbed, "code=abc"
  end

  test "sanitize_exception keeps only the class name" do
    assert_nil RailsPerformanceRecordSanitizer.sanitize_exception(nil)
    assert_equal "", RailsPerformanceRecordSanitizer.sanitize_exception("")
    assert_equal "RuntimeError",
                 RailsPerformanceRecordSanitizer.sanitize_exception("RuntimeError token=super-secret")
  end
end
