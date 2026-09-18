# typed: false
# frozen_string_literal: true

Rails.application.configure do
  config.lograge.enabled = !Rails.env.test?
  config.lograge.formatter = Lograge::Formatters::Json.new

  # Keep Lograge as one JSON object per line, independent of the application
  # logger formatter.
  config.lograge.logger =
    ActiveSupport::Logger.new($stdout).tap do |logger|
      logger.formatter = proc { |_severity, _datetime, _progname, message| "#{message}\n" }
    end

  config.lograge.custom_options =
    lambda do |event|
      observability_context = ObservabilityContextResolver.call

      {
        request_id: event.payload[:request_id],
        trace_id: observability_context.trace_id,
        span_id: observability_context.span_id,
        host: event.payload[:host],
      }.compact
    end
end
