# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class ApplicationErrorTest < ActiveSupport::TestCase
  test "ApplicationError stores status code, context, and translated message" do
    error = ApplicationError.new("errors.messages.login_required", :unauthorized, resource: "client")

    assert_equal :unauthorized, error.status_code
    assert_equal({ resource: "client" }, error.context)
    assert_predicate error.message, :present?
  end

  test "ApplicationError uses raw non-ascii messages without translation" do
    error = ApplicationError.new("こんにちは", :bad_request)

    assert_equal "こんにちは", error.message
  end

  test "specialized application errors expose their status codes" do
    assert_equal :forbidden, AlreadyAuthenticatedError.new.status_code
    assert_equal :unauthorized, NotAuthenticatedError.new.status_code
    assert_equal :unprocessable_content, PreferenceOperationError.new.status_code
    assert_equal :unprocessable_content, InvalidUserStatusError.new(invalid_status: "inactive").status_code
  end

  test "invalid user status error formats messages for explicit and default cases" do
    explicit = InvalidUserStatusError.new(invalid_status: "inactive", message: "Denied")
    translated = InvalidUserStatusError.new(
      invalid_status: "inactive",
      i18n_key: "errors.messages.not_authorized",
    )
    fallback = InvalidUserStatusError.new(invalid_status: "inactive")

    assert_equal "Denied: {invalid_status: \"inactive\"}", explicit.message
    assert_predicate translated.message, :present?
    assert_equal "Invalid user status: inactive", fallback.message
  end

  test "sign and social auth error classes inherit from the expected base classes" do
    assert_operator Sign::WithdrawalError, :<, ApplicationError
    assert_operator Sign::InvalidWithdrawalStateError, :<, Sign::WithdrawalError
    assert_operator Sign::WithdrawalDeletionError, :<, Sign::WithdrawalError
    assert_operator Sign::WithdrawalRecoveryNotAvailableError, :<, Sign::WithdrawalError

    assert_operator SocialAuth::BaseError, :<, ApplicationError
    assert_operator SocialAuth::ConflictError, :<, SocialAuth::BaseError
    assert_operator SocialAuth::LastIdentityError, :<, SocialAuth::BaseError
    assert_operator SocialAuth::ProviderError, :<, SocialAuth::BaseError
    assert_operator SocialAuth::StepUpRequiredError, :<, SocialAuth::BaseError
    assert_operator SocialAuth::UnauthorizedError, :<, SocialAuth::BaseError
  end

  test "sign and social auth errors initialize with the expected default status codes" do
    I18n.stub(:t, ->(key, **_) { key.to_s }) do
      assert_equal :bad_request, Sign::WithdrawalError.new("errors.messages.not_authorized").status_code
      assert_equal :unprocessable_content, Sign::InvalidWithdrawalStateError.new("suspended").status_code
      assert_equal :internal_server_error, Sign::WithdrawalDeletionError.new.status_code
      assert_equal :unprocessable_content, Sign::WithdrawalRecoveryNotAvailableError.new.status_code

      assert_equal :conflict, SocialAuth::ConflictError.new.status_code
      assert_equal :unprocessable_content, SocialAuth::LastIdentityError.new.status_code
      assert_equal :bad_request, SocialAuth::ProviderError.new.status_code
      assert_equal :forbidden, SocialAuth::StepUpRequiredError.new.status_code
      assert_equal :unauthorized, SocialAuth::UnauthorizedError.new.status_code
    end
  end
end
