# typed: false
# frozen_string_literal: true

module SignVerificationStepUpSessionStore
  extend ActiveSupport::Concern

  private

  def start_step_up_session!(scope:, pt_param:)
    token = current_step_up_token
    raise ActionController::BadRequest, "missing session token" unless token

    safe_path = resolve_step_up_pt(pt_param)
    raise ActionController::BadRequest, "invalid pt" if safe_path.blank?

    scope_str = scope.to_s
    raise ActionController::BadRequest, "invalid scope" unless self.class::ALLOWED_SCOPES.key?(scope_str)

    pattern = self.class::ALLOWED_SCOPES[scope_str]
    raise ActionController::BadRequest, "scope mismatch" unless safe_path.match?(pattern)

    attrs = {
      step_up_session_token_foreign_key => token.id,
      :scope => scope_str,
      :return_to => safe_path,
      :method => nil,
      :status => "PENDING",
      :attempt_count => 0,
      :verified_at => nil,
      :discard_at => self.class::STEP_UP_TTL.from_now,
      :purge_eligible_at => self.class::STEP_UP_TTL.from_now,
    }
    ActiveRecord::Base.connected_to(role: :writing) do
      step_up_session =
        step_up_session_model.find_or_initialize_by(step_up_session_token_foreign_key => token.id)
      step_up_session.assign_attributes(attrs)
      step_up_session.save!
    end
    issue_step_up_ceremony_grant!(token: token, scope: scope_str, return_to: safe_path)
  end

  def current_step_up_session
    token = current_step_up_token
    return nil if token.blank?

    ActiveRecord::Base.connected_to(role: :writing) do
      step_up_session_model.find_by(step_up_session_token_foreign_key => token.id)
    end
  end

  def destroy_current_step_up_session!
    ActiveRecord::Base.connected_to(role: :writing) do
      current_step_up_session&.destroy!
    end
  end

  def current_step_up_token
    return actor_token if respond_to?(:actor_token, true) && actor_token.present?

    current_session_token if respond_to?(:current_session_token, true)
  end

  def resolve_step_up_pt(encoded)
    return signed_pt_to_safe_path(encoded) if respond_to?(:signed_pt_to_safe_path, true)
    return safe_internal_path(encoded.to_s) if respond_to?(:safe_internal_path, true)

    encoded.to_s.presence
  end

  def step_up_session_token_foreign_key
    case step_up_session_model.name
    when "ClientStepUpSession"
      :user_token_id
    when "VisitorStepUpSession"
      :visitor_token_id
    when "OperatorStepUpSession"
      :staff_token_id
    else
      raise(NotImplementedError, "#{self.class} must define #step_up_session_token_foreign_key")
    end
  end

  # acme/www owns step-up intent. sign/id never self-issues a ceremony grant
  # (see adr/sign-residual-idp-surface-retirement.md). sign only manages local ceremony state here;
  # when an acme-issued grant is presented it is validated and the acme completion state is recorded.
  # The acme-issued transaction is required later, at result issuance
  # (SignVerificationStepUpLifecycle#current_step_up_ceremony_transaction!), which is the security
  # boundary: sign cannot emit a ceremony result without an acme-issued ceremony.
  def issue_step_up_ceremony_grant!(token:, scope:, return_to:)
    return unless respond_to?(:step_up_ceremony_surface, true)

    grant_token = params[:step_up_ceremony_grant].presence
    return unless grant_token

    validate_acme_step_up_ceremony_grant!(
      grant_token, token: token, scope: scope, return_to: return_to,
    )
  end

  def validate_acme_step_up_ceremony_grant!(grant_token, token:, scope:, return_to:)
    grant = IdentityStepUpCeremonyGrant.decode(
      grant_token,
      issuer_id: IdentityStepUpCeremonyContract.acme_issuer_id(step_up_ceremony_surface),
    )

    raise ActionController::BadRequest, "grant actor mismatch" unless grant["actor_ref"] == step_up_ceremony_actor_ref
    raise ActionController::BadRequest, "grant session mismatch" unless grant["session_ref"] == token.public_id
    raise ActionController::BadRequest, "grant scope mismatch" unless grant["required_scope"] == scope.to_s
    raise ActionController::BadRequest, "grant return target mismatch" unless grant["return_to"] == return_to

    store_acme_step_up_completion_state!(
      transaction_id: grant["transaction_id"],
      surface: grant["surface"],
    )
    grant
  rescue IdentityStepUpCeremonyContract::Error => e
    raise ActionController::BadRequest, "invalid step-up grant: #{e.message}"
  end

  def acme_step_up_completion_session_key
    :acme_step_up_completion
  end

  def clear_acme_step_up_completion_state!
    return unless request_available_for_step_up_completion_state?

    session.delete(acme_step_up_completion_session_key)
    session.delete(acme_step_up_completion_session_key.to_s)
  end

  def store_acme_step_up_completion_state!(transaction_id:, surface:)
    return unless request_available_for_step_up_completion_state?

    session[acme_step_up_completion_session_key.to_s] = {
      "transaction_id" => transaction_id,
      "surface" => surface,
      "csrf_token" => params[:step_up_completion_csrf].presence,
    }
  end

  def acme_step_up_completion_state
    session[acme_step_up_completion_session_key.to_s].to_h.presence ||
      session[acme_step_up_completion_session_key].to_h
  end

  def request_available_for_step_up_completion_state?
    (defined?(@request) && @request.present?) ||
      (defined?(@_request) && @_request.present?)
  end
end
