# frozen_string_literal: true

require "test_helper"

# rubocop:disable Minitest/AssertEqual -- Proof snapshots must not disclose references or keyed digests on failure.

class SignupOtpProofDatabaseTest < ActiveSupport::TestCase
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
      private_key = ROTP::Base32.random_base32
      contact.store_otp(private_key, 1, (now + 10.minutes).to_i)
      code = ROTP::HOTP.new(private_key).at(1).to_s
      flow = flow_model.create!(
        principal_id: owner.id, status_id: flow_model::STATUS_MODEL::CONTACT_PENDING, step: "contact",
        nonce_digest: flow_model.digest_nonce(SecureRandom.hex(32)), issued_at: now,
        expires_at: now + 15.minutes, entry_method: channel.to_s,
        pending_contact_type: channel.to_s, pending_contact_id: contact.id,
      )
      arguments = {
        purpose: :sign_up,
        surface: surface,
        channel: channel,
        subject: flow,
        destination: destination,
        code: code,
        session_nonce: flow.public_id,
      }
      recorded = SignUpOtpChallengeRecorder.call(flow: flow, record: contact, channel: channel, code: code)

      assert recorded, "newly issued signup challenge must retain its original authority"

      original = contact.reload.sign_up_otp_context.deep_dup
      invalid_contexts = [
        original.merge("version" => 2), original.except("nonce_digest"),
        original.merge("extra" => "field"), original.merge("purpose" => "sign_in"),
        original.merge("surface" => "org"), original.merge("contact_ref" => "other_contact"),
        original.merge("counter" => 1), original.merge("counter" => "18446744073709551616"),
        original.merge("verified_at" => now.utc.iso8601(6)),
        original.merge("expires_at" => "infinity"), original.merge("issued_at" => "-infinity"),
      ]
      invalid_contexts.each do |invalid|
        contact.class.transaction(requires_new: true) do
          assert_raises(ActiveRecord::StatementInvalid) do
            contact.update_columns(sign_up_otp_context: invalid)
          end
          raise ActiveRecord::Rollback
        end

        assert_operator original, :==, contact.reload.sign_up_otp_context,
                        "rejected direct writes must preserve challenge facts"
      end

      verified = SignOtpCeremony.verify!(**arguments)

      assert_predicate verified, :success?, "public verification must establish the immutable result"
      committed = contact.reload.sign_up_otp_context.deep_dup
      [nil, original, committed.merge("counter" => "2")].each do |replacement|
        contact.class.transaction(requires_new: true) do
          assert_raises(ActiveRecord::StatementInvalid) do
            contact.update_columns(sign_up_otp_context: replacement)
          end
          raise ActiveRecord::Rollback
        end

        assert_operator committed, :==, contact.reload.sign_up_otp_context,
                        "direct SQL cannot erase or replace committed proof"
      end
    end
  end
end
# rubocop:enable Minitest/AssertEqual
