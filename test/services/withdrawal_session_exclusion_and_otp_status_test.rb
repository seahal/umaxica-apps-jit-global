# typed: false
# frozen_string_literal: true

require "test_helper"

class WithdrawalSessionExclusionAndOtpStatusTest < ActiveSupport::TestCase
  fixtures :client_statuses, :client_visibilities, :client_token_kinds, :client_token_statuses

  test "the two email occurrence statuses resolve to persisted rows" do
    assert_equal EmailOccurrenceStatus::ACTIVE, SignInOtpResender.email_issued_status_id
    assert_equal EmailOccurrenceStatus::NOTHING, SignInOtpResender.email_blocked_status_id
  end
end
