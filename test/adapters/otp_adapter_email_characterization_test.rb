# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "../support/otp_email_records"

# Pins the final Noticed OTP email delivery boundary with real mailers and records:
# one job per OTP and ciphertext rather than plaintext in job arguments.
class OtpAdapterEmailCharacterizationTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include OtpEmailRecords

  setup do
    ChronicleRecord.connected_to(role: :writing) do
      ChronicleRetentionPolicy.find_or_create_by!(code: "security") do |policy|
        policy.name = "Security"
        policy.duration_days = 365
        policy.permanent = false
      end
    end
  end

  test "app email otp enqueues exactly one mail delivery job" do
    record = create_otp_email_record(:app, address: "characterization-app@example.com")

    assert_enqueued_jobs 1, only: OtpNotifierEmailDeliveryJob do
      OtpAdapter.for(surface: :app, channel: :email).deliver(record: record, otp_code: "123456")
    end
  end

  test "email enqueue is recorded without recipient or otp content" do
    record = create_otp_email_record(:app, address: "characterization-audit@example.com")

    assert_difference -> { Chronicle.where(action: "notification.delivery.email.enqueued").count }, 1 do
      OtpAdapter.for(surface: :app, channel: :email).deliver(record: record, otp_code: "123456")
    end

    chronicle = Chronicle.where(action: "notification.delivery.email.enqueued").order(:created_at).last

    assert_equal record.class.name, chronicle.subject_type
    assert_equal record.id, chronicle.subject_id
    assert_not_includes chronicle.metadata.to_json, "characterization-audit@example.com"
    assert_not_includes chronicle.metadata.to_json, "123456"
  end

  test "the Noticed path records email enqueue without recipient or otp content" do
    record = create_otp_email_record(:app, address: "characterization-noticed-audit@example.com")

    assert_difference -> { Chronicle.where(action: "notification.delivery.email.enqueued").count }, 1 do
      OtpAdapter.for(surface: :app, channel: :email).deliver(record: record, otp_code: "654321")
    end

    chronicle = Chronicle.where(action: "notification.delivery.email.enqueued").order(:created_at).last

    assert_equal record.class.name, chronicle.subject_type
    assert_equal record.id, chronicle.subject_id
    assert_not_includes chronicle.metadata.to_json, "characterization-noticed-audit@example.com"
    assert_not_includes chronicle.metadata.to_json, "654321"
  end

  test "the enqueued job arguments carry no plaintext otp" do
    record = create_otp_email_record(:app, address: "characterization-secret@example.com")
    clear_enqueued_jobs

    OtpAdapter.for(surface: :app, channel: :email).deliver(record: record, otp_code: "123456")

    arguments = enqueued_jobs.last[:args].inspect

    assert_not_includes arguments, "123456"
    assert_equal "123456", OutboundSensitivePayload.decrypt_email_otp(enqueued_encrypted_hotp_token)
  end

  test "the enqueued job arguments carry no plaintext verification token" do
    record = create_otp_email_record(:app, address: "characterization-verification@example.com")
    clear_enqueued_jobs

    OtpAdapter.for(surface: :app, channel: :email).deliver(
      record: record,
      otp_code: "123456",
      verification_token: "verification-token",
      public_id: record.public_id,
    )

    arguments = enqueued_jobs.last[:args].inspect

    assert_not_includes arguments, "verification-token"
    assert_equal(
      "verification-token",
      OutboundSensitivePayload.decrypt_email_verification_token(
        enqueued_jobs.last[:args].last.fetch("params").fetch("encrypted_verification_token"),
      ),
    )
  end

  private

  def enqueued_encrypted_hotp_token
    enqueued_jobs.last[:args].last.fetch("params").fetch("encrypted_hotp_token")
  end
end
