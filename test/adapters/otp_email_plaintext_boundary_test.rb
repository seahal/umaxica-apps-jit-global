# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "../support/otp_email_records"

# Runs an OTP email request through the sole Noticed delivery path and asserts
# that the ciphertext boundary remains intact.
class OtpEmailPlaintextBoundaryTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include OtpEmailRecords

  OTP_CODE = "246810"

  setup do
    ActionMailer::Base.deliveries.clear
  end

  test "the Noticed path never places the plaintext otp in job arguments" do
    clear_enqueued_jobs
    deliver_app_otp

    arguments = enqueued_jobs.map { |job| job[:args].inspect }.join

    assert_not_includes arguments, OTP_CODE
  end

  test "the Noticed path delivers the rendered otp mail" do
    ActionMailer::Base.deliveries.clear
    record = nil
    perform_enqueued_jobs { record = deliver_app_otp }
    mail = ActionMailer::Base.deliveries.last

    assert_equal [record.address], mail.to
    assert_match OTP_CODE, mail.html_part.body.decoded
  end

  private

  # Returns the record the OTP was addressed to.
  def deliver_app_otp
    record = create_otp_email_record(:app, address: "boundary-#{SecureRandom.hex(4)}@example.com")

    OtpAdapter.for(surface: :app, channel: :email).deliver(record: record, otp_code: OTP_CODE)

    record
  end
end
