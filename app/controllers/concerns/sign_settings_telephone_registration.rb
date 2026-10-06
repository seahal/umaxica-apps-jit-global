# typed: false
# frozen_string_literal: true

module SignSettingsTelephoneRegistration
  extend ActiveSupport::Concern

  private

  def start_telephone_ceremony!(surface:, actor:, session_ref:, candidate:) # rubocop:disable Lint/UnusedMethodArgument
    nil
  end

  def finish_telephone_ceremony!(surface:, actor:, session_ref:, candidate:) # rubocop:disable Lint/UnusedMethodArgument
    commit_settings_telephone_registration!(
      surface: surface, actor: actor,
      candidate: candidate,
    )
  end

  def commit_settings_telephone_registration!(surface:, actor:, candidate:)
    config = settings_telephone_registration_config(surface)
    config.fetch(:record_class).transaction do
      locked = config.fetch(:record_class).lock.find(candidate.id)
      raise IdentityTelephoneCeremony::Error,
            "telephone candidate owner changed" unless locked.public_send(config.fetch(:owner_key)) == actor.id
      raise IdentityTelephoneCeremony::Error,
            "telephone candidate is already verified" unless locked.public_send(config.fetch(:status_key)) ==
              config.fetch(:unverified_status)

      attributes = { config.fetch(:status_key) => config.fetch(:verified_status) }
      attributes[:binding_finalized_at] = config.fetch(:record_class).database_now if config[:binding]
      locked.update!(attributes)
      record_settings_telephone_registration_audit!(config, actor, locked)
      locked
    end
  end

  def settings_telephone_registration_config(surface)
    {
      "app" => {
        record_class: ClientTelephone,
        owner_key: :user_id,
        status_key: :user_telephone_status_id,
        unverified_status: ClientTelephoneStatus::UNVERIFIED,
        verified_status: ClientTelephoneStatus::VERIFIED,
        binding: true,
        audit_event_id: ClientChronicleEvent::TELEPHONE_REGISTERED,
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
    }.fetch(surface.to_s) { raise IdentityTelephoneCeremony::Error, "surface is invalid" }
  end

  def record_settings_telephone_registration_audit!(config, actor, telephone)
    return if config[:audit_event_id].blank?

    IdentityAudit.record!(
      actor: actor,
      event_id: config.fetch(:audit_event_id),
      action: "telephone.register",
      subject: telephone,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
    )
  end

  def reset_telephone_ceremony_session!
    session.delete(telephone_ceremony_session_key)
  end

  def telephone_ceremony_session_key
    :telephone_ceremony
  end

  def telephone_candidate_ref(candidate)
    (candidate.respond_to?(:public_id) && candidate.public_id.present?) ? candidate.public_id : candidate.id.to_s
  end
end
