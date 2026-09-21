# typed: false
# frozen_string_literal: true

class IdentityTotpCeremonyFinalCommitter
  Commit = Data.define(:transaction, :result, :totp)

  def self.call!(result_token:, actor:, session_ref:, surface:, ip_address: nil, user_agent: nil, now: Time.current)
    new(
      result_token: result_token,
      actor: actor,
      session_ref: session_ref,
      surface: surface,
      ip_address: ip_address,
      user_agent: user_agent,
      now: now,
    ).call!
  end

  def initialize(result_token:, actor:, session_ref:, surface:, ip_address: nil, user_agent: nil, now: Time.current)
    @result_token = result_token
    @actor = actor
    @session_ref = session_ref.to_s
    @surface = surface.to_s
    @ip_address = ip_address
    @user_agent = user_agent
    @now = now
  end

  def call!
    validate_surface!
    validate_actor_binding!
    validate_transaction_state!
    candidate = fetch_candidate!
    validate_enrollment_policy!
    consumption = IdentityTotpCeremonyResultConsumer.new(transaction: transaction, now: now).call(result_token)
    totp = commit_totp!(candidate)
    IdentityTotpCeremonyCandidateStore.delete(candidate.ref)
    record_audit!
    Commit.new(transaction: consumption.transaction, result: consumption.result, totp: totp)
  end

  private

  attr_reader :result_token, :actor, :session_ref, :surface, :ip_address, :user_agent, :now

  def validate_surface!
    raise IdentityTotpCeremonyContract::Error, "surface is invalid" unless surface == "app"
  end

  def validate_actor_binding!
    raise IdentityTotpCeremonyContract::Error, "actor is required" if actor.blank?
    raise IdentityTotpCeremonyContract::Error, "session_ref is required" if session_ref.blank?
    raise IdentityTotpCeremonyContract::Error,
          "result actor does not match current actor" unless result["actor_ref"].to_s == actor.public_id.to_s
    raise IdentityTotpCeremonyContract::Error,
          "result session does not match current session" unless result["session_ref"].to_s == session_ref
    raise IdentityTotpCeremonyContract::Error,
          "result surface does not match current surface" unless result["surface"].to_s == surface
  end

  def validate_transaction_state!
    raise IdentityTotpCeremonyContract::Error, "transaction is expired" if transaction.expired?(now: now)
    raise IdentityTotpCeremonyContract::Error, "transaction is already consumed" if transaction.consumed?
  end

  def fetch_candidate!
    candidate = IdentityTotpCeremonyCandidateStore.fetch!(result["credential_candidate_ref"])
    raise IdentityTotpCeremonyContract::Error, "candidate digest does not match result" unless candidate.digest.to_s ==
      result["credential_candidate_digest"].to_s
    raise IdentityTotpCeremonyContract::Error,
          "candidate actor does not match current actor" unless candidate.actor_ref.to_s == actor.public_id.to_s
    raise IdentityTotpCeremonyContract::Error,
          "candidate session does not match current session" unless candidate.session_ref.to_s == session_ref
    raise IdentityTotpCeremonyContract::Error,
          "candidate surface does not match current surface" unless candidate.surface.to_s == surface

    candidate
  end

  def validate_enrollment_policy!
    credentials = actor.client_totp_credentials
    slot_count =
      if credentials.respond_to?(:where)
        credentials.where(
          user_identity_totp_credential_status_id: ClientTotpCredential.slot_consuming_status_ids,
        ).count
      else
        credentials.count
      end
    return if slot_count < ClientTotpCredential::MAX_TOTP_SLOTS

    raise IdentityTotpCeremonyContract::Error, "TOTP credential limit is reached"
  end

  def commit_totp!(candidate)
    ClientTotpCredential.create_for_user!(
      user: actor,
      private_key: candidate.private_key,
      last_otp_at: candidate.last_otp_at,
      title: candidate.title,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
  rescue ClientTotpCredential::SlotLimitExceeded
    raise IdentityTotpCeremonyContract::Error, "TOTP credential limit is reached"
  end

  def record_audit!
    IdentityAudit.record!(
      actor: actor,
      event_id: ClientChronicleEvent::TOTP_ENABLED,
      action: "totp.enable",
      ip_address: ip_address,
      user_agent: user_agent,
    )
  end

  def result
    @result ||= IdentityTotpCeremonyResult.decode(
      result_token,
      issuer_id: IdentityTotpCeremonyContract.sign_issuer_id(surface), now: now,
    )
  end

  def transaction
    @transaction ||= IdentityTotpCeremonyReplayStore.for(surface).find_transaction!(result["transaction_id"])
  end
end
