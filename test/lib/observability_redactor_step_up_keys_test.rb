# frozen_string_literal: true

require "test_helper"

class ObservabilityRedactorStepUpKeysTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  %w(error_code state_before state_after authentication_state).each do |key|
    test "the fixed-vocabulary key #{key} keeps its value" do
      assert_equal({ key => "transaction_conflict" }, ObservabilityRedactor.scrub({ key => "transaction_conflict" }))
    end
  end

  # Neighbouring names that are not in the allowlist stay filtered.
  %w(code state session_ref authentication_state_token error_code_token).each do |key|
    test "the key #{key} is still filtered" do
      assert_equal({ key => "[FILTERED]" }, ObservabilityRedactor.scrub({ key => "value" }))
    end
  end
end
