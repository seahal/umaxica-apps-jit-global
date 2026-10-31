# frozen_string_literal: true

require "test_helper"

class ComPreferenceIssuanceBoundaryTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "com issuance preparation and emission have one application caller" do
    root = Rails.root.join("app")
    callers =
      Dir.glob(root.join("**/*.rb")).filter_map do |file|
        source = File.read(file)
        next unless source.match?(/\b(?:prepare_anonymous_com_token|emit_anonymous_com_token!)\s*\(/)

        Pathname.new(file).relative_path_from(root).to_s
      end

    assert_equal %w(controllers/concerns/preference_access_token_issuer.rb
                    controllers/concerns/preference_write_boundary.rb), callers.sort
  end

  test "com write entrance does not call the legacy refresh creation path" do
    source = Rails.root.join("app/controllers/concerns/preference_write_boundary.rb").read

    forbidden = /\b(?:persist_new_preference_record!|create_new_preference_record!|generate_refresh_token)(?!\w)/

    assert_no_match forbidden, source
  end
end
