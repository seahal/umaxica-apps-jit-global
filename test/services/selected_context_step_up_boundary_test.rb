# frozen_string_literal: true

require "test_helper"

class SelectedContextStepUpBoundaryTest < ActiveSupport::TestCase
  test "changing or clearing a real selected context revokes authority on each surface while revisiting preserves it" do
    %i(app com org).each do |surface|
      actor, token, transaction_model, ceremony_model =
        case surface
        when :app
          principal = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
          [principal, ClientToken.create!(user: principal), ClientStepUpCeremonyTransaction, ClientAuthCeremonySession]
        when :com
          principal = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
          [principal, VisitorToken.create!(visitor: principal), VisitorStepUpCeremonyTransaction,
           VisitorAuthCeremonySession,]
        when :org
          principal = Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
          [principal, OperatorToken.create!(staff: principal), OperatorStepUpCeremonyTransaction,
           OperatorAuthCeremonySession,]
        else
          raise ArgumentError, "unsupported test surface"
        end
      BaseSelectorBootstrapAuthority.call(surface: surface, principal: actor)
      candidate = BaseSelectorAuthority.new(
        surface: surface, principal: actor,
        session: token,
      ).selectable_candidates.first
      scope = "settings_birthdate"
      requirement = StepUpRequirement.new(
        scope: scope, allowed_methods: [:passkey], purpose: "step_up", audience: "step_up:#{surface}",
        session_binding: token.public_id, token_binding: token.public_id, require_session_binding: true,
      )
      pending = issue_base_step_up_admission!(
        actor: actor, token: token, requirement: requirement, return_to: "/identity/birthdate",
      ).transaction
      continuity, = ceremony_model.rotate_and_admit!(
        admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: pending.transaction_id,
      )
      token.update!(last_step_up_at: token.class.database_now, last_step_up_scope: scope)

      selected = BaseSelectorAuthority.select(
        surface: surface, principal: actor, session: token, params: candidate.fetch(:public),
      )

      assert_equal "selected", selected.fetch(:status)
      assert_equal "revoked", pending.reload.status, surface.to_s
      assert_not_nil continuity.reload.revoked_at
      assert_nil token.reload.last_step_up_at
      assert_predicate token, :currently_usable?
      assert_predicate token, :selected_actor_context?

      pending = issue_base_step_up_admission!(
        actor: actor, token: token, requirement: requirement, return_to: "/identity/birthdate",
      ).transaction
      continuity, = ceremony_model.rotate_and_admit!(
        admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: pending.transaction_id,
      )
      verified_at = token.class.database_now
      token.update!(last_step_up_at: verified_at, last_step_up_scope: scope)
      BaseSwitcherAuthority.switch(surface: surface, principal: actor, session: token, params: candidate.fetch(:public))

      assert_equal "pending", pending.reload.status, surface.to_s
      assert_nil continuity.reload.revoked_at
      assert_equal verified_at, token.reload.last_step_up_at
      assert_raises BaseSwitcherAuthority::InvalidSwitch do
        BaseSwitcherAuthority.switch(
          surface: surface, principal: actor, session: token,
          params: candidate.fetch(:public).merge(account_public_id: "unowned"),
        )
      end
      assert_equal "pending", pending.reload.status
      assert_equal verified_at, token.reload.last_step_up_at

      token.clear_selected_actor_context!

      assert_equal "revoked", transaction_model.find(pending.id).status, surface.to_s
      assert_not_nil continuity.reload.revoked_at
      assert_nil token.reload.last_step_up_at
      assert_not_predicate token, :selected_actor_context?
      assert_nil token.selected_at
      assert_predicate token, :currently_usable?
    end
  end

  test "switching COM organizations revokes verified evidence without issuing another root session" do
    actor = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
    token = VisitorToken.create!(visitor: actor)
    bootstrap = BaseSelectorBootstrapAuthority.call(surface: :com, principal: actor)
    selector = BaseSelectorAuthority.new(surface: :com, principal: actor, session: token)
    initial = selector.selectable_candidates.first.fetch(:public)
    selected = BaseSelectorAuthority.select(surface: :com, principal: actor, session: token, params: initial)

    assert_equal "selected", selected.fetch(:status)

    company = Company.create!(name: "Second authorized company", title: "Second")
    unit = CompanyUnit.create!(company: company, name: "Default")
    IndividualMembership.create!(
      individual: bootstrap.account, company: company, company_unit: unit,
      membership_kind_id: IndividualMembershipKind::OWNER,
      membership_state_id: IndividualMembershipState::ACTIVE, primary: false, metadata: {},
    )
    alternate = selector.selectable_candidates.find do |candidate|
      candidate.fetch(:public).fetch(:organization_public_id) == company.public_id
    end.fetch(:public)
    requirement = StepUpRequirement.new(
      scope: "settings_birthdate", allowed_methods: [:passkey], purpose: "step_up", audience: "step_up:com",
      session_binding: token.public_id, token_binding: token.public_id, require_session_binding: true,
    )
    proof = issue_base_step_up_admission!(
      actor: actor, token: token, requirement: requirement, return_to: "/identity/birthdate",
    ).transaction
    # This is a stored-evidence lifecycle test, not proof of a credential assertion.
    proof.record_verification!(
      method: "passkey", aal: "aal1", phishing_resistant: true,
      verified_at: VisitorStepUpCeremonyTransaction.database_now, verified_credential_ref: "lifecycle-test-credential",
    )
    continuity, = VisitorAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: proof.transaction_id,
    )
    token.update!(last_step_up_at: VisitorToken.database_now, last_step_up_scope: "settings_birthdate")
    root_count = VisitorToken.where(visitor: actor).count
    result = BaseSwitcherAuthority.switch(surface: :com, principal: actor, session: token, params: alternate)

    assert_equal "switched", result.fetch(:status)
    assert_equal company.public_id, token.reload.selected_collective_public_id
    assert_equal "revoked", proof.reload.status
    assert_not_nil continuity.reload.revoked_at
    assert_nil token.last_step_up_at
    assert_equal root_count, VisitorToken.where(visitor: actor).count
    assert_predicate token, :currently_usable?
  end
end
