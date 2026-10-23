# frozen_string_literal: true

require "test_helper"

class CredentialRegistrationOtpSupersessionTest < ActiveSupport::TestCase
  %w(app com org).each do |surface|
    %i(email telephone).each do |channel|
      %i(original foreign).each do |browser|
        test "#{surface} #{channel} reissuance #{browser} browser preserves isolated supersession authority" do
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
            **((channel == :email) ? { address: "supersession@example.test" } :
              { number: "+12025550179", confirm_using_mfa: true }),
          )
          nonce = SecureRandom.urlsafe_base64(32)
          first =
            if channel == :email
              EmailCredentialRegistrationOtpIssuer.call(
                actor: actor, token: token, email: contact, browser_nonce: nonce,
              )
            else
              TelephoneCredentialRegistrationOtpIssuer.call(
                actor: actor, token: token, telephone: contact, browser_nonce: nonce,
              )
            end

          assert_predicate first, :success?
          contact.update!(otp_last_sent_at: contact.class.database_now - 1.minute)
          next_nonce = (browser == :original) ? nonce : SecureRandom.urlsafe_base64(32)
          second =
            if channel == :email
              EmailCredentialRegistrationOtpIssuer.call(
                actor: actor, token: token, email: contact, browser_nonce: next_nonce,
              )
            else
              TelephoneCredentialRegistrationOtpIssuer.call(
                actor: actor, token: token, telephone: contact, browser_nonce: next_nonce,
              )
            end

          assert_predicate second, :success?
          transported = 0
          delivered =
            if channel == :email
              first.transaction.reload.deliver_email_otp!(
                generation: first.transaction.otp_generation, code: first.code,
              ) { transported += 1 }
            else
              first.transaction.reload.deliver_telephone_otp!(
                generation: first.transaction.otp_generation, code: first.code,
              ) { transported += 1 }
            end

          assert_equal browser == :foreign, delivered
          assert_equal((browser == :foreign) ? 1 : 0, transported)
          assert_equal browser == :original, first.transaction.reload.otp_cancelled_at.present?
          assert_equal 1, contact.reload.otp_attempts_count
          assert_nil second.transaction.reload.otp_cancelled_at
        end
      end
    end
  end
end
