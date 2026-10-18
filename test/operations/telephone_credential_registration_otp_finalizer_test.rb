# frozen_string_literal: true

require "test_helper"

class TelephoneCredentialRegistrationOtpFinalizerTest < ActiveSupport::TestCase
  %w(app com).each do |surface|
    %w(current foreign_browser lost_freshness credential_lost source_fault receipt_fault).each do |scenario|
      test "#{surface} Telephone finalization #{scenario} keeps Source audit ahead of Ticket reconciliation" do
        actor, token, telephone, policy, audit =
          case surface
          when "app"
            owner = Client.create!(status_id: ClientStatus::ACTIVE)
            root = ClientToken.create!(user: owner, discard_at: 1.day.from_now)
            candidate = owner.client_telephones.create!(raw_number: "+12025550181", confirm_policy: true)
            [owner, root, candidate, ClientTelephonePolicy, ClientContactAuditOutbox]
          when "com"
            owner = Visitor.create!(status_id: VisitorStatus::ACTIVE)
            root = VisitorToken.create!(visitor: owner, discard_at: 1.day.from_now)
            candidate = owner.visitor_telephones.create!(raw_number: "+12025550182", confirm_policy: true)
            [owner, root, candidate, VisitorTelephonePolicy, VisitorContactAuditOutbox]
          end
        token.rotate_refresh_token!
        passkey =
          case actor
          when Client
            actor.client_passkeys.create!(
              webauthn_id: SecureRandom.uuid, public_key: "telephone-finalization-key", uv_verified_at: Time.current,
            )
          when Visitor
            actor.visitor_passkeys.create!(
              webauthn_id: SecureRandom.uuid, public_key: "telephone-finalization-key", uv_verified_at: Time.current,
            )
          end
        token.update!(
          last_step_up_at: token.class.database_now, last_step_up_scope: "settings_telephone",
          last_step_up_method: "passkey", last_step_up_session_public_id: token.public_id,
          last_step_up_purpose: "step_up", last_step_up_audience: "step_up:#{surface}",
          last_step_up_credential_ref: passkey.public_id, last_step_up_phishing_resistant: true,
          last_step_up_user_verified: true, last_step_up_full_reauthentication: false,
        )
        nonce = SecureRandom.urlsafe_base64(32)
        issued = TelephoneCredentialRegistrationOtpIssuer.call(
          actor: actor, token: token, telephone: telephone, browser_nonce: nonce,
        )
        verified = TelephoneCredentialRegistrationOtpVerificationCommitter.call(
          actor: actor, token: token, telephone: telephone, transaction: issued.transaction,
          browser_nonce: nonce, code: issued.code,
        )

        assert_predicate verified, :success?
        requirement = policy.new(telephone, user: actor).credential_registration_requirement(token: token)
        context = ActorValuesContext.empty.with(
          subject: actor, actor_type: (surface == "app") ? :client : :visitor, tld: surface.to_sym, surface: :base,
        )
        arguments = {
          actor: actor,
          actor_context: context,
          token: token,
          telephone: telephone,
          transaction: issued.transaction,
          browser_nonce: nonce,
          requirement: requirement,
          code: issued.code,
        }
        case scenario
        when "foreign_browser"
          arguments[:browser_nonce] = SecureRandom.urlsafe_base64(32)
        when "lost_freshness"
          token.update!(last_step_up_at: token.class.database_now - 15.minutes)
        when "credential_lost"
          passkey.update!(discard_at: passkey.class.database_now)
        end
        if scenario == "source_fault"
          ContactBindingAuditRecorder.stub(:call!, ->(**) { raise ActiveRecord::StatementInvalid }) do
            assert_raises(ActiveRecord::StatementInvalid) do
              TelephoneCredentialRegistrationOtpFinalizer.call!(**arguments)
            end
          end

          assert_not telephone.reload.binding_effective?
          assert_not audit.exists?(operation_ref: issued.transaction.transaction_id, event_name: "finalized")
          assert_nil issued.transaction.reload.consumed_at
        elsif scenario == "receipt_fault"
          issued.transaction.stub(:consume_registration_result!, -> { raise ActiveRecord::StatementInvalid }) do
            assert_raises(ActiveRecord::StatementInvalid) do
              TelephoneCredentialRegistrationOtpFinalizer.call!(**arguments)
            end
          end

          assert_predicate telephone.reload, :binding_effective?
          assert audit.exists?(operation_ref: issued.transaction.transaction_id, event_name: "finalized")
          assert_nil issued.transaction.reload.consumed_at
          assert_equal :finalized, TelephoneCredentialRegistrationOtpFinalizer.call!(**arguments)
          assert_predicate issued.transaction.reload, :consumed?
          assert_equal 1, audit.where(operation_ref: issued.transaction.transaction_id, event_name: "finalized").count
        else
          expected = (scenario == "current") ? :finalized : :unavailable

          assert_equal expected, TelephoneCredentialRegistrationOtpFinalizer.call!(**arguments)
          assert_equal scenario == "current", telephone.reload.binding_effective?
          assert_equal scenario == "current", issued.transaction.reload.consumed?
          assert_equal scenario == "current", audit.exists?(
            operation_ref: issued.transaction.transaction_id, event_name: "finalized",
          )
        end
      end
    end
  end
end
