# typed: false
# frozen_string_literal: true

class IdentityEmailCeremonyFinalCommitter
  CONFIG = {
    "app" => {
      record_class: ClientEmail,
      owner_key: :user_id,
      status_key: :user_email_status_id,
      unverified_status: ClientEmailStatus::UNVERIFIED,
      verified_status: ClientEmailStatus::VERIFIED,
      verified_signup_status: ClientEmailStatus::VERIFIED_WITH_SIGN_UP,
      account_signup_status: ClientStatus::UNVERIFIED_WITH_SIGN_UP,
      account_verified_signup_status: ClientStatus::VERIFIED_WITH_SIGN_UP,
      audit_event_id: ClientChronicleEvent::EMAIL_REGISTERED,
      audit_class: ClientChronicle,
      audit_event_class: ClientChronicleEvent,
      audit_level_class: ClientChronicleLevel,
      audit_subject: :actor,
      binding: true,
    },
    "com" => {
      record_class: VisitorEmail,
      owner_key: :visitor_id,
      status_key: :visitor_email_status_id,
      unverified_status: VisitorEmailStatus::UNVERIFIED,
      verified_status: VisitorEmailStatus::VERIFIED,
      binding: true,
    },
    "org" => {
      record_class: OperatorEmail,
      owner_key: :staff_id,
      status_key: :staff_email_status_id,
      unverified_status: OperatorEmailStatus::UNVERIFIED,
      verified_status: OperatorEmailStatus::VERIFIED,
    },
  }.freeze

  Commit = Data.define(:transaction, :result, :email)

  def self.call!(result_token:, actor:, session_ref:, surface:, now: Time.current)
    new(result_token: result_token, actor: actor, session_ref: session_ref, surface: surface, now: now).call!
  end

  def initialize(result_token:, actor:, session_ref:, surface:, now: Time.current)
    @result_token = result_token
    @actor = actor
    @session_ref = session_ref.to_s
    @surface = surface.to_s
    @now = now
  end

  def call!
    validate_actor_binding!
    validate_transaction_state!
    validate_candidate_before_consumption!
    consumption = IdentityEmailCeremonyResultConsumer.new(transaction: transaction, now: now).call(result_token)
    commit_candidate!
    record_audit!(email)
    Commit.new(transaction: consumption.transaction, result: consumption.result, email: email)
  end

  private

  attr_reader :result_token, :actor, :session_ref, :surface, :now

  def validate_actor_binding!
    raise IdentityEmailCeremonyContract::Error, "actor is required" if actor.blank?
    raise IdentityEmailCeremonyContract::Error, "session_ref is required" if session_ref.blank?
    raise IdentityEmailCeremonyContract::Error,
          "result actor does not match current actor" unless result["actor_ref"].to_s == actor.public_id.to_s
    raise IdentityEmailCeremonyContract::Error,
          "result session does not match current session" unless result["session_ref"].to_s == session_ref
    raise IdentityEmailCeremonyContract::Error,
          "result surface does not match current surface" unless result["surface"].to_s == surface
  end

  def validate_candidate_before_consumption!
    raise IdentityEmailCeremonyContract::Error,
          "email candidate is already verified" unless status_value == config.fetch(:unverified_status)
    raise IdentityEmailCeremonyContract::Error,
          "email candidate digest does not match result" if result["normalized_email_digest"].present? &&
            result["normalized_email_digest"].to_s != email.address_digest.to_s
  end

  def validate_transaction_state!
    raise IdentityEmailCeremonyContract::Error, "transaction is expired" if transaction.expired?(now: now)
    raise IdentityEmailCeremonyContract::Error, "transaction is already consumed" if transaction.consumed?
  end

  def commit_candidate!
    config.fetch(:record_class).transaction do
      locked = config.fetch(:record_class).lock.find(email.id)
      raise IdentityEmailCeremonyContract::Error,
            "email candidate owner changed" unless locked.public_send(config.fetch(:owner_key)) == actor.id
      raise IdentityEmailCeremonyContract::Error,
            "email candidate is already verified" unless locked.public_send(config.fetch(:status_key)) ==
              config.fetch(:unverified_status)

      attributes = { config.fetch(:status_key) => final_verified_status }
      attributes[:binding_finalized_at] = now if config.fetch(:binding, false)
      locked.update!(attributes)
      update_signup_account_status! if signup_account_status_transition?
      @email = locked
    end
  end

  def final_verified_status
    return config.fetch(:verified_status) unless signup_account_status_transition?

    config.fetch(:verified_signup_status)
  end

  def signup_account_status_transition?
    config[:account_signup_status].present? && actor.respond_to?(:status_id) &&
      actor.status_id == config[:account_signup_status]
  end

  def update_signup_account_status!
    actor.update!(status_id: config.fetch(:account_verified_signup_status))
  end

  def record_audit!(subject)
    return if config[:audit_event_id].blank?

    ChronicleRecord.connected_to(role: :writing) do
      config.fetch(:audit_event_class).find_or_create_by!(id: config.fetch(:audit_event_id))
      config.fetch(:audit_level_class).find_or_create_by!(id: config.fetch(:audit_level_class)::NOTHING)
      config.fetch(:audit_class).create!(
        actor_type: actor.class.name,
        actor_id: actor.id,
        event_id: config.fetch(:audit_event_id),
        level_id: config.fetch(:audit_level_class)::NOTHING,
        subject_id: audit_subject(subject).id.to_s,
        subject_type: audit_subject(subject).class.name,
        occurred_at: now,
      )
    end
  end

  def audit_subject(subject)
    (config[:audit_subject] == :actor) ? actor : subject
  end

  def result
    @result ||= IdentityEmailCeremonyResult.decode(
      result_token,
      issuer_id: IdentityEmailCeremonyContract.sign_issuer_id(surface), now: now,
    )
  end

  def transaction
    @transaction ||= IdentityEmailCeremonyReplayStore.for(surface).find_transaction!(result["transaction_id"])
  end

  def email
    @email ||= find_candidate!
  end

  def find_candidate!
    candidate_ref = result["email_candidate_ref"].to_s
    raise IdentityEmailCeremonyContract::Error, "email candidate is required" if candidate_ref.blank?

    scope = config.fetch(:record_class).where(config.fetch(:owner_key) => actor.id)
    if config.fetch(:record_class).column_names.include?("public_id")
      scope.find_by!(public_id: candidate_ref)
    else
      scope.find(candidate_ref)
    end
  end

  def status_value
    email.public_send(config.fetch(:status_key))
  end

  def config
    CONFIG.fetch(surface) { raise IdentityEmailCeremonyContract::Error, "surface is invalid" }
  end
end
