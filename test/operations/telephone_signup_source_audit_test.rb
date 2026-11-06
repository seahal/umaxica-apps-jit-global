# frozen_string_literal: true

require "test_helper"

class TelephoneSignupSourceAuditTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    ClientSignUpFlowStatus::DEFAULTS.each { |id| ClientSignUpFlowStatus.find_or_create_by!(id: id) }
    ClientSignUpFlowCleanupStatus::DEFAULTS.each { |id| ClientSignUpFlowCleanupStatus.find_or_create_by!(id: id) }
    @source_audit_client_ids = []
    @source_audit_flow_ids = []
  end

  teardown do
    unless @source_audit_client_ids.nil?
      clients = Client.where(id: @source_audit_client_ids).to_a
      client_ids = clients.map(&:id)
      flows = ClientSignUpFlow.where(id: @source_audit_flow_ids).to_a
      bindings = ClientAuthAdmissionBinding.where(id: flows.map(&:auth_admission_binding_id)).to_a
      session_ids = bindings.flat_map do |binding|
        [binding.auth_ceremony_session_id, binding.admitted_auth_ceremony_session_id]
      end.compact.uniq
      parent_ids = bindings.filter_map(&:authorization_transaction_id)
      session_refs =
        flows.filter_map do |flow|
          next unless flow.nonce_digest

          Digest::SHA256.hexdigest(JSON.generate(["telephone_sign_up", flow.public_id, flow.nonce_digest]))
        end

      ClientTelephoneCeremonyTransaction.where(session_ref: session_refs).delete_all
      ClientSignUpFlow.where(id: flows.map(&:id)).delete_all
      ClientAuthAdmissionBinding.where(id: bindings.map(&:id)).delete_all
      ClientAuthCeremonySession.where(id: session_ids).delete_all
      ClientOidcAuthorizationTransaction.where(id: parent_ids).delete_all
      ClientContactAuditOutbox.where(owner_ref: clients.map(&:public_id)).delete_all
      ClientRegistrationCompletion.where(client_id: client_ids).delete_all
      ClientPasskey.where(user_id: client_ids).delete_all
      ClientTelephone.where(user_id: client_ids).delete_all
      ClientAuthorityLock.where(client_id: client_ids).delete_all
      Client.where(id: client_ids).delete_all
    end
  end

  test "telephone signup rejects invalid audit attribution and rolls back Source facts with its intent" do
    [
      [Client, ClientTelephone, :user_id, :user_telephone_status_id,
       ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP, ClientStatus::UNVERIFIED_WITH_SIGN_UP,
       SignAppUpTelephoneRegistrationFinalizer, ClientContactAuditOutbox, :app,],
    ].each do |principal, contact_type, owner_key, status_key, contact_status, owner_status, finalizer, outbox, surface|
      owner = principal.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: owner_status)
      @source_audit_client_ids << owner.id
      contact = contact_type.create!(
        owner_key => owner.id, status_key => contact_status,
        :raw_number => "+819012345679", :confirm_policy => "1", :confirm_using_mfa => "1",
      )
      flow_model = ClientSignUpFlow
      nonce = "telephone-source-audit-browser"
      now = flow_model.database_now
      flow = flow_model.create!(
        auth_admission_binding: SignUpAdmissionTestFactory.binding_for!(flow_model),
        principal_id: owner.id, status_id: flow_model::STATUS_MODEL::CONTACT_PENDING, step: "contact",
        nonce_digest: flow_model.digest_nonce(nonce), issued_at: now, expires_at: now + 15.minutes,
        entry_method: "telephone", pending_contact_type: "telephone", pending_contact_id: contact.id,
      )
      @source_audit_flow_ids << flow.id
      issued = TelephoneSignUpOtpIssuer.call(flow: flow, telephone: contact, session_nonce: nonce)
      verified = TelephoneSignUpOtpVerificationCommitter.call(
        flow: flow, telephone: contact, session_nonce: nonce, code: issued.code,
      )

      assert_predicate verified, :success?
      flow.verify_sign_up_contact!
      flow.advance_sign_up_to_guardrail!
      flow.advance_sign_up_to_checkpoint!
      flow.update!(
        completed_requirements: {
          "otp" => { "cleared" => true },
          "passkey" => { "cleared" => true },
          "birthdate" => { "cleared" => true },
        },
      )
      retained = contact.reload.attributes.slice("otp_attempts_count", "locked_at", "otp_last_sent_at")
      if surface == :app
        ClientPasskey.create!(
          user: owner, webauthn_id: SecureRandom.uuid, public_key: "public-key",
          description: "Signup passkey", sign_count: 0,
        )
      end
      context = ActorValuesContext.empty.with(tld: surface, surface: :sign)
      operation_ref = flow.public_id
      assert_raises(ArgumentError) do
        finalizer.call(
          telephone: contact, actor_context: context.with(tld: :org), operation_ref: operation_ref,
          flow: flow, session_nonce: nonce,
        )
      end
      assert_predicate flow.reload, :sign_up_checkpoint_pending?
      assert_not ClientRegistrationCompletion.exists?(client_id: owner.id)
      assert_nil contact.reload.binding_finalized_at
      assert_equal contact_status, contact[status_key]
      assert_equal owner_status, owner.reload.status_id
      assert_equal retained, contact.attributes.slice(*retained.keys)
      assert_not outbox.exists?(operation_ref: operation_ref)

      [nil, ""].each do |invalid_ref|
        assert_raises(ArgumentError) do
          finalizer.call(
            telephone: contact, actor_context: context, operation_ref: invalid_ref, flow: flow, session_nonce: nonce,
          )
        end
        assert_nil contact.reload.binding_finalized_at
        assert_equal contact_status, contact[status_key]
        assert_equal owner_status, owner.reload.status_id
        assert_equal retained, contact.attributes.slice(*retained.keys)
        assert_not outbox.exists?(contact_ref: contact.public_id)
      end

      principal.transaction do
        finalizer.call(
          telephone: contact, actor_context: context, operation_ref: operation_ref, flow: flow, session_nonce: nonce,
        )

        assert_predicate contact.reload, :binding_effective?
        assert outbox.exists?(operation_ref: operation_ref)
        raise ActiveRecord::Rollback
      end

      assert_nil contact.reload.binding_finalized_at
      assert_equal contact_status, contact[status_key]
      assert_equal owner_status, owner.reload.status_id
      assert_equal retained, contact.attributes.slice(*retained.keys)
      assert_not outbox.exists?(operation_ref: operation_ref)
    end
  end

  test "telephone signup refuses a suspended Identity under its Source owner lock" do
    [
      [Client, ClientTelephone, :user_id, SignAppUpTelephoneRegistrationFinalizer, ClientContactAuditOutbox, :app],
    ].each do |principal, contact_type, owner_key, finalizer, outbox, surface|
      owner_status = ClientStatus::UNVERIFIED_WITH_SIGN_UP
      owner = principal.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: owner_status)
      @source_audit_client_ids << owner.id
      contact = contact_type.create!(
        owner_key => owner.id,
        :raw_number => "+819012345674", :confirm_policy => "1", :confirm_using_mfa => "1",
      )
      flow_model = ClientSignUpFlow
      nonce = "suspended-telephone-source-browser"
      now = flow_model.database_now
      flow = flow_model.create!(
        auth_admission_binding: SignUpAdmissionTestFactory.binding_for!(flow_model),
        principal_id: owner.id, status_id: flow_model::STATUS_MODEL::CONTACT_PENDING, step: "contact",
        nonce_digest: flow_model.digest_nonce(nonce), issued_at: now, expires_at: now + 15.minutes,
        entry_method: "telephone", pending_contact_type: "telephone", pending_contact_id: contact.id,
      )
      @source_audit_flow_ids << flow.id
      issued = TelephoneSignUpOtpIssuer.call(flow: flow, telephone: contact, session_nonce: nonce)
      verified = TelephoneSignUpOtpVerificationCommitter.call(
        flow: flow, telephone: contact, session_nonce: nonce, code: issued.code,
      )

      assert_predicate verified, :success?
      flow.verify_sign_up_contact!
      flow.advance_sign_up_to_guardrail!
      flow.advance_sign_up_to_checkpoint!
      flow.update!(
        completed_requirements: {
          "otp" => { "cleared" => true },
          "passkey" => { "cleared" => true },
          "birthdate" => { "cleared" => true },
        },
      )
      owner.update!(deactivated_at: principal.database_now)
      if surface == :app
        ClientPasskey.create!(
          user: owner, webauthn_id: SecureRandom.uuid, public_key: "public-key", description: "Signup passkey",
        )
      end
      retained = contact.reload.attributes.slice("otp_attempts_count", "locked_at", "otp_last_sent_at")
      operation_ref = flow.public_id
      context = ActorValuesContext.empty.with(tld: surface, surface: :sign)

      assert_raises(FlowInvalidTransition) do
        finalizer.call(
          telephone: contact, actor_context: context, operation_ref: operation_ref, flow: flow, session_nonce: nonce,
        )
      end
      assert_not contact.reload.binding_effective?
      assert_equal retained, contact.attributes.slice(*retained.keys)
      assert_not outbox.exists?(operation_ref: operation_ref)
      assert_predicate owner.reload, :suspended?
    end
  end

  %w(app).each do |surface|
    %w(foreign_browser foreign_operation unconsumed_child uncleared_otp contact_pending expired_parent).each do |state|
      test "#{surface} Telephone signup finalization rejects #{state} durable authority" do
        actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
        @source_audit_client_ids << actor.id
        candidate = actor.client_telephones.create!(
          raw_number: "+12025550191", confirm_policy: true,
          user_telephone_status_id: ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP,
        )
        actor.client_passkeys.create!(
          webauthn_id: SecureRandom.uuid, public_key: "finalization-authority", description: "Signup passkey",
        )
        owner, telephone, flow_model, finalizer, outbox, pending_status =
          [actor, candidate, ClientSignUpFlow, SignAppUpTelephoneRegistrationFinalizer,
           ClientContactAuditOutbox, ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP,]
        nonce = "telephone-finalization-authority"
        now = flow_model.database_now
        flow = flow_model.create!(
          auth_admission_binding: SignUpAdmissionTestFactory.binding_for!(flow_model),
          principal_id: owner.id, status_id: flow_model::STATUS_MODEL::CONTACT_PENDING, step: "contact",
          nonce_digest: flow_model.digest_nonce(nonce), issued_at: now, expires_at: now + 15.minutes,
          entry_method: "telephone", pending_contact_type: "telephone", pending_contact_id: telephone.id,
        )
        @source_audit_flow_ids << flow.id
        issued = TelephoneSignUpOtpIssuer.call(flow: flow, telephone: telephone, session_nonce: nonce)
        unless state == "unconsumed_child"
          verified = TelephoneSignUpOtpVerificationCommitter.call(
            flow: flow, telephone: telephone, session_nonce: nonce, code: issued.code,
          )

          assert_predicate verified, :success?
        end
        unless state == "contact_pending"
          flow.verify_sign_up_contact!
          flow.advance_sign_up_to_guardrail!
          flow.advance_sign_up_to_checkpoint!
        end
        requirements = {
          "passkey" => { "cleared" => true },
          "birthdate" => { "cleared" => true },
        }
        requirements["otp"] = { "cleared" => true } unless state == "uncleared_otp"
        flow.update!(completed_requirements: requirements)
        retained = telephone.reload.attributes.slice("otp_attempts_count", "locked_at", "otp_last_sent_at")
        arguments = {
          telephone: telephone,
          actor_context: ActorValuesContext.empty.with(tld: surface.to_sym, surface: :sign),
          operation_ref: (state == "foreign_operation") ? SecureRandom.uuid : flow.public_id,
          flow: flow,
          session_nonce: (state == "foreign_browser") ? "another-browser" : nonce,
        }
        decision_time = (state == "expired_parent") ? flow.expires_at : flow_model.database_now

        expected_error =
          if %w(contact_pending expired_parent uncleared_otp).include?(state)
            FlowInvalidTransition
          else
            ArgumentError
          end

        flow_model.stub(:database_now, decision_time) do
          assert_raises(expected_error) { finalizer.call(**arguments) }
        end

        assert_nil telephone.reload.binding_finalized_at
        actual_status = telephone.user_telephone_status_id

        assert_equal pending_status, actual_status
        assert_equal retained, telephone.attributes.slice(*retained.keys)
        assert_not outbox.exists?(contact_ref: telephone.public_id)
      end
    end
  end
end
