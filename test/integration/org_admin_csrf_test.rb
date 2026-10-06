# typed: false
# frozen_string_literal: true

require "test_helper"

# Browser-condition CSRF for the org administrative mutations. The requests are authenticated by the
# access cookie alone (no bearer header), synthetic verified evidence is finalized through
# the public Base committer, and forgery protection is on. This isolates mutation CSRF; the
# administrative ceremony integration test exercises the HTTP completion and real signatures. The expected results follow the org surface's
# `protect_from_forgery using: :header_or_legacy_token` contract in Rails:
#
# - `Sec-Fetch-Site: same-origin` or `same-site` is accepted without a token;
# - `cross-site` is accepted only from a trusted origin (none is trusted for these endpoints);
# - a missing `Sec-Fetch-Site` falls back to the authenticity token;
# - an `Origin` header that differs from the request's own origin is rejected;
# - `Referer` is not consulted.
class OrgAdminCsrfTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_tokens, :clients

  setup do
    @host = ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost")
    host! @host
    @operator = operators(:one)
    @granter = operators(:two)
    @token = operator_tokens(:one)
    @client = clients(:one)
    # The compliance row normally comes from migration 20260926130000 (365 days, decided 2026-09-26);
    # a schema-only load skips that insert, so the test ensures it with the same value.
    ChronicleRetentionPolicy.find_or_create_by!(code: "compliance") do |policy|
      policy.name = "Compliance"
      policy.duration_days = 365
      policy.permanent = false
    end
    OperatorCapabilityGrant.bootstrap!(
      operator: @operator, capabilities: OperatorCapabilityGrant::CAPABILITIES, ticket_id: "TEST-CSRF",
      expires_at: 1.day.from_now,
    )
    @passkey = @operator.staff_passkeys.create!(webauthn_id: SecureRandom.uuid, public_key: "public")
    BaseSelectorBootstrapAuthority.call(surface: :org, principal: @operator)
    BaseSelectorAuthority.prepare(surface: :org, principal: @operator, session: @token)
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = AuthenticationToken.encode(
      @operator, host: @host, session_public_id: @token.public_id, resource_type: "operator",
                 jwt_issuer_id: "surface:BASE_ORG",
    )
    @session_headers = { "Host" => @host, "Client-Agent" => "Mozilla/5.0" }.freeze
    @mutations = {
      support: [
        "support_session_revoke",
        -> { base_org_support_client_revocations_url(@client.public_id, host: @host) },
        -> { { reason_code: "security_incident", operation_id: SecureRandom.uuid } },
        -> { Chronicle.where(action: "support.session.revoked").count },
      ],
      iam: [
        "operator_capability",
        -> { base_org_iam_grants_url(host: @host) },
        lambda {
          { operator_public_id: @granter.public_id,
            capability: OperatorCapabilityGrant::SUPPORT_CONSOLE_READ,
            reason_code: "duty_assignment",
            duration_days: "30",
            operation_id: SecureRandom.uuid, }
        },
        -> { OperatorCapabilityGrant.where(operator: @granter).count },
      ],
      enforcement: [
        "enforcement_case_apply",
        -> { base_org_support_app_enforcement_cases_url(host: @host) },
        lambda {
          { enforcement_case: { kind: "cooldown",
                                duration_mode: "timed",
                                visibility: "visible",
                                release_mode: "automatic",
                                effective_at: Time.current,
                                expires_at: 1.day.from_now,
                                reason_code: "abuse",
                                principal_public_id: @client.public_id, } }
        },
        -> { AppEnforcementCase.count },
      ],
    }
  end

  test "each mutation follows the Fetch Metadata and token contract" do
    @mutations.each do |name, (scope, url, params, count)|
      return_to =
        case scope
        when "support_session_revoke" then "/support/clients/#{@client.public_id}/revocations/new"
        when "operator_capability" then "/iam/grants/new"
        when "enforcement_case_apply" then "/support/app/enforcement_cases/new"
        end
      requirement = StepUpRequirement.new(
        scope: scope, allowed_methods: [:passkey], purpose: "step_up", audience: "step_up:org",
        session_binding: @token.public_id, token_binding: @token.public_id, require_session_binding: true,
      )
      transaction = issue_base_step_up_admission!(
        actor: @operator, token: @token, requirement: requirement, return_to: return_to,
      ).transaction
      transaction.record_verification!(
        method: "passkey", aal: "aal1", phishing_resistant: true,
        verified_at: OperatorStepUpCeremonyTransaction.database_now, verified_credential_ref: @passkey.external_id,
      )
      ceremony, = OperatorAuthCeremonySession.rotate_and_admit!(
        admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: transaction.transaction_id,
      )
      result = BaseAuthAdmissionCoordinator.issue_result!(
        transaction: transaction, ceremony_session_ref: ceremony.id.to_s,
      )
      IdentityStepUpCeremonyFreshnessCommitter.call!(
        actor: @operator, token: @token, transaction: transaction, requirement: requirement, raw_result: result.code,
      )

      assert_equal scope, @token.reload.last_step_up_scope, "#{name}: canonical Base authority is established"

      rejected = [
        { "Sec-Fetch-Site" => "cross-site", "Origin" => "https://attacker.example" },
        { "Sec-Fetch-Site" => nil },
        { "Sec-Fetch-Site" => "same-origin", "Origin" => "https://attacker.example" },
        { "Sec-Fetch-Site" => nil, "Referer" => "https://#{@host}/support" },
        { "Sec-Fetch-Site" => nil, "X-CSRF-Token" => "forged-token-value" },
      ]
      original = ActionController::Base.allow_forgery_protection
      ActionController::Base.allow_forgery_protection = true
      begin
        # csrf_meta_tags renders only while forgery protection is on.
        get(base_org_support_index_url(ri: "jp", host: @host), headers: @session_headers)

        assert_predicate css_select("meta[name='csrf-token']").first&.[]("content"), :present?,
                         "#{name}: the page carries a CSRF token"

        rejected.each do |fetch_headers|
          assert_no_difference(count, "#{name}: #{fetch_headers.inspect} must be rejected") do
            post(url.call, params: params.call, headers: @session_headers.merge(fetch_headers))

            assert_response :unprocessable_content
          end
        end
        assert_no_difference(count, "#{name}: a JSON body gets no exemption") do
          post(
            url.call, params: params.call.to_json,
                      headers: @session_headers.merge("Sec-Fetch-Site" => nil, "Content-Type" => "application/json"),
          )

          assert_response :unprocessable_content
        end

        assert_difference(count, 1, "#{name}: same-origin without a token is accepted") do
          post(
            url.call, params: params.call,
                      headers: @session_headers.merge(
                        "Sec-Fetch-Site" => "same-origin",
                        "Referer" => "https://attacker.example/",
                      ),
          )
        end
      ensure
        ActionController::Base.allow_forgery_protection = original
      end
    end
  end

  test "a request without Fetch Metadata but with the page's CSRF token is accepted" do
    scope = "support_session_revoke"
    requirement = StepUpRequirement.new(
      scope: scope, allowed_methods: [:passkey], purpose: "step_up", audience: "step_up:org",
      session_binding: @token.public_id, token_binding: @token.public_id, require_session_binding: true,
    )
    transaction = issue_base_step_up_admission!(
      actor: @operator, token: @token, requirement: requirement,
      return_to: "/support/clients/#{@client.public_id}/revocations/new",
    ).transaction
    transaction.record_verification!(
      method: "passkey", aal: "aal1", phishing_resistant: true,
      verified_at: OperatorStepUpCeremonyTransaction.database_now, verified_credential_ref: @passkey.external_id,
    )
    ceremony, = OperatorAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: transaction.transaction_id,
    )
    result = BaseAuthAdmissionCoordinator.issue_result!(
      transaction: transaction, ceremony_session_ref: ceremony.id.to_s,
    )
    IdentityStepUpCeremonyFreshnessCommitter.call!(
      actor: @operator, token: @token, transaction: transaction, requirement: requirement, raw_result: result.code,
    )

    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    begin
      get(base_org_support_index_url(ri: "jp", host: @host), headers: @session_headers)
      csrf_token = css_select("meta[name='csrf-token']").first["content"]

      assert_difference(-> { Chronicle.where(action: "support.session.revoked").count }, 1) do
        post(
          base_org_support_client_revocations_url(@client.public_id, host: @host),
          params: { reason_code: "security_incident", operation_id: SecureRandom.uuid },
          headers: @session_headers.merge("Sec-Fetch-Site" => nil, "X-CSRF-Token" => csrf_token),
        )
      end
    ensure
      ActionController::Base.allow_forgery_protection = original
    end
  end
end
