# frozen_string_literal: true

# Diagnostic application logs for one Step-Up ceremony, correlated by a keyed reference. Values are
# fixed vocabularies and keyed digests only: never a token, cookie, code, credential or URL.
# Including controllers supply `request` and `logged_in?`.
module StepUpCeremonyLogging
  RETURN_TARGET_CLASSES = %w(dashboard identity protected_resource home sign other_allowlisted).freeze

  private

  def log_step_up_ceremony(event, transaction: nil, ceremony_ref: nil, session_public_id: nil, **attributes)
    trace = ObservabilityContextResolver.call
    reference = ceremony_ref || (transaction && StepUpObservabilityDigest.ceremony_ref(transaction.transaction_id))
    session_public_id ||= transaction&.session_ref
    Rails.logger.info(
      JitLogEvent.format(
        "auth.step_up.#{event}",
        occurred_at: Time.current.utc.iso8601(3),
        request_id: request.request_id,
        trace_id: trace.trace_id,
        ceremony_ref: reference,
        browser_session_digest: session_public_id && StepUpObservabilityDigest.session_ref(session_public_id),
        purpose: transaction&.purpose,
        scope: transaction&.required_scope,
        **attributes,
      ),
    )
  end

  def log_step_up_refusal(error, transaction: nil, ceremony_ref: nil, session_public_id: nil, **attributes)
    log_step_up_ceremony(
      "refused", transaction: transaction, ceremony_ref: ceremony_ref, session_public_id: session_public_id,
                 outcome: "refused", error_code: step_up_refusal_code(error), error_class: error.class.name,
                 state_before: transaction&.status, **attributes,
    )
  end

  def step_up_refusal_code(error)
    case error
    when BaseAuthAdmissionCoordinator::Denied, IdentityStepUpCeremonyContract::Error then error.code
    when ActiveRecord::RecordNotFound then "invalid_admission"
    when ActionController::BadRequest, KeyError, ArgumentError then "malformed_request"
    else "unclassified"
    end
  end

  # The destination is logged as a class, never as a URL.
  # `protected_flow` is true when the destination is the transaction's own validated return target.
  def log_step_up_return_target(destination, reason:, protected_flow:, transaction: nil, ceremony_ref: nil)
    log_step_up_ceremony(
      "return_target_resolved", transaction: transaction, ceremony_ref: ceremony_ref,
                                authentication_state: logged_in? ? "authenticated" : "unauthenticated",
                                resolution_reason: reason,
                                return_target_class: step_up_return_target_class(destination, protected_flow),
    )
  end

  def step_up_return_target_class(destination, protected_flow)
    path = URI.parse(destination.to_s).path
    if path == "/" || path.blank?
      "home"
    elsif path == "/dashboard"
      "dashboard"
    elsif path == "/identity"
      "identity"
    elsif path == "/sign" || path.start_with?("/sign/")
      "sign"
    elsif protected_flow
      "protected_resource"
    else
      "other_allowlisted"
    end
  end
end
