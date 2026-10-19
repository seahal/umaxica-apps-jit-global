# typed: false
# frozen_string_literal: true

class IdentityPasskeyCeremonyFinalCommitter
  CONFIG = {
    "app" => {
      record_class: ClientPasskey,
      owner_key: :user_id,
      owner_association: :client_passkeys,
      audit_event_id: ClientChronicleEvent::PASSKEY_REGISTERED,
    },
    "com" => {
      record_class: VisitorPasskey,
      owner_key: :visitor_id,
      owner_association: :visitor_passkeys,
    },
    "org" => {
      record_class: OperatorPasskey,
      owner_key: :staff_id,
      owner_association: :staff_passkeys,
      audit_event_id: OperatorChronicleEvent::PASSKEY_REGISTERED,
    },
  }.freeze

  Commit = Data.define(:transaction, :result, :passkey)

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
    validate_actor_binding!
    validate_transaction_state!
    consumption = IdentityPasskeyCeremonyResultConsumer.new(transaction: transaction, now: now).call(result_token)
    passkey = commit_passkey!(consumption.result)
    Commit.new(transaction: consumption.transaction, result: consumption.result, passkey: passkey)
  end

  private

  attr_reader :result_token, :actor, :session_ref, :surface, :ip_address, :user_agent, :now

  def validate_actor_binding!
    raise IdentityPasskeyCeremonyContract::Error, "actor is required" if actor.blank?
    raise IdentityPasskeyCeremonyContract::Error, "session_ref is required" if session_ref.blank?
    raise IdentityPasskeyCeremonyContract::Error,
          "result actor does not match current actor" unless result["actor_ref"].to_s == actor.public_id.to_s
    raise IdentityPasskeyCeremonyContract::Error,
          "result session does not match current session" unless result["session_ref"].to_s == session_ref
    raise IdentityPasskeyCeremonyContract::Error,
          "result surface does not match current surface" unless result["surface"].to_s == surface
  end

  def validate_transaction_state!
    raise IdentityPasskeyCeremonyContract::Error, "transaction is expired" if transaction.expired?(now: now)
    raise IdentityPasskeyCeremonyContract::Error, "transaction is already consumed" if transaction.consumed?
  end

  def commit_passkey!(result)
    config.fetch(:record_class).transaction do
      attributes = {
        config.fetch(:owner_key) => actor.id,
        :webauthn_id => result["webauthn_id"],
        :public_key => result["public_key"],
        :sign_count => result["sign_count"].to_i,
        :uv_verified_at => now,
        :description => result["description"].presence || I18n.t("sign.default_passkey_description"),
        **Webauthn::AuthenticatorMetadata.permit(result["authenticator_metadata"]),
      }
      PasskeyRegistrationOperation.call!(
        actor: actor,
        passkey_class: config.fetch(:record_class),
        attributes: attributes.except(config.fetch(:owner_key)),
        audit: {
          event_type: "passkey.registered.settings",
          surface: surface,
          actor_ref: actor.public_id,
          # The replay transaction is the authoritative operation binding.  Real result
          # payloads carry the same reference, but older ceremony adapters may omit it from
          # the decoded evidence; do not turn that harmless representation difference into a
          # KeyError after the transaction has already been validated.
          operation_ref: result["transaction_id"].presence || transaction.transaction_id,
        },
      )
    end
  rescue ActiveRecord::RecordNotUnique => e
    raise unless PasskeyRegistrationOperation.credential_id_conflict?(e)

    raise IdentityPasskeyCeremonyContract::Error, "passkey credential is already registered"
  end

  def result
    @result ||= IdentityPasskeyCeremonyResult.decode(
      result_token,
      issuer_id: IdentityPasskeyCeremonyContract.sign_issuer_id(surface), now: now,
    )
  end

  def transaction
    @transaction ||= IdentityPasskeyCeremonyReplayStore.for(surface).find_transaction!(result["transaction_id"])
  end

  def config
    CONFIG.fetch(surface) { raise IdentityPasskeyCeremonyContract::Error, "surface is invalid" }
  end
end
