# typed: false
# frozen_string_literal: true

# Durable ownership facts for an email binding. A candidate may
# share a destination with other candidates; only a finalized, unreleased row
# participates in identity lookup and cardinality.
# Requires contact_binding_digest, accessible? and self.class.database_now from the concrete model.
module EmailContactBinding
  extend ActiveSupport::Concern

  public

  def binding_effective?
    binding_finalized_at.present? && binding_released_at.blank?
  end

  def binding_released?
    binding_released_at.present?
  end

  def finalize_registration_binding!(transaction:, code:, session_ref:)
    with_lock do
      now = self.class.database_now
      unless !binding_finalized_at && !binding_released? && accessible?(now) &&
          registration_ceremony_evidence?(transaction, code, session_ref)
        raise ArgumentError, "verified registration candidate is unavailable"
      end

      key, pending, verified =
        case self
        when ClientEmail then [:user_email_status_id, ClientEmailStatus::UNVERIFIED, ClientEmailStatus::VERIFIED]
        when VisitorEmail then [:visitor_email_status_id, VisitorEmailStatus::UNVERIFIED, VisitorEmailStatus::VERIFIED]
        else raise ArgumentError, "unsupported registration Contact"
        end
      raise ArgumentError, "registration candidate is not pending" unless self[key] == pending

      update!(key => verified, :binding_finalized_at => now)
      self
    end
  end

  def finalize_binding!(at: self.class.database_now)
    raise ArgumentError, "released contact binding cannot be finalized" if binding_released_at.present?
    return self if binding_finalized_at.present?

    update!(binding_finalized_at: at)
    self
  end

  def finalize_sign_up_binding!(flow:, session_nonce:)
    owner, transaction_model, status_key, pending_status, verified_status, realm =
      sign_up_binding_components(flow)
    transaction_model.connection_owner.connected_to(role: :writing) do
      flow.with_cycle_lock do
        owner.with_lock do
          with_lock do
            unless sign_up_parent_authorizes_binding?(flow, owner, session_nonce) &&
                owner.active? && owner.access_enabled? && owner.accessible?(owner.class.database_now) &&
                accessible?(self.class.database_now) && !binding_released?
              raise ArgumentError, "Email signup binding authority is unavailable"
            end

            session_ref = Digest::SHA256.hexdigest(JSON.generate(["email_sign_up", flow.public_id, flow.nonce_digest]))
            matches = transaction_model.where(
              surface: realm, operation: "sign_up", purpose: "sign_up", actor_ref: owner.public_id,
              session_ref: session_ref, email_candidate_ref: public_id, normalized_email_digest: address_digest,
            )
            raise ArgumentError, "Email signup ceremony is unavailable" unless matches.exists?

            transaction = matches.sole
            transaction.with_lock do
              unless sign_up_consumed_proof?(transaction) &&
                  sign_up_parent_authorizes_binding?(flow, owner, session_nonce)
                raise ArgumentError, "Email signup proof is unavailable"
              end

              if binding_finalized_at
                unless binding_effective? && self[status_key] == verified_status
                  raise ArgumentError, "Email signup binding conflicts with committed state"
                end
              else
                unless [pending_status, verified_status].include?(self[status_key])
                  raise ArgumentError, "Email signup candidate has an unsupported status"
                end

                update!(status_key => verified_status, :binding_finalized_at => self.class.database_now)
              end
            end
          end
        end
      end
    end
    self
  end

  def mark_sign_up_verified!(flow:, session_nonce:, code:)
    owner, transaction_model, status_key, pending_status, verified_status, realm =
      sign_up_binding_components(flow)
    transaction_model.connection_owner.connected_to(role: :writing) do
      flow.with_cycle_lock do
        owner.with_lock do
          with_lock do
            now = flow.class.database_now
            unless sign_up_parent_matches?(flow, owner, session_nonce) &&
                !flow.sign_up_terminal? && !flow.lapsed?(now) && flow.expires_at > now &&
                sign_up_source_available?(owner) && !binding_finalized_at &&
                [pending_status, verified_status].include?(self[status_key])
              raise ArgumentError, "Email signup verification authority is unavailable"
            end

            session_ref = Digest::SHA256.hexdigest(JSON.generate(["email_sign_up", flow.public_id, flow.nonce_digest]))
            matches = transaction_model.where(
              surface: realm, operation: "sign_up", purpose: "sign_up", actor_ref: owner.public_id,
              session_ref: session_ref, email_candidate_ref: public_id, normalized_email_digest: address_digest,
            )
            raise ArgumentError, "Email signup verification ceremony is unavailable" unless matches.exists?

            unless matches.sole.email_otp_verified_evidence?(
              code: code, purpose: "sign_up", actor_ref: owner.public_id, session_ref: session_ref,
              operation: "sign_up", candidate_ref: public_id,
            )
              raise ArgumentError, "Email signup verification receipt is unavailable"
            end

            update!(status_key => verified_status) if self[status_key] == pending_status
          end
        end
      end
    end
    self
  end

  def release_binding!(at: self.class.database_now)
    raise ArgumentError, "candidate contact binding cannot be released" if binding_finalized_at.blank?
    return self if binding_released_at.present?

    update!(binding_released_at: at)
    self
  end

  def retire_for_withdrawal!
    owner, status_column, suspended =
      case self
      when ClientEmail then [user, :user_email_status_id, ClientEmailStatus::SUSPENDED]
      when VisitorEmail then [visitor, :visitor_email_status_id, VisitorEmailStatus::SUSPENDED]
      else raise ArgumentError, "unsupported withdrawal email"
      end
    owner.with_lock do
      raise ArgumentError, "email withdrawal owner is not terminated" unless owner.terminated?

      with_lock do
        now = self.class.database_now
        deadline = owner.purge_eligible_at
        unless deadline == Float::INFINITY || purge_eligible_at == Float::INFINITY
          deadline = [deadline, purge_eligible_at].max
        end
        discarded = [created_at, now].max
        deadline = [deadline, discarded].max unless deadline == Float::INFINITY
        update!(
          status_column => suspended, :otp_private_key => "withdrawn", :otp_counter => "0",
          :otp_expires_at => -Float::INFINITY, :discard_at => discarded,
          :purge_eligible_at => deadline,
        )
      end
    end
    self
  end

  private

  def sign_up_binding_components(flow)
    case [self, flow]
    in [ClientEmail, ClientSignUpFlow]
      [user, ClientEmailCeremonyTransaction, :user_email_status_id,
       ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP, ClientEmailStatus::VERIFIED_WITH_SIGN_UP, "app",]
    in [VisitorEmail, VisitorSignUpFlow]
      [visitor, VisitorEmailCeremonyTransaction, :visitor_email_status_id,
       VisitorEmailStatus::UNVERIFIED_WITH_SIGN_UP, VisitorEmailStatus::VERIFIED_WITH_SIGN_UP, "com",]
    else raise ArgumentError, "unsupported Email signup binding realm"
    end
  end

  def sign_up_parent_matches?(flow, owner, session_nonce)
    session_nonce.is_a?(String) && session_nonce.encoding.ascii_compatible? && session_nonce.valid_encoding? &&
      session_nonce.present? && flow.nonce_matches?(session_nonce) && flow.principal_id == owner.id &&
      flow.entry_method == "email" && flow.pending_contact_type == "email" && flow.pending_contact_id == id
  end

  def sign_up_source_available?(owner)
    owner.active? && owner.access_enabled? && owner.accessible?(owner.class.database_now) &&
      accessible?(self.class.database_now) && !binding_released?
  end

  def sign_up_parent_authorizes_binding?(flow, owner, session_nonce)
    now = flow.class.database_now
    sign_up_parent_matches?(flow, owner, session_nonce) &&
      flow.sign_up_checkpoint_pending? && flow.requirement_cleared?("otp") &&
      !flow.lapsed?(now) && flow.expires_at > now
  end

  def sign_up_consumed_proof?(transaction)
    now = transaction.class.database_now
    transaction.status == "pending" && !transaction.consumed_at && transaction.expires_at > now &&
      transaction.otp_consumed_at.present? && !transaction.otp_cancelled_at && transaction.otp_verifier.nil? &&
      transaction.otp_receipt_verifier.present? && transaction.otp_generation.present?
  end

  def registration_ceremony_evidence?(transaction, code, session_ref)
    owner =
      case [self, transaction]
      in [ClientEmail, ClientEmailCeremonyTransaction] then user
      in [VisitorEmail, VisitorEmailCeremonyTransaction] then visitor
      else raise ArgumentError, "unsupported Email registration ceremony realm"
      end
    transaction.normalized_email_digest == address_digest && transaction.email_otp_verified_evidence?(
      code: code, purpose: "credential_registration", actor_ref: owner.public_id, session_ref: session_ref,
      operation: "registration", candidate_ref: public_id,
    )
  end

  def effective_binding_has_digest
    return if binding_finalized_at.blank?
    return if contact_binding_digest.present?

    errors.add(:base, "an effective contact binding requires a destination digest")
  end
end
