# frozen_string_literal: true

class TelephoneSignUpOtpDeliveryGuard
  class << self
    public

    def call(flow:, telephone:, transaction:, generation:, destination:, code:)
      raise ArgumentError, "Telephone signup delivery requires a transport block" unless block_given?

      owner, pending_status = components(flow, telephone, transaction)
      delivered =
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
      terminate_expired_parent(flow, telephone, owner, transaction, generation) unless delivered
      delivered
    end

    private

    def terminate_expired_parent(flow, telephone, owner, transaction, generation)
      flow.with_lock do
        next if flow.sign_up_terminal? || flow.expires_at > flow.class.database_now

        session_ref = Digest::SHA256.hexdigest(JSON.generate(["telephone_sign_up", flow.public_id, flow.nonce_digest]))
        original_generation =
          transaction.with_lock do
            transaction.session_ref == session_ref && transaction.actor_ref == owner.public_id &&
              transaction.telephone_candidate_ref == telephone.public_id &&
              transaction.operation == "sign_up" && transaction.purpose == "sign_up" &&
              transaction.otp_generation == generation
          end
        next unless original_generation

        SignUpTermination.call(cycle: flow, event: :expire)
      end
    end

    def components(flow, telephone, transaction)
      case flow
      when ClientSignUpFlow
        unless telephone.is_a?(ClientTelephone) && transaction.is_a?(ClientTelephoneCeremonyTransaction)
          raise ArgumentError, "APP signup delivery requires its own Telephone ceremony"
        end

        [telephone.user, ClientStatus::UNVERIFIED_WITH_SIGN_UP]
      when VisitorSignUpFlow
        unless telephone.is_a?(VisitorTelephone) && transaction.is_a?(VisitorTelephoneCeremonyTransaction)
          raise ArgumentError, "COM signup delivery requires its own Telephone ceremony"
        end

        [telephone.visitor, VisitorStatus::ACTIVE]
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
