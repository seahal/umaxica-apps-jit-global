# typed: false
# frozen_string_literal: true

module SignVerificationStepUpLifecycle
  extend ActiveSupport::Concern

  private

  def require_step_up_session!
    return true if valid_step_up_session?(current_step_up_session)
    return true if handle_invalid_step_up_session!

    false
  end

  def consume_step_up_session!(method: nil)
    rs = current_step_up_session
    scope = rs.scope
    method = method.presence || rs.try(:method).presence

    now = Time.current
    ActiveRecord::Base.connected_to(role: :writing) do
      transaction = current_step_up_ceremony_transaction!(scope: scope, now: now)
      result_token = issue_step_up_result!(transaction:, scope:, method:, rs:, now:)
      record_step_up_success!

      clear_step_up_state!
      rs.destroy!
      clear_acme_step_up_completion_state! if respond_to?(:clear_acme_step_up_completion_state!, true)
      return render_acme_step_up_completion!(result_token: result_token, ri: params[:ri])
    end
  end

  def issue_step_up_result!(transaction:, scope:, method:, rs:, now:)
    IdentityStepUpCeremonyResultIssuer.issue!(
      surface: step_up_ceremony_surface,
      actor_ref: step_up_ceremony_actor_ref,
      session_ref: actor_token.public_id,
      transaction_id: transaction.transaction_id,
      grant_jti: transaction.grant_jti,
      scope: scope,
      aal: step_up_achieved_aal(method),
      method: method,
      phishing_resistant: step_up_phishing_resistant?(method),
      challenge_id: rs.id,
      expires_at: [transaction.expires_at, rs.discarded_at].compact.min,
      attempt_count: rs.attempt_count,
      now: now,
    )
  end

  def step_up_achieved_aal(method)
    (method.to_s == "email_otp") ? StepUpRequirement::NO_AAL : "aal1"
  end

  def step_up_phishing_resistant?(method)
    method.to_s == "passkey"
  end

  # acme/www owns step-up freshness. sign/id only records the ceremony audit fact and returns a
  # signed ceremony result. The freshness columns (last_step_up_*) are committed by
  # IdentityStepUpCeremonyFreshnessCommitter when acme/www consumes that result. sign must not write
  # freshness here (see adr/sign-residual-idp-surface-retirement.md).
  def record_step_up_success!
    create_audit_event!(verification_success_event_id, subject: current_verification_actor)
  end

  def valid_step_up_session?(_session_data)
    raise NotImplementedError, "#{self.class} must define #valid_step_up_session?"
  end

  def handle_invalid_step_up_session!
    raise NotImplementedError, "#{self.class} must define #handle_invalid_step_up_session!"
  end

  def clear_step_up_state!
    raise NotImplementedError, "#{self.class} must define #clear_step_up_state!"
  end

  def record_failed_step_up_attempt!(method)
    step_up_session = current_step_up_session
    if step_up_session.is_a?(Hash)
      step_up_session["attempt_count"] = step_up_session["attempt_count"].to_i + 1
    elsif step_up_session
      step_up_session.with_lock do
        step_up_session.attempt_count = step_up_session.attempt_count.to_i + 1
        step_up_session.save!
      end
    end
    actor = current_verification_actor
    StepUpCooldownStamp.call(actor, method) if actor.present?
    record_failed_step_up_activity!(actor) if actor.present?
  end

  def record_failed_step_up_activity!(actor)
    audit_class, event_id =
      case actor_token
      when ClientToken, VisitorToken
        [ClientChronicle, ClientChronicleEvent::STEP_UP_FAILED]
      when OperatorToken
        [OperatorChronicle, OperatorChronicleEvent::STEP_UP_FAILED]
      else
        raise NotImplementedError, "unsupported step-up audit token: #{actor_token.class.name}"
      end

    AuthenticationAuditWriter.write(audit_class, event_id, resource: actor, actor: actor)
  end

  def verification_model
    raise NotImplementedError, "#{self.class} must define #verification_model"
  end

  def verification_success_event_id
    raise NotImplementedError, "#{self.class} must define #verification_success_event_id"
  end

  def verification_success_notice_key
    raise NotImplementedError, "#{self.class} must define #verification_success_notice_key"
  end

  def verification_success_fallback_path
    raise NotImplementedError, "#{self.class} must define #verification_success_fallback_path"
  end

  def step_up_ceremony_surface
    case actor_token.class.name
    when "ClientToken" then "app"
    when "VisitorToken" then "com"
    when "OperatorToken" then "org"
    else
      raise NotImplementedError, "unsupported step-up token class: #{actor_token.class.name}"
    end
  end

  def step_up_ceremony_actor_ref
    current_verification_actor.public_id
  end

  def current_step_up_ceremony_transaction!(scope:, now: Time.current)
    store = IdentityStepUpCeremonyReplayStore.for(step_up_ceremony_surface)

    # Prefer lookup by transaction_id when the session already carries one from grant validation.
    # Token rotation during the sign flow (RefreshTokenable) changes actor_token.public_id between
    # the grant-receipt GET and the OTP verification POST, which breaks a session_ref-only lookup.
    # The transaction_id is an acme-issued UUID that is stable across rotations; it was written into
    # the session when the grant was validated and the actor_ref/scope guards below maintain the
    # same security invariants as the session_ref lookup.
    stored_transaction_id = acme_step_up_completion_state["transaction_id"].presence
    if stored_transaction_id
      begin
        t = store.find_transaction!(stored_transaction_id)
        if t.actor_ref == step_up_ceremony_actor_ref &&
            t.required_scope == scope.to_s &&
            !t.expired?(now: now) &&
            t.status == StepUpCeremonyTransactionable::STATUS_PENDING
          return t
        end
      rescue ActiveRecord::RecordNotFound
        nil
      end
    end

    transaction =
      store.latest_pending_for(
        actor_ref: step_up_ceremony_actor_ref,
        session_ref: actor_token.public_id,
        required_scope: scope,
        now: now,
      )
    return transaction if transaction.present?

    # acme/www owns step-up intent. sign/id must not self-issue a ceremony grant; a pending
    # transaction must already exist from an acme-issued grant (see
    # adr/sign-residual-idp-surface-retirement.md).
    raise ActionController::BadRequest, "missing acme step-up ceremony grant"
  end

  def render_acme_step_up_completion!(result_token:, ri:)
    options = {
      locals: {
        completion_url: acme_step_up_completion_url_for(step_up_ceremony_surface),
        result_token: result_token,
        ri: ri,
        csrf_token: acme_step_up_completion_csrf_token,
      },
    }
    layout = step_up_handoff_layout
    options[:layout] = layout if layout

    render("sign/shared/step_up_completion", **options)
  end

  # The completion page is a cross-host handoff form, not a page of the surface. A controller whose
  # own layout is the Inertia shell has to name the document layout here, or the handoff would be
  # rendered into a shell that never mounts it. `nil` keeps Rails' own layout lookup.
  def step_up_handoff_layout
    nil
  end

  def acme_step_up_completion_state?
    request_available_for_step_up_completion_state? &&
      acme_step_up_completion_state["transaction_id"].present?
  end

  def acme_step_up_completion_csrf_token
    acme_step_up_completion_state["csrf_token"].presence
  end

  def acme_step_up_completion_url_for(surface)
    case surface.to_s
    when "app"
      base_app_verification_completion_url(
        host: ENV.fetch("PUBLIC_BASE_SERVICE_URL"),
      )
    when "com"
      base_com_verification_completion_url(
        host: ENV.fetch("PUBLIC_BASE_CORPORATE_URL"),
      )
    when "org"
      base_org_verification_completion_url(
        host: ENV.fetch("PUBLIC_BASE_STAFF_URL"),
      )
    else
      raise NotImplementedError, "unsupported step-up surface: #{surface}"
    end
  end
end
