# typed: false
# frozen_string_literal: true

Rails.application.configure do
  config.lograge.enabled = !Rails.env.test?
  config.lograge.formatter = Lograge::Formatters::Json.new

  # Keep Lograge as one JSON object per line, independent of the application
  # logger formatter.
  raw_line = proc { |_severity, _datetime, _progname, message| "#{message}\n" }

  access_log_sinks = [ActiveSupport::Logger.new($stdout).tap { |logger| logger.formatter = raw_line }]

  if Rails.env.development?
    # Development also writes the access log to a file so Alloy can tail it into
    # Loki. Host-native Rails' stdout is a terminal on the host, which no
    # container can read, so the file is the only transport that serves the
    # host-native and Dev Container topologies alike
    # (adr/application-logging-boundary.md).
    #
    # A dedicated file rather than `log/development.log`: Lograge owns
    # request-completion access logs and `Rails.logger` owns application logs,
    # and docs/security/observability-boundary.md keeps those layers apart. One
    # file would merge them again and give Loki a single undifferentiated stream.
    #
    # Rotation belongs here, not to Loki: 3 files of 16 MB caps the repository
    # log directory whether or not the observability stack is running. Loki's own
    # 24h retention (podman/loki/loki.yaml) bounds the shipped copy.
    #
    # Stdout stays in the list, so the developer's terminal is unchanged and
    # production — which never reaches this branch — keeps its stdout-only
    # contract.
    access_log_path = Rails.root.join("log/development.access.jsonl")
    access_log_sinks << ActiveSupport::Logger.new(access_log_path, 3, 16.megabytes).tap do |logger|
      logger.formatter = raw_line
    end
  end

  config.lograge.logger =
    (access_log_sinks.one? ? access_log_sinks.first : ActiveSupport::BroadcastLogger.new(*access_log_sinks))

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
