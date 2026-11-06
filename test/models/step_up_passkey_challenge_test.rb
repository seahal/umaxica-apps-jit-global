# frozen_string_literal: true

require "test_helper"

class StepUpPasskeyChallengeTest < ActiveSupport::TestCase
  fixtures :clients, :client_statuses

  test "challenge expiry rejects at and after the deadline and accepts one microsecond before" do
    actor = clients(:one)
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    transaction = ClientStepUpCeremonyTransaction.create_transaction!(
      actor_ref: actor.public_id, session_ref: token.public_id, required_scope: "settings_birthdate",
      required_aal: "none", allowed_methods: ["passkey"], return_to: "/identity/birthdate",
    )
    record = ClientStepUpSession.create!(
      user_token: token, step_up_ceremony_transaction_ref: transaction.transaction_id,
      scope: transaction.required_scope, return_to: transaction.return_to,
      status: "PENDING", discard_at: transaction.expires_at,
    )
    reference = record.issue_bound_passkey_challenge!(
      transaction: transaction, challenge: "public", rp_id: "app.example", origin: "https://app.example",
    )

    [nil, "", 0, "\0", "another-reference"].each do |invalid_reference|
      assert_raises(StepUpSessionConsumable::ChallengeError) do
        record.consume_bound_passkey_challenge!(
          transaction: transaction, reference: invalid_reference, rp_id: "app.example", origin: "https://app.example",
        )
      end
    end
    assert_nil record.reload.passkey_challenge_consumed_at

    [-1, 0, 1].each do |offset|
      record.update!(passkey_challenge_consumed_at: nil)
      # Substitute only the writer clock so PostgreSQL's microsecond boundary can be reached exactly.
      ClientStepUpCeremonyTransaction.stub(
        :database_now, record.passkey_challenge_expires_at + Rational(offset, 1_000_000),
      ) do
        if offset.negative?
          assert_equal "public", record.consume_bound_passkey_challenge!(
            transaction: transaction, reference: reference, rp_id: "app.example", origin: "https://app.example",
          )
        else
          assert_raises(StepUpSessionConsumable::ChallengeError) do
            record.consume_bound_passkey_challenge!(
              transaction: transaction, reference: reference, rp_id: "app.example", origin: "https://app.example",
            )
          end
        end
      end

      assert_not_nil record.reload.passkey_challenge_consumed_at
    end
  end

  test "a challenge is bound to the concrete transaction and consumed once" do
    actor = clients(:one)
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    actor.client_passkeys.create!(webauthn_id: SecureRandom.uuid, public_key: "public", sign_count: 0)
    client = OidcClientRegistry.find!("core-app-jp")
    now = OpBaseAppRecord.database_now
    grant = OpAppGrant.create!(
      authentication_epoch: token.authentication_epoch, client_token: token, oidc_client_id: client.client_id,
      oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: now - 1.hour, refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(expires_at: now + 1.hour, now:)
    params = {
      response_type: "code",
      client_id: client.client_id,
      redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
      scope: grant.oidc_scope,
      state: SecureRandom.urlsafe_base64(32),
      nonce: SecureRandom.urlsafe_base64(32),
      code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest("step-up-passkey-challenge"), padding: false),
      code_challenge_method: "S256",
      prompt: "login",
      claims: OidcAuthorizeRequestResolver::STEP_UP_CLAIMS,
    }
    validated_request = OidcAuthorizeRequestResolver.call(params:, resource: actor, resource_type: "client")
    issuance = OidcStepUpAuthorizationIssuer.call!(
      surface: "app", actor:, token:, client:, params:, validated_request:,
    )
    transaction = issuance.ticket
    record = ClientStepUpSession.find_by!(step_up_ceremony_transaction_ref: transaction.transaction_id)
    reference = record.issue_bound_passkey_challenge!(
      transaction:, challenge: "public-challenge", rp_id: "app.example",
      origin: "https://app.example",
    )

    assert_equal "public-challenge", record.consume_bound_passkey_challenge!(
      transaction:, reference:, rp_id: "app.example", origin: "https://app.example",
    )
    assert_raises(StepUpSessionConsumable::ChallengeError) do
      record.consume_bound_passkey_challenge!(
        transaction:, reference:, rp_id: "app.example", origin: "https://app.example",
      )
    end
    assert_equal issuance.context.public_id, transaction.resource_ref
    assert_not_nil record.reload.passkey_challenge_consumed_at
    assert_equal 0, record.attempt_count
  end

  test "a generated challenge reference retries the named unique index collision" do
    actor = clients(:one)
    first_token = ClientToken.create!(authentication_epoch: 0, user: actor)
    first_transaction = ClientStepUpCeremonyTransaction.create_transaction!(
      actor_ref: actor.public_id, session_ref: first_token.public_id, required_scope: "settings_birthdate",
      required_aal: "none", allowed_methods: ["passkey"], return_to: "/identity/birthdate",
    )
    first_record = ClientStepUpSession.create!(
      user_token: first_token, step_up_ceremony_transaction_ref: first_transaction.transaction_id,
      scope: first_transaction.required_scope, return_to: first_transaction.return_to,
      status: "PENDING", discard_at: first_transaction.expires_at,
    )
    collision = first_record.issue_bound_passkey_challenge!(
      transaction: first_transaction, challenge: "first", rp_id: "app.example", origin: "https://app.example",
    )

    second_token = ClientToken.create!(authentication_epoch: 0, user: actor)
    second_transaction = ClientStepUpCeremonyTransaction.create_transaction!(
      actor_ref: actor.public_id, session_ref: second_token.public_id, required_scope: "settings_birthdate",
      required_aal: "none", allowed_methods: ["passkey"], return_to: "/identity/birthdate",
    )
    second_record = ClientStepUpSession.create!(
      user_token: second_token, step_up_ceremony_transaction_ref: second_transaction.transaction_id,
      scope: second_transaction.required_scope, return_to: second_transaction.return_to,
      status: "PENDING", discard_at: second_transaction.expires_at,
    )
    replacement = "b" * 21
    generated = [collision, replacement]

    result =
      PublicId.stub(:generate, -> { generated.shift }) do
        second_record.issue_bound_passkey_challenge!(
          transaction: second_transaction, challenge: "second", rp_id: "app.example", origin: "https://app.example",
        )
      end

    assert_equal replacement, result
    assert_equal replacement, second_record.reload.passkey_challenge_ref
    assert_equal collision, first_record.reload.passkey_challenge_ref
  end

  test "a matching challenge reference is burned on origin mismatch and its deadline is not extended" do
    actor = clients(:one)
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    transaction = ClientStepUpCeremonyTransaction.create_transaction!(
      actor_ref: actor.public_id, session_ref: token.public_id, required_scope: "settings_birthdate",
      required_aal: "none", allowed_methods: ["passkey"], return_to: "/identity/birthdate",
    )
    record = ClientStepUpSession.create!(
      user_token: token, step_up_ceremony_transaction_ref: transaction.transaction_id,
      scope: transaction.required_scope, return_to: transaction.return_to,
      status: "PENDING", discard_at: transaction.expires_at, attempt_count: 3,
    )
    first = record.issue_bound_passkey_challenge!(
      transaction: transaction, challenge: "first", rp_id: "app.example", origin: "https://app.example",
    )
    deadline = record.passkey_challenge_expires_at
    second = record.issue_bound_passkey_challenge!(
      transaction: transaction, challenge: "second", rp_id: "app.example", origin: "https://app.example",
    )

    assert_not_equal first, second
    assert_equal deadline, record.reload.passkey_challenge_expires_at
    assert_equal 3, record.attempt_count
    assert_raises(StepUpSessionConsumable::ChallengeError) do
      record.consume_bound_passkey_challenge!(
        transaction: transaction, reference: second, rp_id: "app.example", origin: "https://other.example",
      )
    end
    assert_not_nil record.reload.passkey_challenge_consumed_at
    assert_raises(StepUpSessionConsumable::ChallengeError) do
      record.consume_bound_passkey_challenge!(
        transaction: transaction, reference: second, rp_id: "app.example", origin: "https://app.example",
      )
    end
  end
end
