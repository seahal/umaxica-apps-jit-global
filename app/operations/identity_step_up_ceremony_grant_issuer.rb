# typed: false
# frozen_string_literal: true

class IdentityStepUpCeremonyGrantIssuer
  Issuance = Data.define(:transaction, :grant)

  # @deprecated `required_aal` is accepted only so an explicit legacy demand can fail closed at
  # the transaction boundary; it is never translated into an explicit policy.
  def self.issue!(surface:, actor_ref:, session_ref:, required_scope:, required_aal: StepUpRequirement::NO_AAL,
                  step_up_required: true, user_verification_required: false,
                  full_reauthentication_required: false, audience:, token_binding:, require_session_binding: true,
                  tenant_ref: nil, allowed_methods:, phishing_resistant_required: false, resource_ref: nil,
                  return_to: nil, transaction_id: nil,
                  grant_jti: nil, expires_at: nil, now: Time.current)
    transaction =
      IdentityStepUpCeremonyReplayStore.for(surface).create_transaction!(
        surface: surface,
        actor_ref: actor_ref,
        session_ref: session_ref,
        required_scope: required_scope,
        required_aal: required_aal,
        step_up_required: step_up_required,
        user_verification_required: user_verification_required,
        full_reauthentication_required: full_reauthentication_required,
        audience: audience,
        token_binding: token_binding,
        require_session_binding: require_session_binding,
        tenant_ref: tenant_ref,
        allowed_methods: allowed_methods,
        phishing_resistant_required: phishing_resistant_required,
        resource_ref: resource_ref,
        return_to: return_to,
        transaction_id: transaction_id,
        grant_jti: grant_jti,
        expires_at: expires_at,
        now: now,
      )
    Issuance.new(transaction: transaction, grant: new(transaction: transaction, now: now).call)
  end

  def initialize(transaction:, issuer_id: nil, now: Time.current)
    @transaction = transaction
    @issuer_id = issuer_id || IdentityStepUpCeremonyContract.acme_issuer_id(transaction.surface)
    @now = now
  end

  def call
    IdentityStepUpCeremonyGrant.issue(transaction.grant_claims(now: now), issuer_id: issuer_id, now: now)
  end

  private

  attr_reader :transaction, :issuer_id, :now
end
