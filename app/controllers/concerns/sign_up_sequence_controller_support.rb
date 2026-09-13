# typed: false
# frozen_string_literal: true

module SignUpSequenceControllerSupport
  extend ActiveSupport::Concern

  AGE_RESTRICTED_I18N_KEYS = {
    "app" => "sign.app.registration.checkpoint.age_restricted",
    "com" => "sign.com.registration.checkpoint.age_restricted",
  }.freeze
  private_constant :AGE_RESTRICTED_I18N_KEYS

  private

  def load_sign_up_ticket
    return render_sign_up_age_restricted if sign_up_session_state.age_restricted?

    @sign_up_ticket = current_sign_up_flow_ticket
    return if @sign_up_ticket

    render plain: I18n.t("errors.messages.not_found"), status: :not_found
  end

  def load_sign_up_checkpoint_ticket
    return render_sign_up_age_restricted if sign_up_session_state.age_restricted?

    @sign_up_ticket = current_sign_up_flow_ticket
    return if @sign_up_ticket

    sign_up_session_state.clear_all!
    session_missing_key = "sign.#{sign_up_surface}.registration.session_missing"
    redirect_to(
      sign_up_restart_path,
      alert: I18n.t(session_missing_key),
    )
  end

  def authorize_sign_up_participant!(rule)
    return if performed?

    context = sign_up_policy_context
    return if allowed_to?(rule, context, with: SignUp::ParticipantPolicy)

    render plain: I18n.t("errors.messages.not_authorized"), status: :forbidden
  end

  def authorize_sign_up_requirement!(rule)
    return if performed?

    context = sign_up_requirement_context
    return if context && allowed_to?(rule, context, with: SignUp::RequirementPolicy)

    render plain: I18n.t("errors.messages.not_authorized"), status: :forbidden
  end

  def authorize_sign_up_requirement_or_cleared_continue!(rule)
    return if performed?

    context = sign_up_requirement_context
    return if context && (
      allowed_to?(rule, context, with: SignUp::RequirementPolicy) ||
        allowed_to?(:continue_after_cleared_requirement?, context, with: SignUp::RequirementPolicy)
    )

    render plain: I18n.t("errors.messages.not_authorized"), status: :forbidden
  end

  def sign_up_policy_context
    SignUpPolicyContext.build(
      surface: sign_up_surface,
      actor_authentication: sign_up_actor_authentication,
      ticket: @sign_up_ticket,
    )
  end

  def sign_up_requirement_context
    requirement = params[:requirement].presence || params.dig(:sign_up, :requirement).presence
    return if requirement.blank?

    SignUpRequirementContext.build(
      surface: sign_up_surface,
      actor_authentication: sign_up_actor_authentication,
      ticket: @sign_up_ticket,
      requirement: requirement,
      pending_actor: sign_up_pending_actor,
    )
  rescue ArgumentError
    nil
  end

  def run_sign_up_event(event, payload: {})
    return if performed?

    render_sign_up_result(perform_sign_up_event(event, payload: payload))
  end

  def run_sign_up_requirement_event(payload: {})
    return if performed?

    result = perform_sign_up_event(
      :clear_requirement,
      payload: payload.merge(checkpoint_version: sign_up_checkpoint_version_param),
    )
    return finalize_sign_up_from_checkpoint! if result.success? && result.next_event == :finalize

    render_sign_up_result(result)
  end

  def enter_sign_up_checkpoint!
    return if performed?

    unless @sign_up_ticket.sign_up_checkpoint_pending?
      result = perform_sign_up_event(:enter_checkpoint)
      return render_sign_up_result(result) unless result.success?
    end

    return finalize_sign_up_from_checkpoint! if sign_up_missing_requirements.empty?

    render_sign_up_checkpoint
  end

  def perform_sign_up_event(event, payload: {})
    sign_up_ticket_record_class.connected_to(role: :writing) do
      SignUpStateMachine.call(
        ticket: @sign_up_ticket,
        event: event,
        actor_context: sign_up_actor_authentication,
        payload: payload,
      )
    end
  end

  def render_sign_up_result(result)
    status =
      case result.status
      when :ok, :advanced, :completed, :sign_in_handoff_accepted
        :ok
      when :blocked, :unauthorized
        :forbidden
      when :expired
        :gone
      else
        :unprocessable_content
      end

    render plain: result.status.to_s, status: status
  end

  def render_sign_up_checkpoint
    @sign_up_missing_requirements = sign_up_missing_requirements
    @sign_up_completed_requirements = @sign_up_ticket.completed_requirements
    @sign_up_pending_actor = sign_up_pending_actor

    render :show, status: :ok
  end

  def sign_up_missing_requirements
    SignUpRequirementRegistry.for_ticket(
      @sign_up_ticket,
      surface: sign_up_surface,
    ).missing_requirements(@sign_up_ticket.completed_requirements)
  rescue ArgumentError
    []
  end

  def sign_up_requirement_cleared?(requirement)
    SignUpRequirementRegistry.for_ticket(
      @sign_up_ticket,
      surface: sign_up_surface,
    ).requirement_cleared?(@sign_up_ticket.completed_requirements, requirement)
  rescue ArgumentError
    false
  end

  def persist_sign_up_birthdate_requirement
    return true unless sign_up_requirement_param == "birthdate"
    return false unless validate_sign_up_checkpoint_version!

    actor = sign_up_pending_actor
    unless actor
      render plain: I18n.t("errors.messages.not_found"), status: :not_found
      return false
    end

    actor.birthdate = sign_up_birthdate_param
    unless actor.save
      render plain: actor.errors.full_messages.to_sentence, status: :unprocessable_content
      return false
    end

    true
  end

  def clear_sign_up_birthdate_requirement
    return if performed?
    return continue_after_cleared_sign_up_requirement if sign_up_requirement_cleared?(:birthdate)
    return unless validate_sign_up_checkpoint_version!

    actor = sign_up_pending_actor
    unless actor
      render plain: I18n.t("errors.messages.not_found"), status: :not_found
      return
    end

    actor.birthdate = sign_up_birthdate_param
    unless actor.save
      render plain: actor.errors.full_messages.to_sentence, status: :unprocessable_content
      return
    end

    unless SignUpEligibilityPolicy.minimum_age_reached?(
      actor.birthdate,
      surface: sign_up_surface,
      today: Time.zone.today,
    )
      sign_up_session_state.age_restricted = true
      result = SignUpTermination.call(cycle: @sign_up_ticket, event: :fail, actor_context: Actor.authn)
      return render_sign_up_result(result) unless result.success? || result.status == :failed

      render_sign_up_age_restricted
      return
    end

    result = perform_sign_up_event(
      :clear_requirement,
      payload: {
        requirement: :birthdate,
        checkpoint_version: sign_up_checkpoint_version_param,
      },
    )
    return finalize_sign_up_from_checkpoint! if result.success? && result.next_event == :finalize

    render_sign_up_result(result)
  end

  def continue_after_cleared_sign_up_requirement
    return finalize_sign_up_from_checkpoint! if sign_up_missing_requirements.empty?

    render_sign_up_checkpoint
  end

  def render_sign_up_age_restricted
    response.headers["Cache-Control"] = "no-store, private"
    i18n_key =
      AGE_RESTRICTED_I18N_KEYS.fetch(sign_up_surface.to_s) do
        raise ArgumentError, "Unknown sign_up_surface for age-restricted lookup: #{sign_up_surface.inspect}"
      end
    @sign_up_age_restricted_message = I18n.t(i18n_key)
    @sign_up_age_restricted_restart_path = sign_up_restart_path
    render "auth/#{sign_up_surface}/sign/up/checkpoints/age_restricted", status: :ok
  end

  def finalize_sign_up_from_checkpoint!(json: false)
    context = sign_up_finalization_context
    return render_sign_up_finalization_forbidden(json: json) unless context
    return render_sign_up_finalization_forbidden(json: json) unless
      allowed_to?(:finalize?, context, with: SignUp::FinalizationPolicy)

    # This is the shared sign-up completion boundary for all surfaces.
    #
    # Surface matrix:
    # - app: email, google, apple, telephone
    # - com: email, telephone
    # - org: not routed through this sign-up finalize path
    #
    # The surface-specific credential work happens before this method
    # returns, inside `finalize_sign_up_side_effect!`. After that, the
    # durable identity graph is provisioned, then the actor is handed off
    # to the sign-in boundary.
    finalized = nil
    handoff = nil
    sign_in_result = nil

    # Serialize the entire finalize/handoff/complete sequence under the
    # cycle's row-level lock. Without this, two concurrent finalize
    # requests for the same cycle each see CHECKPOINT_PENDING, both
    # mutate the actor (one fails on rp_account uniqueness, leaving a
    # half-built state), and only afterwards the StateMachine catches
    # the duplicate transition. Holding the lock from the policy
    # re-check through `:complete` keeps the actor mutation and the
    # cycle transition atomic with respect to peers.
    sign_up_ticket_record_class.connected_to(role: :writing) do
      @sign_up_ticket.with_cycle_lock do
        @sign_up_ticket.reload

        unless @sign_up_ticket.sign_up_checkpoint_pending?
          finalized = SignUpResult.build(
            status: :invalid_transition,
            ticket: @sign_up_ticket,
            errors: ["ticket is not at checkpoint"],
          )
          next
        end

        finalization_result = finalize_sign_up_side_effect!
        finalized = perform_sign_up_event(
          :finalize, payload: { finalization_result: finalization_result },
        )
        next unless finalized.success?

        IdentityGraphProvisioner.call!(
          surface: sign_up_surface,
          principal: context.pending_actor,
        )
        sign_in_result = handoff_to_sign_in_flow!(context.pending_actor)
        handoff = perform_sign_up_event(
          :handoff_to_sign_in,
          payload: {
            sign_in_handoff_status: sign_in_result.success? ? :accepted : :failed,
            sign_in_handoff: sign_in_result.status,
          },
        )
        next unless handoff.success?

        perform_sign_up_event(:complete)
      end
    end

    return render_sign_up_failure_result(finalized, json: json) unless finalized&.success?
    return render_sign_up_failure_result(handoff, json: json) unless handoff&.success?

    sign_up_session_state.clear_all!
    redirect_after_sign_up_handoff!(sign_in_result, json: json)
  end

  def sign_up_session_state
    SignUpSessionState.for(session, surface: sign_up_surface)
  end

  def sign_up_ticket_public_id
    session[sign_up_sequence_session_key].presence
  end

  def sign_up_requirement_param
    (params[:requirement].presence || params.dig(:sign_up, :requirement).presence).to_s
  end

  def sign_up_birthdate_param
    explicit_birthdate =
      params[:birthdate].presence ||
      params.dig(:sign_up, :birthdate).presence ||
      params.dig(:client, :birthdate).presence ||
      params.dig(:visitor, :birthdate).presence
    return explicit_birthdate if explicit_birthdate.present?

    sign_up_split_birthdate_param
  end

  def sign_up_split_birthdate_param
    year = params[:birthdate_year].presence || params[:birth_year].presence
    month = params[:birthdate_month].presence || params[:birth_month].presence
    day = params[:birthdate_day].presence || params[:birth_day].presence
    return if year.blank? && month.blank? && day.blank?

    [
      year.to_s.rjust(4, "0"),
      month.to_s.rjust(2, "0"),
      day.to_s.rjust(2, "0"),
    ].join("-")
  end

  def sign_up_checkpoint_version_param
    params[:checkpoint_version].presence || params.dig(:sign_up, :checkpoint_version).presence
  end

  def validate_sign_up_checkpoint_version!(json: false)
    return true unless @sign_up_ticket&.has_attribute?(:checkpoint_version)

    submitted_version = sign_up_checkpoint_version_param
    valid =
      submitted_version.present? &&
      Integer(submitted_version.to_s, 10) == @sign_up_ticket.checkpoint_version

    return true if valid

    if json
      render json: { error: "stale_checkpoint" }, status: :conflict
    else
      render plain: "stale_checkpoint", status: :conflict
    end
    false
  rescue ArgumentError, TypeError
    if json
      render json: { error: "stale_checkpoint" }, status: :conflict
    else
      render plain: "stale_checkpoint", status: :conflict
    end
    false
  end

  def sign_up_actor_authentication
    Actor::Authentication.new(
      login_public_id: Actor.authn.login_public_id,
      access_claims: Actor.authn.access_claims,
      acr: Actor.authn.acr,
      amr: Actor.authn.amr,
      actor_type: Actor.authn.actor_type,
      actor_id: Actor.authn.actor_id,
      restricted: Actor.authn.restricted?,
      active_sign_sequence_id: @sign_up_ticket&.public_id,
    )
  end

  def sign_up_flow_locator
    SignUpCycleLocator.new(session, surface: sign_up_surface, cycle_class: sign_up_ticket_class)
  end

  def current_sign_up_flow_ticket
    sign_up_flow_locator.current || sign_up_ticket_from_sequence_id
  end

  def sign_up_ticket_from_sequence_id
    public_id = sign_up_ticket_public_id
    return if public_id.blank?

    ticket = sign_up_ticket_class.find_by(public_id: public_id)
    return unless ticket
    return if ticket.expired? || (ticket.respond_to?(:lapsed?) && ticket.lapsed?)
    return if ticket.respond_to?(:sign_up_terminal?) && ticket.sign_up_terminal?

    ticket
  end

  def sign_up_pending_actor
    return if @sign_up_ticket&.principal_id.blank?

    sign_up_pending_actor_model&.find_by(id: @sign_up_ticket.principal_id)
  end

  def validate_sign_up_checkpoint_contact!
    return true unless @sign_up_ticket&.pending_contact_type == "telephone"

    telephone = sign_up_pending_telephone
    registration = session[sign_up_telephone_registration_session_key] || {}
    session_public_id = registration[:public_id] || registration["public_id"]
    otp_verified = registration[:otp_verified] || registration["otp_verified"]

    return true if telephone &&
      session_public_id.to_s == telephone.public_id.to_s &&
      otp_verified &&
      sign_up_pending_telephone_status?(telephone)

    render_invalid_sign_up_checkpoint_contact
    false
  end

  def sign_up_pending_telephone
    sign_up_pending_telephone_model&.find_by(id: @sign_up_ticket.pending_contact_id)
  end

  def sign_up_pending_telephone_status?(telephone)
    case telephone
    when ClientTelephone
      telephone.user_telephone_status_id == ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP
    when VisitorTelephone
      telephone.visitor_telephone_status_id == VisitorTelephoneStatus::UNVERIFIED_WITH_SIGN_UP
    else
      false
    end
  end

  def sign_up_telephone_registration_session_key
    case sign_up_surface
    when :app
      :user_telephone_registration
    when :com
      :visitor_telephone_registration
    end
  end

  def render_invalid_sign_up_checkpoint_contact
    if request.format.json?
      key = telephone_passkey_required_i18n_key
      render json: {
        error: I18n.t(key),
      }, status: :unprocessable_content
    else
      redirect_to(sign_up_telephone_edit_path)
    end
  end

  def telephone_passkey_required_i18n_key
    case sign_up_surface
    when :com
      "sign.com.registration.telephone.update.passkey_required"
    else
      "sign.app.registration.telephone.update.passkey_required"
    end
  end

  def sign_up_telephone_edit_path
    case sign_up_surface
    when :app
      auth_app_sign_up_check_telephone_otp_path(ri: params[:ri])
    when :com
      auth_com_sign_up_check_telephone_otp_path(ri: params[:ri])
    else
      sign_up_default_sign_in_path
    end
  end

  def sign_up_finalization_context
    SignUpFinalizationContext.build(
      surface: sign_up_surface,
      actor_authentication: sign_up_actor_authentication,
      ticket: @sign_up_ticket,
      pending_actor: sign_up_pending_actor,
    )
  rescue ArgumentError
    nil
  end

  def finalize_sign_up_side_effect!
    actor = sign_up_pending_actor
    return :failed unless actor

    # The ticket type decides which surface finalizer to run.
    # App and com share the same finalize boundary, but they differ in
    # which contact types are accepted and what credential work is needed.
    case @sign_up_ticket
    when ClientSignUpFlow
      finalize_app_sign_up_actor!(actor)
    when VisitorSignUpFlow
      finalize_com_sign_up_actor!(actor)
    else
      :failed
    end
  end

  def finalize_app_sign_up_actor!(actor)
    case @sign_up_ticket.pending_contact_type
    when "telephone"
      # Telephone sign-up keeps the contact proof and active passcode/passkey
      # work in the dedicated finalizer because it has extra credential rules.
      telephone = ClientTelephone.find_by(id: @sign_up_ticket.pending_contact_id)
      return :failed unless telephone

      SignAppUpTelephoneRegistrationFinalizer.call(telephone: telephone)
    when "email", "social_identity"
      # Email and social sign-up only need the actor promoted into the
      # verified-with-sign-up state before the durable graph is provisioned.
      Client.transaction do
        actor.update!(status_id: ClientStatus::VERIFIED_WITH_SIGN_UP) if
          actor.status_id == ClientStatus::UNVERIFIED_WITH_SIGN_UP
      end
    else
      return :failed
    end

    @sign_up_recovery_passcode_reveal_url =
      issue_sign_up_recovery_passcodes!(
        surface: :app,
        actor: actor,
      )

    :accepted
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved,
         SignAppUpTelephoneRegistrationFinalizer::PasskeyMissingError
    :failed
  end

  def finalize_com_sign_up_actor!(actor)
    case @sign_up_ticket.pending_contact_type
    when "telephone"
      # Com sign-up has its own telephone finalizer because the checkpoint
      # requirements are different from app, but the graph handoff is shared.
      telephone = VisitorTelephone.find_by(id: @sign_up_ticket.pending_contact_id)
      return :failed unless telephone

      SignComUpTelephoneRegistrationFinalizer.call(telephone: telephone)
    when "email"
      # Email sign-up has no additional com-side credential finalizer here.
    else
      return :failed
    end

    @sign_up_recovery_passcode_reveal_url =
      issue_sign_up_recovery_passcodes!(
        surface: :com,
        actor: actor,
      )

    :accepted
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved
    :failed
  end

  def handoff_to_sign_in_flow!(actor)
    # bootstrap_actor: true marks this as a fresh registration handoff.
    # The sign-in boundary creates or advances a pending cycle; active
    # session issuance remains delayed until checkpoint and selector pass.
    result = establish_signed_in_session!(
      actor,
      pt: sign_up_handoff_pt,
      ri: params[:ri],
      auth_method: sign_up_auth_method,
      audit_context: { flow: "sign_up", sign_up_flow_id: @sign_up_ticket.public_id },
      bootstrap_actor: true,
      # sign_up_auth_method collapses google/apple to "social" for the MFA-gating
      # value; the sign-up ticket's entry_method still carries the precise
      # provider (adr/unified-enforcement.md, Session attribution).
      established_authentication_method: established_authentication_method_for(@sign_up_ticket.entry_method),
    )
    reset_current_db_sign_in_flow_for_sequence!
    sign_in_result_from_session_result(result, actor: actor)
  end

  def sign_up_auth_method
    # The sign-in handoff only needs a coarse auth-method label; the
    # specific entry method stays recorded on the sign-up ticket.
    case @sign_up_ticket.entry_method
    when "google", "apple"
      "social"
    when "telephone"
      "telephone"
    else
      @sign_up_ticket.entry_method.presence || "sign_up"
    end
  end

  def redirect_after_sign_up_handoff!(sign_in_result, json: false)
    if json
      return render json: {
        status: "ok",
        redirect_url: sign_up_handoff_redirect_url(sign_in_result),
      }, status: :created
    end

    if sign_in_result.success?
      redirect_to_sign_in_sequence!(pt: sign_up_handoff_pt)
    elsif sign_in_result.mfa_required? || sign_in_result.session_limit_pending?
      redirect_to(sign_in_result.redirect_to)
    else
      render plain: sign_in_result.message.presence || sign_in_result.status.to_s,
             status: sign_in_result.response_status
    end
  end

  def sign_up_handoff_redirect_url(sign_in_result)
    if sign_in_result.success?
      sign_in_sequence_redirect_path(pt: sign_up_handoff_pt)
    elsif sign_in_result.mfa_required? || sign_in_result.session_limit_pending?
      sign_in_result.redirect_to
    else
      sign_up_default_sign_in_path
    end
  end

  def render_sign_up_finalization_forbidden(json: false)
    if json
      render json: { error: I18n.t("errors.messages.not_authorized") }, status: :forbidden
    else
      render plain: I18n.t("errors.messages.not_authorized"), status: :forbidden
    end
  end

  def render_sign_up_failure_result(result, json: false)
    if json
      render json: { error: result.errors.to_sentence.presence || result.status.to_s },
             status: :unprocessable_content
    else
      render_sign_up_result(result)
    end
  end

  def sign_up_ticket_record_class
    case @sign_up_ticket
    when ClientSignUpFlow
      AppTicketRecord
    when VisitorSignUpFlow
      ComTicketRecord
    else
      @sign_up_ticket.class
    end
  end

  def sign_up_default_sign_in_path
    case sign_up_surface
    when :app
      auth_app_sign_in_path(ri: params[:ri])
    when :com
      auth_com_sign_in_path(ri: params[:ri])
    else
      "/"
    end
  end

  def sign_up_restart_path
    case sign_up_surface
    when :app
      auth_app_sign_up_path(ri: params[:ri])
    when :com
      auth_com_sign_up_path(ri: params[:ri])
    else
      "/"
    end
  end

  def sign_up_pending_actor_model
    case @sign_up_ticket
    when ClientSignUpFlow
      Client
    when VisitorSignUpFlow
      Visitor
    end
  end

  def sign_up_pending_telephone_model
    case @sign_up_ticket
    when ClientSignUpFlow
      ClientTelephone
    when VisitorSignUpFlow
      VisitorTelephone
    end
  end

  def sign_up_handoff_pt
    return @sign_up_handoff_pt if defined?(@sign_up_handoff_pt)
    return @sign_up_recovery_passcode_reveal_url if @sign_up_recovery_passcode_reveal_url.present?

    ticket_return_to = @sign_up_ticket&.return_to.presence
    current_return_to =
      if respond_to?(:current_db_sign_in_flow_for_sequence, true)
        current_db_sign_in_flow_for_sequence&.return_to.presence
      end

    @sign_up_handoff_pt = path_from_signed_pt(signed_pt_param) || ticket_return_to || current_return_to
  end

  def issue_sign_up_recovery_passcodes!(surface:, actor:)
    config = sign_up_recovery_passcode_config(surface)
    top_up = RecoveryPasscodeTopUp.call(
      actor: actor,
      credential_class: config.fetch(:credential_class),
      target_count: RecoveryPasscodeTopUp::TARGET_ACTIVE_RECOVERY_PASSCODES,
    )
    return if top_up.raw_values.empty?

    reveal = IdentityOneTimeReveal.issue!(
      actor: actor,
      session_nonce: actor.public_id,
      value: top_up.raw_values,
      purpose: config.fetch(:reveal_purpose),
      metadata: { surface: surface.to_s, issued_count: top_up.issued_count },
    )

    config.fetch(:reveal_url).call(reveal.token)
  end

  def sign_up_recovery_passcode_config(surface)
    case surface.to_sym
    when :app
      {
        credential_class: ClientSecretCredential,
        reveal_purpose: "client.recovery_secret_credential",
        reveal_url: ->(token) {
          base_app_identity_secrets_url(
            ri: params[:ri], token: token,
            host: base_authority_host,
          )
        },
      }
    when :com
      {
        credential_class: VisitorSecretCredential,
        reveal_purpose: "visitor.recovery_secret_credential",
        reveal_url: ->(token) {
          base_com_identity_secrets_url(
            ri: params[:ri], token: token,
            host: ENV.fetch("PRIVATE_BASE_CORPORATE_URL"),
          )
        },
      }
    else
      raise ArgumentError, "unsupported sign up surface for recovery passcodes: #{surface.inspect}"
    end
  end
end
