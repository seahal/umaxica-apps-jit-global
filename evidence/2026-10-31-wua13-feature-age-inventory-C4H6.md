# Feature-age source inventory

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained extensive uncommitted changes, including the document updated here.
- Searches for `AgeEligibility`, `minimum_age_reached?`, `adult_for_nsfw?`, `nsfw_unlockable?`, adult-content gate, birthdate and age-restriction terms in application code, frontend source and routes found the helper definitions in `HasBirthdate` and `AgeEligibility`, signup and identity uses of birthdate, and adult-content preference models. They found no application calls to those three feature-age helpers outside their definitions.
- `Auth::Org::Sign::Up::InvitationsController#create` currently rejects every invitation after the Turnstile check. The policy document was updated to distinguish the shared ORG rule from the closed workflow.
- `PARALLEL_WORKERS=1 bin/rails test test/services/sign_up_eligibility_policy_test.rb test/services/age_eligibility_test.rb test/models/concerns/has_birthdate_test.rb`: 46 runs, 224 assertions, 0 failures, 0 errors, 0 skips.
- Text searches cannot establish the inventory of deployed or external products, indirect calls, or feature-owner requirements. They do not complete the pre-release review. The full suite was not run.
