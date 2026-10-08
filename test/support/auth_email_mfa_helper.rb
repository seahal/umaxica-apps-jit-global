# typed: false
# frozen_string_literal: true

module AuthEmailMfaHelper
  def sign_in_with_email_to_mfa!(surface:, email_record:, email:, headers: {})
    email_path = public_send("auth_#{surface}_sign_in_email_path", ri: "jp")
    challenge_path = public_send("auth_#{surface}_sign_in_challenge_path", ri: "jp")

    post(
      email_path,
      params: { user_email: { address: email }, "cf-turnstile-response": "test_token" },
      headers: headers,
    )

    assert_response :found

    delivery_class = OtpEmailNotifierRollout.enabled?(surface) ? OtpNotifierEmailDeliveryJob : OtpMailDeliveryJob
    delivery =
      ActiveJob::Base.queue_adapter.enqueued_jobs.reverse.find do |entry|
        entry.fetch(:job) == delivery_class
      end
    payload = ActiveJob::Arguments.deserialize(delivery.fetch(:args)).last.fetch(:params)
    ceremony =
      case surface.to_sym
      when :app then ClientAuthCeremonySession.find(payload.fetch(:auth_ceremony_session_ref))
      when :com then VisitorAuthCeremonySession.find(payload.fetch(:auth_ceremony_session_ref))
      else raise ArgumentError, "unsupported MFA email surface"
      end

    assert_equal email_record.public_id, ceremony.email_otp_context.fetch("contact_ref")
    assert_equal payload.fetch(:auth_email_otp_generation), ceremony.email_otp_context.fetch("generation")
    pass_code = OutboundSensitivePayload.decrypt_email_otp(payload.fetch(:encrypted_hotp_token))

    patch(
      email_path,
      params: { user_email: { pass_code: pass_code } },
      headers: headers,
    )

    assert_response((surface.to_sym == :com) ? :see_other : :found)
    assert_equal URI.parse(challenge_path).path, URI.parse(response.location).path
  end
end
