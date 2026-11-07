# frozen_string_literal: true

# Sign-up journeys run with `use_transactional_tests = false`: the OTP delivery issuers refuse to
# deliver while a fixture transaction is open, so the transactional fixture wrapper turns every
# delivery into a 503. Nothing then rolls the journey's writes back, so each file records what
# existed before a case and removes what the case added afterwards, in foreign-key-safe order.
# Rows left behind referencing a synthetic client abort the foreign-key re-validation that the
# next fixture load performs inside the same worker.
module SignUpJourneyCleanup
  # Capture before the file's own setup issues its admission entry, so the entry rows are removed
  # with the case's rows instead of accumulating.
  def sign_up_journey_watermarks!
    @sign_up_journey_client_ids = Client.pluck(:id)
    @sign_up_journey_signup_ids = ClientSignUpFlow.pluck(:id)
    @sign_up_journey_binding_ids = ClientAuthAdmissionBinding.pluck(:id)
    @sign_up_journey_ceremony_ids = ClientAuthCeremonySession.pluck(:id)
    @sign_up_journey_parent_ids = ClientOidcAuthorizationTransaction.pluck(:id)
    @sign_up_journey_resolution_ids = ClientSessionLimitResolutionTransaction.pluck(:id)
    @sign_up_journey_chronicle_ids = Chronicle.pluck(:id)
    @sign_up_journey_client_chronicle_ids = ClientChronicle.pluck(:id)
  end

  def delete_sign_up_journey_rows!
    # A setup that failed before the watermarks were captured has no journey to clean; deleting
    # against a missing watermark would match every row instead of the case's own.
    return if @sign_up_journey_client_ids.nil?

    owners = Client.where.not(id: @sign_up_journey_client_ids).to_a
    owner_ids = owners.map(&:id)

    delete_sign_up_journey_flow_rows!(owner_ids)
    delete_sign_up_journey_owner_rows!(owners, owner_ids)
    owners.each { |owner| delete_sign_up_journey_collective_graph!(owner) }
    delete_sign_up_journey_chronicle_rows!
  end

  private

  # The flow side of the journey: ceremony transactions, the flows themselves, the admission
  # rows that pin them, and the tokens issued on the resulting session.
  def delete_sign_up_journey_flow_rows!(owner_ids)
    delete_sign_up_journey_signup_flows!
    # A session-limit resolution references both its flow and the OIDC parent with ON DELETE
    # RESTRICT, so it goes before either of them.
    ClientSessionLimitResolutionTransaction.where.not(id: @sign_up_journey_resolution_ids).delete_all
    ClientOidcAuthorizationTransaction.where.not(id: @sign_up_journey_parent_ids).delete_all
    delete_client_sign_in_flows!(ClientSignInFlow.where(principal_id: owner_ids))
    delete_sign_up_journey_tokens!(owner_ids)
  end

  def delete_sign_up_journey_signup_flows!
    flows = ClientSignUpFlow.where.not(id: @sign_up_journey_signup_ids).to_a
    ClientEmailCeremonyTransaction
      .where(session_ref: flows.filter_map { |flow| sign_up_session_ref("email_sign_up", flow) }).delete_all
    ClientTelephoneCeremonyTransaction
      .where(session_ref: flows.filter_map { |flow| sign_up_session_ref("telephone_sign_up", flow) }).delete_all
    ClientSignUpFlow.where(id: flows.map(&:id)).delete_all
    # Bindings pin the ceremony sessions and the OIDC parent, so they go first.
    ClientAuthAdmissionBinding.where.not(id: @sign_up_journey_binding_ids).delete_all
    ClientAuthCeremonySession.where.not(id: @sign_up_journey_ceremony_ids).delete_all
  end

  def delete_sign_up_journey_tokens!(owner_ids)
    OpAppGrant.where(client_token_id: ClientToken.where(user_id: owner_ids).select(:id)).delete_all
    ClientDeviceSession.where(user_id: owner_ids).update_all(current_refresh_token_id: nil)
    # client_tokens references client_device_sessions with ON DELETE RESTRICT, so tokens go first.
    ClientToken.where(user_id: owner_ids).delete_all
    ClientDeviceSession.where(user_id: owner_ids).delete_all
  end

  def delete_sign_up_journey_owner_rows!(owners, owner_ids)
    ClientContactAuditOutbox.where(owner_ref: owners.map(&:public_id)).delete_all
    ClientPasskey.where(user_id: owner_ids).delete_all
    ClientEmail.where(user_id: owner_ids).delete_all
    ClientTelephone.where(user_id: owner_ids).delete_all
    ClientAccount.where(user_id: owner_ids).delete_all
    ClientOidcConnection.where(user_id: owner_ids).delete_all
    ClientRegistrationCompletion.where(client_id: owner_ids).delete_all
    ClientAuthorityLock.where(client_id: owner_ids).delete_all
    ClientSecretCredential.where(client_id: owner_ids).delete_all
    ClientSecretIssuance.where(client_id: owner_ids).delete_all
    Client.where(id: owner_ids).delete_all
  end

  def delete_sign_up_journey_chronicle_rows!
    chronicle_ids = Chronicle.where.not(id: @sign_up_journey_chronicle_ids).pluck(:id)
    ChronicleVisibility.where(chronicle_id: chronicle_ids).delete_all
    ChronicleOutboxEntry.where(chronicle_id: chronicle_ids).delete_all
    Chronicle.where(id: chronicle_ids).delete_all
    ClientChronicle.where.not(id: @sign_up_journey_client_chronicle_ids).delete_all
  end

  def sign_up_session_ref(kind, flow)
    return nil unless flow.nonce_digest

    Digest::SHA256.hexdigest(JSON.generate([kind, flow.public_id, flow.nonce_digest]))
  end

  # A completed signup commits the actor's bootstrap identity and collective graph alongside the
  # contact, and none of it is reachable from the contact row.
  def delete_sign_up_journey_collective_graph!(owner)
    identity_ids = ClientIdentity.where(source_record_id: owner.id).pluck(:id)
    persona_ids = ClientPersona.where(client_identity_id: identity_ids).pluck(:id)
    enterprise_ids =
      (PersonaMembership.where(persona_id: persona_ids).pluck(:enterprise_id) +
        EnterpriseOwnership.where(client_id: owner.id).pluck(:enterprise_id)).uniq
    unit_ids = EnterpriseUnit.where(enterprise_id: enterprise_ids).pluck(:id)

    delete_sign_up_journey_memberships!(persona_ids, enterprise_ids)
    delete_sign_up_journey_personas!(identity_ids, persona_ids)
    delete_sign_up_journey_enterprises!(enterprise_ids, unit_ids)
  end

  # PersonaMembership spans both graphs, so it goes before either side is removed.
  def delete_sign_up_journey_memberships!(persona_ids, enterprise_ids)
    PersonaMembership.where(persona_id: persona_ids)
      .or(PersonaMembership.where(enterprise_id: enterprise_ids)).delete_all
  end

  def delete_sign_up_journey_personas!(identity_ids, persona_ids)
    PersonaAssignment.where(persona_id: persona_ids).delete_all
    ClientOidcIdentityBinding.where(client_identity_id: identity_ids).delete_all
    AvatarPersonaBinding.where(persona_id: persona_ids).delete_all
    ClientPersonaOwnership.where(client_persona_id: persona_ids).delete_all
    ClientPersonaLifecycle.where(client_persona_id: persona_ids).delete_all
    ClientPersona.where(id: persona_ids).delete_all
    ClientIdentity.where(id: identity_ids).delete_all
  end

  def delete_sign_up_journey_enterprises!(enterprise_ids, unit_ids)
    EnterpriseUnitClosure.where(ancestor_id: unit_ids)
      .or(EnterpriseUnitClosure.where(descendant_id: unit_ids)).delete_all
    EnterpriseUnit.where(id: unit_ids).delete_all
    EnterpriseLifecycle.where(enterprise_id: enterprise_ids).delete_all
    EnterpriseOwnership.where(enterprise_id: enterprise_ids).delete_all
    EnterpriseAdministrationGrant.where(enterprise_id: enterprise_ids).delete_all
    EnterpriseDelegationGrant.where(enterprise_id: enterprise_ids).delete_all
    EnterpriseViewGrant.where(enterprise_id: enterprise_ids).delete_all
    EnterpriseOwnershipTransferRequest.where(enterprise_id: enterprise_ids).delete_all
    Enterprise.where(id: enterprise_ids).delete_all
  end
end
