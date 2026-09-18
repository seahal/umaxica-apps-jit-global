# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class AcmeSelectorSurfaceConfigTest < ActiveSupport::TestCase
  test "CONFIGS contains three surfaces" do
    assert_equal %i(app com org), AcmeSelectorSurfaceConfig::CONFIGS.keys.sort
  end

  test "app config has correct attributes" do
    config = AcmeSelectorSurfaceConfig::CONFIGS[:app]

    assert_equal :app, config.surface
    assert_equal Client, config.principal_class
    assert_equal ClientToken, config.token_class
    assert_equal ClientAccount, config.rp_account_class
    assert_equal :user_id, config.rp_account_foreign_key
    assert_equal ClientIdentity, config.identity_class
    assert_equal ClientIdentityState, config.identity_state_class
    assert_equal ClientPersona, config.account_class
    assert_equal PersonaAssignment, config.account_assignment_class
    assert_equal :persona_id, config.account_assignment_account_key
    assert_equal :client_identity_id, config.account_assignment_identity_key
    assert_equal Enterprise, config.collective_class
    assert_equal EnterpriseUnit, config.unit_class
    assert_equal PersonaMembership, config.membership_class
    assert config.requires_avatar
    assert_equal "Persona01", config.account_title
    assert_equal "Org01", config.collective_title
  end

  test "com config has correct attributes" do
    config = AcmeSelectorSurfaceConfig::CONFIGS[:com]

    assert_equal :com, config.surface
    assert_equal Visitor, config.principal_class
    assert_equal VisitorToken, config.token_class
    assert_equal VisitorAccount, config.rp_account_class
    assert_equal :visitor_id, config.rp_account_foreign_key
    assert_equal VisitorIdentity, config.identity_class
    assert_equal VisitorIdentityState, config.identity_state_class
    assert_equal Individual, config.account_class
    assert_equal IndividualAssignment, config.account_assignment_class
    assert_equal :individual_id, config.account_assignment_account_key
    assert_equal :visitor_identity_id, config.account_assignment_identity_key
    assert_equal Company, config.collective_class
    assert_equal CompanyUnit, config.unit_class
    assert_equal IndividualMembership, config.membership_class
    assert_not config.requires_avatar
    assert_equal "Indiv01", config.account_title
    assert_equal "Org01", config.collective_title
  end

  test "org config has correct attributes" do
    config = AcmeSelectorSurfaceConfig::CONFIGS[:org]

    assert_equal :org, config.surface
    assert_equal Operator, config.principal_class
    assert_equal OperatorToken, config.token_class
    assert_equal OperatorAccount, config.rp_account_class
    assert_equal :staff_id, config.rp_account_foreign_key
    assert_equal OperatorIdentity, config.identity_class
    assert_equal OperatorIdentityState, config.identity_state_class
    assert_equal Agent, config.account_class
    assert_equal AgentAssignment, config.account_assignment_class
    assert_equal :agent_id, config.account_assignment_account_key
    assert_equal :operator_identity_id, config.account_assignment_identity_key
    assert_equal Bureau, config.collective_class
    assert_equal BureauUnit, config.unit_class
    assert_equal AgentMembership, config.membership_class
    assert_not config.requires_avatar
    assert_equal "Agent01", config.account_title
    assert_equal "Org01", config.collective_title
  end

  test "configs are frozen" do
    AcmeSelectorSurfaceConfig::CONFIGS.each_value do |config|
      assert_predicate config, :frozen?
    end
  end
end
