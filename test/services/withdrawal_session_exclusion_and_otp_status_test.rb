# typed: false
# frozen_string_literal: true

require "test_helper"

class WithdrawalSessionExclusionAndOtpStatusTest < ActiveSupport::TestCase
  fixtures :client_statuses, :client_visibilities, :client_token_kinds, :client_token_statuses

  # The occurrence status ids are cached per class, so an unrecognised class has
  # to be refused by name rather than cached as nil and answered from cache after.
  test "an unsupported occurrence status class is refused by name" do
    error =
      assert_raises(KeyError) do
        SignInOtpResender.send(:status_id_for, ClientTokenStatus, :ACTIVE)
      end

    assert_match(/ClientTokenStatus/, error.message)
  end

  test "the two email occurrence statuses resolve to persisted rows" do
    assert_equal EmailOccurrenceStatus::ACTIVE, SignInOtpResender.email_issued_status_id
    assert_equal EmailOccurrenceStatus::NOTHING, SignInOtpResender.email_blocked_status_id
  end
end
