# typed: false
# frozen_string_literal: true

require "test_helper"

class AuditRecordIntegrityTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    ChronicleRecord.connected_to(role: :writing) do
      ChronicleRetentionPolicy.find_or_create_by!(code: "security") do |policy|
        policy.name = "Security"
        policy.duration_days = 365
        policy.permanent = false
      end
    end
  end

  test "security audit records are durable and contain no raw authentication secret" do
    assert_difference -> { Chronicle.where(action: "authentication.security_event.sign_in.failure").count }, 1 do
      AuthenticationSecurityEventEmitter.emit(
        "sign_in.failure",
        reason: "invalid_credential",
        request_id: "audit-integrity-test",
        token: "raw-token",
        otp: "123456",
        refresh_token: "raw-refresh-token",
        authorization_code: "raw-authorization-code",
      )
    end

    chronicle = Chronicle.where(action: "authentication.security_event.sign_in.failure").order(:created_at).last

    assert_equal "succeeded", chronicle.result
    assert_equal "security", chronicle.chronicle_retention_policy.code
    assert_equal "invalid_credential", chronicle.reason
    assert_equal "audit-integrity-test", chronicle.request_id
    assert_not chronicle.metadata.key?("token")
    assert_not chronicle.metadata.key?("otp")
    assert_not chronicle.metadata.key?("refresh_token")
    assert_not chronicle.metadata.key?("authorization_code")
  end

  test "email enqueue audit records identify only the controlled purpose" do
    email = ClientEmail.create!(
      user: clients(:one),
      raw_address: "audit-integrity-#{SecureRandom.hex(6)}@example.com",
      confirm_policy: true,
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )

    assert_difference -> { Chronicle.where(action: "notification.delivery.email.enqueued").count }, 1 do
      OtpEmailAdapter.new(Email::App::OtpMailer).deliver(
        record: email,
        otp_code: "123456",
        purpose: :sign_in,
      )
    end

    chronicle = Chronicle.where(action: "notification.delivery.email.enqueued").order(:created_at).last

    assert_equal email, chronicle.subject
    assert_equal({ "purpose" => "sign_in" }, chronicle.metadata)
    assert_not chronicle.metadata.key?("recipient")
    assert_not chronicle.metadata.key?("code")
  end
end
