# typed: false
# frozen_string_literal: true

module AuthenticationSequenceGate
  extend ActiveSupport::Concern

  def sign_in_sequence_redirect_path(pt: nil, default_path: after_dashboard_path)
    cycle = current_db_sign_in_flow_for_sequence
    return sign_in_session_limit_path(pt: pt) if respond_to?(
      :session_limit_resolution,
      true,
    ) && session_limit_resolution

    if cycle
      url_pt = signed_pt_token(pt || cycle.return_to)
      return sign_in_checkpoint_path(pt: url_pt) if cycle.sign_in_checkpoint_pending?
      return sign_in_selector_path(pt: url_pt) if cycle.sign_in_selector_pending?
      return issue_welcome_gate_and_path(pt: url_pt, sequence_id: cycle.public_id) if cycle.sign_in_completed?
      return reject_invalid_sign_in_sequence_path(default_path) unless cycle.sign_in_guardrail_pending?

      result =
        with_sign_in_flow_writing(cycle) do
          sign_in_guardrail_participant(cycle).advance_if_clear!
        end
      return default_path if result.blocking?

      return sign_in_checkpoint_path(pt: url_pt)
    end

    default_path
  end

  def sign_in_session_limit_path(pt: nil)
    attrs = { ri: current_region_identifier }
    safe_pt = signed_pt_token(pt)
    attrs[AuthIoKeys::Params::PT] = safe_pt if safe_pt.present?

    if respond_to?(:sign_app_sign_in_session_path, true)
      sign_app_sign_in_session_path(**attrs)
    elsif respond_to?(:sign_org_sign_in_session_path, true)
      sign_org_sign_in_session_path(**attrs)
    elsif respond_to?(:sign_com_sign_in_session_path, true)
      sign_com_sign_in_session_path(**attrs)
    else
      path = "/in/session"
      query = attrs.compact.to_query
      query.present? ? "#{path}?#{query}" : path
    end
  end

  def reject_invalid_sign_in_sequence_path(default_path)
    default_path
  end

  def redirect_to_sign_in_sequence!(pt: nil, default_path: after_dashboard_path, **redirect_options)
    destination = sign_in_sequence_redirect_path(pt: pt, default_path: default_path)
    if destination.to_s.start_with?("/")
      redirect_to(destination, allow_other_host: false, **redirect_options)
    else
      redirect_to_jump_url(destination, **redirect_options)
    end
  end

  def after_checkpoint_sequence_path(pt: nil, default_path: after_dashboard_path, sequence_id: nil)
    return issue_welcome_gate_and_path(pt: pt, sequence_id: sequence_id) if dashboard_sequence_step_required?

    path_from_signed_pt(signed_pt_token(pt)) || default_path
  end

  def redirect_after_checkpoint_sequence!(pt: nil, default_path: after_dashboard_path, **redirect_options)
    cycle = current_db_sign_in_flow_for_sequence
    safe_redirect_options = redirect_options.merge(allow_other_host: false)
    if cycle
      return reject_invalid_sign_in_sequence! unless cycle.sign_in_checkpoint_pending?
      return reject_invalid_sign_in_sequence! unless allowed_to?(:complete_checkpoint?, cycle)

      result =
        with_sign_in_flow_writing(cycle) do
          sign_in_checkpoint_participant(cycle).advance_if_clear!
        end
      if result.blocking?
        return redirect_to(sign_in_checkpoint_path(pt: cycle.reload.return_to.presence || pt), **safe_redirect_options)
      end

      return redirect_to(
        sign_in_selector_path(pt: cycle.reload.return_to.presence || pt),
        **safe_redirect_options,
      )
    end

    redirect_to(after_checkpoint_sequence_path(pt: pt, default_path: default_path), **safe_redirect_options)
  end

  def continue_checkpoint_sequence_without_content!
    cycle = current_db_sign_in_flow_for_sequence
    if cycle
      return reject_invalid_sign_in_sequence! unless cycle.sign_in_checkpoint_pending?
      return reject_invalid_sign_in_sequence! unless allowed_to?(:show_checkpoint?, cycle)

      authorize!(cycle, to: :show_checkpoint?)

      result =
        with_sign_in_flow_writing(cycle) do
          sign_in_checkpoint_participant(cycle).advance_if_clear!
        end
      if result.blocking?
        @checkpoint_items = result.stack
        return
      end

      if local_authentication_ceremony?
        return redirect_local_checkpoint_result!(cycle)
      end

      if oidc_authorization_login_challenge.present?
        redirect_to_surface_url(after_login_path)
        return
      end
      redirect_to_surface_url(
        issue_welcome_gate_and_path(pt: cycle.return_to, sequence_id: cycle.public_id),
      )
      return
    end

    if sign_in_sequence_required_for_participant?(:checkpoint)
      return unless require_sign_in_sequence_participant!(
        participant: :checkpoint,
        policy_rule: :show_checkpoint?,
      )
    end

    redirect_after_checkpoint_sequence!(pt: signed_pt_param)
  end

  def redirect_local_checkpoint_result!(cycle)
    with_sign_in_flow_writing(cycle) do
      SignInSelectorParticipant.new(cycle: cycle, actor: sign_in_flow_actor(cycle)).auto_commit_single!
    end
    redirect_to(after_login_path, status: :see_other)
  end

  # OIDC credentials are established by Auth's ceremony, not by an Auth root
  # session. Resolve the actor from the DB-backed sign-in cycle when the
  # transaction challenge is present; a browser credential is only a normal
  # fallback for non-OIDC checkpoint entry.
  def authenticate_sign_in_sequence_actor!
    return authenticate! unless oidc_authorization_login_challenge_present? || local_authentication_ceremony?

    cycle = current_db_sign_in_flow_for_sequence
    actor = cycle && sign_in_flow_actor(cycle)
    return reject_invalid_sign_in_sequence! unless actor.is_a?(resource_class)
    return reject_invalid_sign_in_sequence! unless actor.login_allowed?

    @current_resource = actor
    true
  end

  # The OIDC result handoff must use the actor bound to the pending cycle. It
  # must never fall back to an unrelated Auth root credential or to a request
  # supplied identifier.
  def authenticate_oidc_result_actor!
    return reject_invalid_sign_in_sequence! unless oidc_authorization_login_challenge_present?

    cycle = current_db_sign_in_flow_for_sequence
    actor = cycle && sign_in_flow_actor(cycle)
    return reject_invalid_sign_in_sequence! unless cycle && oidc_result_handoff_cycle_ready?(cycle)
    return reject_invalid_sign_in_sequence! unless actor.is_a?(resource_class)
    return reject_invalid_sign_in_sequence! unless actor.login_allowed?

    @current_resource = actor
    true
  end

  # Auth transfers OIDC evidence before Base commits the root session. The cycle is therefore
  # allowed to remain in the ordinary post-primary graph until Base's issuance lock advances it
  # to SESSION_ISSUANCE_PENDING and completes it. This is an evidence handoff, not post-auth
  # routing; terminal cycles and cycles that have not recorded a primary event have no authority.
  def oidc_result_handoff_cycle_ready?(cycle)
    cycle.authentication_event_at.present? &&
      !cycle.sign_in_failed? && !cycle.sign_in_expired? && !cycle.sign_in_cancelled? &&
      !cycle.sign_in_halted? &&
      (cycle.sign_in_checkpoint_pending? || cycle.sign_in_selector_pending? ||
        cycle.sign_in_session_issuance_pending? || cycle.sign_in_completed?)
  end

  # rubocop:disable Metrics/AbcSize
  def continue_welcome_sequence_without_content!
    cycle = current_db_sign_in_flow_for_sequence
    if cycle
      process_cycle_based_sequence!(cycle)
    else
      process_non_cycle_sequence!
    end
  end

  def process_cycle_based_sequence!(cycle)
    if cycle.sign_in_completed?
      decision = PostAuthenticationRoutingResolver.call(
        flow: cycle,
        default_path: after_welcome_path,
        oidc_continuation: oidc_authorization_login_challenge.present? ? after_login_path : nil,
      )
      clear_welcome_gate!
      clear_current_sign_in_flow_locator!
      return redirect_to(decision.target)
    end
    return redirect_to(sign_in_session_limit_path(pt: cycle.return_to)) if session_limit_resolution
    return redirect_to(sign_in_checkpoint_path(pt: cycle.return_to)) if cycle.sign_in_checkpoint_pending?
    return redirect_to(sign_in_selector_path(pt: cycle.return_to)) if cycle.sign_in_selector_pending?
    return redirect_to(after_welcome_path) unless welcome_gate_available?
    return redirect_to(after_welcome_path) unless consume_welcome_gate!(sequence_id: cycle.public_id)

    bind_current_session_to_sign_in_flow!(cycle)
    clear_welcome_gate!
    clear_current_sign_in_flow_locator!
    @welcome_next_path = after_welcome_path
  end

  def process_non_cycle_sequence!
    return redirect_to(after_welcome_path) unless welcome_gate_available?

    sign_in_sequence_carrier.complete! if sign_in_sequence_carrier.current.participant == "dashboard"
    return redirect_to(after_welcome_path) unless consume_welcome_gate!

    destination = path_from_signed_pt(path_target_value) || after_welcome_path
    clear_welcome_gate!
    sign_in_sequence_carrier.clear!
    @welcome_next_path = destination
    # rubocop:enable Metrics/AbcSize
  end

  alias continue_dashboard_sequence_without_content! continue_welcome_sequence_without_content!

  def continue_selector_sequence!
    cycle = current_db_sign_in_flow_for_sequence
    return reject_invalid_sign_in_sequence! unless cycle
    return reject_invalid_sign_in_sequence! unless cycle.sign_in_selector_pending?
    return reject_invalid_sign_in_sequence! unless allowed_to?(:show_selector?, cycle)

    with_sign_in_flow_writing(cycle) do
      SignInSelectorParticipant.new(
        cycle: cycle,
        actor: sign_in_flow_actor(cycle),
        authn_public_id: Actor.authn.login_public_id,
      ).auto_commit_single!
    end

    result = issue_active_session_for_selector!(cycle.reload)
    return reject_invalid_sign_in_sequence! unless result[:status] == :success

    redirect_to_surface_url(
      issue_welcome_gate_and_path(pt: cycle.reload.return_to, sequence_id: cycle.public_id),
    )
  rescue SignInSelectorParticipant::Error
    reject_invalid_sign_in_sequence!
  end

  def enforce_sign_in_selector_gate!
    return unless logged_in?

    cycle = current_db_sign_in_flow_for_sequence
    return unless cycle&.sign_in_selector_pending?
    return if sign_in_selector_allowed_request?

    unless request.format.html?
      render plain: I18n.t("errors.messages.not_authorized"), status: :forbidden
      return
    end

    redirect_to(sign_in_selector_path(pt: cycle.return_to))
  end

  def dashboard_sequence_step_required?
    true
  end

  def sign_in_sequence_required_for_participant?(_participant)
    true
  end

  def sign_in_sequence_carrier
    @sign_in_sequence_carrier ||= SignInSequenceCarrier.new(session, surface: sign_in_sequence_surface)
  end

  def sign_in_sequence_surface
    Actor.tld
  end

  def sign_in_selector_path(pt: nil)
    attrs = { ri: current_region_identifier }
    safe_pt = signed_pt_token(pt)
    attrs[AuthIoKeys::Params::PT] = safe_pt if safe_pt.present?

    if respond_to?(:sign_app_selector_path, true)
      sign_app_selector_path(**attrs)
    elsif respond_to?(:sign_org_selector_path, true)
      sign_org_selector_path(**attrs)
    elsif respond_to?(:sign_com_selector_path, true)
      sign_com_selector_path(**attrs)
    else
      path = "/selector"
      query = attrs.compact.to_query
      query.present? ? "#{path}?#{query}" : path
    end
  end

  def sign_in_selector_allowed_request?
    return true if oidc_authorization_login_challenge_present? && controller_path.end_with?("/oidc_handoffs")

    allowed_paths = [
      sign_in_selector_path,
      sign_in_session_limit_path,
    ]
    allowed_paths.map { |path| URI.parse(path).path }.include?(request.path) ||
      controller_path.end_with?("/outs")
  rescue URI::InvalidURIError
    false
  end

  def welcome_gate_key
    {
      "app" => :app_sign_in_welcome,
      "com" => :com_sign_in_welcome,
      "org" => :org_sign_in_welcome,
    }[sign_in_sequence_surface.to_s] || :sign_in_welcome
  end

  def issue_welcome_gate_and_path(pt:, sequence_id: nil)
    clear_welcome_gate!
    session[welcome_gate_key] = {
      "remaining" => 5,
      "issued_at" => Time.current.to_i,
      "expires_at" => 10.minutes.from_now.to_i,
      "sequence_id" => sequence_id.presence,
    }
    sign_in_welcome_path(pt: pt)
  end

  def clear_welcome_gate!
    session.delete(welcome_gate_key)
  end

  def consume_welcome_gate!(sequence_id: nil)
    gate = session[welcome_gate_key]
    return false unless gate.is_a?(Hash)
    return clear_welcome_gate! && false if welcome_gate_expired?(gate)
    return clear_welcome_gate! && false if gate["remaining"].to_i <= 0
    if sequence_id.present? && gate["sequence_id"].present? && gate["sequence_id"].to_s != sequence_id.to_s
      return clear_welcome_gate! && false
    end

    remaining = gate["remaining"].to_i - 1
    if remaining <= 0
      clear_welcome_gate!
    else
      session[welcome_gate_key] = gate.merge("remaining" => remaining)
    end
    true
  end

  def welcome_gate_available?(sequence_id: nil)
    gate = session[welcome_gate_key]
    return false unless gate.is_a?(Hash)
    return clear_welcome_gate! && false if welcome_gate_expired?(gate)
    return clear_welcome_gate! && false if gate["remaining"].to_i <= 0
    if sequence_id.present? && gate["sequence_id"].present? && gate["sequence_id"].to_s != sequence_id.to_s
      return clear_welcome_gate! && false
    end

    true
  end

  def welcome_gate_expired?(gate)
    expires_at = gate["expires_at"].to_i
    expires_at <= 0 || Time.current.to_i >= expires_at
  end

  def require_sign_in_sequence_participant!(participant:, policy_rule:)
    sequence = sign_in_sequence_carrier.current

    allowed = allowed_to?(policy_rule, sequence, with: SignIn::SequencePolicy)
    return true if allowed

    sign_in_sequence_carrier.expire! if sequence.present? && sequence.expired?
    Rails.logger.info(
      JitLogEvent.format(
        "authentication.sign_in_sequence.rejected",
        surface: Actor.tld,
        participant: participant.to_s,
        state: sequence&.state,
        expired: sequence&.expired?,
        actor_type: sequence&.actor_type,
      ),
    )
    render plain: I18n.t("errors.messages.not_authorized"), status: :bad_request
    false
  end

  def current_db_sign_in_flow_for_sequence
    return auth_ceremony_local_sign_in_flow if local_authentication_ceremony?

    if respond_to?(:session_limit_resolution, true)
      resolution = session_limit_resolution
      return resolution.sign_in_flow if resolution
    end

    @current_db_sign_in_flow_for_sequence ||=
      begin
        token = respond_to?(:current_session, true) ? current_session : nil
        actor = current_resource
        SignInCycleLocator.new(
          session,
          surface: sign_in_sequence_surface,
          actor: actor,
          token: token,
          allow_principal_without_token: respond_to?(:oidc_authorization_login_challenge, true) &&
            oidc_authorization_login_challenge.present?,
        ).current
      end
  rescue ArgumentError
    nil
  end

  def with_sign_in_flow_writing(cycle, &)
    cycle.class.connection_class_for_self.connected_to(role: :writing, &)
  end

  def sign_in_checkpoint_participant(cycle)
    SignInCheckpointParticipant.new(cycle: cycle, actor: sign_in_flow_actor(cycle))
  end

  def sign_in_guardrail_participant(cycle)
    SignInGuardrailParticipant.new(cycle: cycle, actor: sign_in_flow_actor(cycle))
  end

  def clear_current_sign_in_flow_locator!
    sign_in_flow_locator_for(actor: current_resource, token: current_session).clear!
  rescue ArgumentError
    nil
  end

  def reject_invalid_sign_in_sequence!
    render plain: I18n.t("errors.messages.not_authorized"), status: :bad_request
    false
  end

  private

  def start_sign_in_flow_for!(resource, pt:, authentication_method: nil)
    if resource.is_a?(Client) && authentication_method == "secret" && oidc_authentication_ceremony?
      return with_claimed_oidc_secret_flow(resource) { |flow, _ceremony| flow }
    end

    if local_authentication_ceremony?
      cycle = auth_ceremony_local_sign_in_flow
      raise AuthCeremonySession::InvalidTransition, "local authentication admission is missing" unless cycle
      unless cycle.is_a?(sign_in_flow_class_for(resource))
        raise AuthCeremonySession::InvalidTransition, "local authentication surface mismatch"
      end

      with_sign_in_flow_writing(cycle) do
        cycle.with_lock do
          unless cycle.sign_in_primary_pending? && (cycle.principal_id.nil? || cycle.principal_id == resource.id)
            raise AuthCeremonySession::InvalidTransition, "local authentication flow is already bound"
          end

          cycle.update!(principal_id: resource.id)
        end
      end
      return cycle
    end

    cycle_class = sign_in_flow_class_for(resource)
    nonce = SecureRandom.urlsafe_base64(SignInCycleLocator::NONCE_BYTES)
    cycle_class.create!(
      principal_id: resource.id,
      state_id: cycle_class.state_id_for("PRIMARY_PENDING"),
      return_to: path_from_signed_pt(signed_pt_token(pt)),
      nonce_digest: cycle_class.digest_nonce(nonce),
    )
  end

  def with_claimed_oidc_secret_flow(resource)
    transaction = auth_ceremony_authorization_transaction
    ceremony = admitted_auth_ceremony_session
    raise AuthCeremonySession::InvalidTransition, "Secret OIDC admission missing" unless transaction && ceremony

    resource.with_lock do
      AppTicketRecord.connected_to(role: :writing) do
        transaction.with_lock do
          flow = transaction.secret_sign_in_flow
          raise AuthCeremonySession::InvalidTransition, "Secret OIDC flow missing" unless flow

          flow.lock!
          ceremony.lock!
          now = ClientSignInFlow.database_now
          unless transaction.status == "pending" && !transaction.expired?(now: now) &&
              !transaction.login_challenge_expired?(now: now) && flow.principal_id == resource.id &&
              flow.sign_in_primary_pending? && !flow.expired?(now) &&
              ceremony.admitted? && ceremony.active?(now: now) &&
              ceremony.authorization_transaction_ref == transaction.transaction_id &&
              ClientSecretCredential.where.not(claimed_at: nil).exists?(
                client_id: resource.id, claim_sign_in_flow_ref: flow.public_id,
                claim_ceremony_session_id: ceremony.id, consumed_at: nil, discard_at: Float::INFINITY,
              )
            raise AuthCeremonySession::InvalidTransition, "Secret OIDC claim binding mismatch"
          end

          yield flow, ceremony
        end
      end
    end
  end

  def advance_pending_sign_in_flow_after_primary!(cycle, resource, result)
    return result unless cycle&.persisted?

    # The final session issuer may advance the same flow through session
    # issuance and completion while this request still holds the pre-issuance
    # object. A committed flow is terminal; do not replay the pre-issuance
    # guardrail transition against that terminal state.
    cycle.reload
    return result if cycle.sign_in_completed?

    case result[:status]
    when :session_limit_pending
      sign_in_flow_locator_for(actor: resource).issue!(cycle) unless local_authentication_ceremony?
    when :success, :authentication_evidence_recorded
      cycle.advance_sign_in_to_guardrail! if cycle.sign_in_primary_pending? || cycle.sign_in_mfa_pending?
      if cycle.sign_in_guardrail_pending?
        guardrail = SignInGuardrailParticipant.new(cycle: cycle, actor: resource)
        guardrail.advance_if_clear!
      end
      sign_in_flow_locator_for(actor: resource).issue!(cycle.reload) unless local_authentication_ceremony?
    else
      cycle.halt_sign_in! unless cycle.sign_in_completed? || cycle.sign_in_failed? || cycle.sign_in_expired? ||
        cycle.sign_in_cancelled? || cycle.sign_in_halted?
      sign_in_flow_locator_for(actor: resource).issue!(cycle) if result[:status] == :session_limit_hard_reject
    end
    result
  end

  def bind_current_session_to_sign_in_flow!(cycle)
    return unless cycle.has_attribute?(:token_id)
    return if cycle.token_id.present?
    return unless current_session

    with_sign_in_flow_writing(cycle) do
      changes = { token: current_session }
      changes[:session_issued_at] = Time.current if cycle.has_attribute?(:session_issued_at)
      cycle.reload.update!(changes)
    end
  end

  # Session-limit resolution ends in the same final issuance boundary as any
  # root login: log_in re-locks the flow, re-counts the limit, re-checks the
  # cooldown, and binds the new session to this flow in one transaction. When
  # the limit is full again by then, the durable resolution remains terminally
  # resolved and the parent remains pending for a fresh resolution.
  def promote_current_session_limit_cycle!(actor)
    cycle = current_db_sign_in_flow_for_sequence
    resolution = respond_to?(:session_limit_resolution, true) ? session_limit_resolution : nil
    return false unless cycle && resolution
    return false unless resolution.actor_ref == actor.public_id && resolution.resolved?

    if (local_locator = local_sign_in_locator_for_pending_resume(cycle))
      result = LocalAuthenticationSessionCommitter.resume_pending!(
        controller: self, flow: cycle, actor: actor, nonce: local_locator.fetch(:nonce),
      )
      return false unless result[:status] == :success

      session[local_locator.fetch(:session_key)] = local_locator.fetch(:value)
      reset_current_db_sign_in_flow_for_sequence!
      return true
    end

    authentication_event_at = cycle.authentication_event_at
    return false if authentication_event_at.blank?

    session_result = log_in(
      actor,
      establishment: :root_login,
      sign_in_flow: cycle,
      record_login_audit: true,
      token_kind_id: "BROWSER_WEB",
      require_totp_check: false,
      audit_context: { auth_method: "session_limit_promotion" },
      established_authentication_method: cycle.authentication_method,
      authentication_event_at: authentication_event_at,
    )
    return false unless session_result[:status] == :success

    cycle = cycle.reload
    if cycle.sign_in_guardrail_pending?
      with_sign_in_flow_writing(cycle) do
        SignInGuardrailParticipant.new(cycle: cycle, actor: actor).advance_if_clear!
      end
    end
    sign_in_flow_locator_for(actor: actor, token: current_session).issue!(cycle.reload)
    reset_current_db_sign_in_flow_for_sequence!
    true
  end

  def local_sign_in_locator_for_pending_resume(cycle)
    session_key =
      case cycle
      when ClientSignInFlow then SignInCycleLocator::SESSION_KEYS.fetch(:app)
      when VisitorSignInFlow then SignInCycleLocator::SESSION_KEYS.fetch(:com)
      when OperatorSignInFlow then SignInCycleLocator::SESSION_KEYS.fetch(:org)
      else return nil
      end
    value = session[session_key]
    return unless value.is_a?(Hash) && value["public_id"].to_s == cycle.public_id.to_s

    { session_key: session_key, value: value, nonce: value.fetch("nonce") }
  end

  # Selector completion issues the root login for a flow that has not issued
  # one yet. A flow that already carries a session (or a browser that is
  # already signed in) is refused by the final boundary rather than receiving
  # a second root session.
  def issue_active_session_for_selector!(cycle)
    actor = cycle.principal
    return { status: :invalid_request } unless actor
    return { status: :invalid_request } if logged_in?

    log_in(
      actor,
      establishment: :root_login,
      sign_in_flow: cycle,
      record_login_audit: true,
      token_kind_id: "BROWSER_WEB",
      require_totp_check: false,
      audit_context: { auth_method: "selector" },
    )
  end

  def sign_in_flow_actor(cycle)
    return current_resource if current_resource
    return unless cycle.respond_to?(:principal)

    cycle.principal
  end

  def oidc_authorization_login_challenge_present?
    return false unless respond_to?(:oidc_authorization_login_challenge, true)

    oidc_authorization_login_challenge.present?
  end

  def pending_mfa_sign_in_flow_for(resource)
    if local_authentication_ceremony?
      cycle = auth_ceremony_local_sign_in_flow
      return cycle if cycle&.principal_id == resource.id

      return nil
    end

    sign_in_flow_locator_for(actor: resource).current
  end

  def sign_in_flow_locator_for(actor: nil, token: nil)
    SignInCycleLocator.new(
      session,
      surface: sign_in_sequence_surface_for_actor(actor),
      actor: actor,
      token: token,
    )
  end

  def sign_in_sequence_surface_for_actor(actor)
    case actor
    when ::Client then :app
    when ::Visitor then :com
    when ::Operator then :org
    else sign_in_sequence_surface
    end
  end

  def sign_in_flow_class_for(resource)
    case resource
    when ::Client then ClientSignInFlow
    when ::Visitor then VisitorSignInFlow
    when ::Operator then OperatorSignInFlow
    else
      raise ArgumentError, "unsupported sign-in cycle actor"
    end
  end

  def reset_current_db_sign_in_flow_for_sequence!
    return unless defined?(@current_db_sign_in_flow_for_sequence)

    remove_instance_variable(:@current_db_sign_in_flow_for_sequence)
  end

  def sign_in_result_from_session_result(result, actor: nil, sequence_id: nil)
    SignInResult.from_session_result(
      result,
      actor: actor,
      sequence_id: sequence_id,
      session_management_path: session_management_path,
    )
  end

  private :redirect_local_checkpoint_result!, :reject_invalid_sign_in_sequence_path, :welcome_gate_expired?,
          :authenticate_sign_in_sequence_actor!, :authenticate_oidc_result_actor!,
          :oidc_authorization_login_challenge_present?
end
