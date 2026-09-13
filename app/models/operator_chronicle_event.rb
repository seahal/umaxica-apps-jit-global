# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_chronicle_events
# Database name: chronicle
#
#  id :bigint           not null, primary key
#

class OperatorChronicleEvent < ChronicleRecord
  include ReferenceRecord

  # Fixed IDs - do not modify these values
  LOGIN_SUCCESS = 1
  AUTHORIZATION_FAILED = 2
  LOGGED_IN = 3
  LOGGED_OUT = 4
  LOGIN_FAILED = 5
  TOKEN_REFRESHED = 6
  NOTHING = 7
  STAFF_SECRET_CREATED = 8
  STAFF_SECRET_REMOVED = 9
  STAFF_SECRET_UPDATED = 10
  STEP_UP_VERIFIED = 11
  SOCIAL_UNLINKED = 12
  LOGOUT = 13
  CREDENTIAL_SECURITY_TRANSITION = 14
  PASSKEY_REGISTERED = 15
  STEP_UP_FAILED = 16
  REFRESH_TOKEN_REUSE_DETECTED = 17

  # Association with staff_chronicles
  has_many :staff_chronicles, class_name: "OperatorChronicle", foreign_key: :event_id,
                              dependent: :destroy,
                              inverse_of: :staff_chronicle_event

  DEFAULTS = [
    LOGIN_SUCCESS, AUTHORIZATION_FAILED, LOGGED_IN, LOGGED_OUT, LOGIN_FAILED,
    TOKEN_REFRESHED, NOTHING, STAFF_SECRET_CREATED, STAFF_SECRET_REMOVED,
    STAFF_SECRET_UPDATED, STEP_UP_VERIFIED, SOCIAL_UNLINKED, LOGOUT,
    CREDENTIAL_SECURITY_TRANSITION, PASSKEY_REGISTERED, STEP_UP_FAILED, REFRESH_TOKEN_REUSE_DETECTED,
  ].freeze

  def self.ensure_defaults!
    insert_missing_fixed_ids!(DEFAULTS)
  end
end
