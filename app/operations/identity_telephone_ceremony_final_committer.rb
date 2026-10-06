# typed: false
# frozen_string_literal: true

class IdentityTelephoneCeremonyFinalCommitter
  CONFIG = {
    "app" => {
      record_class: ClientTelephone,
      owner_key: :user_id,
      status_key: :user_telephone_status_id,
      unverified_status: ClientTelephoneStatus::UNVERIFIED,
      verified_status: ClientTelephoneStatus::VERIFIED,
      audit_event_id: ClientChronicleEvent::TELEPHONE_REGISTERED,
      audit_class: ClientChronicle,
      audit_event_class: ClientChronicleEvent,
      audit_level_class: ClientChronicleLevel,
      audit_subject: :actor,
      binding: true,
    },
    "com" => {
      record_class: VisitorTelephone,
      owner_key: :visitor_id,
      status_key: :visitor_telephone_status_id,
      unverified_status: VisitorTelephoneStatus::UNVERIFIED,
      verified_status: VisitorTelephoneStatus::VERIFIED,
      binding: true,
    },
    "org" => {
      record_class: OperatorTelephone,
      owner_key: :staff_id,
      status_key: :staff_telephone_status_id,
      unverified_status: OperatorTelephoneStatus::UNVERIFIED,
      verified_status: OperatorTelephoneStatus::VERIFIED,
    },
  }.freeze

  Commit = Data.define(:transaction, :result, :telephone)

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
    consumption = IdentityTelephoneCeremonyResultConsumer.new(transaction: transaction, now: now).call(result_token)
    commit_candidate!
    record_audit!(telephone)
    Commit.new(transaction: consumption.transaction, result: consumption.result, telephone: telephone)
  end

  private

  attr_reader :result_token, :actor, :session_ref, :surface, :now

  def validate_actor_binding!
    raise IdentityTelephoneCeremony::Error, "actor is required" if actor.blank?
    raise IdentityTelephoneCeremony::Error, "session_ref is required" if session_ref.blank?
    raise IdentityTelephoneCeremony::Error,
          "result actor does not match current actor" unless result["actor_ref"].to_s == actor.public_id.to_s
    raise IdentityTelephoneCeremony::Error,
          "result session does not match current session" unless result["session_ref"].to_s == session_ref
    raise IdentityTelephoneCeremony::Error,
          "result surface does not match current surface" unless result["surface"].to_s == surface
  end

  def validate_candidate_before_consumption!
    raise IdentityTelephoneCeremony::Error,
          "telephone candidate is already verified" unless status_value == config.fetch(:unverified_status)
    raise IdentityTelephoneCeremony::Error,
          "telephone candidate digest does not match result" if result["normalized_number_digest"].present? &&
            result["normalized_number_digest"].to_s != telephone.number_digest.to_s
  end

  def validate_transaction_state!
    raise IdentityTelephoneCeremony::Error, "transaction is expired" if transaction.expired?(now: now)
    raise IdentityTelephoneCeremony::Error, "transaction is already consumed" if transaction.consumed?
  end

  def commit_candidate!
    config.fetch(:record_class).transaction do
      locked = config.fetch(:record_class).lock.find(telephone.id)
      raise IdentityTelephoneCeremony::Error,
            "telephone candidate owner changed" unless locked.public_send(config.fetch(:owner_key)) == actor.id
      raise IdentityTelephoneCeremony::Error,
            "telephone candidate is already verified" unless locked.public_send(config.fetch(:status_key)) ==
              config.fetch(:unverified_status)

      attributes = { config.fetch(:status_key) => config.fetch(:verified_status) }
      attributes[:binding_finalized_at] = now if config.fetch(:binding, false)
      locked.update!(attributes)
      @telephone = locked
    end
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
    @result ||= IdentityTelephoneCeremonyResult.decode(
      result_token,
      issuer_id: IdentityTelephoneCeremonyContract.sign_issuer_id(surface), now: now,
    )
  end

  def transaction
    @transaction ||= IdentityTelephoneCeremonyReplayStore.for(surface).find_transaction!(result["transaction_id"])
  end

  def telephone
    @telephone ||= find_candidate!
  end

  def find_candidate!
    candidate_ref = result["telephone_candidate_ref"].to_s
    raise IdentityTelephoneCeremony::Error, "telephone candidate is required" if candidate_ref.blank?

    scope = config.fetch(:record_class).where(config.fetch(:owner_key) => actor.id)
    if config.fetch(:record_class).column_names.include?("public_id")
      scope.find_by!(public_id: candidate_ref)
    else
      scope.find(candidate_ref)
    end
  end

  def status_value
    telephone.public_send(config.fetch(:status_key))
  end

  def config
    CONFIG.fetch(surface) { raise IdentityTelephoneCeremony::Error, "surface is invalid" }
  end
end
