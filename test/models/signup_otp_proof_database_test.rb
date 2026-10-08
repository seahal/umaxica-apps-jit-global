# frozen_string_literal: true

require "test_helper"

# rubocop:disable Minitest/AssertEqual -- Proof snapshots must not disclose references or keyed digests on failure.

class SignupOtpProofDatabaseTest < ActiveSupport::TestCase
  setup do
    ClientSignUpFlowStatus::DEFAULTS.each { |id| ClientSignUpFlowStatus.find_or_create_by!(id: id) }
    VisitorSignUpFlowStatus::DEFAULTS.each { |id| VisitorSignUpFlowStatus.find_or_create_by!(id: id) }
    ClientSignUpFlowCleanupStatus::DEFAULTS.each { |id| ClientSignUpFlowCleanupStatus.find_or_create_by!(id: id) }
    VisitorSignUpFlowCleanupStatus::DEFAULTS.each { |id| VisitorSignUpFlowCleanupStatus.find_or_create_by!(id: id) }
  end

  [
    [Client, ClientEmail, :user_id, ClientSignUpFlow, :app, :email],
    [Client, ClientTelephone, :user_id, ClientSignUpFlow, :app, :telephone],
    [Visitor, VisitorEmail, :visitor_id, VisitorSignUpFlow, :com, :email],
    [Visitor, VisitorTelephone, :visitor_id, VisitorSignUpFlow, :com, :telephone],
  ].each do |owner_model, contact_model, owner_key, flow_model, surface, channel|
    test "#{surface} #{channel} signup proof database shape and immutable committed result" do
      owner = owner_model.create!(
        status_id: (surface == :app) ? ClientStatus::UNVERIFIED_WITH_SIGN_UP : VisitorStatus::ACTIVE,
      )
      destination =
        (channel == :email) ? "retry-#{SecureRandom.hex(8)}@example.test" :
                 "+8190#{SecureRandom.random_number(100_000_000).to_s.rjust(8, "0")}"
      contact = contact_model.create!(
        owner_key => owner.id, :confirm_policy => "1",
        ((channel == :email) ? :address : :number) => destination,
        **case [surface, channel]
          when [:app, :email] then { user_email_status_id: ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP }
          when [:app, :telephone] then { user_telephone_status_id: ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP }
          when [:com, :email] then { visitor_email_status_id: VisitorEmailStatus::UNVERIFIED_WITH_SIGN_UP }
          when [:com, :telephone] then { visitor_telephone_status_id: VisitorTelephoneStatus::UNVERIFIED_WITH_SIGN_UP }
          end,
      )
      now = flow_model.database_now
      nonce = SecureRandom.hex(32)
      flow = flow_model.create!(
        principal_id: owner.id, status_id: flow_model::STATUS_MODEL::CONTACT_PENDING, step: "contact",
        nonce_digest: flow_model.digest_nonce(nonce), issued_at: now,
        expires_at: now + 15.minutes, entry_method: channel.to_s,
        pending_contact_type: channel.to_s, pending_contact_id: contact.id,
      )
      issued =
        if channel == :email
          EmailSignUpOtpIssuer.call(flow: flow, email: contact, session_nonce: nonce)
        else
          TelephoneSignUpOtpIssuer.call(flow: flow, telephone: contact, session_nonce: nonce)
        end

      assert_predicate issued, :success?, "newly issued signup challenge must retain its original authority"
      transaction = issued.transaction
      original = transaction.reload.attributes

      invalid_contexts = [
        { purpose: "unsupported" }, { otp_generation: nil }, { otp_generation: "not-a-uuid" },
        { otp_verifier: "a" * 63 }, { otp_verifier: "a" * 65 },
        { otp_verifier: "G" * 64 }, { otp_verifier: "" },
        { otp_expires_at: Float::INFINITY }, { expires_at: -Float::INFINITY },
        { otp_consumed_at: now }, { otp_receipt_verifier: "a" * 64 },
      ]
      invalid_contexts.each do |invalid|
        transaction.class.transaction(requires_new: true) do
          assert_raises(ActiveRecord::StatementInvalid) do
            transaction.update_columns(invalid)
          end
          raise ActiveRecord::Rollback
        end

        assert_operator original, :==, transaction.reload.attributes,
                        "rejected direct writes must preserve challenge facts"
      end

      verified =
        if channel == :email
          EmailSignUpOtpVerificationCommitter.call(flow: flow, email: contact, session_nonce: nonce, code: issued.code)
        else
          TelephoneSignUpOtpVerificationCommitter.call(
            flow: flow, telephone: contact, session_nonce: nonce, code: issued.code,
          )
        end

      assert_predicate verified, :success?, "public verification must establish the immutable result"
      committed = transaction.reload.attributes
      [
        { otp_consumed_at: nil, otp_receipt_verifier: nil, otp_result_expires_at: nil },
        { otp_verifier: original.fetch("otp_verifier") }, { otp_generation: SecureRandom.uuid },
      ].each do |replacement|
        transaction.class.transaction(requires_new: true) do
          assert_raises(ActiveRecord::StatementInvalid) do
            transaction.update_columns(replacement)
          end
          raise ActiveRecord::Rollback
        end

        assert_operator committed, :==, transaction.reload.attributes,
                        "direct SQL cannot erase or replace committed proof"
      end
    end
  end
end
# rubocop:enable Minitest/AssertEqual
