# typed: false
# frozen_string_literal: true

require "test_helper"

module Security
  module Invariants
    # ObservabilityRedactor is wired into Rails.logger (through JitLogEvent.format),
    # Sentry, and OpenTelemetry. It is NOT wired into Rails.event.
    #
    # Framework structured-event subscribers are attached by default and forward their
    # raw payloads to Rails.event with filtering explicitly disabled - for example
    # ActionController::StructuredEventSubscriber#emit_csrf_event forwards
    # payload[:message], which for a blocked request reads
    # "HTTP Origin header (...) didn't match request.base_url (...)", via
    # ActiveSupport.event_reporter.notify(..., filter_payload: false).
    #
    # Nothing receives those today because the only subscription is name-filtered. A
    # subscriber registered without a filter would immediately start receiving every
    # framework event, unredacted. Until the redactor covers Rails.event, every
    # subscription has to say which events it wants.
    class EventReporterSubscriptionInvariantTest < ActiveSupport::TestCase
      self.fixture_table_names = []

      SCANNED_GLOBS = %w(
        config/**/*.rb
        app/**/*.rb
        lib/**/*.rb
      ).freeze

      # A subscription is filtered when the call carries a block: Rails.event.subscribe
      # yields each event to the block and only delivers when it returns truthy.
      FILTER_MARKERS = [" do |", " do{", "{ |", "{|"].freeze

      test "every Rails.event subscription is name-filtered" do
        unfiltered =
          event_subscribe_call_sites.reject do |call_site|
            FILTER_MARKERS.any? { |marker| call_site.fetch(:source).include?(marker) }
          end

        assert_empty unfiltered.map { |c| "#{c.fetch(:path)}:#{c.fetch(:line)} -> #{c.fetch(:source)}" },
                     "Rails.event.subscribe without a filter block receives every framework event, " \
                     "including payloads that ObservabilityRedactor never sees. Pass a block that " \
                     "selects the event names this subscriber wants, or wire the redactor into " \
                     "Rails.event first."
      end

      test "the known subscription is still the CSP violation one" do
        call_sites = event_subscribe_call_sites

        assert_equal 1, call_sites.size,
                     "A Rails.event subscription was added or removed. Re-check that it is " \
                     "name-filtered and that its payload is safe to export: #{call_sites.inspect}"
        assert_equal "config/initializers/event_subscribers.rb", call_sites.first.fetch(:path)
      end

      private

      def event_subscribe_call_sites
        SCANNED_GLOBS.flat_map { |glob| Rails.root.glob(glob) }.uniq.flat_map do |path|
          relative = path.relative_path_from(Rails.root).to_s
          path.read.lines.each_with_index.filter_map do |line, index|
            stripped = line.strip
            next if stripped.start_with?("#")
            next unless stripped.include?("Rails.event.subscribe")

            { path: relative, line: index + 1, source: stripped }
          end
        end
      end
    end
  end
end
