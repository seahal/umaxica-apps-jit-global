# WU-9 local shape preflight refresh

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree had extensive pre-existing staged, unstaged, and untracked changes; no commit or destructive database operation was performed.
- Read-only `bin/rails runner -` inventories ran in development and test. Development APP/ORG setting and Zenith Preference parents and child rows were all 0. Test APP and ORG anonymous parents each had 2 rows; APP had 1 theme child, while ORG had 2 cookie children and 1 theme child. Test Client and Operator parents each had 2 rows, with 2 each of language, region, theme, and timezone children. Other Preference child and supplemental receipt/binding/Web Push rows were 0. Existing option and reference catalog rows were retained.
- In test APP/ORG anonymous parents, `jti` was NULL on 2 rows per realm; legacy `used_at`, `replaced_by_id`, and DBSC fields were NULL on both rows per realm. In test ORG, both cookie rows had NULL `consent_version` and `consented_at`. Test Client/Operator `explicit_fields` had 0 NULL rows. These are local test records and values, not production observations.
- Created fresh custom-format, no-owner/no-privileges snapshots of all eight local development/test setting and Zenith databases under `/tmp/wu9-preference-shape-approval-20261031-refresh/`. `pg_restore --list` succeeded for each archive.
- Snapshot SHA-256 / bytes:
  - `development_app_setting_db`: `19c5e7af1e26d236c61853a37aabde63eed1c27def6d81d32126c2c6d355470d` / 109206
  - `development_org_setting_db`: `5ba9d1b34b2684f1307c1eb2623e46071b7c406d9c9a52945ceb821f0fb86b98` / 109239
  - `development_app_zenith_db`: `967423247c170121cf24b3fe8361f5e0441810789fe39e3c7ec0b037e724b03b` / 550397
  - `development_org_zenith_db`: `5a876a7739d78f4df97ae476db29c006dba0dbea52c73c34926c10a52b223f81` / 444463
  - `test_app_setting_db`: `d2956c1227a31b3a8934bdbc5d60158bb523aab012bccafafbc77943f473c17b` / 109849
  - `test_org_setting_db`: `a4e342227c1657334b1abb5b630ba40e359402c55a337d919efe7744edc0d56c` / 109877
  - `test_app_zenith_db`: `f9632b1a280affb1d559be55d79e261e6f9a1a05d7fdcc92c3f48efb43ee861c` / 566263
  - `test_org_zenith_db`: `05e068f40124f15a85e1e403f97940426fb9f0332f5df051b8288371d1a89917` / 451736
- No production, Neon, external repository, or DNS resource was accessed.
