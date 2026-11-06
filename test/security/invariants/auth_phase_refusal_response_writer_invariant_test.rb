# frozen_string_literal: true

require "test_helper"

class AuthPhaseRefusalResponseWriterInvariantTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  RESPONSE_OWNER = "app/controllers/concerns/sign_in_path_refusal.rb"

  test "phase-violation conflict body stays in the shared refusal responder" do
    references =
      Rails.root.glob("app/controllers/**/*.rb").filter_map do |path|
        relative_path = path.relative_path_from(Rails.root).to_s
        relative_path if File.read(path).include?("errors.messages.phase_violation_refused")
      end

    assert_equal [RESPONSE_OWNER], references,
                 "phase-violation response translation escaped its shared responder: #{references.join(", ")}"
    assert_match(
      /render plain: I18n\.t\("errors\.messages\.phase_violation_refused"\), status: :conflict/,
      Rails.root.join(RESPONSE_OWNER).read,
    )
  end
end
