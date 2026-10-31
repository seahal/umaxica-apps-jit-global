# frozen_string_literal: true

# The Source cooldown and Auth challenge are decided while the owner and Contact remain locked.
class AuthEmailSignInOtpIssuer
  class Cooldown < StandardError; end

  class << self
    public

    def call(ceremony:, contact:, destination:)
      raise ArgumentError, "APP email Contact required" unless contact.is_a?(ClientEmail)
      raise ArgumentError, "APP Auth ceremony required" unless ceremony.is_a?(ClientAuthCeremonySession)

      Client.connection_class_for_self.connected_to(role: :writing) do
        owner = Client.find(contact.user_id)
        owner.with_lock do
          contact.with_lock do
            unless contact.user_id == owner.id
              raise AuthCeremonySession::InvalidTransition, "email authentication owner changed"
            end
            raise Cooldown if contact.otp_cooldown_active?(now: contact.class.database_now)

            ceremony.issue_email_otp!(contact: contact, destination: destination)
          end
        end
      end
    end
  end
end
