# frozen_string_literal: true

require "test_helper"

class AuthEmailOtpDeliveryBindingTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    ActionMailer::Base.deliveries.clear
  end

  %w(app com).each do |surface|
    %w(reissued verified expired released halted revoked wrong_generation wrong_destination wrong_code missing_reference).each do |condition|
      test "#{surface} sign-in delivery refuses #{condition} evidence without reviving it" do
        address = "late-email-#{SecureRandom.hex(8)}@example.test"
        if surface == "app"
          owner = Client.create!(id: SecureRandom.random_number(1 << 60) + 1_000_000_000, status_id: ClientStatus::ACTIVE)
          contact = owner.client_emails.create!(
            address: address, confirm_policy: "1", user_email_status_id: ClientEmailStatus::VERIFIED,
          ).tap(&:finalize_binding!)
          model = ClientAuthCeremonySession
          mailer = Email::App::OtpMailer
        else
          owner = Visitor.create!(id: SecureRandom.random_number(1 << 60) + 1_000_000_000, status_id: VisitorStatus::ACTIVE)
          contact = owner.visitor_emails.create!(
            address: address, confirm_policy: "1", visitor_email_status_id: VisitorEmailStatus::VERIFIED,
          ).tap(&:finalize_binding!)
          model = VisitorAuthCeremonySession
          mailer = Email::Com::OtpMailer
        end
        issuance = BaseAuthAdmissionCoordinator.issue_local_entry!(
          surface: surface, intent: "sign_in", base_browser_nonce: SecureRandom.hex(32), base_token: nil,
        )
        ceremony, = model.rotate_and_admit!(
          admission_purpose: "local_sign_in", local_sign_in_flow_ref: issuance.transaction.public_id,
        )
        code = ceremony.issue_email_otp!(contact: contact, destination: address)
        payload = {
          encrypted_hotp_token: OutboundSensitivePayload.encrypt_email_otp(code),
          email_address: address, purpose: "sign_in",
          auth_ceremony_session_ref: ceremony.id.to_s,
          auth_email_otp_generation: ceremony.reload.email_otp_context.fetch("generation"),
        }
        case condition
        when "reissued" then ceremony.issue_email_otp!(contact: contact, destination: address)
        when "verified" then assert_predicate ceremony.verify_email_otp!(code: code), :success?
        when "released" then contact.release_binding!
        when "halted" then issuance.transaction.halt_sign_in!
        when "revoked" then ceremony.revoke!
        when "wrong_generation" then payload[:auth_email_otp_generation] = SecureRandom.uuid
        when "wrong_destination" then payload[:email_address] = "substituted-destination@example.test"
        when "wrong_code"
          different_code = (code == "000000") ? "000001" : "000000"
          payload[:encrypted_hotp_token] = OutboundSensitivePayload.encrypt_email_otp(different_code)
        when "missing_reference" then payload.delete(:auth_ceremony_session_ref)
        end
        snapshot = ceremony.reload.attributes
        source = contact.reload.attributes
        deadline = Time.iso8601(ceremony.email_otp_context.fetch("expires_at"))
        decision_time = (condition == "expired") ? deadline : model.database_now
        model.stub(:database_now, decision_time) do
          assert_no_difference "ActionMailer::Base.deliveries.count" do
            if condition == "missing_reference"
              assert_raises(ArgumentError) do
                # The queue helper asserts no exception; the public delivery API exposes producer corruption.
                mailer.with(payload).create.deliver_now
              end
            else
              perform_enqueued_jobs { mailer.with(payload).create.deliver_later }
            end
          end
        end
        unchanged = snapshot == ceremony.reload.attributes && source == contact.reload.attributes

        assert unchanged, "refused delivery must retain Auth and Source facts"
      end
    end
  end
end
