# typed: false
# frozen_string_literal: true

# rubocop:disable I18n/RailsI18n/DecorateString

require "test_helper"

module Security
  module Invariants
    # Rails 8.2 introduced a CSRF verification strategy, selected with
    # `protect_from_forgery using:`:
    #
    #   :header_only            - trust Sec-Fetch-Site alone; reject anything without it
    #   :header_or_legacy_token - check Sec-Fetch-Site, fall back to the authenticity
    #                             token when the header is missing or "none"
    #
    # config.load_defaults(8.2) sets the framework-wide default to :header_only
    # (config/application.rb:36). This application deliberately runs the hybrid
    # strategy so browsers that do not send Fetch Metadata headers still work, which
    # means every declaration has to say so: omitting `using:` silently inherits the
    # stricter framework default rather than the application's choice.
    class CsrfVerificationStrategyInvariantTest < ActiveSupport::TestCase
      self.fixture_table_names = []

      EXPECTED_STRATEGY = :header_or_legacy_token

      test "every protect_from_forgery declaration states its verification strategy" do
        missing =
          protect_from_forgery_declarations.reject { |declaration| declaration.fetch(:source).include?("using:") }

        assert_empty missing.map { |d| "#{d.fetch(:path)}:#{d.fetch(:line)}" },
                     "These declarations omit `using:` and therefore inherit " \
                     ":header_only from load_defaults(8.2), which is stricter than this " \
                     "application's chosen strategy and rejects browsers without Sec-Fetch-Site."
      end

      test "every browser surface uses the standard hybrid strategy without endpoint exceptions" do
        unexpected =
          protect_from_forgery_declarations.filter_map do |declaration|
            next if declaration.fetch(:source).include?("using: :#{EXPECTED_STRATEGY}")

            "#{declaration.fetch(:path)}:#{declaration.fetch(:line)} -> #{declaration.fetch(:source)}"
          end

        assert_empty unexpected,
                     "Every browser endpoint must use :#{EXPECTED_STRATEGY}; protocol controllers have no browser CSRF."
      end

      test "the framework default is the strict strategy, so the explicit option is load-bearing" do
        assert_equal :header_only, Rails.configuration.action_controller.forgery_protection_verification_strategy,
                     "If load_defaults ever stops setting :header_only, revisit this invariant - " \
                     "the explicit `using:` on every controller is what currently selects the hybrid strategy."
        assert_equal :exception, ActionController::Base.default_protect_from_forgery_with,
                     "A blocked request must raise, not silently null the session."
      end

      test "the resolved strategy on a representative controller is the hybrid one" do
        assert_equal EXPECTED_STRATEGY,
                     ApplicationController.forgery_protection_verification_strategy
        assert_equal ActionController::RequestForgeryProtection::ProtectionMethods::Exception,
                     ApplicationController.forgery_protection_strategy
      end

      private

      def protect_from_forgery_declarations
        Rails.root.glob("app/controllers/**/*.rb").flat_map do |path|
          relative = path.relative_path_from(Rails.root).to_s
          path.read.lines.each_with_index.filter_map do |line, index|
            next unless line.include?("protect_from_forgery")
            next if line.strip.start_with?("#")

            { path: relative, line: index + 1, source: line.strip }
          end
        end
      end
    end
  end
end

# rubocop:enable I18n/RailsI18n/DecorateString
