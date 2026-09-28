# typed: false
# frozen_string_literal: true

require "test_helper"

# Browser-condition CSRF for the org administrative mutations. The requests are authenticated by the
# access cookie alone (no bearer header), Step-Up is earned through the real base completion
# endpoint, and forgery protection is on. The expected results follow the org surface's
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
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = AuthenticationToken.encode(
      @operator, host: @host, session_public_id: @token.public_id, resource_type: "operator",
                 jwt_issuer_id: "surface:BASE_ORG",
    )
    @session_headers = { "Host" => @host, "X-TEST-SESSION-PUBLIC-ID" => @token.public_id }.freeze
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
      transaction = IdentityStepUpCeremonyGrantIssuer.issue!(
        surface: "org", actor_ref: @operator.public_id, session_ref: @token.public_id, required_scope: scope,
        required_aal: StepUpRequirement::NO_AAL, allowed_methods: ["passkey"], return_to: "/support",
        expires_at: 5.minutes.from_now,
      ).transaction
      result = IdentityStepUpCeremonyResultIssuer.issue!(
        surface: "org", actor_ref: @operator.public_id, session_ref: @token.public_id,
        transaction_id: transaction.transaction_id, grant_jti: transaction.grant_jti, scope: scope,
        aal: "aal1", method: "passkey", challenge_id: "c-#{SecureRandom.hex(4)}", expires_at: transaction.expires_at,
      )
      post base_org_verification_completion_url(ri: "jp", host: @host),
           params: { step_up_ceremony_result: result }, headers: @session_headers

      assert_equal scope, @token.reload.last_step_up_scope, "#{name}: Step-Up through the real completion"

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
          rescue ActionController::InvalidAuthenticityToken
            nil
          end
        end
        assert_no_difference(count, "#{name}: a JSON body gets no exemption") do
          post(
            url.call, params: params.call.to_json,
                      headers: @session_headers.merge("Sec-Fetch-Site" => nil, "Content-Type" => "application/json"),
          )
        rescue ActionController::InvalidAuthenticityToken
          nil
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
    transaction = IdentityStepUpCeremonyGrantIssuer.issue!(
      surface: "org", actor_ref: @operator.public_id, session_ref: @token.public_id, required_scope: scope,
      required_aal: StepUpRequirement::NO_AAL, allowed_methods: ["passkey"], return_to: "/support",
      expires_at: 5.minutes.from_now,
    ).transaction
    result = IdentityStepUpCeremonyResultIssuer.issue!(
      surface: "org", actor_ref: @operator.public_id, session_ref: @token.public_id,
      transaction_id: transaction.transaction_id, grant_jti: transaction.grant_jti, scope: scope,
      aal: "aal1", method: "passkey", challenge_id: "c-#{SecureRandom.hex(4)}", expires_at: transaction.expires_at,
    )
    post base_org_verification_completion_url(ri: "jp", host: @host),
         params: { step_up_ceremony_result: result }, headers: @session_headers
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
