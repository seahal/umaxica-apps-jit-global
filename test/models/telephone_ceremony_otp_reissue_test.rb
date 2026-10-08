# frozen_string_literal: true

require "test_helper"

class TelephoneCeremonyOtpReissueTest < ActiveSupport::TestCase
  [ClientTelephoneCeremonyTransaction, VisitorTelephoneCeremonyTransaction,
   OperatorTelephoneCeremonyTransaction,].each do |model|
    test "#{model.name} reissue rotates its generation without extending either deadline" do
      transaction = model.create_transaction!(
        actor_ref: "actor", session_ref: "browser", operation: "registration", telephone_candidate_ref: "candidate",
      )
      original_code = transaction.issue_telephone_otp!(purpose: "credential_registration")
      generation = transaction.otp_generation
      deadline = transaction.otp_expires_at
      parent_deadline = transaction.expires_at
      later = transaction.class.database_now + 1.second
      code = nil
      model.stub(:database_now, later) { code = transaction.reissue_telephone_otp! }
      replacement_generation = transaction.reload.otp_generation

      assert_not_equal generation, replacement_generation
      assert_equal deadline, transaction.otp_expires_at
      assert_equal parent_deadline, transaction.expires_at
      assert_not transaction.deliver_telephone_otp!(generation: generation, code: original_code) { true }
      assert transaction.deliver_telephone_otp!(generation: replacement_generation, code: code) { true }
    end

    %i(expired consumed cancelled).each do |terminal|
      test "#{model.name} reissue cannot revive #{terminal} proof" do
        transaction = model.create_transaction!(
          actor_ref: "actor", session_ref: "browser", operation: "registration", telephone_candidate_ref: "candidate",
        )
        code = transaction.issue_telephone_otp!(purpose: "credential_registration")
        case terminal
        when :expired
          transaction.update!(otp_expires_at: model.database_now - Rational(1, 1_000_000))
        when :consumed

          assert transaction.verify_telephone_otp!(
            code: code, purpose: "credential_registration", actor_ref: "actor", session_ref: "browser",
            operation: "registration", candidate_ref: "candidate",
          )
        when :cancelled

          assert transaction.cancel_telephone_otp!
        end
        original = transaction.reload.attributes

        assert_raises(ArgumentError) { transaction.reissue_telephone_otp! }
        unchanged = original == transaction.reload.attributes

        assert unchanged
      end
    end
  end
end
