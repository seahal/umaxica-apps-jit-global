# typed: false
# frozen_string_literal: true

module BaseSettingsWithdrawalFlow
  extend ActiveSupport::Concern

  private

  def render_withdrawal_entry(actor)
    build_forms
    @schedule_confirmed = withdrawal_flow_closing_or_later?(actor)
    @terminated = actor.terminated?

    return unless params.key?(:ack_schedule_purge)

    if @schedule_form.valid?
      @schedule_confirmed = true
    else
      render_withdrawal_new(status: :unprocessable_content)
    end
  end

  def render_withdrawal_status(actor)
    unless actor.withdrawal_in_progress? || actor.terminated?
      return safe_redirect_to(
        withdrawal_new_path,
        fallback: withdrawal_settings_path,
        status: :see_other,
      )
    end

    assign_status_view_state(actor)
  end

  def recover_withdrawal!(actor)
    unless actor.can_recover? && !privacy_request_blocks_recovery?(actor)
      return safe_redirect_to(
        withdrawal_edit_path,
        fallback: withdrawal_new_path,
        status: :see_other,
      )
    end

    ::WithdrawalLifecycle.recover!(actor: actor, request: request)
    consume_current_withdrawal_ceremony!

    safe_redirect_to(
      withdrawal_public_fallback_path,
      fallback: withdrawal_new_path,
      status: :see_other,
    )
  end

  def update_withdrawal!(actor)
    build_forms

    return start_withdrawal_request!(actor) if should_start_withdrawal_request?(actor)

    unless @deactivate_form.valid?
      return render_update_validation_error
    end

    ::WithdrawalLifecycle.suspend!(
      actor: actor,
      current_session_public_id: withdrawal_current_session_public_id,
      request: request,
    )
    # Suspension revokes the sessions server-side; this drops the browser's own RP credential so
    # the next request is not presented with a credential that can only be refused.
    clear_browser_rp_cookies!
    issue_withdrawal_ceremony!(subject: actor, purpose: "status")

    safe_redirect_to(
      withdrawal_edit_path,
      fallback: withdrawal_settings_path,
      status: :see_other,
    )
  rescue ActiveRecord::RecordInvalid
    handle_deactivation_failure(actor)
  end

  def terminate_withdrawal!(actor)
    ::WithdrawalLifecycle.terminate!(actor: actor, request: request) if actor.early_terminatable?
    consume_current_withdrawal_ceremony!

    safe_redirect_to(
      withdrawal_public_fallback_path,
      fallback: withdrawal_new_path,
      status: :see_other,
    )
  end

  def build_forms
    @schedule_form = Sign::App::Settings::Withdrawal::ScheduleForm.new(schedule_params)
    @deactivate_form = Sign::App::Settings::Withdrawal::DeactivateForm.new(deactivate_params)
  end

  def should_start_withdrawal_request?(actor)
    !withdrawal_flow_closing_or_later?(actor) && !params.key?(:ack_deactivate_today)
  end

  def start_withdrawal_request!(actor)
    unless @schedule_form.valid?
      @schedule_confirmed = false
      return render_withdrawal_new(status: :unprocessable_content)
    end

    ::WithdrawalLifecycle.start!(
      actor: actor,
      current_session_public_id: withdrawal_current_session_public_id,
      request: request,
    )

    safe_redirect_to(
      withdrawal_new_path(ack_schedule_purge: "1"),
      fallback: withdrawal_settings_path,
      status: :see_other,
    )
  end

  def withdrawal_flow_closing_or_later?(actor)
    cycle = active_withdrawal_flow_for(actor)
    return true if cycle&.withdrawal_closing?
    return true if cycle&.withdrawal_discarded?

    actor.closing? || actor.deactivated? || actor.terminated?
  end

  def active_withdrawal_flow_for(actor)
    case actor
    when Client
      actor.client_withdrawal_flows.active.recent_first.first
    when Visitor
      actor.visitor_withdrawal_flows.active.recent_first.first
    end
  end

  def withdrawal_current_session_public_id
    current_session_public_id.presence ||
      instance_variable_get(:@current_token_public_id).presence ||
      (current_session.public_id if respond_to?(:current_session, true))
  end

  def assign_status_view_state(actor)
    @recovery_available_at = actor.recovery_available_at
    @recovery_deadline = actor.recovery_deadline
    @early_termination_available_at = actor.early_termination_available_at
    @recoverable = actor.can_recover?
    @early_terminatable = actor.early_terminatable?
    @terminated = actor.terminated?
  end

  def privacy_request_blocks_recovery?(actor)
    case actor
    when Client then actor.client_privacy_requests.open_for_recovery_block.exists?
    when Visitor then actor.visitor_privacy_requests.open_for_recovery_block.exists?
    else
      false
    end
  end

  def schedule_params
    # `slice` first: this reads a fixed set of keys and ignores everything else the
    # request carries (`ri`, the Turnstile token). Permitting without narrowing would
    # report those as unpermitted, which they are not - they are simply not ours.
    params.slice(:ack_schedule_purge).permit(:ack_schedule_purge)
  end

  def deactivate_params
    params.slice(:ack_deactivate_today).permit(:ack_deactivate_today)
  end

  def render_update_validation_error
    @schedule_confirmed = true
    render_withdrawal_new(status: :unprocessable_content)
  end

  # The withdrawal entry screen, as its surface renders it. `render :new` resolves the including
  # controller's own template, so a surface that has moved the screen to Inertia overrides this and
  # every failure path above follows it.
  def render_withdrawal_new(status: :ok)
    render :new, status: status
  end
end
