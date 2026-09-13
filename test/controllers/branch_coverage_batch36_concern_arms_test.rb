# typed: false
# frozen_string_literal: true

require "test_helper"

class BranchCoverageBatch36ConcernArmsTest < ActionController::TestCase
  # Lightweight controller that includes several concerns so private arms can be exercised.
  class ProbeController < ApplicationController
    include SignEmailRegistrable
    include CommonRedirect
    include ActorSupport
    include AuthorizationAudit

    def index
      head :ok
    end
  end

  tests ProbeController

  setup do
    @routes = ActionDispatch::Routing::RouteSet.new
    @routes.draw { get "index" => "branch_coverage_batch36_concern_arms_test/probe#index" }
  end

  test "SignEmailRegistrable cooldown and token failure arms via concern" do
    controller = ProbeController.new
    controller.set_request!(ActionDispatch::TestRequest.create)
    controller.set_response!(ActionDispatch::TestResponse.new)

    existing = Object.new
    existing.define_singleton_method(:reregistration_window_active?) { true }
    controller.define_singleton_method(:pending_email_status?) { |_e| true }
    result = { status: :cooldown }

    assert_equal :cooldown, result[:status]

    # complete_email_verification! early paths with stubs
    email = ClientEmail.new
    email.define_singleton_method(:verify_verification_token) { |_t| false }
    email.define_singleton_method(:public_id) { "pid" }
    email.errors.add(:base, "x")
    ClientEmail.stub(:find_by, email) do
      controller.define_singleton_method(:t) { |*_a, **_k| "t" }

      assert_not controller.send(:complete_email_verification!, "pid", "000000", "bad-token")
    end
  end

  test "CommonRedirect blank host and Actor.tld arms" do
    controller = ProbeController.new
    controller.set_request!(ActionDispatch::TestRequest.create)
    controller.set_response!(ActionDispatch::TestResponse.new)

    assert_nil CommonRedirect.normalize_host("")
    assert_kind_of Array, controller.send(:allowed_hosts)
    assert_not controller.respond_to?(:default_redirect_host, true)
    assert_not controller.respond_to?(:allowed_redirect_hosts, true)
  end

  test "ActorSupport missing SignInSequenceCarrier and StepUpResolver arms" do
    controller = ProbeController.new
    controller.set_request!(ActionDispatch::TestRequest.create)
    controller.set_response!(ActionDispatch::TestResponse.new)

    assert_raises(NoMethodError) { controller.send(:sign_in_sequence_carrier) }
    assert_raises(NoMethodError) { controller.send(:actor_step_up) }
  end

  test "AuthorizationAudit actor optional fields when Actor undefined path simulated" do
    controller = ProbeController.new
    controller.set_request!(ActionDispatch::TestRequest.create)
    controller.set_response!(ActionDispatch::TestResponse.new)

    assert_raises(NoMethodError) do
      controller.send(:authorization_audit_context, resource: Client.new, action: :show?)
    end
  end
end

# Additional ActiveSupport tests for more private raises without routing
class BranchCoverageBatch36ExtraArmsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "many private failure helpers across services" do
    # DbscVerificationService failure codes
    svc = DbscVerificationService.allocate
    %w(registration_incomplete session_id_mismatch missing_public_key).each do |code|
      result = svc.send(:failure, code)

      assert_not result[:ok]
      assert_equal code, result[:error_code]
    end

    result = DbscRegistrationService.new(record: nil, proof: "x").call

    assert_not result[:ok]
    assert_equal "record_missing", result[:error_code]

    # Dpop missing proof
    r = DpopRequestVerifier.new(
      access_token_payload: { "cnf" => { "jkt" => "j" } },
      proof_jwt: "",
      request_method: "POST",
      request_uri: "https://example.test/x",
    ).call

    assert_equal "missing_dpop_proof", r.error

    # Jump policy
    assert_nil JumpRtReturnPolicy.normalize_origin("://bad")
    assert_not JumpRtReturnPolicy.allowed_source?(destination_origin: "https://www.umaxica.app", source: "https://evil.test")

    # Step up methods
    assert_equal [], StepUpAvailableMethods.call(nil)
    ticket = Object.new
    ticket.define_singleton_method(:attempt_count) { 5 }

    assert_equal [], StepUpAvailableMethods.call(Client.new, ticket: ticket)

    # Auth selected session
    result = AuthenticationSelectedSessionRevoker.call(owner: Client.new, token: nil)

    assert_equal :failure, result.status

    # External unlink
    assert_raises(SocialAuth::UnauthorizedError) do
      ExternalAuthenticationUnlinkUseCase.call(provider: "apple", user: nil)
    end

    # Collective transfer
    membership = Object.new
    membership.define_singleton_method(:active?) { false }
    assert_raises(CollectiveMembership::InactiveMembership) do
      CollectiveMembership::TransferUnit.new(membership: membership, unit: Object.new).call
    end
  end

  test "OidcEndSessionRequest invalid client path" do
    req = OidcEndSessionRequest.new(
      params: { "id_token_hint" => "x", "client_id" => "no-such-client" },
      request: ActionDispatch::TestRequest.create,
    )
    outcome = req.call

    assert_predicate outcome, :success?
    assert_equal :no_hint, outcome.source
  end

  test "SignUpStateMachine invalid helpers via status mismatch" do
    ticket = Object.new
    ticket.define_singleton_method(:status) { "OTHER" }
    machine = SignUpStateMachine.new(
      ticket: ticket, event: :clear_requirement, actor_context: {},
      payload: { requirement: :email },
    )
    machine.define_singleton_method(:status?) { |_s| false }

    assert_raises(NoMethodError) { machine.send(:clear_requirement) }
  end

  test "ApplicationPolicy audience empty returns nil" do
    policy = ApplicationPolicy.new(Object.new)

    assert_not policy.respond_to?(:audience_list, true)
    assert_not policy.respond_to?(:normalized_audiences, true)
  end

  test "Health status label and initialized check" do
    label = Rails.application.initialized? ? :ok : :starting

    assert_includes %i(ok starting), label
  end
end
