# typed: false
# frozen_string_literal: true

require "test_helper"

# Base app session-limit resolution. The parent ClientSignInFlow remains in
# SESSION_ISSUANCE_PENDING; the browser carries only the opaque gate for its durable child
# transaction (adr/root-login-establishment-boundary.md).
class Visa::App::Sign::In::LimitationsControllerTest < ActionController::TestCase
  tests Visa::App::Sign::In::LimitationsController

  setup do
    reference_now = ClientSignInFlow.database_now
    ClientSessionLimitResolutionState::DEFAULTS.each do |id|
      ClientSessionLimitResolutionState.find_or_create_by!(id: id) do |state|
        state.created_at = reference_now
        state.updated_at = reference_now
      end
    end
    @request.host = Rails.configuration.x.boot_config.fetch(:hosts).visa_service.host
    @actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::NOTHING,
      birthdate: "2000-01-01",
    )
    @existing = Array.new(ClientToken::MAX_SESSIONS_PER_USER) { ClientToken.create!(authentication_epoch: 0, user: @actor) }
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

  test "explicit continue completes without revoking when capacity becomes free" do
    @existing.first.revoke!

    post :update, params: { ri: "jp", continue: "1" },
                  session: { SessionLimitGate::GATE_SESSION_KEY => @gate }

    assert_response :see_other
    assert_predicate @flow.reload, :sign_in_completed?
    assert_predicate @resolution.reload, :resolved?
    assert_nil @resolution.selected_session_ref
    assert_not_predicate @existing.first.reload, :currently_usable?
    assert_equal ClientToken::MAX_SESSIONS_PER_USER,
                 ClientToken.active_status.where(user_id: @actor.id).count
  end

  test "a selected session that expires before continuation keeps the waiting resolution" do
    ref = SessionLimitResolutionTokenRef.issue(@existing.first)
    @resolution.select_session!(
      actor: @actor,
      challenge: @issuance.challenge,
      session_ref: @existing.first.public_id,
      browser_binding_digest: ClientSessionLimitResolutionTransaction.digest_challenge(@binding),
    )
    @existing.first.revoke!

    patch :update, params: { ri: "jp", session_ref: ref },
                   session: { SessionLimitGate::GATE_SESSION_KEY => @gate }

    assert_response :unprocessable_content
    assert_not_predicate @existing.first.reload, :currently_usable?
    assert_predicate @resolution.reload, :session_selected?
    assert_predicate @resolution, :open?
    assert_nil @flow.reload.token_id
    assert_equal @existing.length, ClientToken.where(user_id: @actor.id).count
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
    @resolution.cancel!(
      actor: @actor,
      challenge: @issuance.challenge,
      browser_binding_digest: ClientSessionLimitResolutionTransaction.digest_challenge(@binding),
    )
    now = ClientOidcAuthorizationTransaction.database_now
    parent = ClientOidcAuthorizationTransaction.create_transaction!(
      surface: "app", intent: "authentication", client_id: "revocation-test",
      redirect_uri: "https://rp.example.test/callback", response_type: "code", scope: "openid",
      state: SecureRandom.hex(16), nonce: SecureRandom.hex(16),
      code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
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

  private
end
