# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class AccountPolicyTest < ActiveSupport::TestCase
  def setup
    @user = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    @other_user = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    @record = BaseSelectorBootstrapAuthority.call(surface: :app, principal: @user).account
    @other_record = BaseSelectorBootstrapAuthority.call(surface: :app, principal: @other_user).account
    @policy = AccountPolicy.new(@record, user: @user)
  end

  def test_index
    assert_not @policy.index?
  end

  def test_show
    assert_predicate @policy, :show?
  end

  def test_show_rejects_account_owned_by_another_principal
    assert_not AccountPolicy.new(@other_record, user: @user).show?
  end

  def test_show_after_account_family_cutover_uses_explicit_ownership_not_legacy_identity
    ClientPersonaAuthorityCutover.establish!
    @record.ownership.update!(client: @other_user)

    assert_not AccountPolicy.new(@record, user: @user).show?
    assert_predicate AccountPolicy.new(@record, user: @other_user), :show?
  end

  def test_show_after_account_family_cutover_rejects_an_ineligible_owner
    ClientPersonaAuthorityCutover.establish!
    @other_user.update!(status_id: ClientStatus::INACTIVE)
    @record.ownership.update!(client: @other_user)

    assert_not AccountPolicy.new(@record, user: @other_user).show?
  end

  def test_create
    assert_not @policy.create?
  end

  def test_new
    assert_not @policy.new?
  end

  def test_update
    assert_not @policy.update?
  end

  def test_edit
    assert_not @policy.edit?
  end

  def test_destroy
    assert_not @policy.destroy?
  end
end
