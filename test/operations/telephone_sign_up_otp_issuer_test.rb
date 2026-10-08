# frozen_string_literal: true

require "test_helper"

class TelephoneSignUpOtpIssuerTest < ActiveSupport::TestCase
  setup do
    ClientSignUpFlowStatus::DEFAULTS.each { |id| ClientSignUpFlowStatus.find_or_create_by!(id: id) }
    VisitorSignUpFlowStatus::DEFAULTS.each { |id| VisitorSignUpFlowStatus.find_or_create_by!(id: id) }
    ClientSignUpFlowCleanupStatus::DEFAULTS.each { |id| ClientSignUpFlowCleanupStatus.find_or_create_by!(id: id) }
    VisitorSignUpFlowCleanupStatus::DEFAULTS.each { |id| VisitorSignUpFlowCleanupStatus.find_or_create_by!(id: id) }
  end

  %w(app com).each do |surface|
    test "#{surface} Telephone retained receipt guesses count below but not at or above its deadline" do
      owner_model, telephone_model, flow_model, transaction_model, owner_key, status =
        case surface
        when "app"
          [Client, ClientTelephone, ClientSignUpFlow, ClientTelephoneCeremonyTransaction,
           :user_id, ClientStatus::UNVERIFIED_WITH_SIGN_UP,]
        when "com"
          [Visitor, VisitorTelephone, VisitorSignUpFlow, VisitorTelephoneCeremonyTransaction,
           :visitor_id, VisitorStatus::ACTIVE,]
        end
      namespace = "telephone-signup-receipt:#{SecureRandom.hex(12)}"
      connection = Umaxica::Valkey::Connection.new(namespace: namespace)
      budget = TelephoneOtpVerificationFailureBudget.new(connection: connection)
      [-Rational(1, 1_000_000), 0, Rational(1, 1_000_000)].each_with_index do |offset, index|
        owner = owner_model.create!(status_id: status)
        telephone = telephone_model.create!(
          owner_key => owner.id, :raw_number => "+1202555017#{index}", :confirm_policy => true,
        )
        now = flow_model.database_now
        nonce = "retained-receipt-browser"
        flow = flow_model.create!(
          principal_id: owner.id, status_id: flow_model::STATUS_MODEL::CONTACT_PENDING, step: "contact",
          nonce_digest: flow_model.digest_nonce(nonce), issued_at: now, expires_at: now + 15.minutes,
          entry_method: "telephone", pending_contact_type: "telephone", pending_contact_id: telephone.id,
        )
        issued = TelephoneSignUpOtpIssuer.call(flow: flow, telephone: telephone, session_nonce: nonce)
        scope = { flow: flow, telephone: telephone, session_nonce: nonce }
        key = connection.key("#{surface}:sign_up:telephone:#{telephone.number_digest}")
        TelephoneOtpVerificationFailureBudget.stub(:new, budget) do
          fresh = TelephoneSignUpOtpVerificationCommitter.call(**scope, code: issued.code)

          assert_predicate fresh, :success?
          assert_equal 0, telephone.reload.otp_attempts_count
          assert_nil connection.call("GET", key)
          wrong_code = (issued.code == "000000") ? "000001" : "000000"
          at = issued.transaction.reload.otp_result_expires_at + offset
          transaction_model.stub(:database_now, at) do
            wrong = TelephoneSignUpOtpVerificationCommitter.call(**scope, code: wrong_code)

            assert_not wrong.success?
            assert_not wrong.verified_evidence?
            assert_equal offset.negative? ? 1 : 0, telephone.reload.otp_attempts_count
            if offset.negative?
              assert_equal "1", connection.call("GET", key), "A retained-code guess must use valid:false admission"
            else
              assert_nil connection.call("GET", key), "Expired receipts must not admit failure attempts"
            end
            retained = TelephoneSignUpOtpVerificationCommitter.call(**scope, code: issued.code)

            assert_not retained.success?
            assert_equal offset.negative?, retained.verified_evidence?
            assert_equal offset.negative? ? 1 : 0, telephone.reload.otp_attempts_count
            if offset.negative?
              assert_equal "1", connection.call("GET", key)
            else
              assert_nil connection.call("GET", key)
            end
          end
        end
      end
    ensure
      Umaxica::Valkey::Cleanup.delete_by_prefix(connection, prefix: "#{namespace}:") if connection
      connection&.close
    end

    test "#{surface} Telephone public flow lock rollback preserves proof and Source failures" do
      owner_model, telephone_model, flow_model, owner_key, status =
        case surface
        when "app" then [Client, ClientTelephone, ClientSignUpFlow, :user_id, ClientStatus::UNVERIFIED_WITH_SIGN_UP]
        when "com" then [Visitor, VisitorTelephone, VisitorSignUpFlow, :visitor_id, VisitorStatus::ACTIVE]
        end
      owner = owner_model.create!(status_id: status)
      telephone = telephone_model.create!(
        owner_key => owner.id, :raw_number => "+12025550151", :confirm_policy => true, :otp_attempts_count => 2,
      )
      now = flow_model.database_now
      nonce = "outer-lock-fault-browser"
      flow = flow_model.create!(
        principal_id: owner.id, status_id: flow_model::STATUS_MODEL::CONTACT_PENDING, step: "contact",
        nonce_digest: flow_model.digest_nonce(nonce), issued_at: now, expires_at: now + 15.minutes,
        entry_method: "telephone", pending_contact_type: "telephone", pending_contact_id: telephone.id,
      )
      issued = TelephoneSignUpOtpIssuer.call(flow: flow, telephone: telephone, session_nonce: nonce)
      proof = issued.transaction.attributes.slice("otp_verifier", "otp_consumed_at", "otp_receipt_verifier")
      failing_lock =
        lambda do |&work|
          flow.class.transaction(requires_new: true) do
            flow.lock!
            work.call
            raise ActiveRecord::StatementInvalid, "Telephone outer Ticket commit unavailable"
          end
        end

      flow.stub(:with_lock, failing_lock) do
        assert_raises(ActiveRecord::StatementInvalid) do
          TelephoneSignUpOtpVerificationCommitter.call(
            flow: flow, telephone: telephone, session_nonce: nonce, code: issued.code,
          )
        end
      end

      assert_equal proof, issued.transaction.reload.attributes.slice(*proof.keys)
      assert_equal 2, telephone.reload.otp_attempts_count
    end

    test "#{surface} Telephone optional reset preserves failures arriving after consumption" do
      owner_model, telephone_model, flow_model, owner_key, status =
        case surface
        when "app" then [Client, ClientTelephone, ClientSignUpFlow, :user_id, ClientStatus::UNVERIFIED_WITH_SIGN_UP]
        when "com" then [Visitor, VisitorTelephone, VisitorSignUpFlow, :visitor_id, VisitorStatus::ACTIVE]
        end
      owner = owner_model.create!(status_id: status)
      telephone = telephone_model.create!(
        owner_key => owner.id, :raw_number => "+12025550152", :confirm_policy => true, :otp_attempts_count => 2,
      )
      now = flow_model.database_now
      nonce = "newer-failure-browser"
      flow = flow_model.create!(
        principal_id: owner.id, status_id: flow_model::STATUS_MODEL::CONTACT_PENDING, step: "contact",
        nonce_digest: flow_model.digest_nonce(nonce), issued_at: now, expires_at: now + 15.minutes,
        entry_method: "telephone", pending_contact_type: "telephone", pending_contact_id: telephone.id,
      )
      issued = TelephoneSignUpOtpIssuer.call(flow: flow, telephone: telephone, session_nonce: nonce)
      calls = 0
      interleaved_lock =
        lambda do |&work|
          calls += 1
          telephone_model.find(telephone.id).increment_attempts! if calls == 2
          flow.class.transaction(requires_new: true) do
            flow.lock!
            work.call
          end
        end
      verified =
        flow.stub(:with_lock, interleaved_lock) do
          TelephoneSignUpOtpVerificationCommitter.call(
            flow: flow, telephone: telephone, session_nonce: nonce, code: issued.code,
          )
        end

      assert_predicate verified, :success?
      assert issued.transaction.reload.otp_consumed_at
      assert_equal 3, telephone.reload.otp_attempts_count
    end

    test "#{surface} Telephone issuance checks cooldown minus at and plus one microsecond without resetting failures" do
      owner_model, telephone_model, flow_model, owner_key, status =
        case surface
        when "app" then [Client, ClientTelephone, ClientSignUpFlow, :user_id, ClientStatus::UNVERIFIED_WITH_SIGN_UP]
        when "com" then [Visitor, VisitorTelephone, VisitorSignUpFlow, :visitor_id, VisitorStatus::ACTIVE]
        end
      [-Rational(1, 1_000_000), 0, Rational(1, 1_000_000)].each do |offset|
        owner = owner_model.create!(status_id: status)
        telephone = telephone_model.create!(
          owner_key => owner.id, :raw_number => "+12025550147", :confirm_policy => true, :otp_attempts_count => 4,
        )
        now = flow_model.database_now
        nonce = "cooldown-boundary-browser"
        flow = flow_model.create!(
          principal_id: owner.id, status_id: flow_model::STATUS_MODEL::CONTACT_PENDING, step: "contact",
          nonce_digest: flow_model.digest_nonce(nonce), issued_at: now, expires_at: now + 15.minutes,
          entry_method: "telephone", pending_contact_type: "telephone", pending_contact_id: telephone.id,
        )
        issued = TelephoneSignUpOtpIssuer.call(flow: flow, telephone: telephone, session_nonce: nonce)
        generation = issued.transaction.otp_generation
        at = telephone.reload.otp_last_sent_at + TelephoneOtpPolicy::SEND_COOLDOWN + offset
        resend =
          telephone_model.stub(:database_now, at) do
            TelephoneSignUpOtpIssuer.call(flow: flow, telephone: telephone, session_nonce: nonce)
          end

        assert_equal offset.negative? ? :rate_limited : :issued, resend.status
        assert_equal 4, telephone.reload.otp_attempts_count
        if offset.negative?
          assert_equal generation, issued.transaction.reload.otp_generation
        else
          assert_not_equal generation, issued.transaction.reload.otp_generation
        end
      end
    end

    test "#{surface} Telephone cancelled and recreated candidates preserve the shared destination failure budget" do
      owner_model, telephone_model, flow_model, owner_key, status =
        case surface
        when "app" then [Client, ClientTelephone, ClientSignUpFlow, :user_id, ClientStatus::UNVERIFIED_WITH_SIGN_UP]
        when "com" then [Visitor, VisitorTelephone, VisitorSignUpFlow, :visitor_id, VisitorStatus::ACTIVE]
        end
      issued = nil
      telephone = nil
      2.times do |index|
        owner = owner_model.create!(status_id: status)
        telephone = telephone_model.create!(
          owner_key => owner.id, :raw_number => "+12025550149", :confirm_policy => true,
        )
        now = flow_model.database_now
        nonce = "shared-budget-browser-#{index}"
        flow = flow_model.create!(
          principal_id: owner.id, status_id: flow_model::STATUS_MODEL::CONTACT_PENDING, step: "contact",
          nonce_digest: flow_model.digest_nonce(nonce), issued_at: now, expires_at: now + 15.minutes,
          entry_method: "telephone", pending_contact_type: "telephone", pending_contact_id: telephone.id,
        )
        issued = TelephoneSignUpOtpIssuer.call(flow: flow, telephone: telephone, session_nonce: nonce)
        if index.zero?
          wrong_code = (issued.code == "000000") ? "000001" : "000000"
          5.times do |attempt|
            rejected = TelephoneSignUpOtpVerificationCommitter.call(
              flow: flow, telephone: telephone, session_nonce: nonce, code: wrong_code,
            )

            assert_equal (attempt == 4) ? :locked : :invalid_code, rejected.status
          end
          assert_equal 5, telephone.reload.otp_attempts_count
          issued.transaction.cancel_telephone_otp!

          assert_equal 5, telephone.reload.otp_attempts_count
        else
          refused = TelephoneSignUpOtpVerificationCommitter.call(
            flow: flow, telephone: telephone, session_nonce: nonce, code: issued.code,
          )

          assert_equal :locked, refused.status
          assert_nil issued.transaction.reload.otp_consumed_at
          assert_equal 0, telephone.reload.otp_attempts_count
        end
      end
    end

    test "#{surface} Telephone fresh proof survives Source attempt reset failure without receipt resetting attempts" do
      owner_model, telephone_model, flow_model, transaction_model, owner_key, status =
        case surface
        when "app"
          [Client, ClientTelephone, ClientSignUpFlow, ClientTelephoneCeremonyTransaction,
           :user_id, ClientStatus::UNVERIFIED_WITH_SIGN_UP,]
        when "com"
          [Visitor, VisitorTelephone, VisitorSignUpFlow, VisitorTelephoneCeremonyTransaction,
           :visitor_id, VisitorStatus::ACTIVE,]
        end
      owner = owner_model.create!(status_id: status)
      telephone = telephone_model.create!(
        owner_key => owner.id, :raw_number => "+12025550148", :confirm_policy => true, :otp_attempts_count => 2,
      )
      now = flow_model.database_now
      nonce = "source-reset-fault-browser"
      flow = flow_model.create!(
        principal_id: owner.id, status_id: flow_model::STATUS_MODEL::CONTACT_PENDING, step: "contact",
        nonce_digest: flow_model.digest_nonce(nonce), issued_at: now, expires_at: now + 15.minutes,
        entry_method: "telephone", pending_contact_type: "telephone", pending_contact_id: telephone.id,
      )
      issued = TelephoneSignUpOtpIssuer.call(flow: flow, telephone: telephone, session_nonce: nonce)
      observed_consumption = false
      failure =
        lambda do |_name, _started, _finished, _identity, event|
          if event[:name] == "#{telephone_model} Update" && event[:sql].include?("otp_attempts_count")
            observed_consumption = transaction_model.find(issued.transaction.id).otp_consumed_at.present?
            raise ActiveRecord::StatementInvalid, "Telephone Source attempt reset unavailable"
          end
        end

      ActiveSupport::Notifications.subscribed(failure, "sql.active_record") do
        assert_raises(ActiveRecord::StatementInvalid) do
          TelephoneSignUpOtpVerificationCommitter.call(
            flow: flow, telephone: telephone, session_nonce: nonce, code: issued.code,
          )
        end
      end

      assert observed_consumption, "The durable ceremony consumption precedes the independent Source reset"
      assert issued.transaction.reload.otp_consumed_at
      assert_equal 2, telephone.reload.otp_attempts_count
      proof = issued.transaction.attributes.slice("otp_consumed_at", "otp_result_expires_at", "otp_receipt_verifier")
      receipt = TelephoneSignUpOtpVerificationCommitter.call(
        flow: flow, telephone: telephone, session_nonce: nonce, code: issued.code,
      )

      assert_not receipt.success?
      assert_predicate receipt, :verified_evidence?
      assert_equal :already_verified, receipt.status
      assert_equal 2, telephone.reload.otp_attempts_count
      assert_equal proof, issued.transaction.reload.attributes.slice(*proof.keys)
    end

    test "#{surface} Telephone signup late delivery requires the original parent browser destination and generation" do
      owner_model, telephone_model, flow_model, owner_key, status =
        case surface
        when "app" then [Client, ClientTelephone, ClientSignUpFlow, :user_id, ClientStatus::UNVERIFIED_WITH_SIGN_UP]
        when "com" then [Visitor, VisitorTelephone, VisitorSignUpFlow, :visitor_id, VisitorStatus::ACTIVE]
        end
      owner = owner_model.create!(status_id: status)
      telephone = telephone_model.create!(
        owner_key => owner.id, :raw_number => "+12025550141",
        :confirm_policy => true, :otp_attempts_count => 1,
      )
      now = flow_model.database_now
      nonce = "signup-delivery-browser"
      flow = flow_model.create!(
        principal_id: owner.id, status_id: flow_model::STATUS_MODEL::CONTACT_PENDING, step: "contact",
        nonce_digest: flow_model.digest_nonce(nonce), issued_at: now, expires_at: now + 15.minutes,
        entry_method: "telephone", pending_contact_type: "telephone", pending_contact_id: telephone.id,
      )
      issued = TelephoneSignUpOtpIssuer.call(flow: flow, telephone: telephone, session_nonce: nonce)
      arguments = {
        flow: flow,
        telephone: telephone,
        transaction: issued.transaction,
        generation: issued.transaction.otp_generation,
        destination: telephone.number,
        code: issued.code,
      }
      transported = 0
      delivered = TelephoneSignUpOtpDeliveryGuard.call(**arguments) { transported += 1 }

      assert delivered
      assert_equal 1, transported
      [arguments.merge(generation: SecureRandom.uuid),
       arguments.merge(destination: "+12025550199"),].each do |bad|
        assert_not TelephoneSignUpOtpDeliveryGuard.call(**bad) { transported += 1 }
      end
      flow.update!(nonce_digest: flow_model.digest_nonce("another-delivery-browser"))

      assert_not TelephoneSignUpOtpDeliveryGuard.call(**arguments) { transported += 1 }
      assert_equal 1, transported
      assert_equal 1, telephone.reload.otp_attempts_count
      assert_nil issued.transaction.reload.otp_consumed_at
    end

    test "#{surface} Telephone signup issues only ceremony proof and rotates generation without resetting failures" do
      owner_model, telephone_model, flow_model, transaction_model, owner_key, status =
        case surface
        when "app"
          [Client, ClientTelephone, ClientSignUpFlow, ClientTelephoneCeremonyTransaction, :user_id,
           ClientStatus::UNVERIFIED_WITH_SIGN_UP,]
        when "com"
          [Visitor, VisitorTelephone, VisitorSignUpFlow, VisitorTelephoneCeremonyTransaction, :visitor_id,
           VisitorStatus::ACTIVE,]
        end
      owner = owner_model.create!(status_id: status)
      telephone = telephone_model.create!(
        owner_key => owner.id, :raw_number => "+12025550142",
        :confirm_policy => true, :otp_attempts_count => 1,
      )
      now = flow_model.database_now
      nonce = "owned-signup-browser"
      flow = flow_model.create!(
        principal_id: owner.id, status_id: flow_model::STATUS_MODEL::CONTACT_PENDING, step: "contact",
        nonce_digest: flow_model.digest_nonce(nonce), issued_at: now, expires_at: now + 15.minutes,
        entry_method: "telephone", pending_contact_type: "telephone", pending_contact_id: telephone.id,
      )
      original = telephone.attributes.slice("otp_private_key", "otp_counter", "otp_expires_at", "sign_up_otp_context")
      denied = TelephoneSignUpOtpIssuer.call(flow: flow, telephone: telephone, session_nonce: flow.public_id)

      assert_equal :session_mismatch, denied.status
      assert_nil denied.code
      assert_nil denied.transaction
      issued = TelephoneSignUpOtpIssuer.call(flow: flow, telephone: telephone, session_nonce: nonce)

      assert_equal :issued, issued.status
      assert_instance_of transaction_model, issued.transaction
      assert_match(/\A[0-9]{6}\z/, issued.code)
      assert_equal "sign_up", issued.transaction.operation
      assert_equal "sign_up", issued.transaction.purpose
      assert_equal owner.public_id, issued.transaction.actor_ref
      assert_equal telephone.public_id, issued.transaction.telephone_candidate_ref
      assert_equal telephone.number_digest, issued.transaction.normalized_number_digest
      assert_equal flow.expires_at, issued.transaction.expires_at
      assert_equal original, telephone.reload.attributes.slice(*original.keys)
      assert_equal 1, telephone.otp_attempts_count
      generation = issued.transaction.otp_generation
      resend =
        telephone_model.stub(:database_now, telephone.otp_last_sent_at + TelephoneOtpPolicy::SEND_COOLDOWN) do
          TelephoneSignUpOtpIssuer.call(flow: flow, telephone: telephone, session_nonce: nonce)
        end

      assert_equal :issued, resend.status
      assert_equal issued.transaction.id, resend.transaction.id
      assert_not_equal generation, resend.transaction.otp_generation
      assert_equal 1, telephone.reload.otp_attempts_count
      assert_equal original, telephone.attributes.slice(*original.keys)
      delivered = false
      stale = resend.transaction.deliver_telephone_otp!(generation: generation, code: issued.code) { delivered = true }

      assert_not stale
      assert_not delivered
      decision_time = now
      original_sent_at = telephone.otp_last_sent_at
      expired_while_waiting =
        flow_model.stub(:database_now, -> { decision_time }) do
          telephone_model.stub(:database_now, -> { decision_time = flow.expires_at; now }) do
            TelephoneSignUpOtpIssuer.call(flow: flow, telephone: telephone, session_nonce: nonce)
          end
        end

      assert_equal :inactive_flow, expired_while_waiting.status,
                   "The original signup deadline is rechecked after Source lock acquisition"
      assert_equal original_sent_at, telephone.reload.otp_last_sent_at
      assert_equal 1, telephone.otp_attempts_count
      assert_predicate flow.reload, :sign_up_expired?
      denied_after_expiry = TelephoneSignUpOtpIssuer.call(flow: flow, telephone: telephone, session_nonce: nonce)

      assert_equal :inactive_flow, denied_after_expiry.status, "An earlier clock cannot reopen terminal signup"
      assert_nil denied_after_expiry.code
      assert_nil denied_after_expiry.transaction
    end

    test "#{surface} Telephone signup consumes once and bounds receipt retries without another attempt reset" do
      owner_model, telephone_model, flow_model, transaction_model, owner_key, status =
        case surface
        when "app"
          [Client, ClientTelephone, ClientSignUpFlow, ClientTelephoneCeremonyTransaction, :user_id,
           ClientStatus::UNVERIFIED_WITH_SIGN_UP,]
        when "com"
          [Visitor, VisitorTelephone, VisitorSignUpFlow, VisitorTelephoneCeremonyTransaction, :visitor_id,
           VisitorStatus::ACTIVE,]
        end
      owner = owner_model.create!(status_id: status)
      telephone = telephone_model.create!(
        owner_key => owner.id, :raw_number => "+12025550143",
        :confirm_policy => true, :otp_attempts_count => 1,
      )
      now = flow_model.database_now
      nonce = "signup-verify-browser"
      flow = flow_model.create!(
        principal_id: owner.id, status_id: flow_model::STATUS_MODEL::CONTACT_PENDING, step: "contact",
        nonce_digest: flow_model.digest_nonce(nonce), issued_at: now, expires_at: now + 15.minutes,
        entry_method: "telephone", pending_contact_type: "telephone", pending_contact_id: telephone.id,
      )
      original = telephone.attributes.slice("otp_private_key", "otp_counter", "otp_expires_at", "sign_up_otp_context")
      resend = TelephoneSignUpOtpIssuer.call(flow: flow, telephone: telephone, session_nonce: nonce)
      scope = { flow: flow, telephone: telephone, session_nonce: nonce }
      foreign = TelephoneSignUpOtpVerificationCommitter.call(
        **scope.merge(session_nonce: flow.public_id),
        code: resend.code,
      )

      assert_not foreign.success?
      assert_equal :session_mismatch, foreign.status
      assert_equal 1, telephone.reload.otp_attempts_count
      admission_budget = TelephoneOtpVerificationFailureBudget.new
      exhausted =
        TelephoneOtpVerificationFailureBudget.stub(:new, admission_budget) do
          admission_budget.stub(:verify!, :locked) do
            TelephoneSignUpOtpVerificationCommitter.call(**scope, code: resend.code)
          end
        end

      assert_equal :locked, exhausted.status
      assert_nil resend.transaction.reload.otp_consumed_at
      assert_equal 1, telephone.reload.otp_attempts_count
      wrong_code = (resend.code == "000000") ? "000001" : "000000"
      wrong = TelephoneSignUpOtpVerificationCommitter.call(**scope, code: wrong_code)

      assert_equal :invalid_code, wrong.status
      assert_equal 2, telephone.reload.otp_attempts_count
      verified = TelephoneSignUpOtpVerificationCommitter.call(**scope, code: resend.code)

      assert_predicate verified, :success?
      assert_predicate verified, :verified_evidence?
      assert_equal 0, telephone.reload.otp_attempts_count
      assert resend.transaction.reload.otp_consumed_at
      telephone.update!(otp_attempts_count: 1)
      resumed = TelephoneSignUpOtpVerificationCommitter.call(**scope, code: resend.code)

      assert_not resumed.success?, "Retained proof is not another successful verification"
      assert_predicate resumed, :verified_evidence?
      assert_equal :already_verified, resumed.status
      assert_equal 1, telephone.reload.otp_attempts_count, "Receipt reads must not reset subsequent failures"
      assert_equal original, telephone.attributes.slice(*original.keys)
      receipt_now = resend.transaction.otp_result_expires_at - Rational(1, 1_000_000)
      budget = TelephoneOtpVerificationFailureBudget.new
      expired_receipt =
        transaction_model.stub(:database_now, -> { receipt_now }) do
          TelephoneOtpVerificationFailureBudget.stub(:new, budget) do
            budget.stub(:verify!, ->(**) { receipt_now = resend.transaction.otp_result_expires_at; :verified }) do
              TelephoneSignUpOtpVerificationCommitter.call(**scope, code: resend.code)
            end
          end
        end

      assert_not expired_receipt.verified_evidence?, "Budget admission wait cannot extend retained proof"
      assert_equal :result_expired, expired_receipt.status
    end
  end
end
