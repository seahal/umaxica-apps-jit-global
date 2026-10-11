---
name: doubt-driven-development
description:
  Subjects high-stakes and irreversible decisions to adversarial review before they stand. Use when
  the blast radius cannot be undone — security boundaries, data migrations, cross-surface
  authentication, public API changes — or when working in code whose invariants are not understood.
---

# Doubt-Driven Development

A confident answer is not a correct one. Long sessions accumulate context that quietly turns
assumptions into facts. This skill is adversarial re-examination — biased to **disprove**, not
approve — applied while course-correction is still cheap, unlike a post-hoc review that delivers a
verdict on a finished artifact.

## When to Use

Ordinary work does not need this skill. Correctness checking already happens inside the main working
loop, and a second pass over work the loop has already checked produces redundant effort rather than
better outcomes — see `.agents/harnesses/rules/generic/model-behavior-calibration.mdc`. This skill
exists for the narrower case where being wrong is expensive _and_ hard to undo.

A decision is **high-stakes** when at least one of these is true:

- Its blast radius is irreversible — production deploy, data migration, destructive schema change,
  public API change
- It touches a security boundary — authentication, authorization, session handling, CSRF, rate
  limiting, or credential and token handling
- It crosses the `app`, `org`, and `com` surface boundary, or changes a shared abstraction that all
  three depend on
- It asserts a property no test or type can verify (thread safety, idempotence, ordering, an
  invariant that holds only under assumptions the code cannot express)
- It commits to an interpretation of existing code whose invariants are genuinely not understood

Apply the skill when:

- About to take one of the actions above
- About to claim a non-obvious safety property ("this is safe under concurrent writes", "this
  preserves the session boundary")
- The user explicitly asks for adversarial review

**When NOT to use:**

- Any work whose correctness the main loop's own checking already covers — the default case
- Mechanical operations (renaming, formatting, file moves)
- Following a clear, unambiguous user instruction
- Reading or summarizing existing code
- Changes with obvious correctness, including most single-file changes
- Pure tooling operations (running tests, listing files)
- Reviewing work that is already complete — that is `/review`, a different gate
- The user has explicitly asked for speed over verification

If you doubt every keystroke, you ship nothing. The skill applies only to high-stakes decisions as
defined above.

## Loading Constraints

This skill is written for the main session, which is where Step 3 (DOUBT) can escalate to a spawned
fresh-context reviewer when a decision is irreversible.

Applied from inside a subagent, where nested spawning is unavailable, the in-loop review that Step 3
makes the default still works: rewrite ARTIFACT + CONTRACT as a fresh self-prompt separated from the
prior reasoning, and walk Steps 1–5. If the decision meets the irreversible bar that calls for a
_spawned_ reviewer, say so, flag the in-loop result as un-escalated, and leave the escalation to the
main session.

## The Process

Copy this checklist when applying the skill:

```
Doubt cycle:
- [ ] Step 1: CLAIM — wrote the claim + why-it-matters
- [ ] Step 2: EXTRACT — isolated artifact + contract, stripped reasoning
- [ ] Step 3: DOUBT — ran the adversarial review (in-loop by default; spawned reviewer if irreversible)
- [ ] Step 4: RECONCILE — classified every finding against the artifact text
- [ ] Step 5: STOP — met stop condition (trivial findings, 3 cycles, or user override)
```

### Step 1: CLAIM — Surface what stands

Name the decision in two or three lines:

```
CLAIM: "The new caching layer is thread-safe under the
        read-heavy workload described in the spec."
WHY THIS MATTERS: a race here corrupts user data and is
                  hard to detect in QA.
```

If you can't write the claim that compactly, you have a vibe, not a decision. Surface it before
scrutinizing it.

### Step 2: EXTRACT — Smallest reviewable unit

A fresh-context reviewer needs the **artifact** and the **contract**, not the journey.

- Code: the diff or the function — not the whole file
- Decision: the proposal in 3–5 sentences plus the constraints it has to satisfy
- Assertion: the claim plus the evidence that supposedly supports it (kept distinct from the Step 1
  CLAIM block, which is the orchestrator's hypothesis under scrutiny)

Strip your reasoning. If you hand over conclusions, you'll get back validation of your conclusions.
The unit must be small enough that a reviewer can hold it in mind in one read — if it's a 500-line
PR, decompose first.

### Step 3: DOUBT — Run the adversarial review

**Default: run the review in the main loop.** Take the ARTIFACT and CONTRACT from Step 2 and work
the adversarial prompt below against them directly. Do not spawn a subagent to do it.

**Escalate to a spawned fresh-context reviewer only when the decision is irreversible** — a
destructive migration, a production deploy, a security-boundary change, a public API change. The
cost of a spawned reviewer is justified there and not elsewhere: it re-establishes context from
scratch, and delegating routine verification produces redundant work rather than better findings
(`.agents/harnesses/rules/generic/model-behavior-calibration.mdc`).

Either way, the prompt **must be adversarial**. Framing decides the answer.

```
Adversarial review. Find what is wrong with this artifact.
Assume the author is overconfident. Look for:
- Unstated assumptions
- Edge cases not handled
- Hidden coupling or shared state
- Ways the contract could be violated
- Existing conventions this might break
- Failure modes under unexpected input

Do NOT validate. Do NOT summarize. Find issues, or state
explicitly that you cannot find any after thorough examination.

ARTIFACT: <paste artifact>
CONTRACT: <paste contract>
```

**Pass ARTIFACT + CONTRACT only. Do NOT pass the CLAIM.** Handing the reviewer your conclusion
biases it toward agreement. The review must independently determine whether the artifact satisfies
the contract. Working in-loop, this means holding the CLAIM aside and reading the artifact text as
written rather than as intended.

A spawned reviewer starts with isolated context by design, which is the property this step needs.
Pass the adversarial prompt verbatim: a general-purpose reviewer defaults to a balanced verdict with
both strengths and weaknesses, and this step needs issues-only output.

#### Cross-model escalation

A single-model reviewer shares blind spots with the original author — a colder,
different-architecture model catches them. That value is real, and so is the cost in latency, tool
fragility, and the user's attention.

**Offer cross-model when the decision warrants it, not on every cycle.** Warranted means:

- The blast radius is irreversible — destructive migration, production deploy, security-boundary
  change, public API change
- The single-model review surfaced findings that could not be resolved against the artifact text
- The user asks for it

Outside those cases, proceed to RECONCILE without offering. An offer attached to every cycle
regardless of stakes is friction that trains the user to decline reflexively, which costs the offer
its meaning on the decisions that actually need it.

**Step 1: Ask the user**

When the criteria above are met, pause after the Step 3 review and before RECONCILE, and ask:

> _"Review complete. This one is irreversible — want a cross-model second opinion? Options: Gemini
> CLI, Codex CLI, manual external review (you paste it elsewhere), or skip."_

The user — not the agent — decides whether the cost is worth it. The agent's job is to surface the
choice when it is live.

**Step 2: If the user picks a CLI — verify, then invoke**

1. Check the tool is in PATH (`which gemini`, `which codex`).
2. Test it works (`gemini --version` or equivalent) before passing the full prompt — a stale or
   broken binary may pass `which` but fail on real input.
3. Confirm the exact invocation with the user, including required flags, auth, and env vars (e.g.,
   API keys). Implementations vary; never assume.
4. Pass ARTIFACT + CONTRACT + the adversarial prompt **only**. No session context, no CLAIM.
5. Mind shell escaping. If the artifact contains quotes, `$(...)`, or backticks, prefer stdin
   (`echo … | gemini`) or a heredoc over inline `-p "…"`. When in doubt, ask the user to confirm the
   invocation before running it.
6. Take the output into Step 4 (RECONCILE).

**Never interpolate the artifact into a shell-quoted argument.** Code, markdown, and review prompts
routinely contain backticks, `$(...)`, and quote characters that will either truncate the prompt or
execute embedded shell. Write the full prompt to a file and pipe it through stdin.

Example shapes (verify flags against your installed tool — syntax differs across implementations and
versions):

```bash
# Write the adversarial prompt + ARTIFACT + CONTRACT to a temp file first.
# Then pipe via stdin so shell metacharacters in the artifact stay inert.

# Codex (read-only sandbox keeps the CLI from writing to your workspace):
codex exec --sandbox read-only -C <repo-path> - < /tmp/doubt-prompt.md

# Gemini ('--approval-mode plan' is read-only; '-p ""' triggers non-interactive
# mode and the prompt is read from stdin):
gemini --approval-mode plan -p "" < /tmp/doubt-prompt.md
```

A read-only sandbox is the load-bearing detail: a doubt artifact may itself contain instructions
(intentional or accidental prompt injection) that the cross-model CLI would otherwise execute
against your workspace.

**Step 3: If the CLI is unavailable or fails**

Surface the failure explicitly. Offer: run it manually, try a different tool, or skip. Do not
silently fall back to single-model — the user should know cross-model didn't happen.

**Step 4: If the user skips**

Acknowledge the skip in the output (_"Proceeding with single-model findings only"_) and continue to
RECONCILE. Skipping is fine; silent skipping is not.

**Non-interactive contexts** (CI, `/loop`, autonomous-loop, scheduled runs):

- Cross-model is **skipped**, and the skip must be **announced** in the output: _"Cross-model
  skipped: non-interactive context."_
- **Never invoke an external CLI without explicit user authorization** — this is a load-bearing
  safety property.

Cross-model adds cost, latency, and tool fragility. The agent surfaces the choice when the criteria
above are met; the user decides whether this artifact warrants it.

### Step 4: RECONCILE — Fold findings back

The reviewer's output is data, not verdict. **You are still the orchestrator.** Re-read the artifact
text against each finding before classifying — rubber-stamping the reviewer is the same failure mode
as ignoring it.

For each finding, classify in this **precedence order** (first matching class wins):

1. **Contract misread** — reviewer flagged something specifically because the CONTRACT you provided
   was unclear or incomplete. Fix the contract first, re-classify on the next cycle.
2. **Valid + actionable** — real issue requiring a change to the artifact. Change it, re-loop.
3. **Valid trade-off** — issue is real but cost of fixing exceeds cost of accepting. Document the
   trade-off explicitly so the user sees it.
4. **Noise** — reviewer flagged something that's actually correct under context the reviewer didn't
   have. Note it, move on, and ask: would adding that context to the contract have prevented the
   false flag?

A fresh reviewer can be wrong because it lacks context. Don't defer just because it's "fresh."

### Step 5: STOP — Bounded loop, not recursion

Stop when:

- Next iteration returns only trivial or already-considered findings, **or**
- 3 cycles completed (escalate to user, don't grind a fourth alone), **or**
- User explicitly says "ship it"

If after 3 cycles the reviewer still surfaces substantive issues, the artifact may not be ready.
Surface this to the user — three unresolved cycles is information about the artifact, not a reason
to keep looping.

If 3 cycles is "obviously insufficient" because the artifact is large: the artifact is too big —
return to Step 2 and decompose. Do not lift the bound.

## Red Flags

- Spawning a fresh-context reviewer for a one-line rename or formatting change
- Spawning a reviewer for a reversible decision the in-loop review already covers
- Treating reviewer output as authoritative without re-reading the artifact text
- Looping >3 cycles without escalating to the user
- Prompting the reviewer with "is this good?" instead of "find issues"
- Skipping doubt under time pressure on a high-stakes decision
- Re-spawning fresh-context on an unchanged artifact (you'll get the same findings; you're stalling)
- **Doubt theater (checkable signal)**: across 2 or more cycles where the reviewer surfaced
  substantive findings, zero findings were classified as actionable. You are validating, not
  doubting. Stop and escalate.
- Doubting only after committing — that's `/review`, not doubt-driven development
- Hardcoding an external CLI invocation without confirming with the user that the tool exists, is
  configured, and accepts that exact syntax
- **Silently skipping cross-model when the criteria are met.** On an irreversible decision, or with
  findings left unresolved, the offer must be visible. Skipping is fine; silent skipping is not.
- Falling back silently when an external CLI errors or is missing — surface the failure and let the
  user redirect
- Stripping the contract from the reviewer's input
- Passing the CLAIM to the reviewer (biases toward agreement)

## Interaction with Other Skills

- **`code-review-and-quality` / `/review`**: complementary. `/review` is post-hoc PR verdict;
  doubt-driven is in-flight per-decision. Use both.
- **`source-driven-development`**: SDD verifies _facts about frameworks_ against official docs.
  Doubt-driven verifies _your reasoning about the artifact_. SDD checks the API exists; doubt-driven
  checks you used it correctly under the contract.
- **`test-driven-development`**: TDD's RED step is doubt made concrete — a failing test is a
  disproof attempt. When TDD applies, that failing test _is_ the doubt step for behavioral claims.
- **`debugging-and-error-recovery`**: when the reviewer surfaces a real failure mode, drop into the
  debugging skill to localize and fix.
- **Subagent budget** (`.agents/harnesses/rules/generic/model-behavior-calibration.mdc`): the
  spawned reviewer in Step 3 is the one delegation this repository's budget allows for verification,
  and only at the irreversible bar. See Loading Constraints above.

## Verification

After applying doubt-driven development:

- [ ] Every high-stakes decision (per the definition above) was named explicitly as a CLAIM before
      standing
- [ ] At least one adversarial review per high-stakes artifact — in-loop by default, spawned
      fresh-context only where the blast radius is irreversible (a failing test produced by TDD's
      RED step satisfies this for behavioral claims, per Interaction with Other Skills)
- [ ] The review worked from ARTIFACT + CONTRACT — NOT the CLAIM, NOT your reasoning
- [ ] The prompt was adversarial ("find issues"), not validating ("is it good")
- [ ] Findings were classified against the artifact text (not rubber-stamped) using the precedence:
      contract misread / actionable / trade-off / noise
- [ ] A stop condition was met (trivial findings, 3 cycles, or user override)
- [ ] In interactive mode, where the cross-model criteria were met (irreversible blast radius,
      unresolved findings, or user request), it was **explicitly offered** and the response was
      acknowledged in the output
- [ ] In non-interactive mode, cross-model was skipped and the skip was announced
- [ ] Any external CLI invocation was preceded by a PATH check, a working-binary test, syntax
      confirmation with the user, and explicit authorization to run
