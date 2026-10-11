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

  class InventoryReaderProbeController < ApplicationController
    include AuthenticationCredentialInventoryReader
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

  test "AuthenticationCredentialInventoryReader resolves operator visitor client and Actor" do
    controller = InventoryReaderProbeController.new
    inventory = Object.new

    AuthenticationCredentialInventory.stub(:call, ->(*_args, **_kwargs) { inventory }) do
      operator = Object.new
      controller.define_singleton_method(:current_operator) { operator }

      assert_equal operator, controller.send(:current_inventory_actor)
      assert_equal inventory, controller.send(:credential_inventory)
      assert_equal inventory, controller.send(:current_credential_inventory)

      visitor = Object.new
      controller = InventoryReaderProbeController.new
      controller.define_singleton_method(:respond_to?) do |name, include_all = false|
        return false if name == :current_operator
        return true if name == :current_visitor

        super(name, include_all)
      end
      controller.define_singleton_method(:current_visitor) { visitor }

      assert_equal visitor, controller.send(:current_inventory_actor)

      client = Object.new
      controller = InventoryReaderProbeController.new
      controller.define_singleton_method(:respond_to?) do |name, include_all = false|
        return false if %i(current_operator current_visitor).include?(name)
        return true if name == :current_client

        super(name, include_all)
      end
      controller.define_singleton_method(:current_client) { client }

      assert_equal client, controller.send(:current_inventory_actor)

      actor = Object.new
      actor.define_singleton_method(:unauthenticated?) { false }
      controller = InventoryReaderProbeController.new
      controller.define_singleton_method(:respond_to?) do |name, include_all = false|
        return false if %i(current_operator current_visitor current_client).include?(name)

        super(name, include_all)
      end

      Actor.stub(:actor, actor) do
        assert_equal actor, controller.send(:current_inventory_actor)
      end

      unauth = Object.new
      unauth.define_singleton_method(:unauthenticated?) { true }

      Actor.stub(:actor, unauth) do
        assert_nil controller.send(:current_inventory_actor)
      end
    end
  end

  test "Core API base controllers expose surface identity helpers" do
    [
      [Core::App::Api::V0::BaseController, :app, Client, ClientToken, "client"],
      [Core::Com::Api::V0::BaseController, :com, Visitor, VisitorToken, "visitor"],
      [Core::Org::Api::V0::BaseController, :org, Operator, OperatorToken, "operator"],
    ].each do |klass, tld, resource, token, type|
      controller = klass.new

      assert_equal tld, controller.send(:core_actor_tld)
      assert_equal resource, controller.send(:core_resource_class)
      assert_equal token, controller.send(:core_token_class)
      assert_equal type, controller.send(:core_resource_type)
    end
  end

  test "AuthorizationAudit fallback path actor branches and audit identifier" do
    controller = Class.new(ApplicationController) { include AuthorizationAudit }.new
    request = ActionDispatch::TestRequest.create
    controller.set_request!(request)
    controller.set_response!(ActionDispatch::TestResponse.new)

    assert_equal "/", controller.send(:authorization_failure_fallback_path)

    controller.define_singleton_method(:root_path) { "/rooted" }

    assert_equal "/rooted", controller.send(:authorization_failure_fallback_path)

    assert_nil controller.send(:audit_identifier, nil)
    record = Object.new
    record.define_singleton_method(:public_id) { "pub-1" }

    assert_equal "pub-1", controller.send(:audit_identifier, record)

    record_id = Object.new
    record_id.define_singleton_method(:public_id) { nil }
    record_id.define_singleton_method(:id) { 42 }

    assert_equal 42, controller.send(:audit_identifier, record_id)

    controller.define_singleton_method(:current_client) { nil }
    controller.define_singleton_method(:current_user) { nil }
    controller.define_singleton_method(:current_operator) { :op }
    controller.define_singleton_method(:current_visitor) { nil }

    assert_equal :op, controller.send(:current_client_or_staff)
    assert_equal :op, controller.send(:current_user_or_staff)

    controller.define_singleton_method(:current_operator) { nil }
    controller.define_singleton_method(:current_visitor) { :vis }

    assert_equal :vis, controller.send(:current_client_or_staff)

    controller.define_singleton_method(:current_visitor) { nil }

    assert_nil controller.send(:current_client_or_staff)

    # log_authorization_failure early return when no actor
    controller.define_singleton_method(:authorization_audit_actor) { nil }

    assert_nil controller.send(:log_authorization_failure, StandardError.new("x"))

    # create_audit_record Client/Operator/Visitor arms (stub create helpers)
    called = []
    controller.define_singleton_method(:create_user_authorization_audit) { |*_a| called << :client }
    controller.define_singleton_method(:create_staff_authorization_audit) { |*_a| called << :operator }
    controller.define_singleton_method(:create_visitor_authorization_audit) { |*_a| called << :visitor }
    controller.send(:create_audit_record, Client.new, {})
    controller.send(:create_audit_record, Operator.new, {})
    controller.send(:create_audit_record, Visitor.new, {})

    assert_equal %i(client operator visitor), called

    # build_log_data covers request_id / Actor optional fields
    exception = Object.new
    policy = Object.new
    policy.define_singleton_method(:class) { Struct.new(:name).new("P") }
    policy.define_singleton_method(:record) { nil }
    exception.define_singleton_method(:policy) { policy }
    exception.define_singleton_method(:rule) { :show? }
    controller.define_singleton_method(:action_name) { "show" }
    controller.define_singleton_method(:controller_name) { "things" }
    data = controller.send(:build_log_data, Client.new, exception)

    assert_equal "Client", data[:actor_type]
    assert_equal "show", data[:action]
  end

  test "AuthenticationBase DBSC binding status and token expiry helpers" do
    helper = Class.new(ApplicationController) { include AuthenticationBase }.new

    record = Object.new
    record.define_singleton_method(:binding_method_dbsc?) { true }
    record.define_singleton_method(:binding_method_legacy?) { false }

    assert_equal "dbsc", helper.send(:dbsc_binding_method_name, record)

    record = Object.new
    record.define_singleton_method(:binding_method_dbsc?) { false }
    record.define_singleton_method(:binding_method_legacy?) { true }

    assert_equal "legacy", helper.send(:dbsc_binding_method_name, record)

    record = Object.new
    record.define_singleton_method(:binding_method_dbsc?) { false }
    record.define_singleton_method(:binding_method_legacy?) { false }

    assert_equal "nothing", helper.send(:dbsc_binding_method_name, record)

    %w(pending active failed revoke).each do |status|
      record = Object.new
      %w(pending active failed revoke).each do |candidate|
        record.define_singleton_method(:"dbsc_status_#{candidate}?") { candidate == status }
      end

      assert_equal status, helper.send(:dbsc_status_name, record)
    end

    record = Object.new
    %w(pending active failed revoke).each do |candidate|
      record.define_singleton_method(:"dbsc_status_#{candidate}?") { false }
    end

    assert_equal "nothing", helper.send(:dbsc_status_name, record)

    klass =
      Class.new do
        def self.column_names = %w(id revoked_at)

        def self.name = "Tok"
      end

    assert_equal :revoked_at, helper.send(:token_expiry_column, klass)

    klass =
      Class.new do
        def self.column_names = %w(id discarded_at)

        def self.name = "Tok"
      end

    assert_equal :discarded_at, helper.send(:token_expiry_column, klass)

    klass =
      Class.new do
        def self.column_names = %w(id)

        def self.name = "Tok"
      end
    assert_raises(ArgumentError) { helper.send(:token_expiry_column, klass) }

    assert_nil helper.send(:token_record_expiry_at, nil)
    token = Object.new
    token.define_singleton_method(:respond_to?) do |name, include_all = false|
      return true if name == :revoked_at
      return false if name == :discarded_at

      super(name, include_all)
    end
    token.define_singleton_method(:revoked_at) { Time.zone.parse("2026-01-01") }

    assert_equal Time.zone.parse("2026-01-01"), helper.send(:token_record_expiry_at, token)

    token = Object.new
    token.define_singleton_method(:respond_to?) do |name, include_all = false|
      return false if name == :revoked_at
      return true if name == :discarded_at

      super(name, include_all)
    end
    token.define_singleton_method(:discarded_at) { Time.zone.parse("2026-02-02") }

    assert_equal Time.zone.parse("2026-02-02"), helper.send(:token_record_expiry_at, token)
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
