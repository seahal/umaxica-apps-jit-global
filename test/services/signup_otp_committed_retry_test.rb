# frozen_string_literal: true

require "test_helper"

class SignupOtpCommittedRetryTest < ActiveSupport::TestCase
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
        nonce = SecureRandom.hex(32)
        flow = flow_model.create!(
          principal_id: owner.id, status_id: flow_model::STATUS_MODEL::CONTACT_PENDING, step: "contact",
          nonce_digest: flow_model.digest_nonce(nonce), issued_at: now,
          expires_at: now + 15.minutes, entry_method: channel.to_s,
          pending_contact_type: channel.to_s, pending_contact_id: contact.id,
        )
        issuer = (channel == :email) ? EmailSignUpOtpIssuer : TelephoneSignUpOtpIssuer
        verifier = (channel == :email) ? EmailSignUpOtpVerificationCommitter : TelephoneSignUpOtpVerificationCommitter
        arguments = { :flow => flow, channel => contact, :session_nonce => nonce }
        issued = issuer.call(**arguments)

        assert_predicate issued, :success?, "newly issued signup challenge must retain its original authority"
        code = issued.code
        arguments[:code] = code
        first = verifier.call(**arguments)

        assert_predicate first, :success?, "the initial valid comparison must commit verification"
        assert_equal :verified, first.status
        proof = issued.transaction.reload.attributes.slice(
          "purpose", "otp_generation", "otp_verifier", "otp_consumed_at", "otp_cancelled_at",
          "otp_receipt_verifier", "otp_result_expires_at",
        )
        clock = issued.transaction.class.database_now
        case scenario
        when "result_before" then clock = proof.fetch("otp_result_expires_at") - Rational(1, 1_000_000)
        when "result_at" then clock = proof.fetch("otp_result_expires_at")
        when "result_after" then clock = proof.fetch("otp_result_expires_at") + Rational(1, 1_000_000)
        when "wrong_code" then arguments[:code] = (code == "000000") ? "000001" : "000000"
        when "other_flow"
          sibling_nonce = SecureRandom.hex(32)
          sibling = flow_model.create!(
            principal_id: owner.id, status_id: flow_model::STATUS_MODEL::CONTACT_PENDING, step: "contact",
            nonce_digest: flow_model.digest_nonce(sibling_nonce), issued_at: now, expires_at: now + 15.minutes,
            entry_method: channel.to_s, pending_contact_type: channel.to_s, pending_contact_id: contact.id,
          )
          arguments.merge!(flow: sibling, session_nonce: sibling_nonce)
        when "released"
          contact.finalize_binding!
          contact.release_binding!
        when "cancelled" then SignUpTermination.call(cycle: flow, event: :cancel)
        end
        second = nil
        issued.transaction.class.stub(:database_now, clock) { second = verifier.call(**arguments) }
        eligible = %w(exact result_before).include?(scenario)

        assert_equal eligible, second.verified_evidence?,
                     "retry authority must follow binding and the fixed result deadline"
        assert_not second.success?, "Retained proof never creates fresh verification authority"
        assert_equal :already_verified, second.status if eligible

        assert_nil issued.transaction.reload.otp_verifier
        contact.reload
        assert_nil contact.binding_finalized_at unless scenario == "released"

        proof_unchanged = proof == issued.transaction.attributes.slice(*proof.keys)

        assert proof_unchanged, "Refusal and retry must preserve the committed proof"
        snapshot_keys = proof.keys

        assert_not snapshot_keys.include?("otp_private_key")
        assert_not proof.values.include?(code), "committed proof must not persist the raw OTP"
      end
    end
  end
end
