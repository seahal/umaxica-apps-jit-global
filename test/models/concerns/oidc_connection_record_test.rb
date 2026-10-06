# typed: false
# frozen_string_literal: true

require "test_helper"

class OidcConnectionRecordTest < ActiveSupport::TestCase
  setup do
    ClientStatus.ensure_defaults!
    @user = Client.create!(public_id: "u_#{SecureRandom.hex(8)}", status_id: ClientStatus::ACTIVE)
  end

  test "status helpers classify active and revoked connections" do
    active = ClientOidcConnection.create!(user: @user, client_id: "core-app")
    revoked = ClientOidcConnection.create!(user: @user, client_id: "core-app", revoked_at: Time.current)

    assert_predicate active, :active?
    assert_not_predicate active, :revoked?
    assert_equal "active", active.status

    assert_predicate revoked, :revoked?
    assert_not_predicate revoked, :active?
    assert_equal "revoked", revoked.status
  end

  test "scopes returns nonblank scope tokens" do
    connection = ClientOidcConnection.new(scope: "openid  profile   email")

    assert_equal %w(openid profile email), connection.scopes
  end

  test "rp metadata uses registered client and falls back for unknown client" do
    registered = ClientOidcConnection.new(client_id: "core-app")
    unknown = ClientOidcConnection.new(client_id: "unknown-client")

    assert_equal "Core Next RP", registered.rp_name
    assert_predicate registered.rp_domains, :any?
    assert_equal registered.rp_domains.join(", "), registered.rp_domain_text

    assert_nil unknown.rp_client
    assert_equal "unknown-client", unknown.rp_name
    assert_empty unknown.rp_domains
    assert_equal "-", unknown.rp_domain_text
  end

  test "connected_at mirrors created_at" do
    now = Time.current.change(usec: 0)
    connection = ClientOidcConnection.new(created_at: now)

    assert_equal now, connection.connected_at
  end

  test "active scope excludes revoked connections" do
    active = ClientOidcConnection.create!(user: @user, client_id: "core-app")
    revoked = ClientOidcConnection.create!(user: @user, client_id: "core-app", revoked_at: Time.current)

    active_connections = ClientOidcConnection.active.to_a

    assert_includes active_connections, active
    assert_not_includes active_connections, revoked
  end

  test "active_tokens delegates to the surface token inventory" do
    client_connection = ClientOidcConnection.create!(user: @user, client_id: "core-app")
    operator = Operator.create!
    operator_connection = OperatorOidcConnection.create!(staff: operator, client_id: "core-org")
    visitor = Visitor.create!
    visitor_connection = VisitorOidcConnection.create!(visitor: visitor, client_id: "core-com")

    assert_equal client_connection.user_tokens.session_inventory, client_connection.active_tokens
    assert_equal operator_connection.staff_tokens.session_inventory, operator_connection.active_tokens
    assert_equal visitor_connection.visitor_tokens.session_inventory, visitor_connection.active_tokens
  end

  test "including class must define actor foreign key" do
    model_class =
      Class.new(ApplicationRecord) do
        self.table_name = "client_oidc_connections"
        include OidcConnectionRecord
      end

    error = assert_raises(NotImplementedError) { model_class.actor_foreign_key }

    assert_match "must define actor_foreign_key", error.message
  end
end
