# typed: false
# frozen_string_literal: true

require "test_helper"

# A security decision that cannot be applied must not be left looking active. If
# an effect is rejected, the case is marked failed and the error is re-raised so
# the caller sees it -- swallowing it would leave a case that reads as applied
# while none of its effects ran.
class EnforcementCaseApplyFailureTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class FakeCase
    def self.transaction = yield

    attr_accessor :state
    attr_reader :persisted

    def initialize(persisted:)
      @persisted = persisted
      @state = "draft"
    end

    def persisted? = persisted

    def update_column(name, value)
      instance_variable_set(:"@#{name}", value)
    end

    def revoke_method_sessions! = raise(ActiveRecord::RecordNotUnique, "duplicate revocation")

    def write_audit_event_once!(_name) = true

    def principal_effect = nil

    def public_id = "case-public-id"

    def principal_public_id = "principal-public-id"

    def kind = "cooldown"

    def requires_approval? = false

    def transition_to_active! = @state = "active"

    def update!(**) = true

    def close_superseded_effects! = true

    def save!(**) = true

    def apply_principal_effect! = true
  end

  test "a rejected effect marks the case failed and re-raises" do
    enforcement_case = FakeCase.new(persisted: true)

    assert_raises(ActiveRecord::RecordNotUnique) do
      EnforcementCaseApplyOperation.call(enforcement_case: enforcement_case)
    end

    assert_equal "failed", enforcement_case.state
  end

  test "a case that was never persisted is re-raised without being marked failed" do
    enforcement_case = FakeCase.new(persisted: false)

    assert_raises(ActiveRecord::RecordNotUnique) do
      EnforcementCaseApplyOperation.call(enforcement_case: enforcement_case)
    end

    # The state transition itself committed; only the "failed" marking is skipped
    # for a case that has no row to mark.
    assert_equal "active", enforcement_case.state
  end
end
