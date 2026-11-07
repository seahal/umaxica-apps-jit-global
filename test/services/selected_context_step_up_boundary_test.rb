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
      case [actor, token]
      in [Client, ClientToken]
        actor.client_passkeys.create!(webauthn_id: SecureRandom.uuid, public_key: "public", sign_count: 0)
        resource_type = "client"
        client = OidcClientRegistry.find!("core-app-jp")
        grant_model = OpAppGrant
        grant_owner = :client_token
      in [Operator, OperatorToken]
        actor.staff_passkeys.create!(webauthn_id: SecureRandom.uuid, public_key: "public", sign_count: 0)
        resource_type = "operator"
        client = OidcClientRegistry.find!("core-org-jp")
        grant_model = OpOrgGrant
        grant_owner = :operator_token
      end
      now = grant_model.database_now
      grant = grant_model.create!(
        :authentication_epoch => token.authentication_epoch, grant_owner => token, :oidc_client_id => client.client_id,
        :oidc_scope => "openid profile", :oidc_jti => SecureRandom.uuid, :oidc_nonce => SecureRandom.hex(16),
        :oidc_auth_time => now - 1.hour, :refresh_token_expires_at => now + 1.hour,
      )
      grant.issue_refresh_token!(expires_at: now + 1.hour, now:)
      realm = (surface == :app) ? "client" : "operator"
      params = {
        response_type: "code",
        client_id: client.client_id,
        redirect_uri: client.redirect_uris_by_realm.fetch(realm).first,
        scope: grant.oidc_scope,
        state: SecureRandom.urlsafe_base64(32),
        nonce: SecureRandom.urlsafe_base64(32),
        code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest("selected-context-step-up"), padding: false),
        code_challenge_method: "S256",
        prompt: "login",
        claims: OidcAuthorizeRequestResolver::STEP_UP_CLAIMS,
      }
      validated_request = OidcAuthorizeRequestResolver.call(params:, resource: actor, resource_type:)
      issuance = OidcStepUpAuthorizationIssuer.call!(
        surface: surface.to_s, actor:, token:, client:, params:, validated_request:,
      )
      pending = issuance.ticket
      continuity, = ceremony_model.rotate_and_admit!(
        admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: pending.transaction_id,
      )

      selected = BaseSelectorAuthority.select(
        surface: surface, principal: actor, session: token, params: candidate.fetch(:public),
      )

      assert_equal "selected", selected.fetch(:status)
      assert_equal "revoked", pending.reload.status, surface.to_s
      assert_not_nil continuity.reload.revoked_at
      assert_predicate token, :currently_usable?
      assert_predicate token, :selected_actor_context?

      second_params = params.merge(
        state: SecureRandom.urlsafe_base64(32), nonce: SecureRandom.urlsafe_base64(32),
        code_challenge: Base64.urlsafe_encode64(
          Digest::SHA256.digest("selected-context-step-up-again"), padding: false,
        ),
      )
      second_validated_request = OidcAuthorizeRequestResolver.call(
        params: second_params, resource: actor, resource_type:,
      )
      issuance = OidcStepUpAuthorizationIssuer.call!(
        surface: surface.to_s, actor:, token:, client:, params: second_params,
        validated_request: second_validated_request,
      )
      pending = issuance.ticket
      continuity, = ceremony_model.rotate_and_admit!(
        admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: pending.transaction_id,
      )
      BaseSwitcherAuthority.switch(surface: surface, principal: actor, session: token, params: candidate.fetch(:public))

      assert_equal "pending", pending.reload.status, surface.to_s
      assert_nil continuity.reload.revoked_at
      assert_raises BaseSwitcherAuthority::InvalidSwitch do
        BaseSwitcherAuthority.switch(
          surface: surface, principal: actor, session: token,
          params: candidate.fetch(:public).merge(account_public_id: "unowned"),
        )
      end
      assert_equal "pending", pending.reload.status

      token.clear_selected_actor_context!

      assert_equal "revoked", transaction_model.find(pending.id).status, surface.to_s
      assert_not_nil continuity.reload.revoked_at
      assert_not_predicate token, :selected_actor_context?
      assert_nil token.selected_at
      assert_predicate token, :currently_usable?
    end
  end
end
