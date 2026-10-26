# frozen_string_literal: true

require "test_helper"

class SocialCallbackStateMatrixTest < ActiveSupport::TestCase
  test "A08-1 both providers and intents preserve the L1 L2 L3 L5 L6 L7 decisions without allocating authority" do
    %w(google apple).product(
      [false, true],
      %w(unknown registered unusable released unfinished revoked
         deleted),
    ).each do |provider, sign_up_entry, state|
      issuer = (provider == "google") ? "https://accounts.google.com" : "https://appleid.apple.com"
      subject = "matrix-#{SecureRandom.hex(12)}"
      started_at = ClientExternalIdentity.database_now - 1.minute
      principal = ExternalAuthentication::VerifiedPrincipal.new(
        provider:, issuer:, subject:, audience: "#{provider}-test-client-id",
        verified_at: ClientExternalIdentity.database_now, verification_authority: "provider-fixture",
      )
      client = nil
      identity = nil
      unless state == "unknown"
        status_id =
          case state
          when "unusable" then ClientStatus::RESERVED
          when "unfinished" then ClientStatus::UNVERIFIED_WITH_SIGN_UP
          else ClientStatus::ACTIVE
          end
        client = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id:, birthdate: "2000-01-01")
        identity_state =
          case state
          when "revoked" then "consent_revoked"
          when "deleted" then "account_deleted"
          else "active"
          end
        identity = ClientExternalIdentity.create!(
          client:, provider:, issuer:, subject:, audience: principal.audience,
          verified_at: principal.verified_at, verification_authority: "provider-fixture", state: identity_state,
        )
        identity.release! if state == "released"
      end

      assert_no_difference(
        ["Client.count", "ClientSignUpFlow.count", "ClientToken.count",
         "ClientExternalIdentity.count",],
      ) do
        if state == "unknown" && sign_up_entry
          result = ExternalAuthenticationLoginUseCase.call(
            principal:, credential_candidate: nil, sign_up_entry:,
            ceremony_started_at: started_at,
          )

          assert_predicate result, :signup_required?
          assert_nil result.user
        elsif %w(registered unusable).include?(state) && !sign_up_entry
          result = ExternalAuthenticationLoginUseCase.call(
            principal:, credential_candidate: nil, sign_up_entry:,
            ceremony_started_at: started_at,
          )

          assert_equal client.id, result.user.id
          assert_equal state == "registered", result.user.login_allowed?
        else
          expected_class = %w(registered unusable released).include?(state) ? SocialAuth::ConflictError : SocialAuth::UnauthorizedError
          error =
            assert_raises(expected_class, "#{provider}/#{sign_up_entry}/#{state}") do
              ExternalAuthenticationLoginUseCase.call(
                principal:, credential_candidate: nil, sign_up_entry:,
                ceremony_started_at: started_at,
              )
            end
          expected_key =
            case state
            when "registered", "unusable", "released" then "errors.social_auth.identity_conflict"
            when "unfinished" then "errors.social_auth.pending_social_signup_invalid_state"
            when "revoked", "deleted" then "errors.social_auth.unauthorized"
            when "unknown" then "errors.social_auth.invalid_intent"
            end

          assert_equal expected_key, error.i18n_key
          assert_nil identity.reload.last_authenticated_at if identity
        end
      end
    end
  end

  test "A08-2 a banned subject wins before release history and every identity state for both intents and providers" do
    %w(google apple).product(
      [false, true],
      %w(unknown registered unusable released unfinished revoked deleted
         orphan),
    ).each do |provider, sign_up_entry, state|
      issuer = (provider == "google") ? "https://accounts.google.com" : "https://appleid.apple.com"
      subject = "banned-matrix-#{SecureRandom.hex(12)}"
      principal = ExternalAuthentication::VerifiedPrincipal.new(
        provider:, issuer:, subject:, audience: "#{provider}-test-client-id",
        verified_at: ClientExternalIdentity.database_now, verification_authority: "provider-fixture",
      )
      unless %w(unknown orphan).include?(state)
        status_id =
          case state
          when "unusable" then ClientStatus::RESERVED
          when "unfinished" then ClientStatus::UNVERIFIED_WITH_SIGN_UP
          else ClientStatus::ACTIVE
          end
        client = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id:, birthdate: "2000-01-01")
        identity_state =
          case state
          when "revoked" then "consent_revoked"
          when "deleted" then "account_deleted"
          else "active"
          end
        identity = ClientExternalIdentity.create!(
          client:, provider:, issuer:, subject:, audience: principal.audience,
          verified_at: principal.verified_at, verification_authority: "provider-fixture", state: identity_state,
        )
        identity.release! if state == "released"
      end
      enforcement_case = AppEnforcementCase.create!(
        kind: "permanent_ban", duration_mode: "permanent", visibility: "visible", release_mode: "break_glass_only",
        effective_at: 1.minute.ago, reason_code: "abuse", principal_public_id: clients(:one).public_id,
        applied_by_operator_public_id: operators(:one).public_id,
      )
      digest = EnforcementIdentifierDigest.for_social_subject(
        realm: "app", identifier_kind: "#{provider}_subject",
        issuer:, subject:,
      )
      AppEnforcementIdentifierEffect.create!(**digest, enforcement_case:, effective_at: 1.minute.ago)
      # An orphan cannot be persisted through the FK. A collaborator without lookup methods
      # proves that the ban decision precedes even an unavailable/orphan identity repository.
      repository = (state == "orphan") ? Object.new : ExternalAuthentication::ClientExternalIdentityRepositoryAdapter.new(provider:)
      assert_no_difference(
        ["Client.count", "ClientSignUpFlow.count", "ClientToken.count",
         "ClientExternalIdentity.count",],
      ) do
        error =
          assert_raises(SocialAuth::UnauthorizedError) do
            SocialAuthLoginHandler.call(
              principal:, credential_candidate: nil, repository:, provider:, uid: subject,
              sign_up_entry:, ceremony_started_at: ClientExternalIdentity.database_now - 1.minute,
            )
          end
        assert_equal "errors.social_auth.unauthorized", error.i18n_key
      end
    end
  end
end
