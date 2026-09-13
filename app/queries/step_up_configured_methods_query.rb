# typed: false
# frozen_string_literal: true

# Persistent credential state only. Transient cooldowns and ticket lockout
# belong in StepUpAvailableMethods.
module StepUpConfiguredMethodsQuery
  module_function

  def call(subject)
    return [] unless subject

    AuthenticationCredentialInventory.call(subject).step_up_methods
  end

  def configured_email?(subject)
    call(subject).include?(:email_otp)
  end

  def configured_passkey?(subject)
    call(subject).include?(:passkey)
  end

  def configured_totp?(subject)
    call(subject).include?(:totp)
  end
  private_class_method :configured_email?, :configured_passkey?, :configured_totp?
end
