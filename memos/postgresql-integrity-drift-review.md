# Global PostgreSQL Snapshot Drift Review

Read-only live development catalog captured at 2026-09-24T10:25:33Z against commit `2b027d5b38989d3068e4620262bfa6c6fde8df41` with uncommitted changes. This compares table and Rails migration-version identities; it does not assert equivalence of columns, constraints, indexes, or data.

| Logical DB | Live tables | Dump tables | Live-only tables | Dump-only tables | Live versions | Dump versions | Version differences |
| --- | ---: | ---: | --- | --- | ---: | ---: | --- |
| app_setting | 29 | 29 | none | none | 9 | 9 | none |
| app_signal | 4 | 4 | none | none | 3 | 3 | none |
| app_ticket | 40 | 40 | none | none | 77 | 84 | dump-only: 20260924150000, 20260924151000, 20260924152000, 20260924153000, 20260924154000, 20260924155000, 20260924156000 |
| app_zenith | 113 | 113 | none | none | 364 | 364 | none |
| avatar | 47 | 47 | none | none | 40 | 40 | none |
| chronicle | 60 | 60 | none | none | 20 | 20 | none |
| com_setting | 29 | 29 | none | none | 8 | 8 | none |
| com_signal | 3 | 3 | none | none | 3 | 3 | none |
| com_ticket | 28 | 28 | none | none | 69 | 76 | dump-only: 20260924150000, 20260924151000, 20260924152000, 20260924153000, 20260924154000, 20260924155000, 20260924156000 |
| com_zenith | 84 | 84 | none | none | 97 | 97 | none |
| occurrence | 54 | 54 | none | none | 116 | 116 | none |
| org_setting | 29 | 29 | none | none | 8 | 8 | none |
| org_signal | 4 | 4 | none | none | 3 | 3 | none |
| org_ticket | 29 | 29 | none | none | 58 | 65 | dump-only: 20260924150000, 20260924151000, 20260924152000, 20260924153000, 20260924154000, 20260924155000, 20260924156000 |
| org_zenith | 99 | 99 | none | none | 261 | 261 | none |
| primary | 8 | 8 | none | none | 2 | 2 | none |
| publishing | 159 | 159 | none | none | 4 | 4 | none |
| queue | 15 | 15 | none | none | 5 | 5 | none |
| search | 2 | 2 | none | none | 0 | 0 | none |
| storage | 2 | 2 | none | none | 0 | 0 | none |

## Runtime model mappings absent from shared development

A verified isolated Rails boot mapped 741 concrete models. 12 application models target tables absent from the shared development catalog and current dumps; they are supplied by pending local migrations. Framework models whose optional tables are absent are excluded from this list. No shared database was migrated.

- `AgentAuthorityCutover`: `org_zenith.public.agent_authority_cutovers` (app/models/agent_authority_cutover.rb)
- `AgentLifecycle`: `org_zenith.public.agent_lifecycles` (app/models/agent_lifecycle.rb)
- `BureauAuthorityCutover`: `org_zenith.public.bureau_authority_cutovers` (app/models/bureau_authority_cutover.rb)
- `BureauLifecycle`: `org_zenith.public.bureau_lifecycles` (app/models/bureau_lifecycle.rb)
- `ClientPersonaAuthorityCutover`: `app_zenith.public.client_persona_authority_cutovers` (app/models/client_persona_authority_cutover.rb)
- `ClientPersonaLifecycle`: `app_zenith.public.client_persona_lifecycles` (app/models/client_persona_lifecycle.rb)
- `CompanyAuthorityCutover`: `com_zenith.public.company_authority_cutovers` (app/models/company_authority_cutover.rb)
- `CompanyLifecycle`: `com_zenith.public.company_lifecycles` (app/models/company_lifecycle.rb)
- `EnterpriseAuthorityCutover`: `app_zenith.public.enterprise_authority_cutovers` (app/models/enterprise_authority_cutover.rb)
- `EnterpriseLifecycle`: `app_zenith.public.enterprise_lifecycles` (app/models/enterprise_lifecycle.rb)
- `IndividualAuthorityCutover`: `com_zenith.public.individual_authority_cutovers` (app/models/individual_authority_cutover.rb)
- `IndividualLifecycle`: `com_zenith.public.individual_lifecycles` (app/models/individual_lifecycle.rb)
