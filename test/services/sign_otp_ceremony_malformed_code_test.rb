# frozen_string_literal: true

require "test_helper"

class SignOtpCeremonyMalformedCodeTest < ActiveSupport::TestCase
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
    test "#{surface} #{channel} malformed code partitions refuse without consuming or changing proof" do
      owner = owner_model.create!(
        status_id: (surface == :app) ? ClientStatus::UNVERIFIED_WITH_SIGN_UP : VisitorStatus::ACTIVE,
      )
      destination =
        (channel == :email) ? "malformed-#{SecureRandom.hex(8)}@example.test" :
          "+8190#{SecureRandom.random_number(100_000_000).to_s.rjust(8, "0")}"
      contact = contact_model.create!(
        owner_key => owner.id, :confirm_policy => "1",
        ((channel == :email) ? :address : :number) => destination,
      )
      now = flow_model.database_now
      flow = flow_model.create!(
        principal_id: owner.id, status_id: flow_model::STATUS_MODEL::STARTED, step: "start",
        nonce_digest: flow_model.digest_nonce("malformed-code-browser"), issued_at: now,
        expires_at: now + 15.minutes, entry_method: channel.to_s,
        pending_contact_type: channel.to_s, pending_contact_id: contact.id,
      )
      issuer = (channel == :email) ? EmailSignUpOtpIssuer : TelephoneSignUpOtpIssuer
      verifier = (channel == :email) ? EmailSignUpOtpVerificationCommitter : TelephoneSignUpOtpVerificationCommitter
      arguments = { :flow => flow, channel => contact }
      issued = issuer.call(**arguments, session_nonce: "malformed-code-browser")

      assert_predicate issued, :success?
      valid_code = issued.code
      original_contact = contact.reload.attributes
      original_flow = flow.reload.attributes
      original_proof = issued.transaction.reload.attributes
      public_reference = verifier.call(
        **arguments, code: valid_code, session_nonce: flow.public_id,
      )

      assert_not public_reference.success?, "A public flow reference is not its browser nonce"
      assert_equal :session_mismatch, public_reference.status
      ["\xFF", "12345", "1234567", "123\0" + "45", "１２３４５６",
       "123456".encode(Encoding::UTF_16LE), 0, false, nil, "",].each do |submitted|
        result = verifier.call(
          **arguments, code: submitted, session_nonce: "malformed-code-browser",
        )

        assert_not result.success?
        assert_includes %i(blank_code invalid_code), result.status
        contact_unchanged = original_contact == contact.reload.attributes
        flow_unchanged = original_flow == flow.reload.attributes

        assert contact_unchanged, "Malformed input must preserve the Contact proof and failed-attempt state"
        assert flow_unchanged, "Malformed input must preserve the original flow"
        proof_unchanged = original_proof == issued.transaction.reload.attributes

        assert proof_unchanged, "Malformed input must preserve ceremony proof"
      end

      [nil, false, 0, "", "\xFF", "another-browser"].each do |nonce|
        denied = verifier.call(
          **arguments, code: valid_code, session_nonce: nonce,
        )

        assert_not denied.success?
        assert_equal :session_mismatch, denied.status
      end

      SignUpCycleLocator.new({}, surface: surface).issue!(
        flow_model.find(flow.id), nonce: "rotated-code-browser",
      )
      rotated = verifier.call(
        **arguments, code: valid_code, session_nonce: "malformed-code-browser",
      )

      assert_not rotated.success?
      assert_equal :session_mismatch, rotated.status
      contact_unchanged = original_contact == contact.reload.attributes

      assert contact_unchanged, "A rotated browser nonce must refuse the stale caller without changing proof"
      proof_unchanged = original_proof == issued.transaction.reload.attributes

      assert proof_unchanged, "Nonce rotation cannot rewrite the child proof"
    end
  end
end
