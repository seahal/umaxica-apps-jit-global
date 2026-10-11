# Runtime reachability and observability verification

- Date: 2026-09-17 UTC
- Branch: `feature`
- Scope: runtime checks for the intentional dashboard/domain-hub links and the
  `request_id`/OpenTelemetry correlation boundary.

## Reachability

- The app/com/org dashboard, Preference, Identity read-only, and PWA reachability subset passed: 110
  runs / 2,957 assertions / 0 failures / 0 errors / 0 skips.
- The larger set that also included the app Identity authority slice reached 111 runs / 2,957
  assertions; its only error was the sign-out notice's unavailable Valkey service. It did not report
  a dashboard, Preference, Identity read-only, or PWA assertion failure.
- Dashboard tests retained only high-level Preference/Billings/Groups/Offline links as applicable;
  child Preference pages remained under the Preference hub.

## Observability

- The resolver, Lograge configuration callable, Actor support, and static invariant tests passed: 40
  runs / 110 assertions / 0 failures / 0 errors / 0 skips.
- The Lograge test now invokes the configured custom-options callable directly because Lograge is
  intentionally disabled in the test environment; this tests the same configured payload logic
  without enabling production access logging in tests.
- The Actor test suite emits warnings while intentionally replacing the OpenTelemetry constant in
  its missing-SDK branch. The suite still passed; no production configuration was changed.

No browser runtime, deployed Cloudflare Worker, production OpenTelemetry collector, external
provider, migration, or non-test datastore was used. The sign-out Valkey failure and full deployed
request lifecycle remain unverified under CF-002.
