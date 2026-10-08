# frozen_string_literal: true

class TelephoneCredentialRegistrationOtpIssuer
  class << self
    public

    def call(actor:, token:, telephone:, browser_nonce:)
      surface, transaction_model, pending_status = components(actor, token, telephone)
      reference = SecureRandom.uuid
      session = CredentialRegistrationOtpSessionValue.for(
        surface: surface, channel: :telephone, transaction_ref: reference,
        root_ref: token.public_id, browser_nonce: browser_nonce,
      )
      actor.class.connection_class_for_self.connected_to(role: :writing) do
        actor.with_lock do
          transaction_model.connection_owner.connected_to(role: :writing) do
            token.device_session.with_lock do
              token.with_lock do
                telephone.with_lock do
                  issue_locked(
                    actor, token, telephone, transaction_model, pending_status, reference, session, browser_nonce,
                  )
                end
              end
            end
          end
        end
      end
    end

    private

    def components(actor, token, telephone)
      case [actor, token, telephone]
      in [Client, ClientToken, ClientTelephone]
        ["app", ClientTelephoneCeremonyTransaction, ClientTelephoneStatus::UNVERIFIED]
      in [Visitor, VisitorToken, VisitorTelephone]
        ["com", VisitorTelephoneCeremonyTransaction, VisitorTelephoneStatus::UNVERIFIED]
      in [Operator, OperatorToken, OperatorTelephone]
        ["org", OperatorTelephoneCeremonyTransaction, OperatorTelephoneStatus::UNVERIFIED]
      else raise ArgumentError, "unsupported Telephone credential registration realm"
      end
    end

    def issue_locked(actor, token, telephone, transaction_model, pending_status, reference, session, browser_nonce)
      ticket_now = transaction_model.database_now
      source_now = telephone.class.database_now
      unless current_binding?(actor, token, telephone, pending_status, ticket_now, source_now)
        return result(:unavailable)
      end
      return result(:locked) if telephone.locked?(now: source_now)
      if telephone.otp_last_sent_at && telephone.otp_last_sent_at > source_now - TelephoneOtpPolicy::SEND_COOLDOWN
        return result(:rate_limited)
      end

      cancel_original_browser_challenges!(actor, token, telephone, transaction_model, browser_nonce)
      transaction = transaction_model.create_transaction!(
        transaction_id: reference, actor_ref: actor.public_id, session_ref: session.dump,
        operation: "registration", telephone_candidate_ref: candidate_ref(telephone),
        normalized_number_digest: telephone.number_digest, now: ticket_now,
        expires_at: [ticket_now + IdentityTelephoneCeremonyTransaction::DEFAULT_TTL, token.discard_at].min,
      )
      code = transaction.issue_telephone_otp!(purpose: "credential_registration")
      telephone.update!(otp_last_sent_at: source_now)
      result(:issued, transaction: transaction, code: code.freeze)
    end

    def cancel_original_browser_challenges!(actor, token, telephone, transaction_model, browser_nonce)
      transaction_model.where(
        actor_ref: actor.public_id, telephone_candidate_ref: candidate_ref(telephone), operation: "registration",
        purpose: "credential_registration", status: "pending", otp_consumed_at: nil, otp_cancelled_at: nil,
      ).find_each do |previous|
        expected = CredentialRegistrationOtpSessionValue.for(
          surface: previous.surface, channel: :telephone, transaction_ref: previous.transaction_id,
          root_ref: token.public_id, browser_nonce: browser_nonce,
        ).dump
        previous.cancel_telephone_otp! if previous.session_ref == expected
      end
    end

    def current_binding?(actor, token, telephone, pending_status, ticket_now, source_now)
      owned_pending?(actor, token, telephone, pending_status) && actor.login_allowed? &&
        actor.accessible?(source_now) && source_pending?(
          telephone,
          source_now,
        ) && token.currently_usable?(ticket_now) &&
        token.device_session.usable? && token.device_session.current_refresh_token_id == token.id
    end

    def owned_pending?(actor, token, telephone, pending_status)
      case actor
      when Client
        token.user_id == actor.id && token.device_session.user_id == actor.id && telephone.user_id == actor.id &&
          telephone.user_telephone_status_id == pending_status
      when Visitor
        token.visitor_id == actor.id && token.device_session.visitor_id == actor.id &&
          telephone.visitor_id == actor.id && telephone.visitor_telephone_status_id == pending_status
      when Operator
        token.staff_id == actor.id && token.device_session.staff_id == actor.id && telephone.staff_id == actor.id &&
          telephone.staff_telephone_status_id == pending_status
      end
    end

    def candidate_ref(telephone)
      case telephone
      when ClientTelephone, VisitorTelephone then telephone.public_id
      when OperatorTelephone then telephone.id.to_s
      end
    end

    def source_pending?(telephone, now)
      case telephone
      when ClientTelephone, VisitorTelephone
        telephone.accessible?(now) && !telephone.binding_finalized_at && !telephone.binding_released? &&
          !telephone.credential_registration_otp_context
      when OperatorTelephone then telephone.staff_telephone_status_id == OperatorTelephoneStatus::UNVERIFIED
      end
    end

    def result(status, transaction: nil, code: nil)
      TelephoneCredentialRegistrationOtpIssueResult.new(status: status, transaction: transaction, code: code)
    end
  end
end
