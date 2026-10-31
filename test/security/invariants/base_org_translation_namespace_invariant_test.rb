# typed: false
# frozen_string_literal: true

require "test_helper"

module Security
  module Invariants
    class BaseOrgTranslationNamespaceInvariantTest < ActiveSupport::TestCase
      self.fixture_table_names = []

      # adr/i18n-explicit-translation-keys.md keeps surface copy under its own namespace.
      APP_TRANSLATION_KEY = /["'](?:views\.)?(?:sign|base)\.app\.[A-Za-z0-9_.]+["']/

      test "Base org controllers and helpers reference no sign.app or base.app translation key" do
        offenders =
          Rails.root.glob("app/{controllers,helpers}/base/org/**/*.rb").flat_map do |path|
            path.readlines.each_with_index.filter_map do |line, index|
              "#{path.relative_path_from(Rails.root)}:#{index + 1}" if line.match?(APP_TRANSLATION_KEY)
            end
          end

        assert_empty offenders
      end

      test "Base com controllers and helpers reference no sign.app or base.app translation key" do
        offenders =
          Rails.root.glob("app/{controllers,helpers}/base/com/**/*.rb").flat_map do |path|
            path.readlines.each_with_index.filter_map do |line, index|
              "#{path.relative_path_from(Rails.root)}:#{index + 1}" if line.match?(APP_TRANSLATION_KEY)
            end
          end

        assert_empty offenders
      end
    end
  end
end
