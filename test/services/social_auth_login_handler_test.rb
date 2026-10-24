# typed: false
# frozen_string_literal: true

require "test_helper"
require "support/external_identity_test_helper"

# D-48 L1-L8 with D-72 (WU-08): the decision for a verified Google subject under each intent.
class SocialAuthLoginHandlerTest < ActiveSupport::TestCase
  include ExternalIdentityTestHelper

  # L4 only: an identity row whose Client is gone cannot be stored, so the repository boundary is
  # replaced to present one.
  OrphanRepository =
    Struct.new(:identity) do
      def find_by_subject_for_link(*) = identity
    end

  test "L1: an unknown subject is refused on sign-in and becomes a pending sign-up on sign-up" do
    assert_raises(SocialAuth::UnauthorizedError) { decide("unknown-#{SecureRandom.hex(4)}", sign_up_entry: false) }
    result = decide("unknown-#{SecureRandom.hex(4)}", sign_up_entry: true)

    assert result[:pending_social_signup]
    assert_nil result[:user]
  end

  test "L2: a registered subject signs in and refuses sign-up" do
    client = client_with(ClientStatus::ACTIVE)
    identity = create_active_external_identity(client: client, provider: "google")

    assert_equal client, decide(identity.subject, sign_up_entry: false)[:user]
    error = assert_raises(SocialAuth::ConflictError) { decide(identity.subject, sign_up_entry: true) }

    assert_equal "errors.social_auth.identity_conflict", error.i18n_key
  end

  test "L3: a linked Client that cannot sign in is handed to Sign In, which refuses it" do
    client = client_with(ClientStatus::RESERVED)
    identity = create_active_external_identity(client: client, provider: "google")

    assert_equal client, decide(identity.subject, sign_up_entry: false)[:user]
    assert_not client.login_allowed?
  end

  test "L4: an identity without its Client raises the invariant error with a FATAL event" do
    orphan = Struct.new(:state) {
      def association(_)
        Struct.new(:scope).new(Struct.new(:take).new(nil))
      end
    }.new("active")
    logged = []

    Rails.logger.stub(:fatal, ->(message = nil) { logged << message.to_s }) do
      assert_raises(SocialAuth::IdentityInvariantError) do
        decide("orphan-#{SecureRandom.hex(4)}", sign_up_entry: true, repository: OrphanRepository.new(orphan))
      end
    end

    assert(logged.any? { |line| line.include?("social_auth.identity_without_client") })
  end

  test "L6: a subject linked to an unfinished registration is refused in both intents" do
    identity = create_active_external_identity(
      client: client_with(ClientStatus::UNVERIFIED_WITH_SIGN_UP),
      provider: "google",
    )

    [false, true].each do |sign_up_entry|
      error = assert_raises(SocialAuth::UnauthorizedError) { decide(identity.subject, sign_up_entry:) }

      assert_equal "errors.social_auth.pending_social_signup_invalid_state", error.i18n_key
    end
  end

  test "L7: a revoked or deleted provider account is refused in both intents" do
    %w(consent_revoked account_deleted).each do |state|
      identity = create_active_external_identity(
        client: client_with(ClientStatus::ACTIVE), provider: "google",
        state: state,
      )

      [false, true].each do |sign_up_entry|
        assert_raises(SocialAuth::UnauthorizedError) { decide(identity.subject, sign_up_entry:) }
      end
    end
  end

  test "L8: an in-force enforcement effect on the subject is decided before any identity state" do
    identity = create_active_external_identity(client: client_with(ClientStatus::ACTIVE), provider: "google")
    AppEnforcementIdentifierEffect.build_for_google_subject(
      issuer: identity.issuer, subject: identity.subject, enforcement_case: ban_case, effective_at: 1.minute.ago,
    ).save!

    [false, true].each do |sign_up_entry|
      assert_raises(SocialAuth::UnauthorizedError) { decide(identity.subject, sign_up_entry:) }
    end
    assert_raises(SocialAuth::UnauthorizedError) do
      decide(identity.subject, sign_up_entry: true, repository: OrphanRepository.new(nil))
    end
  end

  test "a concurrent identity insert is reported as a conflict" do
    repository = Struct.new(:x) {
      def find_by_subject_for_link(*)
        raise(ActiveRecord::RecordNotUnique, "duplicate")
      end
    }.new(nil)
    error =
      assert_raises(SocialAuth::ConflictError) do
        decide("race-#{SecureRandom.hex(4)}", sign_up_entry: false, repository: repository)
      end

    assert_equal "errors.social_auth.identity_conflict", error.i18n_key
  end

  private

  def client_with(status_id)
    Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: status_id, birthdate: "2000-01-01")
  end

  def decide(subject, sign_up_entry:,
             repository: ExternalAuthentication::ClientExternalIdentityRepositoryAdapter.new(provider: "google"))
    principal = ExternalAuthentication::VerifiedPrincipal.new(
      provider: "google", subject: subject, issuer: "https://accounts.google.com", audience: "google-client-id",
      verified_at: Time.current, verification_authority: "omniauth-google-oauth2/contract",
    )
    SocialAuthLoginHandler.call(
      principal: principal, credential_candidate: nil, repository: repository, provider: "google", uid: subject,
      sign_up_entry: sign_up_entry, ceremony_started_at: 1.minute.ago,
    )
  end

  def ban_case
    AppEnforcementCase.create!(
      kind: "permanent_ban", duration_mode: "permanent", visibility: "visible", release_mode: "break_glass_only",
      effective_at: Time.current, reason_code: "abuse", principal_public_id: Client.first.public_id,
      applied_by_operator_public_id: Operator.first.public_id,
    )
  end
end
