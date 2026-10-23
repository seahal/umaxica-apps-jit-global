# frozen_string_literal: true

require "test_helper"

class RpLiveSessionUniquenessTest < ActiveSupport::TestCase
  CELLS = [
    [RpBaseAppSession, RpBaseAppOpSessionBinding, RpBaseAppIdentityBinding, RpBaseAppPrincipal],
    [RpBaseComSession, RpBaseComOpSessionBinding, RpBaseComIdentityBinding, RpBaseComPrincipal],
    [RpBaseOrgSession, RpBaseOrgOpSessionBinding, RpBaseOrgIdentityBinding, RpBaseOrgPrincipal],
    [RpCoreAppSession, RpCoreAppOpSessionBinding, RpCoreAppIdentityBinding, RpCoreAppPrincipal],
    [RpCoreComSession, RpCoreComOpSessionBinding, RpCoreComIdentityBinding, RpCoreComPrincipal],
    [RpCoreOrgSession, RpCoreOrgOpSessionBinding, RpCoreOrgIdentityBinding, RpCoreOrgPrincipal],
    [RpWarpAppSession, RpWarpAppOpSessionBinding, RpWarpAppIdentityBinding, RpWarpAppPrincipal],
    [RpWarpComSession, RpWarpComOpSessionBinding, RpWarpComIdentityBinding, RpWarpComPrincipal],
    [RpWarpOrgSession, RpWarpOrgOpSessionBinding, RpWarpOrgIdentityBinding, RpWarpOrgPrincipal],
    [RpPalmAppSession, RpPalmAppOpSessionBinding, RpPalmAppIdentityBinding, RpPalmAppPrincipal],
    [RpTechOrgSession, RpTechOrgOpSessionBinding, RpTechOrgIdentityBinding, RpTechOrgPrincipal],
    [RpEditOrgSession, RpEditOrgOpSessionBinding, RpEditOrgIdentityBinding, RpEditOrgPrincipal],
  ].freeze

  CELLS.each do |session_class, anchor_class, identity_class, principal_class|
    test "#{session_class.name} preserves revoked history anchor scope and the DB partial index" do
      principal = principal_class.create!
      identity = identity_class.create!(
        principal: principal, issuer: "https://issuer.example.test",
        realm: session_class::REALM, client_id: session_class::CLIENT_ID, subject: "subject",
      )
      anchor = anchor_class.create!(
        identity_binding: identity, issuer: identity.issuer,
        realm: identity.realm, client_id: identity.client_id, sid: "first",
      )
      now = session_class.database_now
      expired = session_class.create!(
        op_session_binding: anchor, absolute_expires_at: now - 1,
        installed_generation: 0,
      )
      2.times do
        history = session_class.create!(
          op_session_binding: anchor, absolute_expires_at: now + 3600,
          installed_generation: 0, revoked_at: now,
        )

        assert_not history.active?(now: now)
      end
      other_anchor = anchor_class.create!(
        identity_binding: identity, issuer: identity.issuer,
        realm: identity.realm, client_id: identity.client_id, sid: "other",
      )
      other = session_class.create!(
        op_session_binding: other_anchor, absolute_expires_at: now + 3600,
        installed_generation: 0,
      )

      assert_predicate other, :persisted?
      assert_nil expired.reload.revoked_at
      error =
        assert_raises(ActiveRecord::RecordNotUnique) do
          session_class.transaction(requires_new: true) do
            session_class.new(
              op_session_binding: anchor, absolute_expires_at: now + 3600,
              installed_generation: 0,
            ).save!(validate: false)
          end
        end
      assert_instance_of PG::UniqueViolation, error.cause
      expired.update!(revoked_at: now)
      replacement = session_class.create!(
        op_session_binding: anchor, absolute_expires_at: now + 3600,
        installed_generation: 0,
      )

      assert_predicate replacement, :persisted?
    end

    test "#{session_class.name} rejects an unrevoked duplicate even when the existing session expired" do
      principal = principal_class.create!
      identity = identity_class.create!(
        principal: principal, issuer: "https://issuer.example.test",
        realm: session_class::REALM, client_id: session_class::CLIENT_ID, subject: "subject",
      )
      anchor = anchor_class.create!(
        identity_binding: identity, issuer: identity.issuer,
        realm: identity.realm, client_id: identity.client_id, sid: "first",
      )
      now = session_class.database_now
      session_class.create!(
        op_session_binding: anchor, absolute_expires_at: now - 1,
        installed_generation: 0,
      )
      candidate = session_class.new(
        op_session_binding: anchor, absolute_expires_at: now + 3600,
        installed_generation: 0,
      )

      assert_not candidate.valid?
      assert candidate.errors.of_kind?(:op_session_binding_id, :taken)
      assert_raises(ActiveRecord::RecordInvalid) { candidate.save! }
      assert_predicate candidate, :new_record?
      candidate.revoked_at = now

      assert_predicate candidate, :valid?
      candidate.save!

      assert_equal now, candidate.reload.revoked_at
    end
  end
end
