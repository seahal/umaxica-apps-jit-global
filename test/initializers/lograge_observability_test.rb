# frozen_string_literal: true

require "test_helper"
require "opentelemetry-api"

class LogrageObservabilityTest < ActiveSupport::TestCase
  Event = Struct.new(:payload)

  test "access options contain request, trace, and span correlation ids" do
    trace_id = "4bf92f3577b34da6a3ce929d0e0e4736"
    span_id = "00f067aa0ba902b7"
    span = OpenTelemetry::Trace::Span.new(
      span_context: OpenTelemetry::Trace::SpanContext.new(
        trace_id: [trace_id].pack("H*"),
        span_id: [span_id].pack("H*"),
      ),
    )

    options = nil
    OpenTelemetry::Trace.stub(:current_span, span) do
      options = Rails.application.config.lograge.custom_options.call(
        Event.new({ request_id: "request-id", host: "example.test" }),
      )
    end

    assert_equal "request-id", options.fetch(:request_id)
    assert_equal "example.test", options.fetch(:host)
    assert_equal trace_id, options.fetch(:trace_id)
    assert_equal span_id, options.fetch(:span_id)
  end

  test "access options omit trace and span ids when the current context is invalid" do
    options =
      OpenTelemetry::Trace.stub(:current_span, OpenTelemetry::Trace::Span::INVALID) do
        Rails.application.config.lograge.custom_options.call(
          Event.new({ request_id: "request-id", host: "example.test" }),
        )
      end

    assert_equal "request-id", options.fetch(:request_id)
    assert_equal "example.test", options.fetch(:host)
    assert_nil options[:trace_id]
    assert_nil options[:span_id]
  end
end
