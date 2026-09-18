# typed: false
# frozen_string_literal: true

# The request correlation identifier and OpenTelemetry identifiers have
# different authorities. This value carries only identifiers read from the
# current OpenTelemetry span.
class ObservabilityContextValue < Data.define(:trace_id, :span_id)
  EMPTY = new(trace_id: nil, span_id: nil)
end
