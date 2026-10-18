# frozen_string_literal: true

# First registration differs from recovery after loss, lockout or revocation. Base queries
# credential history only at ceremony entry; the issuer repeats this check under the actor lock.
class StepUpBootstrapEligibilityQuery
  class << self
    public

    def call(actor:)
      case actor
      when Client
        Client.connection_class_for_self.connected_to(role: :writing) do
          !actor.client_passkeys.exists? && !actor.client_totp_credentials.exists? &&
            !actor.client_emails.where.not(
              user_email_status_id: [ClientEmailStatus::UNVERIFIED, ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP,
                                     ClientEmailStatus::NOTHING,],
            ).exists?
        end
      when Visitor
        Visitor.connection_class_for_self.connected_to(role: :writing) do
          !actor.visitor_passkeys.exists? && !actor.visitor_emails.where.not(
            visitor_email_status_id: [VisitorEmailStatus::UNVERIFIED, VisitorEmailStatus::UNVERIFIED_WITH_SIGN_UP,
                                      VisitorEmailStatus::NOTHING,],
          ).exists?
        end
      when Operator
        Operator.connection_class_for_self.connected_to(role: :writing) do
          !actor.staff_passkeys.exists?
        end
      else
        raise ArgumentError, "bootstrap actor type unavailable"
      end
    end
  end
end
