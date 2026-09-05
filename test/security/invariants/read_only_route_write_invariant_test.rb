# typed: false
# frozen_string_literal: true

require "test_helper"

module Security
  module Invariants
    class ReadOnlyRouteWriteInvariantTest < ActionDispatch::IntegrationTest
      test "GET preference bootstrap writes are observable and allowlisted lifecycle exceptions" do
        host! "base.app.localhost"
        observed_writes = []

        callback =
          lambda do |_name, _started, _finished, _unique_id, payload|
            sql = payload[:sql].to_s.squish
            next unless sql.match?(/\A(?:INSERT|UPDATE|DELETE)\b/i)
            next if sql.match?(/\A(?:INSERT|UPDATE|DELETE)\s+"?ar_internal_metadata"?\b/i)
            next if sql.match?(/\A(?:INSERT|UPDATE|DELETE)\s+"?schema_migrations"?\b/i)

            observed_writes << sql
          end

        ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
          get "/preference?ri=jp"
        end

        assert_response :success
        assert_predicate observed_writes, :any?,
                         "cookie-less preference GET should currently bootstrap preference state"

        unallowlisted =
          observed_writes.reject do |sql|
            sql.match?(/\bapp_preferences\b/i) ||
              sql.match?(/\bapp_preference_/i) ||
              sql.match?(/\bsolid_queue_/i)
          end

        assert_empty unallowlisted, "GET/HEAD writes must be added to docs/security/db-write-allowlist.md"
      end
    end
  end
end
