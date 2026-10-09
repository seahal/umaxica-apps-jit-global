# frozen_string_literal: true

require "test_helper"

class AuthEmailOtpConsumptionConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  setup do
    ClientSignInFlowState::DEFAULTS.each { |id| ClientSignInFlowState.find_or_create_by!(id: id) }
    VisitorSignInFlowState::DEFAULTS.each { |id| VisitorSignInFlowState.find_or_create_by!(id: id) }
  end

  %w(app com).each do |surface|
    test "#{surface} concurrent Auth email verification consumes once and returns one retained receipt" do
      owner_model, contact_association, contact_status, auth_model, binding_model, ticket_owner =
        if surface == "app"
          [Client, :client_emails, { user_email_status_id: ClientEmailStatus::VERIFIED },
           ClientAuthCeremonySession, ClientAuthAdmissionBinding, AppTicketRecord,]
        else
          [Visitor, :visitor_emails, { visitor_email_status_id: VisitorEmailStatus::VERIFIED },
           VisitorAuthCeremonySession, VisitorAuthAdmissionBinding, ComTicketRecord,]
        end
      owner = owner_model.create!
      contact = owner.public_send(contact_association).create!(
        address: "auth-consume-#{SecureRandom.hex(12)}@example.test", confirm_policy: "1", **contact_status,
      ).tap(&:finalize_binding!)
      issuance = BaseAuthAdmissionCoordinator.issue_local_entry!(
        surface: surface, intent: "sign_in", base_browser_nonce: SecureRandom.hex(32), base_token: nil,
      )
      flow = issuance.transaction
      ceremony, = auth_model.rotate_and_admit!(
        admission_purpose: "local_sign_in", local_sign_in_flow_ref: flow.public_id,
      )
      code = ceremony.issue_email_otp!(contact: contact, destination: contact.address)
      source_before = contact.reload.attributes
      ready = Queue.new
      release = Queue.new
      ActiveRecord::Base.connection_handler.clear_active_connections!
      threads =
        2.times.map do
          Thread.new do
            ticket_owner.connected_to(role: :writing) do
              ticket_owner.connection_pool.with_connection do
                local = auth_model.find(ceremony.id)
                ready << true
                release.pop
                local.verify_email_otp!(code: code)
              end
            end
          end
        end
      2.times { ready.pop }
      2.times { release << true }
      outcomes = threads.map(&:value)

      assert_equal 1, outcomes.count(&:success?)
      assert_equal %i(already_verified verified), outcomes.map(&:status).sort
      assert ceremony.reload.email_otp_context.fetch("verified_at")
      # Equality failure output must not disclose Source OTP secrets or encrypted PII.
      assert_withheld("Auth OTP consumption must not rewrite Source proof or PII") {
        source_before == contact.reload.attributes
      }
    ensure
      threads&.each(&:join)
      # Only rows created by this nontransactional race fixture are removed; lifecycle purge is tested separately.
      binding_model&.where(sign_in_flow_id: flow&.id)&.delete_all if flow
      auth_model&.where(id: ceremony&.id)&.delete_all if ceremony
      flow&.class&.where(id: flow.id)&.delete_all if flow
      contact&.class&.where(id: contact.id)&.delete_all if contact
      owner_model&.where(id: owner&.id)&.delete_all if owner
    end
  end
end
