# frozen_string_literal: true

require "test_helper"

class RpCookiePurgeTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  setup do
    https!
    @host = URI.parse(ENV.fetch("PUBLIC_CORE_SERVICE_URL")).host || ENV.fetch("PUBLIC_CORE_SERVICE_URL")
    host! @host
  end

  test "a purge for the logged-out sid clears this browser's RP credentials" do
    tombstone("sid-old")
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = access_for("sid-old")
    purge("sid-old")

    assert_response :ok
    assert response.parsed_body.fetch("purged")
  end

  test "a stale purge cannot destroy a newer login in the same browser" do
    tombstone("sid-old")
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = access_for("sid-new")
    purge("sid-old")

    assert_not response.parsed_body.fetch("purged")
  end

  test "a purge for a sid this cell has not tombstoned clears nothing" do
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = access_for("sid-live")
    purge("sid-live")

    assert_not response.parsed_body.fetch("purged")
  end

  private

  def purge(sid)
    post(
      "/sign/out/purge", params: { sid:, ri: "jp" },
                         headers: { "Origin" => "https://#{@host}", "Sec-Fetch-Site" => "same-origin" },
    )
  end

  def tombstone(sid)
    RpCoreAppOpSessionBinding.create!(
      issuer: "https://www.umaxica.app", realm: "app", client_id: "core-app-jp",
      sid:, revoked_at: Time.current,
    )
  end

  def access_for(sid)
    JWT.encode({ "sid" => sid }, OpenSSL::PKey::EC.generate("secp384r1"), "ES384")
  end
end
