# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_bulletins
# Database name: org_principal
#
#  id         :bigint           not null, primary key
#  body       :text
#  read_at    :datetime
#  title      :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  public_id  :string(21)       not null
#  staff_id   :bigint           not null
#
# Indexes
#
#  index_operator_bulletins_on_public_id  (public_id) UNIQUE
#  index_operator_bulletins_on_staff_id   (staff_id)
#
# Foreign Keys
#
#  fk_rails_...  (staff_id => operators.id)
#
require "test_helper"

class OperatorBulletinTest < ActiveSupport::TestCase
  fixtures :operators, :operator_statuses

  setup do
    @staff = operators(:one)
    @staff.update!(status_id: OperatorStatus::ACTIVE)
  end

  test "belongs_to staff association" do
    bulletin = OperatorBulletin.create!(
      staff: @staff,
      title: "Test Bulletin",
      body: "Test body content",
    )

    assert_equal @staff, bulletin.staff
  end

  test "title is required" do
    bulletin = OperatorBulletin.new(
      staff: @staff,
      body: "Test body",
    )

    assert_not bulletin.valid?
    assert bulletin.errors.of_kind?(:title, :blank)
  end

  test "public_id is auto-generated" do
    bulletin = OperatorBulletin.create!(
      staff: @staff,
      title: "Test Bulletin",
      body: "Test body",
    )

    assert_predicate bulletin.public_id, :present?
    assert_equal 21, bulletin.public_id.length
  end

  test "public_id is unique" do
    bulletin1 = OperatorBulletin.create!(
      staff: @staff,
      title: "First Bulletin",
      body: "First body",
    )

    # Try to create with same public_id
    bulletin2 = OperatorBulletin.new(
      staff: @staff,
      title: "Second Bulletin",
      body: "Second body",
    )
    bulletin2.public_id = bulletin1.public_id

    assert_not bulletin2.valid?
    assert bulletin2.errors.of_kind?(:public_id, :taken)
  end

  test "unread scope returns only unread bulletins" do
    unread_bulletin = OperatorBulletin.create!(
      staff: @staff,
      title: "Unread",
      body: "Unread body",
    )

    read_bulletin = OperatorBulletin.create!(
      staff: @staff,
      title: "Read",
      body: "Read body",
      read_at: Time.current,
    )

    unread_ids = OperatorBulletin.unread.pluck(:id)

    assert_includes unread_ids, unread_bulletin.id
    assert_not_includes unread_ids, read_bulletin.id
  end

  test "oldest_first scope orders by created_at ascending" do
    old_bulletin = OperatorBulletin.create!(
      staff: @staff,
      title: "Old",
      body: "Old body",
      created_at: 2.days.ago,
    )

    new_bulletin = OperatorBulletin.create!(
      staff: @staff,
      title: "New",
      body: "New body",
      created_at: 1.day.ago,
    )

    bulletins = OperatorBulletin.oldest_first.to_a

    assert_equal old_bulletin, bulletins.first
    assert_equal new_bulletin, bulletins.last
  end

  test "read? returns false for unread bulletins" do
    bulletin = OperatorBulletin.create!(
      staff: @staff,
      title: "Unread",
      body: "Unread body",
    )

    assert_not bulletin.read?
  end

  test "read? returns true for read bulletins" do
    bulletin = OperatorBulletin.create!(
      staff: @staff,
      title: "Read",
      body: "Read body",
      read_at: Time.current,
    )

    assert_predicate bulletin, :read?
  end

  test "mark_as_read! sets read_at timestamp" do
    bulletin = OperatorBulletin.create!(
      staff: @staff,
      title: "Test",
      body: "Test body",
    )

    assert_nil bulletin.read_at

    bulletin.mark_as_read!

    assert_predicate bulletin.read_at, :present?
    assert_predicate bulletin, :read?
  end

  test "mark_as_read! does nothing if already read" do
    original_time = 1.hour.ago
    bulletin = OperatorBulletin.create!(
      staff: @staff,
      title: "Test",
      body: "Test body",
      read_at: original_time,
    )

    bulletin.mark_as_read!

    assert_equal original_time.to_i, bulletin.reload.read_at.to_i
  end

  test "body is optional" do
    bulletin = OperatorBulletin.new(
      staff: @staff,
      title: "No Body",
    )

    assert_predicate bulletin, :valid?
  end

  test "staff_id is required" do
    bulletin = OperatorBulletin.new(
      title: "Test",
      body: "Test body",
    )

    assert_not bulletin.valid?
    assert bulletin.errors.of_kind?(:staff, :blank) || bulletin.errors.of_kind?(:staff, :required)
  end

  test "includes PublicId concern" do
    assert_includes OperatorBulletin.ancestors, PublicId
  end

  test "staff_bulletins association on staff" do
    bulletin1 = OperatorBulletin.create!(
      staff: @staff,
      title: "First",
      body: "First body",
    )

    bulletin2 = OperatorBulletin.create!(
      staff: @staff,
      title: "Second",
      body: "Second body",
    )

    assert_includes @staff.reload.staff_bulletins, bulletin1
    assert_includes @staff.staff_bulletins, bulletin2
  end

  test "dependent behavior on staff destroy" do
    staff = Operator.create!(
      id: 1_000_000_000_000 + SecureRandom.random_number(1_000_000_000), status_id: OperatorStatus::ACTIVE,
    )
    bulletin = OperatorBulletin.create!(
      staff: staff,
      title: "Test",
      body: "Test body",
    )

    assert_difference("OperatorBulletin.count", -1) do
      assert_nothing_raised do
        staff = StrictLoadingAssociationPreloader.for_destruction(staff.reload)
        staff.destroy
      end
    end

    assert_not OperatorBulletin.exists?(bulletin.id)
  end

  test "public_id is a fixed 21-character NanoID" do
    assert_public_id_fixed_length(::OperatorBulletin)
  end
end
