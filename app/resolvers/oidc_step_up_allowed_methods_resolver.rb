# frozen_string_literal: true

# The OP checks only the current Security Mode here. Auth already verified the
# credential; credential inventory is deliberately not rechecked at completion.
class OidcStepUpAllowedMethodsResolver
  APP_NORMAL_METHODS = %i(passkey totp email_otp).freeze
  APP_ADVANCED_METHODS = %i(passkey).freeze
  ORG_METHODS = %i(passkey).freeze

  class << self
    public

    def call(actor:)
      case actor
      when Client
        return [] unless actor.security_mode_valid?

        actor.security_mode_advanced? ? APP_ADVANCED_METHODS : APP_NORMAL_METHODS
      when Operator
        return [] unless actor.security_mode_valid?

        ORG_METHODS
      else
        raise ArgumentError, "unsupported step-up actor"
      end
    end
  end
end
