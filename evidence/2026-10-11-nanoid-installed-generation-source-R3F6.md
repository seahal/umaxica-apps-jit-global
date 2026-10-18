# Installed NanoID generation mechanism

HEAD: `7381e6325fc30d2ba368697b396b776628bfd4e9`. ORG Telephone application/query/task/test changes
and unrelated source-policy changes remain uncommitted. The legacy-inventory Rails full gate was
live during this read-only dependency inspection; no next feature edit occurred.

`bundle show nanoid` exited 0 and identified installed nanoid 2.0.0. Gemfile.lock also resolves
2.0.0 with its recorded checksum. The actual installed `lib/nanoid.rb` was read, not inferred from
an old prompt or a random-sample test. Its public generate API has defaults size 21, the
64-character URL-safe alphabet `_ - 0–9 a–z A–Z` (without spaces), and non_secure=false. The default
simple path obtains bytes through SecureRandom.random_bytes and selects the 64-character alphabet
with the low-six-bit mask. The explicit non_secure=true path uses Random.rand and is not the
approved standard mechanism. No custom alphabet or post-generation case conversion is required here.

PublicId currently calls that dependency with GENERATION_SIZE=21. Source searches found additional
direct Nanoid generation in the three Preference models, ClientTotpCredential, RpSession and the new
ORG Telephone backfill operation. Their standard size literals do not establish completion of the
shared-generation requirement. Centralization and producer/public-boundary regressions remain the
next implementation slice after Gate 2, without changing identifier meaning or reissuing old values.
This inspection does not prove collision handling, bulk-writer behavior, database immutability,
distributed uniqueness or random-quality properties beyond the observed dependency implementation.
No library version/pinning, configuration, application or test code was changed.

No external research, service call, actual secret, production/shared mutation or push was involved.
This evidence records the installed source at this revision rather than a perpetual dependency
guarantee. Rails Gate 2 remains pending and no feature may advance before its result is inspected.
