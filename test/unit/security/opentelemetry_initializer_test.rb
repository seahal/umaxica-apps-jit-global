# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class OpenTelemetryInitializerTest < ActiveSupport::TestCase
  test "uses explicit instrumentation list instead of use_all and scrubs spans" do
    source = Rails.root.join("config/initializers/opentelemetry.rb").read

    assert_no_match(/c\.use_all/, source)
    assert_includes source, 'c.use("OpenTelemetry::Instrumentation::Rack")'
    assert_includes source, 'c.use("OpenTelemetry::Instrumentation::ActiveRecord")'
    assert_includes source, "ObservabilitySpanScrubber"
  end

  test "configures ActionMailer instrumentation with fixed pre-export allowlists" do
    source = Rails.root.join("config/initializers/opentelemetry.rb").read

    assert_match(
      /c\.use\(\s*"OpenTelemetry::Instrumentation::ActionMailer".*?email_address:\s*:omit/m,
      source,
    )
    assert_includes source, "notification_payload_transform:"
    assert_includes source, "process_payload_transform:"
    assert_includes source, '"email.x_mailer"'
    assert_includes source, ":mailer"
    assert_includes source, ":action"
    assert_not_includes source, "email.subject"
    assert_not_includes source, "email.to.address"
    assert_not_includes source, "email.from.address"
    assert_not_includes source, ":args"
  end

  test "scrubs sensitive span attributes" do
    span = Struct.new(:attributes).new(
      {
        "http.url" => "https://example.com/path?token=secret",
        "http.request.header.authorization" => "Bearer secret",
        "http.response.header.set-cookie" => "session=secret",
        "custom" => { cookie: "secret" },
      },
    )

    span = ObservabilitySpanScrubber.scrub(span)

    assert_equal "[FILTERED]", span.attributes["http.url"]
    assert_equal "[FILTERED]", span.attributes["http.request.header.authorization"]
    assert_equal "[FILTERED]", span.attributes["http.response.header.set-cookie"]
    assert_equal "[FILTERED]", span.attributes["custom"][:cookie]
  end
end
