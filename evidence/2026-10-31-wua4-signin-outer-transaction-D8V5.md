# Sign-in resend nested occurrence transaction probes

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had substantial uncommitted changes affecting the inspected implementation.
- The existing non-transactional concurrency file passed before the probes: 2 runs, 9 assertions.
- A temporary non-transactional dummy-contact probe wrapped the resender in an outer `EmailOccurrence.transaction`, observed its successful response and occurrence row inside that transaction, and rolled it back. The occurrence row disappeared while the new Auth generation remained: 1 run, 4 assertions.
- A separate temporary real-contact probe observed the same result and verified that an injected delivery adapter was called before the outer rollback: 1 run, 4 assertions. The probe did not call a real mail provider. Each probe cleaned up its synthetic records. The temporary files were not added to the repository.
- A third non-transactional real-contact probe used an outer Auth transaction instead. The adapter was called and the occurrence persisted, but rolling back the outer Auth transaction restored the prior generation: 1 run, 4 assertions. Its synthetic records were cleaned up.
- These observations contradict the required generation-commit and cooldown-commit ordering under outer transactions. No corrective implementation, production caller nesting, real transport or uncertain commit outcome was verified here.
