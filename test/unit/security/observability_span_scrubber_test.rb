# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class ObservabilitySpanScrubberTest < ActiveSupport::TestCase
  class MutableSpan
    attr_accessor :attributes

    def initialize(attributes)
      @attributes = attributes
    end
  end

  class ImmutableSpan
    attr_reader :attributes

    def initialize(attributes)
      @attributes = attributes
      @attributes_instance_variable = attributes
    end
  end

  test "scrub returns the span unchanged when attributes are not a hash" do
    span = MutableSpan.new(nil)

    assert_same span, ObservabilitySpanScrubber.scrub(span)
  end

  test "scrub mutates spans that expose an attributes writer" do
    span = MutableSpan.new("authorization" => "secret")

    _ = ObservabilitySpanScrubber.scrub(span)

    assert_equal ObservabilityRedactor::REDACTED, span.attributes["authorization"]
  end

  test "scrub falls back to instance_variable_set for immutable spans" do
    span = ImmutableSpan.new("authorization" => "secret")

    _ = ObservabilitySpanScrubber.scrub(span)

    assert_equal ObservabilityRedactor::REDACTED, span.instance_variable_get(:@attributes)["authorization"]
  end

  test "scrub_attribute leaves non-scrubbable values unchanged" do
    integer_value = 42

    assert_equal integer_value, ObservabilitySpanScrubber.scrub_attribute("foo", integer_value)
  end

  test "scrub_attribute scrubs nested sensitive values under a non-sensitive key" do
    span = MutableSpan.new("details" => "https://example.com/path?jwt=secret")

    _ = ObservabilitySpanScrubber.scrub(span)

    assert_equal "https://example.com/path", span.attributes["details"]
  end

  test "scrub_attribute scrubs Hash and Array values under a non-sensitive key" do
    span = MutableSpan.new(
      "payload" => { "token" => "secret" },
      "entries" => ["https://example.com/x?code=abc"],
    )

    _ = ObservabilitySpanScrubber.scrub(span)

    assert_equal ObservabilityRedactor::REDACTED, span.attributes["payload"]["token"]
    assert_equal "https://example.com/x", span.attributes["entries"].first
  end

  test "scrub redacts full-url attribute keys without delegating to URL parsing" do
    span = MutableSpan.new("http.url" => "https://app.example.com/callback?code=abc&state=xyz")

    _ = ObservabilitySpanScrubber.scrub(span)

    assert_equal ObservabilityRedactor::REDACTED, span.attributes["http.url"]
  end

  test "scrub redacts token-family attribute keys outright" do
    span = MutableSpan.new(
      "token" => "t",
      "access_token" => "at",
      "id_token" => "it",
      "refresh_token" => "rt",
    )

    _ = ObservabilitySpanScrubber.scrub(span)

    span.attributes.each_value { |value| assert_equal ObservabilityRedactor::REDACTED, value }
  end

  test "sensitive_attribute_key? matches authorization and cookie substrings" do
    span = MutableSpan.new(
      "x-custom-authorization" => "secret",
      "my-cookie-value" => "y",
    )

    _ = ObservabilitySpanScrubber.scrub(span)

    assert_equal ObservabilityRedactor::REDACTED, span.attributes["x-custom-authorization"]
    assert_equal ObservabilityRedactor::REDACTED, span.attributes["my-cookie-value"]
  end

  test "scrub redacts ActionMailer attributes that must not reach a trace" do
    span = MutableSpan.new(
      "email.subject" => "Your one-time verification code is 123456",
      "email.to.address" => "person@example.com",
      "email.body" => "Your code is 123456",
      "args" => [{ "otp_code" => "123456" }],
    )

    _ = ObservabilitySpanScrubber.scrub(span)

    assert_equal ObservabilityRedactor::REDACTED, span.attributes["email.subject"]
    assert_equal ObservabilityRedactor::REDACTED, span.attributes["email.to.address"]
    assert_equal ObservabilityRedactor::REDACTED, span.attributes["email.body"]
    assert_equal ObservabilityRedactor::REDACTED, span.attributes["args"]
  end

  test "scrub preserves the explicitly allowed ActionMailer mailer attribute" do
    span = MutableSpan.new("email.x_mailer" => "Email::App::OtpMailer")

    _ = ObservabilitySpanScrubber.scrub(span)

    assert_equal "Email::App::OtpMailer", span.attributes["email.x_mailer"]
  end
end
