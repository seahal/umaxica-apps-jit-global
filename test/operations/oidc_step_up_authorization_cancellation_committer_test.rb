# frozen_string_literal: true

require "test_helper"

class OidcStepUpAuthorizationCancellationCommitterTest < ActiveSupport::TestCase
  fixtures :clients, :operators, :client_totp_credentials, :operator_passkeys

  test "APP and ORG cancellation end the Auth ticket and OP context without changing the root login" do
    [
      {
        surface: "app",
        resource_type: "client",
        actor: clients(:one),
        token_class: ClientToken,
        token_owner: :user,
        client_id: "core-app-jp",
        grant_class: OpAppGrant,
        grant_owner: :client_token,
        context_class: ClientStepUpContext,
        context_cancelled_state: ClientStepUpContextState::CANCELLED,
        commit_class: ClientStepUpCommit,
        outbox_class: ClientStepUpAuditOutbox,
        realm: "client",
      },
      {
        surface: "org",
        resource_type: "operator",
        actor: operators(:one),
        token_class: OperatorToken,
        token_owner: :staff,
        client_id: "core-org-jp",
        grant_class: OpOrgGrant,
        grant_owner: :operator_token,
        context_class: OperatorStepUpContext,
        context_cancelled_state: OperatorStepUpContextState::CANCELLED,
        commit_class: OperatorStepUpCommit,
        outbox_class: OperatorStepUpAuditOutbox,
        realm: "operator",
      },
    ].each do |configuration|
      surface = configuration.fetch(:surface)
      actor = configuration.fetch(:actor)
      resource_type = configuration.fetch(:resource_type)
      client = OidcClientRegistry.find!(configuration.fetch(:client_id))
      owner = OidcAuthorizationTransactionCoordinator.model_for(surface).connection_owner
      now = owner.database_now
      token_attributes = { authentication_epoch: 0 }
      token_attributes[configuration.fetch(:token_owner)] = actor
      token = configuration.fetch(:token_class).create!(token_attributes)
      grant_attributes = {
        authentication_epoch: token.authentication_epoch,
        oidc_client_id: client.client_id,
        oidc_scope: "openid profile",
        oidc_jti: SecureRandom.uuid,
        oidc_nonce: SecureRandom.hex(16),
        oidc_auth_time: now - 1.hour,
        refresh_token_expires_at: now + 1.hour,
      }
      grant_attributes[configuration.fetch(:grant_owner)] = token
      grant = configuration.fetch(:grant_class).create!(
        grant_attributes,
      )
      grant.issue_refresh_token!(expires_at: now + 1.hour, now:)
      redirect_uri = client.redirect_uris_by_realm.fetch(configuration.fetch(:realm)).first
      verifier = SecureRandom.urlsafe_base64(32)
      params = {
        response_type: "code",
        client_id: client.client_id,
        redirect_uri:,
        scope: grant.oidc_scope,
        state: SecureRandom.urlsafe_base64(32),
        nonce: SecureRandom.urlsafe_base64(32),
        code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false),
        code_challenge_method: "S256",
        prompt: "login",
        claims: OidcAuthorizeRequestResolver::STEP_UP_CLAIMS,
      }
      validated_request = OidcAuthorizeRequestResolver.call(params:, resource: actor, resource_type:)
      issuance = OidcStepUpAuthorizationIssuer.call!(
        surface:, actor:, token:, client:, params:, validated_request:,
      )
      context = issuance.context
      authorization = issuance.authorization_transaction
      ticket = issuance.ticket
      binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface:, reference: issuance.entry_ref)
      ceremony_model = BaseAuthAdmissionCoordinator.ceremony_session_class(surface)
      attached_ceremony, raw_sid = ceremony_model.issue!
      binding.attach_auth_session!(auth_session: attached_ceremony, confirmation_ref: SecureRandom.uuid)
      binding.confirm_base!(
        base_token: token,
        browser_digest: AuthAdmissionBinding.browser_digest(
          surface:, entry_ref: issuance.entry_ref, nonce: authorization.login_challenge,
        ),
      )
      admitted_ceremony, = ceremony_model.rotate_and_admit!(
        admission_purpose: "step_up_handoff",
        previous_raw_sid: raw_sid,
        step_up_ceremony_transaction_ref: ticket.transaction_id,
      )
      binding.redeem!(auth_session: attached_ceremony, admitted_auth_session: admitted_ceremony)
      cancellation = BaseAuthAdmissionCoordinator.issue_cancellation!(
        transaction: ticket, ceremony_session_ref: admitted_ceremony.id.to_s,
      )
      BaseAuthAdmissionCoordinator.read_cancellation_handoff!(
        handoff: cancellation.handoff, surface:, transaction_ref: ticket.transaction_id,
      )
      token_before = token.attributes.slice(
        "refresh_token_digest", "refresh_token_generation", "root_login_established_at", "last_step_up_at",
      )
      device_before = token.device_session_record!.attributes.slice("current_refresh_token_id", "revoked_at")
      grant_before = grant.attributes.slice("refresh_token_digest", "refresh_generation", "oidc_auth_time")

      outcome = OidcStepUpAuthorizationCancellationCommitter.call!(
        surface:, actor:, token:, context:, ticket:, authorization_transaction: authorization,
        admission_binding: binding, cancellation_handoff: cancellation.handoff,
      )

      assert_equal :cancelled, outcome
      assert_equal configuration.fetch(:context_cancelled_state), context.reload.state_id
      assert_predicate ticket.reload, :canceled?
      assert_equal AuthCeremonySession::STATUS_CANCELLED_BEFORE_PROGRESS, admitted_ceremony.reload.status_id
      assert_predicate binding.reload, :redeemed?
      assert_predicate authorization.reload, :pending?
      assert_equal token_before, token.reload.attributes.slice(*token_before.keys)
      assert_equal device_before, token.device_session_record!.attributes.slice(*device_before.keys)
      assert_equal grant_before, grant.reload.attributes.slice(*grant_before.keys)
      assert_empty configuration.fetch(:commit_class).where(context_ref: context.public_id)
      outbox = configuration.fetch(:outbox_class).find_by!(context_ref: context.public_id)

      assert_equal "step_up.cancelled", outbox.event_type
      assert_equal "user_cancelled", outbox.reason_code
      assert_equal({ "op_context_ref" => context.public_id }, outbox.payload)
    end
  end
end
