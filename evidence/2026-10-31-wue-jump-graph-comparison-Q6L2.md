# Jump graph source comparison

- Rails HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The Rails worktree contained uncommitted changes affecting the policy inspected.
- Compared the namespace pairs in the current `app/policies/jump_rt_return_policy.rb` `EDGE_CATALOG` with the pairs in `/tmp/two-wue-inspection/jump/src/config/registry.umaxica.ts`, whose inspected checkout is `0678dfb4027d3ff47e1a8731b9d6f0d4dd038cb0`. The comparison mapped each Jump node's first two hyphen-separated parts to its corresponding Rails namespace; it did not compare resolved origins, path handling, keys, or deployed revisions.
- Rails listed 46 distinct pairs and Jump 20. All 20 Jump pairs appeared in the Rails catalog. The 26 Rails-only pairs were all Visa edges: 10 APP, eight COM, and eight ORG. The inspected Jump table has no Visa node.
- Both inspected source graphs retain COM authentication-related edges. This source comparison does not establish that those edges should be installed or kept, nor that all local Rails catalog pairs are actually issued or deployed. No registry change, external write or runtime verification was performed.
