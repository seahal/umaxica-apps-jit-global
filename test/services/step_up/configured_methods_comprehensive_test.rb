# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class StepUpConfiguredMethodsComprehensiveTest < ActiveSupport::TestCase
  fixtures :clients

  test "returns empty array for nil subject" do
    assert_equal [], StepUpConfiguredMethodsQuery.call(nil)
  end

  test "returns empty array for object without email/passkey/totp associations" do
    assert_equal [], StepUpConfiguredMethodsQuery.call(Object.new)
  end

  test "call includes email_otp when user has emails" do
    user = clients(:one)
    if user.client_emails.exists?(user_email_status_id: AuthMethodGuard::VERIFIED_EMAIL_STATUSES)
      assert_includes StepUpConfiguredMethodsQuery.call(user), :email_otp
    else
      assert_not_includes StepUpConfiguredMethodsQuery.call(user), :email_otp
    end
  end

  test "call includes passkey when user has passkeys" do
    user = clients(:one)
    result = StepUpConfiguredMethodsQuery.call(user)
    if user.client_passkeys.active.exists?
      assert_includes result, :passkey
    else
      assert_not_includes result, :passkey
    end
  end
end
