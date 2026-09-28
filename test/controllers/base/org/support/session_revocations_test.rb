# typed: false
# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

# adr/operator-capability-authorization.md, Support: app-realm Client and com-realm Visitor lookup and
# forced session revocation. Every test grants the capabilities it relies on in its own body.
class Base::Org::Support::SessionRevocationsTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost")
    @operator = operators(:one)
    @granter = operators(:two)
    @operator_token = OperatorToken.create!(
      staff: @operator,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      staff_token_binding_method_id: OperatorTokenBindingMethod::LEGACY,
      staff_token_dbsc_status_id: OperatorTokenDbscStatus::NOTHING,
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

  test "support pages are routed only on the org host" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{ENV.fetch(
          "PUBLIC_BASE_SERVICE_URL",
          "base.app.localhost",
        )}/support/clients/#{@client.public_id}/revocations",
        method: :post,
      )
    end
  end

  test "creating a revocation is not reachable with GET" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{@host}/support/clients/#{@client.public_id}/revocations", method: :delete,
      )
    end
  end

  test "an operator with no grant cannot list clients" do
    get base_org_support_clients_url(ri: "jp", host: @host),
        headers: as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id),
        as: :json

    assert_response :forbidden
  end

  test "the app read capability lists and shows clients without exposing identifiers" do
    OperatorCapabilityGrant.create!(
      operator: @operator,
      granted_by_operator: @granter,
      origin: "grant",
      capability: OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_APP,
      reason_code: "duty_assignment",
      starts_at: 1.minute.ago,
      expires_at: 1.day.from_now,
    )

    get base_org_support_clients_url(q: @client.public_id, ri: "jp", host: @host),
        headers: as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id)

    assert_response :ok
    assert_equal "base/org/support/clients/index", inertia_component
    assert_equal [@client.public_id], inertia_props.fetch("rows").map { |row| row.fetch("key") }
    assert_equal @operator.public_id, inertia_props.dig("context", "operator_public_id")
    assert_equal "app", inertia_props.dig("context", "realm")

    get base_org_support_client_url(@client.public_id, ri: "jp", host: @host),
        headers: as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id)

    assert_response :ok
    assert_equal "private, no-store", response.headers["Cache-Control"]
    assert_empty inertia_props.fetch("actions"), "read-only operators are offered no operation"
    @client.client_emails.each { |email| assert_not_includes response.body, email.address.to_s }
  end

  test "an app grant does not reach com visitors" do
    OperatorCapabilityGrant.create!(
      operator: @operator,
      granted_by_operator: @granter,
      origin: "grant",
      capability: OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_APP,
      reason_code: "duty_assignment",
      starts_at: 1.minute.ago,
      expires_at: 1.day.from_now,
    )

    get base_org_support_visitor_url(visitors(:reserved_visitor).public_id, ri: "jp", host: @host),
        headers: as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id),
        as: :json

    assert_response :forbidden
  end

  test "a visitor public id under the clients resource is not found" do
    OperatorCapabilityGrant.create!(
      operator: @operator,
      granted_by_operator: @granter,
      origin: "grant",
      capability: OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_APP,
      reason_code: "duty_assignment",
      starts_at: 1.minute.ago,
      expires_at: 1.day.from_now,
    )

    get base_org_support_client_url(visitors(:reserved_visitor).public_id, ri: "jp", host: @host),
        headers: as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id)

    assert_response :not_found
  end

  test "search and page inputs outside their contract are bad requests, not empty lists" do
    OperatorCapabilityGrant.create!(
      operator: @operator,
      granted_by_operator: @granter,
      origin: "grant",
      capability: OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_APP,
      reason_code: "duty_assignment",
      starts_at: 1.minute.ago,
      expires_at: 1.day.from_now,
    )
    headers = as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id)

    [{ q: "a b" }, { q: "x\u0000" }, { q: " x" }, { q: "a" * 65 }, { page: "0" }, { page: "-1" }, { page: "401" },
     { page: "abc" },].each do |query|
      get base_org_support_clients_url(**query, ri: "jp", host: @host), headers: headers

      assert_response :bad_request, "expected #{query.inspect} to be rejected"
    end
  end

  test "search length boundary: 63 and 64 characters are accepted" do
    OperatorCapabilityGrant.create!(
      operator: @operator,
      granted_by_operator: @granter,
      origin: "grant",
      capability: OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_APP,
      reason_code: "duty_assignment",
      starts_at: 1.minute.ago,
      expires_at: 1.day.from_now,
    )
    headers = as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id)

    [63, 64].each do |length|
      get base_org_support_clients_url(q: "a" * length, ri: "jp", host: @host), headers: headers

      assert_response :ok
    end
  end

  test "page boundary: 399 and 400 are accepted, empty means the first page" do
    OperatorCapabilityGrant.create!(
      operator: @operator,
      granted_by_operator: @granter,
      origin: "grant",
      capability: OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_APP,
      reason_code: "duty_assignment",
      starts_at: 1.minute.ago,
      expires_at: 1.day.from_now,
    )
    headers = as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id)

    %w(399 400 1).each do |page|
      get base_org_support_clients_url(page: page, ri: "jp", host: @host), headers: headers

      assert_response :ok
    end
    get base_org_support_clients_url(page: "", ri: "jp", host: @host), headers: headers

    assert_response :ok
  end

  test "the revocation screen needs the revoke capability before it asks for Step-Up" do
    OperatorCapabilityGrant.create!(
      operator: @operator,
      granted_by_operator: @granter,
      origin: "grant",
      capability: OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_APP,
      reason_code: "duty_assignment",
      starts_at: 1.minute.ago,
      expires_at: 1.day.from_now,
    )

    get new_base_org_support_client_revocation_url(@client.public_id, ri: "jp", host: @host),
        headers: as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id),
        as: :json

    assert_response :forbidden
  end

  test "with the revoke capability but no Step-Up, the screen sends the operator to the ceremony" do
    [OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_APP,
     OperatorCapabilityGrant::SUPPORT_SESSION_REVOKE_APP,].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator,
        granted_by_operator: @granter,
        origin: "grant",
        capability: capability,
        reason_code: "duty_assignment",
        starts_at: 1.minute.ago,
        expires_at: 1.day.from_now,
      )
    end

    get new_base_org_support_client_revocation_url(@client.public_id, ri: "jp", host: @host),
        headers: as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id)

    assert_response :redirect
    assert_includes response.location, "scope=support_session_revoke"
  end

  test "the Step-Up return path for this screen is catalogued, and the org enforcement realm is not" do
    pattern = StepUpScopeCatalog::ORG.fetch("support_session_revoke")

    assert_match pattern, "/support/clients/#{@client.public_id}/revocations/new"
    assert_match pattern, "/support/visitors/ABC123/revocations/new"
    assert_no_match pattern, "/support/operators/ABC123/revocations/new"
    assert_no_match pattern, "/support/clients/#{@client.public_id}/revocations"
    assert_no_match StepUpScopeCatalog::ORG.fetch("enforcement_case_apply"), "/support/org/enforcement_cases/new"
  end

  test "an operator with capability and Step-Up revokes a client's sessions and sees the recorded result" do
    [OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_APP,
     OperatorCapabilityGrant::SUPPORT_SESSION_REVOKE_APP,].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator,
        granted_by_operator: @granter,
        origin: "grant",
        capability: capability,
        reason_code: "duty_assignment",
        starts_at: 1.minute.ago,
        expires_at: 1.day.from_now,
      )
    end
    @operator_token.update_columns( # rubocop:disable Rails/SkipsModelValidations
      last_step_up_at: Time.current,
      last_step_up_scope: "support_session_revoke",
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_session_public_id: @operator_token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:org",
    )
    token = ClientToken.create!(user: @client, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    operation_id = SecureRandom.uuid

    post base_org_support_client_revocations_url(@client.public_id, host: @host),
         params: { reason_code: "security_incident", ticket_id: "SEC-635", operation_id: operation_id },
         headers: as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id)

    assert_response :see_other
    assert_redirected_to base_org_support_client_revocation_url(@client.public_id, operation_id, host: @host)
    assert_predicate token.reload, :revoked?
    chronicle = Chronicle.find_by!(event_uuid: operation_id)

    assert_equal "succeeded", chronicle.result
    assert_equal "support.session.revoked", chronicle.action
    assert_equal ["Operator", @operator.id], [chronicle.actor_type, chronicle.actor_id]
    assert_equal ["Client", @client.id], [chronicle.subject_type, chronicle.subject_id]
    assert_equal "app", chronicle.metadata.fetch("realm")
    assert_equal 1, chronicle.changeset.fetch("revoked_count")
    assert_equal "enabled", @client.reload.access_state, "a revocation is not an access lock"

    get base_org_support_client_revocation_url(@client.public_id, operation_id, ri: "jp", host: @host),
        headers: as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id)

    assert_response :ok
    assert_empty inertia_props.fetch("notices")
    assert_includes inertia_props.fetch("fields").map { |field| field.fetch("description") }, @operator.public_id
  end

  test "a session created after the revocation is untouched: revocation ends what existed, it does not lock" do
    [OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_APP,
     OperatorCapabilityGrant::SUPPORT_SESSION_REVOKE_APP,].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator,
        granted_by_operator: @granter,
        origin: "grant",
        capability: capability,
        reason_code: "duty_assignment",
        starts_at: 1.minute.ago,
        expires_at: 1.day.from_now,
      )
    end
    @operator_token.update_columns( # rubocop:disable Rails/SkipsModelValidations
      last_step_up_at: Time.current,
      last_step_up_scope: "support_session_revoke",
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_session_public_id: @operator_token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:org",
    )
    before = ClientToken.create!(user: @client, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    post base_org_support_client_revocations_url(@client.public_id, host: @host),
         params: { reason_code: "support_request", operation_id: SecureRandom.uuid },
         headers: as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id)
    after = ClientToken.create!(user: @client, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    assert_predicate before.reload, :revoked?
    assert_not_predicate after.reload, :revoked?
  end

  test "resubmitting the same operation does not revoke again; reusing its id for another target conflicts" do
    [
      OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_APP, OperatorCapabilityGrant::SUPPORT_SESSION_REVOKE_APP,
      OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_COM, OperatorCapabilityGrant::SUPPORT_SESSION_REVOKE_COM,
    ].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator,
        granted_by_operator: @granter,
        origin: "grant",
        capability: capability,
        reason_code: "duty_assignment",
        starts_at: 1.minute.ago,
        expires_at: 1.day.from_now,
      )
    end
    @operator_token.update_columns( # rubocop:disable Rails/SkipsModelValidations
      last_step_up_at: Time.current,
      last_step_up_scope: "support_session_revoke",
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_session_public_id: @operator_token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:org",
    )
    operation_id = SecureRandom.uuid
    headers = as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id)

    assert_difference -> { AccountAccessEvent.count }, 1 do
      2.times do
        post base_org_support_client_revocations_url(@client.public_id, host: @host),
             params: { reason_code: "security_incident", operation_id: operation_id },
             headers: headers

        assert_response :see_other
      end
    end

    post base_org_support_visitor_revocations_url(visitors(:reserved_visitor).public_id, host: @host),
         params: { reason_code: "security_incident", operation_id: operation_id },
         headers: headers

    assert_response :conflict
  end

  test "reason codes, ticket ids, and operation ids outside their contract are refused without revoking" do
    [OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_APP,
     OperatorCapabilityGrant::SUPPORT_SESSION_REVOKE_APP,].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator,
        granted_by_operator: @granter,
        origin: "grant",
        capability: capability,
        reason_code: "duty_assignment",
        starts_at: 1.minute.ago,
        expires_at: 1.day.from_now,
      )
    end
    @operator_token.update_columns( # rubocop:disable Rails/SkipsModelValidations
      last_step_up_at: Time.current,
      last_step_up_scope: "support_session_revoke",
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_session_public_id: @operator_token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:org",
    )
    token = ClientToken.create!(user: @client, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    headers = as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id)
    valid = { reason_code: "security_incident", operation_id: SecureRandom.uuid }

    [
      valid.except(:reason_code), valid.merge(reason_code: ""), valid.merge(reason_code: "ABUSE"),
      valid.merge(reason_code: "abuse\u0000"), valid.merge(ticket_id: "has space"),
      valid.merge(ticket_id: "T" * 65), valid.except(:operation_id), valid.merge(operation_id: "not-a-uuid"),
      valid.merge(operation_id: "00000000-0000-0000-0000-000000000000"),
    ].each do |params|
      post base_org_support_client_revocations_url(@client.public_id, host: @host), params: params, headers: headers

      assert_response :unprocessable_content, "expected #{params.inspect} to be refused"
    end
    assert_not_predicate token.reload, :revoked?
  end

  test "ticket id length boundary: 63 and 64 characters are accepted" do
    [OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_APP,
     OperatorCapabilityGrant::SUPPORT_SESSION_REVOKE_APP,].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator,
        granted_by_operator: @granter,
        origin: "grant",
        capability: capability,
        reason_code: "duty_assignment",
        starts_at: 1.minute.ago,
        expires_at: 1.day.from_now,
      )
    end
    @operator_token.update_columns( # rubocop:disable Rails/SkipsModelValidations
      last_step_up_at: Time.current,
      last_step_up_scope: "support_session_revoke",
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_session_public_id: @operator_token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:org",
    )
    headers = as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id)

    [63, 64].each do |length|
      post base_org_support_client_revocations_url(@client.public_id, host: @host),
           params: { reason_code: "support_request", ticket_id: "T" * length, operation_id: SecureRandom.uuid },
           headers: headers

      assert_response :see_other
    end
  end

  test "a com revoke grant cannot revoke an app client's sessions" do
    [OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_APP,
     OperatorCapabilityGrant::SUPPORT_SESSION_REVOKE_COM,].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator,
        granted_by_operator: @granter,
        origin: "grant",
        capability: capability,
        reason_code: "duty_assignment",
        starts_at: 1.minute.ago,
        expires_at: 1.day.from_now,
      )
    end
    @operator_token.update_columns( # rubocop:disable Rails/SkipsModelValidations
      last_step_up_at: Time.current,
      last_step_up_scope: "support_session_revoke",
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_session_public_id: @operator_token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:org",
    )
    token = ClientToken.create!(user: @client, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    post base_org_support_client_revocations_url(@client.public_id, host: @host),
         params: { reason_code: "security_incident", operation_id: SecureRandom.uuid },
         headers: as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id),
         as: :json

    assert_response :forbidden
    assert_not_predicate token.reload, :revoked?
  end

  test "an admin-locked operator loses their grants' effect" do
    [OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_APP,
     OperatorCapabilityGrant::SUPPORT_SESSION_REVOKE_APP,].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator,
        granted_by_operator: @granter,
        origin: "grant",
        capability: capability,
        reason_code: "duty_assignment",
        starts_at: 1.minute.ago,
        expires_at: 1.day.from_now,
      )
    end
    @operator.update_columns(
      access_state: "admin_locked",
      admin_locked_at: Time.current, # rubocop:disable Rails/SkipsModelValidations
      admin_locked_reason_code: "security_incident",
    )

    get base_org_support_clients_url(ri: "jp", host: @host),
        headers: as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id)

    assert_not_equal 200, response.status
  end

  test "an Emergency session cannot revoke sessions even with the capability" do
    [OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_APP,
     OperatorCapabilityGrant::SUPPORT_SESSION_REVOKE_APP,].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator,
        granted_by_operator: @granter,
        origin: "grant",
        capability: capability,
        reason_code: "duty_assignment",
        starts_at: 1.minute.ago,
        expires_at: 1.day.from_now,
      )
    end
    OperatorToken.where(staff_id: @operator.id).destroy_all
    emergency_token = OperatorToken.create!(
      staff: @operator,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      discard_at: 30.days.from_now,
      staff_token_binding_method_id: OperatorTokenBindingMethod::LEGACY,
      authentication_context: AuthenticationContextValue::EMERGENCY_KEY,
    )
    token = ClientToken.create!(user: @client, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    post base_org_support_client_revocations_url(@client.public_id, host: @host),
         params: { reason_code: "security_incident", operation_id: SecureRandom.uuid },
         headers: as_staff_headers(@operator, host: @host, session_public_id: emergency_token.public_id)

    assert_not_includes [200, 303], response.status
    assert_not_predicate token.reload, :revoked?
  end

  test "if the audit intent cannot be written, no session is revoked" do
    [OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_APP,
     OperatorCapabilityGrant::SUPPORT_SESSION_REVOKE_APP,].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator,
        granted_by_operator: @granter,
        origin: "grant",
        capability: capability,
        reason_code: "duty_assignment",
        starts_at: 1.minute.ago,
        expires_at: 1.day.from_now,
      )
    end
    @operator_token.update_columns( # rubocop:disable Rails/SkipsModelValidations
      last_step_up_at: Time.current,
      last_step_up_scope: "support_session_revoke",
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_session_public_id: @operator_token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:org",
    )
    token = ClientToken.create!(user: @client, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    chronicle_down = ->(**) { raise ActiveRecord::ConnectionNotEstablished, "chronicle unavailable" }

    ChronicleIntentWriter.stub(:call, chronicle_down) do
      post base_org_support_client_revocations_url(@client.public_id, host: @host),
           params: { reason_code: "security_incident", operation_id: SecureRandom.uuid },
           headers: as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id)
    end

    assert_response :service_unavailable
    assert_not_predicate token.reload, :revoked?
  end

  test "if the audit result cannot be written, the result page reports the operation as unconfirmed" do
    [OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_APP,
     OperatorCapabilityGrant::SUPPORT_SESSION_REVOKE_APP,].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator,
        granted_by_operator: @granter,
        origin: "grant",
        capability: capability,
        reason_code: "duty_assignment",
        starts_at: 1.minute.ago,
        expires_at: 1.day.from_now,
      )
    end
    @operator_token.update_columns( # rubocop:disable Rails/SkipsModelValidations
      last_step_up_at: Time.current,
      last_step_up_scope: "support_session_revoke",
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_session_public_id: @operator_token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:org",
    )
    operation_id = SecureRandom.uuid
    result_write_fails = ->(**) { raise ActiveRecord::ConnectionNotEstablished, "chronicle unavailable" }

    ChronicleResultWriter.stub(:call, result_write_fails) do
      post base_org_support_client_revocations_url(@client.public_id, host: @host),
           params: { reason_code: "security_incident", operation_id: operation_id },
           headers: as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id)
    end

    assert_response :see_other
    assert_equal "manual_recovery_required", Chronicle.find_by!(event_uuid: operation_id).result

    get base_org_support_client_revocation_url(@client.public_id, operation_id, ri: "jp", host: @host),
        headers: as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id)

    assert_equal ["warning"], inertia_props.fetch("notices").map { |notice| notice.fetch("tone") }
  end

  test "a recorded revocation is not shown under a different target" do
    [OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_APP,
     OperatorCapabilityGrant::SUPPORT_SESSION_REVOKE_APP,].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator,
        granted_by_operator: @granter,
        origin: "grant",
        capability: capability,
        reason_code: "duty_assignment",
        starts_at: 1.minute.ago,
        expires_at: 1.day.from_now,
      )
    end
    @operator_token.update_columns( # rubocop:disable Rails/SkipsModelValidations
      last_step_up_at: Time.current,
      last_step_up_scope: "support_session_revoke",
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_session_public_id: @operator_token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:org",
    )
    operation_id = SecureRandom.uuid
    post base_org_support_client_revocations_url(@client.public_id, host: @host),
         params: { reason_code: "security_incident", operation_id: operation_id },
         headers: as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id)

    get base_org_support_client_revocation_url(clients(:two).public_id, operation_id, ri: "jp", host: @host),
        headers: as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id)

    assert_response :not_found
  end

  # The org surface verifies requests with Fetch Metadata (`header_or_legacy_token`): a cross-site
  # browser request without a token is the forgery case.
  test "with forgery protection on, a cross-site revocation without a CSRF token revokes nothing" do
    [OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_APP,
     OperatorCapabilityGrant::SUPPORT_SESSION_REVOKE_APP,].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator, granted_by_operator: @granter, origin: "grant", capability: capability,
        reason_code: "duty_assignment", starts_at: 1.minute.ago, expires_at: 1.day.from_now,
      )
    end
    @operator_token.update_columns( # rubocop:disable Rails/SkipsModelValidations
      last_step_up_at: Time.current, last_step_up_scope: "support_session_revoke", last_step_up_aal: "aal2",
      last_step_up_method: "passkey", last_step_up_session_public_id: @operator_token.public_id,
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:org",
    )
    token = ClientToken.create!(user: @client, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    begin
      post(
        base_org_support_client_revocations_url(@client.public_id, host: @host),
        params: { reason_code: "security_incident", operation_id: SecureRandom.uuid },
        headers: as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id)
          .merge("Sec-Fetch-Site" => "cross-site", "Origin" => "https://attacker.example"),
      )
    ensure
      ActionController::Base.allow_forgery_protection = original
    end

    assert_not_equal 303, response.status
    assert_not_predicate token.reload, :revoked?
  end
end
