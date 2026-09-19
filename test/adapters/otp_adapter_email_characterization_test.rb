# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "../support/otp_email_records"

# Pins the OTP email delivery behaviour that exists before Noticed is introduced.
#
# test/adapters/otp_email_adapter_test.rb covers the adapter against a fake
# mailer. This file deliberately uses the real mailers and real records, so it
# states the end-to-end contract the Noticed path has to reproduce: one job per
# OTP, ciphertext rather than plaintext in the job arguments, and one mailer per
# surface.
class OtpAdapterEmailCharacterizationTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include OtpEmailRecords

  SURFACE_MAILERS = {
    app: Email::App::OtpMailer,
    com: Email::Com::OtpMailer,
    org: Email::Org::OtpMailer,
  }.freeze

  test "app email otp enqueues exactly one mail delivery job" do
    record = create_otp_email_record(:app, address: "characterization-app@example.com")

    assert_enqueued_jobs 1, only: ActionMailer::MailDeliveryJob do
      OtpAdapter.for(surface: :app, channel: :email).deliver(record: record, otp_code: "123456")
    end
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

  test "each surface routes to its own otp mailer" do
    SURFACE_MAILERS.each do |surface, mailer|
      clear_enqueued_jobs
      record = create_otp_email_record(surface, address: "characterization-#{surface}@example.com")

      OtpAdapter.for(surface: surface, channel: :email).deliver(record: record, otp_code: "123456")

      assert_equal mailer.name, enqueued_mailer_name, surface.to_s
    end
  end

  private

  # ActionMailer::MailDeliveryJob serializes as [mailer, action, delivery_method, args: {params:, args:}].
  def enqueued_mailer_name
    enqueued_jobs.last[:args].first
  end

  def enqueued_encrypted_hotp_token
    enqueued_jobs.last[:args].last.fetch("params").fetch("encrypted_hotp_token")
  end
end
