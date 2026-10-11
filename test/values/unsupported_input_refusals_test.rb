# typed: false
# frozen_string_literal: true

require "test_helper"

# A sweep over the places that refuse an input they were never taught. Each is a
# single line, and each is the difference between a value being rejected at the
# boundary and being carried further as though it meant something. They are
# gathered here because the failure mode is identical everywhere: a new surface,
# provider or state added without teaching the mapping must fail loudly.
class UnsupportedInputRefusalsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "a provider whose adapter key has no adapter is refused" do
    entry = Struct.new(:adapter_key).new(:martian_oidc)

    ExternalAuthentication::ProviderRegistry.stub(:fetch, entry) do
      error = assert_raises(ArgumentError) { ExternalAuthentication::ProviderAdapterFactory.build(provider: "martian") }

      assert_match(/adapter is unsupported/, error.message)
    end
  end

  # The challenge verifier is injected through configuration so no production
  # class carries a test-only branch. An unset one has to fail loudly rather than
  # leave every challenge unverified.
  test "an unconfigured challenge verifier is refused rather than skipped" do
    configured = Rails.application.config.x.turnstile.verifier
    Rails.application.config.x.turnstile.verifier = nil

    error = assert_raises(RuntimeError) { Turnstile::VerifierFactory.current }

    assert_match(/turnstile\.verifier is not configured/, error.message)
  ensure
    Rails.application.config.x.turnstile.verifier = configured
  end

  test "each quota policy maps its own surface and refuses one it does not serve" do
    {
      Acme::AccountQuotaPolicy => :account_class,
      Acme::OrganizationQuotaPolicy => :organization_class,
    }.each do |policy_class, mapping|
      policy = policy_class.allocate
      policy.instance_variable_set(:@surface, :martian)

      error = assert_raises(ArgumentError) { policy.send(mapping) }

      assert_match(/unsupported surface/, error.message)
    end
  end

  test "quota policies refuse a principal from another surface" do
    account_policy = Acme::AccountQuotaPolicy.new(surface: :app, principal: Visitor.new)
    organization_policy = Acme::OrganizationQuotaPolicy.new(surface: :com, principal: Client.new)

    assert_raises(ArgumentError) { account_policy.current_count }
    assert_raises(ArgumentError) { organization_policy.current_count }
  end

  test "a sign-up surface with no minimum age is refused rather than treated as unrestricted" do
    assert_predicate SignUpEligibilityPolicy.minimum_age(surface: :app), :positive?
    assert_predicate SignUpEligibilityPolicy.minimum_age(surface: :com), :positive?

    error = assert_raises(ArgumentError) { SignUpEligibilityPolicy.minimum_age(surface: :org) }

    assert_match(/unsupported sign-up eligibility surface/, error.message)
  end

  test "an avatar lifecycle state with no declared transitions is refused" do
    transition = AvatarLifecycle::Transition.allocate

    error =
      assert_raises(AvatarLifecycle::InvalidTransition) do
        transition.send(:validate_transition!, "teleported", "active")
      end

    assert_match(/unsupported avatar lifecycle state/, error.message)

    disallowed =
      assert_raises(AvatarLifecycle::InvalidTransition) do
        transition.send(:validate_transition!, "deleted", "active")
      end

    assert_match(/is not allowed/, disallowed.message)
    assert_nil transition.send(:validate_transition!, "active", "suspended")
  end

  test "an enforcement release mode with no declared actions is refused" do
    enforcement_case = Struct.new(:release_mode).new("teleport")

    error = assert_raises(ArgumentError) { AccountStanding.send(:actions_for, enforcement_case) }

    assert_match(/unsupported enforcement release mode/, error.message)
  end

  # A decision has to carry when it was observed, because staleness is what
  # decides whether it may still be trusted.
  test "an availability decision without an observation time is refused" do
    error =
      assert_raises(ArgumentError) do
        ExternalAuthentication::AvailabilityDecision.new(
          state: :enabled, source: "flipper", configuration_version: nil,
          reason_code: nil, incident_id: nil, observed_at: "just now",
        )
      end

    assert_match(/observed_at must be a time/, error.message)
  end

  test "a signup-required login result cannot also carry an account" do
    error =
      assert_raises(ArgumentError) do
        ExternalAuthentication::LoginResult.new(
          status: :signup_required, user: Object.new, identity: nil, existing_account: false,
        )
      end

    assert_match(/signup required result cannot contain an account/, error.message)
  end

  # Linking or signing up from a social callback is only ever done from a
  # principal something already verified; anything else is refused at construction.
  test "linking and signing up both require an already-verified principal" do
    [ExternalAuthenticationLinkUseCase, ExternalAuthenticationSignupUseCase].each do |use_case|
      error =
        assert_raises(ArgumentError) do
          if use_case == ExternalAuthenticationLinkUseCase
            use_case.new(principal: "not-verified", credential_candidate: nil, user: nil)
          else
            use_case.new(principal: "not-verified", credential_candidate: nil, birthdate: nil)
          end
        end

      assert_match(/verified principal is required/, error.message)
    end
  end
end
