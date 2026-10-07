# frozen_string_literal: true

require "test_helper"

class TelephoneSignupSourceAuditTest < ActiveSupport::TestCase
  test "telephone signup rejects invalid audit attribution and rolls back Source facts with its intent" do
    [
      [Client, ClientTelephone, :user_id, :user_telephone_status_id,
       ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP, ClientStatus::UNVERIFIED_WITH_SIGN_UP,
       SignAppUpTelephoneRegistrationFinalizer, ClientContactAuditOutbox, :app,],
      [Visitor, VisitorTelephone, :visitor_id, :visitor_telephone_status_id,
       VisitorTelephoneStatus::UNVERIFIED_WITH_SIGN_UP, VisitorStatus::NOTHING,
       SignComUpTelephoneRegistrationFinalizer, VisitorContactAuditOutbox, :com,],
    ].each do |principal, contact_type, owner_key, status_key, contact_status, owner_status, finalizer, outbox, surface|
      owner = principal.create!(status_id: owner_status)
      contact = contact_type.create!(
        owner_key => owner.id, status_key => contact_status,
        :raw_number => "+819012345679", :confirm_policy => "1", :confirm_using_mfa => "1",
      )
      contact.store_otp("signup-source-audit", 123, 5.minutes.from_now.to_i)
      if surface == :app
        ClientPasskey.create!(
          user: owner, webauthn_id: SecureRandom.uuid, public_key: "public-key",
          description: "Signup passkey", sign_count: 0,
        )
      end
      context = ActorValuesContext.empty.with(tld: surface, surface: :sign)
      operation_ref = SecureRandom.uuid
      assert_raises(ArgumentError) do
        finalizer.call(
          telephone: contact, actor_context: context.with(tld: :org), operation_ref: operation_ref,
        )
      end
      assert_nil contact.reload.binding_finalized_at
      assert_equal contact_status, contact.public_send(status_key)
      assert_equal owner_status, owner.reload.status_id
      assert_predicate contact, :otp_active?
      assert_not outbox.exists?(operation_ref: operation_ref)

      [nil, ""].each do |invalid_ref|
        assert_raises(ActiveRecord::RecordInvalid) do
          finalizer.call(telephone: contact, actor_context: context, operation_ref: invalid_ref)
        end
        assert_nil contact.reload.binding_finalized_at
        assert_equal contact_status, contact.public_send(status_key)
        assert_equal owner_status, owner.reload.status_id
        assert_predicate contact, :otp_active?
        assert_not outbox.exists?(contact_ref: contact.public_id)
      end

      principal.transaction do
        finalizer.call(telephone: contact, actor_context: context, operation_ref: operation_ref)

        assert_predicate contact.reload, :binding_effective?
        assert outbox.exists?(operation_ref: operation_ref)
        raise ActiveRecord::Rollback
      end

      assert_nil contact.reload.binding_finalized_at
      assert_equal contact_status, contact.public_send(status_key)
      assert_equal owner_status, owner.reload.status_id
      assert_predicate contact, :otp_active?
      assert_not outbox.exists?(operation_ref: operation_ref)
    end
  end

  test "telephone signup refuses a suspended Identity under its Source owner lock" do
    [
      [Client, ClientTelephone, :user_id, SignAppUpTelephoneRegistrationFinalizer, ClientContactAuditOutbox, :app],
      [Visitor, VisitorTelephone, :visitor_id, SignComUpTelephoneRegistrationFinalizer,
       VisitorContactAuditOutbox, :com,],
    ].each do |principal, contact_type, owner_key, finalizer, outbox, surface|
      owner = principal.create!(deactivated_at: principal.database_now)
      contact = contact_type.create!(
        owner_key => owner.id, :raw_number => "+819012345674", :confirm_policy => "1", :confirm_using_mfa => "1",
      )
      contact.store_otp("suspended-signup-source", 1, (contact_type.database_now + 5.minutes).to_i)
      if surface == :app
        ClientPasskey.create!(
          user: owner, webauthn_id: SecureRandom.uuid, public_key: "public-key", description: "Signup passkey",
        )
      end
      retained_otp = contact.reload.get_otp
      operation_ref = SecureRandom.uuid
      context = ActorValuesContext.empty.with(tld: surface, surface: :sign)

      assert_raises(ActiveRecord::RecordNotSaved) do
        finalizer.call(telephone: contact, actor_context: context, operation_ref: operation_ref)
      end
      assert_not contact.reload.binding_effective?
      assert_equal retained_otp, contact.get_otp
      assert_not outbox.exists?(operation_ref: operation_ref)
      assert_predicate owner.reload, :suspended?
    end
  end
end
