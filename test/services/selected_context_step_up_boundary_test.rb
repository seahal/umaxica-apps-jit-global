# frozen_string_literal: true

require "test_helper"

class SelectedContextStepUpBoundaryTest < ActiveSupport::TestCase
  test "changing or clearing a real selected context revokes authority on each surface while revisiting preserves it" do
    %i(app org).each do |surface|
      actor, token, transaction_model, ceremony_model =
        case surface
        when :app
          principal = Client.create!(
            security_mode_id: SecurityModeConfigurable::NORMAL,
            status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER,
          )
          [principal, ClientToken.create!(authentication_epoch: 0, user: principal), ClientStepUpCeremonyTransaction,
           ClientAuthCeremonySession,]
        when :org
          principal = Operator.create!(
            security_mode_id: SecurityModeConfigurable::ADVANCED,
            status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF,
          )
          [
            principal,
            OperatorToken.create!(authentication_epoch: 0, staff: principal),
            OperatorStepUpCeremonyTransaction,
            OperatorAuthCeremonySession,
          ]
        else
          raise ArgumentError, "unsupported test surface"
        end
      BaseSelectorBootstrapAuthority.call(surface: surface, principal: actor)
      candidate = BaseSelectorAuthority.new(
        surface: surface, principal: actor,
        session: token,
      ).selectable_candidates.first
      scope = "settings_birthdate"
      # D-70: a requirement states every mandatory property explicitly; nothing is defaulted.
      requirement = StepUpRequirement.new(
        step_up_required: true, scope: scope, allowed_methods: [:passkey],
        phishing_resistant_required: true, user_verification_required: true,
        full_reauthentication_required: false, ttl: 15.minutes,
        purpose: "step_up", audience: "step_up:#{surface}",
        session_binding: token.public_id, token_binding: token.public_id, require_session_binding: true,
        actor_ref: actor.public_id, resource_ref: nil, tenant_ref: nil,
      )
      pending = BaseStepUpAdmissionIssuer.call!(
        actor: actor,
        token: token,
        requirement: requirement,
        return_to: "/identity/birthdate",
        base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
        base_token: token,
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

      pending = BaseStepUpAdmissionIssuer.call!(
        actor: actor,
        token: token,
        requirement: requirement,
        return_to: "/identity/birthdate",
        base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
        base_token: token,
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
end
