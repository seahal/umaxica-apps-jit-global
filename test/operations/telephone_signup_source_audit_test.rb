# frozen_string_literal: true

require "test_helper"

class TelephoneSignupSourceAuditTest < ActiveSupport::TestCase
  setup do
    ClientSignUpFlowStatus::DEFAULTS.each { |id| ClientSignUpFlowStatus.find_or_create_by!(id: id) }
    VisitorSignUpFlowStatus::DEFAULTS.each { |id| VisitorSignUpFlowStatus.find_or_create_by!(id: id) }
    ClientSignUpFlowCleanupStatus::DEFAULTS.each { |id| ClientSignUpFlowCleanupStatus.find_or_create_by!(id: id) }
    VisitorSignUpFlowCleanupStatus::DEFAULTS.each { |id| VisitorSignUpFlowCleanupStatus.find_or_create_by!(id: id) }
  end

  test "telephone signup rejects invalid audit attribution and rolls back Source facts with its intent" do
    [
      [Client, ClientTelephone, :user_id, :user_telephone_status_id,
       ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP, ClientStatus::UNVERIFIED_WITH_SIGN_UP,
       SignAppUpTelephoneRegistrationFinalizer, ClientContactAuditOutbox, :app,],
      [Visitor, VisitorTelephone, :visitor_id, :visitor_telephone_status_id,
       VisitorTelephoneStatus::UNVERIFIED_WITH_SIGN_UP, VisitorStatus::ACTIVE,
       SignComUpTelephoneRegistrationFinalizer, VisitorContactAuditOutbox, :com,],
    ].each do |principal, contact_type, owner_key, status_key, contact_status, owner_status, finalizer, outbox, surface|
      owner = principal.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: owner_status)
      contact = contact_type.create!(
        owner_key => owner.id, status_key => contact_status,
        :raw_number => "+819012345679", :confirm_policy => "1", :confirm_using_mfa => "1",
      )
      flow_model = (surface == :app) ? ClientSignUpFlow : VisitorSignUpFlow
      nonce = "telephone-source-audit-browser"
      now = flow_model.database_now
      flow = flow_model.create!(
        auth_admission_binding: SignUpAdmissionTestFactory.binding_for!(flow_model),
        principal_id: owner.id, status_id: flow_model::STATUS_MODEL::CONTACT_PENDING, step: "contact",
        nonce_digest: flow_model.digest_nonce(nonce), issued_at: now, expires_at: now + 15.minutes,
        entry_method: "telephone", pending_contact_type: "telephone", pending_contact_id: contact.id,
      )
      issued = TelephoneSignUpOtpIssuer.call(flow: flow, telephone: contact, session_nonce: nonce)
      verified = TelephoneSignUpOtpVerificationCommitter.call(
        flow: flow, telephone: contact, session_nonce: nonce, code: issued.code,
      )

      assert_predicate verified, :success?
      flow.verify_sign_up_contact!
      flow.advance_sign_up_to_guardrail!
      flow.advance_sign_up_to_checkpoint!
      flow.update!(completed_requirements: { "otp" => { "cleared" => true } })
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
      [Visitor, VisitorTelephone, :visitor_id, SignComUpTelephoneRegistrationFinalizer,
       VisitorContactAuditOutbox, :com,],
    ].each do |principal, contact_type, owner_key, finalizer, outbox, surface|
      owner_status = (surface == :app) ? ClientStatus::UNVERIFIED_WITH_SIGN_UP : VisitorStatus::ACTIVE
      owner = principal.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: owner_status)
      contact = contact_type.create!(
        owner_key => owner.id,
        :raw_number => "+819012345674", :confirm_policy => "1", :confirm_using_mfa => "1",
      )
      flow_model = (surface == :app) ? ClientSignUpFlow : VisitorSignUpFlow
      nonce = "suspended-telephone-source-browser"
      now = flow_model.database_now
      flow = flow_model.create!(
        auth_admission_binding: SignUpAdmissionTestFactory.binding_for!(flow_model),
        principal_id: owner.id, status_id: flow_model::STATUS_MODEL::CONTACT_PENDING, step: "contact",
        nonce_digest: flow_model.digest_nonce(nonce), issued_at: now, expires_at: now + 15.minutes,
        entry_method: "telephone", pending_contact_type: "telephone", pending_contact_id: contact.id,
      )
      issued = TelephoneSignUpOtpIssuer.call(flow: flow, telephone: contact, session_nonce: nonce)
      verified = TelephoneSignUpOtpVerificationCommitter.call(
        flow: flow, telephone: contact, session_nonce: nonce, code: issued.code,
      )

      assert_predicate verified, :success?
      flow.verify_sign_up_contact!
      flow.advance_sign_up_to_guardrail!
      flow.advance_sign_up_to_checkpoint!
      flow.update!(completed_requirements: { "otp" => { "cleared" => true } })
      owner.update!(deactivated_at: principal.database_now)
      if surface == :app
        ClientPasskey.create!(
          user: owner, webauthn_id: SecureRandom.uuid, public_key: "public-key", description: "Signup passkey",
        )
      end
      retained = contact.reload.attributes.slice("otp_attempts_count", "locked_at", "otp_last_sent_at")
      operation_ref = flow.public_id
      context = ActorValuesContext.empty.with(tld: surface, surface: :sign)

      assert_raises(ActiveRecord::RecordNotSaved) do
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

  %w(app com).each do |surface|
    %w(foreign_browser foreign_operation unconsumed_child uncleared_otp contact_pending expired_parent).each do |state|
      test "#{surface} Telephone signup finalization rejects #{state} durable authority" do
        owner, telephone, flow_model, finalizer, outbox, pending_status =
          case surface
          when "app"
            actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
            candidate = actor.client_telephones.create!(
              raw_number: "+12025550191", confirm_policy: true,
              user_telephone_status_id: ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP,
            )
            actor.client_passkeys.create!(
              webauthn_id: SecureRandom.uuid, public_key: "finalization-authority", description: "Signup passkey",
            )
            [actor, candidate, ClientSignUpFlow, SignAppUpTelephoneRegistrationFinalizer,
             ClientContactAuditOutbox, ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP,]
          when "com"
            actor = Visitor.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: VisitorStatus::ACTIVE)
            candidate = actor.visitor_telephones.create!(
              raw_number: "+12025550192", confirm_policy: true,
              visitor_telephone_status_id: VisitorTelephoneStatus::UNVERIFIED_WITH_SIGN_UP,
            )
            [actor, candidate, VisitorSignUpFlow, SignComUpTelephoneRegistrationFinalizer,
             VisitorContactAuditOutbox, VisitorTelephoneStatus::UNVERIFIED_WITH_SIGN_UP,]
          end
        nonce = "telephone-finalization-authority"
        now = flow_model.database_now
        flow = flow_model.create!(
          auth_admission_binding: SignUpAdmissionTestFactory.binding_for!(flow_model),
          principal_id: owner.id, status_id: flow_model::STATUS_MODEL::CONTACT_PENDING, step: "contact",
          nonce_digest: flow_model.digest_nonce(nonce), issued_at: now, expires_at: now + 15.minutes,
          entry_method: "telephone", pending_contact_type: "telephone", pending_contact_id: telephone.id,
        )
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
        flow.update!(completed_requirements: { "otp" => { "cleared" => true } }) unless state == "uncleared_otp"
        retained = telephone.reload.attributes.slice("otp_attempts_count", "locked_at", "otp_last_sent_at")
        arguments = {
          telephone: telephone,
          actor_context: ActorValuesContext.empty.with(tld: surface.to_sym, surface: :sign),
          operation_ref: (state == "foreign_operation") ? SecureRandom.uuid : flow.public_id,
          flow: flow,
          session_nonce: (state == "foreign_browser") ? "another-browser" : nonce,
        }
        decision_time = (state == "expired_parent") ? flow.expires_at : flow_model.database_now

        flow_model.stub(:database_now, decision_time) do
          assert_raises(ArgumentError) { finalizer.call(**arguments) }
        end

        assert_nil telephone.reload.binding_finalized_at
        actual_status =
          case telephone
          when ClientTelephone then telephone.user_telephone_status_id
          when VisitorTelephone then telephone.visitor_telephone_status_id
          end

        assert_equal pending_status, actual_status
        assert_equal retained, telephone.attributes.slice(*retained.keys)
        assert_not outbox.exists?(contact_ref: telephone.public_id)
      end
    end
  end
end
