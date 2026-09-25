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
      owner_surface: "app",
      owner_collective_public_id: enterprise.public_id,
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

  test "org selector keeps Avatar optional and can select a Bureau owned Avatar" do
    operator = Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
    token = OperatorToken.create!(staff: operator)
    bootstrap = BaseSelectorBootstrapAuthority.call(surface: :org, principal: operator)
    selector = BaseSelectorAuthority.new(surface: :org, principal: operator, session: token)

    initial_candidates = selector.selectable_candidates

    assert_equal 1, initial_candidates.size
    assert_nil initial_candidates.first.fetch(:avatar)

    created = AvatarProvisioning::Create.call(
      actor: operator,
      subject_type: :agent,
      subject: bootstrap.account,
      avatar_params: { moniker: "Org Avatar" },
      handle_params: { handle: "org-#{SecureRandom.hex(5)}" },
      owner_surface: "org",
      owner_collective_public_id: bootstrap.collective.public_id,
    )

    assert_predicate created, :success?

    avatar_candidate = selector.selectable_candidates.find { |candidate| candidate.dig(:public, :avatar_public_id) }

    assert_equal created.avatar.public_id, avatar_candidate.dig(:public, :avatar_public_id)
    result = BaseSelectorAuthority.select(
      surface: :org,
      principal: operator,
      session: token,
      params: avatar_candidate.fetch(:public),
    )

    assert_equal "selected", result.fetch(:status)
    assert_equal created.avatar.public_id, token.reload.selected_avatar_public_id
  end
end
