# typed: false
# frozen_string_literal: true

require "test_helper"

class AdmissionCurfewValueTest < ActiveSupport::TestCase
  test "the owner's database clock is the only boundary and exactly at curfew is expired" do
    decision_time = Time.zone.local(2026, 10, 24, 12, 30, 0)
    binding = ClientAuthAdmissionBinding.new(curfew_at: decision_time)

    ClientAuthAdmissionBinding.stub(:database_now, decision_time - 1.second) do
      assert_predicate AdmissionCurfewValue.for(binding), :within?
    end

    ClientAuthAdmissionBinding.stub(:database_now, decision_time) do
      assert_not_predicate AdmissionCurfewValue.for(binding), :within?
    end

    ClientAuthAdmissionBinding.stub(:database_now, decision_time + 1.second) do
      assert_not_predicate AdmissionCurfewValue.for(binding), :within?
    end
  end

  test "a missing curfew is rejected instead of becoming an open-ended attempt" do
    error =
      assert_raises(ArgumentError) do
        AdmissionCurfewValue.new(curfew_at: nil, decided_at: Time.current)
      end

    assert_equal "curfew_at is required", error.message
  end
end
