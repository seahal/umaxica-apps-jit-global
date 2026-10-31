# WU-7 com preference diagram inventory correction

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. Staged, unstaged and untracked worktree changes
affected the review.

The Mermaid README described the historical visitor preference DBSC axis as partial and linked to
a removed path, although the anonymous com model and current com setting dump no longer have that
axis. Its transition inventory also described all com databases as deleted. Updated the row to
retired with the existing archived diagram path and clarified that com setting and Chronicle remain.
The new com Preference status diagram and the implementation were not changed.

`git diff --check` passed for the two edited documentation files. A local path check confirmed the
retired row points to the existing archived diagram and the old root path is absent. No application
tests or migrations were run for this documentation-only change; WU-7 remains incomplete.
