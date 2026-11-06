# frozen_string_literal: true

require "test_helper"

class EmailOtpResponseTimingTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "OTP send and suppression outcomes use the same minimum response floor" do
    floors = []
    timing = Object.new.extend(EmailOtpResponseTiming)

    timing.stub(:ensure_min_elapsed, ->(_started_at, floor) { floors << floor }) do
      %i(job_enqueued suppressed).each do |outcome|
        assert_equal outcome, timing.with_otp_issue_response_timing { outcome }
      end
    end

    assert_equal Array.new(2, EmailOtpPolicy::EMAIL_AUTH_RESPONSE_MINIMUM_SECONDS), floors
  end
end
