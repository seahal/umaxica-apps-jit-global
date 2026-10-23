# frozen_string_literal: true

require "test_helper"

class SignOtpCeremonyLockDeadlineTest < ActiveSupport::TestCase
  setup do
    ClientSignUpFlowStatus::DEFAULTS.each { |id| ClientSignUpFlowStatus.find_or_create_by!(id: id) }
    VisitorSignUpFlowStatus::DEFAULTS.each { |id| VisitorSignUpFlowStatus.find_or_create_by!(id: id) }
    ClientSignUpFlowCleanupStatus::DEFAULTS.each { |id| ClientSignUpFlowCleanupStatus.find_or_create_by!(id: id) }
    VisitorSignUpFlowCleanupStatus::DEFAULTS.each { |id| VisitorSignUpFlowCleanupStatus.find_or_create_by!(id: id) }
  end

  [
    [Client, ClientEmail, :user_id, ClientSignUpFlow, :app, :email],
    [Client, ClientTelephone, :user_id, ClientSignUpFlow, :app, :telephone],
    [Visitor, VisitorEmail, :visitor_id, VisitorSignUpFlow, :com, :email],
    [Visitor, VisitorTelephone, :visitor_id, VisitorSignUpFlow, :com, :telephone],
  ].each do |owner_model, contact_model, owner_key, flow_model, surface, channel|
    %i(issue! verify!).each do |operation|
      %w(initial contact_lock).each do |lock_point|
        test "#{surface} #{channel} signup #{operation} commits overdue Ticket expiry at #{lock_point}" do
          owner = owner_model.create!(
            security_mode_id: SecurityModeConfigurable::NORMAL,
            status_id: (surface == :app) ? ClientStatus::UNVERIFIED_WITH_SIGN_UP : VisitorStatus::ACTIVE,
          )
          destination =
            if channel == :email
              "deadline-#{SecureRandom.hex(10)}@example.test"
            else
              "+8190#{SecureRandom.random_number(100_000_000).to_s.rjust(8, "0")}"
            end
          contact = contact_model.create!(
            owner_key => owner.id, :confirm_policy => "1",
            ((channel == :email) ? :address : :number) => destination,
          )
          now = flow_model.database_now
          flow = flow_model.create!(
            auth_admission_binding: SignUpAdmissionTestFactory.binding_for!(flow_model),
            principal_id: owner.id, status_id: flow_model::STATUS_MODEL::STARTED, step: "start",
            nonce_digest: flow_model.digest_nonce("deadline-otp-browser"), issued_at: now,
            expires_at: now + 5.minutes, entry_method: channel.to_s,
            pending_contact_type: channel.to_s, pending_contact_id: contact.id,
          )
          issued =
            if channel == :email
              EmailSignUpOtpIssuer.call(flow: flow, email: contact, session_nonce: "deadline-otp-browser")
            else
              TelephoneSignUpOtpIssuer.call(flow: flow, telephone: contact, session_nonce: "deadline-otp-browser")
            end

          assert_predicate issued, :success?
          contact.update!(otp_last_sent_at: now - 2.minutes) if operation == :issue!
          calls = 0
          clock =
            lambda do
              calls += 1
              (lock_point == "contact_lock" && calls == 1) ? flow.expires_at - Rational(1, 1_000_000) : flow.expires_at
            end
          result = nil
          flow_model.stub(:database_now, clock) do
            arguments = { flow: flow, session_nonce: "deadline-otp-browser" }
            if channel == :email
              arguments[:email] = contact
              result =
                if operation == :issue!
                  EmailSignUpOtpIssuer.call(**arguments)
                else
                  EmailSignUpOtpVerificationCommitter.call(**arguments, code: issued.code)
                end
            else
              arguments[:telephone] = contact
              result =
                if operation == :issue!
                  TelephoneSignUpOtpIssuer.call(**arguments)
                else
                  TelephoneSignUpOtpVerificationCommitter.call(**arguments, code: issued.code)
                end
            end
          end

          assert_not result.success?, "a correct code cannot authorize an overdue Ticket"
          expired = flow.reload.sign_up_expired?

          assert expired, "overdue Ticket must durably enter EXPIRED before refusal"
          assert_nil contact.reload.binding_finalized_at
          assert_equal owner.id, contact[owner_key]
        end
      end
    end
  end
end
