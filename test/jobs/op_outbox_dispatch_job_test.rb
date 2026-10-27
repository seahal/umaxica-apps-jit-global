# frozen_string_literal: true

require "test_helper"

# WU-15 sender (D-26, D-117, D-121, BX-4, BX-10): the authority-stop participant row is the outbox.
class OpOutboxDispatchJobTest < ActiveSupport::TestCase
  fixtures :clients

  setup do
    client = clients(:one)
    root = ClientToken.create!(authentication_epoch: 0, user: client)
    @grant = OpAppGrant.create!(
      authentication_epoch: 0,
      client_token: root, client_device_session: root.device_session, device_session_id: root.device_session_id,
      oidc_client_id: "core-app-jp", oidc_scope: "openid", oidc_jti: SecureRandom.uuid, last_used_at: Time.current,
      refresh_token_expires_at: 1.day.from_now,
    )
    OpAuthorityStopCommitter.stop_root(
      root:, cause: "browser_logout", principal_public_id: client.public_id, authority_evidence_ref: "a",
    )
    @event = OpAppAuthorityStopParticipant.sole
  end

  test "an acknowledged delivery makes the participant final" do
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
    assert_equal status("acknowledged"), @event.reload.status_id
    assert_predicate @event, :final?
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
    id_token = OidcIdTokenIssuer.call(
      resource: clients(:one), client: OidcClientRegistry.find!("core-app-jp"), nonce: "nonce",
      sid: @grant.public_id,
    )
    id_claims, = JWT.decode(id_token, nil, false)

    assert_equal @grant.public_id, id_claims.fetch("sid")
    assert_equal id_claims.fetch("sid"), result.payload.fetch("sid")
    assert_equal @event.sid, result.payload.fetch("sid")
  end

  test "BX-4: redirect range, 400 and endpoint misconfiguration are refused; transient answers retry" do
    { "http_299" => "pending",
      "http_300" => "refused",
      "http_301" => "refused",
      "http_302" => "refused",
      "http_303" => "refused",
      "http_304" => "refused",
      "http_305" => "refused",
      "http_306" => "refused",
      "http_307" => "refused",
      "http_308" => "refused",
      "http_399" => "refused",
      "http_400" => "refused",
      "http_404" => "refused",
      "http_405" => "refused",
      "http_410" => "refused",
      "http_413" => "refused",
      "invalid_endpoint" => "refused",
      "http_401" => "pending",
      "http_403" => "pending",
      "http_429" => "pending",
      "http_500" => "pending",
      "http_503" => "pending",
      "transport_failure" => "pending", }.each do |outcome, expected|
      @event.update!(
        status_id: status("pending"), next_attempt_at: 1.second.ago, lease_expires_at: 1.second.ago,
        last_outcome: "none",
      )
      OidcBackchannelLogoutClient.stub(:call, outcome) { OpOutboxDispatchJob.perform_now }

      assert_equal [status(expected), outcome], [@event.reload.status_id, @event.last_outcome], outcome
    end
  end

  test "BX-4 alert outcomes log an error event for each misconfiguration class" do
    %w(http_401 http_403 http_404 http_405 http_410 http_413).each do |outcome|
      @event.update!(
        status_id: status("pending"), next_attempt_at: 1.second.ago, lease_expires_at: 1.second.ago,
        last_outcome: "none",
      )
      errors = []
      Rails.logger.stub(:error, ->(message) { errors << message }) do
        OidcBackchannelLogoutClient.stub(:call, outcome) { OpOutboxDispatchJob.perform_now }
      end

      assert_equal 1, errors.length, outcome
      assert_includes errors.sole, "oidc.backchannel_logout.delivery"
      assert_includes errors.sole, outcome
      assert_includes errors.sole, @event.client_id
      assert_equal outcome, @event.reload.last_outcome
    end
  end

  test "BX-10: a pending participant is expired at its deadline and never sent after it" do
    now = OpAppAuthorityStopParticipant.database_now + 1
    [-Rational(1, 1_000_000), 0, Rational(1, 1_000_000)].each do |offset|
      @event.update!(
        status_id: status("pending"), deadline_at: now + offset, next_attempt_at: now - 1, lease_expires_at: now - 1,
      )
      calls = 0
      OpAppAuthorityStopParticipant.stub(:database_now, now) do
        OidcBackchannelLogoutClient.stub(
          :call, ->(**) {
                   calls += 1
                   :acknowledged
                 },
        ) do
          OpOutboxDispatchJob.perform_now
        end
      end

      expected = offset.positive? ? "acknowledged" : "expired"

      assert_equal [expected, offset.positive? ? 1 : 0],
                   [OpAuthorityStopReference::PARTICIPANT_STATUSES.key(@event.reload.status_id), calls]
    end
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
    assert_equal status("pending"), @event.status_id
    assert_equal ["http_503", 1], [@event.last_outcome, @event.delivery_attempts]
    assert_operator @event.next_attempt_at, :>, OpAppAuthorityStopParticipant.database_now
  end

  test "an expired lease from a crashed worker is picked up again" do
    @event.update_columns(lease_expires_at: 1.minute.ago, delivery_attempts: 1)
    OidcBackchannelLogoutClient.stub(:call, :acknowledged) { OpOutboxDispatchJob.perform_now }

    assert_equal status("acknowledged"), @event.reload.status_id
  end

  test "a live lease held by another worker is not dispatched twice" do
    @event.update_columns(lease_expires_at: 1.minute.from_now)
    OidcBackchannelLogoutClient.stub(:call, ->(**) { flunk("leased row must not be sent") }) do
      OpOutboxDispatchJob.perform_now
    end

    assert_equal status("pending"), @event.reload.status_id
  end

  test "a delayed failed worker cannot overwrite a successor delivery that already acknowledged" do
    now = OpAppAuthorityStopParticipant.database_now + 1
    deliveries = 0
    OpAppAuthorityStopParticipant.stub(:database_now, -> { now }) do
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
    assert_equal [status("acknowledged"), "acknowledged"], [@event.status_id, @event.last_outcome]
  end

  test "lease expiry one microsecond before at and after the writer clock controls redelivery" do
    now = OpAppAuthorityStopParticipant.database_now + 1
    [-Rational(1, 1_000_000), 0, Rational(1, 1_000_000)].each do |offset|
      @event.update!(lease_expires_at: now + offset, next_attempt_at: now - 1, status_id: status("pending"))
      calls = 0
      OpAppAuthorityStopParticipant.stub(:database_now, now) do
        OidcBackchannelLogoutClient.stub(
          :call, ->(**) {
                   calls += 1
                   :acknowledged
                 },
        ) do
          OpOutboxDispatchJob.perform_now
        end
      end

      assert_equal offset.positive? ? 0 : 1, calls, [offset, @event.reload.attributes, now].inspect
    end
  end

  test "backoff immediately below at and above saturation stays bounded even after prolonged outages" do
    now = OpAppAuthorityStopParticipant.database_now + 1
    [[11, 2048], [12, 3600], [13, 3600], [1_000_000, 3600]].each do |attempts, seconds|
      @event.update!(
        delivery_attempts: attempts - 1, lease_expires_at: now - 1, next_attempt_at: now - 1,
        status_id: status("pending"),
      )
      OpAppAuthorityStopParticipant.stub(:database_now, now) do
        OidcBackchannelLogoutClient.stub(:call, "http_503") do
          OpOutboxDispatchJob.perform_now
        end
      end

      assert_equal now + seconds, @event.reload.next_attempt_at
      assert_equal attempts, @event.delivery_attempts
    end
  end

  private

  def status(name) = OpAuthorityStopReference.participant_status_id(name)
end
