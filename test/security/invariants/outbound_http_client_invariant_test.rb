# typed: false
# frozen_string_literal: true

require "test_helper"

module Security
  module Invariants
    # Outbound HTTP goes through OutboundHttp::Connection, which forces every
    # call site to state a timeout. Reaching for Net::HTTP directly bypasses
    # that: four call sites previously ran on the stdlib sixty-second default,
    # three of them on the sign-in path. Without this guard the pattern comes
    # back one call site at a time.
    class OutboundHttpClientInvariantTest < ActiveSupport::TestCase
      self.fixture_table_names = []

      SEARCH_ROOTS = %w(app lib).freeze

      # The factory selects Faraday's adapter; the adapter subclass is the only place that builds
      # Net::HTTP directly to pin a DNS answer after validating the complete public address set.
      ALLOWLIST = %w(
        app/lib/outbound_http/connection.rb
        app/lib/outbound_http/connection_adapter_port.rb
      ).freeze

      DIRECT_CLIENTS = /\b(?:Net::HTTP|URI\.open|OpenURI|HTTParty|RestClient|Excon|Typhoeus|HTTPX)\b/

      test "application code reaches external services through OutboundHttp::Connection" do
        offenders =
          SEARCH_ROOTS.flat_map { |root| Rails.root.glob("#{root}/**/*.rb") }.filter_map do |path|
            relative_path = path.relative_path_from(Rails.root).to_s
            next if ALLOWLIST.include?(relative_path)

            matches =
              path.readlines.each_with_index.filter_map do |line, index|
                next if line.lstrip.start_with?("#")

                "#{relative_path}:#{index + 1}" if line.match?(DIRECT_CLIENTS)
              end

            matches.presence
          end.flatten

        assert_empty(
          offenders,
          "Use OutboundHttp::Connection instead of a direct HTTP client:\n#{offenders.join("\n")}",
        )
      end

      # Faraday.default_adapter is shared with the OmniAuth, OAuth2, and
      # openid_connect chain. Reassigning it would change their transport as a
      # side effect of an unrelated application change.
      test "the Faraday global adapter is left alone" do
        offenders =
          (SEARCH_ROOTS + ["config"]).flat_map { |root| Rails.root.glob("#{root}/**/*.rb") }.filter_map do |path|
            relative_path = path.relative_path_from(Rails.root).to_s
            relative_path if path.read.match?(/Faraday\.default_adapter\s*=/)
          end

        assert_empty offenders, "Faraday.default_adapter must not be reassigned:\n#{offenders.join("\n")}"
      end
    end
  end
end
