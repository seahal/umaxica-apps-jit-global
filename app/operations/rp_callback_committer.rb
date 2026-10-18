# typed: false
# frozen_string_literal: true

# Commits a verified OIDC callback into one RP cell's own store (R5-WU07, one.md sections 6.2/7.4).
#
# The RP never reads the Global actor or the OP database: the identity is the verified
# (issuer, realm, client_id, subject) of the ID Token, and the OP session is the verified `sid`.
# Everything is written under the per-sid OpSessionBinding row lock, which is the permanent
# serialization anchor shared with Refresh (R5-WU08) and back-channel logout (R5-WU10):
#
# 1. Lock or create the anchor for (issuer, realm, client_id, sid). A revoked anchor is a logout
#    tombstone and is never reopened, so a late callback cannot resurrect a logged-out sid.
# 2. Resolve the immutable identity binding for the verified subject, creating the local principal
#    on first sight. There is no email or Global-ID linking.
# 3. Fill the anchor's identity binding once; a filled anchor must match.
# 4. Create the single live local session for that anchor.
class RpCallbackCommitter
  Result =
    Data.define(:outcome, :session, :principal) do
      def success? = outcome == :committed
    end

  # committed         - a new local session exists for this verified sid.
  # revoked           - the sid was already logged out (tombstone); start a fresh Code Flow.
  # binding_mismatch  - the anchor is bound to a different identity; refuse, never re-bind.
  # already_enrolled  - this sid already has a live local session; the callback is not reused.
  OUTCOMES = %i(committed revoked binding_mismatch already_enrolled).freeze

  def initialize(cell:, issuer:, subject:, sid:, absolute_expires_at:, contract_epoch:)
    @cell = cell
    @issuer = require_value(issuer, "issuer")
    @subject = require_value(subject, "subject")
    @sid = require_value(sid, "sid")
    @absolute_expires_at = absolute_expires_at
    @contract_epoch = ContractEpochValue.coerce(contract_epoch)
  end

  class << self
    public

    def call(...) = new(...).call
  end

  public

  def call
    record_class.connected_to(role: :writing) do
      record_class.transaction do
        anchor = lock_anchor!
        next result(:revoked) if anchor.revoked_at || absolute_expires_at <= now

        identity_binding = resolve_identity_binding!
        next result(:revoked) if identity_binding.principal.disabled_at

        if anchor.identity_binding_id.nil?
          anchor.update!(identity_binding_id: identity_binding.id)
        elsif anchor.identity_binding_id != identity_binding.id
          next result(:binding_mismatch)
        end

        next result(:already_enrolled) if live_session_for?(anchor)

        # The live-session index counts any unrevoked row; close an expired one before enrolling.
        # rubocop:disable Rails/SkipsModelValidations -- a set-based close under the anchor lock; no callbacks apply
        model(:Session).where(op_session_binding_id: anchor.id, revoked_at: nil).update_all(revoked_at: now)
        # rubocop:enable Rails/SkipsModelValidations

        session = model(:Session).create!(
          op_session_binding: anchor, absolute_expires_at:, contract_epoch:, installed_generation: 0,
        )
        Result.new(outcome: :committed, session:, principal: identity_binding.principal)
      end
    end
  end

  private

  attr_reader :cell, :issuer, :subject, :sid, :absolute_expires_at, :contract_epoch

  def lock_anchor!
    keys = { issuer:, realm: cell.realm, client_id: cell.client_id, sid: }
    anchor_class = model(:OpSessionBinding)
    # Insert-or-nothing then lock, so concurrent callback/logout for the same sid serialize on one row.
    # rubocop:disable Rails/SkipsModelValidations -- idempotent anchor insert; the row is validated by its constraints
    anchor_class.insert_all(
      [keys.merge(created_at: now, updated_at: now)],
      unique_by: %i(issuer realm client_id sid),
    )
    # rubocop:enable Rails/SkipsModelValidations
    anchor_class.lock.find_by!(keys)
  end

  def resolve_identity_binding!
    keys = { issuer:, realm: cell.realm, client_id: cell.client_id, subject: }
    binding_class = model(:IdentityBinding)
    existing = binding_class.includes(:principal).lock.find_by(keys)
    return existing if existing

    principal = model(:Principal).create!
    binding_class.create!(keys.merge(principal:))
  end

  def live_session_for?(anchor)
    model(:Session).where(op_session_binding_id: anchor.id, revoked_at: nil)
      .exists?(["absolute_expires_at > ?", now])
  end

  def record_class
    "#{cell.record_prefix}Record".constantize
  end

  # Fixed cell models, e.g. RpCoreAppSession; the prefix comes from the trusted cell binding.
  def model(suffix)
    "#{cell.record_prefix}#{suffix}".constantize
  end

  # Database clock of the cell store, so expiry comparisons use the same clock as the rows.
  def now
    record_class.database_now
  end

  def require_value(value, name)
    raise ArgumentError, "#{name} is required" unless value.is_a?(String) && value.present?

    value
  end

  def result(outcome)
    Result.new(outcome:, session: nil, principal: nil)
  end
end
