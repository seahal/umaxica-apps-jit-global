# typed: false
# frozen_string_literal: true

class IdentityTelephoneCeremonyTransaction
  DEFAULT_TTL = 10.minutes
  STATUS_PENDING = "pending"
  STATUS_CONSUMED = "consumed"

  attr_reader :transaction_id, :surface, :actor_ref, :session_ref, :operation, :status, :grant_jti,
              :result_jti, :telephone_candidate_ref, :normalized_number_digest, :expires_at, :consumed_at,
              :created_at

  def initialize(surface:, actor_ref:, session_ref:, operation:, transaction_id: PublicId.generate,
                 grant_jti: PublicId.generate, status: STATUS_PENDING, result_jti: nil,
                 telephone_candidate_ref: nil, normalized_number_digest: nil, expires_at: nil,
                 consumed_at: nil, created_at: Time.current)
    @surface = surface.to_s
    @actor_ref = actor_ref.to_s
    @session_ref = session_ref.to_s
    @operation = operation.to_s
    @transaction_id = transaction_id.to_s
    @grant_jti = grant_jti.to_s
    @status = status.to_s
    @result_jti = result_jti&.to_s
    @telephone_candidate_ref = telephone_candidate_ref&.to_s
    @normalized_number_digest = normalized_number_digest&.to_s
    @created_at = created_at
    @expires_at = expires_at || (created_at + DEFAULT_TTL)
    @consumed_at = consumed_at

    validate!
  end

  def grant_claims(now: Time.current)
    {
      "surface" => surface,
      "actor_ref" => actor_ref,
      "session_ref" => session_ref,
      "transaction_id" => transaction_id,
      "jti" => grant_jti,
      "operation" => operation,
      "telephone_candidate_ref" => telephone_candidate_ref,
      "normalized_number_digest" => normalized_number_digest,
      "exp" => expires_at.to_i,
      "iat" => now.to_i,
    }.compact
  end

  def expired?(now: Time.current)
    expires_at.to_i <= now.to_i
  end

  def consumed? = status == STATUS_CONSUMED

  def consume(result_jti:, consumed_at: Time.current)
    self.class.new(
      surface: surface,
      actor_ref: actor_ref,
      session_ref: session_ref,
      operation: operation,
      transaction_id: transaction_id,
      grant_jti: grant_jti,
      status: STATUS_CONSUMED,
      result_jti: result_jti,
      telephone_candidate_ref: telephone_candidate_ref,
      normalized_number_digest: normalized_number_digest,
      expires_at: expires_at,
      consumed_at: consumed_at,
      created_at: created_at,
    )
  end

  private

  def validate!
    IdentityTelephoneCeremonyContract.fetch_surface_value(IdentityTelephoneCeremonyContract::ACME_ISSUERS, surface)
    raise IdentityTelephoneCeremony::Error, "operation is invalid" unless IdentityTelephoneCeremonyContract::OPERATIONS.include?(operation)
    raise IdentityTelephoneCeremony::Error, "actor_ref is required" if actor_ref.blank?
    raise IdentityTelephoneCeremony::Error, "session_ref is required" if session_ref.blank?
    raise IdentityTelephoneCeremony::Error, "transaction_id is required" if transaction_id.blank?
    raise IdentityTelephoneCeremony::Error, "grant_jti is required" if grant_jti.blank?
    raise IdentityTelephoneCeremony::Error, "status is invalid" unless [STATUS_PENDING,
                                                                        STATUS_CONSUMED,].include?(status)
    raise IdentityTelephoneCeremony::Error,
          "result_jti is required for consumed transaction" if consumed? && result_jti.blank?
  end
end
