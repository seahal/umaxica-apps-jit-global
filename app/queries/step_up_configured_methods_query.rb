# typed: false
# frozen_string_literal: true

# Persistent credential state only. Transient cooldowns and ticket lockout
# belong in StepUpAvailableMethods.
module StepUpConfiguredMethodsQuery
  module_function

  def call(subject)
    return [] unless subject

    methods = AuthenticationCredentialInventory.call(subject).step_up_methods
    return methods unless subject.respond_to?(:security_mode_valid?)
    # Consolidation ADR 2.3: ADVANCED steps up with a Passkey only; an invalid mode offers nothing.
    return [] unless subject.security_mode_valid?

    subject.security_mode_advanced? ? methods & [:passkey] : methods
  end
end
