# typed: false
# frozen_string_literal: true

require "test_helper"

# Finalising a social sign-up writes an account and its identity in one
# transaction. A rejected write must surface as the provider error the callback
# already knows how to answer, and the diagnostic must name the record that was
# rejected so the failure can be traced without re-running the ceremony.
class SocialAuthSignupFinalizerFailureTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "a rejected write is reported as a provider error and logged against the rejected record" do
    principal = ExternalAuthentication::VerifiedPrincipal.new(
      provider: "google",
      subject: "sub-1",
      issuer: "https://accounts.google.com",
      audience: "client-id",
      verified_at: Time.current,
      verification_authority: "omniauth-google/1.0.0",
    )
    invalid = Client.new(security_mode_id: SecurityModeConfigurable::NORMAL)
    invalid.errors.add(:status_id, :blank)
    exploding = Object.new
    exploding.define_singleton_method(:ensure_active_status!) { raise ActiveRecord::RecordInvalid, invalid }

    recorded = []

    ExternalAuthentication::IdentityRepositoryFactory.stub(
      :current, Struct.new(:repo) { def build(_provider) = repo }.new(exploding),
    ) do
      Rails.logger.stub(:error, ->(*args, &block) { recorded << (args.first || block&.call).to_s }) do
        assert_raises(SocialAuth::ProviderError) do
          SocialAuthSignupFinalizer.call(
            user: Client.new(security_mode_id: SecurityModeConfigurable::NORMAL), principal: principal,
            credential_candidate: nil,
            ceremony_started_at: Time.current,
          )
        end
      end
    end

    assert(recorded.any? { |line| line.include?("social_auth.signup_finalizer.failed") })
    assert(recorded.any? { |line| line.include?("Client") })
  end
end
