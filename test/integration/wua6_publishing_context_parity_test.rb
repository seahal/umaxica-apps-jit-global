# frozen_string_literal: true

require "test_helper"

class Wua6PublishingContextParityTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "ORG Publishing create accepts the same active operator under Normal and Standby" do
    actor = Operator.create!(security_mode_id: SecurityModeTestDefault.id_for(Operator))
    client = OidcClientRegistry.find!("edit-org-ww")
    base_host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    path = "/api/v0/publishing/docs/org/entries"
    base_origin = "http://#{base_host}"
    token_url = "#{base_origin}#{path}"
    host!(base_host)

    %w(normal standby).each do |context|
      root_token = OperatorToken.create!(
        authentication_epoch: 0,
        staff_id: actor.id,
        root_login_established_at: Time.current,
        authentication_context: context,
      )
      grant = OpOrgGrant.create!(
        authentication_epoch: 0,
        operator_token: root_token,
        oidc_client_id: client.client_id,
        oidc_scope: "openid profile",
        oidc_jti: SecureRandom.uuid,
        oidc_auth_time: Time.current,
        refresh_token_expires_at: 10.minutes.from_now,
      )
      access_token = AuthenticationTokenService.encode(
        actor,
        host: base_host,
        resource_type: "operator",
        session_public_id: root_token.public_id,
        base_session_public_id: root_token.public_id,
        oidc_sid: grant.public_id,
        oidc_jti: grant.oidc_jti,
        expires_at: 10.minutes.from_now,
        scopes: %w(openid profile),
        issuer: OidcIssuer.for_client(client),
        audiences: [client.aud],
        jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
        subject: OidcSubject.for(actor, resource_type: "operator"),
        client_id: client.client_id,
        authentication_context: context,
      )
      assertion = OidcClientAssertionJwt.issue(client_id: client.client_id, token_url:)
      slug = "wua6-#{context}-#{SecureRandom.hex(6)}"

      post(
        token_url,
        params: {
          entry: {
            title: "Context parity #{context}",
            summary: "Context parity",
            body: { text: "Publishing body" }.to_json,
            locale: "ja",
            slug:,
          },
        },
        headers: {
          "Authorization" => "Bearer #{access_token}",
          "X-Client-Assertion" => assertion,
          "Accept" => "application/json",
        },
      )

      assert_response :created, "#{context}: #{response.status}"

      entry_response = response.parsed_body.fetch("entry")

      assert_equal slug, entry_response.fetch("canonical_slug")

      revision = Publishing::Docs::Org::EntryRevision.find_by!(
        public_id: entry_response.fetch("current_revision_public_id"),
      )

      assert_equal actor.public_id, revision.created_by_operator_public_id
      assert_equal context, root_token.reload.strict_authentication_context_value.to_s
    end
  end
end
