# typed: false
# frozen_string_literal: true

require "test_helper"

class OrganizationPolicyTest < ActiveSupport::TestCase
  def setup
    @user = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    @other_user = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    @record = BaseSelectorBootstrapAuthority.call(surface: :app, principal: @user).collective
    @other_record = BaseSelectorBootstrapAuthority.call(surface: :app, principal: @other_user).collective
    @policy = OrganizationPolicy.new(@record, user: @user)
  end

  test "index is denied by default" do
    assert_not @policy.index?
  end

  test "show allows an organization with an active membership for the principal" do
    assert_predicate @policy, :show?
  end

  test "show rejects an organization outside the principal membership set" do
    assert_not OrganizationPolicy.new(@other_record, user: @user).show?
  end

  test "create update and destroy stay denied" do
    assert_not @policy.create?
    assert_not @policy.update?
    assert_not @policy.destroy?
  end
end
