# frozen_string_literal: true

require "test_helper"

class DeprecationNotificationSubscriberTest < ActiveSupport::TestCase
  test "all values in an unquoted Cookie header are removed before logging" do
    logged_messages = []

    Rails.logger.stub(:warn, ->(entry) { logged_messages << entry }) do
      ActiveSupport::Notifications.instrument(
        "deprecation.library",
        message: "Deprecated Cookie: first=private-first; second=private-second\nUse the new API",
        callstack: ["vendor/library.rb:8"],
        gem_name: "Library",
        deprecation_horizon: "3.0",
      )
    end

    assert_equal 1, logged_messages.length
    assert_not_includes logged_messages.first, "private-first"
    assert_not_includes logged_messages.first, "private-second"
    assert_includes JSON.parse(logged_messages.first).fetch("data").fetch("message"), "Use the new API"
  end

  test "a Basic authorization credential in deprecation text is removed before logging" do
    logged_messages = []
    credential = Base64.strict_encode64("example-user:example-password")

    Rails.logger.stub(:warn, ->(entry) { logged_messages << entry }) do
      ActiveSupport::Notifications.instrument(
        "deprecation.library",
        message: "Deprecated header Authorization: Basic #{credential}",
        callstack: ["vendor/library.rb:8"],
        gem_name: "Library",
        deprecation_horizon: "3.0",
      )
    end

    assert_equal 1, logged_messages.length
    assert_not_includes logged_messages.first, credential
    assert_includes JSON.parse(logged_messages.first).fetch("data").fetch("message"), "[FILTERED]"
  end

  test "a notification emits one bounded warning without raw payload secrets or a full backtrace" do
    raw_token = "token=do-not-log-this"
    raw_url = "https://user:password@example.invalid/private/path?access_token=also-secret"
    raw_backtrace = "/home/person/private/file.rb:42:in `secret_frame'"
    raw_prefix = "deprecated #{raw_url} "
    safe_prefix_length = "deprecated [FILTERED_URL] ".length
    message = raw_prefix + ("x" * (989 - safe_prefix_length)) + " #{raw_token} tail"
    logged_messages = []

    Rails.logger.stub(:warn, ->(entry) { logged_messages << entry }) do
      ActiveSupport::Notifications.instrument(
        "deprecation.rails",
        message: message,
        callstack: [raw_backtrace],
        gem_name: "Rails",
        deprecation_horizon: "9.0",
        authorization: "Bearer do-not-forward",
        backtrace: [raw_backtrace],
        url: raw_url,
      )
    end

    assert_equal 1, logged_messages.length
    json = logged_messages.fetch(0)
    record = JSON.parse(json)
    data = record.fetch("data")

    assert_equal "rails.deprecation", record.fetch("event")
    assert_equal "Rails", data.fetch("gem_name")
    assert_equal "9.0", data.fetch("deprecation_horizon")
    assert_equal 0, Time.iso8601(data.fetch("at")).utc_offset
    assert_match(/\A[^\/].*\z/, data.dig("callsite", "file"))
    assert_equal 42, data.dig("callsite", "line")
    assert_includes data.fetch("message"), "[FILTERED]"
    assert_includes data.fetch("message"), "[FILTERED_URL]"
    assert_not_includes json, "do-not-log-this"
    assert_not_includes json, "also-secret"
    assert_not_includes json, "do-not-forward"
    assert_not_includes json, raw_backtrace
    assert_not_includes json, "secret_frame"
    assert data.fetch("truncated")
    assert_operator json.bytesize, :<=, 8 * 1024
    assert_predicate json, :valid_encoding?
  end

  test "message and metadata limits accept values below and at the boundary and cut values above it" do
    cases = [
      { label: "below", message: 999, gem: 99, horizon: 99, file: 511, expected_truncated: false },
      { label: "at", message: 1000, gem: 100, horizon: 100, file: 512, expected_truncated: false },
      { label: "above", message: 1001, gem: 101, horizon: 101, file: 513, expected_truncated: true },
    ]
    logged_messages = []

    Rails.logger.stub(:warn, ->(entry) { logged_messages << entry }) do
      cases.each do |boundary|
        ActiveSupport::Notifications.instrument(
          "deprecation.rails",
          message: "m" * boundary.fetch(:message),
          callstack: [("f" * boundary.fetch(:file)) + ":17"],
          gem_name: "g" * boundary.fetch(:gem),
          deprecation_horizon: "h" * boundary.fetch(:horizon),
        )
      end
    end

    assert_equal cases.length, logged_messages.length
    cases.each_with_index do |boundary, index|
      json = logged_messages.fetch(index)
      data = JSON.parse(json).fetch("data")
      expected_truncated = boundary.fetch(:expected_truncated)

      assert_equal [boundary.fetch(:message), 1000].min, data.fetch("message").length, boundary.fetch(:label)
      assert_equal [boundary.fetch(:gem), 100].min, data.fetch("gem_name").length, boundary.fetch(:label)
      assert_equal [boundary.fetch(:horizon), 100].min,
                   data.fetch("deprecation_horizon").length,
                   boundary.fetch(:label)
      assert_equal [boundary.fetch(:file), 512].min, data.dig("callsite", "file").length, boundary.fetch(:label)
      assert_equal expected_truncated, data.fetch("truncated", false), boundary.fetch(:label)
      assert_operator json.bytesize, :<=, 8 * 1024, boundary.fetch(:label)
    end
  end

  test "multibyte text stays valid UTF-8 and the JSON record stays within eight kibibytes" do
    logged_messages = []

    Rails.logger.stub(:warn, ->(entry) { logged_messages << entry }) do
      ActiveSupport::Notifications.instrument(
        "deprecation.library",
        message: "界" * 1001,
        callstack: ["vendor/library.rb:8"],
        gem_name: "Library",
        deprecation_horizon: "3.0",
      )
    end

    json = logged_messages.fetch(0)
    data = JSON.parse(json).fetch("data")

    assert_equal 1000, data.fetch("message").length
    assert_equal 3000, data.fetch("message").bytesize
    assert data.fetch("truncated")
    assert_operator json.bytesize, :<=, 8 * 1024
    assert_predicate json, :valid_encoding?
  end
end
