# frozen_string_literal: true

require "test_helper"

# Boolean snapshots keep keyed digests and root references out of assertion diagnostics.
# rubocop:disable Minitest/AssertEqual, Minitest/AssertOperator
class CredentialRegistrationOtpProofDatabaseTest < ActiveSupport::TestCase
  [
    [Client, ClientToken, ClientEmail, :user_id, :app, :email],
    [Client, ClientToken, ClientTelephone, :user_id, :app, :telephone],
    [Visitor, VisitorToken, VisitorEmail, :visitor_id, :com, :email],
    [Visitor, VisitorToken, VisitorTelephone, :visitor_id, :com, :telephone],
  ].each do |owner_model, root_model, contact_model, owner_key, surface, channel|
    test "#{surface} #{channel} registration proof rejects malformed direct writes and protects verified facts" do
      owner = owner_model.create!(status_id: (surface == :app) ? ClientStatus::ACTIVE : VisitorStatus::ACTIVE)
      root = root_model.create!(owner_key => owner.id, :discard_at => 1.day.from_now)
      root.rotate_refresh_token!
      contact = contact_model.create!(
        owner_key => owner.id,
        :confirm_policy => "1",
        **if channel == :email
            { raw_address: "proof-#{SecureRandom.hex(8)}@example.test" }
          else
            { raw_number: "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}", confirm_using_mfa: "1" }
          end,
      )
      secret = ROTP::Base32.random_base32
      contact.store_otp(secret, 1, (contact.class.database_now + 10.minutes).to_i)
      code = ROTP::HOTP.new(secret).at(1).to_s
      nonce = SecureRandom.urlsafe_base64(32)
      flow = ContactRegistrationOtpIssuer.call!(
        actor: owner, token: root, contact:, channel:, browser_nonce: nonce, code:,
      )
      original = contact.reload.credential_registration_otp_context.deep_dup
      now = Time.iso8601(original.fetch("issued_at"))
      malformed = [
        [], {}, original.except("browser_digest"), original.merge("extra" => true),
        original.merge("version" => 2), original.merge("surface" => "org"),
        original.merge("purpose" => "sign_up"), original.merge("flow_ref" => ""),
        original.merge("session_ref" => ""), original.merge("session_ref" => "x" * 22),
        original.merge("owner_ref" => ""), original.merge("owner_ref" => "x" * 22),
        original.merge("contact_ref" => "other"), original.merge("browser_digest" => nil),
        original.merge("browser_digest" => "a" * 63), original.merge("browser_digest" => "a" * 65),
        original.merge("destination_digest" => "a" * 63), original.merge("code_digest" => "a" * 65),
        original.merge("destination_digest" => "a" * 65), original.merge("code_digest" => "a" * 63),
        original.merge("counter" => 1), original.merge("counter" => "01"),
        original.merge("counter" => "-1"), original.merge("counter" => nil),
        original.merge("counter" => "18446744073709551616"),
        original.merge("issued_at" => nil), original.merge("expires_at" => "infinity"),
        original.merge("issued_at" => "-infinity"),
        original.merge("expires_at" => now.iso8601(6)),
        original.merge("verified_at" => now.iso8601(6)),
        original.merge("result_expires_at" => (now + 60.seconds).iso8601(6)),
        original.merge(
          "verified_at" => (now - Rational(1, 1_000_000)).iso8601(6),
          "result_expires_at" => (now + 60.seconds).iso8601(6),
        ),
        original.merge(
          "verified_at" => now.iso8601(6),
          "result_expires_at" => (now + 60.seconds + Rational(1, 1_000_000)).iso8601(6),
        ),
        original.merge("verified_at" => now.iso8601(6), "result_expires_at" => now.iso8601(6)),
      ]
      malformed.each_with_index do |replacement, index|
        contact.class.transaction(requires_new: true) do
          assert_raises(ActiveRecord::StatementInvalid, "malformed proof partition #{index}") do
            contact.update_columns(credential_registration_otp_context: replacement)
          end
          raise ActiveRecord::Rollback
        end

        assert original == contact.reload.credential_registration_otp_context,
               "rejected writes must preserve the original challenge without disclosing its facts"
      end

      # PostgreSQL timestamps have microsecond precision; counters are canonical unsigned decimal strings.
      valid_boundaries = [
        original.merge("counter" => "0"), original.merge("counter" => "18446744073709551614"),
        original.merge("counter" => "18446744073709551615"),
        original.merge("session_ref" => "x", "owner_ref" => "x"),
        original.merge("session_ref" => "x" * 21, "owner_ref" => "x" * 21),
        original.merge(
          "browser_digest" => "a" * 64, "destination_digest" => "a" * 64,
          "code_digest" => "a" * 64,
        ),
      ]
      [Rational(1, 1_000_000), 60.seconds - Rational(1, 1_000_000), 60.seconds].each do |ttl|
        valid_boundaries << original.merge(
          "verified_at" => now.iso8601(6), "result_expires_at" => (now + ttl).iso8601(6),
        )
      end
      valid_boundaries.each do |replacement|
        contact.class.transaction(requires_new: true) do
          assert contact.update_columns(credential_registration_otp_context: replacement)
          raise ActiveRecord::Rollback
        end

        assert original == contact.reload.credential_registration_otp_context,
               "rolled-back boundary probes must not manufacture a verification result"
      end

      assert_equal :verified, ContactRegistrationOtpVerificationCommitter.call!(
        actor: owner, token: root, contact:, transaction: flow, channel:, browser_nonce: nonce, code:,
      )
      committed = contact.reload.credential_registration_otp_context.deep_dup
      [nil, original, committed.merge("counter" => "2")].each do |replacement|
        contact.class.transaction(requires_new: true) do
          assert_raises(ActiveRecord::StatementInvalid) do
            contact.update_columns(credential_registration_otp_context: replacement)
          end
          raise ActiveRecord::Rollback
        end

        assert committed == contact.reload.credential_registration_otp_context,
               "direct writes cannot erase or replace a committed proof"
      end
      assert_nil contact.get_otp
      assert_not flow.reload.consumed?
    end
  end
end
# rubocop:enable Minitest/AssertEqual, Minitest/AssertOperator
