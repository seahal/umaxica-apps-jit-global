# frozen_string_literal: true

require "test_helper"

class WebauthnPublicRegistryEntrypointsTest < ActiveSupport::TestCase
  test "APP and ORG surfaces resolve their own ceremony transaction classes" do
    app_surface = Webauthn::Surface.for(:app)
    org_surface = Webauthn::Surface.for(:org)

    assert_equal ClientPasskeyCeremonyTransaction, app_surface.ceremony_transaction_class
    assert_equal OperatorPasskeyCeremonyTransaction, org_surface.ceremony_transaction_class
  end

  test "UV policy registry exposes each ceremony policy as server-enforced" do
    policies = Webauthn::UvPolicy.all

    assert_equal %i(direct_sign_in emergency_sign_in high_risk_step_up mfa_challenge ordinary_step_up registration),
                 policies.map(&:purpose).sort
    assert policies.all?(&:enforce_server_side?)
  end

  test "OIDC verification result distinguishes absent and present step-up claims" do
    without_claims = OidcClientAssertionJwt::VerificationResult.new(
      authenticated: true,
      step_up_claims_state: :none,
      step_up_expectation: nil,
    )
    with_claims = OidcClientAssertionJwt::VerificationResult.new(
      authenticated: true,
      step_up_claims_state: :valid,
      step_up_expectation: OidcClientAssertionStepUpExpectationValue.new(
        grant: "sensitive-admission-grant",
        subject: "client-subject",
      ),
    )

    assert_not without_claims.step_up_claims_present?
    assert_predicate with_claims, :step_up_claims_present?
  end
end
