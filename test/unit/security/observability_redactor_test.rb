# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class ObservabilityRedactorTest < ActiveSupport::TestCase
  test "scrubs nested sensitive values and urls" do
    value = ObservabilityRedactor.scrub(
      {
        email: "person@example.com",
        token: "secret-token",
        nested: [
          { cookie: "a=b", original_url: "https://example.com/path?code=abc&state=xyz" },
          { url: "https://example.com/inside?rt=token" },
        ],
      },
    )

    assert_equal "[FILTERED]", value[:email]
    assert_equal "[FILTERED]", value[:token]
    assert_equal "[FILTERED]", value[:nested][0][:cookie]
    assert_equal "https://example.com/path", value[:nested][0][:original_url]
    assert_equal "https://example.com/inside", value[:nested][1][:url]
  end

  test "scrubs query-bearing strings" do
    assert_equal "https://example.com/path", ObservabilityRedactor.scrub("https://example.com/path?jwt=abc")
  end

  test "scrubs token-shaped values inside free-form diagnostic strings" do
    raw_jwt = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJzZWNyZXQifQ.signature-value"

    value = ObservabilityRedactor.scrub("verification failed: #{raw_jwt}; Bearer access-token-value")

    assert_equal "verification failed: [FILTERED]; [FILTERED]", value
  end

  test "scrubs named credential values inside free-form diagnostic strings" do
    value = ObservabilityRedactor.scrub("failure token=secret-value access_token: another-secret")

    assert_equal "failure [FILTERED] [FILTERED]", value
  end

  test "scrub_url returns REDACTED for an unparseable URI" do
    assert_equal ObservabilityRedactor::REDACTED, ObservabilityRedactor.scrub_url("https://[invalid")

    assert_equal(
      { "original_url" => ObservabilityRedactor::REDACTED },
      ObservabilityRedactor.scrub("original_url" => "https://[invalid-bracket"),
    )
  end

  test "scrub leaves non-HTTP strings starting with https scheme prefix unchanged" do
    assert_equal "not a url", ObservabilityRedactor.scrub("not a url")
  end

  test "scrub leaves non-container scalar values unchanged via the else branch" do
    assert_equal 42, ObservabilityRedactor.scrub(42)
    assert ObservabilityRedactor.scrub(true)
    assert_nil ObservabilityRedactor.scrub(nil)
  end

  test "scrub_url redacts a nil value outright" do
    assert_equal ObservabilityRedactor::REDACTED, ObservabilityRedactor.scrub_url(nil)
  end

  test "scrub_url keeps an explicit non-default https port" do
    assert_equal "https://example.com:8443/path", ObservabilityRedactor.scrub_url("https://example.com:8443/path?jwt=secret")
  end

  test "scrub_url keeps an explicit non-default http port and strips the default https port" do
    assert_equal "http://example.com:8080/path", ObservabilityRedactor.scrub_url("http://example.com:8080/path?code=x")
    assert_equal "https://example.com/path", ObservabilityRedactor.scrub_url("https://example.com:443/path?jwt=x")
  end

  test "scrub_url normalizes a bare host to a root path" do
    assert_equal "https://example.com/", ObservabilityRedactor.scrub_url("https://example.com?jwt=secret")
    assert_equal "https://example.com/", ObservabilityRedactor.scrub_url("https://example.com")
  end

  test "sensitive_key? allowlist leaves non-sensitive observability keys unredacted" do
    result = ObservabilityRedactor.scrub(
      {
        event_uuid: "evt-1",
        payload_digest: "abc",
        payload_digest12: "def",
        content_length: 10,
        message_parts: 3,
        normal_key: "keep",
      },
    )

    assert_equal "evt-1", result[:event_uuid]
    assert_equal "abc", result[:payload_digest]
    assert_equal "def", result[:payload_digest12]
    assert_equal 10, result[:content_length]
    assert_equal 3, result[:message_parts]
    assert_equal "keep", result[:normal_key]
  end
end
