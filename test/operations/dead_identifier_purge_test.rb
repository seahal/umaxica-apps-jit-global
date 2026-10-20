# frozen_string_literal: true

require "test_helper"

class DeadIdentifierPurgeTest < ActiveSupport::TestCase
  test "email purge refuses a changed owner reference even after the previous owner was cached" do
    email = ClientEmail.create!(
      user: clients(:one), raw_address: "cached-owner@example.com", confirm_policy: true,
      created_at: 3.days.ago, discard_at: 2.days.ago, purge_eligible_at: 1.day.ago,
    )
    email = ClientEmail.preload(:user).find(email.id)

    assert_equal clients(:one).id, email.user.id

    email.user_id = clients(:two).id
    error = assert_raises(ArgumentError) { EmailIdentifierPurger.call(record: email) }

    assert_equal "email purge owner mismatch", error.message
    assert ClientEmail.exists?(email.id)
    assert_equal clients(:one).id, email.reload.user_id
  end

  %w(app com org).each do |realm|
    test "#{realm} repeated dead email generates independently salted history rows without reserving the destination" do
      model, history_model, owner, owner_key =
        case realm
        when "app" then [ClientEmail, ClientEmailHistory, clients(:one), :user_id]
        when "com" then [VisitorEmail, VisitorEmailHistory, visitors(:reserved_visitor), :visitor_id]
        when "org" then [OperatorEmail, OperatorEmailHistory, operators(:one), :staff_id]
        end
      owner.update!(discard_at: owner.created_at, purge_eligible_at: owner.created_at) if realm == "org"
      address = "repeated-dead-#{SecureRandom.hex(8)}@example.com"
      histories =
        2.times.map do
          attributes = { owner_key => owner.id,
                         :raw_address => address,
                         :confirm_policy => true,
                         :created_at => 3.days.ago, }
          attributes.merge!(discard_at: 2.days.ago, purge_eligible_at: 1.day.ago) unless realm == "org"
          EmailIdentifierPurger.call(record: model.create!(attributes))
        end

      assert_equal 2, history_model.where(id: histories.map(&:id)).count
      assert_not_equal histories.first.fingerprint, histories.last.fingerprint
      assert histories.first.matches_identifier?(address)
      assert histories.last.matches_identifier?(address)
    end

    test "#{realm} repeated dead telephone generates independently salted history rows " \
         "without reserving the destination" do
      model, history_model, owner, owner_key =
        case realm
        when "app" then [ClientTelephone, ClientTelephoneHistory, clients(:one), :user_id]
        when "com" then [VisitorTelephone, VisitorTelephoneHistory, visitors(:reserved_visitor), :visitor_id]
        when "org" then [OperatorTelephone, OperatorTelephoneHistory, operators(:one), :staff_id]
        end
      owner.update!(discard_at: owner.created_at, purge_eligible_at: owner.created_at) if realm == "org"
      number = "+819012399911"
      histories =
        2.times.map do
          attributes = {
            owner_key => owner.id,
            :raw_number => number,
            :confirm_policy => true,
            :confirm_using_mfa => true,
            :created_at => 3.days.ago,
          }
          attributes.merge!(discard_at: 2.days.ago, purge_eligible_at: 1.day.ago) unless realm == "org"
          TelephoneIdentifierPurger.call(record: model.create!(attributes))
        end

      assert_equal 2, history_model.where(id: histories.map(&:id)).count
      assert_not_equal histories.first.fingerprint, histories.last.fingerprint
      assert histories.first.matches_identifier?(number)
      assert histories.last.matches_identifier?(number)
    end
  end

  test "email purge rejects missing wrong-type and unsaved identifier arguments" do
    [nil, 0, false, "", {}, ClientEmail.new(user: clients(:one), address: "unsaved@example.com")].each do |record|
      assert_raises(ArgumentError) { EmailIdentifierPurger.call(record: record) }
    end
  end

  test "telephone purge rejects missing wrong-type and unsaved identifier arguments" do
    [nil, 0, false, "", {}, ClientTelephone.new(user: clients(:one), number: "+819012399909")].each do |record|
      assert_raises(ArgumentError) { TelephoneIdentifierPurger.call(record: record) }
    end
  end

  %w(app com org).each do |realm|
    test "#{realm} email purge refuses an in-memory owner substitution without deleting Source" do
      model, history_model, owner, replacement_owner, owner_key =
        case realm
        when "app" then [ClientEmail, ClientEmailHistory, clients(:one), clients(:two), :user_id]
        when "com" then [VisitorEmail, VisitorEmailHistory, visitors(:reserved_visitor), Visitor.create!, :visitor_id]
        when "org" then [OperatorEmail, OperatorEmailHistory, operators(:one), operators(:two), :staff_id]
        end
      if realm == "org"
        [owner, replacement_owner].each do |actor|
          actor.update!(discard_at: actor.created_at, purge_eligible_at: actor.created_at)
        end
      end
      attributes = {
        owner_key => owner.id,
        :raw_address => "owner-purge-#{SecureRandom.hex(8)}@example.com",
        :confirm_policy => true,
        :created_at => 3.days.ago,
      }
      attributes.merge!(discard_at: 2.days.ago, purge_eligible_at: 1.day.ago) unless realm == "org"
      record = model.create!(attributes)
      record[owner_key] = replacement_owner.id
      count = history_model.count

      assert_raises(ArgumentError) { EmailIdentifierPurger.call(record: record) }
      assert_equal count, history_model.count
      assert_equal owner.id, model.find(record.id)[owner_key]
    end

    test "#{realm} telephone purge refuses an in-memory owner substitution without deleting Source" do
      model, history_model, owner, replacement_owner, owner_key =
        case realm
        when "app" then [ClientTelephone, ClientTelephoneHistory, clients(:one), clients(:two), :user_id]
        when "com"
          [VisitorTelephone, VisitorTelephoneHistory, visitors(:reserved_visitor), Visitor.create!, :visitor_id]
        when "org" then [OperatorTelephone, OperatorTelephoneHistory, operators(:one), operators(:two), :staff_id]
        end
      if realm == "org"
        [owner, replacement_owner].each do |actor|
          actor.update!(discard_at: actor.created_at, purge_eligible_at: actor.created_at)
        end
      end
      attributes = {
        owner_key => owner.id,
        :raw_number => "+819012399908",
        :confirm_policy => true,
        :confirm_using_mfa => true,
        :created_at => 3.days.ago,
      }
      attributes.merge!(discard_at: 2.days.ago, purge_eligible_at: 1.day.ago) unless realm == "org"
      record = model.create!(attributes)
      record[owner_key] = replacement_owner.id
      count = history_model.count

      assert_raises(ArgumentError) { TelephoneIdentifierPurger.call(record: record) }
      assert_equal count, history_model.count
      assert_equal owner.id, model.find(record.id)[owner_key]
    end
  end

  test "ORG email remains recoverable until owner retention ends and dead email may be reused" do
    owner = operators(:one)
    record = OperatorEmail.create!(staff: owner, raw_address: "org-dead@example.com", confirm_policy: true)
    count = OperatorEmailHistory.where(staff_id: owner.id).count

    assert_raises(ArgumentError) { EmailIdentifierPurger.call(record: record) }
    owner.update!(discard_at: owner.created_at, purge_eligible_at: owner.created_at)
    history = EmailIdentifierPurger.call(record: record)

    assert_equal count + 1, OperatorEmailHistory.where(staff_id: owner.id).count
    assert_not OperatorEmail.exists?(record.id)
    assert history.matches_identifier?("org-dead@example.com")
    assert_nil EmailIdentifierPurger.call(record: record)
    replacement = OperatorEmail.create!(
      staff: operators(:two), raw_address: "org-dead@example.com",
      confirm_policy: true,
    )

    assert_predicate replacement, :persisted?
  end

  test "ORG telephone remains recoverable until owner retention ends and dead telephone may be reused" do
    owner = operators(:one)
    record = OperatorTelephone.create!(
      staff: owner, raw_number: "+819012399903", confirm_policy: true, confirm_using_mfa: true,
    )
    count = OperatorTelephoneHistory.where(staff_id: owner.id).count

    assert_raises(ArgumentError) { TelephoneIdentifierPurger.call(record: record) }
    owner.update!(discard_at: owner.created_at, purge_eligible_at: owner.created_at)
    history = TelephoneIdentifierPurger.call(record: record)

    assert_equal count + 1, OperatorTelephoneHistory.where(staff_id: owner.id).count
    assert_not OperatorTelephone.exists?(record.id)
    assert history.matches_identifier?("+819012399903")
    assert_nil TelephoneIdentifierPurger.call(record: record)
    replacement = OperatorTelephone.create!(
      staff: operators(:two), raw_number: "+819012399903", confirm_policy: true, confirm_using_mfa: true,
    )

    assert_predicate replacement, :persisted?
  end

  test "protected email destruction rolls back history insertion with the live row" do
    record = ClientEmail.create!(
      user: clients(:one), raw_address: "protected-dead@example.com", confirm_policy: true,
      undeletable: true, created_at: 3.days.ago, discard_at: 2.days.ago, purge_eligible_at: 1.day.ago,
    )
    count = ClientEmailHistory.count

    assert_raises(ActiveRecord::RecordNotDestroyed) { EmailIdentifierPurger.call(record: record) }
    assert_equal count, ClientEmailHistory.count
    assert ClientEmail.exists?(record.id)
  end

  test "active legal hold prevents email and telephone history insertion and physical deletion" do
    owner = clients(:one)
    ClientRetentionHold.create!(client: owner, hold_kind: "legal_hold", reason_code: "legal_hold")
    email = ClientEmail.create!(
      user: owner, raw_address: "held-dead@example.com", confirm_policy: true,
      created_at: 3.days.ago, discard_at: 2.days.ago, purge_eligible_at: 1.day.ago,
    )
    telephone = ClientTelephone.create!(
      user: owner, raw_number: "+819012399902", confirm_policy: true,
      confirm_using_mfa: true, created_at: 3.days.ago, discard_at: 2.days.ago, purge_eligible_at: 1.day.ago,
    )
    email_count = ClientEmailHistory.count
    telephone_count = ClientTelephoneHistory.count

    assert_nil EmailIdentifierPurger.call(record: email)
    assert_nil TelephoneIdentifierPurger.call(record: telephone)
    assert_equal email_count, ClientEmailHistory.count
    assert_equal telephone_count, ClientTelephoneHistory.count
    assert ClientEmail.exists?(email.id)
    assert ClientTelephone.exists?(telephone.id)
  end

  [
    [ClientEmail, ClientEmailHistory, :user_id, :clients],
    [VisitorEmail, VisitorEmailHistory, :visitor_id, :visitors],
  ].each do |model, history_model, owner_key, fixture_name|
    test "#{model.name} physical retention purge creates one dead history and permits future reuse" do
      owner = (fixture_name == :clients) ? clients(:one) : visitors(:reserved_visitor)
      record = model.create!(
        owner_key => owner.id, :raw_address => "dead-email-#{SecureRandom.hex(5)}@example.com",
        :confirm_policy => true, :created_at => 3.days.ago, :discard_at => 2.days.ago, :purge_eligible_at => 1.day.ago,
      )
      address = record.address
      digest = record.address_digest
      count = history_model.where(owner_key => owner.id).count
      history = EmailIdentifierPurger.call(record: record)

      assert_equal count + 1, history_model.where(owner_key => owner.id).count
      assert_not model.exists?(record.id)
      assert history.matches_identifier?(address)
      assert_not_equal digest, history.fingerprint
      assert_nil EmailIdentifierPurger.call(record: record)
      assert_equal count + 1, history_model.where(owner_key => owner.id).count
      replacement = model.create!(owner_key => owner.id, :raw_address => address, :confirm_policy => true)

      assert_predicate replacement, :persisted?
      assert_raises(ActiveRecord::ReadOnlyRecord) { history.update!(detached_at: Time.current) }
    end

    test "#{model.name} live and logically deleted retained email never creates dead history" do
      owner = (fixture_name == :clients) ? clients(:one) : visitors(:reserved_visitor)
      record = model.create!(
        owner_key => owner.id, :raw_address => "live-email-#{SecureRandom.hex(5)}@example.com",
        :confirm_policy => true,
      )
      count = history_model.where(owner_key => owner.id).count

      assert_raises(ArgumentError) { EmailIdentifierPurger.call(record: record) }
      record.discard_now!(purge_after: 1.day)
      assert_raises(ArgumentError) { EmailIdentifierPurger.call(record: record) }
      assert_equal count, history_model.where(owner_key => owner.id).count
      assert model.exists?(record.id)
    end
  end

  [
    [ClientTelephone, ClientTelephoneHistory, :user_id, :clients],
    [VisitorTelephone, VisitorTelephoneHistory, :visitor_id, :visitors],
  ].each do |model, history_model, owner_key, fixture_name|
    test "#{model.name} physical retention purge creates dead telephone history without lookup material" do
      owner = (fixture_name == :clients) ? clients(:one) : visitors(:reserved_visitor)
      record = model.create!(
        owner_key => owner.id, :raw_number => "+819012399901", :confirm_policy => true,
        :confirm_using_mfa => true, :created_at => 3.days.ago,
        :discard_at => 2.days.ago, :purge_eligible_at => 1.day.ago,
      )
      number = record.number
      count = history_model.where(owner_key => owner.id).count
      history = TelephoneIdentifierPurger.call(record: record)

      assert_equal count + 1, history_model.where(owner_key => owner.id).count
      assert_not model.exists?(record.id)
      assert history.matches_identifier?(number)
      assert_not history.attributes.values.include?(number)
      assert_nil TelephoneIdentifierPurger.call(record: record)
      assert_equal count + 1, history_model.where(owner_key => owner.id).count
      replacement = model.create!(
        owner_key => owner.id, :raw_number => number, :confirm_policy => true,
        :confirm_using_mfa => true,
      )

      assert_predicate replacement, :persisted?
    end
  end
end
