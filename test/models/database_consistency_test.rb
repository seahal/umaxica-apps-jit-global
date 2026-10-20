# typed: false
# frozen_string_literal: true

require "test_helper"

# Test suite to verify database consistency improvements
# Tests for uniqueness, presence, and foreign key validations
class DatabaseConsistencyTest < ActiveSupport::TestCase
  fixtures :clients, :client_statuses, :client_occurrence_statuses, :zip_occurrence_statuses

  setup do
    I18n.locale = I18n.default_locale # rubocop:disable Rails/I18nLocaleAssignment
  end

  # Test PublicId concern validations
  test "ClientEmail requires unique public_id" do
    email = ClientEmail.new(
      address: "test@example.com",
      user_id: clients(:one).id,
      public_id: "test_public_id_12345x",
    )

    assert_predicate email, :valid?

    # Try to create another with same public_id (requires first to be saved if using new logic,
    # but here distinct instances)
    # The first one 'email' is just new. It is NOT in DB.
    # So duplicate IS valid unless we save 'email' first.
    email.save!

    duplicate = ClientEmail.new(
      address: "other@example.com",
      user_id: clients(:one).id,
      public_id: "test_public_id_12345x",
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:public_id], "はすでに存在します"
  end

  test "ClientEmail auto-generates public_id when nil" do
    email = ClientEmail.new(
      address: "test@example.com",
      user_id: clients(:one).id,
      public_id: nil,
    )
    # PublicId concern auto-generates public_id before validation on create
    email.valid?

    assert_not_nil email.public_id
    assert_equal 21, email.public_id.length
  end

  # Test Preference jti uniqueness
  test "AppPreference requires unique jti" do
    AppPreference.create!(
      jti: "unique_jti_123",
      status_id: AppPreferenceStatus::NOTHING,
    )

    pref2 = AppPreference.new(
      jti: "unique_jti_123",
      status_id: AppPreferenceStatus::NOTHING,
    )

    assert_not pref2.valid?
    assert_includes pref2.errors[:jti], "はすでに存在します"
  end

  # Test Occurrence composite uniqueness
  test "ClientZipOccurrence requires unique combination of user_occurrence_id and zip_occurrence_id" do
    user_occ = ClientOccurrence.first || ClientOccurrence.create!(
      body: "user_occ_#{SecureRandom.hex(6)}",
      status_id: ClientOccurrenceStatus::NOTHING,
    )
    zip_occ = ZipOccurrence.first || ZipOccurrence.create!(
      body: "zip_#{SecureRandom.hex(4)}",
      status_id: ZipOccurrenceStatus::NOTHING,
    )

    ClientZipOccurrence.create!(
      user_occurrence_id: user_occ.id,
      zip_occurrence_id: zip_occ.id,
    )

    # Try to create duplicate
    occurrence2 = ClientZipOccurrence.new(
      user_occurrence_id: user_occ.id,
      zip_occurrence_id: zip_occ.id,
    )

    assert_not occurrence2.valid?
    assert_includes occurrence2.errors[:user_occurrence_id], "はすでに存在します"
  end

  # Test belongs_to presence validation
  test "ClientEmail requires user association" do
    email = ClientEmail.new(
      address: "test@example.com",
      public_id: "test_public_id",
      user_id: nil,
    )
    # Note: before_validation sets default user_id, so we test after that
    email.user_id = nil
    email.valid?

    assert_not email.valid?
    assert_includes email.errors[:user], "を入力してください"
  end

  test "OperatorNotificationRecord requires operator association" do
    notification = OperatorNotificationRecord.new(
      public_id: SecureRandom.uuid,
      staff_id: nil,
    )

    assert_not notification.valid?
    assert_includes notification.errors[:operator], "を入力してください"
  end
end
