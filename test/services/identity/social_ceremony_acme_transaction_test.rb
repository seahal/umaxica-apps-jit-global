# typed: false
# frozen_string_literal: true

require "test_helper"
require "support/external_identity_test_helper"
# require "helpers/global_test_support"

class IdentitySocialCeremonyAcmeTransactionTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers
  include ExternalIdentityTestHelper

  fixtures :clients, :client_statuses, :client_chronicle_events, :client_chronicle_levels

  setup do
    @now = Time.zone.parse("2026-06-03 12:00:00")
    @client = clients(:one)
    @client.client_external_identities.where(provider: "google").destroy_all
    @session_ref = "session-#{SecureRandom.hex(4)}"
  end

  teardown do
    travel_back
  end

  test "grant issuance creates durable transaction and valid grant" do
    travel_to @now do
      issuance = issue_grant
      grant = IdentitySocialCeremonyGrant.decode(
        issuance.grant,
        issuer_id: IdentitySocialCeremonyContract.acme_issuer_id("app"),
        now: @now,
      )

      assert_equal issuance.transaction.transaction_id, grant["transaction_id"]
      assert_equal issuance.transaction.grant_jti, grant["jti"]
      assert_equal @client.public_id, grant["actor_ref"]
      assert_equal @session_ref, grant["session_ref"]
      assert_equal "google", grant["provider"]
    end
  end

  test "valid result consumes once and commits social link under acme authority" do
    travel_to @now do
      issuance = issue_grant
      result_token = issue_result(issuance.grant)

      assert_difference -> { @client.client_external_identities.where(provider: "google").count }, 1 do
        commit = IdentitySocialCeremonyFinalCommitter.call!(
          result_token: result_token,
          actor: @client,
          session_ref: @session_ref,
          surface: "app",
          ip_address: "127.0.0.1",
          user_agent: "Rails test",
          now: @now,
        )

        assert_equal "google", commit.identity.provider
        assert_equal auth_hash["uid"], commit.identity.uid
      end

      assert_predicate issuance.transaction.reload, :consumed?
      assert_raises(IdentitySocialCeremonyContract::Error) do
        IdentitySocialCeremonyFinalCommitter.call!(
          result_token: result_token,
          actor: @client,
          session_ref: @session_ref,
          surface: "app",
          ip_address: "127.0.0.1",
          user_agent: "Rails test",
          now: @now,
        )
      end
    end
  end

  test "signup result commits a new client even when another provider shares the same email" do
    travel_to @now do
      existing_user = Client.create!(
        status_id: ClientStatus::VERIFIED_WITH_SIGN_UP,
        visibility_id: ClientVisibility::USER,
        birthdate: "2000-01-01",
      )
      ClientEmailStatus.ensure_defaults!
      ClientEmail.create!(
        user: existing_user,
        address: "shared-email@example.com",
        address_digest: Digest::SHA256.hexdigest("shared-email@example.com"),
        user_email_status_id: ClientEmailStatus::VERIFIED,
        public_id: SecureRandom.alphanumeric(21),
      )
      create_active_external_identity(client: existing_user, provider: "apple", subject: "apple-shared-email-uid")

      signup_auth_hash = {
        "provider" => "google",
        "uid" => "google-signup-shared-email-#{SecureRandom.hex(6)}",
        "credentials" => {
          "token" => "signup-provider-access-token",
          "refresh_token" => "signup-provider-refresh-token",
          "expires_at" => 1.hour.from_now.to_i,
        },
        "info" => {
          "email" => "shared-email@example.com",
        },
        "extra" => {
          "raw_info" => {
            "email_verified" => true,
          },
        },
      }
      issuance = issue_signup_grant
      result_token = issue_signup_result(issuance.grant, auth_hash: signup_auth_hash, birthdate: "2000-02-03")

      assert_difference -> { Client.count }, 1 do
        commit = IdentitySocialCeremonyFinalCommitter.call!(
          result_token: result_token,
          actor: nil,
          session_ref: @session_ref,
          surface: "app",
          ip_address: "127.0.0.1",
          user_agent: "Rails test",
          now: @now,
        )

        assert_equal "google", commit.identity.provider
        assert_equal signup_auth_hash["uid"], commit.identity.uid
        assert_not_equal existing_user.id, commit.user.id
        assert_equal 1, existing_user.client_emails.count
        assert_equal "shared-email@example.com", existing_user.client_emails.first.address
      end
    end
  end

  test "google signup result rejects thirteen-to-fifteen year old birthdate" do
    assert_social_signup_rejects_under_sixteen(provider: "google")
  end

  test "apple signup result rejects thirteen-to-fifteen year old birthdate" do
    assert_social_signup_rejects_under_sixteen(provider: "apple")
  end

  test "signup result rejects a provider uid already linked to another client" do
    travel_to @now do
      owner = Client.create!(
        status_id: ClientStatus::VERIFIED_WITH_SIGN_UP,
        visibility_id: ClientVisibility::USER,
        birthdate: "2000-01-01",
      )
      create_active_external_identity(client: owner, provider: "google", subject: "google-conflict-uid")

      issuance = issue_signup_grant
      result_token = issue_signup_result(
        issuance.grant,
        auth_hash: auth_hash.merge("uid" => "google-conflict-uid"),
        birthdate: "2000-02-03",
      )

      error =
        assert_raises(SocialAuth::ProviderError) do
          IdentitySocialCeremonyFinalCommitter.call!(
            result_token: result_token,
            actor: nil,
            session_ref: @session_ref,
            surface: "app",
            ip_address: "127.0.0.1",
            user_agent: "Rails test",
            now: @now,
          )
        end

      assert_equal "errors.social_auth.identity_conflict", error.i18n_key
      assert_equal 1, ClientExternalIdentity.where(provider: "google", subject: "google-conflict-uid").count
    end
  end

  test "result payload and transaction table do not expose provider tokens" do
    travel_to @now do
      issuance = issue_grant
      result_token = issue_result(issuance.grant)
      payload = IdentitySocialCeremonyContract.decode_untrusted_routing_payload(result_token)

      assert_not_includes payload.to_json, auth_hash["credentials"]["token"]
      assert_not_includes payload.to_json, auth_hash["credentials"]["refresh_token"]
      assert_not payload.key?("token")
      assert_not payload.key?("access_token")
      assert_not payload.key?("refresh_token")
      assert_not payload.key?("id_token")
    end

    forbidden_columns = %w(
      access_token id_token refresh_token session_token token raw_email provider_token provider_refresh_token
    )

    assert_empty ClientSocialCeremonyTransaction.column_names & forbidden_columns
  end

  test "replay store rejects invalid surface" do
    assert_raises(IdentitySocialCeremonyContract::Error) do
      IdentitySocialCeremonyReplayStore.for("invalid-surface")
    end
  end

  test "replay store raises error on missing transaction" do
    store = IdentitySocialCeremonyReplayStore.for("app")
    assert_raises(IdentitySocialCeremonyContract::Error) do
      store.find_transaction!("non-existent-id")
    end
  end

  test "wrong actor and session are rejected before link commit" do
    travel_to @now do
      issuance = issue_grant
      result_token = issue_result(issuance.grant)

      assert_no_difference("ClientToken.count") do
        assert_no_difference("VisitorToken.count") do
          assert_no_difference("OperatorToken.count") do
            assert_raises(IdentitySocialCeremonyContract::Error) do
              IdentitySocialCeremonyFinalCommitter.call!(
                result_token: result_token,
                actor: clients(:two),
                session_ref: @session_ref,
                surface: "app",
                now: @now,
              )
            end
            assert_raises(IdentitySocialCeremonyContract::Error) do
              IdentitySocialCeremonyFinalCommitter.call!(
                result_token: result_token,
                actor: @client,
                session_ref: "wrong-session",
                surface: "app",
                now: @now,
              )
            end
          end
        end
      end

      assert_nil ClientExternalIdentity.find_by(provider: "google", subject: auth_hash["uid"])
    end
  end

  test "a result is refused without a session, on another surface, or after its transaction expired" do
    travel_to @now do
      issuance = issue_grant
      result_token = issue_result(issuance.grant)
      refusals = {
        "session_ref is required" => { session_ref: "", surface: "app", now: @now },
      }

      refusals.each do |message, args|
        error =
          assert_raises(IdentitySocialCeremonyContract::Error, message) do
            IdentitySocialCeremonyFinalCommitter.call!(result_token: result_token, actor: @client, **args)
          end

        assert_equal message, error.message
      end
      # An expired result is refused (its own exp lapses no later than the transaction), and a result
      # minted for the app surface cannot even be verified under the com issuer's keys.
      assert_raises(IdentitySocialCeremonyContract::Error) do
        IdentitySocialCeremonyFinalCommitter.call!(
          result_token: result_token, actor: @client, session_ref: @session_ref, surface: "app", now: @now + 1.day,
        )
      end
      assert_raises(IdentitySocialCeremonyContract::Error) do
        IdentitySocialCeremonyFinalCommitter.call!(
          result_token: result_token, actor: @client, session_ref: @session_ref, surface: "com", now: @now,
        )
      end

      assert_not_predicate issuance.transaction.reload, :consumed?
      assert_nil ClientExternalIdentity.find_by(provider: "google", subject: auth_hash["uid"])
    end
  end

  test "purger removes only retained expired and consumed transactions" do
    travel_to @now do
      active = issue_grant.transaction
      expired_old = IdentitySocialCeremonyReplayStore.for("app").create_transaction!(
        surface: "app",
        actor_ref: @client.public_id,
        session_ref: "#{@session_ref}-old-expired",
        operation: "link",
        provider: "google",
        expires_at: @now - 8.days,
        now: @now - 9.days,
      )
      consumed_old = IdentitySocialCeremonyReplayStore.for("app").create_transaction!(
        surface: "app",
        actor_ref: @client.public_id,
        session_ref: "#{@session_ref}-old-consumed",
        operation: "link",
        provider: "google",
        expires_at: @now + 1.hour,
        now: @now - 9.days,
      )
      consumed_old.update!(
        status: SocialCeremonyTransactionable::STATUS_CONSUMED, result_jti: SecureRandom.uuid,
        consumed_at: @now - 8.days,
      )

      counts = IdentitySocialCeremonyTransactionPurger.new(now: @now).call

      assert_equal 2, counts.fetch("app")
      assert ClientSocialCeremonyTransaction.exists?(active.id)
      assert_not ClientSocialCeremonyTransaction.exists?(expired_old.id)
      assert_not ClientSocialCeremonyTransaction.exists?(consumed_old.id)
    end
  end

  # Invariant: the untrusted routing payload is attacker-controlled, but the
  # verified ceremony path is the only thing that can authorize a commit.
  test "tampering the untrusted payload cannot commit a social link without a valid verified result" do
    travel_to @now do
      issuance = issue_grant
      result_token = issue_result(issuance.grant)

      # Forge a token: keep the original (valid) signature but rewrite the
      # payload claims an attacker would want to control.
      tampered = tamper_payload(
        result_token,
        "operation" => "login",
        "session_ref" => "attacker-session",
        "actor_ref" => clients(:two).public_id,
      )

      # Untrusted decode reflects the attacker's claims (by design: it is untrusted).
      forged = IdentitySocialCeremonyContract.decode_untrusted_routing_payload(tampered)

      assert_equal "login", forged["operation"]
      assert_equal "attacker-session", forged["session_ref"]

      # The verified path rejects the forged token: signature no longer matches.
      assert_raises(IdentitySocialCeremonyContract::Error) do
        IdentitySocialCeremonyFinalCommitter.call!(
          result_token: tampered,
          actor: @client,
          session_ref: @session_ref,
          surface: "app",
          now: @now,
        )
      end

      assert_nil ClientExternalIdentity.find_by(provider: "google", subject: auth_hash["uid"])
      assert_not_predicate issuance.transaction.reload, :consumed?
    end
  end

  test "untrusted operation cannot route a verified link token into a login commit" do
    travel_to @now do
      issuance = issue_grant
      # Genuine, untampered link result token.
      result_token = issue_result(issuance.grant)

      # The acme login path passes actor: nil. Even though an attacker could flip
      # the UNVERIFIED operation to "login" to slip past the controller's link
      # rejection, the committer derives operation from the VERIFIED result
      # ("link") and rejects because a link requires an actor.
      error =
        assert_raises(IdentitySocialCeremonyContract::Error) do
          IdentitySocialCeremonyFinalCommitter.call!(
            result_token: result_token,
            actor: nil,
            session_ref: @session_ref,
            surface: "app",
            now: @now,
          )
        end

      assert_equal "actor is required", error.message
      assert_nil ClientExternalIdentity.find_by(provider: "google", subject: auth_hash["uid"])
      assert_not_predicate issuance.transaction.reload, :consumed?
    end
  end

  private

  # Rewrites the payload segment of a JWS while leaving the original signature in
  # place, simulating an attacker tampering with claims they cannot re-sign.
  def tamper_payload(token, overrides)
    header_b64, payload_b64, signature_b64 = token.split(".")
    payload = JSON.parse(url_b64_decode(payload_b64)).merge(overrides)
    [header_b64, url_b64_encode(payload.to_json), signature_b64].join(".")
  end

  def url_b64_decode(segment)
    Base64.urlsafe_decode64(segment + ("=" * ((4 - (segment.length % 4)) % 4)))
  end

  def url_b64_encode(bytes)
    Base64.urlsafe_encode64(bytes, padding: false)
  end

  def issue_grant
    IdentitySocialCeremonyGrantIssuer.issue!(
      surface: "app",
      actor_ref: @client.public_id,
      session_ref: @session_ref,
      operation: "link",
      provider: "google",
      now: @now,
    )
  end

  def assert_social_signup_rejects_under_sixteen(provider:)
    travel_to(@now) do
      signup_auth_hash = auth_hash(provider: provider)
      issuance = issue_signup_grant(provider: provider)
      result_token = issue_signup_result(
        issuance.grant,
        auth_hash: signup_auth_hash,
        birthdate: "2010-06-26",
      )

      assert_no_difference -> { Client.count } do
        error =
          assert_raises(IdentitySocialCeremonyContract::Error) do
            IdentitySocialCeremonyFinalCommitter.call!(
              result_token: result_token,
              actor: nil,
              session_ref: @session_ref,
              surface: "app",
              ip_address: "127.0.0.1",
              user_agent: "Rails test",
              now: @now,
            )
          end

        assert_equal "birthdate is ineligible", error.message
      end
    end
  end

  def issue_signup_grant(provider: "google")
    IdentitySocialCeremonyGrantIssuer.issue!(
      surface: "app",
      actor_ref: @client.public_id,
      session_ref: @session_ref,
      operation: "signup",
      provider: provider,
      now: @now,
    )
  end

  def issue_result(grant_token)
    provider_auth = auth_hash
    callback_result = ExternalAuthentication::CallbackResult.verified(
      principal: ExternalAuthentication::VerifiedPrincipal.new(
        provider: provider_auth.fetch("provider"),
        subject: provider_auth.fetch("uid"),
        issuer: "https://accounts.google.com",
        audience: "google-client-id",
        verified_at: @now,
        verification_authority: "omniauth-google-oauth2/contract",
      ),
      credential_candidate: nil,
    )
    IdentitySocialCeremonyResultIssuer.issue!(
      grant_token: grant_token,
      callback_result: callback_result,
      surface: "app",
      actor_ref: @client.public_id,
      session_ref: @session_ref,
      operation: "link",
      now: @now,
    )
  end

  def issue_signup_result(grant_token, auth_hash:, birthdate:)
    provider = auth_hash.fetch("provider")
    callback_result = ExternalAuthentication::CallbackResult.verified(
      principal: ExternalAuthentication::VerifiedPrincipal.new(
        provider: provider,
        subject: auth_hash.fetch("uid"),
        issuer: ((provider == "apple") ? "https://appleid.apple.com" : "https://accounts.google.com"),
        audience: "#{provider}-client-id",
        verified_at: @now,
        verification_authority: "test-provider-contract",
      ),
      credential_candidate: nil,
    )
    IdentitySocialCeremonyResultIssuer.issue!(
      grant_token: grant_token,
      callback_result: callback_result,
      surface: "app",
      actor_ref: @client.public_id,
      session_ref: @session_ref,
      operation: "signup",
      birthdate: birthdate,
      now: @now,
    )
  end

  def auth_hash(provider: "google")
    return @auth_hash ||= build_auth_hash(provider: provider) if provider == "google"

    build_auth_hash(provider: provider)
  end

  def build_auth_hash(provider:)
    {
      "provider" => provider,
      "uid" => "social-ceremony-#{provider}-#{SecureRandom.hex(6)}",
      "credentials" => {
        "token" => "provider-access-token",
        "refresh_token" => "provider-refresh-token",
        "expires_at" => 1.hour.from_now.to_i,
      },
      "info" => {
        "email" => "social-ceremony@example.com",
      },
      "extra" => {
        "raw_info" => {
          "email_verified" => true,
        },
      },
    }
  end
end
