# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_bulletins
# Database name: app_principal
#
#  id         :bigint           not null, primary key
#  body       :text
#  read_at    :datetime
#  title      :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  public_id  :string(21)       not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_client_bulletins_on_public_id  (public_id) UNIQUE
#  index_client_bulletins_on_user_id    (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => clients.id)
#
require "test_helper"

class ClientBulletinTest < ActiveSupport::TestCase
  fixtures :clients, :client_statuses

  setup do
    @user = clients(:one)
    @user.update!(status_id: ClientStatus::VERIFIED_WITH_SIGN_UP)
  end

  test "belongs_to user association" do
    bulletin = ClientBulletin.create!(
      user: @user,
      title: "Test Bulletin",
      body: "Test body content",
    )

    assert_equal @user, bulletin.user
  end

  test "title is required" do
    bulletin = ClientBulletin.new(
      user: @user,
      body: "Test body",
    )

    assert_not bulletin.valid?
    assert bulletin.errors.of_kind?(:title, :blank)
  end

  test "public_id is auto-generated" do
    bulletin = ClientBulletin.create!(
      user: @user,
      title: "Test Bulletin",
      body: "Test body",
    )

    assert_predicate bulletin.public_id, :present?
    assert_equal 21, bulletin.public_id.length
  end

  test "retries only a collision on the public_id unique index" do
    existing = ClientBulletin.create!(user: @user, title: "Existing")
    generated = [existing.public_id, "freshpublicid12345678"]

    Nanoid.stub(:generate, ->(**_args) { generated.shift }) do
      bulletin = ClientBulletin.new(user: @user, title: "Retried")
      bulletin.save!(validate: false)

      assert_equal "freshpublicid12345678", bulletin.public_id
    end
  end

  test "stops after the bounded public_id collision retry limit" do
    existing = ClientBulletin.create!(user: @user, title: "Existing")
    generated = Array.new(PublicId::MAX_COLLISION_RETRIES + 1, existing.public_id)

    Nanoid.stub(:generate, ->(**_args) { generated.shift }) do
      bulletin = ClientBulletin.new(user: @user, title: "Retry limit")

      assert_raises(ActiveRecord::RecordNotUnique) { bulletin.save!(validate: false) }
      assert_empty generated
    end
  end

  test "does not regenerate a caller-supplied public_id after a collision" do
    existing = ClientBulletin.create!(user: @user, title: "Existing").public_id
    generated = ["should-not-be-used"]

    Nanoid.stub(:generate, ->(**_args) { generated.shift }) do
      bulletin = ClientBulletin.new(user: @user, title: "Supplied", public_id: existing)

      assert_raises(ActiveRecord::RecordNotUnique) { bulletin.save!(validate: false) }
      assert_equal existing, bulletin.public_id
      assert_equal ["should-not-be-used"], generated
    end
  end

  test "public_id is unique" do
    bulletin1 = ClientBulletin.create!(
      user: @user,
      title: "First Bulletin",
      body: "First body",
    )

    # Try to create with same public_id
    bulletin2 = ClientBulletin.new(
      user: @user,
      title: "Second Bulletin",
      body: "Second body",
    )
    bulletin2.public_id = bulletin1.public_id

    assert_not bulletin2.valid?
    assert bulletin2.errors.of_kind?(:public_id, :taken)
  end

  test "unread scope returns only unread bulletins" do
    unread_bulletin = ClientBulletin.create!(
      user: @user,
      title: "Unread",
      body: "Unread body",
    )

    read_bulletin = ClientBulletin.create!(
      user: @user,
      title: "Read",
      body: "Read body",
      read_at: Time.current,
    )

    unread_ids = ClientBulletin.unread.pluck(:id)

    assert_includes unread_ids, unread_bulletin.id
    assert_not_includes unread_ids, read_bulletin.id
  end

  test "oldest_first scope orders by created_at ascending" do
    old_bulletin = ClientBulletin.create!(
      user: @user,
      title: "Old",
      body: "Old body",
      created_at: 2.days.ago,
    )

    new_bulletin = ClientBulletin.create!(
      user: @user,
      title: "New",
      body: "New body",
      created_at: 1.day.ago,
    )

    bulletins = ClientBulletin.oldest_first.to_a

    assert_equal old_bulletin, bulletins.first
    assert_equal new_bulletin, bulletins.last
  end

  test "read? returns false for unread bulletins" do
    bulletin = ClientBulletin.create!(
      user: @user,
      title: "Unread",
      body: "Unread body",
    )

    assert_not bulletin.read?
  end

  test "read? returns true for read bulletins" do
    bulletin = ClientBulletin.create!(
      user: @user,
      title: "Read",
      body: "Read body",
      read_at: Time.current,
    )

    assert_predicate bulletin, :read?
  end

  test "mark_as_read! sets read_at timestamp" do
    bulletin = ClientBulletin.create!(
      user: @user,
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
    bulletin = ClientBulletin.create!(
      user: @user,
      title: "Test",
      body: "Test body",
      read_at: original_time,
    )

    bulletin.mark_as_read!

    assert_equal original_time.to_i, bulletin.reload.read_at.to_i
  end

  test "body is optional" do
    bulletin = ClientBulletin.new(
      user: @user,
      title: "No Body",
    )

    assert_predicate bulletin, :valid?
  end

  test "user_id is required" do
    bulletin = ClientBulletin.new(
      title: "Test",
      body: "Test body",
    )

    assert_not bulletin.valid?
    assert bulletin.errors.of_kind?(:user, :blank) || bulletin.errors.of_kind?(:user, :required)
  end

  test "includes PublicId concern" do
    assert_includes ClientBulletin.ancestors, PublicId
  end

  test "client_bulletins association on user" do
    bulletin1 = ClientBulletin.create!(
      user: @user,
      title: "First",
      body: "First body",
    )

    bulletin2 = ClientBulletin.create!(
      user: @user,
      title: "Second",
      body: "Second body",
    )

    assert_includes @user.reload.client_bulletins, bulletin1
    assert_includes @user.client_bulletins, bulletin2
  end

  test "dependent behavior on user destroy" do
    ClientBulletin.create!(
      user: @user,
      title: "Test",
      body: "Test body",
    )

    # Bulletins should not prevent user deletion
    assert_nothing_raised do
      operation = -> { @user.destroy }
      defined?(Prosopite) ? Prosopite.pause(&operation) : operation.call
    end
  end

  test "public_id is a fixed 21-character NanoID" do
    assert_public_id_fixed_length(::ClientBulletin)
  end
end
