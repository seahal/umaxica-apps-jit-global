# typed: false
# frozen_string_literal: true

# Reference data (lookup / status tables) is owned by migrations, which insert the fixed rows
# with `INSERT ... ON CONFLICT DO NOTHING` (see adr/reference-table-discipline.md). This file is
# only responsible for development/test sample fixtures (sample Client / Operator and their
# email/secret), and is a no-op in production. The sample fixtures below rely on the reference
# rows already being present from migrations.

return if Rails.env.production?

# `schema_format: :sql` loads `structure.sql` for db:prepare, which carries schema only (no row
# data). Migrations that seed fixed reference-table rows via raw INSERTs are marked "already run"
# by structure.sql's schema_migrations rows, so their INSERT side effects never replay on a freshly
# prepared database. Ensure the reference tables this file depends on are populated before use.
[
  ClientStatus, ClientVisibility, ClientMfaLevel, ClientMfaStatus,
  ClientEmailStatus, ClientSecretCredentialKind, ClientSecretCredentialStatus,
  OperatorStatus, OperatorVisibility, OperatorMfaLevel, OperatorMfaStatus,
  OperatorEmailStatus, OperatorSecretCredentialKind,
].each(&:ensure_defaults!)
OperatorSecretCredentialStatus.insert_missing_fixed_ids!(
  [OperatorSecretCredentialStatus::ACTIVE, OperatorSecretCredentialStatus::DELETED,
   OperatorSecretCredentialStatus::EXPIRED, OperatorSecretCredentialStatus::REVOKED,
   OperatorSecretCredentialStatus::USED,],
)

sample_user_secret = "00000000000000000000000000000000"
sample_staff_public_id = "2222222222222222"
sample_staff_secret = "22222222222222222222222222222222"
sample_staff_email_address = "sample-staff@example.test"

user = Client.find_or_initialize_by(public_id: "sample_user")
user.status_id = ClientStatus::ACTIVE
user.visibility_id = ClientVisibility::USER
user.mfa_level_id = ClientMfaLevel::NOTHING
user.mfa_status_id = ClientMfaStatus::UNCONFIGURED
user.save!

# `address` is encrypted, so a plaintext `find_or_initialize_by(address:)` never matches an
# existing row and the second seed run fails the blind-index uniqueness validation. Look the
# record up through the `with_address` scope, which searches the blind index instead.
sample_user_email_address = "sample-user@example.test"
user_email = user.client_emails.with_address(sample_user_email_address).first ||
  user.client_emails.new(address: sample_user_email_address)
user_email.user_email_status_id = ClientEmailStatus::VERIFIED
user_email.confirm_policy = true
user_email.save!

user_secret = user.client_secret_credentials.find_or_initialize_by(name: "sample-user-secret")
user_secret.user_secret_kind_id = ClientSecretCredentialKind::PERMANENT
user_secret.user_identity_secret_status_id = ClientSecretCredentialStatus::ACTIVE
user_secret.uses_remaining = 10
user_secret.password = sample_user_secret
user_secret.save!

staff = Operator.find_or_initialize_by(public_id: sample_staff_public_id)
staff.status_id = OperatorStatus::ACTIVE
staff.visibility_id = OperatorVisibility::USER
staff.mfa_level_id = OperatorMfaLevel::NOTHING
staff.mfa_status_id = OperatorMfaStatus::UNCONFIGURED
staff.save!

staff_email = OperatorEmail.with_address(sample_staff_email_address).first ||
  OperatorEmail.new(address: sample_staff_email_address)
staff_email.staff = staff
staff_email.staff_email_status_id = OperatorEmailStatus::VERIFIED
staff_email.save!

staff_secret = staff.operator_secret_credentials.find_or_initialize_by(name: "sample-staff-secret")
staff_secret.staff_secret_kind_id = OperatorSecretCredentialKind::PERMANENT
staff_secret.staff_identity_secret_status_id = OperatorSecretCredentialStatus::ACTIVE
staff_secret.password = sample_staff_secret
staff_secret.save!

# Flipper stores nothing until a feature is written, so a fresh platform database shows an
# empty feature list and every external authentication ceremony reads as disabled. Register
# the ceremony kill switches so they appear in the Flipper UI and local sign-in works.
#
# Development only, and deliberately not extended to production: the flags are kill switches
# for external authentication ceremonies, and their production state must be an explicit
# operator decision rather than a side effect of running seeds. `enable` is idempotent, so a
# flag an operator disabled locally is re-enabled by the next seed run.
ExternalAuthentication::FlipperProviderAvailabilityAdapter::PROVIDER_FEATURE_NAMES
  .each_value { |feature_name| Flipper.enable(feature_name) }

# `fqdn_available_*` carries the same `:availability` polarity, so an unwritten flag closes the
# FQDN: a fresh platform database answers every request with 503 `fqdn_unavailable` before routing.
# Every slot the router serves is opened here so a freshly seeded development environment serves the
# hosts its own routes declare. Production is untouched (this file returns above) -- switching a
# public FQDN on stays an explicit operator decision made through the Flipper UI.
FqdnAvailabilityRegistry.flag_names.each { |feature_name| Flipper.enable(feature_name) }

# Deterministic development CMS documents so all twelve public content cells have
# a published entry. Uses the normal draft -> promote -> publish lifecycle.
AUDIENCES = %w(app com org).freeze
SURFACES = %w(info docs news help).freeze
LOCALES = %w(ja en).freeze
REGIONAL_SURFACES = %w(docs news help).freeze

AUDIENCES.product(SURFACES, LOCALES).each do |audience, surface, locale|
  edition =
    Publishing::Edition.find_or_create_by!(audience:, surface:, locale:) do |record|
      record.region_code = "jp" if REGIONAL_SURFACES.include?(surface)
    end
  slug = "welcome"
  next if Publishing::EntrySlug.exists?(edition:, slug:)

  title = "#{surface.capitalize} #{audience} (#{locale})"
  entry = Publishing::Entry.create!(edition:, locale:)
  Publishing::EntrySlug.create!(
    entry:, edition:, locale:, slug:, state: "canonical", canonicalized_at: Time.current,
  )
  revision = Publishing::EntryRevision.create!(
    entry:, locale:, title:, summary: "#{title} summary",
    body: { "text" => "#{title} body" }, schema_version: 1,
    content_digest: Digest::SHA256.hexdigest("#{audience}-#{surface}-#{locale}-welcome"),
    sequence: 1,
  )
  entry.update!(current_revision: revision)
  version = Publishing::PromoteRevisionOperation.call(revision:)
  Publishing::Publication.create!(entry:, entry_version: version, effective_from: 1.hour.ago)
end
