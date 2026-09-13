# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_chronicle_events
# Database name: chronicle
#
#  id :bigint           not null, primary key
#
class ClientChronicleEvent < ChronicleRecord
  include ReferenceRecord

  # Fixed IDs - do not modify these values
  ACCOUNT_RECOVERED = 1
  ACCOUNT_WITHDRAWN = 2
  AUTHORIZATION_FAILED = 3
  LOGGED_IN = 4
  LOGGED_OUT = 5
  LOGIN_FAILED = 6
  LOGIN_SUCCESS = 7
  LOGOUT = 8
  NOTHING = 9
  NON_EXISTENT_EVENT = 10
  PASSKEY_REGISTERED = 11
  PASSKEY_REMOVED = 12
  RECOVERY_CODES_GENERATED = 13
  RECOVERY_CODE_USED = 14
  SIGNED_UP_WITH_APPLE = 15
  SIGNED_UP_WITH_EMAIL = 16
  SIGNED_UP_WITH_GOOGLE = 17
  SIGNED_UP_WITH_TELEPHONE = 18
  TOKEN_REFRESHED = 19
  TOTP_DISABLED = 20
  TOTP_ENABLED = 21
  USER_SECRET_CREATED = 22
  USER_SECRET_REMOVED = 23
  USER_SECRET_UPDATED = 24
  EMAIL_REMOVED = 25
  TELEPHONE_REMOVED = 26
  SOCIAL_UNLINKED = 27
  STEP_UP_VERIFIED = 28
  SESSION_REVOKED = 29
  SOCIAL_LINKED = 30
  EMAIL_REGISTERED = 31
  TELEPHONE_REGISTERED = 32
  CREDENTIAL_SECURITY_TRANSITION = 33
  STEP_UP_FAILED = 34
  REFRESH_TOKEN_REUSE_DETECTED = 35

  # Association with client_chronicles
  has_many :client_chronicles,
           foreign_key: :event_id,
           dependent: :restrict_with_error,
           inverse_of: :user_chronicle_event

  DEFAULTS = [
    ACCOUNT_RECOVERED,
    ACCOUNT_WITHDRAWN,
    AUTHORIZATION_FAILED,
    LOGGED_IN,
    LOGGED_OUT,
    LOGIN_FAILED,
    LOGIN_SUCCESS,
    LOGOUT,
    NOTHING,
    NON_EXISTENT_EVENT,
    PASSKEY_REGISTERED,
    PASSKEY_REMOVED,
    RECOVERY_CODES_GENERATED,
    RECOVERY_CODE_USED,
    SIGNED_UP_WITH_APPLE,
    SIGNED_UP_WITH_EMAIL,
    SIGNED_UP_WITH_GOOGLE,
    SIGNED_UP_WITH_TELEPHONE,
    TOKEN_REFRESHED,
    TOTP_DISABLED,
    TOTP_ENABLED,
    USER_SECRET_CREATED,
    USER_SECRET_REMOVED,
    USER_SECRET_UPDATED,
    EMAIL_REMOVED,
    TELEPHONE_REMOVED,
    SOCIAL_UNLINKED,
    STEP_UP_VERIFIED,
    SESSION_REVOKED,
    SOCIAL_LINKED,
    EMAIL_REGISTERED,
    TELEPHONE_REGISTERED,
    CREDENTIAL_SECURITY_TRANSITION,
    STEP_UP_FAILED,
    REFRESH_TOKEN_REUSE_DETECTED,
  ].freeze

  public_constant :ACCOUNT_RECOVERED
  public_constant :ACCOUNT_WITHDRAWN
  public_constant :AUTHORIZATION_FAILED
  public_constant :LOGGED_IN
  public_constant :LOGGED_OUT
  public_constant :LOGIN_FAILED
  public_constant :LOGIN_SUCCESS
  public_constant :LOGOUT
  public_constant :NOTHING
  public_constant :NON_EXISTENT_EVENT
  public_constant :PASSKEY_REGISTERED
  public_constant :PASSKEY_REMOVED
  public_constant :RECOVERY_CODES_GENERATED
  public_constant :RECOVERY_CODE_USED
  public_constant :SIGNED_UP_WITH_APPLE
  public_constant :SIGNED_UP_WITH_EMAIL
  public_constant :SIGNED_UP_WITH_GOOGLE
  public_constant :SIGNED_UP_WITH_TELEPHONE
  public_constant :TOKEN_REFRESHED
  public_constant :TOTP_DISABLED
  public_constant :TOTP_ENABLED
  public_constant :USER_SECRET_CREATED
  public_constant :USER_SECRET_REMOVED
  public_constant :USER_SECRET_UPDATED
  public_constant :EMAIL_REMOVED
  public_constant :TELEPHONE_REMOVED
  public_constant :SOCIAL_UNLINKED
  public_constant :STEP_UP_VERIFIED
  public_constant :SESSION_REVOKED
  public_constant :SOCIAL_LINKED
  public_constant :EMAIL_REGISTERED
  public_constant :TELEPHONE_REGISTERED
  public_constant :CREDENTIAL_SECURITY_TRANSITION
  public_constant :STEP_UP_FAILED
  public_constant :REFRESH_TOKEN_REUSE_DETECTED
  public_constant :DEFAULTS

  def self.ensure_defaults!
    insert_missing_fixed_ids!(DEFAULTS)
  end
end
