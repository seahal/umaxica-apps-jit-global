# typed: false
# frozen_string_literal: true

return if Rails.env.test?

# `compose.yaml` declares OPEN_TELEMETRY on `core` and sets it to "true": the
# observability group is no longer profile-gated, so `alloy` is always running
# and always able to receive.
#
# The gate stays because `core` also runs outside Compose -- a host `bin/rails`,
# a CI job, a one-off `podman run` -- where no agent exists. Without it the SDK
# would initialise there too and export into a host that does not resolve,
# producing a steady trickle of exporter retry warnings.
#
# Two-argument fetch on purpose: this is a toggle with a meaningful off state,
# not required configuration whose absence should stop the boot. The default is
# off so that the no-agent environments above stay quiet without each having to
# set the variable.
return unless ENV.fetch("OPEN_TELEMETRY", "false") == "true"

require "opentelemetry/sdk"
require "opentelemetry/exporter/otlp"
require "opentelemetry/instrumentation/action_mailer"
require "opentelemetry/instrumentation/action_pack"
require "opentelemetry/instrumentation/action_view"
require "opentelemetry/instrumentation/active_job"
require "opentelemetry/instrumentation/active_record"
require "opentelemetry/instrumentation/active_support"
require "opentelemetry/instrumentation/concurrent_ruby"
require "opentelemetry/instrumentation/faraday"
require "opentelemetry/instrumentation/net/http"
require "opentelemetry/instrumentation/rack"
require "opentelemetry/instrumentation/redis"
require Rails.root.join("lib/observability_span_scrubber").to_s

OpenTelemetry::SDK.configure do |c|
  c.service_name = "umaxica-apps-jit"
  c.use("OpenTelemetry::Instrumentation::Rack")
  c.use("OpenTelemetry::Instrumentation::ActionPack")
  c.use("OpenTelemetry::Instrumentation::ActionView")
  c.use("OpenTelemetry::Instrumentation::ActiveSupport")
  c.use("OpenTelemetry::Instrumentation::ActiveRecord")
  c.use("OpenTelemetry::Instrumentation::ActionMailer")
  c.use("OpenTelemetry::Instrumentation::ActiveJob")
  c.use("OpenTelemetry::Instrumentation::ConcurrentRuby")
  c.use("OpenTelemetry::Instrumentation::Faraday")
  c.use("OpenTelemetry::Instrumentation::Net::HTTP")
  c.use("OpenTelemetry::Instrumentation::Redis")
  c.add_span_processor(
    Class.new do
      def on_start(*)
      end

      def on_finish(span)
        ObservabilitySpanScrubber.scrub(span)
      end

      def force_flush(*)
        true
      end

      def shutdown(*)
        true
      end
    end.new,
  )
end
