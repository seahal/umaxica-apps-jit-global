# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: account_access_events
# Database name: chronicle
#
#  id                    :bigint           not null, primary key
#  account_type          :string           not null
#  event_type            :string           not null
#  metadata              :jsonb            not null
#  next_access_state     :string           not null
#  occurred_at           :datetime         not null
#  previous_access_state :string           not null
#  reason_code           :string           not null
#  reason_note           :text
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  account_id            :bigint           not null
#  operator_id           :bigint           not null
#  ticket_id             :string
#
# Indexes
#
#  idx_on_account_type_account_id_occurred_at_950619886b  (account_type,account_id,occurred_at)
#  index_account_access_events_on_event_type              (event_type)
#  index_account_access_events_on_operator_id             (operator_id)
#  index_account_access_events_on_reason_code             (reason_code)
#  index_account_access_events_on_ticket_id               (ticket_id)
#
class AccountAccessEvent < ChronicleRecord
  encrypts :reason_note

  EVENT_TYPE_ADMIN_LOCK = "admin_lock"
  EVENT_TYPE_ADMIN_LOCK_REAFFIRMED = "admin_lock_reaffirmed"
  EVENT_TYPE_ADMIN_UNLOCK = "admin_unlock"
  EVENT_TYPE_EMERGENCY_SESSION_REVOKE = "emergency_session_revoke"
  EVENT_TYPE_SESSION_PURGE = "session_purge"
  EVENT_TYPES = [
    EVENT_TYPE_ADMIN_LOCK,
    EVENT_TYPE_ADMIN_LOCK_REAFFIRMED,
    EVENT_TYPE_ADMIN_UNLOCK,
    EVENT_TYPE_EMERGENCY_SESSION_REVOKE,
    EVENT_TYPE_SESSION_PURGE,
  ].freeze

  ACCOUNT_TYPES = %w(Client Visitor Operator).freeze

  validates :account_type, presence: true, inclusion: { in: ACCOUNT_TYPES }
  validates :account_id, presence: true, numericality: { only_integer: true }
  validates :event_type, presence: true, inclusion: { in: EVENT_TYPES }
  validates :previous_access_state, presence: true, inclusion: { in: AdministrativeAccessLockable::ACCESS_STATES }
  validates :next_access_state, presence: true, inclusion: { in: AdministrativeAccessLockable::ACCESS_STATES }
  validates :operator_id, presence: true, numericality: { only_integer: true }
  validates :reason_code, presence: true, inclusion: { in: AdministrativeAccessLockable::ADMIN_LOCK_REASON_CODES }
  validates :occurred_at, presence: true
  validates :metadata, exclusion: { in: [nil] }
end
