# typed: false
# frozen_string_literal: true

require "test_helper"

# Candidate rows carry a serialised provider payload, so a row whose payload has
# lost a claim or holds the wrong type is corrupt state, not a missing record.
# Both readers report it as a contract error so the ceremony stops rather than
# continuing with a half-read candidate.
class IdentitySocialCeremonyCandidateStoreFailuresTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "changed social candidate identity or actor binding is rejected before consumption" do
    %i(subject issuer provider actor).each do |changed|
      principal = ExternalAuthentication::VerifiedPrincipal.new(
        provider: "google", subject: "original-subject", issuer: "https://accounts.google.com",
        audience: "google-client-id", verified_at: IdentitySocialCeremonyCandidate.database_now,
        verification_authority: "test-provider-contract",
      )
      candidate = IdentitySocialCeremonyCandidateStore.store!(
        surface: "app", actor_ref: "original-actor", session_ref: "bound-session",
        transaction_id: SecureRandom.uuid, operation: "link", provider: "google",
        callback_result: ExternalAuthentication::CallbackResult.verified(principal: principal),
        expires_at: IdentitySocialCeremonyCandidate.database_now + 5.minutes,
      )
      row = IdentitySocialCeremonyCandidate.find_by!(ref: candidate.ref)
      if changed == :actor
        row.update!(actor_ref: "different-actor")
      else
        payload = row.auth_hash.deep_dup
        payload.fetch("principal")[changed.to_s] =
          { subject: "different-subject", issuer: "https://different.example", provider: "apple" }.fetch(changed)
        row.update!(auth_hash: payload)
      end

      assert_raises(IdentitySocialCeremonyContract::Error) do
        IdentitySocialCeremonyCandidateStore.fetch!(candidate.ref)
      end
      assert_raises(IdentitySocialCeremonyContract::Error) do
        IdentitySocialCeremonyCandidateStore.consume!(candidate.ref)
      end
      assert_nil row.reload.consumed_at
    end
  end

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

  test "candidate creation fails closed when the OP insert fails" do
    principal = ExternalAuthentication::VerifiedPrincipal.new(
      provider: "google", subject: "insert-unavailable", issuer: "https://accounts.google.com",
      audience: "google-client-id", verified_at: IdentitySocialCeremonyCandidate.database_now,
      verification_authority: "test-provider-contract",
    )
    transaction_id = SecureRandom.uuid
    insert_seen = false
    observer =
      lambda do |_name, _start, _finish, _id, event|
        next unless event.fetch(:sql).match?(/\A\s*INSERT\s+INTO\s+"identity_social_ceremony_candidates"/i)

        insert_seen = true
        raise ActiveRecord::ConnectionNotEstablished, "injected OP insert failure"
      end

    ActiveSupport::Notifications.subscribed(observer, "sql.active_record") do
      assert_raises(ActiveRecord::ConnectionNotEstablished) do
        IdentitySocialCeremonyCandidateStore.store!(
          surface: "app", actor_ref: "anonymous", session_ref: "insert-unavailable-session",
          transaction_id: transaction_id, operation: "login", provider: "google",
          callback_result: ExternalAuthentication::CallbackResult.verified(principal: principal),
          expires_at: IdentitySocialCeremonyCandidate.database_now + 5.minutes,
        )
      end
    end

    assert insert_seen
    assert_not IdentitySocialCeremonyCandidate.exists?(transaction_id: transaction_id)
  end

  test "candidate storage retains the verified principal without provider credentials" do
    principal = ExternalAuthentication::VerifiedPrincipal.new(
      provider: "apple", subject: "credential-boundary", issuer: "https://appleid.apple.com",
      audience: "apple-client-id", verified_at: IdentitySocialCeremonyCandidate.database_now,
      verification_authority: "test-provider-contract",
    )
    callback_result = ExternalAuthentication::CallbackResult.verified(
      principal: principal, credential_candidate: { "access_token" => "synthetic-provider-secret" },
    )
    candidate = IdentitySocialCeremonyCandidateStore.store!(
      surface: "app", actor_ref: "anonymous", session_ref: "credential-boundary-session",
      transaction_id: SecureRandom.uuid, operation: "login", provider: "apple",
      callback_result: callback_result, expires_at: IdentitySocialCeremonyCandidate.database_now + 5.minutes,
    )
    row = IdentitySocialCeremonyCandidate.find_by!(ref: candidate.ref)

    assert_equal ["principal"], row.auth_hash.keys
    assert_equal %w(audience issuer provider subject verification_authority verified_at),
                 row.auth_hash.fetch("principal").keys.sort
    assert_equal principal.subject, row.auth_hash.fetch("principal").fetch("subject")
    assert_nil IdentitySocialCeremonyCandidateStore.fetch!(candidate.ref).callback_result.credential_candidate
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
