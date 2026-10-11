# frozen_string_literal: true

require "test_helper"
require "opentelemetry-api"

class ObservabilityContextResolverTest < ActiveSupport::TestCase
  test "returns lowercase OpenTelemetry trace and span ids from a valid span context" do
    trace_id = "4bf92f3577b34da6a3ce929d0e0e4736"
    span_id = "00f067aa0ba902b7"
    span = OpenTelemetry::Trace::Span.new(
      span_context: OpenTelemetry::Trace::SpanContext.new(
        trace_id: [trace_id].pack("H*"),
        span_id: [span_id].pack("H*"),
      ),
    )

    result = nil
    OpenTelemetry::Trace.stub(:current_span, span) do
      result = ObservabilityContextResolver.call
    end

    assert_equal trace_id, result.trace_id
    assert_equal span_id, result.span_id
    assert_match(/\A[0-9a-f]{32}\z/, result.trace_id)
    assert_match(/\A[0-9a-f]{16}\z/, result.span_id)
  end

  test "returns empty ids for an invalid span context" do
    result = nil
    OpenTelemetry::Trace.stub(:current_span, OpenTelemetry::Trace::Span::INVALID) do
      result = ObservabilityContextResolver.call
    end

    assert_nil result.trace_id
    assert_nil result.span_id
  end

  test "does not retain a valid span context after the current context is restored" do
    trace_id = "4bf92f3577b34da6a3ce929d0e0e4736"
    span_id = "00f067aa0ba902b7"
    span = OpenTelemetry::Trace::Span.new(
      span_context: OpenTelemetry::Trace::SpanContext.new(
        trace_id: [trace_id].pack("H*"),
        span_id: [span_id].pack("H*"),
      ),
    )

    inside = nil
    outside = nil
    OpenTelemetry::Trace.stub(:current_span, span) do
      inside = ObservabilityContextResolver.call
    end
    OpenTelemetry::Trace.stub(:current_span, OpenTelemetry::Trace::Span::INVALID) do
      outside = ObservabilityContextResolver.call
    end

    assert_equal trace_id, inside.trace_id
    assert_equal span_id, inside.span_id
    assert_nil outside.trace_id
    assert_nil outside.span_id
  end
end
