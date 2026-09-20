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
end
