# typed: false
# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

# adr/operator-capability-authorization.md: a support session revocation completed through the real
# Step-Up ceremony. Only the WebAuthn cryptographic assertion is stubbed (as in the other org
# verification tests); the base intent, the signed grant, the auth ceremony, the signed result, the
# base completion, the return to the confirmation screen, the mutation, and the audit all run as in
# production. The operator's session token is never written to directly.
class OrgAdminStepUpCeremonyTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_tokens, :clients

  setup do
    @base_host = ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost")
    @auth_host = ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost")
    @operator = operators(:one)
    @token = operator_tokens(:one)
    @passkey = OperatorPasskey.create!(
      staff: @operator, webauthn_id: "org_admin_ceremony_#{SecureRandom.hex(8)}", external_id: SecureRandom.uuid,
      public_key: "org-admin-ceremony-public-key", sign_count: 0, description: "Admin ceremony passkey",
      status_id: OperatorPasskeyStatus::ACTIVE,
    )
    @client = clients(:one)
    AuthenticationSessionRevoker.tokens_for(@client).find_each(&:revoke!)
    # The compliance row normally comes from migration 20260926130000 (365 days, decided 2026-09-26);
    # a schema-only load skips that insert, so the test ensures it with the same value.
    ChronicleRetentionPolicy.find_or_create_by!(code: "compliance") do |policy|
      policy.name = "Compliance"
      policy.duration_days = 365
      policy.permanent = false
    end
  end

  test "revocation passes capability, the real Step-Up ceremony, returns to the screen, and is audited" do
    [OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_APP,
     OperatorCapabilityGrant::SUPPORT_SESSION_REVOKE_APP,].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator, origin: "bootstrap", capability: capability,
        reason_code: "bootstrap", starts_at: 1.minute.ago, expires_at: 1.day.from_now,
      )
    end
    target_session = ClientToken.create!(user: @client, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    # A browser sends each host's session cookie alongside the access credential. An explicit Cookie
    # header would replace the integration cookie jar and drop the auth host's session, which holds
    # the WebAuthn challenge, so the access token travels only as the bearer credential here.
    base_headers = as_staff_headers(@operator, host: @base_host, session_public_id: @token.public_id)
      .except("Cookie", "HTTP_COOKIE")
    auth_headers = as_staff_headers(@operator, host: @auth_host, session_public_id: @token.public_id)
      .except("Cookie", "HTTP_COOKIE")
    screen_path = new_base_org_support_client_revocation_path(@client.public_id, ri: "jp")

    # 1. The confirmation screen asks for Step-Up and sends the operator to the base intent.
    get new_base_org_support_client_revocation_url(@client.public_id, ri: "jp", host: @base_host), headers: base_headers

    assert_response :redirect
    intent_uri = URI.parse(response.location)

    assert_equal "support_session_revoke", Rack::Utils.parse_query(intent_uri.query)["scope"]

    # 2. The base intent issues a signed grant bound to this operator, session, and scope.
    get response.location, headers: base_headers

    assert_response :see_other
    gateway = URI.parse(response.location)
    assert_equal "jump.umaxica.net", gateway.host
    payload, = JWT.decode(Rack::Utils.parse_nested_query(gateway.query).fetch("rt"), nil, false)
    auth_location = payload.fetch("url")
    grant_query = Rack::Utils.parse_query(URI.parse(auth_location).query)
    transaction = OperatorStepUpCeremonyTransaction.order(:created_at).last

    assert_equal "support_session_revoke", transaction.required_scope
    assert_predicate grant_query["step_up_ceremony_grant"], :present?

    StepUpAvailableMethods.stub(:call, [:passkey]) do
      WebAuthn::Credential.stub(:options_for_get, OpenStruct.new(id: "challenge")) do
        assertion = Struct.new(:sign_count, :verified_at).new(1, Time.current)
        Webauthn::AssertionVerifier.stub(:verify!, assertion) do
          # 3. The auth ceremony accepts the grant and verifies the passkey.
          get auth_location, headers: auth_headers

          assert_response :success
          get new_auth_org_verification_passkey_url(ri: "jp", host: @auth_host), headers: auth_headers
          post auth_org_verification_passkey_url(ri: "jp", host: @auth_host),
               params: { verification: { challenge_id: session[:passkey_challenges].keys.first,
                                         credential_json: { id: @passkey.webauthn_id }.to_json, } },
               headers: auth_headers

          assert_response :success
          assert_includes response.body, "step-up-completion-form"
          assert_nil @token.reload.last_step_up_at, "the auth ceremony does not write base freshness"

          # 4. The signed result is posted to the base completion, which commits freshness.
          submit_step_up_completion_if_present!(host: @base_host, headers: base_headers)
        end
      end
    end

    assert_response :see_other
    assert_equal screen_path, URI.parse(response.location).request_uri
    @token.reload

    assert_equal "support_session_revoke", @token.last_step_up_scope
    assert_equal "step_up:org", @token.last_step_up_audience
    assert_equal @token.public_id, @token.last_step_up_session_public_id
    assert_equal "passkey", @token.last_step_up_method
    # The admin scopes carry no AAL floor (StepUpRequirement::NO_AAL); a passkey Step-Up records aal1.
    assert_equal "aal1", @token.last_step_up_aal

    # 5. Back on the screen, the mutation succeeds and is audited.
    get response.location, headers: base_headers

    assert_response :ok
    operation_id = inertia_props.fetch("fields").find { |field| field["name"] == "operation_id" }.fetch("value")

    post base_org_support_client_revocations_url(@client.public_id, host: @base_host),
         params: { reason_code: "security_incident", operation_id: operation_id }, headers: base_headers

    assert_response :see_other
    assert_predicate target_session.reload, :revoked?
    chronicle = Chronicle.find_by!(event_uuid: operation_id)

    assert_equal ["support.session.revoked", "succeeded"], [chronicle.action, chronicle.result]
    assert_equal ["Operator", @operator.id], [chronicle.actor_type, chronicle.actor_id]
  end

  test "Step-Up freshness for another scope does not satisfy the revocation" do
    [OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_APP,
     OperatorCapabilityGrant::SUPPORT_SESSION_REVOKE_APP,].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator, origin: "bootstrap", capability: capability,
        reason_code: "bootstrap", starts_at: 1.minute.ago, expires_at: 1.day.from_now,
      )
    end
    issuance = IdentityStepUpCeremonyGrantIssuer.issue!(
      surface: "org", actor_ref: @operator.public_id, session_ref: @token.public_id,
      required_scope: "session_revoke_all", required_aal: StepUpRequirement::NO_AAL, allowed_methods: ["passkey"],
      return_to: "/identity/sessions", expires_at: 5.minutes.from_now,
    )
    transaction = issuance.transaction
    result = IdentityStepUpCeremonyResultIssuer.issue!(
      surface: "org", actor_ref: @operator.public_id, session_ref: @token.public_id,
      transaction_id: transaction.transaction_id, grant_jti: transaction.grant_jti,
      scope: transaction.required_scope, aal: "aal1", method: "passkey",
      challenge_id: "challenge-#{SecureRandom.hex(4)}", expires_at: transaction.expires_at,
    )
    base_headers = as_staff_headers(@operator, host: @base_host, session_public_id: @token.public_id)
    post base_org_verification_completion_url(ri: "jp", host: @base_host),
         params: { step_up_ceremony_result: result }, headers: base_headers

    assert_equal "session_revoke_all", @token.reload.last_step_up_scope

    get new_base_org_support_client_revocation_url(@client.public_id, ri: "jp", host: @base_host), headers: base_headers

    assert_response :redirect
    assert_includes response.location, "scope=support_session_revoke"
  end

  test "an Emergency session cannot start the ceremony for an administrative scope" do
    [OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_APP,
     OperatorCapabilityGrant::SUPPORT_SESSION_REVOKE_APP,].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator, origin: "bootstrap", capability: capability,
        reason_code: "bootstrap", starts_at: 1.minute.ago, expires_at: 1.day.from_now,
      )
    end
    OperatorToken.where(staff_id: @operator.id).destroy_all
    emergency = OperatorToken.create!(
      staff: @operator, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE, discard_at: 30.days.from_now,
      staff_token_binding_method_id: OperatorTokenBindingMethod::LEGACY,
      authentication_context: AuthenticationContextValue::EMERGENCY_KEY,
    )
    headers = as_staff_headers(@operator, host: @base_host, session_public_id: emergency.public_id)

    assert_no_difference -> { OperatorStepUpCeremonyTransaction.count } do
      get new_base_org_support_client_revocation_url(@client.public_id, ri: "jp", host: @base_host), headers: headers
    end

    assert_response :forbidden
  end

  test "a result for another session, for another surface, or replayed does not satisfy Step-Up" do
    [OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_APP,
     OperatorCapabilityGrant::SUPPORT_SESSION_REVOKE_APP,].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator, origin: "bootstrap", capability: capability,
        reason_code: "bootstrap", starts_at: 1.minute.ago, expires_at: 1.day.from_now,
      )
    end
    other_session = OperatorToken.create!(staff: @operator, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    base_headers = as_staff_headers(@operator, host: @base_host, session_public_id: @token.public_id)
      .except("Cookie", "HTTP_COOKIE")
    screen = new_base_org_support_client_revocation_path(@client.public_id, ri: "jp")

    # Another session's ceremony.
    foreign = IdentityStepUpCeremonyGrantIssuer.issue!(
      surface: "org", actor_ref: @operator.public_id, session_ref: other_session.public_id,
      required_scope: "support_session_revoke", required_aal: StepUpRequirement::NO_AAL,
      allowed_methods: ["passkey"], return_to: screen, expires_at: 5.minutes.from_now,
    ).transaction
    foreign_result = IdentityStepUpCeremonyResultIssuer.issue!(
      surface: "org", actor_ref: @operator.public_id, session_ref: other_session.public_id,
      transaction_id: foreign.transaction_id, grant_jti: foreign.grant_jti, scope: foreign.required_scope,
      aal: "aal1", method: "passkey", challenge_id: "c-#{SecureRandom.hex(4)}", expires_at: foreign.expires_at,
    )
    post base_org_verification_completion_url(ri: "jp", host: @base_host),
         params: { step_up_ceremony_result: foreign_result }, headers: base_headers

    assert_nil @token.reload.last_step_up_at, "another session's result is not committed to this session"

    # A result signed for the app surface.
    app_grant = IdentityStepUpCeremonyGrantIssuer.issue!(
      surface: "app", actor_ref: @operator.public_id, session_ref: @token.public_id,
      required_scope: "session_revoke_all", required_aal: StepUpRequirement::NO_AAL,
      allowed_methods: ["passkey"], return_to: "/identity/sessions", expires_at: 5.minutes.from_now,
    ).transaction
    app_result = IdentityStepUpCeremonyResultIssuer.issue!(
      surface: "app", actor_ref: @operator.public_id, session_ref: @token.public_id,
      transaction_id: app_grant.transaction_id, grant_jti: app_grant.grant_jti, scope: app_grant.required_scope,
      aal: "aal1", method: "passkey", challenge_id: "c-#{SecureRandom.hex(4)}", expires_at: app_grant.expires_at,
    )
    post base_org_verification_completion_url(ri: "jp", host: @base_host),
         params: { step_up_ceremony_result: app_result }, headers: base_headers

    assert_nil @token.reload.last_step_up_at, "a result signed for another surface is rejected"

    # A valid result, then its replay.
    own = IdentityStepUpCeremonyGrantIssuer.issue!(
      surface: "org", actor_ref: @operator.public_id, session_ref: @token.public_id,
      required_scope: "support_session_revoke", required_aal: StepUpRequirement::NO_AAL,
      allowed_methods: ["passkey"], return_to: screen, expires_at: 5.minutes.from_now,
    ).transaction
    own_result = IdentityStepUpCeremonyResultIssuer.issue!(
      surface: "org", actor_ref: @operator.public_id, session_ref: @token.public_id,
      transaction_id: own.transaction_id, grant_jti: own.grant_jti, scope: own.required_scope,
      aal: "aal1", method: "passkey", challenge_id: "c-#{SecureRandom.hex(4)}", expires_at: own.expires_at,
    )
    post base_org_verification_completion_url(ri: "jp", host: @base_host),
         params: { step_up_ceremony_result: own_result }, headers: base_headers
    first_commit = @token.reload.last_step_up_at

    assert_not_nil first_commit

    travel 1.minute do
      post base_org_verification_completion_url(ri: "jp", host: @base_host),
           params: { step_up_ceremony_result: own_result }, headers: base_headers

      assert_equal first_commit, @token.reload.last_step_up_at, "a replayed result does not refresh freshness"
    end
  end

  test "Step-Up freshness expires after its window" do
    [OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_APP,
     OperatorCapabilityGrant::SUPPORT_SESSION_REVOKE_APP,].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator, origin: "bootstrap", capability: capability,
        reason_code: "bootstrap", starts_at: 1.minute.ago, expires_at: 2.days.from_now,
      )
    end
    base_headers = as_staff_headers(@operator, host: @base_host, session_public_id: @token.public_id)
      .except("Cookie", "HTTP_COOKIE")
    screen = new_base_org_support_client_revocation_path(@client.public_id, ri: "jp")
    grant = IdentityStepUpCeremonyGrantIssuer.issue!(
      surface: "org", actor_ref: @operator.public_id, session_ref: @token.public_id,
      required_scope: "support_session_revoke", required_aal: StepUpRequirement::NO_AAL,
      allowed_methods: ["passkey"], return_to: screen, expires_at: 5.minutes.from_now,
    ).transaction
    result = IdentityStepUpCeremonyResultIssuer.issue!(
      surface: "org", actor_ref: @operator.public_id, session_ref: @token.public_id,
      transaction_id: grant.transaction_id, grant_jti: grant.grant_jti, scope: grant.required_scope,
      aal: "aal1", method: "passkey", challenge_id: "c-#{SecureRandom.hex(4)}", expires_at: grant.expires_at,
    )
    post base_org_verification_completion_url(ri: "jp", host: @base_host),
         params: { step_up_ceremony_result: result }, headers: base_headers

    get new_base_org_support_client_revocation_url(@client.public_id, ri: "jp", host: @base_host), headers: base_headers

    assert_response :ok, "fresh Step-Up opens the screen"

    travel StepUpRequirement::DEFAULT_TTL + 1.second do
      get new_base_org_support_client_revocation_url(@client.public_id, ri: "jp", host: @base_host),
          headers: as_staff_headers(@operator, host: @base_host, session_public_id: @token.public_id)
            .except("Cookie", "HTTP_COOKIE")

      assert_response :redirect
      assert_includes response.location, "scope=support_session_revoke"
    end
  end

  test "the return target cannot be forged or reused for a different scope" do
    [OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_APP,
     OperatorCapabilityGrant::SUPPORT_SESSION_REVOKE_APP,].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator, origin: "bootstrap", capability: capability,
        reason_code: "bootstrap", starts_at: 1.minute.ago, expires_at: 1.day.from_now,
      )
    end
    base_headers = as_staff_headers(@operator, host: @base_host, session_public_id: @token.public_id)
      .except("Cookie", "HTTP_COOKIE")
    get new_base_org_support_client_revocation_url(@client.public_id, ri: "jp", host: @base_host), headers: base_headers
    signed_pt = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("pt")

    assert_no_difference -> { OperatorStepUpCeremonyTransaction.count } do
      get base_org_verification_url(scope: "support_session_revoke", pt: "forged-target", ri: "jp", host: @base_host),
          headers: base_headers

      assert_response :bad_request

      get base_org_verification_url(scope: "session_revoke_all", pt: signed_pt, ri: "jp", host: @base_host),
          headers: base_headers

      assert_response :bad_request
    end
  end
end
