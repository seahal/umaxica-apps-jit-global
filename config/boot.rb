# typed: false
# frozen_string_literal: true

ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

# A browser E2E flag is valid only in an explicitly selected Rails test process.
if ENV["RAILS_BROWSER_E2E"] && !(ENV.fetch("RAILS_BROWSER_E2E") == "1" && ENV.fetch("RAILS_ENV") == "test")
  raise ArgumentError, "RAILS_BROWSER_E2E requires RAILS_ENV=test"
end

# Load the repository's non-secret local contract before Rails configuration is evaluated.
# Compose may provide topology, but the application reads the same contract on bare metal and
# in a Dev Container; it never needs Compose to decide its own configuration.
require_relative "../lib/local_environment"
LocalEnvironment.load!

require "bundler/setup" # Set up gems listed in the Gemfile.

# In the devcontainer the workspace (including tmp/cache) is a ZFS bind mount;
# test boots (16 parallel workers) hammer the bootsnap cache, so keep it on
# tmpfs-backed /tmp for tests. Dev keeps the default tmp/cache so the cache
# survives container restarts.
# RAILS_ENV is not yet set when `bin/rails test` boots, so also detect the
# test command from ARGV.
if ENV["RAILS_ENV"] == "test" || (defined?(ARGV) && ARGV.first == "test")
  ENV["BOOTSNAP_CACHE_DIR"] ||= "/tmp/bootsnap"
end

require "bootsnap/setup" # Speed up boot time by caching expensive operations.
