# typed: false
# frozen_string_literal: true

module SignSettingsEmailRegistration
  private

  def start_email_ceremony!(surface:, actor:, session_ref:, candidate:, operation: "registration") # rubocop:disable Lint/UnusedMethodArgument
    nil
  end

  def finish_email_ceremony!(surface:, actor:, session_ref:, candidate:, operation: "registration") # rubocop:disable Lint/UnusedMethodArgument
    commit_settings_email_registration!(
      surface: surface, actor: actor,
      candidate: candidate,
    )
  end

  def commit_settings_email_registration!(surface:, actor:, candidate:)
    config = settings_email_registration_config(surface)
    email =
      config.fetch(:record_class).transaction do
        locked = config.fetch(:record_class).lock.find(candidate.id)
        raise IdentityEmailCeremonyContract::Error,
              "email candidate owner changed" unless locked.public_send(config.fetch(:owner_key)) == actor.id
        raise IdentityEmailCeremonyContract::Error,
              "email candidate is already verified" unless locked.public_send(config.fetch(:status_key)) ==
                config.fetch(:unverified_status)

        attributes = { config.fetch(:status_key) => config.fetch(:verified_status) }
        attributes[:binding_finalized_at] = config.fetch(:record_class).database_now if config[:binding]
        locked.update!(attributes)
        record_settings_email_registration_audit!(config, actor, locked)
        locked
      end
    on_email_registration_verified!(user_email: email, target_user: actor)
    email
  end

  # Extension point for surfaces that react to a verified settings-email
  # registration. Base::App and Base::Com explicitly choose their freshness and
  # root-session revocation policy. The default leaves that decision with the
  # concrete surface rather than copying another surface's policy.
  def on_email_registration_verified!(*)
    nil
  end

  def settings_email_registration_config(surface)
    {
      "app" => {
        record_class: ClientEmail,
        owner_key: :user_id,
        status_key: :user_email_status_id,
        unverified_status: ClientEmailStatus::UNVERIFIED,
        verified_status: ClientEmailStatus::VERIFIED,
        binding: true,
        audit_event_id: ClientChronicleEvent::EMAIL_REGISTERED,
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
    }.fetch(surface.to_s) { raise IdentityEmailCeremonyContract::Error, "surface is invalid" }
  end

  def record_settings_email_registration_audit!(config, actor, email)
    return if config[:audit_event_id].blank?

    IdentityAudit.record!(
      actor: actor,
      event_id: config.fetch(:audit_event_id),
      action: "email.register",
      subject: email,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
    )
  end

  def reset_email_ceremony_session!
    session.delete(email_ceremony_session_key)
  end

  def email_ceremony_session_key
    :email_ceremony
  end

  def email_candidate_ref(candidate)
    (candidate.respond_to?(:public_id) && candidate.public_id.present?) ? candidate.public_id : candidate.id.to_s
  end
end
