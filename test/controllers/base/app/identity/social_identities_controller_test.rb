# frozen_string_literal: true

require "test_helper"

class BaseAppSocialIdentitiesTest < ActionDispatch::IntegrationTest
  test "shows only the authenticated actor's allowed provider statuses" do
    actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    ClientExternalIdentity.create!(
      client: actor, provider: "google", issuer: "https://accounts.google.com",
      subject: SecureRandom.uuid, audience: "client", verification_authority: "test",
      verified_at: Time.current, state: "active",
    )
    other = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    ClientExternalIdentity.create!(
      client: other, provider: "apple", issuer: "https://appleid.apple.com",
      subject: SecureRandom.uuid, audience: "client", verification_authority: "test",
      verified_at: Time.current, state: "active",
    )
    host!(ENV.fetch("PUBLIC_BASE_SERVICE_URL"))
    https!
    cell = RpCellBinding.for_client("base-app-ww")
    issuer = OidcIssuer.for_resource_type("client")
    subject = OidcSubject.for(actor, resource_type: "client")
    sid = SecureRandom.uuid
    enrollment = RpCallbackCommitter.call(
      cell: cell, issuer: issuer, subject: subject, sid: sid, absolute_expires_at: 1.hour.from_now,
    )

    assert_predicate enrollment, :success?
    key = OpenSSL::PKey::EC.generate("secp384r1")
    now = Time.current.to_i
    token = JWT.encode(
      { "iss" => issuer,
        "aud" => [cell.client_id],
        "sub" => subject,
        "sid" => sid,
        "iat" => now,
        "nbf" => now - 1,
        "exp" => now + 300,
        "jti" => SecureRandom.uuid,
        "scope" => "openid",
        "client_id" => cell.client_id,
        "authn_ctx" => "normal", },
      key, "ES384", { "kid" => "social-status-test", "typ" => "at+jwt" },
    )
    jwks = OidcOpJwksClient.new(
      jwks_uri: OidcIssuer.jwks_uri("client"),
      fetcher: -> { { "keys" => [JitSecurityJwtJwk.export_public(key, kid: "social-status-test")] } },
    )
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = token
    cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE] = enrollment.session.public_id
    selection = OrgAdminAuthorityClient::Result.new(status: :ok, data: {}, errors: {}, http_status: 200)
    owner = Minitest::Mock.new
    owner.expect(:get, selection, ["/identity/selection"])
    RuntimeRole.stub(:current, "rp-base-app-ww") do
      RuntimeRole.stub(:rp_browser_admission_open?, true) do
        OidcOpJwksClient.stub(:for_resource_type, jwks) do
          OrgAdminAuthorityClient.stub(:new, ->(**) { owner }) do
            get "/identity/social_identities?ri=jp",
                headers: { "X-Inertia" => "true", "X-Inertia-Version" => InertiaRails.configuration.version }

            assert_response :success
            rows = response.parsed_body.fetch("props").fetch("identities")

            assert_equal ["Google", "Apple"], rows.map { |row| row.fetch("provider") }
            expected = [I18n.t("base_social_identities.linked"), I18n.t("base_social_identities.unlinked")]

            assert_equal expected, rows.map { |row| row.fetch("status") }
          end
        end
      end
    end
    cookies.delete(OidcRpBrowserCredentialContract::SESSION_COOKIE)
    get "/identity/social_identities?ri=jp"

    assert_not_equal 200, response.status
  end
end
