# frozen_string_literal: true

require "test_helper"

# rubocop:disable Minitest/AssertEqual -- Proof snapshots must not disclose references or keyed digests on failure.

class SignupOtpCommittedRetryTest < ActiveSupport::TestCase
  [
    [Client, ClientEmail, :user_id, ClientSignUpFlow, :app, :email],
    [Client, ClientTelephone, :user_id, ClientSignUpFlow, :app, :telephone],
    [Visitor, VisitorEmail, :visitor_id, VisitorSignUpFlow, :com, :email],
    [Visitor, VisitorTelephone, :visitor_id, VisitorSignUpFlow, :com, :telephone],
  ].each do |owner_model, contact_model, owner_key, flow_model, surface, channel|
    %w(exact result_before result_at result_after wrong_code other_flow released cancelled).each do |scenario|
      test "#{surface} #{channel} signup committed retry validates #{scenario} without consuming another generation" do
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
        first = SignOtpCeremony.verify!(**arguments)

        assert_predicate first, :success?, "the initial valid comparison must commit verification"
        assert_equal :verified, first.status
        proof = contact.reload.sign_up_otp_context.deep_dup
        clock = contact.class.database_now
        case scenario
        when "result_before" then clock = Time.iso8601(proof.fetch("result_expires_at")) - Rational(1, 1_000_000)
        when "result_at" then clock = Time.iso8601(proof.fetch("result_expires_at"))
        when "result_after" then clock = Time.iso8601(proof.fetch("result_expires_at")) + Rational(1, 1_000_000)
        when "wrong_code" then arguments[:code] = (code == "000000") ? "000001" : "000000"
        when "other_flow"
          sibling = flow_model.create!(
            principal_id: owner.id, status_id: flow_model::STATUS_MODEL::CONTACT_PENDING, step: "contact",
            nonce_digest: flow_model.digest_nonce(SecureRandom.hex(32)), issued_at: now, expires_at: now + 15.minutes,
            entry_method: channel.to_s, pending_contact_type: channel.to_s, pending_contact_id: contact.id,
          )
          arguments.merge!(subject: sibling, session_nonce: sibling.public_id)
        when "released"
          contact.finalize_binding!
          contact.release_binding!
        when "cancelled" then SignUpTermination.call(cycle: flow, event: :cancel)
        end
        second = nil
        contact.class.stub(:database_now, clock) { second = SignOtpCeremony.verify!(**arguments) }
        eligible = %w(exact result_before).include?(scenario)

        assert_equal eligible, second.success?, "retry authority must follow binding and the fixed result deadline"
        assert_equal :verified, second.status if eligible

        assert_nil contact.reload.get_otp
        assert_nil contact.binding_finalized_at unless scenario == "released"

        assert_operator proof, :==, contact.sign_up_otp_context, "refusal and retry must preserve the committed proof"
        snapshot_keys = proof.keys

        assert_not snapshot_keys.include?("otp_private_key")
        assert_not proof.values.include?(code), "committed proof must not persist the raw OTP"
      end
    end
  end
end
# rubocop:enable Minitest/AssertEqual
