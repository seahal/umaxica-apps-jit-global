# typed: false
# frozen_string_literal: true

require "test_helper"

class LifecycleDirectStateWriteInvariantTest < ActiveSupport::TestCase
  LIFECYCLE_CARRIERS = %w(
    ClientSignInFlow VisitorSignInFlow OperatorSignInFlow
    ClientSignUpFlow VisitorSignUpFlow OperatorSignUpFlow
    ClientSignOutFlow VisitorSignOutFlow OperatorSignOutFlow
  ).freeze
  TRANSITION_CONCERNS = %r{app/models/concerns/(flow_base|flow_sign_in|flow_sign_up|flow_sign_out|sign_flow|sign_out_flow|sign_up_flow_ticket|session_limit_resolution_transactionable)\.rb\z}
  NON_LIFECYCLE_WRITER_ALLOWLIST = %w(
    app/controllers/concerns/sign_up_sequence_controller_support.rb
  ).freeze
  STATE_WRITERS = /\b(?:update!|update_columns|update_all|assign_attributes|write_attribute)\s*\([^)]*\b(?:status_id|state_id|state|step)\b/m

  test "lifecycle state writes stay inside the transition concerns" do
    offenders = []

    (Rails.root.glob("app/**/*.rb") + Rails.root.glob("lib/**/*.rb")).each do |path|
      relative_path = Pathname(path).relative_path_from(Rails.root).to_s
      next if TRANSITION_CONCERNS.match?(relative_path)
      next if NON_LIFECYCLE_WRITER_ALLOWLIST.include?(relative_path)

      source = File.read(path)
      next unless LIFECYCLE_CARRIERS.any? { |carrier| source.include?(carrier) }
      next unless source.match?(STATE_WRITERS)

      offenders << relative_path
    end

    assert_empty offenders, "lifecycle state writers escaped transition concerns:\n#{offenders.join("\n")}"
  end

  test "production lifecycle code never selects the legacy failed terminal" do
    offenders = []
    transition_writer = /(?:transition_(?:sign_in|sign_up|sign_out)_to!|transition_cycle_to!)\s*\(\s*[\"']FAILED/
    legacy_event = /(?:event\s*:\s*|when\s+):fail\b/

    (Rails.root.glob("app/**/*.rb") + Rails.root.glob("lib/**/*.rb")).each do |path|
      relative_path = Pathname(path).relative_path_from(Rails.root).to_s
      source = File.read(path)
      offenders << relative_path if source.match?(transition_writer) || source.match?(legacy_event)
    end

    assert_empty offenders, "legacy FAILED lifecycle writer escaped the tombstone boundary:\n#{offenders.join("\n")}"
  end
end
