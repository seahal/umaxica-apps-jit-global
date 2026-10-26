# frozen_string_literal: true

class EmailSignUpOtpDeliveryGuard
  class << self
    public

    def call(flow:, email:, transaction:, generation:, destination:, code:)
      raise ArgumentError, "Email signup delivery requires a transport block" unless block_given?

      owner, pending_status = components(flow, email, transaction)
      flow.with_lock do
        owner.with_lock do
          email.with_lock do
            next false unless current_parent_and_source?(flow, email, owner, pending_status)

            session_ref = Digest::SHA256.hexdigest(
              JSON.generate(
                ["email_sign_up", flow.public_id,
                 flow.nonce_digest,],
              ),
            )
            transaction.with_lock do
              next false unless transaction.operation == "sign_up" && transaction.purpose == "sign_up" &&
                transaction.session_ref == session_ref && transaction.actor_ref == owner.public_id &&
                transaction.email_candidate_ref == email.public_id &&
                transaction.normalized_email_digest == email.address_digest
              next false unless destination.is_a?(String) && destination.encoding.ascii_compatible? &&
                destination.valid_encoding? &&
                IdentifierBlindIndex.bidx_for_email(
                  destination,
                  realm: transaction.surface,
                ) == email.address_digest

              transaction.deliver_email_otp!(generation: generation, code: code) { yield }
            end
          end
        end
      end

    end

    private

    def components(flow, email, transaction)
      case flow
      when ClientSignUpFlow
        unless email.is_a?(ClientEmail) && transaction.is_a?(ClientEmailCeremonyTransaction)
          raise ArgumentError, "APP signup delivery requires its own Email ceremony"
        end

        [Client.find(email.user_id), ClientStatus::UNVERIFIED_WITH_SIGN_UP]
      when VisitorSignUpFlow
        unless email.is_a?(VisitorEmail) && transaction.is_a?(VisitorEmailCeremonyTransaction)
          raise ArgumentError, "COM signup delivery requires its own Email ceremony"
        end

        [Visitor.find(email.visitor_id), VisitorStatus::UNVERIFIED_WITH_SIGN_UP]
      else raise ArgumentError, "unsupported Email signup delivery realm"
      end
    end

    def current_parent_and_source?(flow, email, owner, pending_status)
      now = flow.class.database_now
      owner_id =
        case email
        when ClientEmail then email.user_id
        when VisitorEmail then email.visitor_id
        else raise ArgumentError, "unsupported Email signup candidate"
        end
      !flow.sign_up_terminal? && flow.expires_at > now && !flow.lapsed?(now) &&
        flow.pending_contact_type == "email" && flow.pending_contact_id == email.id &&
        flow.principal_id == owner.id && owner_id == owner.id &&
        owner.status_id == pending_status && owner.active? && owner.access_enabled? &&
        owner.accessible?(owner.class.database_now) && email.accessible?(email.class.database_now) &&
        !email.binding_finalized_at && !email.binding_released?
    end
  end
end
