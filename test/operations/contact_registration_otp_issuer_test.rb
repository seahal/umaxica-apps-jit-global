# frozen_string_literal: true

require "test_helper"

# Boolean assertions prevent disclosure of code and binding material.
class ContactRegistrationOtpIssuerTest < ActiveSupport::TestCase
  test "registration OTP issuance refuses a token rebound after it was read" do
    %i(email telephone).each do |channel|
      actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
      token = ClientToken.create!(authentication_epoch: 0, user: actor, discard_at: 1.day.from_now)
      token.rotate_refresh_token!
      contact =
        if channel == :email
          actor.client_emails.create!(raw_address: "issuance-#{SecureRandom.hex(8)}@example.test", confirm_policy: "1")
        else
          actor.client_telephones.create!(
            raw_number: "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}",
            confirm_policy: "1", confirm_using_mfa: "1",
          )
        end
      issuer, flow_model, source =
        if channel == :email
          [EmailCredentialRegistrationOtpIssuer, ClientEmailCeremonyTransaction, { email: contact }]
        else
          [TelephoneCredentialRegistrationOtpIssuer, ClientTelephoneCeremonyTransaction, { telephone: contact }]
        end
      stale_token = ClientToken.find(token.id)
      replacement = ClientToken.create!(authentication_epoch: 0, user: actor)
      new_device = replacement.device_session_record!
      ClientToken.find(token.id).update!(device_session_id: new_device.id)
      new_device.update!(current_refresh_token_id: token.id)
      before = contact.reload.attributes

      assert_no_difference -> { flow_model.count } do
        result = issuer.call(actor: actor, token: stale_token, browser_nonce: SecureRandom.urlsafe_base64(32), **source)

        assert_equal :unavailable, result.status
      end
      assert_equal before, contact.reload.attributes
    end
  end

  %w(app).each do |surface|
    %i(email telephone).each do |channel|
      test "#{surface} #{channel} issuance persists the original ceremony browser root and candidate facts" do
        actor, token, contact, flow_model =
          case [surface, channel]
          when ["app", :email], ["app", :telephone]
            owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
            root = ClientToken.create!(authentication_epoch: 0, user: owner, discard_at: 1.day.from_now)
            candidate =
              if channel == :email
                owner.client_emails.create!(
                  raw_address: "registration-#{SecureRandom.hex(8)}@example.test", confirm_policy: "1",
                )
              else
                owner.client_telephones.create!(
                  raw_number: "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}",
                  confirm_policy: "1", confirm_using_mfa: "1",
                )
              end
            [owner, root, candidate, (channel == :email) ? ClientEmailCeremonyTransaction :
              ClientTelephoneCeremonyTransaction,]
          end
        token.rotate_refresh_token!
        nonce = SecureRandom.urlsafe_base64(32)
        issued =
          case channel
          when :email
            EmailCredentialRegistrationOtpIssuer.call(actor:, token:, email: contact, browser_nonce: nonce)
          when :telephone
            TelephoneCredentialRegistrationOtpIssuer.call(actor:, token:, telephone: contact, browser_nonce: nonce)
          end

        assert_predicate issued, :success?
        transaction = issued.transaction
        source = contact.reload.attributes
        expected_session = CredentialRegistrationOtpSessionValue.for(
          surface:, channel:, transaction_ref: transaction.transaction_id, root_ref: token.public_id,
          browser_nonce: nonce,
        ).dump

        assert_instance_of flow_model, transaction
        assert_equal surface, transaction.surface
        assert_equal "credential_registration", transaction.purpose
        assert_equal "registration", transaction.operation
        assert_match(/\A[A-Za-z0-9_-]{21}\z/, transaction.transaction_id)
        assert_withheld("Issuance must bind the original browser and Root") {
          transaction.session_ref == expected_session
        }
        assert_withheld { transaction.actor_ref == actor.public_id }
        candidate_ref = (channel == :email) ? transaction.email_candidate_ref : transaction.telephone_candidate_ref
        candidate_digest =
          (channel == :email) ? transaction.normalized_email_digest : transaction.normalized_number_digest
        source_digest = (channel == :email) ? contact.address_digest : contact.number_digest

        assert_withheld { candidate_ref == contact.public_id }
        assert_withheld { candidate_digest == source_digest }
        assert_match(
          /\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/,
          transaction.otp_generation,
        )
        assert_match(/\A[0-9]{6}\z/, issued.code)
        assert_match(/\A[0-9a-f]{64}\z/, transaction.otp_verifier)
        assert_nil transaction.otp_consumed_at
        assert_nil transaction.otp_receipt_verifier
        assert_nil transaction.otp_result_expires_at
        assert_nil transaction.otp_cancelled_at
        assert_not_predicate contact, :binding_effective?
        assert_operator transaction.otp_expires_at, :<=, transaction.expires_at
        destination = (channel == :email) ? contact.address : contact.number
        guard, arguments =
          case channel
          when :email
            [EmailCredentialRegistrationOtpDeliveryGuard, { email: contact }]
          when :telephone
            [TelephoneCredentialRegistrationOtpDeliveryGuard, { telephone: contact }]
          end
        delivered = false

        assert guard.call(
          transaction:, generation: transaction.otp_generation, destination:, code: issued.code, **arguments,
        ) { delivered = true }
        assert delivered
        wrong_code = (issued.code == "000000") ? "000001" : "000000"

        assert_not guard.call(
          transaction:, generation: transaction.otp_generation, destination:, code: wrong_code, **arguments,
        ) { flunk("Wrong code must not reach transport") }
        assert_withheld { source == contact.reload.attributes }
      end
    end
  end
end
