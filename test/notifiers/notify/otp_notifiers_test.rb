# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "../../support/otp_email_records"

class Notify::OtpNotifiersTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include OtpEmailRecords

  SURFACE_NOTIFIERS = {
    app: Notify::App::OtpNotifier,
    com: Notify::Com::OtpNotifier,
    org: Notify::Org::OtpNotifier,
  }.freeze

  SURFACE_SENDERS = {
    app: "otp@umaxica.app",
    com: "otp@umaxica.com",
    org: "otp@umaxica.org",
  }.freeze

  setup do
    ClientSignInFlowState::DEFAULTS.each { |id| ClientSignInFlowState.find_or_create_by!(id: id) }
    ActionMailer::Base.deliveries.clear
  end

  teardown do
    Flipper.disable(:outbound_email_suspended)
  end

  test "issue enqueues one noticed email delivery for the app surface" do
    record = create_otp_email_record(:app, address: "notifier-app@example.com")

    assert_enqueued_jobs 1, only: OtpNotifierEmailDeliveryJob do
      Notify::App::OtpNotifier.issue(record: record, otp_code: "123456")
    end
  end

  # The linchpin of the migration: Noticed serializes `params` straight into the
  # delivery job, so anything secret has to be ciphertext before `with` is called.
  test "issue puts encrypted sensitive values into the job arguments" do
    record = create_otp_email_record(:app, address: "notifier-secret@example.com")
    clear_enqueued_jobs

    Notify::App::OtpNotifier.issue(
      record: record,
      otp_code: "123456",
      verification_token: "verification-token",
    )

    arguments = enqueued_jobs.last[:args].inspect

    assert_not_includes arguments, "123456"
    assert_not_includes arguments, "notifier-secret@example.com"
    assert_not_includes arguments, "verification-token"
    assert_equal "123456", OutboundSensitivePayload.decrypt_email_otp(enqueued_encrypted_hotp_token)
    assert_equal(
      "verification-token",
      OutboundSensitivePayload.decrypt_email_verification_token(
        enqueued_jobs.last[:args].last.fetch("params").fetch("encrypted_verification_token"),
      ),
    )
  end

  test "issue serialises the recipient as a global id" do
    record = create_otp_email_record(:app, address: "notifier-globalid@example.com")
    clear_enqueued_jobs

    Notify::App::OtpNotifier.issue(record: record, otp_code: "123456")

    recipient = enqueued_jobs.last[:args].last.fetch("recipient")

    assert_equal record.to_global_id.to_s, recipient.fetch("_aj_globalid")
  end

  test "issue rejects a blank otp code" do
    record = create_otp_email_record(:app, address: "notifier-blank-otp@example.com")

    assert_raises(ArgumentError) { Notify::App::OtpNotifier.issue(record: record, otp_code: "") }
  end

  test "issue rejects a nil record" do
    assert_raises(ArgumentError) { Notify::App::OtpNotifier.issue(record: nil, otp_code: "123456") }
  end

  test "performing the delivery renders the app surface otp mail" do
    record = create_otp_email_record(:app, address: "notifier-render@example.com")

    perform_enqueued_jobs do
      Notify::App::OtpNotifier.issue(
        record: record,
        otp_code: "123456",
        verification_token: "verification-token",
        public_id: record.public_id,
      )
    end

    mail = ActionMailer::Base.deliveries.last

    assert_equal I18n.t("mail.email.app.otp_mailer.create.subject"), mail.subject
    assert_equal ["otp@umaxica.app"], mail.from
    assert_equal ["notifier-render@example.com"], mail.to
    assert_match "123456", mail.html_part.body.decoded
    assert_match "verification-token", mail.html_part.body.decoded
  end

  test "purpose-specific delivery reaches the app mailer without exposing the otp" do
    owner = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      id: SecureRandom.random_number(1 << 60) + 1_000_000_000, status_id: ClientStatus::ACTIVE,
    )
    record = owner.client_emails.create!(
      address: "notifier-purpose@example.com", confirm_policy: "1", user_email_status_id: ClientEmailStatus::VERIFIED,
    ).tap(&:finalize_binding!)
    issuance = OidcTestEntry.issue!(
      surface: "app", intent: "sign_in", base_browser_nonce: SecureRandom.hex(32), base_token: nil,
    )
    ceremony, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "authentication_handoff", authorization_transaction_ref: issuance.transaction.transaction_id,
    )
    code = ceremony.issue_email_otp!(contact: record, destination: record.address)

    perform_enqueued_jobs do
      Notify::App::OtpNotifier.issue(
        record: record, otp_code: code, purpose: :sign_in,
        auth_ceremony_session_ref: ceremony.id.to_s,
        auth_email_otp_generation: ceremony.reload.email_otp_context.fetch("generation"),
      )
    end

    mail = ActionMailer::Base.deliveries.last

    assert_equal I18n.t("mail.email.app.otp_mailer.create.subjects.sign_in"), mail.subject
    assert_not_includes mail.subject, code
  end

  # Regression guard for the surface boundary: an app OTP must never leave through
  # the com or org sender, and vice versa.
  test "each surface notifier reaches only its own mailer" do
    SURFACE_NOTIFIERS.each do |surface, notifier|
      ActionMailer::Base.deliveries.clear
      record = create_otp_email_record(surface, address: "notifier-#{surface}@example.com")

      perform_enqueued_jobs do
        notifier.issue(record: record, otp_code: "123456")
      end

      mail = ActionMailer::Base.deliveries.last

      assert_equal [SURFACE_SENDERS.fetch(surface)], mail.from, surface.to_s
      assert_equal ["notifier-#{surface}@example.com"], mail.to, surface.to_s
    end
  end

  # The kill switch lives in OutboundEmailSuspensionInterceptor, which is registered
  # for every mailer. Going through Noticed must not route around it.
  test "no mail is delivered while the outbound email channel is suspended" do
    record = create_otp_email_record(:app, address: "notifier-suspended@example.com")
    Flipper.enable(:outbound_email_suspended)

    perform_enqueued_jobs do
      Notify::App::OtpNotifier.issue(record: record, otp_code: "123456")
    end

    assert_empty ActionMailer::Base.deliveries
  end

  private

  def enqueued_encrypted_hotp_token
    enqueued_jobs.last[:args].last.fetch("params").fetch("encrypted_hotp_token")
  end
end
