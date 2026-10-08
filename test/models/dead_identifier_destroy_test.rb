# frozen_string_literal: true

require "test_helper"

class DeadIdentifierDestroyTest < ActiveSupport::TestCase
  %w(app com org).each do |realm|
    test "#{realm} physical email destruction atomically archives the database identifier rather than unsaved PII" do
      model, history_model, owner_key, owner =
        case realm
        when "app" then [ClientEmail, ClientEmailHistory, :user_id, clients(:one)]
        when "com" then [VisitorEmail, VisitorEmailHistory, :visitor_id, visitors(:reserved_visitor)]
        when "org" then [OperatorEmail, OperatorEmailHistory, :staff_id, operators(:one)]
        end
      address = "direct-dead-#{SecureRandom.hex(8)}@example.com"
      record = model.create!(owner_key => owner.id, :raw_address => address, :confirm_policy => true)
      record.address = "unsaved-other@example.com"
      count = history_model.count
      record.destroy!

      assert_equal count + 1, history_model.count
      assert_not model.exists?(record.id)
      assert record.dead_email_history.matches_identifier?(address)
      assert_not record.dead_email_history.matches_identifier?("unsaved-other@example.com")
    end

    test "#{realm} telephone destruction atomically archives database PII rather than unsaved PII" do
      model, history_model, owner_key, owner =
        case realm
        when "app" then [ClientTelephone, ClientTelephoneHistory, :user_id, clients(:one)]
        when "com" then [VisitorTelephone, VisitorTelephoneHistory, :visitor_id, visitors(:reserved_visitor)]
        when "org" then [OperatorTelephone, OperatorTelephoneHistory, :staff_id, operators(:one)]
        end
      number = "+819012399912"
      record = model.create!(
        owner_key => owner.id, :raw_number => number, :confirm_policy => true, :confirm_using_mfa => true,
      )
      record.number = "+819012399913"
      count = history_model.count
      record.destroy!

      assert_equal count + 1, history_model.count
      assert_not model.exists?(record.id)
      assert record.dead_telephone_history.matches_identifier?(number)
      assert_not record.dead_telephone_history.matches_identifier?("+819012399913")
    end
  end

  test "a live owner's legal hold refuses ordinary email and telephone destruction without histories" do
    owner = clients(:one)
    ClientRetentionHold.create!(client: owner, hold_kind: "legal_hold", reason_code: "legal_hold")
    email = ClientEmail.create!(user: owner, raw_address: "direct-held@example.com", confirm_policy: true)
    telephone = ClientTelephone.create!(
      user: owner, raw_number: "+819012399914", confirm_policy: true, confirm_using_mfa: true,
    )
    email_count = ClientEmailHistory.count
    telephone_count = ClientTelephoneHistory.count

    assert_raises(ActiveRecord::RecordNotDestroyed) { email.destroy! }
    assert_raises(ActiveRecord::RecordNotDestroyed) { telephone.destroy! }
    assert_equal email_count, ClientEmailHistory.count
    assert_equal telephone_count, ClientTelephoneHistory.count
    assert ClientEmail.exists?(email.id)
    assert ClientTelephone.exists?(telephone.id)
  end

  test "a later email destruction refusal rolls back the archive insertion and exposes no receipt" do
    email = ClientEmail.create!(
      user: clients(:one), raw_address: "archive-rollback@example.com", confirm_policy: true,
    )
    email.undeletable = true
    count = ClientEmailHistory.count

    assert_raises(ActiveRecord::RecordNotDestroyed) { email.destroy! }
    assert_equal count, ClientEmailHistory.count
    assert ClientEmail.exists?(email.id)
    assert_nil email.dead_email_history
  end

  %w(app com).each do |realm|
    test "#{realm} recoverable email and telephone cannot bypass retention through ordinary destruction" do
      email_model, telephone_model, email_history, telephone_history, owner_key, owner =
        case realm
        when "app"
          [ClientEmail, ClientTelephone, ClientEmailHistory, ClientTelephoneHistory, :user_id, clients(:one)]
        when "com"
          [VisitorEmail, VisitorTelephone, VisitorEmailHistory, VisitorTelephoneHistory,
           :visitor_id, visitors(:reserved_visitor),]
        end
      timestamps = { discard_at: 1.day.from_now, purge_eligible_at: 2.days.from_now }
      email = email_model.create!(
        timestamps.merge(
          owner_key => owner.id, :raw_address => "retained-destroy@example.com",
          :confirm_policy => true,
        ),
      )
      telephone = telephone_model.create!(
        timestamps.merge(
          owner_key => owner.id, :raw_number => "+819012399915", :confirm_policy => true, :confirm_using_mfa => true,
        ),
      )
      email_count = email_history.count
      telephone_count = telephone_history.count

      assert_raises(ActiveRecord::RecordNotDestroyed) { email.destroy! }
      assert_raises(ActiveRecord::RecordNotDestroyed) { telephone.destroy! }
      assert_equal email_count, email_history.count
      assert_equal telephone_count, telephone_history.count
      assert email_model.exists?(email.id)
      assert telephone_model.exists?(telephone.id)
    end
  end
end
