# frozen_string_literal: true

require "test_helper"

class Notify::StepUpOtpNotifiersTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  fixtures :clients, :client_statuses

  test "step-up job contains ciphertext and its exact transaction generation" do
    credential = clients(:one).client_emails.create!(address: "step-up-delivery@example.com")
    reference = SecureRandom.uuid
    clear_enqueued_jobs
    assert_enqueued_jobs 1, only: StepUpEmailDeliveryJob do
      Notify::App::StepUpOtpNotifier.issue(
        record: credential, otp_code: "012345", transaction_ref: reference, generation: 2,
      )
    end
    arguments = enqueued_jobs.last.fetch(:args)

    assert_not_includes arguments.inspect, "012345"
    assert_not_includes arguments.inspect, credential.address
    payload = arguments.last.fetch("params")

    assert_equal reference, payload.fetch("transaction_ref")
    assert_equal 2, payload.fetch("generation")
    assert_equal "012345", OutboundSensitivePayload.decrypt_email_otp(payload.fetch("encrypted_hotp_token"))
  end
end
