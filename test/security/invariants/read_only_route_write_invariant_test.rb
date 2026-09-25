# typed: false
# frozen_string_literal: true

require "test_helper"

module Security
  module Invariants
    class ReadOnlyRouteWriteInvariantTest < ActionDispatch::IntegrationTest
      test "ordinary Base GET navigation does not write authentication or preference state" do
        observed_writes = []

        callback =
          lambda do |_name, _started, _finished, _unique_id, payload|
            sql = payload[:sql].to_s.squish
            next unless sql.match?(/\A(?:INSERT|UPDATE|DELETE)\b/i)
            next if sql.match?(/\A(?:INSERT|UPDATE|DELETE)\s+"?ar_internal_metadata"?\b/i)
            next if sql.match?(/\A(?:INSERT|UPDATE|DELETE)\s+"?schema_migrations"?\b/i)

            observed_writes << sql
          end

        surfaces = [
          ["app", "base.app.localhost"],
          ["com", "base.com.localhost"],
          ["org", "base.org.localhost"],
        ]
        paths = [
          ["/", :success],
          ["/dashboard", :see_other],
          ["/preference", :success],
          ["/preference/region/edit", :success],
          ["/preference/theme/edit", :success],
          ["/sign/out/edit", :success],
        ]
        methods = [
          "GET",
          "HEAD",
        ]

        surfaces.each do |surface, host|
          methods.each do |method_name|
            paths.each do |path, expected_status|
              reset!
              host! host
              observed_writes.clear

              ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
                if method_name == "GET"
                  get "#{path}?ri=jp"
                else
                  head "#{path}?ri=jp"
                end
              end

              assert_response expected_status, "#{surface} #{method_name} #{path} response"
              assert_empty observed_writes,
                           "#{surface} #{method_name} #{path} must not persist preference or auth state"
            end
          end
        end
      end
    end
  end
end
