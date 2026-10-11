# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthorityVocabularyTest < ActiveSupport::TestCase
  test "persona vocabulary exposes an interface and a concrete app implementation" do
    assert_instance_of Module, Persona
    assert_equal "personas", ClientPersona.table_name
    assert_includes ClientPersona.included_modules, Persona
    assert_not_equal Persona, ClientPersona
  end

  test "organization vocabulary exposes an interface and a concrete legacy org implementation" do
    assert_instance_of Module, Organization
    assert_equal "organizations", OperatorOrganization.table_name
    assert_includes OperatorOrganization.included_modules, Organization
    assert_not_equal Organization, OperatorOrganization
  end

  test "legacy organization fixture resolves through the renamed concrete model" do
    assert_instance_of OperatorOrganization, organizations(:one)
  end
end
