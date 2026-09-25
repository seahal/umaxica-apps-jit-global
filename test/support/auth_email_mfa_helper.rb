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

    otp_private_key = ROTP::Base32.random_base32
    otp_counter = 55_555
    pass_code = ROTP::HOTP.new(otp_private_key).at(otp_counter).to_s
    email_record.store_otp(otp_private_key, otp_counter, 12.minutes.from_now.to_i)

    patch(
      email_path,
      params: { user_email: { pass_code: pass_code } },
      headers: headers,
    )

    assert_response((surface.to_sym == :com) ? :see_other : :found)
    assert_equal URI.parse(challenge_path).path, URI.parse(response.location).path
  end
end
