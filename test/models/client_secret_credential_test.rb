# frozen_string_literal: true

require "test_helper"

class ClientSecretCredentialTest < ActiveSupport::TestCase
  test "name accepts 254 and 255 characters and rejects 256 missing and empty values" do
    credential = client_secret_credentials(:one)
    [254, 255].each do |length|
      credential.name = "n" * length

      assert_predicate credential, :valid?
    end
    ["n" * 256, "", nil].each do |name|
      credential.name = name

      assert_predicate credential, :invalid?
      assert_predicate credential.errors[:name], :any?
    end
  end

  test "credential owner and public identity cannot change after persistence" do
    credential = client_secret_credentials(:one)
    owner_id = credential.client_id
    reference = credential.public_id

    assert_equal reference, credential.to_param
    assert_raises(ActiveRecord::ReadonlyAttributeError) { credential.update!(client_id: clients(:two).id) }
    assert_raises(ActiveRecord::ReadonlyAttributeError) { credential.update!(public_id: SecureRandom.base58(21)) }
    assert_equal owner_id, credential.reload.client_id
    assert_equal reference, credential.public_id
  end

  test "candidate validation requires owner issuance and stored digests" do
    credential = client_secret_credentials(:one).dup
    credential.client = nil

    assert_predicate credential, :invalid?
    assert_predicate credential.errors[:client], :any?
    credential.client = clients(:one)
    credential.issuance = nil

    assert_predicate credential, :invalid?
    assert_predicate credential.errors[:issuance], :any?
    credential.issuance = client_secret_credentials(:one).issuance
    [nil, ""].each do |digest|
      credential.password_digest = digest

      assert_predicate credential, :invalid?
      assert_predicate credential.errors[:password_digest], :any?
    end
  end

  test "withdrawal revocation rejects an active Client without state changes or audit" do
    credential = client_secret_credentials(:one)
    now = Client.database_now
    assert_no_difference "ClientSecretAuditOutbox.count" do
      assert_raises(ClientSecretCredential::InvalidTransition) do
        credential.commit_withdrawal_revocation!(at: now, purge_at: now + 1.day)
      end
    end
    assert_nil credential.reload.revoked_at
    assert_equal Float::INFINITY, credential.discard_at
  end

  test "forced withdrawal revocation bypasses voluntary capability preservation" do
    credential = client_secret_credentials(:one)
    actor = credential.client
    actor.client_external_identities.delete_all
    actor.client_emails.delete_all
    actor.client_telephones.delete_all
    actor.client_passkeys.delete_all
    actor.client_totp_credentials.delete_all
    ClientSecretCredential.where(client_id: actor.id).where.not(id: credential.id).delete_all
    telephone = ClientTelephone.create!(
      user: actor,
      number: "+8190#{SecureRandom.random_number(10_000_000).to_s.rjust(7, "0")}",
      user_identity_telephone_status_id: ClientTelephoneStatus::VERIFIED,
      binding_finalized_at: ClientTelephone.database_now,
    )
    now = Client.database_now

    assert_equal [:secret], AuthenticationCredentialInventory.call(actor).usable_sign_in_capabilities
    assert_equal [:telephone], AuthenticationCredentialInventory.call(actor).contact_identifiers
    assert_not AuthMethodGuard.can_remove_secret_credential?(actor, credential)

    actor.update!(withdrawn_at: now, terminated_at: now)
    credential.commit_withdrawal_revocation!(at: now, purge_at: now + 1.day)

    assert credential.reload.revoked_at
    assert_kind_of Time, credential.discard_at
    assert_equal actor.id, telephone.reload.user_id
  end

  test "withdrawal retention rejects non-time and unordered boundaries before writing audit" do
    credential = client_secret_credentials(:one)
    now = Client.database_now
    credential.client.update!(withdrawn_at: now, terminated_at: now)
    invalid = [nil, "", 0, 1, [], {}, Float::INFINITY]
    boundaries = invalid.map { |value| [value, now + 1.day] } +
      invalid.map { |value| [now, value] } + [[now, now - 0.000001.seconds], [now, now]]

    boundaries.each do |at, purge_at|
      assert_no_difference "ClientSecretAuditOutbox.count" do
        assert_raises(ClientSecretCredential::InvalidTransition) do
          credential.commit_withdrawal_revocation!(at: at, purge_at: purge_at)
        end
      end
    end
    assert_nil credential.reload.revoked_at
    assert_equal Float::INFINITY, credential.discard_at
  end
end
