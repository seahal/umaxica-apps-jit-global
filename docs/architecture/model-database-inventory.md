# Model Database Inventory

## Purpose

This document is a current-state inventory of model and database placement in Project Umaxica. It
intentionally separates:

- current storage
- semantic ownership
- target placement
- migration decisions

This is not a migration plan and not a database rename. It records what the repository currently
does so later placement decisions can be made against current facts instead of memory or
assumptions.

## Scope

In scope:

- database connections
- migration paths
- abstract ActiveRecord base classes
- model-to-table-to-database mapping
- ambiguous ownership notes
- current principal, zenith, and avatar contents

Out of scope:

- schema changes
- database renames
- model connection changes
- migrations
- route changes
- controller changes
- service implementation
- token/session/ceremony/logout/OAuth transaction migration
- preference migration
- Avatar relocation

## Reading Rules

Classification uses the following dimensions:

semantic_class:

- authority
- projection
- credential
- session_token
- ceremony_transaction
- lifecycle
- content
- avatar_authority
- social_graph
- bridge
- transitional
- unknown

decision_status:

- settled
- candidate
- excluded
- transitional
- unknown

placement_type:

- current_storage
- target_authority
- future_candidate
- out_of_scope

Important rule: current database name is not proof of canonical authority ownership. Current storage
and target placement are separate facts.

## Database Connections

| connection key          | config path / environment key                                                          | database name pattern                                   | migration path                                       | role today                                | target role                            | notes                                                                                      |
| ----------------------- | -------------------------------------------------------------------------------------- | ------------------------------------------------------- | ---------------------------------------------------- | ----------------------------------------- | -------------------------------------- | ------------------------------------------------------------------------------------------ |
| `app_principal`         | `config/database.yml` / `POSTGRESQL_APP_PRINCIPAL_PUB`, `POSTGRESQL_APP_PRINCIPAL_SUB` | `development_app_principal_db`, `test_app_principal_db` | `db/app_principal_reserved_migrate`                  | Empty retained connection key             | future regional-ready application data | Reserved path only after principal/zenith physical consolidation.                          |
| `app_principal_replica` | `config/database.yml` / `POSTGRESQL_APP_PRINCIPAL_SUB`                                 | replica of `app_principal`                              | `db/app_principal_reserved_migrate`                  | read replica                              | read replica                           | Replica only.                                                                              |
| `app_zenith`            | `config/database.yml` / `POSTGRESQL_APP_ZENITH_PUB`, `POSTGRESQL_APP_ZENITH_SUB`       | `development_app_zenith_db`, `test_app_zenith_db`       | `db/app_principals_migrate`, `db/app_zenith_migrate` | Consolidated principal and zenith storage | target authority                       | Current app-side principal, account, identity binding, content, and bridge rows live here. |
| `app_zenith_replica`    | `config/database.yml` / `POSTGRESQL_APP_ZENITH_SUB`                                    | replica of `app_zenith`                                 | `db/app_principals_migrate`, `db/app_zenith_migrate` | read replica                              | read replica                           | Replica only.                                                                              |
| `app_setting`           | `config/database.yml` / `POSTGRESQL_APP_SETTING_PUB`, `POSTGRESQL_APP_SETTING_SUB`     | `development_app_setting_db`, `test_app_setting_db`     | `db/app_settings_migrate`                            | surface settings                          | out of scope                           | Preference database, not part of the authority placement migration.                        |
| `app_setting_replica`   | `config/database.yml` / `POSTGRESQL_APP_SETTING_SUB`                                   | replica of `app_setting`                                | `db/app_settings_migrate`                            | read replica                              | read replica                           | Replica only.                                                                              |
| `app_signal`            | `config/database.yml` / `POSTGRESQL_APP_SIGNAL_PUB`, `POSTGRESQL_APP_SIGNAL_SUB`       | `development_app_signal_db`, `test_app_signal_db`       | `db/app_signals_migrate`                             | signal / notification                     | out of scope                           | Notification-origin rows.                                                                  |
| `app_signal_replica`    | `config/database.yml` / `POSTGRESQL_APP_SIGNAL_SUB`                                    | replica of `app_signal`                                 | `db/app_signals_migrate`                             | read replica                              | read replica                           | Replica only.                                                                              |
| `app_ticket`            | `config/database.yml` / `POSTGRESQL_APP_TICKET_PUB`, `POSTGRESQL_APP_TICKET_SUB`       | `development_app_ticket_db`, `test_app_ticket_db`       | `db/app_tickets_migrate`                             | ticket / session / token / ceremony       | out of scope                           | Excluded from authority placement migration.                                               |
| `app_ticket_replica`    | `config/database.yml` / `POSTGRESQL_APP_TICKET_SUB`                                    | replica of `app_ticket`                                 | `db/app_tickets_migrate`                             | read replica                              | read replica                           | Replica only.                                                                              |
| `avatar`                | `config/database.yml` / `POSTGRESQL_AVATAR_PUB`, `POSTGRESQL_AVATAR_SUB`               | `development_avatar_db`, `test_avatar_db`               | `db/avatars_migrate`                                 | avatar authority boundary                 | current storage only                   | Separate actor-authority boundary in this phase.                                           |
| `avatar_replica`        | `config/database.yml` / `POSTGRESQL_AVATAR_SUB`                                        | replica of `avatar`                                     | `db/avatars_migrate`                                 | read replica                              | read replica                           | Replica only.                                                                              |
| `chronicle`             | `config/database.yml` / `POSTGRESQL_CHRONICLE_PUB`, `POSTGRESQL_CHRONICLE_SUB`         | `development_chronicle_db`, `test_chronicle_db`         | `db/chronicle_migrate`                               | audit / chronicle                         | out of scope                           | Shared cross-cutting audit store.                                                          |
| `chronicle_replica`     | `config/database.yml` / `POSTGRESQL_CHRONICLE_SUB`                                     | replica of `chronicle`                                  | `db/chronicle_migrate`                               | read replica                              | read replica                           | Replica only.                                                                              |
| `com_principal`         | `config/database.yml` / `POSTGRESQL_COM_PRINCIPAL_PUB`, `POSTGRESQL_COM_PRINCIPAL_SUB` | `development_com_principal_db`, `test_com_principal_db` | `db/com_principal_reserved_migrate`                  | Empty retained connection key             | future regional-ready application data | Reserved path only after principal/zenith physical consolidation.                          |
| `com_principal_replica` | `config/database.yml` / `POSTGRESQL_COM_PRINCIPAL_SUB`                                 | replica of `com_principal`                              | `db/com_principal_reserved_migrate`                  | read replica                              | read replica                           | Replica only.                                                                              |
| `com_zenith`            | `config/database.yml` / `POSTGRESQL_COM_ZENITH_PUB`, `POSTGRESQL_COM_ZENITH_SUB`       | `development_com_zenith_db`, `test_com_zenith_db`       | `db/com_principals_migrate`, `db/com_zenith_migrate` | Consolidated principal and zenith storage | target authority                       | Current com-side principal, account, identity binding, and content rows live here.         |
| `com_zenith_replica`    | `config/database.yml` / `POSTGRESQL_COM_ZENITH_SUB`                                    | replica of `com_zenith`                                 | `db/com_principals_migrate`, `db/com_zenith_migrate` | read replica                              | read replica                           | Replica only.                                                                              |
| `com_setting`           | `config/database.yml` / `POSTGRESQL_COM_SETTING_PUB`, `POSTGRESQL_COM_SETTING_SUB`     | `development_com_setting_db`, `test_com_setting_db`     | `db/com_settings_migrate`                            | surface settings                          | out of scope                           | Preference database.                                                                       |
| `com_setting_replica`   | `config/database.yml` / `POSTGRESQL_COM_SETTING_SUB`                                   | replica of `com_setting`                                | `db/com_settings_migrate`                            | read replica                              | read replica                           | Replica only.                                                                              |
| `com_signal`            | `config/database.yml` / `POSTGRESQL_COM_SIGNAL_PUB`, `POSTGRESQL_COM_SIGNAL_SUB`       | `development_com_signal_db`, `test_com_signal_db`       | `db/com_signals_migrate`                             | signal / notification                     | out of scope                           | Notification-origin rows.                                                                  |
| `com_signal_replica`    | `config/database.yml` / `POSTGRESQL_COM_SIGNAL_SUB`                                    | replica of `com_signal`                                 | `db/com_signals_migrate`                             | read replica                              | read replica                           | Replica only.                                                                              |
| `com_ticket`            | `config/database.yml` / `POSTGRESQL_COM_TICKET_PUB`, `POSTGRESQL_COM_TICKET_SUB`       | `development_com_ticket_db`, `test_com_ticket_db`       | `db/com_tickets_migrate`                             | ticket / session / token / ceremony       | out of scope                           | Excluded from authority placement migration.                                               |
| `com_ticket_replica`    | `config/database.yml` / `POSTGRESQL_COM_TICKET_SUB`                                    | replica of `com_ticket`                                 | `db/com_tickets_migrate`                             | read replica                              | read replica                           | Replica only.                                                                              |
| `occurrence`            | `config/database.yml` / `POSTGRESQL_OCCURRENCE_PUB`, `POSTGRESQL_OCCURRENCE_SUB`       | `development_occurrence_db`, `test_occurrence_db`       | `db/occurrences_migrate`                             | cross-cutting occurrence / telemetry      | out of scope                           | Not part of authority placement.                                                           |
| `occurrence_replica`    | `config/database.yml` / `POSTGRESQL_OCCURRENCE_SUB`                                    | replica of `occurrence`                                 | `db/occurrences_migrate`                             | read replica                              | read replica                           | Replica only.                                                                              |
| `org_principal`         | `config/database.yml` / `POSTGRESQL_ORG_PRINCIPAL_PUB`, `POSTGRESQL_ORG_PRINCIPAL_SUB` | `development_org_principal_db`, `test_org_principal_db` | `db/org_principal_reserved_migrate`                  | Empty retained connection key             | future regional-ready application data | Reserved path only after principal/zenith physical consolidation.                          |
| `org_principal_replica` | `config/database.yml` / `POSTGRESQL_ORG_PRINCIPAL_SUB`                                 | replica of `org_principal`                              | `db/org_principal_reserved_migrate`                  | read replica                              | read replica                           | Replica only.                                                                              |
| `org_zenith`            | `config/database.yml` / `POSTGRESQL_ORG_ZENITH_PUB`, `POSTGRESQL_ORG_ZENITH_SUB`       | `development_org_zenith_db`, `test_org_zenith_db`       | `db/org_principals_migrate`, `db/org_zenith_migrate` | Consolidated principal and zenith storage | target authority                       | Current org-side principal, account, identity binding, and content rows live here.         |
| `org_zenith_replica`    | `config/database.yml` / `POSTGRESQL_ORG_ZENITH_SUB`                                    | replica of `org_zenith`                                 | `db/org_principals_migrate`, `db/org_zenith_migrate` | read replica                              | read replica                           | Replica only.                                                                              |
| `org_setting`           | `config/database.yml` / `POSTGRESQL_ORG_SETTING_PUB`, `POSTGRESQL_ORG_SETTING_SUB`     | `development_org_setting_db`, `test_org_setting_db`     | `db/org_settings_migrate`                            | surface settings                          | out of scope                           | Preference database.                                                                       |
| `org_setting_replica`   | `config/database.yml` / `POSTGRESQL_ORG_SETTING_SUB`                                   | replica of `org_setting`                                | `db/org_settings_migrate`                            | read replica                              | read replica                           | Replica only.                                                                              |
| `org_signal`            | `config/database.yml` / `POSTGRESQL_ORG_SIGNAL_PUB`, `POSTGRESQL_ORG_SIGNAL_SUB`       | `development_org_signal_db`, `test_org_signal_db`       | `db/org_signals_migrate`                             | signal / notification                     | out of scope                           | Notification-origin rows.                                                                  |
| `org_signal_replica`    | `config/database.yml` / `POSTGRESQL_ORG_SIGNAL_SUB`                                    | replica of `org_signal`                                 | `db/org_signals_migrate`                             | read replica                              | read replica                           | Replica only.                                                                              |
| `org_ticket`            | `config/database.yml` / `POSTGRESQL_ORG_TICKET_PUB`, `POSTGRESQL_ORG_TICKET_SUB`       | `development_org_ticket_db`, `test_org_ticket_db`       | `db/org_tickets_migrate`                             | ticket / session / token / ceremony       | out of scope                           | Excluded from authority placement migration.                                               |
| `org_ticket_replica`    | `config/database.yml` / `POSTGRESQL_ORG_TICKET_SUB`                                    | replica of `org_ticket`                                 | `db/org_tickets_migrate`                             | read replica                              | read replica                           | Replica only.                                                                              |
| `queue`                 | `config/database.yml` / `POSTGRESQL_QUEUE_PUB`, `POSTGRESQL_QUEUE_SUB`                 | `development_queue_db`, `test_queue_db`                 | `db/queues_migrate`                                  | infrastructure                            | out of scope                           | Solid Queue database.                                                                      |
| `queue_replica`         | `config/database.yml` / `POSTGRESQL_QUEUE_SUB`                                         | replica of `queue`                                      | `db/queues_migrate`                                  | read replica                              | read replica                           | Replica only.                                                                              |
| `search`                | `config/database.yml` / `POSTGRESQL_SEARCH_PUB`, `POSTGRESQL_SEARCH_SUB`               | `development_search_db`, `test_search_db`               | `db/searches_migrate`                                | infrastructure / search                   | out of scope                           | Reserved empty owner directory. No application schema yet.                                 |
| `search_replica`        | `config/database.yml` / `POSTGRESQL_SEARCH_SUB`                                        | replica of `search`                                     | `db/searches_migrate`                                | read replica                              | read replica                           | Replica only.                                                                              |
| `storage`               | `config/database.yml` / `POSTGRESQL_STORAGE_PUB`, `POSTGRESQL_STORAGE_SUB`             | `development_storage_db`, `test_storage_db`             | `db/storages_migrate`                                | infrastructure                            | out of scope                           | Reserved empty owner directory. Not the publishing media store.                            |
| `storage_replica`       | `config/database.yml` / `POSTGRESQL_STORAGE_SUB`                                       | replica of `storage`                                    | `db/storages_migrate`                                | read replica                              | read replica                           | Replica only.                                                                              |

## Migration Directories

| migration path                      | inferred database key | migration count | newest migration                                                           | oldest migration                                                | role           | notes                                                               |
| ----------------------------------- | --------------------- | --------------: | -------------------------------------------------------------------------- | --------------------------------------------------------------- | -------------- | ------------------------------------------------------------------- |
| `db/app_principals_migrate`         | `app_zenith`          |             302 | `20260513153000_repair_user_passkey_status_reference_rows`                 | `20240827130201_create_users`                                   | principal      | Historical app principal migrations now applied through app_zenith. |
| `db/app_principal_reserved_migrate` | `app_principal`       |               0 | n/a                                                                        | n/a                                                             | reserved       | Empty retained path for future regional-ready storage.              |
| `db/app_settings_migrate`           | `app_setting`         |               7 | `20260612000001_convert_timestamps_to_timestamptz`                         | `20260518030000_load_initial_app_setting_schema`                | setting        | App settings.                                                       |
| `db/app_signals_migrate`            | `app_signal`          |               3 | `20260507000000_create_app_signal_tables`                                  | `20260520143001_rename_app_signal_tables_to_model_conventions`  | signal         | App signal tables.                                                  |
| `db/app_tickets_migrate`            | `app_ticket`          |              56 | `20260626000000_create_logout_transactions`                                | `20260507010001_add_dpop_jkt_and_session_id_to_user_tokens`     | ticket         | Session / token / ceremony storage.                                 |
| `db/app_zenith_migrate`             | `app_zenith`          |              23 | `20260627000001_create_persona_assignments`                                | `20260511223446_create_user_resident_statuses`                  | zenith         | App-side authority / projection store.                              |
| `db/avatars_migrate`                | `avatar`              |              30 | `20260627000003_add_avatar_social_graph_invariants`                        | `20251225200010_create_avatar_identity_core_tables`             | avatar         | Avatar authority boundary.                                          |
| `db/chronicle_migrate`              | `chronicle`           |              18 | `20260616150020_remove_redundant_chronicle_indexes`                        | `20260501000000_load_initial_chronicle_schema`                  | chronicle      | Audit / chronicle store.                                            |
| `db/com_principals_migrate`         | `com_zenith`          |              54 | `20240627130203_create_extensions`                                         | `20251224171000_insert_dummy_guest_data`                        | principal      | Historical com principal migrations now applied through com_zenith. |
| `db/com_principal_reserved_migrate` | `com_principal`       |               0 | n/a                                                                        | n/a                                                             | reserved       | Empty retained path for future regional-ready storage.              |
| `db/com_settings_migrate`           | `com_setting`         |               7 | `20260612000001_convert_timestamps_to_timestamptz`                         | `20260518030000_load_initial_com_setting_schema`                | setting        | Com settings.                                                       |
| `db/com_signals_migrate`            | `com_signal`          |               3 | `20260517070000_create_com_signal_tables`                                  | `20260520143005_rename_com_signal_tables_to_model_conventions`  | signal         | Com signal tables.                                                  |
| `db/com_tickets_migrate`            | `com_ticket`          |              49 | `20260624000000_create_visitor_token_usages_and_bind_authorization_codes`  | `20260507010003_add_dpop_jkt_and_session_id_to_customer_tokens` | ticket         | Session / token / ceremony storage.                                 |
| `db/com_zenith_migrate`             | `com_zenith`          |              22 | `20260627000001_create_individual_assignments`                             | `20260511223457_create_client_visitor_statuses`                 | zenith         | Com-side authority / projection store.                              |
| `db/occurrences_migrate`            | `occurrence`          |             114 | `20240627130203_create_extensions`                                         | `20251225004951_create_area_user_occurrences`                   | occurrence     | Cross-cutting occurrence store.                                     |
| `db/org_principals_migrate`         | `org_zenith`          |             220 | `20260623100000_update_operator_preference_defaults`                       | `20240827130202_create_staffs`                                  | principal      | Historical org principal migrations now applied through org_zenith. |
| `db/org_principal_reserved_migrate` | `org_principal`       |               0 | n/a                                                                        | n/a                                                             | reserved       | Empty retained path for future regional-ready storage.              |
| `db/org_settings_migrate`           | `org_setting`         |               7 | `20260612000001_convert_timestamps_to_timestamptz`                         | `20260518030000_load_initial_org_setting_schema`                | setting        | Org settings.                                                       |
| `db/org_signals_migrate`            | `org_signal`          |               3 | `20260507000000_create_org_signal_tables`                                  | `20260520143009_rename_org_signal_tables_to_model_conventions`  | signal         | Org signal tables.                                                  |
| `db/org_tickets_migrate`            | `org_ticket`          |              38 | `20260624000000_create_operator_token_usages_and_bind_authorization_codes` | `20260507010002_add_dpop_jkt_and_session_id_to_staff_tokens`    | ticket         | Session / token / ceremony storage.                                 |
| `db/org_zenith_migrate`             | `org_zenith`          |              27 | `20260630000005_create_bureau_unit_closures`                               | `20260511223457_create_staff_personnel_statuses`                | zenith         | Org-side authority / projection store.                              |
| `db/queues_migrate`                 | `queue`               |               4 | `20251220094000_create_solid_queue_schema`                                 | `20260309000001_convert_timestamps_to_timestamptz`              | infrastructure | Queue store.                                                        |

## Abstract ActiveRecord Bases

| class                | file                                 | abstract? | superclass           | connects_to / connection                                                         | inferred database | role                  | notes                                                               |
| -------------------- | ------------------------------------ | --------: | -------------------- | -------------------------------------------------------------------------------- | ----------------- | --------------------- | ------------------------------------------------------------------- |
| `ApplicationRecord`  | `app/models/application_record.rb`   |       yes | `ActiveRecord::Base` | `primary_abstract_class`                                                         | default app base  | root base             | Shared root model class.                                            |
| `AppPrincipalRecord` | `app/models/app_principal_record.rb` |       yes | `ApplicationRecord`  | `connects_to database: { writing: :app_zenith, reading: :app_zenith_replica }`   | `app_zenith`      | principal semantics   | App-side principal semantic base backed by consolidated app_zenith. |
| `AppRpRecord`        | `app/models/app_rp_record.rb`        |       yes | `ApplicationRecord`  | `connects_to database: { writing: :app_zenith, reading: :app_zenith_replica }`   | `app_zenith`      | zenith                | App-side RP / authority base.                                       |
| `AppSettingRecord`   | `app/models/app_setting_record.rb`   |       yes | `ApplicationRecord`  | `connects_to database: { writing: :app_setting, reading: :app_setting_replica }` | `app_setting`     | setting               | App-side setting base.                                              |
| `AppSignalRecord`    | `app/models/app_signal_record.rb`    |       yes | `ApplicationRecord`  | `connects_to database: { writing: :app_signal, reading: :app_signal_replica }`   | `app_signal`      | signal                | App-side signal base.                                               |
| `AppTicketRecord`    | `app/models/app_ticket_record.rb`    |       yes | `ApplicationRecord`  | `connects_to database: { writing: :app_ticket, reading: :app_ticket_replica }`   | `app_ticket`      | ticket                | App-side ticket / token / ceremony base.                            |
| `AvatarRecord`       | `app/models/avatar_record.rb`        |       yes | `ApplicationRecord`  | `connects_to database: { writing: :avatar, reading: :avatar_replica }`           | `avatar`          | avatar                | Avatar authority base.                                              |
| `ChronicleRecord`    | `app/models/chronicle_record.rb`     |       yes | `ApplicationRecord`  | `connects_to database: { writing: :chronicle, reading: :chronicle_replica }`     | `chronicle`       | chronicle             | Audit / chronicle base.                                             |
| `ComPrincipalRecord` | `app/models/com_principal_record.rb` |       yes | `ApplicationRecord`  | `connects_to database: { writing: :com_zenith, reading: :com_zenith_replica }`   | `com_zenith`      | principal semantics   | Com-side principal semantic base backed by consolidated com_zenith. |
| `ComRpRecord`        | `app/models/com_rp_record.rb`        |       yes | `ApplicationRecord`  | `connects_to database: { writing: :com_zenith, reading: :com_zenith_replica }`   | `com_zenith`      | zenith                | Com-side RP / authority base.                                       |
| `ComSettingRecord`   | `app/models/com_setting_record.rb`   |       yes | `ApplicationRecord`  | `connects_to database: { writing: :com_setting, reading: :com_setting_replica }` | `com_setting`     | setting               | Com-side setting base.                                              |
| `ComSignalRecord`    | `app/models/com_signal_record.rb`    |       yes | `ApplicationRecord`  | `connects_to database: { writing: :com_signal, reading: :com_signal_replica }`   | `com_signal`      | signal                | Com-side signal base.                                               |
| `ComTicketRecord`    | `app/models/com_ticket_record.rb`    |       yes | `ApplicationRecord`  | `connects_to database: { writing: :com_ticket, reading: :com_ticket_replica }`   | `com_ticket`      | ticket                | Com-side ticket / token / ceremony base.                            |
| `OccurrenceRecord`   | `app/models/occurrence_record.rb`    |       yes | `ApplicationRecord`  | `connects_to database: { writing: :occurrence, reading: :occurrence_replica }`   | `occurrence`      | lifecycle / telemetry | Cross-cutting occurrence base.                                      |
| `OrgPrincipalRecord` | `app/models/org_principal_record.rb` |       yes | `ApplicationRecord`  | `connects_to database: { writing: :org_zenith, reading: :org_zenith_replica }`   | `org_zenith`      | principal semantics   | Org-side principal semantic base backed by consolidated org_zenith. |
| `OrgRpRecord`        | `app/models/org_rp_record.rb`        |       yes | `ApplicationRecord`  | `connects_to database: { writing: :org_zenith, reading: :org_zenith_replica }`   | `org_zenith`      | zenith                | Org-side RP / authority base.                                       |
| `OrgSettingRecord`   | `app/models/org_setting_record.rb`   |       yes | `ApplicationRecord`  | `connects_to database: { writing: :org_setting, reading: :org_setting_replica }` | `org_setting`     | setting               | Org-side setting base.                                              |
| `OrgSignalRecord`    | `app/models/org_signal_record.rb`    |       yes | `ApplicationRecord`  | `connects_to database: { writing: :org_signal, reading: :org_signal_replica }`   | `org_signal`      | signal                | Org-side signal base.                                               |
| `OrgTicketRecord`    | `app/models/org_ticket_record.rb`    |       yes | `ApplicationRecord`  | `connects_to database: { writing: :org_ticket, reading: :org_ticket_replica }`   | `org_ticket`      | ticket                | Org-side ticket / token / ceremony base.                            |
| `SearchRecord`       | `app/models/search_record.rb`        |       yes | `ApplicationRecord`  | `connects_to database: { writing: :search, reading: :search_replica }`           | `search`          | infrastructure        | Search base.                                                        |

## Model Inventory

### Principal semantic models in consolidated zenith storage

| model                                                                                                                         | file                                   | table                      | superclass / base record | current DB / connection | migration path              | semantic class | target placement | decision status | evidence                                 | notes                                                                                                                                                                                          |
| ----------------------------------------------------------------------------------------------------------------------------- | -------------------------------------- | -------------------------- | ------------------------ | ----------------------- | --------------------------- | -------------- | ---------------- | --------------- | ---------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Client`                                                                                                                      | `app/models/client.rb`                 | `clients`                  | `AppPrincipalRecord`     | `app_zenith`            | `db/app_principals_migrate` | authority      | target authority | transitional    | `AppPrincipalRecord` inheritance         | Runtime actor; retains credentials/session/contact/lifecycle state today inside the consolidated app zenith database.                                                                          |
| `Member`                                                                                                                      | `app/models/member.rb`                 | `members`                  | `AppPrincipalRecord`     | `app_zenith`            | `db/app_principals_migrate` | transitional   | future candidate | transitional    | `AppPrincipalRecord`; includes `Account` | Main ambiguity cluster. See `docs/architecture/principal-zenith-membership-organization-placement.md` and `adr/member-client-membership-organization-decomposition-before-placement.md`.       |
| `ClientMembership`                                                                                                            | `app/models/client_membership.rb`      | `client_memberships`       | `AppPrincipalRecord`     | `app_zenith`            | `db/app_principals_migrate` | transitional   | future candidate | transitional    | `AppPrincipalRecord`                     | Transitional membership join; see `docs/architecture/principal-zenith-membership-organization-placement.md` and `adr/member-client-membership-organization-decomposition-before-placement.md`. |
| `ClientAppleIdentity`                                                                                                         | `app/models/client_apple_identity.rb`  | `client_apple_identities`  | `AppPrincipalRecord`     | `app_zenith`            | `db/app_principals_migrate` | credential     | out of scope     | excluded        | `AppPrincipalRecord`                     | Credential-side row.                                                                                                                                                                           |
| `ClientGoogleIdentity`                                                                                                        | `app/models/client_google_identity.rb` | `client_google_identities` | `AppPrincipalRecord`     | `app_zenith`            | `db/app_principals_migrate` | credential     | out of scope     | excluded        | `AppPrincipalRecord`                     | Credential-side row.                                                                                                                                                                           |
| `ClientEmail`, `ClientTelephone`, `ClientPasskey`, `ClientSecretCredential`, `ClientTotpCredential` and related status tables | various                                | various                    | `AppPrincipalRecord`     | `app_zenith`            | `db/app_principals_migrate` | credential     | out of scope     | excluded        | `AppPrincipalRecord`                     | Credential/contact inventory remains semantically principal-side but physically consolidated into app zenith.                                                                                  |

### Zenith contents today

#### app_zenith

| model                                                                 | current zenith DB | semantic class | role today                | target placement | decision status | notes                                                     |
| --------------------------------------------------------------------- | ----------------- | -------------- | ------------------------- | ---------------- | --------------- | --------------------------------------------------------- |
| `Persona`                                                             | `app_zenith`      | authority      | canonical app account     | target authority | settled         | Account implementation for app.                           |
| `ClientIdentity`                                                      | `app_zenith`      | bridge         | RP/IdP identity binding   | target authority | settled         | Identity binding, not runtime actor and not account.      |
| `ClientAccount`                                                       | `app_zenith`      | bridge         | RP account projection     | target authority | settled         | Not the canonical account model from the domain glossary. |
| `PersonaAssignment`                                                   | `app_zenith`      | bridge         | account assignment        | target authority | settled         | Identity->Account access state.                           |
| `PersonaMembership`                                                   | `app_zenith`      | transitional   | collective membership     | candidate        | transitional    | Membership/history shape, not account authority.          |
| `Enterprise` / `EnterpriseUnit` / `EnterpriseUnitClosure`             | `app_zenith`      | authority      | organization side of app  | target authority | settled         | App-side organization hierarchy.                          |
| `DocsAppContentEntry` / `HelpAppContentEntry` / `NewsAppContentEntry` | `app_zenith`      | content        | read-only content         | current storage  | settled         | Read-only docs/help/news entries.                         |
| `ClientProfile` / `ClientProfileStatus`                               | `app_zenith`      | projection     | legacy/projection content | current storage  | unknown         | Transitional or legacy projection; keep under review.     |
| `CoreAppClientBridge`                                                 | `app_zenith`      | bridge         | Core RP bridge            | current storage  | settled         | RP bridge row, not authority placement.                   |

#### org_zenith

| model                                                                 | current zenith DB | semantic class | role today               | target placement | decision status | notes                                                                                                             |
| --------------------------------------------------------------------- | ----------------- | -------------- | ------------------------ | ---------------- | --------------- | ----------------------------------------------------------------------------------------------------------------- |
| `Agent`                                                               | `org_zenith`      | authority      | canonical org account    | target authority | settled         | Account implementation for org.                                                                                   |
| `OperatorIdentity`                                                    | `org_zenith`      | bridge         | RP/IdP identity binding  | target authority | settled         | Identity binding, not runtime actor and not account.                                                              |
| `OperatorAccount`                                                     | `org_zenith`      | bridge         | RP account projection    | target authority | settled         | Not the canonical account model from the domain glossary.                                                         |
| `AgentAssignment`                                                     | `org_zenith`      | bridge         | account assignment       | target authority | settled         | Identity->Account access state.                                                                                   |
| `AgentMembership`                                                     | `org_zenith`      | transitional   | collective membership    | candidate        | transitional    | Membership/history shape, not account authority.                                                                  |
| `Bureau` / `BureauUnit` / `BureauUnitClosure`                         | `org_zenith`      | authority      | organization side of org | target authority | settled         | Org-side organization hierarchy.                                                                                  |
| `DocsOrgContentEntry` / `HelpOrgContentEntry` / `NewsOrgContentEntry` | `org_zenith`      | content        | read-only content        | current storage  | settled         | Read-only docs/help/news entries.                                                                                 |
| `OperatorWorkspaceAccount` / `OperatorWorkspaceAccountMembership`     | `org_zenith`      | transitional   | legacy account surface   | candidate        | transitional    | Transitional naming and placement; see `docs/architecture/principal-zenith-membership-organization-placement.md`. |
| `CoreOrgOperatorBridge`                                               | `org_zenith`      | bridge         | Core RP bridge           | current storage  | settled         | RP bridge row, not authority placement.                                                                           |

#### com_zenith

| model                                                                 | current zenith DB | semantic class | role today               | target placement | decision status | notes                                                     |
| --------------------------------------------------------------------- | ----------------- | -------------- | ------------------------ | ---------------- | --------------- | --------------------------------------------------------- |
| `Individual`                                                          | `com_zenith`      | authority      | canonical com account    | target authority | settled         | Account implementation for com.                           |
| `VisitorIdentity`                                                     | `com_zenith`      | bridge         | RP/IdP identity binding  | target authority | settled         | Identity binding, not runtime actor and not account.      |
| `VisitorAccount`                                                      | `com_zenith`      | bridge         | RP account projection    | target authority | settled         | Not the canonical account model from the domain glossary. |
| `IndividualAssignment`                                                | `com_zenith`      | bridge         | account assignment       | target authority | settled         | Identity->Account access state.                           |
| `IndividualMembership`                                                | `com_zenith`      | transitional   | collective membership    | candidate        | transitional    | Membership/history shape, not account authority.          |
| `Company` / `CompanyUnit` / `CompanyUnitClosure`                      | `com_zenith`      | authority      | organization side of com | target authority | settled         | Com-side organization hierarchy.                          |
| `DocsComContentEntry` / `HelpComContentEntry` / `NewsComContentEntry` | `com_zenith`      | content        | read-only content        | current storage  | settled         | Read-only docs/help/news entries.                         |
| `CoreComVisitorBridge`                                                | `com_zenith`      | bridge         | Core RP bridge           | current storage  | settled         | RP bridge row, not authority placement.                   |

### Avatar contents today

| model                                                                                                                                                                                  | current DB | semantic class   | role                            | target placement | decision status        | notes                                                 |
| -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------- | ---------------- | ------------------------------- | ---------------- | ---------------------- | ----------------------------------------------------- |
| `Avatar`                                                                                                                                                                               | `avatar`   | avatar_authority | SNS actor                       | current storage  | settled for this phase | Separate actor-authority boundary.                    |
| `AvatarAssignment`                                                                                                                                                                     | `avatar`   | avatar_authority | avatar RBAC                     | current storage  | settled for this phase | Keep separate from account bridge layers.             |
| `AvatarMembership`                                                                                                                                                                     | `avatar`   | transitional     | temporal participation/history  | current storage  | settled for this phase | Not the Avatar/account bridge.                        |
| `AvatarOwnershipPeriod`                                                                                                                                                                | `avatar`   | transitional     | owner history                   | current storage  | settled for this phase | Ownership history remains in avatar.                  |
| `AvatarPersonaBinding`                                                                                                                                                                 | `avatar`   | bridge           | Avatar->Account binding         | current storage  | settled for this phase | Explicit additive bridge remains in avatar.           |
| `AvatarAgentBinding`                                                                                                                                                                   | `avatar`   | bridge           | Avatar->Agent binding           | current storage  | unknown                | Present but not part of the current placement target. |
| `AvatarIndividualBinding`                                                                                                                                                              | `avatar`   | bridge           | Avatar->Individual binding      | current storage  | unknown                | Present but not part of the current placement target. |
| `AvatarMoniker` / `Handle` / `HandleAssignment`                                                                                                                                        | `avatar`   | avatar_authority | mutable identity / handle state | current storage  | settled for this phase | Avatar naming/handle lifecycle.                       |
| `AvatarFollow` / `AvatarBlock` / `AvatarMute`                                                                                                                                          | `avatar`   | social_graph     | Avatar-to-Avatar state          | current storage  | settled for this phase | Keep social graph within avatar.                      |
| `MemberAvatarAccess` / `MemberAvatarVisibility` / `MemberAvatarOversight` / `MemberAvatarExtraction` / `MemberAvatarImpersonation` / `MemberAvatarSuspension` / `MemberAvatarDeletion` | `avatar`   | bridge           | member-to-avatar governance     | current storage  | transitional           | Legacy governance/oversight rows tied to avatar.      |

### Content / info / public document models

| model                 | current DB   | semantic class | role              | target placement | decision status | notes                        |
| --------------------- | ------------ | -------------- | ----------------- | ---------------- | --------------- | ---------------------------- |
| `DocsAppContentEntry` | `app_zenith` | content        | read-only content | current storage  | settled         | App-side docs content entry. |
| `HelpAppContentEntry` | `app_zenith` | content        | read-only content | current storage  | settled         | App-side help content entry. |
| `NewsAppContentEntry` | `app_zenith` | content        | read-only content | current storage  | settled         | App-side news content entry. |
| `DocsOrgContentEntry` | `org_zenith` | content        | read-only content | current storage  | settled         | Org-side docs content entry. |
| `HelpOrgContentEntry` | `org_zenith` | content        | read-only content | current storage  | settled         | Org-side help content entry. |
| `NewsOrgContentEntry` | `org_zenith` | content        | read-only content | current storage  | settled         | Org-side news content entry. |
| `DocsComContentEntry` | `com_zenith` | content        | read-only content | current storage  | settled         | Com-side docs content entry. |
| `HelpComContentEntry` | `com_zenith` | content        | read-only content | current storage  | settled         | Com-side help content entry. |
| `NewsComContentEntry` | `com_zenith` | content        | read-only content | current storage  | settled         | Com-side news content entry. |

### Token / Session / Ceremony / OAuth Transaction Models

| model                                                                                                                                                                                                                                                                                        | current DB   | semantic class                       | reason excluded                                  | notes                                                                                    |
| -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------ | ------------------------------------ | ------------------------------------------------ | ---------------------------------------------------------------------------------------- |
| `LogoutTransaction`                                                                                                                                                                                                                                                                          | `app_ticket` | session_token                        | Explicitly out of scope for this placement pass. | Browser-facing logout state remains excluded.                                            |
| `AcmeLogoutTransaction`                                                                                                                                                                                                                                                                      | `app_ticket` | session_token                        | Explicitly out of scope for this placement pass. | Local logout transport state remains excluded.                                           |
| `ClientAuthorizationCode`, `ClientOidcAuthorizationTransaction`, `ClientOidcConnection`, `ClientDeviceSession`, `ClientToken`, `ClientStepUpSession`, `ClientSignInFlow`, `ClientSignOutFlow`, `ClientSignUpFlow`, `ClientVerification`, and related `app_ticket` models                     | `app_ticket` | ceremony_transaction / session_token | Explicitly out of scope for this placement pass. | Principal-side lifecycle and ceremony storage remains separate from authority placement. |
| `OperatorAuthorizationCode`, `OperatorOidcAuthorizationTransaction`, `OperatorOidcConnection`, `OperatorDeviceSession`, `OperatorToken`, `OperatorStepUpSession`, `OperatorSignInFlow`, `OperatorSignOutFlow`, `OperatorSignUpFlow`, `OperatorVerification`, and related `org_ticket` models | `org_ticket` | ceremony_transaction / session_token | Explicitly out of scope for this placement pass. | Org-side lifecycle and ceremony storage remains separate from authority placement.       |
| `VisitorAuthorizationCode`, `VisitorOidcAuthorizationTransaction`, `VisitorOidcConnection`, `VisitorDeviceSession`, `VisitorToken`, `VisitorStepUpSession`, `VisitorSignInFlow`, `VisitorSignOutFlow`, `VisitorSignUpFlow`, `VisitorVerification`, and related `com_ticket` models           | `com_ticket` | ceremony_transaction / session_token | Explicitly out of scope for this placement pass. | Com-side lifecycle and ceremony storage remains separate from authority placement.       |

## Ambiguous / Transitional Ownership

| item                                                                                   | current placement          | why ambiguous                                                                                            | possible target                | decision needed                                                                                           | risk   |
| -------------------------------------------------------------------------------------- | -------------------------- | -------------------------------------------------------------------------------------------------------- | ------------------------------ | --------------------------------------------------------------------------------------------------------- | ------ |
| `Member`                                                                               | `app_zenith`               | Transitional account-like row still using principal semantics inside consolidated zenith storage.        | zenith or retired bridge layer | Whether it should remain as a legacy bridge or be replaced by a settled account model.                    | High   |
| `ClientMembership`                                                                     | `app_zenith`               | Membership join still uses principal semantics, but its semantic boundary is not settled.                | zenith or transitional         | Whether this is authority, membership history, or a compatibility bridge.                                 | High   |
| `Organization`                                                                         | `org_zenith`               | Current org principal hierarchy container now physically consolidated into zenith.                       | zenith                         | Whether the current `Organization` model is authoritative or transitional.                                | High   |
| `OperatorWorkspaceAccount` / `OperatorWorkspaceAccountMembership`                      | `org_zenith`               | Transitional naming and account semantics do not cleanly match the target model vocabulary.              | zenith or retirement           | Whether this is the final org account model or a bridge.                                                  | Medium |
| `ClientProfile` / `ClientProfileStatus`                                                | `app_zenith`               | Legacy/projection shape; current domain role is not fully settled.                                       | current storage or retirement  | Whether this is a projection, replacement candidate, or dead-end compatibility layer.                     | Medium |
| `AvatarAgentBinding`                                                                   | `avatar`                   | Present in avatar DB, but outside the current Avatar->Persona placement target.                          | unknown                        | Whether this belongs to a future Avatar->Agent bridge or should remain isolated.                          | Medium |
| `AvatarIndividualBinding`                                                              | `avatar`                   | Present in avatar DB, but outside the current Avatar->Persona placement target.                          | unknown                        | Whether this belongs to a future Avatar->Individual bridge or should remain isolated.                     | Medium |
| `Avatar` organization fields (`owner_organization_id`, `representing_organization_id`) | `avatar`                   | Field semantics are not fully resolved by the current placement docs.                                    | avatar or later org policy     | Whether these are authoritative ownership/representation markers or transitional data.                    | Medium |
| `CoreAppClientBridge`, `CoreOrgOperatorBridge`, `CoreComVisitorBridge`                 | zenith-side projection DBs | RP bridge records, not authority records, but their relationship to future placement is easy to misread. | keep current                   | Whether future docs should mention them only as bridge records or give them a separate inventory section. | Low    |

## Current vs Target Summary

| area                            | current placement                                                                            | target placement                                                    | status                  |
| ------------------------------- | -------------------------------------------------------------------------------------------- | ------------------------------------------------------------------- | ----------------------- |
| Principal authority             | semantic principal models backed by `app_zenith` / `org_zenith` / `com_zenith`               | `zenith` for authority data, with ticket/session/token out of scope | physically consolidated |
| Regional-ready application data | future principal placement candidate                                                         | `principal` first, later regional extraction                        | candidate               |
| Identity binding                | `app_zenith` / `org_zenith` / `com_zenith`                                                   | `zenith`                                                            | settled                 |
| Account authority               | `app_zenith` / `org_zenith` / `com_zenith`                                                   | `zenith`                                                            | settled                 |
| Organization authority          | semantic principal hierarchy plus hierarchy/projection models in consolidated zenith storage | `zenith`                                                            | ambiguous               |
| Avatar authority                | `avatar`                                                                                     | `avatar`                                                            | settled for this phase  |
| Avatar social graph             | `avatar`                                                                                     | `avatar`                                                            | settled for this phase  |
| Token/session/ceremony          | mixed across `app_ticket`, `org_ticket`, `com_ticket`                                        | out of scope                                                        | excluded                |
| Public content/info             | `app_zenith` / `org_zenith` / `com_zenith`                                                   | current storage                                                     | settled                 |

## Findings

Principal connection keys are retained but intentionally empty. Runtime actors, credentials,
lifecycle columns, and transitional rows now live in the matching consolidated zenith databases
through semantic principal base classes.

`zenith` already contains the account and identity-binding graph for all three surfaces, plus
read-only content rows and RP bridge rows. That graph is the clearest target authority store for
Account and Identity placement.

`principal` is reserved for future regional-ready application data, not canonical Principal
authority ownership.

Avatar is still a separate actor-authority boundary. `Avatar`, `AvatarAssignment`,
`AvatarMembership`, `AvatarOwnershipPeriod`, and `AvatarPersonaBinding` remain in `avatar`, and the
social graph (`AvatarFollow`, `AvatarBlock`, `AvatarMute`) also stays there.

The most dangerous ambiguities are `Member`, `ClientMembership`, `Organization`, the
`OperatorWorkspaceAccount` family, `Client`, `Visitor`, `Operator`, and the credential/contact/
recovery rows plus OIDC connection rows. `Avatar` organization-related fields are also ambiguous and
should not be overread as settled authority signals. The retained principal role does not decide
their final placement by itself.

Do not touch token/session/ceremony/logout/OAuth transaction placement in the next implementation
pass. Those rows are intentionally excluded from this authority inventory.

New regional-ready models placed in `principal` should be designed for later extraction. Use an
explicit regional or extraction-friendly scope where appropriate, avoid accidental global uniqueness
requirements, and do not treat `principal` as the canonical authority boundary.

Do not place new global authority models in `principal` merely because the database name is
`principal`. Authority ownership must follow the semantic role of the data, not the retained storage
label.

## Future Work Checklist

- [ ] Decide `Member`, `ClientMembership`, and `Organization` placement.
- [ ] Audit principal credential/session/token rows separately from authority placement.
- [ ] Audit OIDC connection placement separately.
- [ ] Verify zenith account and identity graph completeness.
- [ ] Keep Avatar relocation out of this migration unless a later ADR changes it.
- [ ] Consider a machine-generated inventory if future drift becomes a recurring problem.
- [ ] Consider a CI check that prevents new authority models from being added to principal
      accidentally.

## Validation

- `git diff --check` completed cleanly.
- `git diff --stat` was inspected before finalizing.
- `docs/index.md` now links the new inventory doc.
- No application code, schema, migration, route, controller, service, or test files were changed by
  this docs inventory pass.
