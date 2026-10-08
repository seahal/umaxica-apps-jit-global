# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_identities
# Database name: com_zenith
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
#  index_visitor_identities_on_issuer_and_subject_and_audience  (issuer,subject,audience) UNIQUE
#  index_visitor_identities_on_public_id                        (public_id) UNIQUE
#  index_visitor_identities_on_source_record_id                 (source_record_id) UNIQUE
#  index_visitor_identities_on_status_id                        (status_id)
#
# Foreign Keys
#
#  fk_rails_...  (status_id => visitor_identity_states.id)
#
require "test_helper"
require "base64"

class VisitorIdentityTest < ActiveSupport::TestCase
  setup do
    Prosopite.pause do
      VisitorMfaLevel.ensure_defaults!
      VisitorMfaStatus.ensure_defaults!
      VisitorStatus.ensure_defaults!
      VisitorVisibility.ensure_defaults!
      VisitorEmailStatus.ensure_defaults!
      VisitorTelephoneStatus.ensure_defaults!
      VisitorSecretCredentialStatus.ensure_defaults!
      [1, 3, 4].each { |id| VisitorSecretCredentialKind.find_or_create_by!(id: id) }
      VisitorPasskeyStatus.ensure_defaults!
      VisitorIdentityState.ensure_defaults!
    end
  end

  test "visitor tracks verified recovery identity through visitor email and telephone" do
    visitor = Visitor.create!

    assert_not visitor.has_verified_recovery_identity?

    visitor.visitor_emails.create!(
      address: "visitor-#{SecureRandom.hex(4)}@example.com",
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
      confirm_policy: "1",
    ).tap(&:finalize_binding!)

    assert_predicate visitor, :verified_email?
    assert_predicate visitor, :has_verified_recovery_identity?

    visitor.visitor_telephones.create!(
      number: "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
      confirm_policy: "1",
    ).tap(&:finalize_binding!)

    assert_predicate visitor, :verified_telephone?
  end

  test "visitor secret_credential requires verified recovery identity" do
    visitor = Visitor.create!
    secret_credential = VisitorSecretCredential.new(visitor: visitor, name: "login", password: "a" * 32)

    assert_not secret_credential.valid?
    assert_includes secret_credential.errors[:base], Visitor::RECOVERY_IDENTITY_REQUIRED_MESSAGE
  end

  # D-90: a usable Identity with a usable passkey may hold zero contacts, so a passkey no longer
  # requires a verified contact. The recovery secret above still does.
  test "visitor passkey does not require a verified contact" do
    visitor = Visitor.create!
    passkey = VisitorPasskey.new(
      visitor: visitor,
      webauthn_id: Base64.urlsafe_encode64("visitor_passkey", padding: false),
      external_id: SecureRandom.uuid,
      public_key: "public_key",
      description: "Visitor Passkey",
    )

    passkey.valid?

    assert_not_includes passkey.errors[:base], Visitor::RECOVERY_IDENTITY_REQUIRED_MESSAGE
  end

  test "creates visitor identity mapping" do
    identity = VisitorIdentity.create!(
      issuer: "https://id.example.test",
      subject: "client-subject-1",
      audience: "acme_com",
      source_record_id: 301,
      status_id: VisitorIdentityState::ACTIVE,
    )

    assert_predicate identity.public_id, :present?
    assert_equal ComRpRecord.connection_db_config.name, identity.class.connection_db_config.name
    assert_equal VisitorIdentityState::ACTIVE, identity.status_id
  end

  test "requires oidc mapping fields" do
    identity = VisitorIdentity.new

    assert_not identity.valid?
    assert identity.errors.of_kind?(:issuer, :blank)
    assert identity.errors.of_kind?(:subject, :blank)
    assert identity.errors.of_kind?(:audience, :blank)
    assert identity.errors.of_kind?(:source_record_id, :blank)
  end

  test "allows one mapping per issuer subject and audience" do
    VisitorIdentity.create!(
      issuer: "https://id.example.test",
      subject: "client-subject-2",
      audience: "acme_com",
      source_record_id: 302,
      status_id: VisitorIdentityState::ACTIVE,
    )

    duplicate = VisitorIdentity.new(
      issuer: "https://id.example.test",
      subject: "client-subject-2",
      audience: "acme_com",
      source_record_id: 303,
      status_id: VisitorIdentityState::ACTIVE,
    )

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:subject, :taken)
  end

  test "allows one mapping per source record" do
    VisitorIdentity.create!(
      issuer: "https://id.example.test",
      subject: "client-subject-3",
      audience: "acme_com",
      source_record_id: 304,
      status_id: VisitorIdentityState::ACTIVE,
    )

    duplicate = VisitorIdentity.new(
      issuer: "https://id.example.test",
      subject: "client-subject-4",
      audience: "acme_com",
      source_record_id: 304,
      status_id: VisitorIdentityState::ACTIVE,
    )

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:source_record_id, :taken)
  end
end
