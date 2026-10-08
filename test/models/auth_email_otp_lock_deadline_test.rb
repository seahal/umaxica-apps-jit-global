# frozen_string_literal: true

require "test_helper"

class AuthEmailOtpLockDeadlineTest < ActiveSupport::TestCase
  setup do
    ClientSignInFlowState::DEFAULTS.each { |id| ClientSignInFlowState.find_or_create_by!(id: id) }
    VisitorSignInFlowState::DEFAULTS.each { |id| VisitorSignInFlowState.find_or_create_by!(id: id) }
  end

  %w(app com).each do |surface|
    test "#{surface} an overdue local parent commits its named expiry before OTP refusal" do
      model = (surface == "app") ? ClientAuthCeremonySession : VisitorAuthCeremonySession
      issuance = BaseAuthAdmissionCoordinator.issue_local_entry!(
        surface: surface, intent: "sign_in", base_browser_nonce: SecureRandom.hex(32), base_token: nil,
      )
      ceremony, = model.rotate_and_admit!(
        admission_purpose: "local_sign_in", local_sign_in_flow_ref: issuance.transaction.public_id,
      )
      parent = issuance.transaction
      context = ceremony.reload.attributes
      deadline = parent.expires_at
      parent.class.stub(:database_now, deadline) do
        model.stub(:database_now, deadline) do
          assert_raises(AuthCeremonySession::InvalidTransition) { ceremony.verify_email_otp!(code: "000000") }
        end
      end

      parent_expired = parent.reload.sign_in_expired?

      assert parent_expired, "overdue local parent must commit its named expiry"
      assert_equal context, ceremony.reload.attributes
    end

    %w(otp parent parent_issuance parent_delivery).each do |deadline_kind|
      test "#{surface} email challenge rechecks #{deadline_kind} deadline after acquiring Contact ownership locks" do
        address = "lock-deadline-#{SecureRandom.hex(8)}@example.test"
        if surface == "app"
          owner = Client.create!(id: SecureRandom.random_number(1 << 60) + 1_000_000_000, status_id: ClientStatus::ACTIVE)
          contact = owner.client_emails.create!(
            address: address, confirm_policy: "1", user_email_status_id: ClientEmailStatus::VERIFIED,
          ).tap(&:finalize_binding!)
          model = ClientAuthCeremonySession
        else
          owner = Visitor.create!(id: SecureRandom.random_number(1 << 60) + 1_000_000_000, status_id: VisitorStatus::ACTIVE)
          contact = owner.visitor_emails.create!(
            address: address, confirm_policy: "1", visitor_email_status_id: VisitorEmailStatus::VERIFIED,
          ).tap(&:finalize_binding!)
          model = VisitorAuthCeremonySession
        end
        issuance = BaseAuthAdmissionCoordinator.issue_local_entry!(
          surface: surface, intent: "sign_in", base_browser_nonce: SecureRandom.hex(32), base_token: nil,
        )
        ceremony, = model.rotate_and_admit!(
          admission_purpose: "local_sign_in", local_sign_in_flow_ref: issuance.transaction.public_id,
        )
        code = ceremony.issue_email_otp!(contact: contact, destination: address)
        context = ceremony.reload.email_otp_context.deep_dup
        source = contact.reload.attributes
        deadline =
          if deadline_kind.start_with?("parent")
            issuance.transaction.expires_at
          else
            Time.iso8601(context.fetch("expires_at"))
          end
        calls = 0
        clock =
          lambda do
            calls += 1
            (calls == 1) ? deadline - Rational(1, 1_000_000) : deadline
          end
        result = nil
        issuance.transaction.class.stub(:database_now, deadline) do
          model.stub(:database_now, clock) do
            case deadline_kind
            when "parent_issuance"
              assert_raises(AuthCeremonySession::InvalidTransition) do
                ceremony.issue_email_otp!(contact: contact, destination: address)
              end
            when "parent_delivery"
              result =
                ceremony.with_email_otp_delivery!(
                  generation: context.fetch("generation"), code: code, destination: address,
                ) { flunk("expired parent must not reach transport") }
            else
              result = ceremony.verify_email_otp!(code: code)
            end
          end
        end

        if deadline_kind == "parent_delivery"
          assert_instance_of FalseClass, result
        elsif deadline_kind != "parent_issuance"
          assert_not result.success?
          assert_equal :expired, result.status
        end

        assert_equal context, ceremony.reload.email_otp_context
        assert_equal source, contact.reload.attributes
        if deadline_kind.start_with?("parent")
          parent_expired = issuance.transaction.reload.sign_in_expired?

          assert parent_expired, "post-lock parent expiry must commit before refusal"
        end
      end
    end
  end
end
