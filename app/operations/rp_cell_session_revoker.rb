# typed: false
# frozen_string_literal: true

# Applies a verified back-channel Logout Token to one RP cell's own store (R5-WU10, one.md 7.6).
#
# In one cell-writer transaction: record the event receipt (unique per sender/JTI), upsert and lock
# the same per-sid OpSessionBinding the callback and Refresh use, set its absorbing revoked_at
# tombstone and revoke every local session under it. The receiver answers 200 only after this
# commit. A duplicate delivery of an already committed event is also a success, and a logout for a
# sid this cell has never seen still leaves a tombstone so a late callback cannot enroll it.
class RpCellSessionRevoker
  RECEIPT_EVENT_TYPE = "backchannel_logout"

  def initialize(cell:, payload:)
    @cell = cell
    @payload = payload
  end

  class << self
    public

    # Returns :revoked or :duplicate; raises on persistence failure (never a false success).
    def call(...) = new(...).call
  end

  public

  def call
    record_class.connected_to(role: :writing) do
      record_class.transaction do
        receipt_keys = {
          issuer:, client_id: cell.client_id, realm: cell.realm, event_type: RECEIPT_EVENT_TYPE, jti_digest:,
        }
        next :duplicate if model(:EventReceipt).exists?(receipt_keys)

        anchor = lock_anchor!(now)
        # A concurrent delivery may have committed while this request waited for the sid anchor.
        next :duplicate if model(:EventReceipt).exists?(receipt_keys)

        anchor.update!(revoked_at: anchor.revoked_at || now)
        # rubocop:disable Rails/SkipsModelValidations -- set-based close under the anchor lock
        model(:Session).where(op_session_binding_id: anchor.id, revoked_at: nil).update_all(revoked_at: now)
        # rubocop:enable Rails/SkipsModelValidations
        model(:EventReceipt).create!(
          receipt_keys.merge(
            op_session_binding: anchor, expires_at: Time.zone.at(payload.fetch("exp")),
            committed_at: now,
          ),
        )
        :revoked
      end
    end
  end

  private

  attr_reader :cell, :payload

  def lock_anchor!(now)
    keys = { issuer:, realm: cell.realm, client_id: cell.client_id, sid: payload.fetch("sid") }
    # rubocop:disable Rails/SkipsModelValidations -- idempotent anchor insert shared with the callback
    model(:OpSessionBinding).insert_all(
      [keys.merge(created_at: now, updated_at: now)],
      unique_by: %i(issuer realm client_id sid),
    )
    # rubocop:enable Rails/SkipsModelValidations
    model(:OpSessionBinding).lock.find_by!(keys)
  end

  def issuer = payload.fetch("iss")

  # Only a digest of the sender's JTI is stored; it is the replay key, not a secret to keep.
  def jti_digest = Digest::SHA256.digest(payload.fetch("jti"))

  def now
    record_class.database_now
  end

  def record_class = "#{cell.record_prefix}Record".constantize

  def model(suffix) = "#{cell.record_prefix}#{suffix}".constantize
end
