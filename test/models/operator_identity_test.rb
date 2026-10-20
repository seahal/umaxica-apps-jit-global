# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_identities
# Database name: org_zenith
#
#  id                    :bigint           not null, primary key
#  audience              :string           not null
#  issuer                :string           not null
#  last_authenticated_at :datetime
#  lock_version          :integer          default(0), not null
#  subject               :string           not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  public_id             :string           default(""), not null
#  source_record_id      :bigint           not null
#  status_id             :bigint           default(0), not null
#
# Indexes
#
#  index_operator_identities_on_issuer_and_subject_and_audience  (issuer,subject,audience) UNIQUE
#  index_operator_identities_on_public_id                        (public_id) UNIQUE
#  index_operator_identities_on_source_record_id                 (source_record_id) UNIQUE
#  index_operator_identities_on_status_id                        (status_id)
#
# Foreign Keys
#
#  fk_rails_...  (status_id => operator_identity_states.id)
#
require "test_helper"

class OperatorIdentityTest < ActiveSupport::TestCase
  setup do
    OperatorIdentityState.ensure_defaults!
  end

  test "creates operator identity mapping" do
    identity = OperatorIdentity.create!(
      issuer: "https://id.example.test",
      subject: "staff-subject-1",
      audience: "acme_org",
      source_record_id: 201,
      status_id: OperatorIdentityState::ACTIVE,
    )

    assert_predicate identity.public_id, :present?
    assert_equal OrgRpRecord.connection_db_config.name, identity.class.connection_db_config.name
    assert_equal OperatorIdentityState::ACTIVE, identity.status_id
  end

  test "requires oidc mapping fields" do
    identity = OperatorIdentity.new

    assert_not identity.valid?
    assert identity.errors.of_kind?(:issuer, :blank)
    assert identity.errors.of_kind?(:subject, :blank)
    assert identity.errors.of_kind?(:audience, :blank)
    assert identity.errors.of_kind?(:source_record_id, :blank)
  end

  test "allows one mapping per issuer subject and audience" do
    OperatorIdentity.create!(
      issuer: "https://id.example.test",
      subject: "staff-subject-2",
      audience: "acme_org",
      source_record_id: 202,
      status_id: OperatorIdentityState::ACTIVE,
    )

    duplicate = OperatorIdentity.new(
      issuer: "https://id.example.test",
      subject: "staff-subject-2",
      audience: "acme_org",
      source_record_id: 203,
      status_id: OperatorIdentityState::ACTIVE,
    )

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:subject, :taken)
  end

  test "allows one mapping per source record" do
    OperatorIdentity.create!(
      issuer: "https://id.example.test",
      subject: "staff-subject-3",
      audience: "acme_org",
      source_record_id: 204,
      status_id: OperatorIdentityState::ACTIVE,
    )

    duplicate = OperatorIdentity.new(
      issuer: "https://id.example.test",
      subject: "staff-subject-4",
      audience: "acme_org",
      source_record_id: 204,
      status_id: OperatorIdentityState::ACTIVE,
    )

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:source_record_id, :taken)
  end

  test "public_id is a fixed 21-character NanoID" do
    assert_public_id_fixed_length(::OperatorIdentity)
  end
end
