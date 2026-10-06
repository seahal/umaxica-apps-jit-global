# frozen_string_literal: true

# Base's encrypted Rails session keeps only an opaque locator. The transaction-specific marker map
# lives in the auth-state store so a later intent cannot erase a canceled transaction's retry proof.
module BaseStepUpTransactionMarker
  LOCATOR_PATTERN = /\A[A-Za-z0-9_-]{32,128}={0,2}\z/.freeze

  private

  def remember_base_step_up_transaction!(transaction:, actor:, token:)
    locator = base_step_up_marker_locator!
    Valkey::AuthState::BaseStepUpMarkerStore.new.issue!(
      locator:, transaction_ref: transaction.transaction_id, surface: transaction.surface,
      actor_ref: actor.public_id, session_ref: token.public_id, expires_at: transaction.expires_at,
    )
  end

  def base_step_up_transaction_marker(reference:, surface:, actor:, token:, allow_root_replacement: false)
    locator = base_step_up_marker_locator
    return nil unless locator

    payload = Valkey::AuthState::BaseStepUpMarkerStore.new.read(locator:, transaction_ref: reference)
    return nil unless payload
    return nil unless payload["surface"] == surface.to_s && payload["actor_ref"] == actor.public_id
    return payload if payload["session_ref"] == token.public_id
    return nil unless allow_root_replacement

    replaced_root_token_matches?(payload, actor:, token:)
  rescue KeyError, ActiveRecord::RecordNotFound
    nil
  end

  def replaced_root_token_matches?(payload, actor:, token:)
    session_ref = payload.fetch("session_ref")
    previous =
      case token
      when ClientToken then ClientToken.find_by(public_id: session_ref)
      when VisitorToken then VisitorToken.find_by(public_id: session_ref)
      when OperatorToken then OperatorToken.find_by(public_id: session_ref)
      end
    return false unless previous
    return false unless previous.device_session_id.present? && previous.device_session_id == token.device_session_id

    actor_match =
      case [previous, actor]
      in [ClientToken, Client] then previous.user_id == actor.id
      in [VisitorToken, Visitor] then previous.visitor_id == actor.id
      in [OperatorToken, Operator] then previous.staff_id == actor.id
      else false
      end
    actor_match ? payload : false
  end

  def base_step_up_marker_locator
    value = session[:base_step_up_marker_locator]
    return value if value.is_a?(String) && value.match?(LOCATOR_PATTERN)

    nil
  end

  def base_step_up_marker_locator!
    locator = base_step_up_marker_locator
    return locator if locator

    locator = SecureRandom.urlsafe_base64(32, false)
    session[:base_step_up_marker_locator] = locator
    locator
  end
end
