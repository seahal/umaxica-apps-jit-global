# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class OidcSubjectTest < ActiveSupport::TestCase
  test "uses prefixed public subject instead of database id" do
    client = clients(:one)

    assert_equal "cli_#{client.public_id}", OidcSubject.for(client, resource_type: "client")
    assert_equal client.public_id, OidcSubject.public_id_from("cli_#{client.public_id}", resource_type: "client")
  end

  test "uses separate prefixes for each actor type" do
    assert_equal "opr", OidcSubject.prefix_for("operator")
    assert_equal "vis", OidcSubject.prefix_for("visitor")
  end

  test "uses oidc_subject when resource provides it" do
    resource = OpenStruct.new(oidc_subject: "custom-oidc-id", public_id: "cli_abc123")

    assert_equal "cli_custom-oidc-id", OidcSubject.for(resource, resource_type: "client")
  end

  test "raises when resource lacks both oidc_subject and public_id" do
    resource = OpenStruct.new

    assert_raises(ArgumentError) { OidcSubject.for(resource, resource_type: "client") }
  end

  test "infers operator resource type" do
    operator = Operator.new(security_mode_id: SecurityModeConfigurable::ADVANCED, id: 1, public_id: "opr_xyz")

    assert_equal "opr_#{operator.public_id}", OidcSubject.for(operator)
  end

  test "infers visitor resource type" do
    visitor = Visitor.new(security_mode_id: SecurityModeConfigurable::NORMAL, id: 1, public_id: "vis_xyz")

    assert_equal "vis_#{visitor.public_id}", OidcSubject.for(visitor)
  end

  test "defaults to client prefix for unknown resource types" do
    unknown = OpenStruct.new(public_id: "custom_001")

    assert_equal "cli_custom_001", OidcSubject.for(unknown)
  end
end
