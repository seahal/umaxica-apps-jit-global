# frozen_string_literal: true

require "test_helper"

class RpSenderKeyUniquenessTest < ActiveSupport::TestCase
  CELLS = [
    [RpBaseAppEventReceipt, RpBaseAppOpSessionBinding, RpBaseAppIdentityBinding, RpBaseAppPrincipal],
    [RpBaseComEventReceipt, RpBaseComOpSessionBinding, RpBaseComIdentityBinding, RpBaseComPrincipal],
    [RpBaseOrgEventReceipt, RpBaseOrgOpSessionBinding, RpBaseOrgIdentityBinding, RpBaseOrgPrincipal],
    [RpCoreAppEventReceipt, RpCoreAppOpSessionBinding, RpCoreAppIdentityBinding, RpCoreAppPrincipal],
    [RpCoreComEventReceipt, RpCoreComOpSessionBinding, RpCoreComIdentityBinding, RpCoreComPrincipal],
    [RpCoreOrgEventReceipt, RpCoreOrgOpSessionBinding, RpCoreOrgIdentityBinding, RpCoreOrgPrincipal],
    [RpWarpAppEventReceipt, RpWarpAppOpSessionBinding, RpWarpAppIdentityBinding, RpWarpAppPrincipal],
    [RpWarpComEventReceipt, RpWarpComOpSessionBinding, RpWarpComIdentityBinding, RpWarpComPrincipal],
    [RpWarpOrgEventReceipt, RpWarpOrgOpSessionBinding, RpWarpOrgIdentityBinding, RpWarpOrgPrincipal],
    [RpPalmAppEventReceipt, RpPalmAppOpSessionBinding, RpPalmAppIdentityBinding, RpPalmAppPrincipal],
    [RpTechOrgEventReceipt, RpTechOrgOpSessionBinding, RpTechOrgIdentityBinding, RpTechOrgPrincipal],
    [RpEditOrgEventReceipt, RpEditOrgOpSessionBinding, RpEditOrgIdentityBinding, RpEditOrgPrincipal],
  ].freeze

  CELLS.each do |receipt_class, anchor_class, identity_class, principal_class|
    test "#{anchor_class.name} scopes SID by issuer and retains DB enforcement" do
      keys = { issuer: "https://issuer.example.test",
               realm: anchor_class::REALM,
               client_id: anchor_class::CLIENT_ID,
               sid: "anchor", }
      first = anchor_class.create!(keys)

      assert_predicate anchor_class.create!(keys.merge(sid: "other")), :persisted?
      assert_predicate anchor_class.create!(keys.merge(issuer: "https://other.example.test")), :persisted?
      first.revoke!

      assert_predicate first.reload, :revoked?
      assert_raises(ActiveRecord::RecordNotUnique) do
        anchor_class.transaction(requires_new: true) { anchor_class.new(keys).save!(validate: false) }
      end
    end

    test "#{anchor_class.name} preflights the complete SID key on creation" do
      keys = { issuer: "https://issuer.example.test",
               realm: anchor_class::REALM,
               client_id: anchor_class::CLIENT_ID,
               sid: "anchor", }
      anchor_class.create!(keys)
      duplicate = anchor_class.new(keys)

      assert_not duplicate.valid?
      assert duplicate.errors.of_kind?(:sid, :taken)
      assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }
    end

    test "#{identity_class.name} scopes subjects by issuer and retains the immutable identity mapping" do
      principal = principal_class.create!
      keys = { issuer: "https://issuer.example.test",
               realm: identity_class::REALM,
               client_id: identity_class::CLIENT_ID,
               subject: "subject",
               principal: principal, }
      first = identity_class.create!(keys)

      assert_predicate identity_class.create!(keys.merge(subject: "other")), :persisted?
      assert_predicate identity_class.create!(keys.merge(issuer: "https://other.example.test")), :persisted?
      first.save!

      assert_equal principal.id, first.reload.principal_id
      assert_raises(ActiveRecord::RecordNotUnique) do
        identity_class.transaction(requires_new: true) { identity_class.new(keys).save!(validate: false) }
      end
      first.subject = "changed"

      assert_not first.valid?
      assert first.errors.of_kind?(:subject, "cannot be changed after creation")
    end

    test "#{identity_class.name} preflights the complete subject key on creation" do
      principal = principal_class.create!
      keys = { issuer: "https://issuer.example.test",
               realm: identity_class::REALM,
               client_id: identity_class::CLIENT_ID,
               subject: "subject",
               principal: principal, }
      identity_class.create!(keys)
      duplicate = identity_class.new(keys)

      assert_not duplicate.valid?
      assert duplicate.errors.of_kind?(:subject, :taken)
      assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }
    end

    test "#{receipt_class.name} retains sender event and JTI scope with raw DB replay enforcement" do
      anchor = anchor_class.create!(
        issuer: "https://issuer.example.test", realm: anchor_class::REALM,
        client_id: anchor_class::CLIENT_ID, sid: "anchor",
      )
      now = receipt_class.database_now
      keys = { issuer: anchor.issuer,
               realm: anchor.realm,
               client_id: anchor.client_id,
               event_type: "backchannel_logout",
               jti_digest: Digest::SHA256.digest("first"),
               op_session_binding: anchor,
               expires_at: now + 60,
               committed_at: now, }
      receipt_class.create!(keys)

      assert_predicate receipt_class.create!(keys.merge(jti_digest: Digest::SHA256.digest("other"))), :persisted?
      assert_predicate receipt_class.create!(keys.merge(event_type: "other")), :persisted?
      assert_predicate receipt_class.create!(keys.merge(issuer: "https://other.example.test")), :persisted?
      assert_raises(ActiveRecord::RecordNotUnique) do
        receipt_class.transaction(requires_new: true) { receipt_class.new(keys).save!(validate: false) }
      end
    end

    test "#{receipt_class.name} preflights sender event and JTI together on creation" do
      anchor = anchor_class.create!(
        issuer: "https://issuer.example.test", realm: anchor_class::REALM,
        client_id: anchor_class::CLIENT_ID, sid: "anchor",
      )
      now = receipt_class.database_now
      keys = { issuer: anchor.issuer,
               realm: anchor.realm,
               client_id: anchor.client_id,
               event_type: "backchannel_logout",
               jti_digest: Digest::SHA256.digest("first"),
               op_session_binding: anchor,
               expires_at: now + 60,
               committed_at: now, }
      receipt_class.create!(keys)
      duplicate = receipt_class.new(keys)

      assert_not duplicate.valid?
      assert duplicate.errors.of_kind?(:jti_digest, :taken)
      assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }
    end
  end
end
