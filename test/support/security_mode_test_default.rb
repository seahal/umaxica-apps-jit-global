# frozen_string_literal: true

# The Security Mode a test actor starts in when the test does not name one, matching the product
# rule (adr/authentication-security-mode.md B1/B2): APP and COM start NORMAL, ORG is ADVANCED.
module SecurityModeTestDefault
  module_function

  def id_for(actor_class)
    (actor_class <= Operator) ? OperatorSecurityMode::ADVANCED : SecurityModeConfigurable::NORMAL
  end
end
