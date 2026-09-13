# typed: false
# frozen_string_literal: true

require "test_helper"

# Passkey sign-in has to answer the same way whether the account exists or not,
# and has to refuse every way an assertion can fail without leaking which one it
# was beyond the coarse reason it reports. Each rescue arm below is a distinct
# refusal that ends the ceremony; an arm that stopped firing would let a failed
# assertion fall through to whatever the ensure block left behind.
class PasskeySignInFlowRefusalsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  # The concern pulls in callbacks when included, so the harness has to be a
  # controller. ApplicationController would drag in the surface stack this is
  # deliberately outside of.
  class Harness < ActionController::Base # rubocop:disable Rails/ApplicationController
    include ::PasskeySignInFlow

    attr_accessor :params, :errors, :failures, :discarded, :raise_on_consume

    def initialize
      super
      @params = ActionController::Parameters.new({})
      @errors = []
      @failures = []
      @discarded = []
    end

    def invoke(name, ...) = send(name, ...)

    def render_error(key, status) = errors << [key, status]

    def emit_passkey_auth_failed(reason:) = failures << reason

    def discard_passkey_challenge(id) = discarded << id

    def consume_passkey_challenge_with_actor!(_id, **)
      raise raise_on_consume if raise_on_consume

      Struct.new(:challenge, :actor_global_key).new(:challenge, "client:1")
    end
  end

  def verify_with(error_class, message = "denied")
    harness = Harness.new
    harness.params = ActionController::Parameters.new(challenge_id: "challenge-1")
    harness.raise_on_consume = error_class.new(message)
    harness.verification
    harness
  end

  test "a missing challenge id is refused before anything is consumed" do
    harness = Harness.new

    harness.verification

    assert_equal [["errors.webauthn.challenge_id_required", :bad_request]], harness.errors
    assert_empty harness.discarded
  end

  {
    Webauthn::ChallengeStore::ChallengeNotFoundError =>
      ["challenge_invalid", "errors.webauthn.challenge_invalid", :bad_request],
    Webauthn::ChallengeStore::ChallengeExpiredError =>
      ["challenge_invalid", "errors.webauthn.challenge_invalid", :bad_request],
    Webauthn::ChallengeStore::ChallengePurposeMismatchError =>
      ["challenge_binding_mismatch", "errors.webauthn.challenge_invalid", :bad_request],
    Webauthn::ChallengeStore::ChallengeBindingMismatchError =>
      ["challenge_binding_mismatch", "errors.webauthn.challenge_invalid", :bad_request],
    WebAuthn::SignCountVerificationError =>
      ["sign_count_mismatch", "errors.webauthn.sign_count_mismatch", :unauthorized],
    Webauthn::AssertionVerifier::VerificationError =>
      ["uv_rejected", "errors.webauthn.verification_failed", :unauthorized],
    WebAuthn::Error =>
      ["verification_failed", "errors.webauthn.verification_failed", :unauthorized],
  }.each do |error_class, (reason, error_key, status)|
    test "#{error_class} is refused as #{reason} and the challenge is discarded" do
      harness = verify_with(error_class)

      assert_equal [reason], harness.failures
      assert_equal [[error_key, status]], harness.errors
      assert_equal ["challenge-1"], harness.discarded,
                   "no path may leave a replayable challenge behind"
    end
  end

  test "an identifier is accepted by default and its two refusal keys agree" do
    harness = Harness.new

    assert harness.invoke(:valid_passkey_identifier?, "anything")
    assert_equal harness.invoke(:passkey_identifier_required_error_key),
                 harness.invoke(:passkey_identifier_invalid_error_key)
  end

  test "a restricted sign-in is recognised from the result and no surface claims a domain status" do
    harness = Harness.new

    assert harness.invoke(:passkey_success_restricted?, { restricted: true })
    assert_not harness.invoke(:passkey_success_restricted?, { restricted: false })
    assert_not harness.invoke(:handle_domain_specific_login_status, {})
  end
end
