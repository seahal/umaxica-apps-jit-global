# frozen_string_literal: true

require "test_helper"

# BX-7 at the request level: a Logout Token whose key cannot be obtained because the OP JWKS
# fetch fails is answered 503 (retryable), never 400, and changes nothing in the RP cell.
class RpBackchannelLogoutJwksOutageTest < ActionDispatch::IntegrationTest
  include OutboundHttpStub

  fixtures :clients

  setup do
    https!
    host! URI.parse(ENV.fetch("PUBLIC_CORE_SERVICE_URL")).host || ENV.fetch("PUBLIC_CORE_SERVICE_URL")
    root = ClientToken.create!(authentication_epoch: 0, user: clients(:one))
    OpAppGrant.create!(
      authentication_epoch: 0,
      client_token: root, client_device_session: root.device_session, device_session_id: root.device_session_id,
      oidc_client_id: "core-app-jp", oidc_scope: "openid", oidc_jti: SecureRandom.uuid, last_used_at: Time.current,
      refresh_token_expires_at: 1.day.from_now,
    )
    OpAuthorityStopCommitter.stop_root(
      root:, cause: "browser_logout", principal_public_id: clients(:one).public_id,
      authority_evidence_ref: "test",
    )
    @participant = OpAppAuthorityStopParticipant.sole
    @local = RpCallbackCommitter.call(
      cell: RpCellBinding.fetch("rp_core_app"), issuer: @participant.issuer, subject: "subject-a",
      sid: @participant.sid, absolute_expires_at: 1.hour.from_now,
    ).session
    @jwks_uri = OidcIssuer.jwks_uri("client")
    clear_refetch_window
  end

  teardown { clear_refetch_window }

  test "a Logout Token signed with a key the OP JWKS cannot be fetched for answers 503 and changes nothing" do
    stubs =
      Faraday::Adapter::Test::Stubs.new do |stub|
        stub.get(@jwks_uri) { raise Faraday::ConnectionFailed, "refused" }
      end

    stub_outbound_http(stubs) do
      post "/oidc/closures", params: { logout_token: token_with_unpublished_kid }
    end

    assert_response :service_unavailable
    assert_nil @local.reload.revoked_at
    assert_equal 0, RpCoreAppEventReceipt.count
  end

  private

  # The OP's own claims, signed with a fresh ES384 key under a kid the OP has not published yet
  # (an unannounced rotation), so the RP must go to the JWKS for it.
  def token_with_unpublished_kid
    issued = OpLogoutTokenIssuer.call(participant: @participant)
    payload, header = JWT.decode(issued, nil, false)
    JWT.encode(
      payload, OpenSSL::PKey::EC.generate("secp384r1"), "ES384",
      header.merge("kid" => "unpublished-#{SecureRandom.hex(4)}"),
    )
  end

  def clear_refetch_window
    store = Umaxica::Valkey::Connection.new(
      url: Umaxica::Valkey::Settings.current.rate_limit.url,
      namespace: "#{Rails.configuration.x.rate_limit.fetch(:namespace)}:#{OidcJwksRefetchLimiter::NAMESPACE_SUFFIX}",
    )
    issuer_key = OidcJwksRefetchLimiter.issuer_key(@jwks_uri)
    store.call("DEL", store.key("#{issuer_key}:lease"), store.key("#{issuer_key}:last"))
  end
end
