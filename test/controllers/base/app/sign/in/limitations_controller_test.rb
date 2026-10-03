# typed: false
# frozen_string_literal: true

require "test_helper"

# Base app session-limit resolution for a social sign-in. The pending state is the verified
# ClientSignInFlow in SESSION_LIMIT_PENDING, located only through the flow locator in this
# browser's Rails session; the request carries no grant (adr/root-login-establishment-boundary.md).
class Base::App::Sign::In::LimitationsControllerTest < ActionController::TestCase
  tests Base::App::Sign::In::LimitationsController

  setup do
    @request.host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    @actor = Client.create!(status_id: ClientStatus::NOTHING, birthdate: "2000-01-01")
    @existing = Array.new(ClientToken::MAX_SESSIONS_PER_USER) { ClientToken.create!(user: @actor) }
    @flow = ClientSignInFlow.create!(
      principal_id: @actor.id,
      status_id: ClientSignInFlow.status_id_for("SESSION_LIMIT_PENDING"),
      state: "SESSION_LIMIT_PENDING",
      step: "session_limit",
      nonce_digest: ClientSignInFlow.digest_nonce("unused"),
    )
    @locator = { "public_id" => @flow.public_id, "nonce" => SecureRandom.urlsafe_base64(32) }
    @flow.update!(nonce_digest: ClientSignInFlow.digest_nonce(@locator.fetch("nonce")))
  end

  test "the browser holding the pending flow sees its sessions" do
    get :show, params: { ri: "jp" }, session: { app_sign_in_flow_locator: @locator }

    assert_response :success
  end

  test "without the flow locator the page refuses, whatever the request names" do
    get :show, params: { ri: "jp", social_resolution: "anything", actor_ref: @actor.public_id }

    assert_response :gone
  end

  test "a locator whose nonce does not match refuses" do
    get :show, params: { ri: "jp" },
               session: { app_sign_in_flow_locator: @locator.merge("nonce" => "wrong") }

    assert_response :gone
  end

  test "revoking one session commits the waiting flow exactly once" do
    ref = SessionLimitResolutionTokenRef.issue(@existing.first)

    assert_difference(-> { ClientToken.where(user_id: @actor.id).count }, 1) do
      patch :update, params: { ri: "jp", session_ref: ref }, session: { app_sign_in_flow_locator: @locator }
    end

    assert_response :see_other
    assert_predicate @existing.first.reload, :revoked?
    issued = ClientToken.where(user_id: @actor.id).order(:id).last

    assert_equal issued.id, @flow.reload.token_id
    assert_not_nil issued.root_login_established_at
  end

  test "cancelling ends only the waiting flow" do
    delete :destroy, params: { ri: "jp" }, session: { app_sign_in_flow_locator: @locator }

    assert_predicate @flow.reload, :sign_in_failed?
    assert(@existing.all? { |token| token.reload.active_status? })
  end

  test "local result waiting on capacity resumes on Base without renewing its authentication time" do
    @flow.record_local_authentication_evidence!(method: "email")
    event_at = @flow.authentication_event_at
    @flow.prepare_local_result_delivery!(digest: "a" * 64, ttl: 1.minute)
    @flow.update!(result_expires_at: 1.second.ago)
    ceremony, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "local_sign_in",
      local_sign_in_flow_ref: @flow.public_id,
    )
    ceremony.record_authentication_evidence!(method: "email")
    ref = SessionLimitResolutionTokenRef.issue(@existing.first)

    assert_difference(-> { ClientToken.where(user_id: @actor.id).count }, 1) do
      patch :update, params: { ri: "jp", session_ref: ref }, session: { app_sign_in_flow_locator: @locator }
    end

    assert_response :see_other
    assert_not_nil @flow.reload.base_finalized_at
    assert_equal event_at, @flow.token.authentication_event_at
    assert_equal "email", @flow.token.established_authentication_method
    assert_not_nil ceremony.reload.completed_at
  end
end
