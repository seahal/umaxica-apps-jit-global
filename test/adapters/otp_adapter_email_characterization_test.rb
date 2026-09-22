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

    assert_enqueued_jobs 1, only: ActionMailer::MailDeliveryJob do
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

  test "notifier rollout records email enqueue without recipient or otp content" do
    Flipper.enable(:otp_email_notifier_app)
    record = create_otp_email_record(:app, address: "characterization-rollout-audit@example.com")

    assert_difference -> { Chronicle.where(action: "notification.delivery.email.enqueued").count }, 1 do
      OtpAdapter.for(surface: :app, channel: :email).deliver(record: record, otp_code: "654321")
    end

    chronicle = Chronicle.where(action: "notification.delivery.email.enqueued").order(:created_at).last

    assert_equal record.class.name, chronicle.subject_type
    assert_equal record.id, chronicle.subject_id
    assert_not_includes chronicle.metadata.to_json, "characterization-rollout-audit@example.com"
    assert_not_includes chronicle.metadata.to_json, "654321"
  ensure
    Flipper.disable(:otp_email_notifier_app)
  end

  test "records email enqueue failure without exposing recipient or otp content" do
    record = create_otp_email_record(:app, address: "characterization-failure@example.com")
    delivery = Object.new
    delivery.define_singleton_method(:deliver_later) do
      raise Net::ReadTimeout, "provider timeout"
    end
    message = Object.new
    message.define_singleton_method(:create) { delivery }
    mailer = Object.new
    mailer.define_singleton_method(:with) { |_| message }

    assert_difference -> { Chronicle.where(action: "notification.delivery.email.enqueue_failed").count }, 1 do
      assert_raises(Net::ReadTimeout) do
        OtpEmailAdapter.new(mailer).deliver(
          record: record,
          otp_code: "987654",
          purpose: :sign_in,
        )
      end
    end

    chronicle = Chronicle.where(action: "notification.delivery.email.enqueue_failed").order(:created_at).last

    assert_equal "Net::ReadTimeout", chronicle.reason
    assert_equal({ "purpose" => "sign_in" }, chronicle.metadata)
    assert_not_includes chronicle.metadata.to_json, "characterization-failure@example.com"
    assert_not_includes chronicle.metadata.to_json, "987654"
    assert_not_includes chronicle.reason, "provider timeout"
  end

  test "audit failure after email enqueue does not report a duplicate delivery failure" do
    record = create_otp_email_record(:app, address: "characterization-audit-failure@example.com")
    calls = 0
    delivery = Object.new
    delivery.define_singleton_method(:deliver_later) { calls += 1 }
    message = Object.new
    message.define_singleton_method(:create) { delivery }
    mailer = Object.new
    mailer.define_singleton_method(:with) { |_| message }

    Chronicle.stub(:capture, ->(**) { raise ActiveRecord::ConnectionNotEstablished, "audit unavailable" }) do
      OtpEmailAdapter.new(mailer).deliver(record: record, otp_code: "123456")
    end

    assert_equal 1, calls
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
