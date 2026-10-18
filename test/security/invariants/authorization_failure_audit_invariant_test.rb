# typed: false
# frozen_string_literal: true

require "test_helper"

module Security
  module Invariants
    # An authorization denial is a security event of record: besides refusing the request, it
    # must leave an AUTHORIZATION_FAILED chronicle for the actor that was refused.
    class AuthorizationFailureAuditInvariantTest < ActionDispatch::IntegrationTest
      test "an operator refused by a staff policy is answered 403 and recorded as an authorization failure" do
        host = ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost")
        operator = Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
        token = OperatorToken.create!(staff: operator, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)

        headers = as_staff_headers(
          operator, host: host, session_public_id: token.public_id,
                    headers: { "Accept" => "application/json" },
        )
        rp_client = OidcClientRegistry.find!("base-org-ww")
        token.rotate_refresh_token! unless token.device_session.current_refresh_token_id
        rp_session = OpOrgGrant.create!(
          operator_token: token, oidc_client_id: rp_client.client_id,
          oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
          oidc_auth_time: Time.current, refresh_token_expires_at: 10.minutes.from_now,
        )
        rp_access = AuthenticationTokenService.encode(
          operator,
          host: host,
          resource_type: "operator",
          session_public_id: token.public_id,
          base_session_public_id: token.public_id,
          oidc_sid: rp_session.public_id,
          oidc_jti: rp_session.oidc_jti,
          expires_at: 10.minutes.from_now,
          scopes: %w(openid profile),
          issuer: OidcIssuer.for_client(rp_client),
          audiences: [rp_client.aud],
          jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
          subject: OidcSubject.for(operator, resource_type: "operator"),
          client_id: rp_client.client_id,
        )
        rp_cookie = [headers.fetch("Cookie"),
                     "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
                     "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(
                       rp_session
                                              .issue_refresh_token!,
                     )}",].join("; ")
        headers = headers.merge("Cookie" => rp_cookie, "HTTP_COOKIE" => rp_cookie)

        before =
          ChronicleRecord.connected_to(role: :writing) do
            OperatorChronicle.where(event_id: OperatorChronicleEvent::AUTHORIZATION_FAILED).count
          end

        get base_org_system_index_url(ri: "jp", host: host),
            headers: headers

        assert_response :forbidden
        assert_equal({ "error" => "Unauthorized" }, response.parsed_body)
        audits =
          ChronicleRecord.connected_to(role: :writing) do
            OperatorChronicle.where(event_id: OperatorChronicleEvent::AUTHORIZATION_FAILED).order(:occurred_at).to_a
          end

        assert_equal before + 1, audits.size
        assert_equal operator.id.to_s, audits.last.subject_id.to_s
      end
    end
  end
end
