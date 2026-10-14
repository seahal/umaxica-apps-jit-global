# typed: false
# frozen_string_literal: true

module AuthenticationDeviceBinding
  extend ActiveSupport::Concern

  private

  def find_token_record_by_device_session_identifier(session_identifier)
    return unless token_record_column?("device_session_id")

    device_session = find_device_session_by_public_id(session_identifier)
    return unless device_session

    token_class.currently_usable_at.where(device_session_id: device_session.id).order(created_at: :desc).first
  end

  def find_device_session_by_public_id(public_id)
    klass = device_session_class
    return unless klass && public_id.present?

    klass.active.find_by(public_id: public_id)
  end

  def device_session_class
    case resource_type
    when "client" then ClientDeviceSession
    when "operator" then OperatorDeviceSession
    when "visitor" then VisitorDeviceSession
    end
  end

  def ensure_device_session_for!(resource, token_record, dpop_jkt: nil)
    return unless [ClientToken, VisitorToken, OperatorToken].any? { |token_class| token_record.is_a?(token_class) }

    existing_device_session = token_record.device_session_record
    return existing_device_session if existing_device_session

    klass = device_session_class
    return unless klass

    attrs = {
      dpop_jkt: dpop_jkt.presence,
      refresh_token_family_id: token_record.refresh_token_family_id,
      last_seen_at: Time.current,
    }.compact
    attrs[device_session_actor_key] = resource.id
    device_session = klass.create!(attrs)
    token_record.update!(device_session_id: device_session.id)
    device_session
  end

  def update_device_session_refresh_state!(device_session, token_record)
    return if device_session.blank?

    device_session.update!(
      current_refresh_token_id: token_record.id,
      refresh_token_family_id: token_record.refresh_token_family_id,
      last_seen_at: Time.current,
    )
  end

  def device_session_actor_key
    case resource_type
    when "operator" then :staff_id
    when "visitor" then :visitor_id
    else :user_id
    end
  end
end
