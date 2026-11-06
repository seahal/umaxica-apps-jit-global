# frozen_string_literal: true

require "test_helper"

class TelephoneCredentialRegistrationOtpFinalizerTest < ActiveSupport::TestCase
  self.fixture_table_names = []
  self.use_transactional_tests = false

  setup do
    @created_client_ids = []
    @created_op_grant_ids = []
  end

  teardown do
    client_ids = Array(@created_client_ids)
    client_refs = Client.where(id: client_ids).pluck(:public_id)
    ClientContactAuditOutbox.where(owner_ref: client_refs).delete_all
    ClientTelephoneCeremonyTransaction.where(actor_ref: client_refs).delete_all
    ClientTelephone.where(user_id: client_ids).delete_all
    ClientPasskey.where(user_id: client_ids).delete_all
    OpAppGrant.where(id: @created_op_grant_ids).delete_all
    ClientPreference.where(client_id: client_ids).destroy_all
    ClientDeviceSession.where(user_id: client_ids).update_all(current_refresh_token_id: nil)
    ClientToken.where(user_id: client_ids).delete_all
    ClientDeviceSession.where(user_id: client_ids).delete_all
    ClientAuthorityLock.where(client_id: client_ids).delete_all
    ClientChronicle.where(subject_type: "Client", subject_id: client_ids.map(&:to_s)).delete_all
    ClientAccount.where(user_id: client_ids).delete_all
    Client.where(id: client_ids).delete_all
  end

  %w(app).each do |surface|
    %w(current foreign_browser lost_freshness credential_lost source_fault receipt_fault).each do |scenario|
      test "#{surface} Telephone finalization #{scenario} keeps Ticket before Source" do
        actor, token, telephone, policy, audit =
          case surface
          when "app"
            owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
            @created_client_ids << owner.id
            root = ClientToken.create!(authentication_epoch: 0, user: owner, discard_at: 1.day.from_now)
            candidate = owner.client_telephones.create!(raw_number: "+12025550181", confirm_policy: true)
            [owner, root, candidate, ClientTelephonePolicy, ClientContactAuditOutbox]
          end
        token.rotate_refresh_token!
        passkey = actor.client_passkeys.create!(
          webauthn_id: SecureRandom.uuid, public_key: "telephone-finalization-key", uv_verified_at: Time.current,
        )
        @step_up_grant, step_up_evidence = grant_telephone_step_up!(actor, token)
        root_step_up_state = token.attributes.slice(*token.attributes.keys.grep(/last_step_up_/))
        nonce = SecureRandom.urlsafe_base64(32)
        issued = TelephoneCredentialRegistrationOtpIssuer.call(
          actor: actor, token: token, telephone: telephone, browser_nonce: nonce,
        )
        verified = TelephoneCredentialRegistrationOtpVerificationCommitter.call(
          actor: actor, token: token, telephone: telephone, transaction: issued.transaction,
          browser_nonce: nonce, code: issued.code,
        )

        assert_predicate verified, :success?
        requirement = policy.new(telephone, user: actor).credential_registration_requirement(token: token)
        context = ActorValuesContext.empty.with(
          subject: actor, actor_type: :client, tld: surface.to_sym, surface: :base,
        )
        arguments = {
          actor: actor,
          actor_context: context,
          token: token,
          telephone: telephone,
          transaction: issued.transaction,
          browser_nonce: nonce,
          requirement: requirement,
          code: issued.code,
          step_up_evidence: step_up_evidence,
        }
        case scenario
        when "foreign_browser"
          arguments[:browser_nonce] = SecureRandom.urlsafe_base64(32)
        when "lost_freshness"
          auth_time = token.class.database_now.to_i - StepUpEvidenceValue::MAX_AGE_SECONDS
          @step_up_grant.update!(oidc_auth_time: Time.at(auth_time).utc)
          arguments[:step_up_evidence] = step_up_evidence.with(auth_time: auth_time)
        when "credential_lost"
          passkey.update!(discard_at: passkey.class.database_now)
        end
        if scenario == "source_fault"
          ContactBindingAuditRecorder.stub(:call!, ->(**) { raise ActiveRecord::StatementInvalid }) do
            assert_raises(TelephoneCredentialRegistrationOtpFinalizer::DependencyFailure) do
              TelephoneCredentialRegistrationOtpFinalizer.call!(**arguments)
            end
          end

          assert_not telephone.reload.binding_effective?
          assert_not audit.exists?(operation_ref: issued.transaction.transaction_id, event_name: "finalized")
          assert_predicate issued.transaction.reload, :consumed?
          assert_equal root_step_up_state, token.reload.attributes.slice(*root_step_up_state.keys)
          assert_equal :unavailable, TelephoneCredentialRegistrationOtpFinalizer.call!(**arguments)
          assert_not_predicate telephone.reload, :binding_effective?
          assert_equal root_step_up_state, token.reload.attributes.slice(*root_step_up_state.keys)
        elsif scenario == "receipt_fault"
          original_root_step_up_state = token.reload.attributes.slice(*root_step_up_state.keys)
          original_telephone = telephone.reload.attributes
          original_ticket = issued.transaction.reload.attributes

          issued.transaction.stub(:consume_registration_result!, -> { raise ActiveRecord::StatementInvalid }) do
            assert_raises(TelephoneCredentialRegistrationOtpFinalizer::DependencyFailure) do
              TelephoneCredentialRegistrationOtpFinalizer.call!(**arguments)
            end
          end

          assert_not_predicate telephone.reload, :binding_effective?
          assert_not audit.exists?(operation_ref: issued.transaction.transaction_id, event_name: "finalized")
          assert_nil issued.transaction.reload.consumed_at
          assert_equal original_root_step_up_state, token.reload.attributes.slice(*root_step_up_state.keys)
          assert_equal original_telephone, telephone.reload.attributes
          assert_equal original_ticket, issued.transaction.reload.attributes
          assert_equal :finalized, TelephoneCredentialRegistrationOtpFinalizer.call!(**arguments)
          assert_predicate issued.transaction.reload, :consumed?
          assert_predicate telephone.reload, :binding_effective?
          assert_equal original_root_step_up_state, token.reload.attributes.slice(*root_step_up_state.keys)
          assert_equal 1, audit.where(operation_ref: issued.transaction.transaction_id, event_name: "finalized").count
        else
          # The verified event remains usable after the authenticating credential is removed;
          # Section 9 intentionally removes credential-activity binding from ordinary Step-Up.
          expected = %w(current credential_lost).include?(scenario) ? :finalized : :unavailable

          assert_equal expected, TelephoneCredentialRegistrationOtpFinalizer.call!(**arguments)
          assert_equal expected == :finalized, telephone.reload.binding_effective?
          assert_equal expected == :finalized, issued.transaction.reload.consumed?
          assert_equal expected == :finalized, audit.exists?(
            operation_ref: issued.transaction.transaction_id, event_name: "finalized",
          )
          assert_equal root_step_up_state, token.reload.attributes.slice(*root_step_up_state.keys)
        end
      end
    end
  end

  private

  def grant_telephone_step_up!(actor, token)
    now = OpBaseAppRecord.database_now
    token.update!(root_login_established_at: now, established_authentication_method: "passkey")
    token.rotate_refresh_token!(now:)
    token.device_session_record!
    client = OidcClientRegistry.find!("base-app-ww")
    auth_time = now.to_i
    grant = OpAppGrant.create!(
      authentication_epoch: token.authentication_epoch,
      client_token: token,
      oidc_client_id: client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(auth_time).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(now:)
    @created_op_grant_ids << grant.id
    evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr,
      amr: ["passkey"],
      auth_time:,
      sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "client"),
      client_id: client.client_id,
      aud: [client.aud],
      jti: grant.oidc_jti,
    )
    [grant, evidence]
  end
end
