# typed: false
# frozen_string_literal: true

class IdentitySocialCeremonyResultIssuer
  def self.issue!(grant_token:, callback_result:, surface:, actor_ref:, session_ref:, operation:, challenge_id: nil,
                  candidate: nil, birthdate: nil,
                  now: Time.current)
    new(
      grant_token: grant_token,
      callback_result: callback_result,
      surface: surface,
      actor_ref: actor_ref,
      session_ref: session_ref,
      operation: operation,
      challenge_id: challenge_id,
      candidate: candidate,
      birthdate: birthdate,
      now: now,
    ).issue!
  end

  def initialize(grant_token:, callback_result:, surface:, actor_ref:, session_ref:, operation:, challenge_id: nil,
                 candidate: nil, birthdate: nil,
                 now: Time.current)
    @grant_token = grant_token
    @callback_result = callback_result
    @surface = surface.to_s
    @actor_ref = actor_ref.to_s
    @session_ref = session_ref.to_s
    @operation = operation.to_s
    @challenge_id = challenge_id
    @provided_candidate = candidate
    @birthdate = birthdate
    @now = now
  end

  def issue!
    validate_grant!
    IdentitySocialCeremonyResult.issue(
      result_claims,
      issuer_id: IdentitySocialCeremonyContract.sign_issuer_id(surface), now: now,
    )
  end

  private

  attr_reader :grant_token, :callback_result, :surface, :actor_ref, :session_ref, :operation, :challenge_id,
              :provided_candidate, :birthdate, :now

  def validate_grant!
    raise IdentitySocialCeremonyContract::Error, "social ceremony grant is required" if grant_token.blank?
    raise IdentitySocialCeremonyContract::Error, "provider subject is required" if provider_subject.blank?
    raise IdentitySocialCeremonyContract::Error,
          "grant surface does not match ceremony" unless grant["surface"].to_s == surface
    raise IdentitySocialCeremonyContract::Error,
          "grant actor does not match ceremony" unless grant["actor_ref"].to_s == actor_ref
    raise IdentitySocialCeremonyContract::Error,
          "grant session does not match ceremony" unless grant["session_ref"].to_s == session_ref
    raise IdentitySocialCeremonyContract::Error,
          "grant operation does not match ceremony" unless grant["operation"].to_s == operation
    raise IdentitySocialCeremonyContract::Error,
          "grant provider does not match ceremony" unless grant["provider"].to_s == provider
    raise IdentitySocialCeremonyContract::Error,
          "grant jti does not match transaction" unless grant["jti"].to_s == transaction.grant_jti.to_s
    raise IdentitySocialCeremonyContract::Error, "transaction is expired" if transaction.expired?(now: now)
    raise IdentitySocialCeremonyContract::Error, "transaction is already consumed" if transaction.consumed?
  end

  def grant
    @grant ||= IdentitySocialCeremonyGrant.decode(
      grant_token,
      issuer_id: IdentitySocialCeremonyContract.acme_issuer_id(surface), now: now,
    )
  end

  def transaction
    @transaction ||= IdentitySocialCeremonyReplayStore.for(surface).find_transaction!(grant["transaction_id"])
  end

  def provider
    @provider ||= principal.provider
  end

  def provider_subject
    @provider_subject ||= principal.subject
  end

  def provider_subject_digest
    @provider_subject_digest ||= IdentitySocialCeremonyContract.provider_subject_digest(
      provider: provider,
      subject: provider_subject,
    )
  end

  def candidate
    return provided_candidate if provided_candidate.present?

    @candidate ||= IdentitySocialCeremonyCandidateStore.store!(
      surface: surface,
      actor_ref: actor_ref,
      session_ref: session_ref,
      transaction_id: transaction.transaction_id,
      operation: operation,
      provider: provider,
      callback_result: callback_result,
      expires_at: transaction.expires_at,
    )
  end

  def principal
    unless callback_result.is_a?(ExternalAuthentication::CallbackResult) && callback_result.verified?
      raise IdentitySocialCeremonyContract::Error, "verified callback result is required"
    end

    callback_result.principal
  end

  def result_claims
    {
      "surface" => surface,
      "actor_ref" => actor_ref,
      "session_ref" => session_ref,
      "transaction_id" => transaction.transaction_id,
      "grant_jti" => transaction.grant_jti,
      "result_jti" => SecureRandom.uuid,
      "operation" => operation,
      "provider" => provider,
      "provider_subject_ref" => provider_subject_digest,
      "provider_subject_digest" => provider_subject_digest,
      "candidate_ref" => candidate&.ref,
      "candidate_digest" => candidate&.digest,
      "birthdate" => birthdate,
      # The adapter's verified_at is the only trusted authentication-event
      # timestamp available at this boundary. Preserve it in the signed
      # handoff so Base can establish its session with the event time rather
      # than the later browser handoff time.
      "auth_time" => principal.verified_at.to_i,
      "verified_at" => now.to_i,
      "challenge_id" => challenge_id.presence || transaction.transaction_id,
      "expires_at" => transaction.expires_at.to_i,
    }.compact
  end
end
