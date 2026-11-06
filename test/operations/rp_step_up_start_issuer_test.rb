# frozen_string_literal: true

require "test_helper"

class RpStepUpStartIssuerTest < ActiveSupport::TestCase
  fixtures :clients, :operators
  self.fixture_table_names = %w(clients operators)

  test "APP start creates one session-bound state and canonical authorization request" do
    actor = clients(:one)
    cell = RpCellBinding.fetch("rp_base_app")
    issuer = OidcIssuer.for_resource_type("client")
    subject = OidcSubject.for(actor, resource_type: "client")
    session_result = RpCallbackCommitter.call(
      cell:, issuer:, subject:, sid: "rp-step-up-app-sid", absolute_expires_at: 1.hour.from_now,
    )
    rp_session = session_result.session
    binding = RpBaseAppOpSessionBinding.includes(identity_binding: :principal).find(rp_session.op_session_binding_id)
    principal = binding.identity_binding.principal
    browser_binding = "a" * 43
    access_state = BrowserRpAuthentication::AccessState.new(
      status: :valid,
      resource: principal,
      rp_session:,
      payload: { "iss" => issuer,
                 "aud" => [cell.client_id],
                 "sid" => "rp-step-up-app-sid",
                 "sub" => subject,
                 "client_id" => cell.client_id,
                 "authn_ctx" => AuthenticationContextValue::NORMAL_KEY, },
      security_context: nil,
    )

    result = RpStepUpStartIssuer.call(
      cell:, access_state:, actor:, browser_binding:, return_target: "/settings/security",
    )

    authorization_uri = URI.parse(result.authorization_url)
    query = Rack::Utils.parse_nested_query(authorization_uri.query)
    client = OidcClientRegistry.find!(cell.client_id)
    callback_uri =
      client.redirect_uris_by_realm.fetch("client").find do |candidate|
        URI.parse(candidate).path == "/verification/oidc/callback"
      end
    state = RpStepUpState.find_by!(public_id: result.state_ref)
    raw_verifier = StepUpPkceVerifierCipherAdapter.decrypt(ciphertext: state.pkce_verifier_ciphertext)
    outbox = RpStepUpAuditOutbox.find_by!(context_ref: state.public_id)

    assert_equal "/settings/security", result.return_target
    assert_equal ["code", cell.client_id, callback_uri, "openid", "S256", "login"],
                 %w(response_type client_id redirect_uri scope code_challenge_method prompt).map { |key|
                   query.fetch(key)
                 }
    assert_nil query["acr_values"]
    assert_equal(
      {
        "id_token" => {
          "acr" => { "essential" => true, "value" => RpStepUpStartIssuer::STEP_UP_ACR },
          "auth_time" => { "essential" => true },
        },
      }, JSON.parse(query.fetch("claims")),
    )
    assert_equal Digest::SHA256.hexdigest(query.fetch("state")), state.state_digest
    assert_equal Digest::SHA256.hexdigest(query.fetch("nonce")), state.nonce_digest
    assert_equal Digest::SHA256.hexdigest(["op-mediated-step-up", cell.client_id, browser_binding].join("\0")),
                 state.browser_binding_digest
    assert_equal state.pkce_challenge, OidcPkce.challenge_for(raw_verifier)
    assert_not_includes state.pkce_verifier_ciphertext, raw_verifier
    assert_equal RpStepUpStateStatus::PENDING, state.state_id
    assert_in_delta RpStepUpStartIssuer::PENDING_TTL, state.expires_at - state.created_at, 1.second
    assert_equal rp_session.installed_generation, state.initiating_generation
    assert_equal "step_up.requested", outbox.event_type
    assert_equal "requested", outbox.reason_code
    assert_equal({ "rp_state_ref" => state.public_id, "return_target_kind" => "relative" }, outbox.payload)
    assert_equal 0, RpStepUpStateTransition.where(owner_id: state.id).count
  end

  test "ORG start uses the separate Base ORG store and callback registration" do
    actor = operators(:one)
    cell = RpCellBinding.fetch("rp_base_org")
    issuer = OidcIssuer.for_resource_type("operator")
    subject = OidcSubject.for(actor, resource_type: "operator")
    session_result = RpCallbackCommitter.call(
      cell:, issuer:, subject:, sid: "rp-step-up-org-sid", absolute_expires_at: 1.hour.from_now,
    )
    rp_session = session_result.session
    binding = RpBaseOrgOpSessionBinding.includes(identity_binding: :principal).find(rp_session.op_session_binding_id)
    principal = binding.identity_binding.principal
    access_state = BrowserRpAuthentication::AccessState.new(
      status: :valid,
      resource: principal,
      rp_session:,
      payload: { "iss" => issuer,
                 "aud" => [cell.client_id],
                 "sid" => "rp-step-up-org-sid",
                 "sub" => subject,
                 "client_id" => cell.client_id,
                 "authn_ctx" => AuthenticationContextValue::NORMAL_KEY, },
      security_context: nil,
    )

    result = RpStepUpStartIssuer.call(
      cell:, access_state:, actor:, browser_binding: "b" * 43, return_target: "/settings/security",
    )

    state = RpBaseOrgStepUpState.find_by!(public_id: result.state_ref)
    outbox = RpBaseOrgStepUpAuditOutbox.find_by!(context_ref: state.public_id)
    query = Rack::Utils.parse_nested_query(URI.parse(result.authorization_url).query)
    client = OidcClientRegistry.find!(cell.client_id)
    callback_uri =
      client.redirect_uris_by_realm.fetch("operator").find do |candidate|
        URI.parse(candidate).path == "/verification/oidc/callback"
      end

    assert_equal callback_uri, query.fetch("redirect_uri")
    assert_equal "ORG", state.realm
    assert_equal "base-org-ww", state.client_id
    assert_equal RpBaseOrgStepUpStateStatus::PENDING, state.state_id
    assert_equal "step_up.requested", outbox.event_type
  end

  test "start refuses another actor and unsafe return targets without creating state" do
    actor = clients(:one)
    cell = RpCellBinding.fetch("rp_base_app")
    issuer = OidcIssuer.for_resource_type("client")
    subject = OidcSubject.for(actor, resource_type: "client")
    session_result = RpCallbackCommitter.call(
      cell:, issuer:, subject:, sid: "rp-step-up-invalid-sid", absolute_expires_at: 1.hour.from_now,
    )
    rp_session = session_result.session
    binding = RpBaseAppOpSessionBinding.includes(identity_binding: :principal).find(rp_session.op_session_binding_id)
    principal = binding.identity_binding.principal
    access_state = BrowserRpAuthentication::AccessState.new(
      status: :valid,
      resource: principal,
      rp_session:,
      payload: { "iss" => issuer,
                 "aud" => [cell.client_id],
                 "sid" => "rp-step-up-invalid-sid",
                 "sub" => subject,
                 "client_id" => cell.client_id,
                 "authn_ctx" => AuthenticationContextValue::NORMAL_KEY, },
      security_context: nil,
    )
    states_before = RpStepUpState.count
    outboxes_before = RpStepUpAuditOutbox.count

    refusal =
      assert_raises(RpStepUpStartIssuer::Refused) do
        RpStepUpStartIssuer.call(
          cell:, access_state:, actor: operators(:one), browser_binding: "c" * 43,
          return_target: "/settings/security",
        )
      end
    assert_raises(ActionController::BadRequest) do
      RpStepUpStartIssuer.call(
        cell:, access_state:, actor:, browser_binding: "c" * 43,
        return_target: "https://attacker.example/",
      )
    end

    assert_equal states_before, RpStepUpState.count
    assert_equal outboxes_before, RpStepUpAuditOutbox.count
    assert_equal "authentication_context_invalid", refusal.reason_code
  end

  test "ORG start refuses a standby authentication context without creating state or audit" do
    actor = operators(:one)
    cell = RpCellBinding.fetch("rp_base_org")
    issuer = OidcIssuer.for_resource_type("operator")
    subject = OidcSubject.for(actor, resource_type: "operator")
    sid = "rp-step-up-standby-sid"
    rp_session = RpCallbackCommitter.call(
      cell:, issuer:, subject:, sid:, absolute_expires_at: 1.hour.from_now,
    ).session
    binding = RpBaseOrgOpSessionBinding.includes(identity_binding: :principal).find(rp_session.op_session_binding_id)
    access_state = BrowserRpAuthentication::AccessState.new(
      status: :valid,
      resource: binding.identity_binding.principal,
      rp_session:,
      payload: {
        "iss" => issuer,
        "aud" => [cell.client_id],
        "sid" => sid,
        "sub" => subject,
        "client_id" => cell.client_id,
        "authn_ctx" => AuthenticationContextValue::STANDBY_KEY,
      },
      security_context: nil,
    )
    states_before = RpBaseOrgStepUpState.count
    outboxes_before = RpBaseOrgStepUpAuditOutbox.count

    refusal =
      assert_raises(RpStepUpStartIssuer::Refused) do
        RpStepUpStartIssuer.call(
          cell:, access_state:, actor:, browser_binding: "d" * 43, return_target: "/identity",
        )
      end

    assert_equal states_before, RpBaseOrgStepUpState.count
    assert_equal outboxes_before, RpBaseOrgStepUpAuditOutbox.count
    assert_equal "authentication_context_invalid", refusal.reason_code
  end
end
