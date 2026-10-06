# frozen_string_literal: true

require "test_helper"

class BaseSelfRpCredentialReissuerTest < ActiveSupport::TestCase
  fixtures :clients, :client_statuses

  setup do
    @client = clients(:one)
    @root_token = ClientToken.create!(user: @client, discard_at: 1.day.from_now)
    @root_token.rotate_refresh_token!
    @rp_session = ClientRpSession.create!(
      client_token: @root_token,
      oidc_client_id: "base-app-ww",
      oidc_scope: "openid profile",
      oidc_auth_time: 5.minutes.ago,
      oidc_acr: "aal1",
      oidc_amr: JSON.generate(["pwd"]),
    )
    @refresh_token = @rp_session.issue_refresh_token!
  end

  test "refreshability requires the exact active Base self-RP chain" do
    assert BaseSelfRpCredentialReissuer.refreshable?(
      resource: @client, rp_session: @rp_session, raw_refresh_token: @refresh_token,
      client_id: "base-app-ww",
    )

    @root_token.update!(discard_at: ClientToken.database_now)

    assert_not BaseSelfRpCredentialReissuer.refreshable?(
      resource: @client, rp_session: @rp_session, raw_refresh_token: @refresh_token,
      client_id: "base-app-ww",
    )
  end

  test "accepted event updates RP claims without rotating the root authority" do
    root_snapshot = @root_token.attributes.slice(
      "last_used_at", "discard_at", "root_login_established_at", "refresh_token_generation",
    )
    response = OidcTokenExchangeCoordinator::Result.new(
      success: true,
      token_response: { "access_token" => "access", "refresh_token" => "refresh" },
      error: nil,
      error_description: nil,
      access_expires_at: 1.minute.from_now,
      refresh_expires_at: 1.hour.from_now,
    )

    OidcClientAssertionJwt.stub(:issue, "assertion") do
      OidcTokenExchangeCoordinator.stub(:call, response) do
        result = BaseSelfRpCredentialReissuer.call!(
          resource: @client, rp_session: @rp_session, raw_refresh_token: @refresh_token,
          client_id: "base-app-ww", authentication_event_at: 1.minute.ago,
          acr: "aal2", amr: ["otp"],
        )

        assert_same response, result
      end
    end

    assert_equal "aal2", @rp_session.reload.oidc_acr
    assert_equal ["otp"], JSON.parse(@rp_session.oidc_amr)
    assert_equal 1.minute.ago.to_i, @rp_session.oidc_auth_time.to_i
    actual_root_snapshot =
      @root_token.reload.attributes.slice(*root_snapshot.keys).transform_values do |value|
        value.respond_to?(:to_time) ? value.to_time.to_i : value
      end

    assert_equal root_snapshot.transform_values { |value| value.respond_to?(:to_time) ? value.to_time.to_i : value },
                 actual_root_snapshot
  end

  test "a missing or whitespace refresh credential is unavailable" do
    [nil, "", " refresh-token", "refresh-token "].each do |raw_refresh_token|
      assert_not BaseSelfRpCredentialReissuer.refreshable?(
        resource: @client, rp_session: @rp_session, raw_refresh_token:, client_id: "base-app-ww",
      )
    end
  end
end
