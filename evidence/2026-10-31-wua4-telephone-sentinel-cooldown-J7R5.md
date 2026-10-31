# Telephone credential-registration cooldown sentinel

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted application and test changes.
- The issuer file passed before the change (6 runs, 49 assertions). Injecting the already representable `-infinity` timestamp produced `ArgumentError` for APP and ORG (8 focused cases, 28 assertions, 2 errors).
- The issuer now recognizes the same negative-infinity timestamp already handled by Telephone signup before comparing against Time. Both realms' never-sent, 29-second, 30-second and 31-second cases passed (8 runs, 38 assertions), including no transaction or cooldown change on refusal.
- The issuer, verification, finalization, ORG registration controller and APP Telephone signup controller files passed together (112 runs, 1,081 assertions). After formatting-only edits, the eight focused cases passed again (38 assertions). Scoped RuboCop and `git diff --check` passed.
- No schema or data migration was performed. The existing nullable column and its NULL-dependent code remain unresolved and require the separately documented shape review. Real SMS delivery was not tested.
