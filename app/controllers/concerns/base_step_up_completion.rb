# frozen_string_literal: true

# Concrete Base controllers supply transaction loading and protect the exact Auth origin.
# The Base browser's stored transaction reference is required independently of the bearer result.
module BaseStepUpCompletion
  include StepUpCeremonyLogging
  include BaseStepUpTransactionMarker

  public

  def show
    apply_base_browser_continuation_headers!
    result_reference_param
    transaction_reference_param
    render "base/shared/result_continuation", layout: false,
                                              locals: { action_url: request.path,
                                                        result_ref: params[:result_ref],
                                                        transaction_ref: params[:transaction_ref],
                                                        ri: params[:ri], }
  rescue ActionController::BadRequest, ArgumentError
    render plain: I18n.t("errors.messages.invalid_request"), status: :bad_request
  end

  private

  def complete_step_up_ceremony!(surface:, actor:, token:)
    transaction = nil
    reference = transaction_reference_param
    result_reference = result_reference_param
    unless reference.is_a?(String) && reference.present? &&
        base_step_up_transaction_marker(
          reference:, surface:, actor:, token:,
        )
      raise BaseAuthAdmissionCoordinator::Denied.new("Base browser binding missing", code: "return_binding_mismatch")
    end

    transaction = completion_step_up_transaction(reference)
    unless base_step_up_transaction_marker(
      reference:, surface:, actor:, token:,
      allow_root_replacement: transaction.purpose == "reauthentication" && transaction.consumed?,
    )
      raise BaseAuthAdmissionCoordinator::Denied.new("Base browser binding missing", code: "return_binding_mismatch")
    end
    # The destination is checked before the result is consumed: an invalid target must not leave
    # the transaction terminal.
    unless transaction.surface == surface && completion_return_target_valid?(transaction)
      raise BaseAuthAdmissionCoordinator::Denied.new("step-up destination invalid", code: "return_binding_mismatch")
    end

    return unless ensure_base_self_rp_refreshable!(transaction: transaction, actor: actor)

    state_before = transaction.status
    finalized = finalize_completion_transaction!(
      actor: actor, token: token, transaction: transaction, result_reference: result_reference,
    )
    # A consumed transaction can be a lost-response retry. The reissuer is idempotent: it
    # redelivers the retained receipt when the RP claims still need the event, and skips the
    # exchange when the claims already reflect it.
    reissue_base_self_rp_credentials!(actor:, transaction:)
    log_step_up_ceremony(
      "completed", transaction: finalized, outcome: "completed", method: finalized.method,
                   state_before: state_before, state_after: finalized.status,
    )
    log_step_up_return_target(
      finalized.return_to, reason: "transaction_return_to", protected_flow: true, transaction: finalized,
    )
    redirect_to(completion_redirect_target(finalized), status: :see_other, allow_other_host: false)
  rescue ActionController::BadRequest, BaseAuthAdmissionCoordinator::Denied, ActiveRecord::RecordNotFound,
         IdentityStepUpCeremonyContract::Error,
         KeyError, ArgumentError => e
    log_step_up_refusal(
      e, transaction: transaction, session_public_id: token.public_id, stage: "base_completion",
    )
    render plain: I18n.t("errors.messages.invalid_request"), status: :bad_request
  rescue BaseSelfRpCredentialReissuer::DependencyError, Umaxica::Valkey::Unavailable,
         Umaxica::Valkey::OperationError
    render plain: I18n.t("errors.rate_limit.backend_unavailable"), status: :service_unavailable
  rescue BaseSelfRpCredentialReissuer::CredentialUnavailable
    render_browser_rp_unauthenticated! unless performed?
  end

  def result_reference_param
    value = params[:result_ref]
    raise ActionController::BadRequest unless
      value.is_a?(String) && value.match?(BaseAuthAdmissionCoordinator::ADMISSION_REFERENCE_PATTERN)

    value
  end

  def transaction_reference_param
    value = params[:transaction_ref]
    raise ActionController::BadRequest unless value.is_a?(String) && value.present?

    value
  end

  # The same rule the issuer applied when it stored the target: a path of the transaction's scope.
  def completion_return_target_valid?(transaction)
    catalog =
      case transaction.surface
      when "app" then StepUpScopeCatalog::APP
      when "com" then StepUpScopeCatalog::COM
      when "org" then StepUpScopeCatalog::ORG
      else raise ArgumentError, "unsupported step-up surface: #{transaction.surface.inspect}"
      end
    pattern = catalog[transaction.required_scope]
    return_to = transaction.return_to
    pattern.present? && return_to.is_a?(String) && !return_to.match?(/[\x00-\x1F\x7F]/) && pattern.match?(return_to)
  end

  def finalize_completion_transaction!(actor:, token:, transaction:, result_reference:)
    requirement = step_up_requirement(
      scope: transaction.required_scope,
      purpose: transaction.purpose,
      resource_ref: transaction.resource_ref,
      tenant_ref: transaction.tenant_ref,
    )
    IdentityStepUpCeremonyFreshnessCommitter.call!(
      actor: actor, token: token, transaction: transaction, requirement: requirement,
      result_reference: result_reference,
    )
  end

  def ensure_base_self_rp_refreshable!(transaction:, actor:)
    return true unless %w(step_up reauthentication bootstrap credential_registration credential_change).include?(
      transaction.purpose,
    )

    rp_session = browser_rp_access_state.rp_session
    raw_refresh_token = BrowserCredentialCookie.read(
      cookies, OidcRpBrowserCredentialContract::REFRESH_COOKIE,
    )
    return true if BaseSelfRpCredentialReissuer.refreshable?(
      resource: actor, rp_session:, raw_refresh_token:, client_id: browser_rp_client_id,
    )

    render_browser_rp_unauthenticated!
    false
  end

  def reissue_base_self_rp_credentials!(actor:, transaction:)
    return unless %w(step_up reauthentication).include?(transaction.purpose)

    rp_session = browser_rp_access_state.rp_session
    return if base_self_rp_claims_reflect_transaction?(rp_session:, transaction:)

    raw_refresh_token = BrowserCredentialCookie.read(
      cookies, OidcRpBrowserCredentialContract::REFRESH_COOKIE,
    )
    result = BaseSelfRpCredentialReissuer.call!(
      resource: actor, rp_session:, raw_refresh_token:, client_id: browser_rp_client_id,
      authentication_event_at: transaction.verified_at,
      acr: transaction.aal,
      amr: base_self_rp_amr_for(transaction.method),
    )
    install_browser_rp_token_response!(result)
  end

  def base_self_rp_claims_reflect_transaction?(rp_session:, transaction:)
    return false unless rp_session&.oidc_auth_time && rp_session.oidc_auth_time >= transaction.verified_at
    return false unless rp_session.oidc_acr.to_s == transaction.aal.to_s

    JSON.parse(rp_session.oidc_amr.to_s) == base_self_rp_amr_for(transaction.method)
  rescue JSON::ParserError
    false
  end

  def base_self_rp_amr_for(method)
    case method.to_s
    when "totp" then ["otp"]
    when "email_otp" then ["email_otp"]
    when "passkey" then ["passkey"]
    else [method.to_s]
    end
  end

  def completion_redirect_target(transaction)
    transaction.return_to
  end
end
