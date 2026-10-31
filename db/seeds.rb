# typed: false
# frozen_string_literal: true

# Reference data (lookup / status tables) is normally owned by migrations, which insert the fixed
# rows with `INSERT ... ON CONFLICT DO NOTHING` (see adr/reference-table-discipline.md). This file
# also replays fixed reference catalogs after a schema-only load, because migration markers
# suppress the original data inserts. The remaining content is development/test sample data.

# A SQL structure load records the migration version without its reference rows.
# Reuse the migration's fixed catalog on the Ticket writer after a schema-only load.
require Rails.root.join("db/op_base_app_migrate/20261006160000_seed_app_sign_flow_reference_data").to_s
require Rails.root.join("db/op_base_org_migrate/20261006160002_seed_org_sign_flow_reference_data").to_s
SeedAppSignFlowReferenceData.seed_into(
  OpBaseAppRecord.lease_connection,
  tables: %i(client_sign_in_flow_states client_sign_up_flow_statuses client_sign_up_flow_cleanup_statuses),
)
SeedOrgSignFlowReferenceData.seed_into(
  OpBaseOrgRecord.lease_connection,
  tables: %i(operator_sign_in_flow_states operator_sign_up_flow_statuses),
)

[
  [ClientTokenKind, ClientTokenStatus, ClientTokenBindingMethod, ClientTokenDbscStatus,
   OperatorTokenKind, OperatorTokenStatus, OperatorTokenBindingMethod, OperatorTokenDbscStatus,],
  [PersonaMembershipKind, PersonaMembershipState, PersonaMembershipRevokeReason,
   AgentMembershipKind, AgentMembershipState, AgentMembershipRevokeReason,
   OperatorEntraIdentityState, OrganizationEntraConnectionState,
   ClientChronicleEvent, ClientChronicleLevel, OperatorChronicleEvent, OperatorChronicleLevel,],
  [AvatarMembershipStatus, AvatarOwnershipStatus, AvatarPermission, AvatarRole, HandleStatus, HandleAssignmentStatus,
   DepartmentStatus, DivisionStatus, OperatorWorkspaceAccountStatus, OrganizationStatus,],
  [ComPreferenceStatus, ComPreferenceChronicleEvent, ComPreferenceChronicleLevel,
   ComPreferenceLanguageOption, ComPreferenceRegionOption, ComPreferenceThemeOption, ComPreferenceTimezoneOption,
   ComPreferenceCurrencyOption, ComPreferenceDateFormatOption, ComPreferenceDensityOption, ComPreferenceMotionOption,
   ComPreferencePageSizeOption, ComPreferenceTimeFormatOption, ComPreferenceWebPushOption,],
  [AppPreferenceLanguageOption, AppPreferenceRegionOption, AppPreferenceThemeOption, AppPreferenceTimezoneOption,
   AppPreferenceCurrencyOption, AppPreferenceDateFormatOption, AppPreferenceDensityOption, AppPreferenceMotionOption,
   AppPreferencePageSizeOption, AppPreferenceTimeFormatOption,],
  [OrgPreferenceLanguageOption, OrgPreferenceRegionOption, OrgPreferenceThemeOption, OrgPreferenceTimezoneOption,
   OrgPreferenceCurrencyOption, OrgPreferenceDateFormatOption, OrgPreferenceDensityOption, OrgPreferenceMotionOption,
   OrgPreferencePageSizeOption, OrgPreferenceTimeFormatOption,],
  [ClientPreferenceLanguageOption, ClientPreferenceRegionOption, ClientPreferenceThemeOption,
   ClientPreferenceTimezoneOption, ClientPreferenceCurrencyOption, ClientPreferenceDateFormatOption,
   ClientPreferenceDensityOption, ClientPreferenceMotionOption, ClientPreferencePageSizeOption,
   ClientPreferenceTimeFormatOption,],
  [OperatorPreferenceLanguageOption, OperatorPreferenceRegionOption, OperatorPreferenceThemeOption,
   OperatorPreferenceTimezoneOption, OperatorPreferenceCurrencyOption, OperatorPreferenceDateFormatOption,
   OperatorPreferenceDensityOption, OperatorPreferenceMotionOption, OperatorPreferencePageSizeOption,
   OperatorPreferenceTimeFormatOption,],
  [ClientStatus, ClientVisibility, ClientSecurityMode, ClientMfaStatus, ClientEmailStatus,
   ClientTelephoneStatus, ClientPasskeyStatus, ClientTotpCredentialStatus, ClientIdentityState,
   OperatorStatus, OperatorVisibility, OperatorSecurityMode, OperatorMfaStatus, OperatorEmailStatus,
   OperatorTelephoneStatus, OperatorSecretCredentialKind, OperatorIdentityState,],
].flatten.each do |model|
  connection = model.lease_connection
  table = connection.quote_table_name(model.table_name)
  model::DEFAULTS.each do |id|
    connection.execute("INSERT INTO #{table} (id) VALUES (#{connection.quote(id)}) ON CONFLICT (id) DO NOTHING")
  end
end

member_status_connection = MemberStatus.lease_connection
member_status_table = member_status_connection.quote_table_name(MemberStatus.table_name)
MemberStatus::DEFAULTS.each do |id|
  member_status_connection.execute(
    "INSERT INTO #{member_status_table} (id, created_at, updated_at) " \
    "VALUES (#{member_status_connection.quote(id)}, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP) ON CONFLICT (id) DO NOTHING",
  )
end

[
  [OperatorPasskeyStatus, [OperatorPasskeyStatus::ACTIVE, OperatorPasskeyStatus::REVOKED]],
  [OperatorSecretCredentialStatus,
   [OperatorSecretCredentialStatus::ACTIVE, OperatorSecretCredentialStatus::DELETED,
    OperatorSecretCredentialStatus::EXPIRED, OperatorSecretCredentialStatus::REVOKED,
    OperatorSecretCredentialStatus::USED,],],
].each do |model, ids|
  connection = model.lease_connection
  table = connection.quote_table_name(model.table_name)
  ids.each do |id|
    connection.execute("INSERT INTO #{table} (id) VALUES (#{connection.quote(id)}) ON CONFLICT (id) DO NOTHING")
  end
end

require Rails.root.join(
  "db/op_base_app_migrate/20261006140000_normalize_client_session_limit_resolution_transactions",
).to_s
require Rails.root.join(
  "db/op_base_org_migrate/20261006140002_create_operator_session_limit_resolution_transactions",
).to_s
[
  [OpBaseAppRecord, :client_session_limit_resolution_states, NormalizeClientSessionLimitResolutionTransactions::STATE_IDS],
  [OpBaseOrgRecord, :operator_session_limit_resolution_states, CreateOperatorSessionLimitResolutionTransactions::STATE_IDS],
].each do |record_class, table, ids|
  connection = record_class.lease_connection
  quoted_table = connection.quote_table_name(table)
  ids.each do |id|
    connection.execute(
      "INSERT INTO #{quoted_table} (id, created_at, updated_at) " \
      "VALUES (#{connection.quote(id)}, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP) ON CONFLICT (id) DO NOTHING",
    )
  end
end

require Rails.root.join("db/op_base_app_migrate/20261025120000_create_op_authority_stops_op_base_app").to_s
require Rails.root.join("db/op_base_org_migrate/20261025120000_create_op_authority_stops_op_base_org").to_s
[
  [OpBaseAppRecord, "app", CreateOpAuthorityStopsOpBaseApp],
  [OpBaseOrgRecord, "org", CreateOpAuthorityStopsOpBaseOrg],
].each do |record_class, realm, catalog|
  connection = record_class.lease_connection
  reference_sets = {
    causes: catalog::CAUSES, scopes: catalog::SCOPES, participant_statuses: catalog::PARTICIPANT_STATUSES,
  }
  reference_sets.each do |suffix, ids|
    table = connection.quote_table_name("op_#{realm}_authority_stop_#{suffix}")
    ids.each_key do |id|
      connection.execute("INSERT INTO #{table} (id) VALUES (#{connection.quote(id)}) ON CONFLICT (id) DO NOTHING")
    end
  end
end

return if Rails.env.production?

# Occurrence reference rows are owned by the occurrence database, not primary.
# A structure.sql load marks data migrations as applied without replaying their
# INSERTs, so reproduce the current JWT anomaly catalog through the same
# idempotent migration writer on the correct writer connection. During the
# pre-migration bootstrap both tables are absent and this section is skipped;
# a partially-created occurrence schema fails loudly instead of reporting a
# successful but incomplete seed.
occurrence_connection = OccurrenceRecord.lease_connection
occurrence_tables = %w(jwt_occurrence_statuses jwt_occurrences)
occurrence_table_presence =
  occurrence_tables.map do |table_name|
    occurrence_connection.data_source_exists?(table_name)
  end

if occurrence_table_presence.any?
  require Rails.root.join(
    "db/occurrences_migrate/20260918150000_insert_current_jwt_anomaly_reference_data",
  ).to_s
  InsertCurrentJwtAnomalyReferenceData.new.seed_into(occurrence_connection)
end

# Avatar lifecycle states are owned by the avatar database and are required by
# avatar provisioning (social sign-up completion). Replay them for the same
# structure.sql reason as the occurrence catalog above.
avatar_connection = AvatarRecord.lease_connection
if avatar_connection.data_source_exists?("avatar_lifecycle_states")
  require Rails.root.join(
    "db/avatars_migrate/20260703000001_create_avatar_lifecycle_state_authority",
  ).to_s
  CreateAvatarLifecycleStateAuthority.new.seed_into(avatar_connection)
end

sample_staff_public_id = "2222222222222222"
sample_staff_secret = "22222222222222222222222222222222"
sample_staff_email_address = "sample-staff@example.test"

user = Client.find_or_initialize_by(public_id: "sample_userxxxxxxxxxx")
user.status_id = ClientStatus::ACTIVE
user.visibility_id = ClientVisibility::USER
user.security_mode_id = ClientSecurityMode::NORMAL
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

staff = Operator.find_or_initialize_by(public_id: sample_staff_public_id)
staff.status_id = OperatorStatus::ACTIVE
staff.visibility_id = OperatorVisibility::USER
staff.security_mode_id = OperatorSecurityMode::ADVANCED
staff.mfa_status_id = OperatorMfaStatus::UNCONFIGURED
staff.save!

staff_email = OperatorEmail.with_address(sample_staff_email_address).first ||
  OperatorEmail.new(address: sample_staff_email_address)
staff_email.staff = staff
staff_email.staff_email_status_id = OperatorEmailStatus::VERIFIED
staff_email.save!

staff_secret = staff.operator_secret_credentials.find_or_initialize_by(name: "sample-staff-secret")
staff_secret.staff_secret_kind_id = OperatorSecretCredentialKind::LOGIN
staff_secret.staff_identity_secret_status_id = OperatorSecretCredentialStatus::ACTIVE
staff_secret.password = sample_staff_secret
staff_secret.save!

# Flipper stores nothing until a feature is written, so a fresh primary database shows an
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
# FQDN: a fresh primary database answers every request with 503 `fqdn_unavailable` before routing.
# Every slot the router serves is opened here so a freshly seeded development environment serves the
# hosts its own routes declare. Production is untouched (this file returns above) -- switching a
# public FQDN on stays an explicit operator decision made through the Flipper UI.
FqdnAvailabilityRegistry.flag_names.each { |feature_name| Flipper.enable(feature_name) }

# Sign Entry Sentry switches have the same polarity: an unwritten flag answers every Sign In and
# Sign Up entry with 503 `sentry_blocked`. Open all six so local sign-in and sign-up work.
SignEntrySentryResolver::ENTRY_FLAGS.each_value { |feature_name| Flipper.enable(feature_name) }

# Deterministic development CMS documents so all twelve public content cells have
# a published entry. Uses the normal draft -> promote -> publish lifecycle.
# Keep this out of test: `db:prepare` seeds newly created test databases, and the
# welcome rows then leak into every worker clone and break empty-table assertions.
if Rails.env.development?
  locales = %w(ja en)

  Publishing::ContentFamilies::ENTRY_CLASSES.product(locales).each do |entry_class, locale|
    slug = "welcome"
    next if entry_class.reflect_on_association(:slugs).klass.exists?(locale:, slug:)

    title = "#{entry_class::SURFACE.capitalize} #{entry_class::AUDIENCE} (#{locale})"
    entry = entry_class.create!(locale:)
    entry.slugs.create!(locale:, slug:, state: "canonical", canonicalized_at: Time.current)
    revision = entry.revisions.create!(
      locale:, title:, summary: "#{title} summary",
      body: { "text" => "#{title} body" }, schema_version: 1,
      content_digest: Digest::SHA256.hexdigest("#{entry_class::AUDIENCE}-#{entry_class::SURFACE}-#{locale}-welcome"),
      sequence: 1,
    )
    entry.update!(current_revision: revision)
    version = Publishing::PromoteRevisionOperation.call(revision:)
    entry.publications.create!(entry_version: version, effective_from: 1.hour.ago)
  end
end
