# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class BaseSelectorAuthorityTest < ActiveSupport::TestCase
  setup do
    @user = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    @token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    @bootstrap = BaseSelectorBootstrapAuthority.call(surface: :app, principal: @user)
  end

  test "auto selects when only one valid candidate exists" do
    result = BaseSelectorAuthority.prepare(surface: :app, principal: @user, session: @token)

    assert_equal "selected", result[:status]
    assert_equal "/", result[:next]
    assert_predicate @token.reload, :selected_actor_context?
    assert_predicate @token.selected_avatar_public_id, :present?
  end

  test "returns selection required when multiple valid candidates exist" do
    persona = @bootstrap.account
    enterprise = Enterprise.create!(name: "Second", title: "Second")
    unit = EnterpriseUnit.create!(enterprise: enterprise, name: "Default")
    PersonaMembership.create!(
      persona: persona,
      enterprise: enterprise,
      enterprise_unit: unit,
      membership_kind_id: PersonaMembershipKind::OWNER,
      membership_state_id: PersonaMembershipState::ACTIVE,
      primary: false,
      metadata: {},
    )
    persona.current_avatar_persona_binding.revoke!(force: true)
    result = AvatarProvisioning::Create.call(
      actor: @user,
      subject_type: :persona,
      subject: persona,
      avatar_params: { moniker: "Second Avatar" },
      handle_params: { handle: "second-#{SecureRandom.hex(5)}" },
      organization_public_id: enterprise.public_id,
    )

    assert_predicate result, :success?

    result = BaseSelectorAuthority.prepare(surface: :app, principal: @user, session: @token)

    assert_equal "selection_required", result[:status]
    assert_equal 2, result[:accounts].size
  end

  test "rejects another identity selection" do
    other = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: other)
    other_candidate = BaseSelectorAuthority.new(
      surface: :app, principal: other,
      session: ClientToken.create!(user: other),
    )
      .selectable_candidates
      .first

    assert_raises BaseSelectorAuthority::InvalidSelection do
      BaseSelectorAuthority.select(
        surface: :app,
        principal: @user,
        session: @token,
        params: other_candidate[:public],
      )
    end
  end

  test "rejects inconsistent account organization avatar combination" do
    candidate = BaseSelectorAuthority.new(
      surface: :app, principal: @user,
      session: @token,
    ).selectable_candidates.first
    enterprise = Enterprise.create!(name: "Foreign Combination", title: "Foreign1")
    unit = EnterpriseUnit.create!(enterprise: enterprise, name: "Default")

    params = candidate[:public].merge(
      organization_public_id: enterprise.public_id,
      organization_unit_public_id: unit.public_id,
    )

    assert_raises BaseSelectorAuthority::InvalidSelection do
      BaseSelectorAuthority.select(surface: :app, principal: @user, session: @token, params: params)
    end
  end
end
