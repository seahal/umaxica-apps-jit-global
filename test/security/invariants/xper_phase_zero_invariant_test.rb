# frozen_string_literal: true

require "test_helper"
require "yaml"

module Security
  module Invariants
    class XperPhaseZeroInvariantTest < ActiveSupport::TestCase
      self.fixture_table_names = []

      test "Xper owns Importmap ERB layouts and excludes Vite Inertia and React pages" do
        stacks = YAML.safe_load_file(Rails.root.join("config/frontend_stacks.yml")).fetch("stacks")
        %w(app com org).each do |edition|
          layout = "xper/#{edition}/application"

          assert_includes stacks.fetch("importmap"), layout
          assert_not_includes stacks.fetch("vite"), layout
          assert_not Rails.root.join("app/views/layouts/xper/#{edition}/inertia.html.erb").exist?
          assert_empty Rails.root.glob("src/pages/xper/#{edition}/**/*")
          body = Rails.root.join("app/views/layouts/#{layout}.html.erb").read

          assert_includes body, "javascript_importmap_tags"
          assert_includes body, "stylesheet_link_tag"
          assert_no_match(/vite_|inertia|serviceWorker|manifest/i, body)
        end
      end

      test "Xper source has no preference actor hydration or Experience credential and persistence implementation" do
        paths = Rails.root.glob("app/controllers/xper/**/*.rb") + Rails.root.glob("app/views/**/xper/**/*.erb")

        assert_not_empty paths
        paths.each do |path|
          assert_no_match(
            /PreferenceGlobal|PreferenceBase|Actor\.preferences|SurfaceInertiaPage|experience_(?:access|refresh|dbsc)/,
            path.read, path.to_s,
          )
        end
        assert_empty Rails.root.glob("app/models/xper/**/*.rb")
        assert_empty Rails.root.glob("app/models/experience*.rb")
        assert_empty Rails.root.glob("app/**/experience*jwt*.rb")
        assert_empty Rails.root.glob("db/*xper*")
        assert_empty Rails.root.glob("db/*experience*")
      end
    end
  end
end
