# N5 partial instruction clarification

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had extensive uncommitted changes; the change and check describe that worktree.

The root `AGENTS.md` now explicitly distinguishes an Accepted ADR's intended contract from evidence of current implementation and directs agents to identify and resolve conflicts within user authorization. The existing instruction to follow implementation patterns and report discrepancies remains. `git diff --check -- AGENTS.md` completed successfully. No runtime tests were run for this prose change.

The original N5 audit asked for Accepted ADR precedence over the unconditional code-pattern rule. This clarification does not settle that precedence, and the user's directly supplied current instruction remains binding in this session.
