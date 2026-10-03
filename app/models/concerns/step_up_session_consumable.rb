# typed: false
# frozen_string_literal: true

module StepUpSessionConsumable
  extend ActiveSupport::Concern

  class ChallengeError < StandardError; end

  public

  def issue_bound_passkey_challenge!(transaction:, challenge:, rp_id:, origin:)
    unless challenge.is_a?(String) && challenge.present? && challenge.exclude?("\0") &&
        rp_id.is_a?(String) && rp_id.present? &&
        origin.is_a?(String) && origin.present?
      raise ArgumentError, "Passkey challenge binding is required"
    end

    Webauthn::RelyingPartyConfig.new(rp_id: rp_id, origin: origin)

    self.class.connection_class_for_self.connected_to(role: :writing) do
      with_lock do
        transaction.with_lock do
          now = transaction.class.database_now
          validate_passkey_transaction!(transaction, now: now)
          deadline = [passkey_challenge_expires_at || (now + 10.minutes), transaction.expires_at].min
          raise ChallengeError, "challenge expired" if deadline <= now

          update!(
            passkey_challenge: challenge, passkey_challenge_ref: SecureRandom.uuid,
            passkey_rp_id: rp_id, passkey_origin: origin,
            passkey_challenge_expires_at: deadline, passkey_challenge_consumed_at: nil,
          )
          passkey_challenge_ref
        end
      end
    end
  end

  def consume_bound_passkey_challenge!(transaction:, reference:, rp_id:, origin:)
    challenge = nil
    failure = nil
    self.class.connection_class_for_self.connected_to(role: :writing) do
      with_lock do
        transaction.with_lock do
          now = transaction.class.database_now
          validate_passkey_transaction!(transaction, now: now)
          unless reference.is_a?(String) && reference.present? && reference == passkey_challenge_ref &&
              passkey_challenge_consumed_at.nil? && passkey_challenge.present?
            raise ChallengeError, "challenge unavailable"
          end

          # Commit the burn before raising for an expired or mismatched assertion. A rescue outside
          # this transaction must not resurrect a challenge after signature verification fails.
          update!(passkey_challenge_consumed_at: now)
          if passkey_challenge_expires_at <= now || passkey_rp_id != rp_id || passkey_origin != origin
            failure = ChallengeError
          else
            challenge = passkey_challenge
          end
        end
      end
    end
    raise failure, "challenge rejected" if failure

    challenge
  end

  private

  def validate_passkey_transaction!(transaction, now:)
    unless transaction.is_a?(passkey_transaction_model) &&
        step_up_ceremony_transaction_ref == transaction.transaction_id &&
        transaction.session_ref == passkey_session_token.public_id &&
        %w(step_up reauthentication).include?(transaction.purpose) && transaction.status == "pending" &&
        !transaction.expired?(now: now) && transaction.allowed_methods_array.include?("passkey") &&
        status == "PENDING" && discard_at > now
      raise ChallengeError, "ceremony unavailable"
    end
  end

  class_methods do
    public

    # Runs the one-time completion work while holding the session row lock. A nil block result
    # leaves the row untouched; a successful result destroys the pending row before the transaction
    # commits. This keeps a concurrent worker from issuing a second step-up result.
    def consume_pending!(id:, now: Time.current)
      raise ArgumentError, "a completion block is required" unless block_given?

      result = nil
      transaction do
        locked = lock.find_by(id: id)
        if locked&.status == "PENDING" && locked.discard_at > now
          candidate = yield locked
          unless candidate.nil?
            locked.destroy!
            result = candidate
          end
        end
      end
      result
    end
  end
end
