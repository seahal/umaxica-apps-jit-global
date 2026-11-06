# frozen_string_literal: true

require "test_helper"

class OidcStepUpAuthorizationIssuerTest < ActiveSupport::TestCase
  fixtures :clients, :operators, :client_totp_credentials, :operator_passkeys

  test "ADVANCED with only TOTP configured fails the requested class without issuing an Auth ticket" do
    actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: ClientStatus::ACTIVE,
    )
    ClientTotpCredential.create_for_user!(
      user: actor, private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    client = OidcClientRegistry.find!("core-app-jp")
    now = OpBaseAppRecord.database_now
    grant = OpAppGrant.create!(
      authentication_epoch: token.authentication_epoch, client_token: token, oidc_client_id: client.client_id,
      oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: now - 1.hour, refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(expires_at: now + 1.hour, now:)
    redirect_uri = client.redirect_uris_by_realm.fetch("client").first
    params = {
      response_type: "code",
      client_id: client.client_id,
      redirect_uri:,
      scope: grant.oidc_scope,
      state: SecureRandom.urlsafe_base64(32),
      nonce: SecureRandom.urlsafe_base64(32),
      code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest("step-up-unsatisfiable"), padding: false),
      code_challenge_method: "S256",
      prompt: "login",
      claims: OidcAuthorizeRequestResolver::STEP_UP_CLAIMS,
    }
    validated_request = OidcAuthorizeRequestResolver.call(params:, resource: actor, resource_type: "client")

    issuance = OidcStepUpAuthorizationIssuer.call!(
      surface: "app", actor:, token:, client:, params:, validated_request:,
    )

    assert_equal :unsatisfiable, issuance.outcome
    assert_nil issuance.ticket
    assert_nil issuance.entry_ref
    assert_equal ClientStepUpContextState::FAILED, issuance.context.reload.state_id
    transition = ClientStepUpContextTransition.find_by!(owner_id: issuance.context.id)

    assert_equal "unsatisfiable_class", transition.reason_code
    outbox = ClientStepUpAuditOutbox.find_by!(context_ref: issuance.context.public_id)

    assert_equal "step_up.failed", outbox.event_type
    assert_equal "unsatisfiable_class", outbox.payload.fetch("failure_code")
    assert_predicate issuance.authorization_transaction.reload, :pending?
  end

  test "APP and ORG issuance bind the existing live grant without establishing a root login" do
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
        context_state_class: ClientStepUpContextState,
        context_pending_state: ClientStepUpContextState::PENDING,
        ticket_class: ClientStepUpCeremonyTransaction,
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
        context_state_class: OperatorStepUpContextState,
        context_pending_state: OperatorStepUpContextState::PENDING,
        ticket_class: OperatorStepUpCeremonyTransaction,
        realm: "operator",
      },
    ].each do |configuration|
      surface = configuration.fetch(:surface)
      resource_type = configuration.fetch(:resource_type)
      actor = configuration.fetch(:actor)
      token_class = configuration.fetch(:token_class)
      token_owner = configuration.fetch(:token_owner)
      client = OidcClientRegistry.find!(configuration.fetch(:client_id))
      grant_class = configuration.fetch(:grant_class)
      grant_owner = configuration.fetch(:grant_owner)
      owner = OidcAuthorizationTransactionCoordinator.model_for(surface).connection_owner
      now = owner.database_now
      token = token_class.create!(:authentication_epoch => 0, token_owner => actor)
      grant = grant_class.create!(
        :authentication_epoch => token.authentication_epoch,
        grant_owner => token,
        :oidc_client_id => client.client_id,
        :oidc_scope => "openid profile",
        :oidc_jti => SecureRandom.uuid,
        :oidc_nonce => SecureRandom.hex(16),
        :oidc_auth_time => now - 1.hour,
        :refresh_token_expires_at => now + 1.hour,
      )
      grant.issue_refresh_token!(expires_at: now + 1.hour, now:)
      redirect_uri = client.redirect_uris_by_realm.fetch(configuration.fetch(:realm)).first
      verifier = SecureRandom.urlsafe_base64(32)
      code_challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false)
      params = {
        response_type: "code",
        client_id: client.client_id,
        redirect_uri:,
        scope: grant.oidc_scope,
        state: SecureRandom.urlsafe_base64(32),
        nonce: SecureRandom.urlsafe_base64(32),
        code_challenge:,
        code_challenge_method: "S256",
        prompt: "login",
        claims: OidcAuthorizeRequestResolver::STEP_UP_CLAIMS,
      }
      validated_request = OidcAuthorizeRequestResolver.call(params:, resource: actor, resource_type:)
      root_snapshot = token.attributes.slice(
        "refresh_token_digest", "refresh_token_generation", "root_login_established_at", "authentication_event_at",
      )
      grant_snapshot = grant.attributes.slice(
        "refresh_token_digest", "refresh_generation", "oidc_auth_time", "oidc_acr", "oidc_amr",
      )
      root_count = token_class.where(token_owner => actor).count

      issuance = OidcStepUpAuthorizationIssuer.call!(
        surface:, actor:, token:, client:, params:, validated_request:,
      )

      context = issuance.context.reload
      transaction = issuance.authorization_transaction.reload
      ticket = issuance.ticket.reload
      admission = BaseAuthAdmissionCoordinator.find_admission_binding!(
        surface:, reference: issuance.entry_ref,
      )

      assert_equal :issued, issuance.outcome
      assert_equal 21, context.public_id.length
      assert_equal configuration.fetch(:context_pending_state), context.state_id
      assert_equal grant.id, context.grant_id
      assert_equal OidcSubject.for(actor, resource_type:), context.bound_subject
      assert_equal OidcAuthorizeRequestResolver::STEP_UP_ACR, context.requested_acr
      assert_equal transaction.id, context.oidc_authorization_transaction_id
      assert_equal "step_up", transaction.intent
      assert_predicate transaction, :pending?
      assert_nil transaction.actor_ref
      assert_equal "step_up", ticket.purpose
      assert_equal OidcAuthorizeRequestResolver::STEP_UP_SCOPE, ticket.required_scope
      assert_equal context.public_id, ticket.resource_ref
      assert_equal actor.public_id, ticket.actor_ref
      assert_equal token.public_id, ticket.session_ref
      assert_equal "step_up_handoff", admission.purpose
      assert_equal ticket.id, admission.step_up_ceremony_transaction_id
      assert_equal root_snapshot, token.reload.attributes.slice(*root_snapshot.keys)
      assert_equal grant_snapshot, grant.reload.attributes.slice(*grant_snapshot.keys)
      assert_equal root_count, token_class.where(token_owner => actor).count
      assert_nil token.reload.root_login_established_at
      assert_nil token.reload.last_step_up_at
    end
  end
end
