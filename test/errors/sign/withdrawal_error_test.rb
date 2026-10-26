# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

module Sign
  class WithdrawalErrorTest < ActiveSupport::TestCase
    test "WithdrawalError initializes with i18n key and status code" do
      error = WithdrawalError.new("sign.withdrawal.errors.deletion_failed", :bad_request)

      assert_equal "sign.withdrawal.errors.deletion_failed", error.i18n_key
      assert_equal :bad_request, error.status_code
    end

    test "InvalidWithdrawalStateError initializes with i18n key and context" do
      I18n.stub(:t, "invalid state error") do
        error = InvalidWithdrawalStateError.new("ACTIVE")

        assert_equal "sign.withdrawal.errors.invalid_state", error.i18n_key
        assert_equal :unprocessable_content, error.status_code
        assert_equal "ACTIVE", error.context[:current_status]
      end
    end

    test "WithdrawalRecoveryNotAvailableError initializes with unprocessable_content status" do
      I18n.stub(:t, "recovery not available") do
        error = ::Sign::WithdrawalRecoveryNotAvailableError.new

        assert_equal "sign.withdrawal.errors.recovery_not_available", error.i18n_key
        assert_equal :unprocessable_content, error.status_code
      end
    end

    test "WithdrawalDeletionError initializes with internal_server_error status" do
      I18n.stub(:t, "deletion failed") do
        error = ::Sign::WithdrawalDeletionError.new

        assert_equal "sign.withdrawal.errors.deletion_failed", error.i18n_key
        assert_equal :internal_server_error, error.status_code
      end
    end

    test "WithdrawalError is subclass of ApplicationError" do
      assert_operator ApplicationError, :>, WithdrawalError
    end

    test "InvalidWithdrawalStateError is subclass of WithdrawalError" do
      assert_operator WithdrawalError, :>, InvalidWithdrawalStateError
    end

    test "WithdrawalRecoveryNotAvailableError is subclass of WithdrawalError" do
      assert_operator WithdrawalError, :>, WithdrawalRecoveryNotAvailableError
    end

    test "WithdrawalDeletionError is subclass of WithdrawalError" do
      assert_operator WithdrawalError, :>, WithdrawalDeletionError
    end

    test "WithdrawalError can be raised and caught" do
      assert_raises(WithdrawalError) do
        raise WithdrawalError.new("sign.withdrawal.errors.deletion_failed", :bad_request)
      end
    end

    test "InvalidWithdrawalStateError can be raised and caught" do
      I18n.stub(:t, "invalid state") do
        assert_raises(InvalidWithdrawalStateError) do
          raise InvalidWithdrawalStateError.new("SUSPENDED")
        end
      end
    end

    test "WithdrawalDeletionError can be raised and caught" do
      I18n.stub(:t, "deletion failed") do
        assert_raises(::Sign::WithdrawalDeletionError) do
          raise ::Sign::WithdrawalDeletionError.new
        end
      end
    end

    test "WithdrawalFinalizedError initializes with finalized i18n key and status" do
      I18n.stub(:t, "finalized") do
        error = ::Sign::WithdrawalFinalizedError.new

        assert_equal "sign.app.configuration.withdrawal.errors.finalized", error.i18n_key
        assert_equal :unprocessable_content, error.status_code
      end
    end

    test "WithdrawalFinalizedError can be raised and caught" do
      I18n.stub(:t, "finalized") do
        assert_raises(::Sign::WithdrawalFinalizedError) do
          raise ::Sign::WithdrawalFinalizedError.new
        end
      end
    end

    test "WithdrawalCooldownError initializes with cooldown i18n key, status, and context" do
      I18n.stub(:t, "cooldown active") do
        error = ::Sign::WithdrawalCooldownError.new(withdraw_cooldown_until: Time.current)

        assert_equal "sign.app.configuration.withdrawal.errors.cooldown_active", error.i18n_key
        assert_equal :unprocessable_content, error.status_code
        assert error.context[:withdraw_cooldown_until]
      end
    end

    test "WithdrawalCooldownError can be raised and caught" do
      I18n.stub(:t, "cooldown active") do
        assert_raises(::Sign::WithdrawalCooldownError) do
          raise ::Sign::WithdrawalCooldownError.new(withdraw_cooldown_until: Time.current)
        end
      end
    end

    test "WithdrawalFinalizedError is subclass of WithdrawalError" do
      assert_operator WithdrawalError, :>, WithdrawalFinalizedError
    end

    test "WithdrawalCooldownError is subclass of WithdrawalError" do
      assert_operator WithdrawalError, :>, WithdrawalCooldownError
    end
  end
end
