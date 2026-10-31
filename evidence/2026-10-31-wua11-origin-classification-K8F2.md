# Surface redirect origin classification

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree had extensive uncommitted changes.
- Source inspection of `CommonRedirect#redirect_to_surface_url` found its absolute-URL local branch compares `uri.host` with `request.host` and checks userinfo, but does not compare scheme or port. It then redirects to `uri.request_uri`. The separate `request_origin_url?` compares scheme, host and port.
- `two.md` §3.11 specifies local paths for same-origin destinations and Jump for other origins on an existing allowed edge. The before/after proposal and its client and registry dependencies are recorded in `four.md`.
- No public HTTP reproduction, changed response, external Jump deployment or full-suite test was performed. No implementation or API shape was changed.
