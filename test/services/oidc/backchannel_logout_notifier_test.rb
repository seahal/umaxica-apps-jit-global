# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class OidcBackchannelLogoutNotifierTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "call enqueues logout context for delivery instead of a pre-minted token" do
    sid = SecureRandom.uuid
    client = OidcClientRegistry.find!("core-app")
    uri = "https://id.app.localhost/oidc/backchannel_logout"

    OidcClientRegistry.stub(:logout_clients_for_resource_type, [client]) do
      OidcClientRegistry.stub(:backchannel_logout_uris_for, [uri]) do
        assert_enqueued_jobs 1, only: OidcBackchannelLogoutDeliveryJob do
          count = OidcBackchannelLogoutNotifier.new(
            resource_type: "client",
            subject: "subject-1",
            sid: sid,
          ).call

          assert_equal 1, count
        end
      end
    end

    enqueued_jobs.each do |job|
      assert_equal OidcBackchannelLogoutDeliveryJob, job.fetch(:job)
      assert_equal 1, job.fetch(:args).size
      payload = OutboundSensitivePayload.decrypt_oidc_backchannel_logout(job[:args].first)

      assert_equal "core-app", payload.fetch(:client_id)
      assert_equal "client", payload.fetch(:resource_type)
      assert_equal "subject-1", payload.fetch(:subject)
      assert_equal sid, payload.fetch(:sid)
      assert_not_includes job[:args].inspect, "subject-1"
      assert_not_includes job[:args].inspect, sid
    end
  end

  test "call batches all logout deliveries for the same client" do
    sid = SecureRandom.uuid
    client = OidcClientRegistry.find!("core-app")
    uris = [
      "https://id.app.localhost/oidc/backchannel_logout",
      "https://id2.app.localhost/oidc/backchannel_logout",
    ]

    OidcClientRegistry.stub(:logout_clients_for_resource_type, [client]) do
      OidcClientRegistry.stub(:backchannel_logout_uris_for, uris) do
        assert_enqueued_jobs 2, only: OidcBackchannelLogoutDeliveryJob do
          count = OidcBackchannelLogoutNotifier.new(
            resource_type: "client",
            subject: "subject-1",
            sid: sid,
          ).call

          assert_equal 2, count
        end
      end
    end
  end

  test "call raises when sid is missing but subject is present" do
    assert_raises(ArgumentError, "logout token requires sid") do
      OidcBackchannelLogoutNotifier.new(
        resource_type: "client",
        subject: "subject-1",
        sid: nil,
      ).call
    end
  end
end
