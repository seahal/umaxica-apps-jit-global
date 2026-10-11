# typed: false
# frozen_string_literal: true

require "test_helper"

# A sign-in that started from an OIDC authorization resumes at the URL the
# authorization transaction hands back, and the challenge is cleared from the
# session either way -- leaving it behind would let a later, unrelated sign-in
# resume someone else's authorization.
class Auth::OidcAuthorizationResumeTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  def harness_for(controller_class)
    Class.new(controller_class) do
      def session = @session_hash ||= {}

      def current_resource = nil

      def current_session_public_id = "session-public-id"

      def invoke(name, ...) = send(name, ...)
    end.new
  end

  [Auth::Com::ApplicationController, Auth::Org::ApplicationController].each do |klass|
    test "#{klass.name} resumes at the url the authorization transaction hands back" do
      harness = harness_for(klass)
      harness.session[:oidc_authorization_login_challenge] = "challenge-1"
      captured = nil
      # `oidc_authorization_after_login_path` calls `BaseAuthAdmissionCoordinator.register_result_and_issue_resume!`
      # directly (not `OidcAuthorizationTransactionCoordinator.register_result!`, which that method calls
      # internally and then feeds through the real `issue_result!`/`resume_url` computation) -- stubbing at
      # the inner layer with a double missing the `:transaction` field it needs raises a NoMethodError, and
      # even a complete double there would have its `resume_url` overwritten by the real downstream
      # computation. Stub at the same layer the code under test actually calls.
      registrar =
        lambda do |**arguments|
          captured = arguments
          BaseAuthAdmissionCoordinator::Issuance.new(
            transaction: nil, code: nil,
            resume_url: "https://www.example/oauth/authorize?resume=1",
          )
        end

      Actor.clear

      BaseAuthAdmissionCoordinator.stub(:register_result_and_issue_resume!, registrar) do
        assert_equal "https://www.example/oauth/authorize?resume=1",
                     harness.invoke(:oidc_authorization_after_login_path)
      end

      assert_equal "challenge-1", captured.fetch(:login_challenge)
      assert_nil harness.session[:oidc_authorization_login_challenge]
    ensure
      Actor.clear
    end

    test "#{klass.name} clears the challenge even when the transaction refuses" do
      harness = harness_for(klass)
      harness.session[:oidc_authorization_login_challenge] = "challenge-1"
      refusing = ->(**) { raise IdentityStepUpCeremonyContract::Error, "no such transaction" }

      Actor.clear

      OidcAuthorizationTransactionCoordinator.stub(:register_result!, refusing) do
        assert_raises(StandardError) { harness.invoke(:oidc_authorization_after_login_path) }
      end

      assert_nil harness.session[:oidc_authorization_login_challenge]
    ensure
      Actor.clear
    end
  end
end
