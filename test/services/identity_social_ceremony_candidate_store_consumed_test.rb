# frozen_string_literal: true

require "test_helper"

class IdentitySocialCeremonyCandidateStoreConsumedTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "consumed candidate is available through the class and instance readers" do
    principal = ExternalAuthentication::VerifiedPrincipal.new(
      provider: "google",
      subject: "consumed-candidate-subject",
      issuer: "https://accounts.google.com",
      audience: "google-client-id",
      verified_at: IdentitySocialCeremonyCandidate.database_now,
      verification_authority: "test-provider-contract",
    )
    candidate = IdentitySocialCeremonyCandidateStore.store!(
      surface: "app",
      actor_ref: "consumed-candidate-actor",
      session_ref: "consumed-candidate-session",
      transaction_id: SecureRandom.uuid,
      operation: "login",
      provider: "google",
      callback_result: ExternalAuthentication::CallbackResult.verified(principal:),
      expires_at: IdentitySocialCeremonyCandidate.database_now + 5.minutes,
    )

    IdentitySocialCeremonyCandidateStore.consume!(candidate.ref)
    class_result = IdentitySocialCeremonyCandidateStore.fetch_consumed!(candidate.ref)
    instance_result = IdentitySocialCeremonyCandidateStore.new.fetch_consumed!(candidate.ref)

    assert_equal candidate.ref, class_result.ref
    assert_equal candidate.ref, instance_result.ref
    assert_equal "consumed-candidate-subject", class_result.callback_result.principal.subject
    assert_nil class_result.callback_result.credential_candidate
  end

  test "unconsumed candidate is unavailable to the consumed reader without mutation" do
    principal = ExternalAuthentication::VerifiedPrincipal.new(
      provider: "apple",
      subject: "active-candidate-subject",
      issuer: "https://appleid.apple.com",
      audience: "apple-client-id",
      verified_at: IdentitySocialCeremonyCandidate.database_now,
      verification_authority: "test-provider-contract",
    )
    candidate = IdentitySocialCeremonyCandidateStore.store!(
      surface: "app",
      actor_ref: "active-candidate-actor",
      session_ref: "active-candidate-session",
      transaction_id: SecureRandom.uuid,
      operation: "login",
      provider: "apple",
      callback_result: ExternalAuthentication::CallbackResult.verified(principal:),
      expires_at: IdentitySocialCeremonyCandidate.database_now + 5.minutes,
    )

    assert_raises(IdentitySocialCeremonyContract::Error) do
      IdentitySocialCeremonyCandidateStore.fetch_consumed!(candidate.ref)
    end
    assert_nil IdentitySocialCeremonyCandidate.find_by!(ref: candidate.ref).consumed_at
  end
end
