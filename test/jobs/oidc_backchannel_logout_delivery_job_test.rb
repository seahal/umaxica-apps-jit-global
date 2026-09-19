# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class OidcBackchannelLogoutDeliveryJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  LOGOUT_URI = "https://id.app.localhost/oidc/backchannel_logout"

  teardown { Flipper.remove(:oidc_backchannel_logout_suspended) }

  test "perform mints the logout token during delivery" do
    sid = SecureRandom.uuid
    posted_body = nil
    stubs =
      Faraday::Adapter::Test::Stubs.new do |stub|
        stub.post(LOGOUT_URI) do |env|
          posted_body = env.body
          [200, {}, ""]
        end
      end

    stub_outbound_http(stubs) do
      OidcLogoutTokenCodec.stub(
        :encode, proc { |**kwargs|
                   assert_equal "sign-rp", kwargs.fetch(:client_id)
                   assert_equal "client", kwargs.fetch(:resource_type)
                   assert_equal "subject-1", kwargs.fetch(:subject)
                   assert_equal sid, kwargs.fetch(:sid)
                   "jwt-token"
                 },
      ) do
        encrypted_payload = OutboundSensitivePayload.encrypt_oidc_backchannel_logout(
          uri: LOGOUT_URI,
          client_id: "sign-rp",
          resource_type: "client",
          subject: "subject-1",
          sid: sid,
        )
        OidcClientRegistry.stub(
          :backchannel_logout_uris_for,
          [LOGOUT_URI],
        ) do
          OidcBackchannelLogoutDeliveryJob.perform_now(encrypted_payload)
        end
      end
    end

    stubs.verify_stubbed_calls

    assert_equal "jwt-token", Rack::Utils.parse_nested_query(posted_body)["logout_token"]
  end

  test "a global suspension mints no token and posts to no relying party" do
    Flipper.enable(:oidc_backchannel_logout_suspended)

    assert_nothing_raised { deliver_to("sign-rp") }
  end

  test "an actor suspension stops only the named relying party" do
    Flipper.enable_actor(
      :oidc_backchannel_logout_suspended,
      OidcClientFlipperActor.new(client_id: "sign-rp"),
    )

    assert_nothing_raised { deliver_to("sign-rp") }

    posted_to = deliver_to("other-rp", expect_delivery: true)

    assert_equal "id.app.localhost", posted_to
  end

  test "a permanent HTTP response is recorded as a failure and is raised" do
    error =
      assert_raises OidcBackchannelLogoutDeliveryJob::PermanentResponseError do
        deliver_with_response(400)
      end

    assert_equal 400, error.status
  end

  test "production refuses an HTTP logout destination before transport" do
    http_uri = "http://id.app.localhost/oidc/backchannel_logout"

    OidcClientRegistry.stub(:backchannel_logout_uris_for, [http_uri]) do
      OidcLogoutTokenCodec.stub(:encode, "jwt-token") do
        Rails.env.stub(:production?, true) do
          error =
            assert_raises(OutboundHttp::Connection::InsecureEndpointError) do
              OidcBackchannelLogoutDeliveryJob.perform_now(
                encrypted_delivery_payload(uri: http_uri),
              )
            end

          assert_match(/must be HTTPS/, error.message)
        end
      end
    end
  end

  test "a retryable HTTP response is scheduled for Active Job retry" do
    encrypted_payload = encrypted_delivery_payload

    stubs =
      Faraday::Adapter::Test::Stubs.new do |stub|
        stub.post(LOGOUT_URI) { [503, {}, ""] }
      end

    OidcClientRegistry.stub(:backchannel_logout_uris_for, [LOGOUT_URI]) do
      OidcLogoutTokenCodec.stub(:encode, "jwt-token") do
        stub_outbound_http(stubs) do
          assert_enqueued_with(
            job: OidcBackchannelLogoutDeliveryJob,
            args: [encrypted_payload],
          ) do
            OidcBackchannelLogoutDeliveryJob.perform_now(encrypted_payload)
          end
        end
      end
    end

    stubs.verify_stubbed_calls
  end

  test "a network failure escapes instead of being marked delivered" do
    stubs =
      Faraday::Adapter::Test::Stubs.new do |stub|
        stub.post(LOGOUT_URI) { raise Faraday::ConnectionFailed, "connection refused" }
      end

    error =
      assert_raises Faraday::ConnectionFailed do
        OidcClientRegistry.stub(:backchannel_logout_uris_for, [LOGOUT_URI]) do
          OidcLogoutTokenCodec.stub(:encode, "jwt-token") do
            stub_outbound_http(stubs) do
              OidcBackchannelLogoutDeliveryJob.new.perform(encrypted_delivery_payload)
            end
          end
        end
      end

    assert_equal "connection refused", error.message
    stubs.verify_stubbed_calls
  end

  private

  # Delivers to `client_id` with the network and the token codec stubbed to fail
  # the test if they are reached, unless `expect_delivery` says otherwise.
  # Returns the host that was posted to.
  def deliver_to(client_id, expect_delivery: false)
    host = nil
    stubs =
      Faraday::Adapter::Test::Stubs.new do |stub|
        stub.post(LOGOUT_URI) do |env|
          flunk("posted to #{env.url.host} while suspended") unless expect_delivery
          host = env.url.host
          [200, {}, ""]
        end
      end
    codec_stub =
      proc do |**_kwargs|
        flunk("minted a logout token while suspended") unless expect_delivery
        "jwt-token"
      end

    stub_outbound_http(stubs) do
      OidcLogoutTokenCodec.stub(:encode, codec_stub) do
        OidcClientRegistry.stub(
          :backchannel_logout_uris_for,
          [LOGOUT_URI],
        ) do
          OidcBackchannelLogoutDeliveryJob.perform_now(
            LOGOUT_URI,
            client_id,
            "client",
            "subject-1",
            SecureRandom.uuid,
          )
        end
      end
    end

    host
  end

  def deliver_with_response(status)
    stubs =
      Faraday::Adapter::Test::Stubs.new do |stub|
        stub.post(LOGOUT_URI) { [status, {}, ""] }
      end

    OidcClientRegistry.stub(:backchannel_logout_uris_for, [LOGOUT_URI]) do
      OidcLogoutTokenCodec.stub(:encode, "jwt-token") do
        stub_outbound_http(stubs) do
          OidcBackchannelLogoutDeliveryJob.new.perform(encrypted_delivery_payload)
        end
      end
    end
  ensure
    stubs&.verify_stubbed_calls
  end

  def encrypted_delivery_payload(uri: LOGOUT_URI)
    OutboundSensitivePayload.encrypt_oidc_backchannel_logout(
      uri: uri,
      client_id: "sign-rp",
      resource_type: "client",
      subject: "subject-1",
      sid: SecureRandom.uuid,
    )
  end
end
