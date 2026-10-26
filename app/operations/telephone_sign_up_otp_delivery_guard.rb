# frozen_string_literal: true

class TelephoneSignUpOtpDeliveryGuard
  class << self
    public

    def call(flow:, telephone:, transaction:, generation:, destination:, code:)
      raise ArgumentError, "Telephone signup delivery requires a transport block" unless block_given?

      owner, pending_status = components(flow, telephone, transaction)
      flow.with_lock do
        owner.with_lock do
          telephone.with_lock do
            session_ref = Digest::SHA256.hexdigest(
              JSON.generate(
                ["telephone_sign_up", flow.public_id,
                 flow.nonce_digest,],
              ),
            )
            transaction.with_lock do
              next false unless current_parent_and_source?(flow, telephone, owner, pending_status)

              next false unless transaction.operation == "sign_up" && transaction.purpose == "sign_up" &&
                transaction.session_ref == session_ref && transaction.actor_ref == owner.public_id &&
                transaction.telephone_candidate_ref == telephone.public_id &&
                transaction.normalized_number_digest == telephone.number_digest
              next false unless destination.is_a?(String) && destination.encoding.ascii_compatible? &&
                destination.valid_encoding? &&
                IdentifierBlindIndex.bidx_for_telephone(
                  destination,
                  realm: transaction.surface,
                ) == telephone.number_digest

              transaction.deliver_telephone_otp!(generation: generation, code: code) { yield }
            end
          end
        end
      end

    end

    private

    def components(flow, telephone, transaction)
      case flow
      when ClientSignUpFlow
        unless telephone.is_a?(ClientTelephone) && transaction.is_a?(ClientTelephoneCeremonyTransaction)
          raise ArgumentError, "APP signup delivery requires its own Telephone ceremony"
        end

        [Client.find(telephone.user_id), ClientStatus::UNVERIFIED_WITH_SIGN_UP]
      when VisitorSignUpFlow
        unless telephone.is_a?(VisitorTelephone) && transaction.is_a?(VisitorTelephoneCeremonyTransaction)
          raise ArgumentError, "COM signup delivery requires its own Telephone ceremony"
        end

        [Visitor.find(telephone.visitor_id), VisitorStatus::UNVERIFIED_WITH_SIGN_UP]
      else raise ArgumentError, "unsupported Telephone signup delivery realm"
      end
    end

    def current_parent_and_source?(flow, telephone, owner, pending_status)
      now = flow.class.database_now
      owner_id =
        case telephone
        when ClientTelephone then telephone.user_id
        when VisitorTelephone then telephone.visitor_id
        else raise ArgumentError, "unsupported Telephone signup candidate"
        end
      !flow.sign_up_terminal? && flow.expires_at > now && !flow.lapsed?(now) &&
        flow.pending_contact_type == "telephone" && flow.pending_contact_id == telephone.id &&
        flow.principal_id == owner.id && owner_id == owner.id &&
        owner.status_id == pending_status && owner.active? && owner.access_enabled? &&
        owner.accessible?(owner.class.database_now) && telephone.accessible?(telephone.class.database_now) &&
        !telephone.binding_finalized_at && !telephone.binding_released?
    end
  end
end
