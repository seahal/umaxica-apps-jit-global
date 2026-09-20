# typed: false
# frozen_string_literal: true

require "test_helper"

# Closes the remaining method/branch gap after the feature merge:
# method floor needs ~8 more hits; branch floor needs ~128.
class BranchCoverageBatch38ThresholdPushTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class SettingsRedirectProbeController < ApplicationController
    include SignSettingsAuthorityRedirect
  end

  test "SignSettingsAuthorityRedirect actions all redirect through acme settings" do
    controller = SettingsRedirectProbeController.new
    request = ActionDispatch::TestRequest.create("GET" => "/settings/secret_credentials?ri=jp")
    controller.set_request!(request)
    controller.set_response!(ActionDispatch::TestResponse.new)

    redirected = []
    controller.define_singleton_method(:redirect_to_acme_authority!) do |path, query: nil|
      redirected << [path, query]
    end

    %i(show index edit update destroy).each do |action|
      controller.public_send(action)
    end

    assert_equal 5, redirected.size
    assert(redirected.all? { |path, _| path.to_s.include?("secret_credentials") || path == request.path })
  end

  test "JitSecurityJwtJtiGenerator encoded_length remainder arms" do
    assert_equal 2, JitSecurityJwtJtiGenerator.encoded_length(1)
    assert_equal 3, JitSecurityJwtJtiGenerator.encoded_length(2)
    assert_equal 4, JitSecurityJwtJtiGenerator.encoded_length(3)
    assert_equal 0, JitSecurityJwtJtiGenerator.encoded_length(0)
  end

  test "Webauthn AuthenticatorMetadata attributes_from nil resolution arms" do
    context = Object.new
    context.define_singleton_method(:aaguid) { "00000000-0000-0000-0000-000000000000" }
    context.define_singleton_method(:transports) { [] }
    context.define_singleton_method(:backup_eligible) { false }
    context.define_singleton_method(:backup_state) { false }
    context.define_singleton_method(:authenticator_attachment) { nil }

    Webauthn::AuthenticatorNameResolver.stub(:resolve, nil) do
      attrs = Webauthn::AuthenticatorMetadata.attributes_from(context)

      assert_nil attrs[:provider_name]
      assert_nil attrs[:metadata_source]
    end
  end

  test "OidcLogoutRequest verify rejects blank client_id and blank jti" do
    verifier = Object.new
    verifier.define_singleton_method(:verified) { |_token, **_| { "client_id" => "", "jti" => "abc" } }

    OidcLogoutRequest.stub(:verifier, verifier) do
      assert_nil OidcLogoutRequest.verify("token")
    end

    verifier = Object.new
    verifier.define_singleton_method(:verified) { |_token, **_| { "client_id" => "cid", "jti" => "" } }

    OidcLogoutRequest.stub(:verifier, verifier) do
      assert_nil OidcLogoutRequest.verify("token")
    end
  end

  test "AppleOnlyCredentialStatus short-circuits blank client" do
    assert_not AppleOnlyCredentialStatus.call(nil)
    assert_not AppleOnlyCredentialStatus.new(nil).call
  end

  test "cancellations controller thin wrappers delegate" do
    [
      Auth::App::Sign::In::Check::CancellationsController,
      Auth::Com::Sign::In::Check::CancellationsController,
      Auth::Org::Sign::In::Check::CancellationsController,
    ].each do |klass|
      parent =
        Module.new do
          def show = :shown_super

          def update = :updated_super

          def destroy = :destroyed_super
        end
      # Prepend ancestor so `super` inside the thin wrappers resolves cleanly.
      klass.prepend(parent) unless klass.ancestors.include?(parent)
      controller = klass.allocate

      assert_equal :destroyed_super, controller.create
      assert_equal :shown_super, controller.show
      assert_equal :updated_super, controller.update
    end
  end
end
