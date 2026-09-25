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

      # Endpoints that intentionally require Sec-Fetch-Site with no token fallback.
      # These are cross-site POSTs from a trusted origin where no session-bound
      # authenticity token can exist, so the header is the only real signal and a
      # token fallback would weaken them.
      HEADER_ONLY_EXCEPTIONS = {
        "app/controllers/base/app/oidc/logouts_controller.rb" =>
          "RP-initiated logout POST, guarded by an explicit trusted_origins allowlist",
        "app/controllers/base/com/oidc/logouts_controller.rb" =>
          "Corporate RP-initiated logout POST, guarded by its surface-local trusted_origins allowlist",
        "app/controllers/base/org/oidc/logouts_controller.rb" =>
          "Staff RP-initiated logout POST, guarded by its surface-local trusted_origins allowlist",
      }.freeze

      test "every protect_from_forgery declaration states its verification strategy" do
        missing =
          protect_from_forgery_declarations.reject { |declaration| declaration.fetch(:source).include?("using:") }

        assert_empty missing.map { |d| "#{d.fetch(:path)}:#{d.fetch(:line)}" },
                     "These declarations omit `using:` and therefore inherit " \
                     ":header_only from load_defaults(8.2), which is stricter than this " \
                     "application's chosen strategy and rejects browsers without Sec-Fetch-Site."
      end

      test "every surface uses the hybrid strategy except the reviewed header-only endpoints" do
        unexpected =
          protect_from_forgery_declarations.filter_map do |declaration|
            next if declaration.fetch(:source).include?("using: :#{EXPECTED_STRATEGY}")
            next if HEADER_ONLY_EXCEPTIONS.key?(declaration.fetch(:path))

            "#{declaration.fetch(:path)}:#{declaration.fetch(:line)} -> #{declaration.fetch(:source)}"
          end

        assert_empty unexpected,
                     "Unreviewed CSRF verification strategy. Either use :#{EXPECTED_STRATEGY} or " \
                     "record the endpoint in HEADER_ONLY_EXCEPTIONS with the reason."
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
          # relative_path_from keeps this stable regardless of how Rails.root
          # interpolates; HEADER_ONLY_EXCEPTIONS is keyed without a leading slash.
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
