# frozen_string_literal: true

require "test_helper"

class CredentialRegistrationOtpSupersessionRollbackTest < ActiveSupport::TestCase
  %w(app com org).each do |surface|
    %i(email telephone).each do |channel|
      test "#{surface} #{channel} replacement Source write failure restores original challenge authority" do
        owner_model, root_model, contact_model, owner_key, active_status =
          case [surface, channel]
          when ["app", :email] then [Client, ClientToken, ClientEmail, :user_id, ClientStatus::ACTIVE]
          when ["app", :telephone] then [Client, ClientToken, ClientTelephone, :user_id, ClientStatus::ACTIVE]
          when ["com", :email] then [Visitor, VisitorToken, VisitorEmail, :visitor_id, VisitorStatus::ACTIVE]
          when ["com", :telephone] then [Visitor, VisitorToken, VisitorTelephone, :visitor_id, VisitorStatus::ACTIVE]
          when ["org", :email] then [Operator, OperatorToken, OperatorEmail, :staff_id, OperatorStatus::ACTIVE]
          when ["org", :telephone] then [Operator, OperatorToken, OperatorTelephone, :staff_id, OperatorStatus::ACTIVE]
          end
        actor = owner_model.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: active_status)
        token = root_model.create!(:authentication_epoch => 0, owner_key => actor.id)
        token.rotate_refresh_token!
        contact = contact_model.create!(
          owner_key => actor.id, :confirm_policy => true, :otp_attempts_count => 1,
          **((channel == :email) ? { address: "supersession-rollback@example.test" } :
            { number: "+12025550178", confirm_using_mfa: true }),
        )
        issuer = (channel == :email) ? EmailCredentialRegistrationOtpIssuer : TelephoneCredentialRegistrationOtpIssuer
        arguments = {
          :actor => actor, :token => token, :browser_nonce => SecureRandom.urlsafe_base64(32), channel => contact,
        }
        first = issuer.call(**arguments)

        assert_predicate first, :success?
        contact.update!(otp_last_sent_at: contact.class.database_now - 1.minute)
        original_source = contact.reload.attributes
        original_proof = first.transaction.reload.attributes
        original_count = first.transaction.class.count
        fired = false
        fault =
          lambda do |event|
            sql = event.payload.fetch(:sql)
            next if fired || !sql.start_with?("UPDATE") || sql.exclude?(contact_model.table_name) ||
              sql.exclude?("otp_last_sent_at")

            fired = true
            raise ActiveRecord::StatementInvalid, "injected replacement Source persistence failure"
          end

        ActiveSupport::Notifications.subscribed(fault, "sql.active_record") do
          assert_raises(ActiveRecord::StatementInvalid) { issuer.call(**arguments) }
        end

        assert fired, "Actual Source persistence must be reached after prior challenge cancellation"
        proof_retained = original_proof == first.transaction.reload.attributes
        source_retained = original_source == contact.reload.attributes

        assert proof_retained
        assert source_retained
        assert_equal original_count, first.transaction.class.count
        delivered =
          if channel == :email
            first.transaction.deliver_email_otp!(
              generation: first.transaction.otp_generation, code: first.code,
            ) { true }
          else
            first.transaction.deliver_telephone_otp!(
              generation: first.transaction.otp_generation, code: first.code,
            ) { true }
          end

        assert delivered
      end
    end
  end
end
