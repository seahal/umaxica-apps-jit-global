# frozen_string_literal: true

require "test_helper"

class SignupOtpDelayedTransportTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    [ClientSignUpFlowStatus, ClientSignUpFlowCleanupStatus].each do |model|
      model::DEFAULTS.each { |id| model.find_or_create_by!(id: id) }
    end
  end

  test "suspended asynchronous Email delivery leaves the current signup proof usable" do
    owner = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    email = ClientEmail.create!(
      user: owner, address: "suspended-signup-#{SecureRandom.hex(8)}@example.test", confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    now = ClientSignUpFlow.database_now
    nonce = SecureRandom.urlsafe_base64(32)
    flow = ClientSignUpFlow.create!(
      auth_admission_binding: SignUpAdmissionTestFactory.binding_for!(ClientSignUpFlow),
      principal_id: owner.id, status_id: ClientSignUpFlowStatus::CONTACT_PENDING, step: "contact",
      nonce_digest: ClientSignUpFlow.digest_nonce(nonce), issued_at: now, expires_at: now + 15.minutes,
      entry_method: "email", pending_contact_type: "email", pending_contact_id: email.id,
    )
    issued = EmailSignUpOtpDeliveryIssuer.call(flow: flow, email: email, session_nonce: nonce)

    assert_predicate issued, :success?
    transaction = issued.transaction
    generation = transaction.otp_generation
    expires_at = transaction.otp_expires_at
    before_deliveries = ActionMailer::Base.deliveries.length
    OutboundChannelSuspension.stub(:suspended?, ->(channel) { channel == :email }) do
      perform_enqueued_jobs only: OtpNotifierEmailDeliveryJob
    end

    assert_equal before_deliveries, ActionMailer::Base.deliveries.length
    assert_withheld("delivery suspension preserves the issued generation") {
      generation == transaction.reload.otp_generation
    }
    assert_equal expires_at, transaction.otp_expires_at
    assert_nil transaction.otp_consumed_at
    result = EmailSignUpOtpVerificationCommitter.call(flow: flow, email: email, session_nonce: nonce, code: issued.code)

    assert_predicate result, :verified_evidence?
  end

  test "suspended asynchronous SMS leaves the current signup proof usable" do
    owner = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    telephone = ClientTelephone.create!(
      user: owner, number: "+819012345678", confirm_policy: "1",
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
    issued = nil
    assert_enqueued_jobs 1, only: Outbound::SmsDeliveryJob do
      issued = TelephoneSignUpOtpDeliveryIssuer.call(flow: flow, telephone: telephone, session_nonce: nonce)
    end

    assert_predicate issued, :success?
    transaction = issued.transaction
    generation = transaction.otp_generation
    expires_at = transaction.otp_expires_at
    provider_calls = 0
    OutboundSms.stub(:suspended?, true) do
      OutboundSms.stub(:provider, -> { provider_calls += 1 }) do
        perform_enqueued_jobs only: Outbound::SmsDeliveryJob
      end
    end

    assert_equal 0, provider_calls
    assert_withheld("delivery suspension preserves the issued generation") {
      generation == transaction.reload.otp_generation
    }
    assert_equal expires_at, transaction.otp_expires_at
    assert_nil transaction.otp_consumed_at
    result = TelephoneSignUpOtpVerificationCommitter.call(
      flow: flow, telephone: telephone, session_nonce: nonce, code: issued.code,
    )

    assert_predicate result, :verified_evidence?
  end

  test "an SMS transport retry cannot deliver a superseded signup generation" do
    owner = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    telephone = ClientTelephone.create!(
      user: owner, number: "+819012345678", confirm_policy: "1",
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
    issued = TelephoneSignUpOtpIssuer.call(flow: flow, telephone: telephone, session_nonce: nonce)

    assert_predicate issued, :success?
    transaction = issued.transaction
    expiry = transaction.otp_expires_at
    encrypted = OutboundSensitivePayload.encrypt_sms_delivery(
      to: telephone.number, title: "Verification code", body: "Your verification code: #{issued.code}",
      otp_binding: ["app", "sign_up", flow.public_id, transaction.transaction_id, transaction.otp_generation],
      otp_code: issued.code,
    )

    OutboundSms.stub(:deliver_now, ->(**) { raise Net::ReadTimeout, "injected transport timeout" }) do
      assert_enqueued_jobs 1, only: Outbound::SmsDeliveryJob do
        Outbound::SmsDeliveryJob.perform_now(encrypted_payload: encrypted)
      end
    end

    assert_nil transaction.reload.otp_consumed_at
    assert_equal expiry, transaction.otp_expires_at
    decision_time = telephone.reload.otp_last_sent_at + TelephoneOtpPolicy::SEND_COOLDOWN
    replacement =
      ClientTelephone.stub(:database_now, decision_time) do
        TelephoneSignUpOtpIssuer.call(flow: flow, telephone: telephone, session_nonce: nonce)
      end

    assert_predicate replacement, :success?
    current_generation = replacement.transaction.otp_generation
    replacement_expiry = replacement.transaction.otp_expires_at
    sends = 0

    OutboundSms.stub(:deliver_now, ->(**) { sends += 1 }) do
      assert_performed_jobs 1, only: Outbound::SmsDeliveryJob do
        perform_enqueued_jobs only: Outbound::SmsDeliveryJob, at: 1.hour.from_now
      end
    end

    assert_equal 0, sends
    assert_withheld("retry keeps the replacement generation") {
      current_generation == transaction.reload.otp_generation
    }
    assert_equal replacement_expiry, transaction.otp_expires_at
    assert_operator replacement_expiry, :<=, flow.reload.expires_at
    result = TelephoneSignUpOtpVerificationCommitter.call(
      flow: flow, telephone: telephone, session_nonce: nonce, code: replacement.code,
    )

    assert_predicate result, :verified_evidence?
  end

  [
    [Client, ClientEmail, :user_id, ClientSignUpFlow, :app, :email],
    [Client, ClientTelephone, :user_id, ClientSignUpFlow, :app, :telephone],
  ].each do |owner_model, contact_model, owner_key, flow_model, surface, channel|
    %w(current reissued consumed expired).each do |state|
      test "#{surface} #{channel} delayed signup checks #{state} evidence" do
        owner = owner_model.create!(
          security_mode_id: SecurityModeConfigurable::NORMAL,
          status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP,
        )
        destination =
          (channel == :email) ? "delayed-#{SecureRandom.hex(8)}@example.test" :
                   "+8190#{SecureRandom.random_number(100_000_000).to_s.rjust(8, "0")}"
        status_key, status =
          case channel
          when :email then [:user_email_status_id, ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP]
          when :telephone then [:user_telephone_status_id, ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP]
          end
        contact = contact_model.create!(
          owner_key => owner.id, status_key => status, :confirm_policy => "1",
          ((channel == :email) ? :address : :number) => destination,
        )
        now = flow_model.database_now
        nonce = SecureRandom.urlsafe_base64(32)
        flow = flow_model.create!(
          auth_admission_binding: SignUpAdmissionTestFactory.binding_for!(flow_model),
          principal_id: owner.id, status_id: flow_model::STATUS_MODEL::CONTACT_PENDING, step: "contact",
          nonce_digest: flow_model.digest_nonce(nonce), issued_at: now,
          expires_at: now + 15.minutes, entry_method: channel.to_s,
          pending_contact_type: channel.to_s, pending_contact_id: contact.id,
        )
        issued =
          if channel == :email
            EmailSignUpOtpIssuer.call(flow: flow, email: contact, session_nonce: nonce)
          else
            TelephoneSignUpOtpIssuer.call(flow: flow, telephone: contact, session_nonce: nonce)
          end

        assert_predicate issued, :success?
        code = issued.code
        generation = issued.transaction.otp_generation
        if state == "reissued"
          contact.update!(otp_last_sent_at: contact.class.database_now - 1.minute)
          replacement =
            if channel == :email
              EmailSignUpOtpIssuer.call(flow: flow, email: contact, session_nonce: nonce)
            else
              TelephoneSignUpOtpIssuer.call(flow: flow, telephone: contact, session_nonce: nonce)
            end

          assert_predicate replacement, :success?
        elsif state == "consumed"
          verification =
            if channel == :email
              EmailSignUpOtpVerificationCommitter.call(flow: flow, email: contact, session_nonce: nonce, code: code)
            else
              TelephoneSignUpOtpVerificationCommitter.call(
                flow: flow, telephone: contact, session_nonce: nonce, code: code,
              )
            end

          assert_predicate verification, :verified_evidence?
        end
        deadline = (state == "expired") ? flow.expires_at : now
        sent = 0
        flow_model.stub(:database_now, deadline) do
          if channel == :email
            before = ActionMailer::Base.deliveries.length
            perform_enqueued_jobs do
              OtpAdapter.for(surface: surface, channel: channel).deliver(
                record: contact, otp_code: code, public_id: contact.public_id, purpose: "sign_up",
                sign_up_flow_ref: flow.public_id,
                sign_up_email_transaction_ref: issued.transaction.transaction_id,
                sign_up_email_otp_generation: generation,
              )
            end
            sent = ActionMailer::Base.deliveries.length - before
          else
            encrypted = OutboundSensitivePayload.encrypt_sms_delivery(
              to: destination, title: "Verification code", body: "Your verification code: #{code}",
              otp_binding: [surface.to_s, "sign_up", flow.public_id, issued.transaction.transaction_id, generation],
              otp_code: code,
            )
            OutboundSms.stub(:deliver_now, ->(**) { sent += 1 }) do
              Outbound::SmsDeliveryJob.perform_now(encrypted_payload: encrypted)
            end
          end
        end

        assert_equal((state == "current") ? 1 : 0, sent)
        # D-177: an undelivered expired generation leaves the Ticket for SignUpExpiryJob.
        assert_not flow.reload.sign_up_terminal?
        assert_nil contact.reload.binding_finalized_at
      end
    end
  end
end
