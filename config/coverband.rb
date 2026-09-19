# typed: false
# frozen_string_literal: true

# Coverband's configuration, and it has to be this file at this path.
#
# `Coverband::Railtie` hooks `before_configuration` -- which fires when the Rails::Application
# subclass in config/application.rb is defined -- and calls `Coverband.configure`, which with no
# argument loads `./config/coverband.rb`. config/initializers/* has not been read at that point and
# will not be for some time, so configuration placed there would apply after the collector had
# already started with gem defaults, including a Redis client pointed at localhost.
#
# Nothing here is guarded by `Rails.env.development?`: the gem is `group :development` with
# `require: false`, and config/application.rb requires it only when
# `CoverbandProcessGate.measuring?` says this process serves requests. If this file is being read
# at all, both of those already decided yes.

require_relative "../lib/umaxica/valkey/error"
require_relative "../lib/umaxica/valkey/configuration_error"
require_relative "../lib/umaxica/valkey/settings"

Coverband.configure do |config|
  # Fails the boot when diagnostic Valkey settings are missing. Coverband otherwise
  # falls back to redis://127.0.0.1:6379/0 -- the application cache.
  coverband_valkey = Umaxica::Valkey::Settings.current.coverband

  # HashRedisStore keeps one hash per file rather than one key per line, which is what makes the
  # key count a function of the repository rather than of traffic. The namespace is belt and braces:
  # this responsibility already has its own logical database, so the prefix exists so that a human
  # reading a key dump can tell at a glance whose data they are looking at.
  config.store = Coverband::Adapters::HashRedisStore.new(
    Redis.new(url: coverband_valkey.url, driver: :hiredis),
    redis_namespace: "coverband",
  )

  # One-shot line coverage. Ruby's Coverage.start(oneshot_lines: true) stops counting a line after
  # its first execution, which is dramatically cheaper than maintaining a counter per line on every
  # request -- the reason it is worth having on a request path at all.
  #
  # The trade is that the data answers "did this line ever run" and nothing else. Execution counts
  # are not merely unreported, they are never collected, so the dashboard cannot rank hot code and
  # this store can never be used to answer a performance question. That is the performance
  # dashboard's job. Recorded in adr/diagnostic-surfaces-performance-coverband-swagger.md.
  config.use_oneshot_lines_coverage = true

  # Ruby only. View, route, and translation tracking each add their own instrumentation to the
  # request path and answer a different question than "which Ruby executed", which is the one this
  # surface was introduced for.
  config.track_views = false
  config.track_routes = false
  config.track_translations = false
  config.track_query_bursts = false

  # Read-only dashboard. `web_enable_clear` already defaults to false; it is stated because the
  # clear action wipes the entire coverage dataset, and a default is not where a destructive
  # capability should be left to rest.
  config.web_enable_clear = false

  # Do not expose the configuration dump in the web UI. It renders resolved settings, which is one
  # gem change away from rendering the store URL -- and these URLs can carry credentials.
  config.hide_settings = true

  # Coverband 6.2 ships an MCP server that answers coverage queries over an unauthenticated
  # protocol of its own, entirely outside this application's host constraints and Basic Auth.
  # It defaults to off; stated for the same reason as web_enable_clear.
  config.mcp_enabled = false

  # Quiet. `verbose` logs every store round trip.
  config.verbose = false
end
