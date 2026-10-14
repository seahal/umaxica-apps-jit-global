# typed: false
# frozen_string_literal: true

require "test_helper"

# Base app session-limit resolution. The parent ClientSignInFlow remains in
# SESSION_ISSUANCE_PENDING; the browser carries only the opaque gate for its durable child
# transaction (adr/root-login-establishment-boundary.md).
class Base::App::Sign::In::LimitationsControllerTest < ActionController::TestCase
  tests Base::App::Sign::In::LimitationsController

  setup do
    reference_now = ClientSignInFlow.database_now
    ClientSessionLimitResolutionState::DEFAULTS.each do |id|
      ClientSessionLimitResolutionState.find_or_create_by!(id: id) do |state|
        state.created_at = reference_now
        state.updated_at = reference_now
      end
    end
    ClientSignOutFlowKind.ensure_defaults!
    ClientSignOutFlowStatus.ensure_defaults!
    @request.host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    @actor = Client.create!(status_id: ClientStatus::NOTHING, birthdate: "2000-01-01")
    @existing = Array.new(ClientToken::MAX_SESSIONS_PER_USER) { ClientToken.create!(user: @actor) }
    now = ClientSignInFlow.database_now
    @flow = ClientSignInFlow.create!(
      principal_id: @actor.id,
      state_id: ClientSignInFlow.state_id_for("SESSION_ISSUANCE_PENDING"),
      nonce_digest: ClientSignInFlow.digest_nonce(SecureRandom.urlsafe_base64(32)),
      issued_at: now,
      expires_at: now + 5.minutes,
      authentication_method: "email",
      authentication_event_at: now,
      authentication_context: AuthenticationContextValue::NORMAL_KEY,
    )
    begin
      @binding = SecureRandom.urlsafe_base64(32)
      @issuance = ClientSessionLimitResolutionTransaction.issue!(
        actor: @actor,
        sign_in_flow: @flow,
        browser_binding_digest: ClientSessionLimitResolutionTransaction.digest_challenge(@binding),
      )
      @resolution = @issuance.transaction
      @gate =
        begin
          fv5015 = @issuance.challenge
          fv5014 = @binding
          fv5016 = @flow
          {
            "nonce" => SecureRandom.hex(16),
            "issued_at" => Time.current.to_i,
            "pt" => "/sign/in",
            "flow" => fv5016.public_id,
            "resolution_challenge" => fv5015,
            "resolution_binding" => fv5014,
            "actor_type" => "Client",
          }
        end
    end
  end

  test "the browser holding the pending flow sees its sessions" do
    get :show, params: { ri: "jp" }, session: { SessionLimitGate::GATE_SESSION_KEY => @gate }

    assert_response :success
  end

  test "without the flow locator the page refuses, whatever the request names" do
    get :show, params: { ri: "jp", social_resolution: "anything", actor_ref: @actor.public_id }

    assert_response :gone
  end

  test "a locator whose nonce does not match refuses" do
    get :show, params: { ri: "jp" },
               session: { SessionLimitGate::GATE_SESSION_KEY => @gate.merge("resolution_binding" => "wrong") }

    assert_response :gone
  end

  test "revoking one session commits the waiting flow exactly once" do
    ref = SessionLimitResolutionTokenRef.issue(@existing.first)
    begin
      begin
        { "Origin" => "http://#{@request.host}", "Sec-Fetch-Site" => "same-origin" }
      end.each { |fv5013, fv5012|
        @request.headers[fv5013] = fv5012
      }
    end

    assert_difference(-> { ClientToken.where(user_id: @actor.id).count }, 1) do
      patch :update, params: { ri: "jp", session_ref: ref },
                     session: { SessionLimitGate::GATE_SESSION_KEY => @gate }
    end

    assert_response :see_other
    assert_predicate @existing.first.reload, :revoked?
    issued = ClientToken.where(user_id: @actor.id).order(:id).last

    assert_equal issued.id, @flow.reload.token_id
    assert_not_nil issued.root_login_established_at
  end

  test "cancelling ends only the waiting flow" do
    begin
      begin
        { "Origin" => "http://#{@request.host}", "Sec-Fetch-Site" => "same-origin" }
      end.each { |fv5011, fv5010|
        @request.headers[fv5011] = fv5010
      }
    end
    delete :destroy, params: { ri: "jp" }, session: { SessionLimitGate::GATE_SESSION_KEY => @gate }

    assert_redirected_to base_app_sign_show_path(ri: "jp")
    assert_predicate @flow.reload, :sign_in_cancelled?
    assert_predicate @resolution.reload, :cancelled?
    assert(@existing.all? { |token| token.reload.active_status? })
    assert_nil session[:app_sign_in_flow_locator]
    assert_equal ClientToken::MAX_SESSIONS_PER_USER, ClientToken.where(user_id: @actor.id).count
  end

  test "an expired authenticated OIDC parent refuses capacity resolution before revoking a selected session" do
    now = ClientOidcAuthorizationTransaction.database_now
    parent = ClientOidcAuthorizationTransaction.create_transaction!(
      surface: "app", intent: "authentication", client_id: "revocation-test",
      redirect_uri: "https://rp.example.test/callback", response_type: "code", scope: "openid",
      state: SecureRandom.hex(16), nonce: SecureRandom.hex(16), code_challenge: "a" * 43,
      code_challenge_method: "S256", login_challenge: SecureRandom.hex(32),
      login_challenge_expires_at: now + 5.minutes, expires_at: now + 5.minutes,
    )
    parent.register_authentication!(
      actor_ref: @actor.public_id, session_ref: nil, auth_method: "passkey", acr: "aal1",
      authentication_event_at: now,
    )
    flow = ClientSignInFlow.create!(
      principal_id: @actor.id,
      state_id: ClientSignInFlow.state_id_for("SESSION_ISSUANCE_PENDING"),
      nonce_digest: ClientSignInFlow.digest_nonce(SecureRandom.urlsafe_base64(32)),
      issued_at: now,
      expires_at: now + 5.minutes,
    )
    raw_binding = SecureRandom.urlsafe_base64(32)
    issuance = ClientSessionLimitResolutionTransaction.issue!(
      actor: @actor,
      sign_in_flow: flow,
      browser_binding_digest: ClientSessionLimitResolutionTransaction.digest_challenge(raw_binding),
      oidc_authorization_transaction: parent,
    )
    oidc_gate =
      begin
        fv5008 = issuance.challenge
        fv5007 = raw_binding
        fv5009 = flow
        {
          "nonce" => SecureRandom.hex(16),
          "issued_at" => Time.current.to_i,
          "pt" => "/sign/in",
          "flow" => fv5009.public_id,
          "resolution_challenge" => fv5008,
          "resolution_binding" => fv5007,
          "actor_type" => "Client",
        }
      end
    parent.update!(expires_at: now - 1.second)
    ref = SessionLimitResolutionTokenRef.issue(@existing.first)

    get :show, params: { ri: "jp", resolution_challenge: issuance.challenge }, session: {
      SessionLimitGate::GATE_SESSION_KEY => oidc_gate,
    }

    assert_response :gone
    assert_no_difference(-> { ClientToken.where(user_id: @actor.id).count }) do
      begin
        begin
          { "Origin" => "http://#{@request.host}", "Sec-Fetch-Site" => "same-origin" }
        end.each { |fv5006, fv5005|
          @request.headers[fv5006] = fv5005
        }
      end
      patch :update, params: { ri: "jp", resolution_challenge: issuance.challenge, session_ref: ref }, session: {
        SessionLimitGate::GATE_SESSION_KEY => oidc_gate,
      }
    end

    assert_response :gone
    assert_predicate @existing.first.reload, :currently_usable?
    assert_nil parent.reload.base_finalized_at
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
    assert_predicate issuance.transaction.reload, :pending?
  end

  test "local result waiting on capacity resumes on Base without renewing its authentication time" do
    @resolution.cancel!(
      actor: @actor,
      challenge: @issuance.challenge,
      browser_binding_digest: ClientSessionLimitResolutionTransaction.digest_challenge(@binding),
    )
    @flow.cancel_sign_in!
    now = ClientSignInFlow.database_now
    local_nonce = SecureRandom.urlsafe_base64(32)
    @flow = ClientSignInFlow.create!(
      principal_id: @actor.id,
      state_id: ClientSignInFlow.state_id_for("SESSION_ISSUANCE_PENDING"),
      nonce_digest: ClientSignInFlow.digest_nonce(local_nonce),
      issued_at: now,
      expires_at: now + 5.minutes,
      authentication_method: "email",
      authentication_event_at: now,
      authentication_context: AuthenticationContextValue::NORMAL_KEY,
    )
    event_at = @flow.authentication_event_at
    @flow.prepare_local_result_delivery!(digest: "a" * 64, ttl: 1.minute)
    @flow.update!(result_expires_at: 1.second.ago)
    ceremony, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "local_sign_in",
      local_sign_in_flow_ref: @flow.public_id,
    )
    ceremony.record_authentication_evidence!(method: "email")
    @binding = SecureRandom.urlsafe_base64(32)
    @issuance = ClientSessionLimitResolutionTransaction.issue!(
      actor: @actor,
      sign_in_flow: @flow,
      browser_binding_digest: ClientSessionLimitResolutionTransaction.digest_challenge(@binding),
    )
    @resolution = @issuance.transaction
    @gate =
      begin
        fv5003 = @issuance.challenge
        fv5002 = @binding
        fv5004 = @flow
        {
          "nonce" => SecureRandom.hex(16),
          "issued_at" => Time.current.to_i,
          "pt" => "/sign/in",
          "flow" => fv5004.public_id,
          "resolution_challenge" => fv5003,
          "resolution_binding" => fv5002,
          "actor_type" => "Client",
        }
      end
    @local_locator = { "public_id" => @flow.public_id, "nonce" => local_nonce }
    ref = SessionLimitResolutionTokenRef.issue(@existing.first)
    begin
      begin
        { "Origin" => "http://#{@request.host}", "Sec-Fetch-Site" => "same-origin" }
      end.each { |fv5001, fv5000|
        @request.headers[fv5001] = fv5000
      }
    end

    assert_difference(-> { ClientToken.where(user_id: @actor.id).count }, 1) do
      patch :update, params: { ri: "jp", session_ref: ref },
                     session: {
                       SessionLimitGate::GATE_SESSION_KEY => @gate,
                       SignInCycleLocator::SESSION_KEYS.fetch(:app) => @local_locator,
                     }
    end

    assert_response :see_other
    assert_not_nil @flow.reload.completed_at
    token = ClientToken.find_by!(id: @flow.token_id, user_id: @actor.id)

    assert_equal event_at, token.authentication_event_at
    assert_equal "email", token.established_authentication_method
    assert_not_nil ceremony.reload.completed_at
  end

  private
end
