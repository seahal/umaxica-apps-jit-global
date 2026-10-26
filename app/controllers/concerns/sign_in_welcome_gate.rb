# typed: false
# frozen_string_literal: true

# Reads and spends the one-shot Welcome gate used by the remaining Auth-side sign-in sequence.
# Base self-RP Welcome pages do not include this concern and never read the OP-written gate from
# their host-local Rails session.
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
end
