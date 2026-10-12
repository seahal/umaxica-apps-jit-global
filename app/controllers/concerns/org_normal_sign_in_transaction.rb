# typed: false
# frozen_string_literal: true

# Pending-ceremony state for the org Normal sign-in sequence.
#
# Normal org sign-in is two-stage: Entra ID identifies the Operator, and a
# Passkey (or, when the Passkey is lost, the existing Secret/SecretKey
# credential) authenticates them. Entra success alone establishes no session.
#
# This concern holds the state between those stages. It is session-backed, in
# the same place and with the same shape as the pending-MFA state that already
# gates the second factor in `AuthenticationBase` -- the ceremony spans two
# requests of one browser session, not the sign/base boundary, so it needs no
# durable ceremony-transaction row.
#
# The binding it carries is what stops Operator substitution: the second stage
# reads the Operator from here, never from a request parameter, so a browser
# cannot answer an Entra transaction for Operator A with a credential belonging
# to Operator B.
#
# Including this concern installs no callbacks and touches no session by itself;
# every method below is an explicit call.
module OrgNormalSignInTransaction
  extend ActiveSupport::Concern

  SESSION_KEY = :org_normal_sign_in_transaction
  PURPOSE = "org_normal_sign_in"
  TTL = 10.minutes
  BINDING_PHASE = "PRIMARY_PENDING"

  private

  # Records the Entra result as the first stage of a Normal sign-in. Returns
  # the transaction's public id purely so the caller can log it.
  def issue_org_normal_sign_in_transaction!(operator:, entra_identity_id:, pt: nil, ri: nil)
    now = Time.current
    public_id = SecureRandom.hex(16)

    session[SESSION_KEY] = {
      "public_id" => public_id,
      "purpose" => PURPOSE,
      "operator_id" => operator.id,
      "entra_identity_id" => entra_identity_id,
      "pt" => pt.presence,
      "ri" => ri.to_s.presence,
      "issued_at" => now.to_i,
      "expires_at" => (now + TTL).to_i,
      "status" => "active",
    }
    public_id
  end

  def org_normal_sign_in_transaction
    raw = session[SESSION_KEY]
    return nil unless raw.is_a?(Hash)

    data = raw.with_indifferent_access
    return nil unless data[:purpose] == PURPOSE
    return nil if data[:operator_id].blank?
    return nil if data[:status].to_s == "halted"
    return nil if Time.current.to_i >= data[:expires_at].to_i

    data
  end

  # The Operator the Entra stage selected. This is the only admissible source of
  # the actor for the second stage of Normal sign-in.
  def org_normal_sign_in_operator
    transaction = org_normal_sign_in_transaction
    return nil if transaction.blank?

    operator = ::Operator.find_by(id: transaction[:operator_id])
    operator if operator&.login_allowed?
  end

  # One-shot: the transaction is removed before the session-establishing call,
  # so a replayed second stage finds nothing to continue.
  def consume_org_normal_sign_in_transaction!
    transaction = org_normal_sign_in_transaction
    clear_org_normal_sign_in_transaction!
    transaction
  end

  def clear_org_normal_sign_in_transaction!
    session.delete(SESSION_KEY)
  end

  def org_normal_sign_in_binding_params
    transaction = org_normal_sign_in_transaction
    return {} unless transaction

    {
      AuthIoKeys::Params::FLOW_BINDING => OrgNormalSignInBindingCodec.encode(
        transaction: transaction,
        surface: "org",
        phase: BINDING_PHASE,
      ),
    }
  end

  def enforce_org_normal_sign_in_binding!
    transaction = org_normal_sign_in_transaction
    binding = OrgNormalSignInBindingCodec.decode(params[AuthIoKeys::Params::FLOW_BINDING])

    return refuse_org_normal_sign_in_binding!("missing_binding", transaction) unless transaction && binding
    return refuse_org_normal_sign_in_binding!("surface_mismatch", transaction) unless binding.surface == "org"
    return refuse_org_normal_sign_in_binding!("transaction_mismatch", transaction) unless
      binding.transaction_public_id == transaction[:public_id].to_s

    if binding.phase != BINDING_PHASE || binding.generation != transaction[:issued_at].to_i.to_s ||
        binding.expires_at != transaction[:expires_at].to_i
      return refuse_org_normal_sign_in_binding!("phase_mismatch", transaction)
    end

    true
  end

  private

  def refuse_org_normal_sign_in_binding!(reason_code, transaction)
    if request.get? || request.head?
      log_org_normal_sign_in_binding_refusal(reason_code, transaction)
      return render_org_normal_sign_in_binding_refusal!
    end

    if transaction && transaction[:public_id].to_s == decoded_org_normal_binding_public_id.to_s
      halt_org_normal_sign_in_transaction!(transaction: transaction, reason_code: "phase_violation")
    end
    log_org_normal_sign_in_binding_refusal(reason_code, transaction)
    render_org_normal_sign_in_binding_refusal!
  end

  def decoded_org_normal_binding_public_id
    OrgNormalSignInBindingCodec.decode(params[AuthIoKeys::Params::FLOW_BINDING])&.transaction_public_id
  end

  def halt_org_normal_sign_in_transaction!(transaction:, reason_code:)
    session[SESSION_KEY] = transaction.merge(
      "status" => "halted",
      "halted_at" => Time.current.to_i,
      "halt_reason" => reason_code,
    )
  end

  def log_org_normal_sign_in_binding_refusal(reason_code, transaction)
    Rails.logger.info(
      JitLogEvent.format(
        "auth.org.normal_sign_in.phase_binding.refused",
        reason_code: reason_code,
        transaction_public_id: transaction&.[](:public_id),
        request_id: request.request_id,
      ),
    )
  end

  def render_org_normal_sign_in_binding_refusal!
    response.headers["Cache-Control"] = "private, no-store"
    render plain: "戻るはだめです", status: :conflict
    false
  end
end
