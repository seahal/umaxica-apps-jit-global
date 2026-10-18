# frozen_string_literal: true

require "test_helper"

class OpOutboxDispatchJobTest < ActiveSupport::TestCase
  fixtures :clients

  setup do
    client = clients(:one)
    root = ClientToken.create!(user: client)
    OpAppGrant.create!(
      client_token: root, client_device_session: root.device_session, device_session_id: root.device_session_id,
      oidc_client_id: "core-app-jp", oidc_scope: "openid", oidc_jti: SecureRandom.uuid, last_used_at: Time.current,
      refresh_token_expires_at: 1.day.from_now,
    )
    @flow = OpLogoutCommitter.call(
      realm: "app", root_token: root, idempotency_key: "k", browser_binding: "b", audit_ref: "a",
    ).flow
    @event = OpAppOutboxEvent.sole
  end

  test "an acknowledged delivery completes the outbox row and the participant" do
    sent = []
    OidcBackchannelLogoutClient.stub(
      :call, ->(endpoint:, logout_token:) {
               sent << [endpoint, logout_token]
               :acknowledged
             },
    ) do
      OpOutboxDispatchJob.perform_now
    end

    assert_equal [OidcClientStoresStaticClientStore.backchannel_logout_uri("core-app-jp")], sent.map(&:first)
    assert_not_nil @event.reload.completed_at
    assert_not_nil OpAppLogoutFlowParticipant.sole.acknowledged_at
  end

  test "the delivered Logout Token verifies under the OP published JWKS for exactly that client and sid" do
    token = nil
    OidcBackchannelLogoutClient.stub(
      :call, ->(endpoint:, logout_token:) {
               token = logout_token
               :acknowledged
             },
    ) do
      OpOutboxDispatchJob.perform_now
    end
    published = JitSecurityJwtRegistry.jwks_for(OidcIssuer.jwt_issuer_id_for_resource_type("client")).to_json
    result = OidcOpLogoutTokenVerifier.new(
      logout_token: token, client_id: "core-app-jp", issuer: OidcIssuer.for_resource_type("client"),
      jwks_client: OidcOpJwksClient.new(
        jwks_uri: "https://base.example/jwks", fetcher: -> { published },
        clock: -> { Time.current },
      ),
    ).call

    assert_predicate result, :success?
    assert_equal OpAppLogoutFlowParticipant.sole.sid, result.payload.fetch("sid")
  end

  test "a failed delivery is retried later and a second run does not resend inside the backoff" do
    calls = 0
    OidcBackchannelLogoutClient.stub(
      :call, ->(**) {
               calls += 1
               "http_503"
             },
    ) do
      OpOutboxDispatchJob.perform_now
      OpOutboxDispatchJob.perform_now
    end

    @event.reload

    assert_equal 1, calls
    assert_nil @event.completed_at
    assert_equal ["http_503", 1], [@event.last_error_code, @event.delivery_attempts]
    assert_operator @event.next_attempt_at, :>, OpAppOutboxEvent.database_now
  end

  test "an expired lease from a crashed worker is picked up again" do
    @event.update_columns(lease_expires_at: 1.minute.ago, delivery_attempts: 1)
    OidcBackchannelLogoutClient.stub(:call, :acknowledged) { OpOutboxDispatchJob.perform_now }

    assert_not_nil @event.reload.completed_at
  end

  test "a live lease held by another worker is not dispatched twice" do
    @event.update_columns(lease_expires_at: 1.minute.from_now)
    OidcBackchannelLogoutClient.stub(:call, ->(**) { flunk("leased row must not be sent") }) do
      OpOutboxDispatchJob.perform_now
    end

    assert_nil @event.reload.completed_at
  end

  test "a delayed failed worker cannot overwrite a successor delivery that already acknowledged" do
    now = OpAppOutboxEvent.database_now + 1
    deliveries = 0
    OpAppOutboxEvent.stub(:database_now, -> { now }) do
      OidcBackchannelLogoutClient.stub(
        :call, ->(**) {
                 deliveries += 1
                 if deliveries == 1
                   now += OpOutboxDispatchJob::LEASE + 1
                   OpOutboxDispatchJob.perform_now
                   "http_503"
                 else
                   :acknowledged
                 end
               },
      ) do
        OpOutboxDispatchJob.perform_now
      end
    end

    assert_equal 2, deliveries
    assert_equal 2, @event.reload.delivery_attempts
    assert_not_nil @event.completed_at
    assert_nil @event.last_error_code
    participant = OpAppLogoutFlowParticipant.sole

    assert_not_nil participant.acknowledged_at
    assert_nil participant.last_error_code
  end

  test "a delayed failed worker leaves a newer live lease and its delivery counter untouched" do
    successor_expiry = 1.minute.from_now
    OidcBackchannelLogoutClient.stub(
      :call, ->(**) {
               @event.reload.update!(delivery_attempts: 2, lease_expires_at: successor_expiry)
               "http_503"
             },
    ) do
      OpOutboxDispatchJob.perform_now
    end

    assert_equal 2, @event.reload.delivery_attempts
    # Compare at the stored microsecond precision; Float epoch seconds cannot hold one microsecond.
    assert_equal successor_expiry.change(usec: successor_expiry.usec), @event.lease_expires_at
    assert_nil @event.last_error_code
    assert_nil OpAppLogoutFlowParticipant.sole.last_error_code
  end

  test "lease expiry one microsecond before at and after the writer clock controls redelivery" do
    now = OpAppOutboxEvent.database_now + 1
    [-Rational(1, 1_000_000), 0, Rational(1, 1_000_000)].each do |offset|
      @event.update!(lease_expires_at: now + offset, next_attempt_at: now - 1, completed_at: nil)
      calls = 0
      OpAppOutboxEvent.stub(:database_now, now) do
        OidcBackchannelLogoutClient.stub(
          :call, ->(**) {
                   calls += 1
                   :acknowledged
                 },
        ) do
          OpOutboxDispatchJob.perform_now
        end
      end

      assert_equal offset.positive? ? 0 : 1, calls
      assert_equal offset.positive?, @event.reload.completed_at.nil?
    end
  end

  test "backoff immediately below at and above saturation stays bounded even after prolonged outages" do
    now = OpAppOutboxEvent.database_now + 1
    [[11, 2048], [12, 3600], [13, 3600], [1_000_000, 3600]].each do |attempts, seconds|
      @event.update!(
        delivery_attempts: attempts - 1, lease_expires_at: nil, next_attempt_at: now - 1, completed_at: nil,
      )
      OpAppOutboxEvent.stub(:database_now, now) do
        OidcBackchannelLogoutClient.stub(:call, "http_503") do
          OpOutboxDispatchJob.perform_now
        end
      end

      assert_equal now + seconds, @event.reload.next_attempt_at
      assert_equal attempts, @event.delivery_attempts
    end
  end
end
