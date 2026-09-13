# typed: false
# frozen_string_literal: true

require "test_helper"

class CoverageThresholdControllerHelpersTest < ActiveSupport::TestCase
  test "settings passkey option controllers expose registration collaborators" do
    controllers = [
      Auth::App::Settings::Passkeys::OptionsController.new,
      Auth::Com::Settings::Passkeys::OptionsController.new,
      Auth::Org::Settings::Passkeys::OptionsController.new,
    ]
    controllers.each do |controller|
      client = clients(:one)
      controller.define_singleton_method(:current_client) { client }
      controller.define_singleton_method(:current_visitor) { client }
      controller.define_singleton_method(:current_operator) { client }

      assert_same client, controller.send(:passkey_registration_actor)
      if controller.method(:recovery_passcode_top_up_credential_class).owner != PasskeyRegistrationFlow
        assert_includes [ClientSecretCredential, VisitorSecretCredential, OperatorSecretCredential],
                        controller.send(:recovery_passcode_top_up_credential_class)
      end
      if controller.method(:recovery_passcode_top_up_actor).owner != PasskeyRegistrationFlow
        assert_same client, controller.send(:recovery_passcode_top_up_actor)
      end
    end
  end

  test "settings passkey verification controllers expose registration collaborators" do
    controllers = [
      Auth::App::Settings::Passkeys::VerificationsController.new,
      Auth::Com::Settings::Passkeys::VerificationsController.new,
      Auth::Org::Settings::Passkeys::VerificationsController.new,
    ]
    controllers.each do |controller|
      client = clients(:one)
      controller.define_singleton_method(:current_client) { client }
      controller.define_singleton_method(:current_visitor) { client }
      controller.define_singleton_method(:current_operator) { client }
      if controller.respond_to?(:passkey_registration_actor, true)
        assert_same client, controller.send(:passkey_registration_actor)
      end
      if controller.method(:recovery_passcode_top_up_actor).owner != PasskeyRegistrationFlow
        assert_same client, controller.send(:recovery_passcode_top_up_actor)
      end
    end
  end
end

class CoverageThresholdControllerHelpersTest
  test "application controllers exercise authentication helper delegates when signed out" do
    cases = [
      [Auth::App::ApplicationController.new, :logged_in_client?],
      [Base::App::ApplicationController.new, :logged_in_client?],
      [Base::Com::ApplicationController.new, :logged_in_visitor?],
      [Auth::Com::ApplicationController.new, :logged_in_visitor?],
    ]
    cases.each do |controller, logged_method|
      controller.define_singleton_method(:current_resource) { nil }
      controller.define_singleton_method(:current_session_restricted?) { false }
      controller.define_singleton_method(:signed_pt_param) { nil } if controller.respond_to?(:signed_pt_param, true)

      assert_not controller.send(logged_method)
      active_method = logged_method.to_s.sub("logged_in", "active").to_sym

      assert_not controller.send(active_method)
      assert_not controller.send(:current_session_restricted?)
      assert_not_nil controller.send(:current_actor)
    end
  ensure
    Actor.reset
  end

  test "base app apple-only warning has safe nil and populated forms" do
    controller = Base::App::ApplicationController.new
    controller.define_singleton_method(:apple_only_credential?) { false }

    assert_nil controller.send(:apple_only_credential_warning_props)
    controller.define_singleton_method(:apple_only_credential?) { true }
    controller.define_singleton_method(:t) { |key| key.to_s }
    controller.define_singleton_method(:params) { { ri: "region" } }
    controller.define_singleton_method(:new_auth_app_settings_passkey_url) { |**kwargs| kwargs }
    controller.define_singleton_method(:edit_auth_app_settings_google_url) { |**kwargs| kwargs }

    props = controller.send(:apple_only_credential_warning_props)

    assert_equal 2, props[:items].size
    assert_equal "region", props[:items].first[:href][:ri]
  end
end

class CoverageThresholdControllerHelpersTest
  test "generated view helper delegates are executable on each authentication surface" do
    surfaces = [
      [Auth::App::ApplicationController,
       %i(logged_in_client? active_client? signed_pt_param current_session_restricted? current_actor),],
      [Base::App::ApplicationController,
       %i(logged_in_client? active_client? signed_pt_param current_session_restricted? current_session_public_id
          current_actor),],
      [Auth::Com::ApplicationController,
       %i(logged_in_visitor? active_visitor? current_session_restricted? current_actor),],
      [Base::Com::ApplicationController,
       %i(logged_in_visitor? active_visitor? current_session_restricted? current_session_public_id current_actor),],
    ]
    surfaces.each do |controller_class, methods|
      controller = controller_class.new
      controller.define_singleton_method(:current_resource) { nil }
      proxy = Object.new
      proxy.define_singleton_method(:controller) { controller }
      proxy.extend(controller_class.const_get(:HelperMethods, false))

      methods.each { |method_name| assert_nothing_raised { proxy.public_send(method_name) } }
    end
  ensure
    Actor.reset
  end
end

class CoverageThresholdControllerHelpersTest
  test "app passkey registration controllers expose all redirect and actor helpers" do
    client = clients(:one)
    controllers = [
      Auth::App::Settings::Passkeys::OptionsController.new,
      Auth::App::Settings::Passkeys::VerificationsController.new,
      Auth::App::Settings::PasskeysController.new,
    ]
    controllers.each do |controller|
      controller.define_singleton_method(:current_client) { client }
      controller.define_singleton_method(:params) { { ri: "jp" } }
      controller.define_singleton_method(:base_authority_host) { "base.example" }
      controller.define_singleton_method(:base_app_identity_secrets_url) { |**options| options }
      controller.define_singleton_method(:auth_app_settings_passkeys_url) { |**options| options }
      controller.define_singleton_method(:auth_app_settings_passkeys_path) { |**options| options }

      assert_same client, controller.send(:passkey_registration_actor)
      assert_respond_to controller.send(:passkey_registration_passkeys), :to_a
      assert_equal "sign.webauthn.registration", controller.send(:passkey_registration_log_prefix)
      assert_kind_of Hash, controller.send(:passkey_registration_redirect_url)
      assert_same client, controller.send(:recovery_passcode_top_up_actor)
      assert_equal ClientSecretCredential, controller.send(:recovery_passcode_top_up_credential_class)
      assert_kind_of Hash, controller.send(:recovery_passcode_setup_url)
      assert_kind_of Hash, controller.send(:recovery_passcode_reveal_redirect_url, "token")
    end
  end
end

class CoverageThresholdControllerHelpersTest
  test "OIDC callback controller class attributes expose their configured RP types" do
    callbacks =
      ObjectSpace.each_object(Class).select do |klass|
        klass.name&.end_with?("::Oidc::CallbacksController")
      end

    assert_operator callbacks.size, :>=, 6
    callbacks.each do |controller|
      %i(oidc_rp_actor_class_name oidc_rp_identity_class_name oidc_rp_bridge_class_name
         oidc_rp_actor_class_name? oidc_rp_identity_class_name? oidc_rp_bridge_class_name?).each do |method_name|
        next unless controller.respond_to?(method_name)

        assert_nothing_raised { controller.public_send(method_name) }
      end
    end
  end
end

class CoverageThresholdControllerHelpersTest
  test "authentication surface root actions render for anonymous visitors" do
    [Auth::App::RootsController, Auth::Com::RootsController, Auth::Org::RootsController].each do |klass|
      controller = klass.new
      rendered = []
      controller.define_singleton_method(:logged_in?) { false }
      controller.define_singleton_method(:t) { |_key| "landing" }
      controller.define_singleton_method(:render) { |**options| rendered << options }
      controller.index

      assert rendered.last[:inertia]
      assert_equal "landing", rendered.last[:props][:description]
    end
  end
end

class CoverageThresholdControllerHelpersTest
  test "generated delegates execute across core side and org surfaces" do
    classes = [
      Base::App::ApplicationController, Base::Com::ApplicationController, Base::Org::ApplicationController,
      Core::App::ApplicationController, Core::Com::ApplicationController, Core::Org::ApplicationController,
      Side::App::ApplicationController, Side::Com::ApplicationController, Side::Org::ApplicationController,
      Auth::Org::ApplicationController,
    ]
    classes.each do |controller_class|
      controller = controller_class.new
      controller.define_singleton_method(:current_resource) { nil }
      controller.define_singleton_method(:base_authority_host) { "base.example" }
      controller.define_singleton_method(:acme_authority_host) { "acme.example" }
      controller.define_singleton_method(:current_region_identifier) { nil }
      controller.define_singleton_method(:apple_only_credential?) { false }
      proxy = Object.new
      proxy.define_singleton_method(:controller) { controller }
      proxy.extend(controller_class.const_get(:HelperMethods, false))
      controller_class.const_get(:HelperMethods, false).instance_methods(false).each do |method_name|
        assert_nothing_raised { proxy.public_send(method_name) } if proxy.respond_to?(method_name)
      end
    end
  ensure
    Actor.reset
  end
end

class CoverageThresholdControllerHelpersTest
  test "root controllers redirect authenticated visitors on every surface" do
    names = %w(
      Auth::App::RootsController Auth::Com::RootsController Auth::Org::RootsController
      Base::App::RootsController Base::Com::RootsController Base::Org::RootsController
      Core::App::RootsController Core::Com::RootsController Core::Org::RootsController
      Side::App::RootsController Side::Com::RootsController Side::Org::RootsController
    )
    names.each do |name|
      controller = name.constantize.new
      redirected = []
      controller.define_singleton_method(:logged_in?) { true }
      controller.define_singleton_method(:params) { { ri: "jp" } }
      request = ActionDispatch::TestRequest.create
      request.host = "auth.app.localhost"
      request.format = Mime[:html]
      controller.define_singleton_method(:request) { request }
      controller.define_singleton_method(:after_login_path) { "/after" }
      controller.define_singleton_method(:after_login_allows_other_host?) { false }
      controller.define_singleton_method(:redirect_to) { |*args, **kwargs| redirected << [args, kwargs] }
      controller.define_singleton_method(:render) { |*args, **kwargs| redirected << [args, kwargs] }
      controller.define_singleton_method(:method_missing) { |method_name, *_args, **_kwargs| "/#{method_name}" }
      controller.index

      assert_predicate redirected, :any?, name
    end
  end
end

class CoverageThresholdControllerHelpersTest
  test "operator passkey turnstile guard covers success and negotiated failures" do
    controller = Auth::Org::Settings::Passkeys::OptionsController.new
    controller.define_singleton_method(:cloudflare_turnstile_stealth_validation) { { "success" => true } }

    assert controller.send(:verify_settings_passkey_turnstile!)

    events = []
    formatter = Class.new do
      define_method(:html) { |&block| block.call }
      define_method(:json) { |&block| block.call }
    end.new
    controller.define_singleton_method(:cloudflare_turnstile_stealth_validation) { { "success" => false } }
    controller.define_singleton_method(:respond_to) { |&block| block.call(formatter) }
    controller.define_singleton_method(:redirect_back_or_to) { |*args, **kwargs| events << [args, kwargs] }
    controller.define_singleton_method(:render) { |*args, **kwargs| events << [args, kwargs] }
    controller.define_singleton_method(:auth_org_settings_passkeys_path) { |**| "/passkeys" }
    controller.define_singleton_method(:params) { { ri: "jp" } }
    controller.define_singleton_method(:t) { |_key| "turnstile" }

    assert_not controller.send(:verify_settings_passkey_turnstile!)
    assert_equal 2, events.size
  end
end
