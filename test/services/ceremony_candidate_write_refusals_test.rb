# typed: false
# frozen_string_literal: true

require "test_helper"

# Ceremony candidate stores hold a half-finished credential between two requests.
# A write the database refuses is re-raised as the ceremony's own error type,
# because the caller answers a ceremony failure differently from a database one.
# Activation candidates are the same idea in reverse: a region that cannot be
# read falls back rather than leaving the candidate without one.
class CeremonyCandidateWriteRefusalsTest < ActiveSupport::TestCase
  fixtures :clients, :client_statuses, :client_visibilities

  test "a secret credential candidate the database refuses is raised as a ceremony error" do
    store = IdentitySecretCredentialCeremonyCandidateStore.new
    arguments = {
      surface: "app",
      actor_ref: "actor-1",
      session_ref: "session-1",
      transaction_id: SecureRandom.uuid,
      operation: "registration",
      password_digest: "digest",
      name: "primary",
      enabled: true,
      expires_at: 10.minutes.from_now,
    }

    IdentitySecretCredentialCeremonyCandidate.stub(
      :create!, ->(**) { raise ActiveRecord::RecordNotUnique, "duplicate digest" },
    ) do
      error =
        assert_raises(IdentitySecretCredentialCeremonyContract::Error) { store.store!(**arguments) }

      assert_match(/secret credential candidate is invalid/, error.message)
    end
  end

  test "a secret credential candidate with no password digest is refused before any write" do
    store = IdentitySecretCredentialCeremonyCandidateStore.new

    error =
      assert_raises(IdentitySecretCredentialCeremonyContract::Error) do
        store.store!(
          surface: "app", actor_ref: "actor-1", session_ref: "session-1", transaction_id: SecureRandom.uuid,
          operation: "registration", password_digest: "", name: "primary", enabled: true,
          expires_at: 10.minutes.from_now,
        )
      end

    assert_match(/password digest is required/, error.message)
  end

  test "a TOTP candidate the database refuses is raised as a ceremony error" do
    store = IdentityTotpCeremonyCandidateStore.new

    IdentityTotpCeremonyCandidate.stub(
      :create!, ->(**) { raise ActiveRecord::RecordNotUnique, "duplicate digest" },
    ) do
      error =
        assert_raises(IdentityTotpCeremonyContract::Error) do
          store.store!(
            surface: "app", actor_ref: "actor-1", session_ref: "session-1",
            private_key: ROTP::Base32.random_base32, title: "Authenticator",
            last_otp_at: Time.current.to_i, expires_at: 10.minutes.from_now,
          )
        end

      assert_match(/TOTP candidate is invalid/, error.message)
    end
  end

  test "an activation resolver with no actor at all offers no candidates" do
    assert_empty SignInActivationCandidateResolver.new(cycle: ClientSignInFlow.new, actor: nil).candidates
  end
end
