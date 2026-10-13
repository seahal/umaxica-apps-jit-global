# typed: false
# frozen_string_literal: true

class IdentityTotpCeremonyCandidateStore
  Candidate = Data.define(
    :ref,
    :digest,
    :surface,
    :actor_ref,
    :session_ref,
    :private_key,
    :title,
    :last_otp_at,
    :expires_at,
  )

  DEFAULT_TTL = 10.minutes

  def self.store!(surface:, actor_ref:, session_ref:, private_key:, title:, last_otp_at:, expires_at:)
    new.store!(
      surface: surface,
      actor_ref: actor_ref,
      session_ref: session_ref,
      private_key: private_key,
      title: title,
      last_otp_at: last_otp_at,
      expires_at: expires_at,
    )
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

  def store!(surface:, actor_ref:, session_ref:, private_key:, title:, last_otp_at:, expires_at:)
    raise IdentityTotpCeremonyContract::Error, "TOTP candidate secret is required" if private_key.blank?

    record =
      IdentityTotpCeremonyCandidate.connection_owner.connected_to(role: :writing) do
        IdentityCeremonyCandidateRecord.create_with_generated_ref(
          IdentityTotpCeremonyCandidate,
          digest: digest_for(private_key),
          surface: surface.to_s,
          actor_ref: actor_ref.to_s,
          session_ref: session_ref.to_s,
          private_key: private_key.to_s,
          title: title.to_s,
          last_otp_at: Time.zone.at(last_otp_at.to_i),
          expires_at: expires_at,
        )
      end
    candidate_from(record)
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
    raise IdentityTotpCeremonyContract::Error, "TOTP candidate is invalid: #{e.message}"
  end

  def fetch!(ref)
    record = IdentityTotpCeremonyCandidate.find_active_by_ref!(
      ref,
      now: Time.current,
      error_class: IdentityTotpCeremonyContract::Error,
      not_found_message: "TOTP candidate is not found",
      expired_message: "TOTP candidate is expired",
    )
    candidate_from(record)
  end

  def consume!(ref)
    record = IdentityTotpCeremonyCandidate.new(ref: ref.to_s).consume!(
      now: Time.current,
      error_class: IdentityTotpCeremonyContract::Error,
      not_found_message: "TOTP candidate is not found",
      expired_message: "TOTP candidate is expired",
    )
    candidate_from(record)
  end

  def delete(ref)
    IdentityTotpCeremonyCandidate.connection_owner.connected_to(role: :writing) do
      record = IdentityTotpCeremonyCandidate.find_by(ref: ref.to_s)
      record&.update!(consumed_at: Time.current)
    end
  end

  private

  def candidate_from(record)
    raise IdentityTotpCeremonyContract::Error, "TOTP candidate is invalid" unless record.valid?

    Candidate.new(
      ref: record.ref,
      digest: record.digest,
      surface: record.surface,
      actor_ref: record.actor_ref,
      session_ref: record.session_ref,
      private_key: record.private_key,
      title: record.title,
      last_otp_at: record.last_otp_at,
      expires_at: record.expires_at,
    )
  end

  def digest_for(private_key)
    OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, private_key.to_s)
  end
end
