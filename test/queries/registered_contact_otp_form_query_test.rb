# frozen_string_literal: true

require "test_helper"

class RegisteredContactOtpFormQueryTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    ClientSignUpFlowStatus::DEFAULTS.each { |id| ClientSignUpFlowStatus.find_or_create_by!(id: id) }
    ClientSignUpFlowCleanupStatus::DEFAULTS.each { |id| ClientSignUpFlowCleanupStatus.find_or_create_by!(id: id) }
  end

  test "sign-up Email form remains available without a challenge for a registered address" do
    owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    address = "registered-signup-form-#{SecureRandom.hex(8)}@example.test"
    email = owner.client_emails.create!(raw_address: address, confirm_policy: true)
    now = ClientSignUpFlow.database_now
    nonce = SecureRandom.urlsafe_base64(32)
    flow = ClientSignUpFlow.create!(
      auth_admission_binding: SignUpAdmissionTestFactory.binding_for!(ClientSignUpFlow),
      principal_id: owner.id, status_id: ClientSignUpFlowStatus::CONTACT_PENDING, step: "contact",
      nonce_digest: ClientSignUpFlow.digest_nonce(nonce), issued_at: now, expires_at: now + 15.minutes,
      entry_method: "email", pending_contact_type: "email", pending_contact_id: email.id,
    )
    scope = { flow: flow, email: email, session_nonce: nonce }

    assert_not EmailSignUpOtpFormQuery.call(**scope)

    competitor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    registered = competitor.client_emails.create!(
      raw_address: address, confirm_policy: true, user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    registered.finalize_binding!

    assert EmailSignUpOtpFormQuery.call(**scope)
    assert_equal 0, ClientEmailCeremonyTransaction.where(actor_ref: owner.public_id).count
  end

  test "sign-up Telephone form remains available without a challenge for a registered number" do
    owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    number = "+1202555#{SecureRandom.random_number(1_000_000).to_s.rjust(6, "0")}"
    telephone = owner.client_telephones.create!(
      raw_number: number, confirm_policy: true,
      user_telephone_status_id: ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    now = ClientSignUpFlow.database_now
    nonce = SecureRandom.urlsafe_base64(32)
    flow = ClientSignUpFlow.create!(
      auth_admission_binding: SignUpAdmissionTestFactory.binding_for!(ClientSignUpFlow),
      principal_id: owner.id, status_id: ClientSignUpFlowStatus::CONTACT_PENDING, step: "contact",
      nonce_digest: ClientSignUpFlow.digest_nonce(nonce), issued_at: now, expires_at: now + 15.minutes,
      entry_method: "telephone", pending_contact_type: "telephone", pending_contact_id: telephone.id,
    )
    scope = { flow: flow, telephone: telephone, session_nonce: nonce }

    assert_not TelephoneSignUpOtpFormQuery.call(**scope)

    competitor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    registered = competitor.client_telephones.create!(
      raw_number: number, confirm_policy: true, user_telephone_status_id: ClientTelephoneStatus::VERIFIED,
    )
    registered.finalize_binding!

    assert TelephoneSignUpOtpFormQuery.call(**scope)
    assert_equal 0, ClientTelephoneCeremonyTransaction.where(actor_ref: owner.public_id).count
  end

  %i(email telephone).each do |channel|
    test "post-login #{channel} form remains available without a challenge for a registered destination" do
      owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
      token = ClientToken.create!(authentication_epoch: 0, user: owner, discard_at: 1.day.from_now)
      destination =
        (channel == :email) ? "registered-post-login-form-#{SecureRandom.hex(8)}@example.test" :
          "+1202555#{SecureRandom.random_number(1_000_000).to_s.rjust(6, "0")}"
      contact =
        if channel == :email
          owner.client_emails.create!(raw_address: destination, confirm_policy: true)
        else
          owner.client_telephones.create!(raw_number: destination, confirm_policy: true)
        end
      token.rotate_refresh_token!
      nonce = SecureRandom.urlsafe_base64(32)
      scope = { actor: owner, token: token, browser_nonce: nonce, transaction: nil }
      query =
        if channel == :email
          [EmailCredentialRegistrationOtpFormQuery, { email: contact }]
        else
          [TelephoneCredentialRegistrationOtpFormQuery, { telephone: contact }]
        end

      assert_not query.first.call(**scope, **query.last)

      competitor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
      registered =
        if channel == :email
          competitor.client_emails.create!(
            raw_address: destination, confirm_policy: true, user_email_status_id: ClientEmailStatus::VERIFIED,
          )
        else
          competitor.client_telephones.create!(
            raw_number: destination, confirm_policy: true, user_telephone_status_id: ClientTelephoneStatus::VERIFIED,
          )
        end
      registered.finalize_binding!

      assert query.first.call(**scope, **query.last)
    end
  end
end
