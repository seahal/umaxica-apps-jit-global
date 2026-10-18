# frozen_string_literal: true

require "test_helper"

class AuthenticationCredentialInventoryCommonIdentityTest < ActiveSupport::TestCase
  fixtures :client_statuses

  test "locked Email remains configured but cannot protect Passkey removal before its writer deadline" do
    %i(app com).each do |surface|
      actor = (surface == :app) ? Client.create!(id: 9_110_000_000_000) : Visitor.create!(id: 9_110_000_000_000)
      deadline = actor.class.database_now
      attributes = { address: "lock-boundary-#{SecureRandom.hex(8)}@example.com", step_up_otp_locked_until: deadline }
      email, passkey =
        if surface == :app
          email = actor.client_emails.create!(
            **attributes, user_email_status_id: ClientEmailStatus::VERIFIED,
                          binding_finalized_at: deadline,
          )
          [email,
           actor.client_passkeys.create!(
             webauthn_id: SecureRandom.uuid, public_key: "lock-boundary",
             uv_verified_at: deadline,
           ),]
        else
          email = actor.visitor_emails.create!(
            **attributes, visitor_email_status_id: VisitorEmailStatus::VERIFIED,
                          binding_finalized_at: deadline,
          )
          [email,
           actor.visitor_passkeys.create!(
             webauthn_id: SecureRandom.uuid, public_key: "lock-boundary",
             uv_verified_at: deadline,
           ),]
        end
      [-1, 0, 1].each do |microseconds|
        actor.class.stub(:database_now, deadline + Rational(microseconds, 1_000_000)) do
          inventory = AuthenticationCredentialInventory.call(actor, excluding: passkey)

          assert_includes inventory.step_up_methods, :email_otp
          assert_equal [:email], inventory.contact_identifiers
          assert_equal microseconds >= 0, inventory.has_usable_step_up_capability?
          assert_equal microseconds >= 0, AuthMethodGuard.can_remove_passkey?(actor, passkey)
        end
      end

      assert_equal deadline, email.reload.step_up_otp_locked_until
    end
  end

  test "APP and COM retained credentials are available before but not at or after writer expiry" do
    %i(app com).each do |surface|
      %i(passkey email telephone).each_with_index do |kind, kind_index|
        actor, model =
          if surface == :app
            [Client.create!(id: 9_108_000_000_000 + kind_index), Client]
          else
            [Visitor.create!(id: 9_108_000_000_000 + kind_index), Visitor]
          end
        deadline = model.database_now
        attributes = { created_at: deadline - 1.minute, discard_at: deadline, purge_eligible_at: deadline + 1.hour }
        if surface == :app
          case kind
          when :passkey
            actor.client_passkeys.create!(
              **attributes, webauthn_id: SecureRandom.uuid, public_key: "expiry-key",
                            uv_verified_at: deadline,
            )
          when :email
            actor.client_emails.create!(
              **attributes, address: "inventory-app-#{SecureRandom.hex(6)}@example.com",
                            user_email_status_id: ClientEmailStatus::VERIFIED, binding_finalized_at: deadline,
            )
          when :telephone
            actor.client_telephones.create!(
              **attributes, number: "+8190#{format("%08d", kind_index + 12_345_678)}",
                            user_identity_telephone_status_id: ClientTelephoneStatus::VERIFIED,
                            binding_finalized_at: deadline,
            )
          end
        else
          case kind
          when :passkey
            recovery = actor.visitor_emails.create!(
              created_at: deadline - 2.minutes,
              address: "inventory-com-#{SecureRandom.hex(6)}@example.com", visitor_email_status_id: VisitorEmailStatus::VERIFIED,
            )
            actor.visitor_passkeys.create!(
              **attributes, webauthn_id: SecureRandom.uuid, public_key: "expiry-key",
                            uv_verified_at: deadline,
            )
            recovery.update!(discard_at: deadline - 1.minute)
          when :email
            actor.visitor_emails.create!(
              **attributes, address: "inventory-com-#{SecureRandom.hex(6)}@example.com",
                            visitor_email_status_id: VisitorEmailStatus::VERIFIED, binding_finalized_at: deadline,
            )
          when :telephone
            actor.visitor_telephones.create!(
              **attributes, number: "+8190#{format("%08d", kind_index + 22_345_678)}",
                            visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
                            binding_finalized_at: deadline,
            )
          end
        end
        [-1, 0, 1].each do |microseconds|
          decision_time = deadline + Rational(microseconds, 1_000_000)
          inventory = model.stub(:database_now, decision_time) { AuthenticationCredentialInventory.call(actor) }
          available = microseconds < 0

          assert_equal available && kind != :telephone, inventory.has_usable_sign_in_capability?,
                       "#{surface} #{kind} #{microseconds}"
          assert_equal available && kind != :telephone, inventory.has_usable_step_up_capability?,
                       "#{surface} #{kind} #{microseconds}"
          assert_equal available && kind != :passkey, inventory.contact_identifiers.any?,
                       "#{surface} #{kind} #{microseconds}"
        end
      end
    end
  end

  test "uses active common social identities after the repository cutover" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, public_id: "n#{SecureRandom.hex(8)}")
    ClientExternalIdentity.create!(
      client: client,
      provider: "apple",
      issuer: "https://appleid.apple.com",
      subject: "common-inventory-#{SecureRandom.hex(8)}",
      audience: "apple-client-id",
      verification_authority: "test",
      verified_at: Time.current,
    )

    inventory = AuthenticationCredentialInventory.call(client)

    assert_equal [:apple], inventory.sign_in_methods
  end
end
