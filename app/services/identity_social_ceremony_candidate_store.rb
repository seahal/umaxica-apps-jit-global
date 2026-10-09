# typed: false
# frozen_string_literal: true

class IdentitySocialCeremonyCandidateStore
  Candidate = Data.define(
    :ref,
    :digest,
    :surface,
    :actor_ref,
    :session_ref,
    :transaction_id,
    :operation,
    :provider,
    :callback_result,
    :expires_at,
  )

  def self.store!(**attributes)
    new.store!(**attributes)
  end

  def self.fetch!(ref)
    new.fetch!(ref)
  end

  def self.fetch_consumed!(ref)
    new.fetch_consumed!(ref)
  end

  public_class_method :fetch_consumed!

  def self.consume!(ref)
    new.consume!(ref)
  end

  def self.delete(ref)
    new.delete(ref)
  end

  def store!(surface:, actor_ref:, session_ref:, transaction_id:, operation:, provider:, callback_result:, expires_at:)
    unless callback_result.is_a?(ExternalAuthentication::CallbackResult) && callback_result.verified?
      raise IdentitySocialCeremonyContract::Error, "social auth candidate is required"
    end
    unless callback_result.principal.provider == provider.to_s
      raise IdentitySocialCeremonyContract::Error, "social auth candidate provider does not match"
    end

    payload = payload_for(callback_result)
    record =
      IdentitySocialCeremonyCandidate.connection_owner.connected_to(role: :writing) do
        IdentitySocialCeremonyCandidate.create!(
          ref: SecureRandom.uuid,
          digest: digest_for(
            surface, actor_ref, session_ref, transaction_id, operation, provider,
            callback_result.principal,
          ),
          surface: surface.to_s,
          actor_ref: actor_ref.to_s,
          session_ref: session_ref.to_s,
          transaction_id: transaction_id.to_s,
          operation: operation.to_s,
          provider: provider.to_s,
          auth_hash: payload,
          expires_at: expires_at,
        )
      end
    candidate_from(record)
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
    raise IdentitySocialCeremonyContract::Error, "social auth candidate is invalid: #{e.message}"
  end

  def fetch!(ref)
    record = IdentitySocialCeremonyCandidate.find_active_by_ref!(
      ref,
      now: IdentitySocialCeremonyCandidate.database_now,
      error_class: IdentitySocialCeremonyContract::Error,
      not_found_message: "social auth candidate is not found",
      expired_message: "social auth candidate is expired",
    )
    candidate_from(record)
  rescue KeyError, TypeError, ActiveRecord::SerializationTypeMismatch => e
    raise IdentitySocialCeremonyContract::Error, "social auth candidate is invalid: #{e.message}"
  end

  def fetch_consumed!(ref)
    record = IdentitySocialCeremonyCandidate.find_by!(ref: ref.to_s)
    unless record.consumed_at && record.expires_at > IdentitySocialCeremonyCandidate.database_now
      raise IdentitySocialCeremonyContract::Error, "social completion candidate is unavailable"
    end

    candidate_from(record)
  end

  public :fetch_consumed!

  def consume!(ref)
    record = IdentitySocialCeremonyCandidate.new(ref: ref.to_s).consume!(
      now: IdentitySocialCeremonyCandidate.database_now,
      error_class: IdentitySocialCeremonyContract::Error,
      not_found_message: "social auth candidate is not found",
      expired_message: "social auth candidate is expired",
    )
    candidate_from(record)
  rescue KeyError, TypeError, ActiveRecord::SerializationTypeMismatch => e
    raise IdentitySocialCeremonyContract::Error, "social auth candidate is invalid: #{e.message}"
  end

  def delete(ref)
    IdentitySocialCeremonyCandidate.connection_owner.connected_to(role: :writing) do
      record = IdentitySocialCeremonyCandidate.find_by(ref: ref.to_s)
      record&.update!(consumed_at: IdentitySocialCeremonyCandidate.database_now)
    end
  end

  private

  def candidate_from(record)
    raise IdentitySocialCeremonyContract::Error, "social auth candidate is invalid" unless record.valid?

    Candidate.new(
      ref: record.ref,
      digest: record.digest,
      surface: record.surface,
      actor_ref: record.actor_ref,
      session_ref: record.session_ref,
      transaction_id: record.transaction_id,
      operation: record.operation,
      provider: record.provider,
      callback_result: callback_result_from(record.auth_hash),
      expires_at: record.expires_at,
    )
  end

  def digest_for(surface, actor_ref, session_ref, transaction_id, operation, provider, principal)
    data = [
      surface,
      actor_ref,
      session_ref,
      transaction_id,
      operation,
      provider,
      principal.issuer,
      principal.subject,
    ].map(&:to_s).join(":")
    OpenSSL::HMAC.hexdigest("SHA256", social_ceremony_hmac_key, data)
  end

  # Rails.app.creds reads ENV before the encrypted credentials, so the explicit
  # ENV.fetch looks redundant. It is not: tests stub creds lookups, and the
  # fetch keeps the real value reachable while still failing loudly, by name,
  # when nothing provides the key.
  def social_ceremony_hmac_key
    Rails.app.creds.option(:SOCIAL_AUTH_CEREMONY_HMAC_KEY).presence ||
      ENV.fetch("SOCIAL_AUTH_CEREMONY_HMAC_KEY")
  end

  def payload_for(callback_result)
    principal = callback_result.principal
    {
      "principal" => {
        "provider" => principal.provider,
        "subject" => principal.subject,
        "issuer" => principal.issuer,
        "audience" => principal.audience,
        "verified_at" => principal.verified_at.iso8601(6),
        "verification_authority" => principal.verification_authority,
      },
    }

  end

  def callback_result_from(payload)
    principal_payload = payload.fetch("principal")
    principal = ExternalAuthentication::VerifiedPrincipal.new(
      provider: principal_payload.fetch("provider"),
      subject: principal_payload.fetch("subject"),
      issuer: principal_payload.fetch("issuer"),
      audience: principal_payload.fetch("audience"),
      verified_at: Time.iso8601(principal_payload.fetch("verified_at")),
      verification_authority: principal_payload.fetch("verification_authority"),
    )
    unless %w(apple google).include?(principal.provider)
      raise IdentitySocialCeremonyContract::Error, "social auth candidate is invalid"
    end

    ExternalAuthentication::CallbackResult.verified(
      principal: principal,
      credential_candidate: nil,
    )
  rescue ArgumentError, KeyError, TypeError
    raise IdentitySocialCeremonyContract::Error, "social auth candidate is invalid"
  end
end
