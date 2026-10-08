# frozen_string_literal: true

class EmailCredentialRegistrationBootstrapGuard
  class << self
    public

    def call(**arguments, &)
      new(**arguments).call(&)
    end
  end

  public

  def initialize(actor:, token:, bootstrap_transaction:, browser_nonce:, credential_ref: nil, receipt: false)
    @actor, @token, @parent, @browser_nonce = actor, token, bootstrap_transaction, browser_nonce
    @credential_ref, @receipt = credential_ref, receipt
    @surface, @session_model, @binding_model, @catalog =
      case [actor, token, bootstrap_transaction]
      in [Client, ClientToken, ClientStepUpCeremonyTransaction]
        ["app", ClientStepUpSession, ClientAuthAdmissionBinding, StepUpScopeCatalog::APP]
      in [Visitor, VisitorToken, VisitorStepUpCeremonyTransaction]
        ["com", VisitorStepUpSession, VisitorAuthAdmissionBinding, StepUpScopeCatalog::COM]
      else raise ArgumentError, "unsupported Email bootstrap authority realm"
      end
  end

  def call
    raise ArgumentError, "Email bootstrap authority requires a block" unless block_given?

    token_key = (surface == "app") ? :user_token_id : :visitor_token_id
    session = session_model.lock.find_by(token_key => token.id)
    return false unless session && session.step_up_ceremony_transaction_ref == parent.transaction_id

    parent.lock!
    bindings = binding_model.where(step_up_ceremony_transaction_id: parent.id).lock.to_a
    return false unless bindings.one?

    binding = bindings.first
    now = parent.class.database_now
    return false unless parent_current?(now) && return_target_matches?(session) &&
      browser_matches?(session, binding, now)

    yield(parent, session, binding)
  end

  private

  attr_reader :actor, :token, :parent, :browser_nonce, :credential_ref, :receipt,
              :surface, :session_model, :binding_model, :catalog

  def parent_current?(now)
    parent_status_matches? && parent.purpose == "bootstrap" && parent.allowed_methods_array == ["email_otp"] &&
      parent.surface == surface && parent.actor_ref == actor.public_id && parent.session_ref == token.public_id &&
      parent.token_binding == token.public_id && parent.require_session_binding &&
      parent.audience == "step_up:#{surface}" && parent.expires_at > now &&
      !parent.step_up_required && !parent.phishing_resistant_required && !parent.user_verification_required &&
      !parent.full_reauthentication_required
  end

  def parent_status_matches?
    parent.status == "pending" ||
      (receipt && parent.consumed? && parent.verified_credential_ref == credential_ref &&
       parent[:method] == "email_otp")
  end

  def return_target_matches?(session)
    scope = parent.required_scope
    target = parent.return_to
    target.is_a?(String) && catalog.key?(scope) && catalog.fetch(scope).match?(target) &&
      session.scope == scope && session.return_to == target
  end

  def browser_matches?(session, binding, now)
    session.status == "PENDING" && session.discard_at > now && binding.base_token_id == token.id &&
      binding.purpose == "bootstrap_handoff" && binding.retired_at.nil? &&
      binding.base_browser_digest == AuthAdmissionBinding.browser_digest(
        surface: surface, entry_ref: binding.entry_ref, nonce: browser_nonce,
      )
  end
end
