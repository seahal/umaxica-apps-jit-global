# typed: false
# frozen_string_literal: true

require "test_helper"

# Candidate rows carry a serialised provider payload, so a row whose payload has
# lost a claim or holds the wrong type is corrupt state, not a missing record.
# Both readers report it as a contract error so the ceremony stops rather than
# continuing with a half-read candidate.
class IdentitySocialCeremonyCandidateStoreFailuresTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "candidate reads and consumption fail closed when the OP database clock is unavailable" do
    principal = ExternalAuthentication::VerifiedPrincipal.new(
      provider: "google", subject: "database-unavailable", issuer: "https://accounts.google.com",
      audience: "google-client-id", verified_at: IdentitySocialCeremonyCandidate.database_now,
      verification_authority: "test-provider-contract",
    )
    candidate = IdentitySocialCeremonyCandidateStore.store!(
      surface: "app", actor_ref: "anonymous", session_ref: "database-unavailable-session",
      transaction_id: SecureRandom.uuid, operation: "login", provider: "google",
      callback_result: ExternalAuthentication::CallbackResult.verified(principal:, credential_candidate: nil),
      expires_at: IdentitySocialCeremonyCandidate.database_now + 5.minutes,
    )
    unavailable = -> { raise ActiveRecord::ConnectionNotEstablished, "OP database unavailable" }

    IdentitySocialCeremonyCandidate.stub(:database_now, unavailable) do
      assert_raises(ActiveRecord::ConnectionNotEstablished) do
        IdentitySocialCeremonyCandidateStore.fetch!(candidate.ref)
      end
      assert_raises(ActiveRecord::ConnectionNotEstablished) do
        IdentitySocialCeremonyCandidateStore.consume!(candidate.ref)
      end
    end

    assert_nil IdentitySocialCeremonyCandidate.find_by!(ref: candidate.ref).consumed_at
    assert_equal candidate.ref, IdentitySocialCeremonyCandidateStore.fetch!(candidate.ref).ref
  end

  test "a candidate row whose payload has lost a claim is reported as a contract error" do
    broken = ->(*, **) { raise KeyError, "key not found: \"issuer\"" }

    IdentitySocialCeremonyCandidate.stub(:find_active_by_ref!, broken) do
      error =
        assert_raises(IdentitySocialCeremonyContract::Error) do
          IdentitySocialCeremonyCandidateStore.fetch!("candidate-ref")
        end

      assert_match(/candidate is invalid/, error.message)
    end
  end

  test "a candidate row whose payload holds the wrong type is reported the same way" do
    broken = ->(*, **) { raise TypeError, "no implicit conversion" }

    IdentitySocialCeremonyCandidate.stub(:find_active_by_ref!, broken) do
      assert_raises(IdentitySocialCeremonyContract::Error) do
        IdentitySocialCeremonyCandidateStore.fetch!("candidate-ref")
      end
    end
  end
end
