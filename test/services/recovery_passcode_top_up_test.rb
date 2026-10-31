# frozen_string_literal: true

require "test_helper"

class RecoveryPasscodeTopUpTest < ActiveSupport::TestCase
  test "app Secret is refused by the retired recovery top-up contract without issuance" do
    actor = clients(:one)
    assert_no_difference("ClientSecretCredential.count") do
      assert_no_difference("ClientSecretIssuance.count") do
        assert_raises(ArgumentError) do
          RecoveryPasscodeTopUp.call(actor: actor, credential_class: ClientSecretCredential)
        end
        assert_raises(ArgumentError) do
          SignRecoveryPasscodeRequirement.usable_unused_count(actor: actor, credential_class: ClientSecretCredential)
        end
      end
    end
  end

  test "org without a recovery kind retains its empty top-up result" do
    result = RecoveryPasscodeTopUp.call(actor: operators(:one), credential_class: OperatorSecretCredential)

    assert_equal 0, result.issued_count
    assert_equal 0, result.active_usable_count_before
    assert_equal 0, result.active_usable_count_after
    assert_empty result.new_credentials
    assert_empty result.raw_values
  end
end
