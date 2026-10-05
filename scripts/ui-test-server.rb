# frozen_string_literal: true

# Run with: bin/rails runner -e test scripts/ui-test-server.rb
# This is a local browser-test harness, never an application entrypoint.
abort 'The isolated test environment is required' unless Rails.env.test?

require 'puma'
require Rails.root.join('test/support/outbound_http_guard')
require Rails.root.join('test/support/turnstile_verifier_stub')

# Keep the same process-local availability baseline as test/test_helper.rb.
# No callbacks are skipped and no authentication/session is manufactured.
adapter = Flipper::Adapters::Memory.new
Flipper.configure { |config| config.adapter { adapter } }
FqdnAvailabilityRegistry.flag_names.each { |flag| Flipper.enable(flag) }
Rails.configuration.x.turnstile.verifier = 'TurnstileVerifierStub'

server = Puma::Server.new(Rails.application)
server.add_tcp_listener('127.0.0.1', 3188)
server.run.join
