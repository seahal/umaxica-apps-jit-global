# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_passkeys
# Database name: app_zenith
#
#  id                       :bigint           not null, primary key
#  aaguid                   :uuid
#  authenticator_attachment :string
#  backup_eligible          :boolean
#  backup_state             :boolean
#  description              :string           default(""), not null
#  discard_at             :datetime         default(Infinity), not null
#  last_used_at             :datetime
#  metadata_source          :string
#  provider_name            :string
#  public_key               :text             not null
#  purge_eligible_at                :datetime         default(Infinity), not null
#  sign_count               :bigint           default(0), not null
#  transports               :jsonb
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  external_id              :uuid             not null
#  public_id                :string(21)
#  status_id                :bigint           default(1), not null
#  user_id                  :bigint           not null
#  webauthn_id              :string           default(""), not null
#
# Indexes
#
#  index_client_passkeys_on_discard_at    (discard_at)
#  index_client_passkeys_on_public_id       (public_id) UNIQUE
#  index_client_passkeys_on_purge_eligible_at       (purge_eligible_at)
#  index_client_passkeys_on_status_id       (status_id)
#  index_client_passkeys_on_webauthn_id     (webauthn_id) UNIQUE
#  index_user_identity_passkeys_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (status_id => client_passkey_statuses.id)
#  fk_rails_...  (user_id => clients.id)
#

require "test_helper"

class ClientPasskeyTest < ActiveSupport::TestCase
  def setup
    ClientEmailStatus.find_or_create_by!(id: ClientEmailStatus::VERIFIED)
    @user = Client.create!(public_id: "u_#{SecureRandom.hex(8)}", status_id: ClientStatus::NOTHING)
    ClientEmail.create!(
      user: @user,
      address: "passkey-model-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    @passkey = ClientPasskey.new(
      user: @user,
      webauthn_id: SecureRandom.uuid,
      external_id: SecureRandom.uuid,
      public_key: "test-key",
      description: "My Passkey",
      sign_count: 0,
    )
  end

  test "should be valid" do
    assert_predicate @passkey, :valid?
  end

  test "defaults status_id to active" do
    passkey = ClientPasskey.new(user: @user, webauthn_id: "id3", public_key: "key3")

    assert_equal ClientPasskeyStatus::ACTIVE, passkey.status_id
  end

  test "database default status_id matches active status" do
    default = ClientPasskey.columns.find { |column| column.name == "status_id" }.default

    assert_equal ClientPasskeyStatus::ACTIVE, default.to_i
  end

  test "repairs missing active status before create" do
    ClientPasskeyStatus.where(id: ClientPasskeyStatus::ACTIVE).delete_all

    passkey = ClientPasskey.new(
      user: @user,
      webauthn_id: "repair-test",
      public_key: "repair-key",
      description: "Repair Test",
    )

    assert_difference -> { ClientPasskeyStatus.where(id: ClientPasskeyStatus::ACTIVE).count }, 1 do
      assert_difference("ClientPasskey.count", 1) do
        passkey.save!
      end
    end

    assert_equal ClientPasskeyStatus::ACTIVE, passkey.status_id
  end

  test "status association uses status_id" do
    status = ClientPasskeyStatus.find(ClientPasskeyStatus::ACTIVE)
    @passkey.status = status
    @passkey.save!

    assert_equal status, @passkey.reload.status
    assert_equal status.id, @passkey.status_id
  end

  test "should require webauthn_id and public_key" do
    @passkey.webauthn_id = nil

    assert_not @passkey.valid?
    @passkey.webauthn_id = "test-id"

    @passkey.public_key = nil

    assert_not @passkey.valid?
  end

  test "should set default sign_count and description" do
    passkey = ClientPasskey.new(user: @user, webauthn_id: "id2", public_key: "key2")
    passkey.save # trigger callback

    assert_not_nil passkey.external_id
    assert_equal 0, passkey.sign_count
    assert_not_nil passkey.description
  end

  test "should validate uniqueness of webauthn_id" do
    @passkey.save!
    duplicate = @passkey.dup

    assert_not duplicate.valid?
  end

  test "db unique index rejects duplicate webauthn_id" do
    @passkey.save!

    now = Time.current
    duplicate_row = {
      user_id: @user.id,
      webauthn_id: @passkey.webauthn_id,
      external_id: SecureRandom.uuid,
      public_key: "duplicate-key",
      description: "Duplicate Passkey",
      sign_count: 0,
      status_id: ClientPasskeyStatus::ACTIVE,
      public_id: SecureRandom.urlsafe_base64(16)[0, 21],
      created_at: now,
      updated_at: now,
    }

    connection = ClientPasskey.connection
    insert_sql = <<~SQL.squish
      INSERT INTO #{ClientPasskey.quoted_table_name}
        (user_id, webauthn_id, external_id, public_key, description, sign_count,
         status_id, public_id, created_at, updated_at)
      VALUES
        (#{duplicate_row[:user_id]},
         #{connection.quote(duplicate_row[:webauthn_id])},
         #{connection.quote(duplicate_row[:external_id])},
         #{connection.quote(duplicate_row[:public_key])},
         #{connection.quote(duplicate_row[:description])},
         #{duplicate_row[:sign_count]},
         #{duplicate_row[:status_id]},
         #{connection.quote(duplicate_row[:public_id])},
         #{connection.quote(duplicate_row[:created_at])},
         #{connection.quote(duplicate_row[:updated_at])})
    SQL

    assert_raises(ActiveRecord::RecordNotUnique) do
      connection.insert(insert_sql)
    end
  end

  test "enforces maximum passkeys per user" do
    Prosopite.pause do
      ClientPasskey::MAX_PASSKEYS_PER_USER.times do |i|
        ClientPasskey.create!(
          user: @user,
          webauthn_id: SecureRandom.uuid,
          external_id: SecureRandom.uuid,
          public_key: "test-key-#{i}",
          description: "Key #{i}",
        )
      end
    end

    extra_passkey = ClientPasskey.new(
      user: @user,
      webauthn_id: SecureRandom.uuid,
      external_id: SecureRandom.uuid,
      public_key: "overflow-key",
      description: "Overflow key",
    )

    assert_not extra_passkey.valid?
    assert_includes extra_passkey.errors[:base], "exceeds maximum passkeys per user (#{ClientPasskey::MAX_PASSKEYS_PER_USER})"
  end

  test "description is invalid when blank" do
    @passkey.description = ""
    @passkey.define_singleton_method(:set_defaults) { } # Skip callback to test validation

    assert_not @passkey.valid?
    assert_not_empty @passkey.errors[:description]
  end

  test "sign_count cannot be negative" do
    @passkey.sign_count = -1

    assert_not @passkey.valid?
    assert_not_empty @passkey.errors[:sign_count]
  end

  test "association deletion: destroys when user is destroyed" do
    @passkey.save!
    @user.destroy
    assert_raise(ActiveRecord::RecordNotFound) { @passkey.reload }
  end

  test "is valid on create when user has no verified recovery identity" do
    user_without_identity = Client.create!(public_id: "u_#{SecureRandom.hex(8)}", status_id: ClientStatus::NOTHING)
    passkey = ClientPasskey.new(
      user: user_without_identity,
      webauthn_id: SecureRandom.uuid,
      external_id: SecureRandom.uuid,
      public_key: "test-key",
      description: "No Identity",
      sign_count: 0,
    )

    assert_predicate passkey, :valid?
  end
end
