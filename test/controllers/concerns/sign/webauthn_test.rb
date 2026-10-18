# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign
  class WebauthnTest < ActionDispatch::IntegrationTest
    class TestController < ApplicationController
      include PasskeyCeremonyContext

      webauthn_surface :app

      attr_accessor :request, :session

      def initialize
        super
        @session = {}
      end
    end

    setup do
      @controller = TestController.new
    end

    test "ceremony state helpers remain private" do
      %i(
        passkey_challenge_store
        passkey_actor_global_key
        passkey_actor_id_from
        issue_passkey_registration_challenge
        issue_passkey_authentication_challenge
        consume_passkey_challenge!
        consume_passkey_challenge_with_actor!
        discard_passkey_challenge
        webauthn_credential_ids
        passkey_resource_display_name
      ).each do |method_name|
        assert_includes @controller.private_methods, method_name
        assert_not_includes @controller.public_methods, method_name
      end
    end

    test "declared surface and relying-party configuration are public" do
      assert_equal :app, @controller.webauthn_surface.key
      assert_respond_to @controller, :webauthn_relying_party_config
      assert_not_includes @controller.private_methods, :webauthn_surface
      assert_not_includes @controller.private_methods, :webauthn_relying_party_config
    end
  end
end
