# Identifier purge and normalized reuse races

Commit: `48ff7040de2b50a8a08ed660fa71878a029ba577`.
Uncommitted worktree changes affected this verification.

`bin/rails test test/operations/dead_identifier_purge_concurrency_test.rb`
passed with 12 runs, 76 assertions, no failures, errors or skips (seed 38657).
The six new cases exercise APP/COM/ORG email and telephone equivalent-identifier
creation racing with irreversible purge. Each checks exactly one old-owner history,
physical deletion, successful eventual reuse, and no replacement-owner history.
The existing six concurrent duplicate-purge cases remain enabled.

Initial runs exposed test construction errors: duplicate validation can reject before
the database uniqueness constraint, and contact destruction advances an owner's
optimistic lock. Tests now recognize only the channel's `taken` validation error
and reload the owner before cleanup. Other validation failures still propagate.
No application uniqueness constraint or lifecycle behavior was weakened.

Focused RuboCop inspected one file, corrected six formatting offenses, and exited
successfully with all detected offenses corrected. Full-suite verification and
complete ceremony integration remain outstanding.

The broader command adding `test/models/dead_identifier_destroy_test.rb`,
`test/models/dead_identifier_history_contract_test.rb`,
`test/operations/dead_identifier_purge_test.rb` and
`test/jobs/dead_identifier_retention_test.rb` passed 49 runs/267 assertions,
zero failures, errors or skips (seed 16820).

The existing lifecycle-direct-write, CSRF strategy, standard CSRF, identity-authority
inversion and WebAuthn invariant files passed together: 24 runs/129 assertions,
zero failures, errors or skips (seed 6955). These selected guards are not a claim
that all repository harnesses or the full Rails suite have passed.

The five ceremony primitive files, authentication-mode inventory and route authority inventory
ran together: 54 runs/292 assertions, one failure, no errors or skips (seed 16639).
`AuthBoundaryAuthorityInventoryTest` expects seven RP clients, while the canonical map lists ten.
Both that test and `app/values/auth_boundary_authority_map.rb` have no worktree diff; inspecting
the map at HEAD confirms the same ten entries. This is a pre-existing inventory mismatch, not
an identifier change. It remains failed final-verification evidence and was not relaxed.
