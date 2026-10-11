# typed: false
# frozen_string_literal: true

require "test_helper"

class CoreRpBridgeTest < ActiveSupport::TestCase
  test "app bridge exposes core client identity for the client actor" do
    client = clients(:one)
    bridge = CoreAppClientBridge.create!(client:)

    assert_predicate bridge.public_id, :present?
    assert_equal "core-app", bridge.rp_client_id
    assert_equal "umaxica-core-app", bridge.audience
    assert_equal "jpx.umaxica.app", bridge.host
    assert_equal client, bridge.actor
    assert_equal client.public_id, bridge.subject
    assert_predicate bridge, :core?
    assert_equal AppRpRecord.connection_db_config.name, bridge.class.connection_db_config.name
    assert_equal bridge, client.reload.core_app_client_bridge
  end

  test "com bridge exposes core visitor identity for the visitor actor" do
    visitor = Visitor.create!
    bridge = CoreComVisitorBridge.create!(visitor:)

    assert_predicate bridge.public_id, :present?
    assert_equal "core-com", bridge.rp_client_id
    assert_equal "umaxica-core-com", bridge.audience
    assert_equal "jpx.umaxica.com", bridge.host
    assert_equal visitor, bridge.actor
    assert_equal visitor.public_id, bridge.subject
    assert_predicate bridge, :core?
    assert_equal ComRpRecord.connection_db_config.name, bridge.class.connection_db_config.name
    assert_equal bridge, visitor.reload.core_com_visitor_bridge
  end

  test "org bridge exposes core operator identity for the operator actor" do
    operator = operators(:one)
    bridge = CoreOrgOperatorBridge.create!(operator:)

    assert_predicate bridge.public_id, :present?
    assert_equal "core-org", bridge.rp_client_id
    assert_equal "umaxica-core-org", bridge.audience
    assert_equal "jpx.umaxica.org", bridge.host
    assert_equal operator, bridge.actor
    assert_equal operator.public_id, bridge.subject
    assert_predicate bridge, :core?
    assert_equal OrgRpRecord.connection_db_config.name, bridge.class.connection_db_config.name
    assert_equal bridge, operator.reload.core_org_operator_bridge
  end

  test "bridge requires an actor" do
    bridge = CoreAppClientBridge.new

    assert_not bridge.valid?
    assert bridge.errors.of_kind?(:client, :blank)
  end

  test "bridge allows only one row per actor and rp client" do
    client = clients(:two)
    CoreAppClientBridge.create!(client:)

    duplicate = CoreAppClientBridge.new(client:)

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:client_id, :taken)
  end
end
