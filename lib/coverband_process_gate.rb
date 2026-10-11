# typed: false
# frozen_string_literal: true

# Decides whether this process should load and run Coverband at all.
#
# Coverband measures which Ruby lines actually execute. That question is only meaningful for the
# process serving requests. Every other process that boots this application would answer it wrongly
# and expensively:
#
#   rails console   one operator poking at a model marks that model's lines "executed in
#                   production", which is the opposite of what the dashboard is read for.
#   rake / bin/jobs task and job code paths are not request paths; recording them into the same
#                   store makes the coverage report describe a union of unrelated workloads.
#   rails test      the suite runs nearly everything. SimpleCov already measures test coverage, and
#                   letting Coverband see the suite would make its report meaningless. The gem is
#                   `group :development` so it is not even loadable here, but the gate does not
#                   depend on that for its correctness.
#
# So this is an allowlist, not a denylist: an unrecognised process does not measure. A denylist
# would silently start measuring in whatever new process type gets added next, and the failure mode
# of being wrong in that direction is a corrupted dataset that nobody can tell is corrupted.
#
# Loaded by config/application.rb before the Rails::Application subclass is defined, because
# Coverband's railtie hooks `before_configuration` -- which fires on that class definition -- to
# start itself. There is no Rails to lean on at that point, so this reads ARGV and $PROGRAM_NAME
# directly.
#
# Fork safety is the gem's own design and is not re-implemented here: `Coverband.start` skips the
# background reporting thread when `RackServerCheck.running?` is true, and
# `Coverband::BackgroundMiddleware` starts it on the first request each process handles instead.
# Under Puma with multiple workers that means each forked worker starts its own reporter after the
# fork, which is the only point at which a thread would survive.
module CoverbandProcessGate
  # `bin/rails server` (Procfile.dev's `web:` entry) and its alias.
  WEB_SERVER_COMMANDS = %w(server s).freeze

  # Puma booted directly, without going through the Rails CLI.
  WEB_SERVER_PROGRAM_PATTERN = /\Apuma/

  ENABLED_VARIABLE = "COVERBAND_ENABLED"

  module_function

  # @return [Boolean] true only for the process that serves HTTP requests, and only when Coverband
  #   is switched on.
  def measuring?(argv: ARGV, program_name: $PROGRAM_NAME, environment: ENV)
    return false unless enabled?(environment)

    web_server?(argv, program_name)
  end

  # Two-argument fetch on purpose: this is an optional switch with a meaningful default, not
  # required configuration. Anything other than the exact string "false" leaves Coverband on, so a
  # typo cannot silently disable observability.
  def enabled?(environment = ENV) = environment.fetch(ENABLED_VARIABLE, "true") != "false"

  def web_server?(argv = ARGV, program_name = $PROGRAM_NAME)
    return true if File.basename(program_name.to_s).match?(WEB_SERVER_PROGRAM_PATTERN)

    WEB_SERVER_COMMANDS.include?(argv.first.to_s)
  end
end
