# frozen_string_literal: true

require "test_helper"

class ContactRegistrationOtpIssuerTest < ActiveSupport::TestCase
  %w(app com).each do |surface|
    %i(email telephone).each do |channel|
      test "#{surface} #{channel} issuance persists the original ceremony browser root and candidate facts" do
        actor, token, contact, flow_model =
          case [surface, channel]
          when ["app", :email], ["app", :telephone]
            owner = Client.create!(status_id: ClientStatus::ACTIVE)
            root = ClientToken.create!(user: owner, discard_at: 1.day.from_now)
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
          when ["com", :email], ["com", :telephone]
            owner = Visitor.create!
            root = VisitorToken.create!(visitor: owner, discard_at: 1.day.from_now)
            candidate =
              if channel == :email
                owner.visitor_emails.create!(
                  raw_address: "registration-#{SecureRandom.hex(8)}@example.test", confirm_policy: "1",
                )
              else
                owner.visitor_telephones.create!(
                  raw_number: "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}",
                  confirm_policy: "1", confirm_using_mfa: "1",
                )
              end
            [owner, root, candidate, (channel == :email) ? VisitorEmailCeremonyTransaction :
              VisitorTelephoneCeremonyTransaction,]
          end
        token.rotate_refresh_token!
        secret = ROTP::Base32.random_base32
        contact.store_otp(secret, 1, (contact.class.database_now + 10.minutes).to_i)
        code = ROTP::HOTP.new(secret).at(1).to_s
        nonce = SecureRandom.urlsafe_base64(32)
        transaction = ContactRegistrationOtpIssuer.call!(
          actor: actor, token: token, contact: contact, channel: channel,
          browser_nonce: nonce, code: code,
        )
        context = contact.reload.credential_registration_otp_context

        assert_instance_of flow_model, transaction
        assert_equal surface, context.fetch("surface")
        assert_equal "credential_registration", context.fetch("purpose")
        assert_equal transaction.transaction_id, context.fetch("flow_ref")
        assert_equal AuthAdmissionBinding.browser_digest(
          surface: surface, entry_ref: transaction.transaction_id,
          nonce: nonce,
        ), context.fetch("browser_digest")
        assert_equal token.public_id, context.fetch("session_ref")
        assert_equal actor.public_id, context.fetch("owner_ref")
        assert_equal contact.public_id, context.fetch("contact_ref")
        assert_equal "1", context.fetch("counter")
        assert_nil context.fetch("verified_at")
        assert_nil context.fetch("result_expires_at")
        assert_predicate contact, :otp_active?
        assert_not contact.binding_effective?
        assert_equal CredentialRegistrationOtpCodeDigest.for(context: context, channel: channel, code: code),
                     context.fetch("code_digest")
        assert_operator Time.iso8601(context.fetch("expires_at")), :<=, transaction.expires_at
      end
    end
  end
end
