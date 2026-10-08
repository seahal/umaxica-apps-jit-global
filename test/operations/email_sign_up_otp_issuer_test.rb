# frozen_string_literal: true

require "test_helper"

class EmailSignUpOtpIssuerTest < ActiveSupport::TestCase
  setup do
    ClientSignUpFlowStatus::DEFAULTS.each { |id| ClientSignUpFlowStatus.find_or_create_by!(id: id) }
    VisitorSignUpFlowStatus::DEFAULTS.each { |id| VisitorSignUpFlowStatus.find_or_create_by!(id: id) }
    ClientSignUpFlowCleanupStatus::DEFAULTS.each { |id| ClientSignUpFlowCleanupStatus.find_or_create_by!(id: id) }
    VisitorSignUpFlowCleanupStatus::DEFAULTS.each { |id| VisitorSignUpFlowCleanupStatus.find_or_create_by!(id: id) }
  end

  %w(app com).each do |surface|
    test "#{surface} Email retained receipt guesses count below but not at or above its deadline" do
      owner_model, email_model, flow_model, transaction_model, owner_key, status =
        case surface
        when "app"
          [Client, ClientEmail, ClientSignUpFlow, ClientEmailCeremonyTransaction,
           :user_id, ClientStatus::UNVERIFIED_WITH_SIGN_UP,]
        when "com"
          [Visitor, VisitorEmail, VisitorSignUpFlow, VisitorEmailCeremonyTransaction,
           :visitor_id, VisitorStatus::ACTIVE,]
        end
      namespace = "email-signup-receipt:#{SecureRandom.hex(12)}"
      connection = Umaxica::Valkey::Connection.new(namespace: namespace)
      budget = EmailOtpVerificationFailureBudget.new(connection: connection)
      [-Rational(1, 1_000_000), 0, Rational(1, 1_000_000)].each do |offset|
        owner = owner_model.create!(status_id: status)
        email = email_model.create!(
          owner_key => owner.id, :raw_address => "receipt-guess-#{SecureRandom.hex(8)}@example.test",
          :confirm_policy => true,
        )
        now = flow_model.database_now
        nonce = "retained-email-receipt-browser"
        flow = flow_model.create!(
          principal_id: owner.id, status_id: flow_model::STATUS_MODEL::CONTACT_PENDING, step: "contact",
          nonce_digest: flow_model.digest_nonce(nonce), issued_at: now, expires_at: now + 15.minutes,
          entry_method: "email", pending_contact_type: "email", pending_contact_id: email.id,
        )
        issued = EmailSignUpOtpIssuer.call(flow: flow, email: email, session_nonce: nonce)
        scope = { flow: flow, email: email, session_nonce: nonce }
        key = connection.key("#{surface}:sign_up:email:#{email.address_digest}")
        EmailOtpVerificationFailureBudget.stub(:new, budget) do
          fresh = EmailSignUpOtpVerificationCommitter.call(**scope, code: issued.code)

          assert_predicate fresh, :success?
          assert_equal 0, email.reload.otp_attempts_count
          assert_nil connection.call("GET", key)
          wrong_code = (issued.code == "000000") ? "000001" : "000000"
          at = issued.transaction.reload.otp_result_expires_at + offset
          transaction_model.stub(:database_now, at) do
            wrong = EmailSignUpOtpVerificationCommitter.call(**scope, code: wrong_code)

            assert_not wrong.success?
            assert_not wrong.verified_evidence?
            assert_equal offset.negative? ? 1 : 0, email.reload.otp_attempts_count
            if offset.negative?
              assert_equal "1", connection.call("GET", key), "Retained-code guesses use valid:false admission"
            else
              assert_nil connection.call("GET", key), "Expired receipts do not admit failure attempts"
            end
            retained = EmailSignUpOtpVerificationCommitter.call(**scope, code: issued.code)

            assert_not retained.success?
            assert_equal offset.negative?, retained.verified_evidence?
            assert_equal offset.negative? ? 1 : 0, email.reload.otp_attempts_count
          end
        end
      end
    ensure
      Umaxica::Valkey::Cleanup.delete_by_prefix(connection, prefix: "#{namespace}:") if connection
      connection&.close
    end

    [2, 3].each do |later_count|
      test "#{surface} Email signup preserves rollback failures and later Source writes ending at #{later_count}" do
        owner_model, email_model, flow_model, owner_key, status =
          case surface
          when "app" then [Client, ClientEmail, ClientSignUpFlow, :user_id, ClientStatus::UNVERIFIED_WITH_SIGN_UP]
          when "com" then [Visitor, VisitorEmail, VisitorSignUpFlow, :visitor_id, VisitorStatus::ACTIVE]
          end
        owner = owner_model.create!(status_id: status)
        email = email_model.create!(
          owner_key => owner.id, :raw_address => "signup-rollback-#{SecureRandom.hex(8)}@example.test",
          :confirm_policy => true, :otp_attempts_count => 2,
        )
        now = flow_model.database_now
        nonce = "signup-rollback-browser"
        flow = flow_model.create!(
          principal_id: owner.id, status_id: flow_model::STATUS_MODEL::CONTACT_PENDING, step: "contact",
          nonce_digest: flow_model.digest_nonce(nonce), issued_at: now, expires_at: now + 15.minutes,
          entry_method: "email", pending_contact_type: "email", pending_contact_id: email.id,
        )
        issued = EmailSignUpOtpIssuer.call(flow: flow, email: email, session_nonce: nonce)
        failing_lock =
          lambda do |&verification|
            flow.class.transaction(requires_new: true) do
              flow.lock!
              verification.call
              raise ActiveRecord::StatementInvalid, "Injected Ticket failure before commit"
            end
          end

        assert_raises(ActiveRecord::StatementInvalid) do
          flow.stub(:with_lock, failing_lock) do
            EmailSignUpOtpVerificationCommitter.call(flow: flow, email: email, session_nonce: nonce, code: issued.code)
          end
        end
        assert_nil issued.transaction.reload.otp_consumed_at
        assert_equal 2, email.reload.otp_attempts_count,
                     "Source reset must follow successful Ticket consumption, not precede its commit"
        lock_calls = 0
        delayed_lock =
          lambda do |&verification|
            lock_calls += 1
            if lock_calls == 2
              email.update!(otp_attempts_count: later_count, updated_at: email.updated_at + 1.second)
            end
            flow.class.transaction(requires_new: true) do
              flow.lock!
              verification.call
            end
          end
        verified =
          flow.stub(:with_lock, delayed_lock) do
            EmailSignUpOtpVerificationCommitter.call(flow: flow, email: email, session_nonce: nonce, code: issued.code)
          end

        assert_predicate verified, :success?
        assert issued.transaction.reload.otp_consumed_at
        assert_equal later_count, email.reload.otp_attempts_count,
                     "A failure after successful consumption must not be erased by its delayed reset"
      end
    end

    test "#{surface} Email signup late delivery requires the original parent browser destination and generation" do
      owner_model, email_model, flow_model, owner_key, status =
        case surface
        when "app" then [Client, ClientEmail, ClientSignUpFlow, :user_id, ClientStatus::UNVERIFIED_WITH_SIGN_UP]
        when "com" then [Visitor, VisitorEmail, VisitorSignUpFlow, :visitor_id, VisitorStatus::ACTIVE]
        end
      owner = owner_model.create!(status_id: status)
      email = email_model.create!(
        owner_key => owner.id, :raw_address => "signup-delivery-#{SecureRandom.hex(8)}@example.test",
        :confirm_policy => true, :otp_attempts_count => 1,
      )
      now = flow_model.database_now
      nonce = "signup-delivery-browser"
      flow = flow_model.create!(
        principal_id: owner.id, status_id: flow_model::STATUS_MODEL::CONTACT_PENDING, step: "contact",
        nonce_digest: flow_model.digest_nonce(nonce), issued_at: now, expires_at: now + 15.minutes,
        entry_method: "email", pending_contact_type: "email", pending_contact_id: email.id,
      )
      issued = EmailSignUpOtpIssuer.call(flow: flow, email: email, session_nonce: nonce)
      arguments = {
        flow: flow,
        email: email,
        transaction: issued.transaction,
        generation: issued.transaction.otp_generation,
        destination: email.address,
        code: issued.code,
      }
      transported = 0
      delivered = EmailSignUpOtpDeliveryGuard.call(**arguments) { transported += 1 }

      assert delivered
      assert_equal 1, transported
      [arguments.merge(generation: SecureRandom.uuid),
       arguments.merge(destination: "foreign@example.test"),].each do |bad|
        assert_not EmailSignUpOtpDeliveryGuard.call(**bad) { transported += 1 }
      end
      flow.update!(nonce_digest: flow_model.digest_nonce("another-delivery-browser"))

      assert_not EmailSignUpOtpDeliveryGuard.call(**arguments) { transported += 1 }
      assert_equal 1, transported
      assert_equal 1, email.reload.otp_attempts_count
      assert_nil issued.transaction.reload.otp_consumed_at
    end

    test "#{surface} Email signup issues only ceremony proof and rotates generation without resetting failures" do
      owner_model, email_model, flow_model, transaction_model, owner_key, status =
        case surface
        when "app"
          [Client, ClientEmail, ClientSignUpFlow, ClientEmailCeremonyTransaction, :user_id,
           ClientStatus::UNVERIFIED_WITH_SIGN_UP,]
        when "com"
          [Visitor, VisitorEmail, VisitorSignUpFlow, VisitorEmailCeremonyTransaction, :visitor_id,
           VisitorStatus::ACTIVE,]
        end
      owner = owner_model.create!(status_id: status)
      email = email_model.create!(
        owner_key => owner.id, :raw_address => "owned-signup-#{SecureRandom.hex(8)}@example.test",
        :confirm_policy => true, :otp_attempts_count => 1,
      )
      now = flow_model.database_now
      nonce = "owned-signup-browser"
      flow = flow_model.create!(
        principal_id: owner.id, status_id: flow_model::STATUS_MODEL::CONTACT_PENDING, step: "contact",
        nonce_digest: flow_model.digest_nonce(nonce), issued_at: now, expires_at: now + 15.minutes,
        entry_method: "email", pending_contact_type: "email", pending_contact_id: email.id,
      )
      original = email.attributes.slice("otp_private_key", "otp_counter", "otp_expires_at", "sign_up_otp_context")
      denied = EmailSignUpOtpIssuer.call(flow: flow, email: email, session_nonce: flow.public_id)

      assert_equal :session_mismatch, denied.status
      assert_nil denied.code
      assert_nil denied.transaction
      issued = EmailSignUpOtpIssuer.call(flow: flow, email: email, session_nonce: nonce)

      assert_equal :issued, issued.status
      assert_instance_of transaction_model, issued.transaction
      assert_match(/\A[0-9]{6}\z/, issued.code)
      assert_equal "sign_up", issued.transaction.operation
      assert_equal "sign_up", issued.transaction.purpose
      assert_equal owner.public_id, issued.transaction.actor_ref
      assert_equal email.public_id, issued.transaction.email_candidate_ref
      assert_equal email.address_digest, issued.transaction.normalized_email_digest
      assert_equal flow.expires_at, issued.transaction.expires_at
      assert_equal original, email.reload.attributes.slice(*original.keys)
      assert_equal 1, email.otp_attempts_count
      generation = issued.transaction.otp_generation
      resend =
        email_model.stub(:database_now, email.otp_last_sent_at + EmailOtpPolicy::SEND_COOLDOWN) do
          EmailSignUpOtpIssuer.call(flow: flow, email: email, session_nonce: nonce)
        end

      assert_equal :issued, resend.status
      assert_equal issued.transaction.id, resend.transaction.id
      assert_not_equal generation, resend.transaction.otp_generation
      assert_equal 1, email.reload.otp_attempts_count
      assert_equal original, email.attributes.slice(*original.keys)
      delivered = false
      stale = resend.transaction.deliver_email_otp!(generation: generation, code: issued.code) { delivered = true }

      assert_not stale
      assert_not delivered
      decision_time = now
      original_sent_at = email.otp_last_sent_at
      expired_while_waiting =
        flow_model.stub(:database_now, -> { decision_time }) do
          email_model.stub(:database_now, -> { decision_time = flow.expires_at; now }) do
            EmailSignUpOtpIssuer.call(flow: flow, email: email, session_nonce: nonce)
          end
        end

      assert_equal :inactive_flow, expired_while_waiting.status,
                   "The original signup deadline is rechecked after Source lock acquisition"
      assert_equal original_sent_at, email.reload.otp_last_sent_at
      assert_equal 1, email.otp_attempts_count
      assert_predicate flow.reload, :sign_up_expired?
      denied_after_expiry = EmailSignUpOtpIssuer.call(flow: flow, email: email, session_nonce: nonce)

      assert_equal :inactive_flow, denied_after_expiry.status, "An earlier clock cannot reopen terminal signup"
      assert_nil denied_after_expiry.code
      assert_nil denied_after_expiry.transaction
    end

    test "#{surface} Email signup consumes once and bounds receipt retries without another attempt reset" do
      owner_model, email_model, flow_model, transaction_model, owner_key, status =
        case surface
        when "app"
          [Client, ClientEmail, ClientSignUpFlow, ClientEmailCeremonyTransaction, :user_id,
           ClientStatus::UNVERIFIED_WITH_SIGN_UP,]
        when "com"
          [Visitor, VisitorEmail, VisitorSignUpFlow, VisitorEmailCeremonyTransaction, :visitor_id,
           VisitorStatus::ACTIVE,]
        end
      owner = owner_model.create!(status_id: status)
      email = email_model.create!(
        owner_key => owner.id, :raw_address => "signup-verify-#{SecureRandom.hex(8)}@example.test",
        :confirm_policy => true, :otp_attempts_count => 1,
      )
      now = flow_model.database_now
      nonce = "signup-verify-browser"
      flow = flow_model.create!(
        principal_id: owner.id, status_id: flow_model::STATUS_MODEL::CONTACT_PENDING, step: "contact",
        nonce_digest: flow_model.digest_nonce(nonce), issued_at: now, expires_at: now + 15.minutes,
        entry_method: "email", pending_contact_type: "email", pending_contact_id: email.id,
      )
      original = email.attributes.slice("otp_private_key", "otp_counter", "otp_expires_at", "sign_up_otp_context")
      resend = EmailSignUpOtpIssuer.call(flow: flow, email: email, session_nonce: nonce)
      scope = { flow: flow, email: email, session_nonce: nonce }
      foreign = EmailSignUpOtpVerificationCommitter.call(
        **scope.merge(session_nonce: flow.public_id),
        code: resend.code,
      )

      assert_not foreign.success?
      assert_equal :session_mismatch, foreign.status
      assert_equal 1, email.reload.otp_attempts_count
      admission_budget = EmailOtpVerificationFailureBudget.new
      exhausted =
        EmailOtpVerificationFailureBudget.stub(:new, admission_budget) do
          admission_budget.stub(:verify!, :locked) do
            EmailSignUpOtpVerificationCommitter.call(**scope, code: resend.code)
          end
        end

      assert_equal :locked, exhausted.status
      assert_nil resend.transaction.reload.otp_consumed_at
      assert_equal 1, email.reload.otp_attempts_count
      wrong_code = (resend.code == "000000") ? "000001" : "000000"
      wrong = EmailSignUpOtpVerificationCommitter.call(**scope, code: wrong_code)

      assert_equal :invalid_code, wrong.status
      assert_equal 2, email.reload.otp_attempts_count
      verified = EmailSignUpOtpVerificationCommitter.call(**scope, code: resend.code)

      assert_predicate verified, :success?
      assert_predicate verified, :verified_evidence?
      assert_equal 0, email.reload.otp_attempts_count
      assert resend.transaction.reload.otp_consumed_at
      email.update!(otp_attempts_count: 1)
      resumed = EmailSignUpOtpVerificationCommitter.call(**scope, code: resend.code)

      assert_not resumed.success?, "Retained proof is not another successful verification"
      assert_predicate resumed, :verified_evidence?
      assert_equal :already_verified, resumed.status
      assert_equal 1, email.reload.otp_attempts_count, "Receipt reads must not reset subsequent failures"
      assert_equal original, email.attributes.slice(*original.keys)
      receipt_now = resend.transaction.otp_result_expires_at - Rational(1, 1_000_000)
      budget = EmailOtpVerificationFailureBudget.new
      expired_receipt =
        transaction_model.stub(:database_now, -> { receipt_now }) do
          EmailOtpVerificationFailureBudget.stub(:new, budget) do
            budget.stub(:verify!, ->(**) { receipt_now = resend.transaction.otp_result_expires_at; :verified }) do
              EmailSignUpOtpVerificationCommitter.call(**scope, code: resend.code)
            end
          end
        end

      assert_not expired_receipt.verified_evidence?, "Budget admission wait cannot extend retained proof"
      assert_equal :result_expired, expired_receipt.status
    end
  end
end
