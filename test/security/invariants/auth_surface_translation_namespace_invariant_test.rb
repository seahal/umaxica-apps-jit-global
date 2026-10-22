# typed: false
# frozen_string_literal: true

require "test_helper"

module Security
  module Invariants
    class AuthSurfaceTranslationNamespaceInvariantTest < ActiveSupport::TestCase
      self.fixture_table_names = []

      # adr/i18n-explicit-translation-keys.md keeps surface copy under its own sign.<surface>
      # namespace; the com and org Auth surfaces once borrowed sign.app copy.
      APP_TRANSLATION_KEY = /["'](?:views\.)?sign\.app\.[A-Za-z0-9_.]+["']/

      %w(com org).each do |surface|
        test "Auth #{surface} controllers and helpers reference no sign.app translation key" do
          offenders =
            Rails.root.glob("app/{controllers,helpers}/auth/#{surface}/**/*.rb").flat_map do |path|
              path.readlines.each_with_index.filter_map do |line, index|
                "#{path.relative_path_from(Rails.root)}:#{index + 1}" if line.match?(APP_TRANSLATION_KEY)
              end
            end

          assert_empty offenders
        end
      end
    end
  end
end
