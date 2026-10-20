# typed: false
# frozen_string_literal: true

class ComIdentityAuthenticationEvent < ComZenithRecord
  self.table_name = "identity_authentication_events"

  REALM = "com"

  validates :event_id, :actor_ref, :realm, :cutoff_epoch, :reason, :scope, :committed_at,
            presence: true
  validates :realm, inclusion: { in: [REALM] }
  validates :cutoff_epoch, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :realm, length: { maximum: 3 }
  validates :reason, :scope, length: { maximum: 64 }
end
