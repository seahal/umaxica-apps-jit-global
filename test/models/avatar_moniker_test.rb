# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: avatar_monikers
# Database name: avatar
#
#  id                       :bigint           not null, primary key
#  moniker                  :string           not null
#  valid_from               :datetime         not null
#  valid_to                 :datetime         default(Infinity), not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  avatar_id                :bigint           not null
#
# Indexes
#
#  index_avatar_monikers_on_avatar_id                 (avatar_id) UNIQUE WHERE (valid_to = 'infinity'::timestamp with time zone)
#  index_avatar_monikers_on_avatar_id_and_valid_from  (avatar_id,valid_from DESC)
#
# Foreign Keys
#
#  fk_rails_...  (avatar_id => avatars.id)
#

require "test_helper"

class AvatarMonikerTest < ActiveSupport::TestCase
  fixtures :avatars

  test "accepts the byte-size boundary immediately below and at 128 bytes" do
    below = AvatarMoniker.new(moniker: ("あ\u0300\uFE0F" * 15) + "a\uFE0F\uFE0F")
    boundary = AvatarMoniker.new(moniker: "あ\u0300\uFE0F" * 16)

    below.valid?
    boundary.valid?

    assert_empty below.errors[:moniker]
    assert_equal 127, below.moniker.bytesize
    assert_empty boundary.errors[:moniker]
    assert_equal 128, boundary.moniker.bytesize
  end

  test "rejects the byte-size boundary immediately above 128 bytes" do
    moniker = AvatarMoniker.new(moniker: ("あ\u0300\uFE0F" * 15) + "あ\u0300\u0301\u0302")

    moniker.valid?

    assert_equal 129, moniker.moniker.bytesize
    assert_not_empty moniker.errors[:moniker]
  end

  test "accepts the grapheme boundary immediately below and at 16 clusters" do
    below = AvatarMoniker.new(moniker: "あ" * 15)
    boundary = AvatarMoniker.new(moniker: "あ" * 16)

    below.valid?
    boundary.valid?

    assert_empty below.errors[:moniker]
    assert_empty boundary.errors[:moniker]
  end

  test "rejects the grapheme boundary immediately above 16 clusters" do
    moniker = AvatarMoniker.new(moniker: "あ" * 17)

    moniker.valid?

    assert_not_empty moniker.errors[:moniker]
  end

  test "rejects missing blank and edge-whitespace values without trimming" do
    missing = AvatarMoniker.new(moniker: nil)
    empty = AvatarMoniker.new(moniker: "")
    whitespace = AvatarMoniker.new(moniker: "\u3000\t")
    leading = AvatarMoniker.new(moniker: " name")
    trailing = AvatarMoniker.new(moniker: "name ")

    [missing, empty, whitespace, leading, trailing].each(&:valid?)

    [missing, empty, whitespace, leading, trailing].each do |record|
      assert_not_empty record.errors[:moniker]
    end
    assert_equal " name", leading.moniker
    assert_equal "name ", trailing.moniker
  end

  test "normalizes monikers to NFC before validation" do
    moniker = AvatarMoniker.new(moniker: "e\u0301")

    moniker.valid?

    assert_equal "é", moniker.moniker
  end

  test "rejects malformed UTF-8 and prohibited controls" do
    malformed = AvatarMoniker.new(moniker: "\xFF".dup.force_encoding(Encoding::UTF_8))
    prohibited =
      [
        "\u0000", "\u001F", "\u007F", "\u0085", "\t", "\r", "\n", "\u2028", "\u2029",
        "\uFEFF", "\u200B", "\u061C", "\u200E", "\u200F", "\u202A", "\u202E", "\u2066", "\u2069",
      ].map { |character| AvatarMoniker.new(moniker: "a#{character}b") }

    malformed.valid?
    prohibited.each(&:valid?)

    assert_not_empty malformed.errors[:moniker]
    prohibited.each { |record| assert_not_empty record.errors[:moniker] }
  end

  test "keeps Japanese combining marks emoji ZWJ ZWNJ and variation selectors valid" do
    moniker = AvatarMoniker.new(moniker: "日本 e\u0301 😀 👩‍💻 x\u200Cy あ\uFE0F")

    moniker.valid?

    assert_empty moniker.errors[:moniker]
  end

  test "Avatar exposes the row whose valid_to is infinity even when its valid_from is older" do
    avatar = Avatar.create!(
      active_handle: handles(:one),
      capability: avatar_capabilities(:normal),
      lifecycle_state: avatar_lifecycle_states(:active),
    )

    AvatarMoniker.create!(
      avatar: avatar,
      moniker: "Historical name",
      valid_from: Time.utc(2030, 1, 1),
      valid_to: Time.utc(2031, 1, 1),
    )
    AvatarMoniker.create!(
      avatar: avatar,
      moniker: "Current name",
      valid_from: Time.utc(2025, 1, 1),
    )

    assert_equal "Current name", avatar.reload.moniker
  end

  test "Avatar moniker read fails when no current temporal row exists and has no writer" do
    avatar = Avatar.create!(
      active_handle: handles(:one),
      capability: avatar_capabilities(:normal),
      lifecycle_state: avatar_lifecycle_states(:active),
    )

    assert_raises(ActiveRecord::RecordNotFound) { avatar.moniker }
    assert_not_respond_to avatar, :moniker=
  end

  test "persists an encrypted 128-byte moniker inside the varchar 512 column" do
    avatar = Avatar.create!(
      active_handle: handles(:one),
      capability: avatar_capabilities(:normal),
      lifecycle_state: avatar_lifecycle_states(:active),
    )
    plaintext = "あ\u0300\uFE0F" * 16

    assert_equal 128, plaintext.bytesize
    moniker = AvatarMoniker.new(avatar: avatar, moniker: plaintext, valid_from: Time.current)

    AvatarRecord.connected_to(role: :writing) do
      moniker.save!
      encrypted_value = AvatarMoniker.connection.select_value(
        AvatarMoniker.sanitize_sql_array(["SELECT moniker FROM avatar_monikers WHERE id = ?", moniker.id]), # rubocop:disable I18n/RailsI18n/DecorateString -- Parameterized SQL.
      )

      assert_equal 512, AvatarMoniker.columns_hash.fetch("moniker").limit
      assert_operator encrypted_value.bytesize, :<=, 512
      assert_not_equal plaintext, encrypted_value
      assert_equal plaintext, AvatarMoniker.find(moniker.id).moniker

      historical = AvatarMoniker.create!(
        avatar: avatar,
        moniker: plaintext,
        valid_from: Time.utc(2024, 1, 1),
        valid_to: Time.utc(2024, 1, 2),
      )
      historical_ciphertext = AvatarMoniker.connection.select_value(
        AvatarMoniker.sanitize_sql_array(["SELECT moniker FROM avatar_monikers WHERE id = ?", historical.id]), # rubocop:disable I18n/RailsI18n/DecorateString -- Parameterized SQL.
      )

      assert_not_equal encrypted_value, historical_ciphertext
      assert_equal plaintext, historical.moniker
    end

    moniker_indexes =
      AvatarMoniker.connection.indexes(AvatarMoniker.table_name).select do |index|
        index.columns.include?("moniker")
      end

    assert_empty moniker_indexes
  end

  test "Rails encrypted fixtures persist ciphertext while exposing plaintext through the model" do
    fixture = avatar_monikers(:one)
    encrypted_value = AvatarMoniker.connection.select_value(
      AvatarMoniker.sanitize_sql_array(["SELECT moniker FROM avatar_monikers WHERE id = ?", fixture.id]), # rubocop:disable I18n/RailsI18n/DecorateString -- Parameterized SQL.
    )

    assert ActiveRecord::Encryption.encryptor.encrypted?(encrypted_value)
    assert_not_equal "Moniker One", encrypted_value
    assert_equal "Moniker One", fixture.moniker
  end

  test "database temporal constraint accepts equality and rejects a reversed interval" do
    avatar = avatars(:one)
    boundary = Time.utc(2026, 1, 1)
    equal_interval = AvatarMoniker.create!(
      avatar: avatar,
      moniker: "Finite",
      valid_from: boundary,
      valid_to: boundary,
    )

    assert_predicate equal_interval, :persisted?

    reversed_interval = AvatarMoniker.new(
      avatar: avatar,
      moniker: "Reversed",
      valid_from: boundary + 1.second,
      valid_to: boundary,
    )

    assert_raises(ActiveRecord::StatementInvalid) { reversed_interval.save(validate: false) }
  end
end
