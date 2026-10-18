# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_secret_credentials
# Database name: org_principal
#
#  id                              :bigint           not null, primary key
#  consumed_at                     :datetime
#  delivery_method                 :string
#  discard_at                    :datetime         default(Infinity), not null
#  failure_count                   :integer          default(0), not null
#  issued_at                       :datetime
#  issued_by_ref                   :string
#  issued_by_type                  :string
#  last_failed_at                  :datetime
#  last_used_at                    :datetime
#  locked_at                       :datetime
#  lookup_digest                   :string
#  max_failures                    :integer
#  max_uses                        :integer
#  name                            :string           not null
#  not_before_at                   :datetime
#  password_digest                 :string
#  purge_eligible_at                       :datetime         default(Infinity), not null
#  revoked_at                      :datetime
#  safe_prefix                     :string
#  scope                           :string
#  secret_kind                     :string
#  usage_policy                    :string
#  use_count                       :integer          default(0), not null
#  created_at                      :datetime         not null
#  updated_at                      :datetime         not null
#  issued_by_id                    :bigint
#  public_id                       :string(21)       not null
#  staff_id                        :bigint           not null
#  staff_identity_secret_status_id :bigint           default(1), not null
#  staff_secret_kind_id            :bigint           default(2), not null
#
# Indexes
#
#  idx_on_staff_identity_secret_status_id_1e2bab9ca1          (staff_identity_secret_status_id)
#  index_operator_secret_credentials_on_lookup_digest         (lookup_digest)
#  index_operator_secret_credentials_on_public_id             (public_id) UNIQUE
#  index_operator_secret_credentials_on_staff_id              (staff_id)
#  index_operator_secret_credentials_on_staff_secret_kind_id  (staff_secret_kind_id)
#
# Foreign Keys
#
#  fk_rails_...                              (staff_id => operators.id)
#  fk_rails_...                              (staff_identity_secret_status_id => operator_secret_credential_statuses.id)
#  fk_staff_secrets_on_staff_secret_kind_id  (staff_secret_kind_id => operator_secret_credential_kinds.id)
#

require "test_helper"

class OperatorSecretCredentialTest < ActiveSupport::TestCase
  fixtures :operators, :operator_secret_credential_statuses, :operator_secret_credential_kinds

  setup do
    # Set up OperatorSecretCredentialKind records
    OperatorSecretCredentialKind.find_or_create_by!(id: OperatorSecretCredentialKind::NOTHING)
    OperatorSecretCredentialKind.find_or_create_by!(id: OperatorSecretCredentialKind::LOGIN)

    @staff = Operator.find_by!(public_id: "BCDE2345FGHJ67KM")
  end

  test "allows up to the maximum number of secret_credentials per staff" do
    Prosopite.pause do
      OperatorSecretCredential::MAX_SECRETS_PER_STAFF.times do
        create_secret_credential!
      end
    end

    assert_equal OperatorSecretCredential::MAX_SECRETS_PER_STAFF,
                 OperatorSecretCredential.where(staff: @staff).count
  end

  test "rejects creating more than the maximum secret_credentials per staff" do
    Prosopite.pause { OperatorSecretCredential::MAX_SECRETS_PER_STAFF.times { create_secret_credential! } }

    assert_raises(ActiveRecord::RecordInvalid) { create_secret_credential! }
  end

  test "issue! returns raw secret_credential and persists a digest" do
    record, raw_secret_credential = OperatorSecretCredential.issue!(
      name: "API Key", staff: @staff,
      staff_secret_kind_id: OperatorSecretCredentialKind::LOGIN,
    )

    assert_predicate record, :persisted?
    assert_predicate raw_secret_credential, :present?
    assert record.authenticate(raw_secret_credential)
    assert_not_includes record.attributes.values, raw_secret_credential
  end

  test "sample fixture secret_credential authenticates with fixed raw secret_credential" do
    secret_credential = operator_secret_credentials(:sample_login)

    assert secret_credential.authenticate("11111111111111111111111111111111")
    assert_equal OperatorSecretCredentialKind::LOGIN, secret_credential.staff_secret_kind_id
    assert_equal OperatorSecretCredentialStatus::ACTIVE, secret_credential.staff_secret_status_id
  end

  test "requires name to be present" do
    record = OperatorSecretCredential.new(
      staff: @staff,
      name: "",
      password: "SecretPass123!",
    )

    assert_not record.valid?
    assert record.errors[:name]
  end

  test "validates kind_id is required" do
    record = OperatorSecretCredential.new(
      staff: @staff,
      name: "Test Secret",
      password: secure_secret_credential,
      staff_secret_kind_id: nil,
    )

    assert_not record.valid?
    assert_not_empty record.errors[:staff_secret_credential_kind]
  end

  test "login_secret_credential? predicate returns true for LOGIN kind" do
    record = OperatorSecretCredential.new(staff: @staff, name: "Key", staff_secret_kind_id: OperatorSecretCredentialKind::LOGIN)

    assert_predicate record, :login_secret_credential?
  end

  test "public_id is automatically generated on create" do
    record = OperatorSecretCredential.create!(
      staff: @staff,
      name: "Test Secret",
      password: secure_secret_credential,
      staff_secret_kind_id: OperatorSecretCredentialKind::LOGIN,
    )

    assert_predicate record.public_id, :present?
    assert_equal 21, record.public_id.length
  end

  test "to_param returns public_id" do
    record = OperatorSecretCredential.create!(
      staff: @staff,
      name: "Test Secret",
      password: secure_secret_credential,
      staff_secret_kind_id: OperatorSecretCredentialKind::LOGIN,
    )

    assert_equal record.public_id, record.to_param
  end

  test "public_id is unique" do
    record1 = OperatorSecretCredential.create!(
      staff: @staff,
      name: "Test Secret 1",
      password: secure_secret_credential,
      staff_secret_kind_id: OperatorSecretCredentialKind::LOGIN,
    )

    record2 = OperatorSecretCredential.new(
      staff: @staff,
      name: "Test Secret 2",
      password: secure_secret_credential,
      staff_secret_kind_id: OperatorSecretCredentialKind::LOGIN,
    )
    record2.public_id = record1.public_id

    assert_not record2.valid?
    assert_not_empty record2.errors[:public_id]
  end

  private

  def create_secret_credential!
    OperatorSecretCredential.create!(
      staff: @staff,
      name: "Secret-#{SecureRandom.hex(4)}",
      password: secure_secret_credential,
      password_confirmation: secure_secret_credential,
      staff_secret_kind_id: OperatorSecretCredentialKind::LOGIN,
    )
  end

  def secure_secret_credential
    SecureRandom.base58(SecretCredential::SECRET_PASSWORD_LENGTH)
  end
end
