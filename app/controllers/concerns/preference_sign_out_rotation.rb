# typed: false
# frozen_string_literal: true

# Sign-out preference rotation (target semantics: sign-out must detach the
# browser from the signed-out principal's preference credential, not merely
# end the auth session). Before this concern existed, ordinary sign-out never
# touched the `preference_access`/`preference_refresh`/`preference_dbsc`
# cookies or the underlying AppPreference/ComPreference/OrgPreference row at
# all (see memos/2026-07-21-preference-lifecycle-sign-out-audit.md section 4): the
# same token/jti stayed live across the sign-out boundary and rode into the
# next sign-in's adoption merge unchanged.
#
# `rotate_preference_after_sign_out!` is the single entry point, included on
# every surface via PreferenceGlobal, so app/com/org share one implementation
# rather than three copies. It:
#   1. snapshots only the low-sensitivity display keys from the current
#      (about-to-be-abandoned) token-scoped preference row,
#   2. creates a brand-new guest preference row (fresh jti, fresh refresh
#      token, default consent/adult-gate state) via the existing
#      PreferenceRefreshTokenTransport#persist_new_preference_record!,
#   3. seeds only the safe keys onto the new row *without* marking them
#      explicit -- they are browser-continuity seed values, not the new
#      guest's own explicit choice (target semantics section 6.1/section 6.4),
#   4. retires the old row server-side so a leaked/cached old refresh token
#      cannot be replayed after sign-out.
#
# Fail-open only with respect to auth logout itself: an error anywhere in
# this concern must never prevent `AuthenticationLogoutable#logout_current_session!`
# from completing. It is NOT fail-open with respect to the old credential's
# trust status -- a failure to retire the old row is a distinct,
# ERROR-level, structurally-tagged event
# (`preference.sign_out.retirement_failed`), never folded into the same log
# line as an ordinary "couldn't seed a display value" warning. Callers /
# on-call responders must be able to grep for the retirement-specific event
# and know the old preference_access/preference_refresh/preference_dbsc
# credential family may still be valid.
#
# The three DB writes -- new row create, safe seed, and old row retirement --
# use one connection and one transaction. Refresh, DBSC, and access transport
# issuance is deliberately separate because response side effects cannot be
# rolled back with the database transaction.
module PreferenceSignOutRotation
  extend ActiveSupport::Concern

  # Adult content gate, consent, and anything identity-adjacent are
  # deliberately excluded: adult_content_gate is server/age-policy authority
  # (never client-copied), and consent is not carried across an identity
  # rotation -- the new guest re-affirms it (target semantics section 6.1).
  SAFE_COPY_TYPES = %i(
    theme language timezone region currency date_format time_format motion density page_size
  ).freeze

  private

  def rotate_preference_after_sign_out!
    return unless respond_to?(:preference_class, true)
    return unless respond_to?(:persist_new_preference_record!, true)
    return unless respond_to?(:issue_new_preference_transport!, true)
    return if @preferences.blank?

    old_preference = @preferences
    new_preference = perform_preference_sign_out_rotation!(old_preference)
    return if new_preference.blank?

    @preferences = new_preference
    issue_new_preference_transport!(new_preference)
    issue_access_token_from(new_preference) if respond_to?(:issue_access_token_from, true)
  rescue StandardError => e
    log_preference_sign_out_event!(
      "preference.sign_out.cookie_issuance_failed", e,
      severity: :warn,
    )
  end

  # Steps 2 (create new guest identity), 3 (safe-copy seed), and 4/retire
  # (invalidate old credential) all live on the same preference connection
  # class, so they are wrapped in one transaction: either the whole rotation
  # lands, or none of it does. A DB-level failure here therefore never
  # leaves a new guest row created *without* the old row being retired (the
  # inconsistent state the sign-in adoption/replay paths are not designed to
  # tolerate) -- worst case is "rotation did not happen at all, old
  # credential stays exactly as valid as it already was," which is reported
  # loudly rather than silently.
  def perform_preference_sign_out_rotation!(old_preference)
    connection_class =
      preference_connection_class(old_preference) if respond_to?(:preference_connection_class, true)
    new_preference = nil
    stage = :new_identity_creation

    rotation =
      proc do
        new_preference = persist_new_preference_record!(params_hash: {})
        stage = :safe_value_seed
        seed_guest_preference_from_sign_out!(new_preference, old_preference)
        stage = :old_credential_retirement
        retire_preference_after_sign_out!(old_preference)
      end

    if connection_class
      connection_class.connected_to(role: :writing) { connection_class.transaction(&rotation) }
    else
      rotation.call
    end

    new_preference
  rescue StandardError => e
    @preferences = old_preference
    # Whatever stage failed, the transaction above rolled the whole rotation
    # back -- there is no partially-applied DB state to worry about, but the
    # old credential is, as a direct consequence, still exactly as valid as
    # it was before sign-out was requested. That is the fact this event
    # exists to surface: it must never be conflated with an ordinary
    # display-preference write failure.
    log_preference_sign_out_event!(
      "preference.sign_out.retirement_failed", e,
      severity: :error, old_preference: old_preference, stage: stage,
    )
    nil
  end

  def seed_guest_preference_from_sign_out!(new_preference, old_preference)
    association_prefix = old_preference.class.name.underscore

    SAFE_COPY_TYPES.each do |type|
      old_child_name = "#{association_prefix}_#{type}"
      next unless old_preference.respond_to?(old_child_name)

      old_child = old_preference.public_send(old_child_name)
      next if old_child.blank? || old_child.option_id.blank?

      new_child_name = "#{new_preference.class.name.underscore}_#{type}"
      next unless new_preference.respond_to?(new_child_name)

      new_child = new_preference.public_send(new_child_name)
      next if new_child.blank? || new_child.option_id == old_child.option_id

      # Seed only -- deliberately not `mark_field_explicit!`. This value is
      # browser continuity, not the new guest's own explicit choice.
      new_child.update!(option_id: old_child.option_id)
    end
  end

  # Consume the old row (subsequent presentation is then handled by the
  # existing replay-detection path,
  # see PreferenceRefreshTokenTransport#handle_preference_refresh_replay!)
  # and expire it immediately so it also drops out of the `active` scope used
  # by every other lookup.
  def retire_preference_after_sign_out!(old_preference)
    old_preference.update!(used_at: Time.current, discard_at: Time.current)
  end

  # Never logs the raw token/digest/cookie value or any PII -- only the
  # preference row's own opaque public_id (never a principal/account
  # identifier, see security_jwt_preference_token_codec.rb) and the error
  # class, so this is safe to ship to a general log sink.
  def log_preference_sign_out_event!(event, error, severity:, old_preference: nil, stage: nil)
    Rails.logger.public_send(
      severity,
      JitLogEvent.format(
        event,
        error: error.class.name,
        message: error.message,
        preference_public_id: old_preference&.public_id,
        stage: stage,
      ),
    )
  end
end
