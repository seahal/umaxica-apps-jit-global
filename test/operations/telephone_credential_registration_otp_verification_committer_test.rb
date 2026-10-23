# frozen_string_literal: true

require "test_helper"

class TelephoneCredentialRegistrationOtpVerificationCommitterTest < ActiveSupport::TestCase
  %w(app com).each do |surface|
    %w(ticket_rollback source_reset_fault newer_failure newer_failure_aba).each do |scenario|
      test "#{surface} fresh Telephone registration consumption preserves Source failures on #{scenario}" do
        actor, token, telephone =
          case surface
          when "app"
            owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
            root = ClientToken.create!(authentication_epoch: 0, user: owner, discard_at: 1.day.from_now)
            candidate = owner.client_telephones.create!(
              raw_number: "+12025550191", confirm_policy: true, otp_attempts_count: 2,
            )
            [owner, root, candidate]
          when "com"
            owner = Visitor.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: VisitorStatus::ACTIVE)
            root = VisitorToken.create!(authentication_epoch: 0, visitor: owner, discard_at: 1.day.from_now)
            candidate = owner.visitor_telephones.create!(
              raw_number: "+12025550192", confirm_policy: true, otp_attempts_count: 2,
            )
            [owner, root, candidate]
          end
        token.rotate_refresh_token!
        nonce = SecureRandom.urlsafe_base64(32)
        issued = TelephoneCredentialRegistrationOtpIssuer.call(
          actor: actor, token: token, telephone: telephone, browser_nonce: nonce,
        )
        arguments = {
          actor: actor,
          token: token,
          telephone: telephone,
          transaction: issued.transaction,
          browser_nonce: nonce,
          code: issued.code,
        }
        if scenario == "ticket_rollback"
          proof = issued.transaction.attributes.slice("otp_verifier", "otp_generation", "otp_consumed_at")
          failing_lock =
            lambda do |&verification|
              token.class.transaction(requires_new: true) do
                token.lock!
                verification.call
                raise ActiveRecord::StatementInvalid
              end
            end

          token.stub(:with_lock, failing_lock) do
            assert_raises(ActiveRecord::StatementInvalid) do
              TelephoneCredentialRegistrationOtpVerificationCommitter.call(**arguments)
            end
          end

          assert_equal proof, issued.transaction.reload.attributes.slice(*proof.keys)
          assert_equal 2, telephone.reload.otp_attempts_count
        elsif scenario == "source_reset_fault"
          telephone.stub(:update!, ->(**) { raise ActiveRecord::StatementInvalid }) do
            assert_raises(ActiveRecord::StatementInvalid) do
              TelephoneCredentialRegistrationOtpVerificationCommitter.call(**arguments)
            end
          end

          assert issued.transaction.reload.otp_consumed_at
          assert_nil issued.transaction.otp_verifier
          assert_equal 2, telephone.reload.otp_attempts_count
          resumed = TelephoneCredentialRegistrationOtpVerificationCommitter.call(**arguments)

          assert_equal :already_verified, resumed.status
          assert_not resumed.success?
          assert_predicate resumed, :verified_evidence?
          assert_equal 2, telephone.reload.otp_attempts_count
        else
          entries = 0
          newer_failure =
            lambda do |&verification|
              entries += 1
              result =
                actor.class.transaction(requires_new: true) do
                  actor.lock!
                  verification.call
                end
              if entries == 1
                telephone.update!(otp_attempts_count: 3)
                telephone.update!(otp_attempts_count: 2) if scenario == "newer_failure_aba"
              end
              result
            end
          actor.stub(:with_lock, newer_failure) do
            result = TelephoneCredentialRegistrationOtpVerificationCommitter.call(**arguments)

            assert_predicate result, :success?
          end

          assert issued.transaction.reload.otp_consumed_at
          assert_equal (scenario == "newer_failure_aba") ? 2 : 3, telephone.reload.otp_attempts_count
        end
      end
    end

    test "#{surface} retained Telephone registration guesses share the destination budget until receipt expiry" do
      actor, token, telephone =
        case surface
        when "app"
          owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
          root = ClientToken.create!(authentication_epoch: 0, user: owner, discard_at: 1.day.from_now)
          candidate = owner.client_telephones.create!(raw_number: "+12025550193", confirm_policy: true)
          [owner, root, candidate]
        when "com"
          owner = Visitor.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: VisitorStatus::ACTIVE)
          root = VisitorToken.create!(authentication_epoch: 0, visitor: owner, discard_at: 1.day.from_now)
          candidate = owner.visitor_telephones.create!(raw_number: "+12025550194", confirm_policy: true)
          [owner, root, candidate]
        end
      token.rotate_refresh_token!
      nonce = SecureRandom.urlsafe_base64(32)
      issued = TelephoneCredentialRegistrationOtpIssuer.call(
        actor: actor, token: token, telephone: telephone, browser_nonce: nonce,
      )
      arguments = {
        actor: actor,
        token: token,
        telephone: telephone,
        transaction: issued.transaction,
        browser_nonce: nonce,
      }
      namespace = "telephone-registration-receipt:#{SecureRandom.hex(12)}"
      connection = Umaxica::Valkey::Connection.new(namespace: namespace)
      budget = TelephoneOtpVerificationFailureBudget.new(connection: connection)
      key = connection.key("#{surface}:credential_registration:telephone:#{telephone.number_digest}")
      TelephoneOtpVerificationFailureBudget.stub(:new, budget) do
        fresh = TelephoneCredentialRegistrationOtpVerificationCommitter.call(**arguments, code: issued.code)

        assert_predicate fresh, :success?
        wrong_code = (issued.code == "000000") ? "000001" : "000000"
        deadline = issued.transaction.reload.otp_result_expires_at
        [-Rational(1, 1_000_000), 0, Rational(1, 1_000_000)].each do |offset|
          issued.transaction.class.stub(:database_now, deadline + offset) do
            wrong = TelephoneCredentialRegistrationOtpVerificationCommitter.call(**arguments, code: wrong_code)

            assert_not wrong.success?
            assert_not wrong.verified_evidence?
            assert_equal 1, telephone.reload.otp_attempts_count
            assert_equal "1", connection.call("GET", key)
            retained = TelephoneCredentialRegistrationOtpVerificationCommitter.call(**arguments, code: issued.code)

            assert_not retained.success?
            assert_equal offset.negative?, retained.verified_evidence?
            assert_equal 1, telephone.reload.otp_attempts_count
          end
        end
      end
    ensure
      Umaxica::Valkey::Cleanup.delete_by_prefix(connection, prefix: "#{namespace}:") if connection
      connection&.close
    end
  end
end
