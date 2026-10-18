# Unbound logout continuation refusal in every realm

Recorded 2026-10-15 UTC against commit `7d4e2d941f4eb576eb77076c2c2a4e54badfa847`, with uncommitted
application/test/documentation changes.

REQ-006/REQ-009 require captured browser intent for continuation and truthful completion. Extended
the twelve-client HTTP completion matrix with token-valid POSTs lacking browser intent proof. It
reproduced Core COM returning 200 completion instead of refusal. Removing the non-APP completion
substitution from the shared ERB renderer then exposed the equivalent Warp COM Inertia substitution.
Both renderers now return unavailable/422 for every realm.

The matrix verifies refusal without transaction advancement, then installs the legitimate bound
proof and verifies the existing successful continuation for every registered client. Red runs: 1 run
/ 72 assertions / 1 failure (Core COM), then 1 run / 166 assertions / 1 failure (Warp COM). Green
matrix: 1 run / 411 assertions / no failures, errors or skips.

The broader selection of completion matrix, authority-first logout, Tech completion and Palm
completion passed 8 runs / 654 assertions / 0 failures / 0 errors / 0 skips using standard Rails
test databases with the isolated-run identifier unset. No reset or isolated fleet was used. Targeted
lint exposed pre-existing indentation in SignOutInertiaPages; formatting was corrected. This closes
the reproduced response defect, not the remaining full authority-flow matrix or external/manual
acceptance.
