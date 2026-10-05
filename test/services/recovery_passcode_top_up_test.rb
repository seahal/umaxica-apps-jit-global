# frozen_string_literal: true

require "test_helper"

class RecoveryPasscodeTopUpTest < ActiveSupport::TestCase
  test "app Secret is refused by the retired recovery top-up contract without issuance" do
    actor = clients(:one)
    assert_no_difference("ClientSecretCredential.count") do
      assert_no_difference("ClientSecretIssuance.count") do
        assert_raises(ArgumentError) do
          RecoveryPasscodeTopUp.call(actor: actor, credential_class: ClientSecretCredential)
        end
        assert_raises(ArgumentError) do
          SignRecoveryPasscodeRequirement.usable_unused_count(actor: actor, credential_class: ClientSecretCredential)
        end
      end
    end
  end

  test "com retains ten recovery credentials and repeat top-up issues none" do
    VisitorSecretCredentialKind.find_or_create_by!(id: VisitorSecretCredentialKind::RECOVERY)
    VisitorSecretCredentialStatus.find_or_create_by!(id: VisitorSecretCredentialStatus::ACTIVE)
    actor = visitors(:reserved_visitor)
    address = "com-top-up@example.com"
    actor.visitor_emails.create!(
      address: address, address_digest: IdentifierBlindIndex.bidx_for_email(address),
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
      otp_private_key: SecureRandom.base64(24), otp_counter: "", otp_attempts_count: 0,
    )
    now = VisitorSecretCredential.database_now
    before = SignRecoveryPasscodeRequirement.usable_unused_count(
      actor: actor, credential_class: VisitorSecretCredential, now: now,
    )
    result = RecoveryPasscodeTopUp.call(actor: actor, credential_class: VisitorSecretCredential, now: now)

    assert_equal 10, result.target_count
    assert_equal before, result.active_usable_count_before
    assert_equal 10 - before, result.issued_count
    assert_equal 10, result.active_usable_count_after
    assert_equal result.issued_count, result.new_credentials.length
    assert_equal result.issued_count, result.raw_values.length
    result.new_credentials.zip(result.raw_values).each do |credential, raw|
      assert_equal actor.id, credential.visitor_id
      assert_equal VisitorSecretCredentialKind::RECOVERY, credential.visitor_secret_credential_kind_id
      assert_equal VisitorSecretCredentialStatus::ACTIVE, credential.visitor_secret_credential_status_id
      assert_equal 1, credential.uses_remaining
      assert_equal 32, raw.length
      assert credential.reload.authenticate(raw)
      assert_not_includes credential.attributes.values, raw
    end
    replay = RecoveryPasscodeTopUp.call(actor: actor, credential_class: VisitorSecretCredential, now: now)

    assert_equal 0, replay.issued_count
    assert_equal 10, replay.active_usable_count_before
    assert_equal 10, replay.active_usable_count_after
    assert_empty replay.new_credentials
    assert_empty replay.raw_values
  end

  test "org without a recovery kind retains its empty top-up result" do
    result = RecoveryPasscodeTopUp.call(actor: operators(:one), credential_class: OperatorSecretCredential)

    assert_equal 0, result.issued_count
    assert_equal 0, result.active_usable_count_before
    assert_equal 0, result.active_usable_count_after
    assert_empty result.new_credentials
    assert_empty result.raw_values
  end
end
