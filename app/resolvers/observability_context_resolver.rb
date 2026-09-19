# typed: false
# frozen_string_literal: true

# Reads the current OpenTelemetry span without creating a tracing context or
# substituting an HTTP request identifier for a trace identifier.
class ObservabilityContextResolver
  class << self
    public

    def call
      return ObservabilityContextValue::EMPTY unless defined?(OpenTelemetry::Trace)

      context = OpenTelemetry::Trace.current_span.context
      return ObservabilityContextValue::EMPTY unless context.valid?

      ObservabilityContextValue.new(
        trace_id: context.hex_trace_id,
        span_id: context.hex_span_id,
      )
    end
  end
end
