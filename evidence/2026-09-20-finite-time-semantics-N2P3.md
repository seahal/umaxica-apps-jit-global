# Finite authentication and retention time semantics

Date: 2026-09-20

## Scope

This slice covers the public expiry predicates in `Retainable`,
`TokenStatusManagement`, and `RefreshTokenable`. It does not claim completion
of the broader database reconstruction or the approved lifecycle-column rename.

## Verification

The first focused RED run exercised 40 tests and 153 assertions and reported 3
failures and 1 error. The error was caused by attempting to insert `NULL` into
an existing database `NOT NULL` expiry column; the corrected test represents
the invalid `NULL` value through the public predicate boundary without
changing the schema.

The corrected GREEN run completed with:

```text
40 runs, 167 assertions, 0 failures, 0 errors, 0 skips
```

The existing coverage-threshold test that treated a missing refresh-token
expiry as usable was updated to the accepted security contract. Its focused
verification completed with:

```text
4 runs, 67 assertions, 0 failures, 0 errors, 0 skips
```

The Rails full suite after the correction completed with:

```text
11400 runs, 72953 assertions, 0 failures, 0 errors, 5 skips
```

## Result

Negative infinity and missing authentication-token expiry values no longer
produce a usable state. Positive infinity remains reserved for explicitly
timeless retention periods. Future finite expiry values remain usable until
their boundary, while finite past values are expired or due. No broad schema
constraint or retention-column rename was introduced by this slice.

The suite also emitted existing OmniAuth test diagnostics and Ruby constant
reinitialization warnings; they did not produce test failures or errors.
