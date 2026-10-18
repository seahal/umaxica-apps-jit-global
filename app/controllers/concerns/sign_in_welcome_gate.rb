# typed: false
# frozen_string_literal: true

# Reads and spends the one-shot Welcome gate that a completed sign-in leaves in the host-local Rails
# session. The gate is a presentation token only: it grants no authentication and no authority, so
# both the root sign-in sequence that issues it and the Base self-RP Welcome page that spends it can
# share it without the RP side reading the root credential.
#
# The including class supplies `sign_in_sequence_surface`.
module SignInWelcomeGate
  extend ActiveSupport::Concern

  private

  def welcome_gate_key
    {
      "app" => :app_sign_in_welcome,
      "com" => :com_sign_in_welcome,
      "org" => :org_sign_in_welcome,
    }[sign_in_sequence_surface.to_s] || :sign_in_welcome
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

  # The page the browser was heading to before sign-in, or nil. Only a path-target token that this
  # browser session's own sign-in issued for this surface is honoured; an absent session nonce means
  # the origin is unknown, so the caller falls back to its default. Welcome and the sign entry are
  # refused as destinations so "Next" can never loop.
  #
  # The including class also supplies RedirectsSignedTargetSupport and CommonRedirect.
  def welcome_return_path(token)
    session_nonce = session[:authentication_pt_nonce].to_s
    return if session_nonce.blank?

    payload = verified_signed_target_payload(
      token,
      purpose: AuthenticationRedirects::PATH_TARGET_TOKEN_PURPOSE,
      salt: AuthenticationRedirects::PATH_TARGET_TOKEN_SALT,
      expected_flow: AuthenticationRedirects::PATH_TARGET_TOKEN_FLOW,
      expected_surface: sign_in_sequence_surface,
      session_nonce: session_nonce,
    )
    return if payload.blank?

    path = safe_internal_path(signed_target_internal_path(payload["pt"]))
    return if path.blank?

    destination = URI.parse(path).path
    return if destination == "/welcome" || destination == "/sign" || destination.start_with?("/sign/")

    path
  rescue URI::InvalidURIError
    nil
  end
end
