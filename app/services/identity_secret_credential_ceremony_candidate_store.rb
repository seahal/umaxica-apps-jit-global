# typed: false
# frozen_string_literal: true

class IdentitySecretCredentialCeremonyCandidateStore
  Candidate = Data.define(
    :ref,
    :digest,
    :surface,
    :actor_ref,
    :session_ref,
    :transaction_id,
    :operation,
    :password_digest,
    :name,
    :enabled,
    :expires_at,
  )

  def self.store!(**attributes)
    new.store!(**attributes)
  end

  def self.fetch!(ref)
    new.fetch!(ref)
  end

  def self.consume!(ref)
    new.consume!(ref)
  end

  def self.delete(ref)
    new.delete(ref)
  end

  def store!(surface:, actor_ref:, session_ref:, transaction_id:, operation:, password_digest:, name:, enabled:,
             expires_at:)
    raise IdentitySecretCredentialCeremonyContract::Error,
          "secret credential password digest is required" if password_digest.blank?

    enabled_value = ActiveModel::Type::Boolean.new.cast(enabled)
    record =
      IdentitySecretCredentialCeremonyCandidate.connection_owner.connected_to(role: :writing) do
        IdentityCeremonyCandidateRecord.create_with_generated_ref(
          IdentitySecretCredentialCeremonyCandidate,
          digest: digest_for(
            surface, actor_ref, session_ref,
            transaction_id, operation, password_digest,
          ),
          surface: surface.to_s,
          actor_ref: actor_ref.to_s,
          session_ref: session_ref.to_s,
          transaction_id: transaction_id.to_s,
          operation: operation.to_s,
          password_digest: password_digest.to_s,
          name: name.to_s,
          enabled: enabled_value,
          expires_at: expires_at,
        )
      end
    candidate_from(record)
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
    raise IdentitySecretCredentialCeremonyContract::Error, "secret credential candidate is invalid: #{e.message}"
  end

  def fetch!(ref)
    record = IdentitySecretCredentialCeremonyCandidate.find_active_by_ref!(
      ref,
      now: Time.current,
      error_class: IdentitySecretCredentialCeremonyContract::Error,
      not_found_message: "secret credential candidate is not found",
      expired_message: "secret credential candidate is expired",
    )
    candidate_from(record)
  end

  def consume!(ref)
    record = IdentitySecretCredentialCeremonyCandidate.new(ref: ref.to_s).consume!(
      now: Time.current,
      error_class: IdentitySecretCredentialCeremonyContract::Error,
      not_found_message: "secret credential candidate is not found",
      expired_message: "secret credential candidate is expired",
    )
    candidate_from(record)
  end

  def delete(ref)
    IdentitySecretCredentialCeremonyCandidate.connection_owner.connected_to(role: :writing) do
      record = IdentitySecretCredentialCeremonyCandidate.find_by(ref: ref.to_s)
      record&.update!(consumed_at: Time.current)
    end
  end

  private

  def candidate_from(record)
    raise IdentitySecretCredentialCeremonyContract::Error, "secret credential candidate is invalid" unless record.valid?

    Candidate.new(
      ref: record.ref,
      digest: record.digest,
      surface: record.surface,
      actor_ref: record.actor_ref,
      session_ref: record.session_ref,
      transaction_id: record.transaction_id,
      operation: record.operation,
      password_digest: record.password_digest,
      name: record.name,
      enabled: ActiveModel::Type::Boolean.new.cast(record.enabled),
      expires_at: record.expires_at,
    )
  end

  def digest_for(surface, actor_ref, session_ref, transaction_id, operation, password_digest)
    data = [surface, actor_ref, session_ref, transaction_id, operation, password_digest].map(&:to_s).join(":")
    OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, data)
  end
end
