# frozen_string_literal: true

require "test_helper"

class DeadIdentifierRetentionTest < ActiveJob::TestCase
  %w(app com).each do |realm|
    test "#{realm} a longer retained Contact prevents a false account shredding receipt" do
      owner_model, email_model, email_history, owner_key, occurrence_model =
        case realm
        when "app" then [Client, ClientEmail, ClientEmailHistory, :user_id, ClientOccurrence]
        when "com" then [Visitor, VisitorEmail, VisitorEmailHistory, :visitor_id, VisitorOccurrence]
        end
      owner = owner_model.create!(created_at: 4.days.ago, discard_at: 2.days.ago, purge_eligible_at: 1.day.ago)
      email = email_model.create!(
        owner_key => owner.id, :raw_address => "retained-contact-#{SecureRandom.hex(8)}@example.test",
        :confirm_policy => true, :created_at => 3.days.ago, :discard_at => 2.days.ago,
        :purge_eligible_at => 1.day.from_now,
      )
      deadline = email.reload.purge_eligible_at

      RetentionPurgeJob.perform_now

      assert_nil owner.reload.terminated_at
      assert email_model.exists?(email.id)
      assert_equal deadline, email.reload.purge_eligible_at
      assert_empty email_history.where(owner_key => owner.id)
      assert_not occurrence_model.where(event_type: "withdrawal.shredded")
        .exists?(["context ->> 'subject_public_id' = ?", owner.public_id])

      after_deadline = deadline + 1.second
      owner_model.stub(:database_now, after_deadline) do
        email_model.stub(:database_now, after_deadline) { RetentionPurgeJob.perform_now }
      end

      assert owner.reload.terminated_at
      assert_not email_model.exists?(email.id)
      assert_equal 1, email_history.where(owner_key => owner.id).count
    end

    test "#{realm} due account collection archives original identifiers before marking retirement complete" do
      owner_model, email_model, telephone_model, email_history, telephone_history, owner_key =
        case realm
        when "app"
          [Client, ClientEmail, ClientTelephone, ClientEmailHistory, ClientTelephoneHistory, :user_id]
        when "com"
          [Visitor, VisitorEmail, VisitorTelephone, VisitorEmailHistory, VisitorTelephoneHistory, :visitor_id]
        end
      owner = owner_model.create!(created_at: 4.days.ago, discard_at: 2.days.ago, purge_eligible_at: 1.day.ago)
      original_address = "due-account-#{SecureRandom.hex(8)}@example.test"
      original_number = "+819012399930"
      email = email_model.create!(
        owner_key => owner.id, :raw_address => original_address, :confirm_policy => true, :created_at => 3.days.ago,
      )
      telephone = telephone_model.create!(
        owner_key => owner.id, :raw_number => original_number, :confirm_policy => true,
        :confirm_using_mfa => true, :created_at => 3.days.ago,
      )

      RetentionPurgeJob.perform_now

      assert owner.reload.terminated_at
      assert owner_model.exists?(owner.id)
      assert_not email_model.exists?(email.id)
      assert_not telephone_model.exists?(telephone.id)
      assert email_history.where(owner_key => owner.id).sole.matches_identifier?(original_address)
      assert telephone_history.where(owner_key => owner.id).sole.matches_identifier?(original_number)
    end
  end

  test "protected Operator email refuses whole erasure without removing prior history or peer identifiers" do
    operator = Operator.create!
    first_email = OperatorEmail.create!(
      staff: operator, raw_address: "earlier-erasure-#{SecureRandom.hex(8)}@example.test", confirm_policy: true,
    )
    email = OperatorEmail.create!(
      staff: operator, raw_address: "protected-erasure-#{SecureRandom.hex(8)}@example.test",
      confirm_policy: true, undeletable: true,
    )
    telephone = OperatorTelephone.create!(
      staff: operator, raw_number: "+819012399905", confirm_policy: true, confirm_using_mfa: true,
    )
    prior_history = OperatorEmailHistory.create!(
      staff: operator, fingerprint: "prior-protected-fingerprint", attached_at: 3.days.ago,
      detached_at: 2.days.ago, created_at: 2.days.ago,
    )
    operator.update_columns(discard_at: 1.hour.ago, purge_eligible_at: 1.hour.ago)

    assert_raises(ActiveRecord::RecordNotDestroyed) { RetentionPurgeJob.perform_now }
    assert Operator.exists?(operator.id)
    assert OperatorEmail.exists?(first_email.id)
    assert OperatorEmail.exists?(email.id)
    assert OperatorTelephone.exists?(telephone.id)
    assert OperatorEmailHistory.exists?(prior_history.id)
    assert_equal 1, OperatorEmailHistory.where(staff_id: operator.id).count
    assert_empty OperatorTelephoneHistory.where(staff_id: operator.id)
  end

  test "irreversible due Operator erasure removes its dead histories and live identifiers atomically" do
    operator = Operator.create!
    email = OperatorEmail.create!(
      staff: operator, raw_address: "erasure-#{SecureRandom.hex(8)}@example.test", confirm_policy: true,
    )
    telephone = OperatorTelephone.create!(
      staff: operator, raw_number: "+819012399904", confirm_policy: true, confirm_using_mfa: true,
    )
    prior_history = OperatorEmailHistory.create!(
      staff: operator, fingerprint: "prior-dead-fingerprint", attached_at: 3.days.ago,
      detached_at: 2.days.ago, created_at: 2.days.ago,
    )
    operator.update_columns(discard_at: 1.hour.ago, purge_eligible_at: 1.hour.ago)

    RetentionPurgeJob.perform_now

    assert_not Operator.exists?(operator.id)
    assert_not OperatorEmail.exists?(email.id)
    assert_not OperatorTelephone.exists?(telephone.id)
    assert_not OperatorEmailHistory.exists?(prior_history.id)
    assert_empty OperatorEmailHistory.where(staff_id: operator.id)
    assert_empty OperatorTelephoneHistory.where(staff_id: operator.id)
  end

  test "retention collection records dead email and telephone history before deleting source rows" do
    owner = clients(:one)
    email = ClientEmail.create!(
      user: owner, raw_address: "retention-dead@example.com", confirm_policy: true,
      created_at: 3.days.ago, discard_at: 2.days.ago, purge_eligible_at: 1.day.ago,
    )
    telephone = ClientTelephone.create!(
      user: owner, raw_number: "+819012399903", confirm_policy: true,
      confirm_using_mfa: true, created_at: 3.days.ago, discard_at: 2.days.ago, purge_eligible_at: 1.day.ago,
    )
    email_count = ClientEmailHistory.where(user_id: owner.id).count
    telephone_count = ClientTelephoneHistory.where(user_id: owner.id).count
    RetentionPurgeJob.perform_now

    assert_not ClientEmail.exists?(email.id)
    assert_not ClientTelephone.exists?(telephone.id)
    assert_equal email_count + 1, ClientEmailHistory.where(user_id: owner.id).count
    assert_equal telephone_count + 1, ClientTelephoneHistory.where(user_id: owner.id).count
  end
end
