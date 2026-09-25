# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::App::Identity::Mfa::ResetsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients

  setup do
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! @host
    @client = clients(:one)
    @client.update!(mfa_level_id: ClientMfaLevel::FULL, mfa_level_enabled: true)
    @headers = as_user_headers(@client, host: @host)
    @token = ClientToken.find_by!(public_id: @headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
  end

  test "show is a GET-only unavailable placeholder that leaves security state unchanged" do
    before = security_state

    get base_app_identity_mfa_reset_url(ri: "jp", host: @host), headers: @headers

    assert_response :success
    assert_predicate inertia_props.fetch("reset_unavailable"), :present?
    assert_equal before, security_state
  end

  test "mutation verbs are not routes and change no security state" do
    before = security_state
    path = base_app_identity_mfa_reset_url(ri: "jp", host: @host)

    %i(post patch put delete).each do |method|
      process(method, path, headers: @headers)

      assert_response :not_found, method.to_s
    end

    assert_equal before, security_state
  end

  private

  def security_state
    {
      client: @client.reload.attributes,
      session: @token.reload.attributes,
      credentials: [
        @client.client_secret_credentials.count,
        @client.client_totp_credentials.count,
        @client.client_passkeys.count,
      ],
      chronicles: [
        Chronicle.where(actor_type: "Client", actor_id: @client.id).count,
        Chronicle.where(subject_type: "Client", subject_id: @client.id).count,
        ClientChronicle.where(actor_type: "Client", actor_id: @client.id).count,
        ClientChronicle.where(subject_type: "Client", subject_id: @client.id.to_s).count,
      ],
    }
  end
end
