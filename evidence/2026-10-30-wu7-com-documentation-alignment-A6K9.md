# WU-7 current com documentation alignment

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree contained staged, unstaged and untracked changes affecting this review.
- Compared the Preference architecture and behavior documents with the current `PreferenceBrowserControlsRegistry`, com controllers, cookie-name and JWT codec, `PreferenceClassRegistry`, and com write boundary. Corrected claims that a VisitorPreference still exists, that Warp/Auth/Core com serve preference write endpoints, that com uses the app/org refresh-token shape, and that historical app query counts establish com behavior.
- Updated the com status diagram and transition inventory to describe the enclosing Chronicle transaction and the remaining separate-commit failure window. `git diff --check` passed for the four changed documentation files. A Mermaid renderer was not available, so the diagram was not rendered.
- The test Chronicle data-loss incident remains unresolved; no fixture-based Rails test, migration or full suite was run. These documentation edits do not establish completion of WU-7 or WU-9.
