# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Email::SurfaceMailersTest < ActionMailer::TestCase
  include ActiveJob::TestHelper

  test "APP and ORG OTP messages bound to SMTP use the deadline transport" do
    [Email::App::OtpMailer, Email::Org::OtpMailer].each do |mailer|
      mailer.stub(:delivery_method, :smtp) do
        message = mailer.with(
          encrypted_hotp_token: encrypted_otp("123456"), email_address: "recipient@example.test",
        ).create.message

        assert_instance_of OtpSmtpDelivery, message.delivery_method
      end
    end
  end

  test "app otp mailer sends verification code from app sender" do
    mail = Email::App::OtpMailer.with(
      encrypted_hotp_token: encrypted_otp("123456"),
      email_address: "user@example.com",
      public_id: "email-public-id",
      encrypted_verification_token: OutboundSensitivePayload.encrypt_email_verification_token("verification-token"),
    ).create

    assert_equal I18n.t("mail.email.app.otp_mailer.create.subject"), mail.subject
    assert_equal ["user@example.com"], mail.to
    assert_equal ["otp@umaxica.app"], mail.from
    assert_match "123456", mail.html_part.body.decoded
    assert_match "verification-token", mail.html_part.body.decoded
  end

  test "app sign-up otp mail uses the purpose-specific subject" do
    mail = Email::App::OtpMailer.with(
      encrypted_hotp_token: encrypted_otp("123456"),
      email_address: "user@example.com",
      purpose: :sign_up,
    ).create

    assert_equal I18n.t("mail.email.app.otp_mailer.create.subjects.sign_up"), mail.subject
    assert_not_includes mail.subject, "123456"
  end

  test "app sign-in otp mail uses the purpose-specific subject" do
    mail = Email::App::OtpMailer.with(
      encrypted_hotp_token: encrypted_otp("123456"),
      email_address: "user@example.com",
      purpose: :sign_in,
    ).create

    assert_equal I18n.t("mail.email.app.otp_mailer.create.subjects.sign_in"), mail.subject
    assert_not_includes mail.subject, "123456"
  end

  test "org otp mailer sends verification code from org sender" do
    mail = Email::Org::OtpMailer.with(
      encrypted_hotp_token: encrypted_otp("999888"),
      email_address: "operator@example.com",
    ).create

    assert_equal I18n.t("mail.email.org.otp_mailer.create.subject"), mail.subject
    assert_equal ["operator@example.com"], mail.to
    assert_equal ["otp@umaxica.org"], mail.from
    assert_match "999888", mail.text_part.body.decoded
  end

  test "otp mailers build verification links for their own surface" do
    [
      [Email::App::OtpMailer, "mail-app-public-id", "app-token",
       ENV.fetch("PUBLIC_BASE_SERVICE_URL"),
       "/identity/emails/registration/edit",],
      [Email::Org::OtpMailer, "mail-org-public-id", "org-token", ENV.fetch("PUBLIC_BASE_STAFF_URL"),
       "/identity",],
    ].each do |mailer, public_id, token, host, path|
      mail = mailer.with(
        encrypted_hotp_token: encrypted_otp("123456"),
        email_address: "target@example.com",
        public_id: public_id,
        encrypted_verification_token: OutboundSensitivePayload.encrypt_email_verification_token(token),
      ).create

      assert_match host, mail.html_part.body.decoded
      assert_match path, mail.html_part.body.decoded
      assert_match token, mail.html_part.body.decoded
      assert_match host, mail.text_part.body.decoded
      assert_match path, mail.text_part.body.decoded
      assert_match token, mail.text_part.body.decoded
    end
  end

  test "otp mailer enqueue arguments do not include plaintext otp" do
    clear_enqueued_jobs

    Email::App::OtpMailer.with(
      encrypted_hotp_token: encrypted_otp("112233"),
      email_address: "target@example.com",
    ).create.deliver_later

    job_payload = enqueued_jobs.last[:args].inspect

    assert_includes job_payload, "encrypted_hotp_token"
    assert_no_match(/"hotp_token"\s*=>/, job_payload)
    assert_not_includes job_payload, "112233"
  end

  test "alert mailers send a generic alert payload per surface" do
    [
      [Email::App::AlertMailer, "alert@umaxica.app"],
      [Email::Org::AlertMailer, "alert@umaxica.org"],
    ].each do |mailer, sender|
      mail = mailer.with(email_address: "target@example.com", title: "Alert title", body: "Alert body").notice

      assert_equal "Alert title", mail.subject
      assert_equal ["target@example.com"], mail.to
      assert_equal [sender], mail.from
      assert_match "Alert body", mail.text_part.body.decoded
    end
  end

  test "promotional mailers send from promotional addresses per surface" do
    [
      [Email::App::PromotionalMailer, "promotion@umaxica.app"],
      [Email::Org::PromotionalMailer, "promotion@umaxica.org"],
    ].each do |mailer, sender|
      mail = mailer.with(
        email_address: "target@example.com",
        title: "Promotion title",
        body: "Promotion body",
        cta_url: "https://example.com/campaign",
      ).notice

      assert_equal "Promotion title", mail.subject
      assert_equal ["target@example.com"], mail.to
      assert_equal [sender], mail.from
      assert_match "Promotion body", mail.text_part.body.decoded
      assert_match "https://example.com/campaign", mail.text_part.body.decoded
    end
  end

  test "promotional mailers omit unsafe cta urls" do
    [
      Email::App::PromotionalMailer,
      Email::Org::PromotionalMailer,
    ].each do |mailer|
      mail = mailer.with(
        email_address: "target@example.com",
        title: "Promotion title",
        body: "Promotion body",
        cta_url: "javascript:alert(1)",
      ).notice

      assert_match "Promotion body", mail.text_part.body.decoded
      assert_not_includes mail.text_part.body.decoded, "javascript:alert"
      assert_not_includes mail.html_part.body.decoded, "javascript:alert"
    end
  end

  test "promotional mailers omit cta urls with credentials" do
    [
      Email::App::PromotionalMailer,
      Email::Org::PromotionalMailer,
    ].each do |mailer|
      mail = mailer.with(
        email_address: "target@example.com",
        title: "Promotion title",
        body: "Promotion body",
        cta_url: "https://user:pass@example.com/campaign",
      ).notice

      assert_not_includes mail.text_part.body.decoded, "user:pass"
      assert_not_includes mail.html_part.body.decoded, "user:pass"
    end
  end

  test "promotional mailers can set unsubscribe headers per surface" do
    [
      [Email::App::PromotionalMailer, ClientEmail.new(public_id: "app-email-public-id"), "promotion@umaxica.app"],
      [Email::Org::PromotionalMailer, OperatorEmail.new(public_id: "org-email-public-id"), "promotion@umaxica.org"],
    ].each do |mailer, email_record, sender|
      mail = mailer.with(
        email_address: "target@example.com",
        title: "Promotion title",
        body: "Promotion body",
        cta_url: "https://example.com/campaign",
        email_record: email_record,
      ).notice

      assert_equal "Promotion title", mail.subject
      assert_equal [sender], mail.from
      assert_match "List-Unsubscribe", mail.header.to_s
    end
  end

  private

  def encrypted_otp(code)
    OutboundSensitivePayload.encrypt_email_otp(code)
  end
end
