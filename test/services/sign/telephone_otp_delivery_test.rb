# frozen_string_literal: true

require "test_helper"

module Sign
  class TelephoneOtpDeliveryTest < ActiveSupport::TestCase
    include ActiveJob::TestHelper

    setup do
      ClientSignUpFlowStatus::DEFAULTS.each { |id| ClientSignUpFlowStatus.find_or_create_by!(id: id) }
      VisitorSignUpFlowStatus::DEFAULTS.each { |id| VisitorSignUpFlowStatus.find_or_create_by!(id: id) }
      ClientSignUpFlowCleanupStatus::DEFAULTS.each { |id| ClientSignUpFlowCleanupStatus.find_or_create_by!(id: id) }
      VisitorSignUpFlowCleanupStatus::DEFAULTS.each { |id| VisitorSignUpFlowCleanupStatus.find_or_create_by!(id: id) }
    end

    %w(app com).each do |surface|
      test "#{surface} typed signup delivery encrypts six ASCII digits and the original ceremony generation" do
        telephone_model, flow_model =
          (surface == "app") ? [ClientTelephone, ClientSignUpFlow] : [VisitorTelephone, VisitorSignUpFlow]
        candidate = telephone_model.new(raw_number: "+12025550163", confirm_policy: true, confirm_using_mfa: true)
        created = TelephoneSignUpCandidateCreator.call(telephone: candidate)
        owner = (surface == "app") ? created.telephone.user : created.telephone.visitor
        now = flow_model.database_now
        nonce = "typed-delivery-original-browser"
        flow = flow_model.create!(
          auth_admission_binding: SignUpAdmissionTestFactory.binding_for!(flow_model),
          principal_id: owner.id, status_id: flow_model::STATUS_MODEL::CONTACT_PENDING, step: "contact",
          nonce_digest: flow_model.digest_nonce(nonce), issued_at: now, expires_at: now + 15.minutes,
          entry_method: "telephone", pending_contact_type: "telephone", pending_contact_id: candidate.id,
        )
        issued = TelephoneSignUpOtpIssuer.call(flow: flow, telephone: candidate, session_nonce: nonce)

        assert_equal :issued, issued.status
        assert_match(/\A[0-9]{6}\z/, issued.code)
        assert_enqueued_jobs 1, only: Outbound::SmsDeliveryJob do
          OtpAdapter.for(surface: surface.to_sym, channel: :telephone).deliver(
            record: candidate, otp_code: issued.code, purpose: :sign_up,
            sign_up_flow_ref: flow.public_id,
            sign_up_telephone_transaction_ref: issued.transaction.transaction_id,
            sign_up_telephone_otp_generation: issued.transaction.otp_generation,
          )
        end
        arguments = enqueued_jobs.last[:args].first
        payload = OutboundSensitivePayload.decrypt_sms_delivery(arguments.fetch("encrypted_payload"))

        assert_equal candidate.number, payload.fetch(:to)
        assert_equal "Verification code", payload.fetch(:title)
        assert_equal "Your verification code: #{issued.code}", payload.fetch(:body)
        assert_equal issued.code, payload.fetch(:otp_code)
        assert_equal [surface, "sign_up", flow.public_id, issued.transaction.transaction_id,
                      issued.transaction.otp_generation,], payload.fetch(:otp_binding)
        assert_not_includes arguments.inspect, candidate.number
        assert_not_includes arguments.inspect, issued.code
      end

      test "#{surface} ceremony replacement preserves Source failures and uses bounded explicit database time" do
        telephone_model, flow_model, transaction_model =
          if surface == "app"
            [ClientTelephone, ClientSignUpFlow, ClientTelephoneCeremonyTransaction]
          else
            [VisitorTelephone, VisitorSignUpFlow, VisitorTelephoneCeremonyTransaction]
          end
        candidate = telephone_model.new(raw_number: "+12025550165", confirm_policy: true, confirm_using_mfa: true)
        TelephoneSignUpCandidateCreator.call(telephone: candidate)
        owner = (surface == "app") ? candidate.user : candidate.visitor
        now = flow_model.database_now
        nonce = "replacement-original-browser"
        flow = flow_model.create!(
          auth_admission_binding: SignUpAdmissionTestFactory.binding_for!(flow_model),
          principal_id: owner.id, status_id: flow_model::STATUS_MODEL::CONTACT_PENDING, step: "contact",
          nonce_digest: flow_model.digest_nonce(nonce), issued_at: now, expires_at: now + 15.minutes,
          entry_method: "telephone", pending_contact_type: "telephone", pending_contact_id: candidate.id,
        )
        candidate.update!(otp_attempts_count: 2)
        first = TelephoneSignUpOtpIssuer.call(flow: flow, telephone: candidate, session_nonce: nonce)
        old_generation = first.transaction.otp_generation
        at = candidate.reload.otp_last_sent_at + TelephoneOtpPolicy::SEND_COOLDOWN
        replacement =
          telephone_model.stub(:database_now, at) do
            transaction_model.stub(:database_now, at) do
              TelephoneSignUpOtpIssuer.call(flow: flow, telephone: candidate, session_nonce: nonce)
            end
          end

        assert_equal :issued, replacement.status
        assert_match(/\A[0-9]{6}\z/, first.code)
        assert_match(/\A[0-9]{6}\z/, replacement.code)
        assert_not_equal old_generation, replacement.transaction.otp_generation
        assert_equal at, candidate.reload.otp_last_sent_at
        assert_equal [at + TelephoneCeremonyOtp::OTP_TTL, flow.expires_at].min,
                     replacement.transaction.otp_expires_at
        assert_equal 2, candidate.otp_attempts_count
      end
    end

    test "typed signup issuance refuses missing malformed and wrong realm parents without changing candidate facts" do
      telephone = ClientTelephone.new(raw_number: "+12025550164", confirm_policy: true)
      facts = telephone.attributes
      [nil, 0, false, "", [], {}, VisitorSignUpFlow.new].each do |flow|
        assert_raises(ArgumentError) do
          TelephoneSignUpOtpIssuer.call(flow: flow, telephone: telephone, session_nonce: "original-browser")
        end

        assert_equal facts, telephone.attributes
      end
    end

    test "typed signup issuance refuses wrong channel candidates without changing their proof facts" do
      flow = ClientSignUpFlow.new

      [nil, 0, false, "", [], {}, ClientEmail.new, VisitorEmail.new, OperatorEmail.new,
       OperatorTelephone.new, VisitorTelephone.new,].each do |candidate|
        assert_raises(ArgumentError) do
          TelephoneSignUpOtpIssuer.call(flow: flow, telephone: candidate, session_nonce: "original-browser")
        end
      end
      email = ClientEmail.new(address: "wrong-channel@example.test")
      facts = email.attributes

      assert_raises(ArgumentError) do
        TelephoneSignUpOtpIssuer.call(flow: flow, telephone: email, session_nonce: "original-browser")
      end
      assert_equal facts, email.attributes
    end

    test "typed delivery rejects five and seven digits and non ASCII code partitions without enqueueing" do
      candidate = ClientTelephone.new(raw_number: "+12025550166")

      [nil, 0, false, "", "12345", "1234567", "abcdef", "１２３４５６", [], {}].each do |code|
        assert_no_enqueued_jobs only: Outbound::SmsDeliveryJob do
          assert_raises(ArgumentError) do
            OtpAdapter.for(surface: :app, channel: :telephone).deliver(
              record: candidate, otp_code: code, purpose: :sign_up,
              sign_up_flow_ref: "original-flow",
              sign_up_telephone_transaction_ref: SecureRandom.uuid,
              sign_up_telephone_otp_generation: SecureRandom.uuid,
            )
          end
        end
      end
    end

    %w(app com org).each do |surface|
      test "#{surface} registration refuses locked candidates without resetting failures or lockout" do
        actor, token, telephone, transaction_model =
          case surface
          when "app"
            owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
            root = ClientToken.create!(authentication_epoch: 0, user: owner)
            candidate = owner.client_telephones.create!(raw_number: "+12025550167", confirm_policy: true)
            [owner, root, candidate, ClientTelephoneCeremonyTransaction]
          when "com"
            owner = Visitor.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: VisitorStatus::ACTIVE)
            root = VisitorToken.create!(authentication_epoch: 0, visitor: owner)
            candidate = owner.visitor_telephones.create!(raw_number: "+12025550167", confirm_policy: true)
            [owner, root, candidate, VisitorTelephoneCeremonyTransaction]
          when "org"
            owner = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
            root = OperatorToken.create!(authentication_epoch: 0, staff: owner)
            candidate = owner.operator_telephones.create!(raw_number: "+12025550167")
            [owner, root, candidate, OperatorTelephoneCeremonyTransaction]
          end
        token.rotate_refresh_token!
        telephone.update!(otp_attempts_count: 2, locked_at: telephone.class.database_now + 5.minutes)
        facts = telephone.attributes.slice("otp_attempts_count", "locked_at", "otp_last_sent_at")
        outcome = nil

        assert_no_difference -> { transaction_model.count } do
          outcome = TelephoneCredentialRegistrationOtpIssuer.call(
            actor: actor, token: token, telephone: telephone, browser_nonce: SecureRandom.urlsafe_base64(32),
          )
        end

        assert_equal :locked, outcome.status
        assert_nil outcome.code
        assert_equal facts, telephone.reload.attributes.slice(*facts.keys)
      end
    end
  end
end
