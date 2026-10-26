# typed: false
# frozen_string_literal: true

require "test_helper"

module Security
  module Invariants
    # Every feature this application reads must be declared in FeatureFlags.
    #
    # A misspelled name is not an error in Flipper: it reads as "not enabled",
    # which silently means "not suspended" for a kill switch and "closed" for an
    # availability gate. Neither failure announces itself, and the operator sees
    # a switch that appears wired. Routing every read through the registry turns
    # that into an ArgumentError at the call site; this test keeps the bypass
    # closed.
    class FeatureFlagRegistryInvariantTest < ActiveSupport::TestCase
      self.fixture_table_names = []

      REGISTRY_PATH = "app/values/feature_flags.rb"

      # The registry itself performs the real read, the initializer configures
      # the adapter, and the routes mount the UI.
      DIRECT_READ_ALLOWLIST = [
        REGISTRY_PATH,
        "config/initializers/flipper.rb",
        "config/routes/base.rb",
        "db/seeds.rb",
      ].freeze

      DIRECT_READ_PATTERN = /\bFlipper\.enabled\?/

      test "no application source reads a feature outside the registry" do
        offenders =
          source_paths.reject { |path| DIRECT_READ_ALLOWLIST.include?(path) }
            .select { |path| File.read(path).match?(DIRECT_READ_PATTERN) }

        assert_empty offenders,
                     "call FeatureFlags.enabled? instead of Flipper.enabled? in: #{offenders.join(", ")}"
      end

      test "every declared feature name is registered" do
        declared =
          OutboundChannelSuspension::CHANNEL_FEATURE_NAMES.values +
          %i(
            sign_in_available_app sign_up_available_app
            sign_in_available_com sign_up_available_com
            sign_in_available_org sign_up_available_org
          ) +
          ExternalAuthentication::FlipperProviderAvailabilityAdapter::PROVIDER_FEATURE_NAMES.values +
          [TurnstileDegradation::FEATURE_NAME, RetentionPurgeJob::FEATURE_NAME]

        assert_empty declared.uniq - FeatureFlags.names
      end

      test "every registered feature declares a known polarity and an effect" do
        FeatureFlags::REGISTRY.each_value do |flag|
          assert_includes FeatureFlags::POLARITIES, flag.polarity, flag.name.to_s
          assert_predicate flag.effect, :present?, flag.name.to_s
        end
      end

      test "reading an unregistered feature is an error rather than a silent false" do
        error = assert_raises(ArgumentError) { FeatureFlags.enabled?(:outbund_push_suspended) }

        assert_match(/unregistered feature flag/, error.message)
      end

      private

      def source_paths
        Dir.glob("{app,lib,config,db}/**/*.rb", base: Rails.root).select do |path|
          Rails.root.join(path).file?
        end
      end
    end
  end
end
