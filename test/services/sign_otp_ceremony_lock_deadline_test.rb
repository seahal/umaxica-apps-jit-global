# frozen_string_literal: true

require "test_helper"

class SignOtpCeremonyLockDeadlineTest < ActiveSupport::TestCase
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
          private_key = ROTP::Base32.random_base32
          now = flow_model.database_now
          contact.store_otp(private_key, 1, (now + 10.minutes).to_i)
          contact.update!(otp_last_sent_at: now - 2.minutes) if operation == :issue! && channel == :email
          code = ROTP::HOTP.new(private_key).at(1).to_s
          flow = flow_model.create!(
            principal_id: owner.id, status_id: flow_model::STATUS_MODEL::STARTED, step: "start",
            nonce_digest: flow_model.digest_nonce(SecureRandom.hex(32)), issued_at: now,
            expires_at: now + 5.minutes, entry_method: channel.to_s,
            pending_contact_type: channel.to_s, pending_contact_id: contact.id,
          )
          calls = 0
          clock =
            lambda do
              calls += 1
              (lock_point == "contact_lock" && calls == 1) ? flow.expires_at - Rational(1, 1_000_000) : flow.expires_at
            end
          result = nil
          flow_model.stub(:database_now, clock) do
            arguments = {
              purpose: :sign_up,
              surface: surface,
              channel: channel,
              subject: flow,
              destination: destination,
              code: code,
              session_nonce: flow.public_id,
            }
            result = (operation == :issue!) ? SignOtpCeremony.issue!(**arguments) : SignOtpCeremony.verify!(**arguments)
          end

          assert_not result.success?, "a correct code cannot authorize an overdue Ticket"
          expired = flow.reload.sign_up_expired?

          assert expired, "overdue Ticket must durably enter EXPIRED before refusal"
          assert_nil contact.reload.binding_finalized_at
          assert_equal owner.id, contact.public_send(owner_key)
        end
      end
    end
  end
end
