# Base Dashboard image authentication refusal

Performed 2026-10-04, recorded 05:34 UTC (Etc/UTC).
Rails feature HEAD f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5, 412 dirty paths
at capture, including concurrent work. Results include uncommitted changes and
are not CI results. No deployment or shared DB operation ran.

## Confirmed defect and change

Anonymous app/org GET /dashboard/avatar_image returned 302 to local /sign, including
an actual image Accept/Fetch Metadata representation. This non-document endpoint
must not feed an interactive login document to an image consumer.

Both controllers retain their private mode and existing resource authorization.
They opt out of interactive authentication redirect using AuthenticationBase's
protected response extension. The default remains enabled everywhere else.
The actual callback path is enforce_access_policy! -> enforce_authentication_private!
-> bodyless 401; this is distinct from the explicit authenticate! path, which uses
the same response extension. JSON retains its existing private-gate error. No
credential resolver, login, Jump, Cookie or admission mechanism was replaced.

App's image-local authenticate_client! callback was redundant with PreAccessController
and removed. The inherited callback and private mode gate remain. No authentication
or authorization skip was added. Authenticated image reads, ETag/revalidation,
invalid selection, normal org absence 404 and storage failure handling are unchanged.
com has no Dashboard Avatar image endpoint.

## Verification

Used `bundle exec ruby /tmp/umaxica-registration-fresh-db-task.rb test <paths>`
against only the guarded codex_integrity_20261004registration_* disposable fleet.

- Red: new public HTTP boundary file, 3 tests/3 assertions, 2 failures for the
  app/org 302 responses; com absence passed. No environment failure counted Red.
- An intermediate authenticate!-only response change failed because the private
  mode gate uses its separate response method. The actual private-mode branch
  was then connected to the same protected extension.
- An intermediate header test reached the existing Inertia version mismatch 409.
  Authentication cases now send the configured version; a separate case confirms
  mismatch still reloads the image endpoint rather than opening Sign. No adapter
  check was disabled or converted into successful authentication.
- Image boundary, Base Dashboard guidance and both authenticated image suites:
  **40 tests, 373 assertions, zero failures/errors/skips**.
- Related regression additionally included app/com Auth Passkey and org local
  Dashboard journeys, local authentication, Jump return/configuration/JWKS,
  Inertia and authentication-mode/forbidden-pattern invariants:
  **97 tests, 964 assertions, zero failures/errors/skips**.
- Final focused image boundary after adding version-mismatch refusal assertions:
  **3 tests, 117 assertions, zero failures/errors/skips**. It covers image/HTML/
  valid Inertia GET and HEAD, existing JSON GET/HEAD, no Location, no login
  challenge, no admission or token creation, and the existing mismatch reload.
- Plain `bundle exec rubocop` on AuthenticationBase, both image controllers,
  the new boundary test and both existing image tests: six files, no offenses
  after visibility/hash-format corrections. No suppression or gate reduction.
- `git diff --check`: PASS before this record.

The image-delivery ADR and Base/Auth architecture reference describe the response
clarification and why the previous redirect/non-200 expectations were replaced.

NOT_RUN: real-browser image/login integration, CDN routing/cache verification,
full suite or full audit of every other protected Base resource. The related
journeys use their existing synthetic protocol/transport boundaries; local HTTP
success does not prove external Jump gateway/browser completion. This slice does
not complete the Secret, Chronicle/purge or conditional refresh workstreams.
