# frozen_string_literal: true

require "test_helper"

class AppSignUpRegistrationReceiptTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  %w(google apple).each do |provider|
    test "#{provider} source commit is immutable and reconciles after the OP update is interrupted" do
      client, flow, principal = registration(provider)
      result = finalize(client, flow, principal)
      receipt = ClientRegistrationCompletion.find_by!(client_id: client.id)

      assert_equal client.id, result.fetch(:identity).client_id
      assert_equal [flow.public_id, ClientRegistrationCompletionMethod::IDS.fetch(provider)],
                   [receipt.sign_up_flow_ref, receipt.method_id]
      assert_equal ClientSignUpFlowStatus::FINALIZING, flow.reload.status_id
      assert_raises(ActiveRecord::ReadOnlyRecord) { receipt.update!(completed_at: receipt.completed_at + 1.second) }
      assert_raises(ActiveRecord::ReadOnlyRecord) { receipt.destroy! }
      assert_no_difference ["ClientRegistrationCompletion.count", "ClientExternalIdentity.count",
                            "ClientSocialAuditOutbox.count",] do
        finalize(client, flow, principal)
      end
      assert_predicate flow.reload, :sign_up_completed?
    end
  end

  test "source and audit writes roll back if receipt persistence fails" do
    client, flow, principal = registration("google")
    failure = ->(**) { raise ActiveRecord::RecordNotSaved, "receipt persistence unavailable" }
    assert_no_difference ["ClientRegistrationCompletion.count", "ClientExternalIdentity.count",
                          "ClientSocialAuditOutbox.count",] do
      ClientRegistrationCompletion.stub(:create!, failure) do
        assert_raises(SocialAuth::ProviderError) { finalize(client, flow, principal) }
      end
    end
    assert_equal ClientStatus::UNVERIFIED_WITH_SIGN_UP, client.reload.status_id
    assert_equal ClientSignUpFlowStatus::FINALIZING, flow.reload.status_id
  end

  test "receipt protects committed registration after parent cancellation and flow expiry" do
    client, flow, principal = registration("google")
    finalize(client, flow, principal)
    binding = flow.association(:auth_admission_binding).scope.take!
    parent = binding.association(:authorization_transaction).scope.take!
    parent.prepare_cancellation_handoff!(reference: SecureRandom.uuid, ciphertext: "test-cancellation-ciphertext")
    parent.cancel!(cancellation_handoff_digest: Digest::SHA256.hexdigest("receipt-test-cancel"))
    before_actor, before_identity = client.reload.attributes,
ClientExternalIdentity.find_by!(client_id: client.id).attributes
    ClientSignUpFlow.stub(:database_now, flow.expires_at + 1.second) do
      SignUpTermination.call(cycle: flow, event: :expire)
      SignUpArtifactCleanup.call(cycle: flow)
    end

    assert_predicate flow.reload, :sign_up_completed?
    assert_equal before_actor, client.reload.attributes
    assert_equal before_identity, ClientExternalIdentity.find_by!(client_id: client.id).attributes
  end

  test "parent cancellation before source registration creates no identity or receipt" do
    client, flow, principal = registration("google")
    binding = flow.association(:auth_admission_binding).scope.take!
    parent = binding.association(:authorization_transaction).scope.take!
    parent.prepare_cancellation_handoff!(reference: SecureRandom.uuid, ciphertext: "test-cancellation-ciphertext")
    parent.cancel!(cancellation_handoff_digest: Digest::SHA256.hexdigest("receipt-test-cancel-first"))
    assert_no_difference ["ClientRegistrationCompletion.count", "ClientExternalIdentity.count"] do
      assert_raises(FlowInvalidTransition) { finalize(client, flow, principal) }
    end
    assert_equal ClientStatus::UNVERIFIED_WITH_SIGN_UP, client.reload.status_id
  end

  test "completion for another flow or method cannot authorize registration" do
    client, flow, principal = registration("google")
    finalize(client, flow, principal)
    receipt = ClientRegistrationCompletion.find_by!(client_id: client.id)
    other_client, other_flow, = registration("google")
    assert_raises(ClientRegistrationCompletion::Conflict) { receipt.verify_flow!(other_flow) }
    assert_raises(ArgumentError) do
      AppSignUpRegistrationCommitter.call!(flow: flow, client: other_client, method: "google") { flunk }
    end
    assert_raises(ArgumentError) do
      AppSignUpRegistrationCommitter.call!(flow: flow, client: client, method: "apple") { flunk }
    end
  end

  test "existing verified Clients without receipts are never inferred to have completion evidence" do
    client, flow, principal = registration("google")
    client.update!(status_id: ClientStatus::VERIFIED_WITH_SIGN_UP)
    assert_no_difference "ClientRegistrationCompletion.count" do
      assert_raises(FlowInvalidTransition) { finalize(client, flow, principal) }
    end
  end

  private

  def registration(provider)
    client = Client.create!(
      status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP,
      security_mode_id: ClientSecurityMode::NORMAL,
    )
    principal = ExternalAuthentication::VerifiedPrincipal.new(
      provider: provider, subject: SecureRandom.uuid,
      issuer: (provider == "google") ? "https://accounts.google.com" : "https://appleid.apple.com",
      audience: "receipt-test-client", verified_at: Time.current, verification_authority: "provider-test-boundary",
    )
    now = ClientSignUpFlow.database_now
    flow = ClientSignUpFlow.create!(
      auth_admission_binding: SignUpAdmissionTestFactory.binding_for!(ClientSignUpFlow),
      principal_id: client.id, entry_method: provider, social_provider: provider,
      pending_contact_type: "social_identity", status_id: ClientSignUpFlowStatus::CHECKPOINT_PENDING,
      step: "checkpoint", issued_at: now, expires_at: now + 15.minutes,
      nonce_digest: ClientSignUpFlow.digest_nonce(SecureRandom.hex(16)),
      completed_requirements: {
        "confirmation" => { "cleared" => true },
        "birthdate" => { "cleared" => true },
        "social_signup" => { "provider" => provider,
                             "uid_digest" => OpenSSL::HMAC.hexdigest(
                               "SHA256", Rails.application.secret_key_base,
                               [provider, principal.subject].join(":"),
                             ), },
      },
    )
    [client, flow, principal]
  end

  def finalize(client, flow, principal)
    SocialAuthSignupFinalizer.call(
      user: client, flow: flow, principal: principal,
      credential_candidate: nil, ceremony_started_at: flow.issued_at,
    )
  end
end
