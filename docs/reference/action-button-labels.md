# Action Button Labels

How to word the pair of buttons that proceeds with or abandons an action: confirmation dialogs,
alerts, and forms with an explicit way out.

This page covers wording only. Size, hierarchy, placement, and disabled states stay with
[the design guide](../design.md). Google, Apple, and Microsoft sign-in buttons follow
[their own requirements](third-party-sign-in-button-requirements.md) and are outside this page.

## Source

Apple Human Interface Guidelines,
[Alerts](https://developer.apple.com/design/human-interface-guidelines/alerts), read on
**2026-10-08** through the official JSON representation because the HTML page requires JavaScript.
The latest entry in its change log is 2024-02-02, "Enhanced guidance for using default and Cancel
buttons". The pause outcome comes from
[Progress indicators](https://developer.apple.com/design/human-interface-guidelines/progress-indicators),
read the same day by the same route. The Japanese edition of the page could not be retrieved, so no
Japanese wording below is attributed to Apple. [References](#references) lists every page read.

Relevant sentences, quoted verbatim:

- "Always use "Cancel" to title a button that cancels the alert's action."
- "Create succinct, logical button titles. Aim for a one- or two-word title that describes the
  result of selecting the button. Prefer verbs and verb phrases that relate directly to the alert
  text — for example, "View All," "Reply," or "Ignore.""
- "Avoid using OK as the default button title unless the alert is purely informational."
- "In informational alerts only, you can use "OK" for acceptance, avoiding "Yes" and "No.""
- "If there's a destructive action, include a Cancel button to give people a clear, safe way to
  avoid the action."
- From Progress indicators: "If people can interrupt a process without causing negative side
  effects, include a Cancel button. If interrupting the process might cause negative side effects —
  such as losing the downloaded portion of a file — it can be useful to provide a Pause button in
  addition to a Cancel button."

## Assessment

The guidance is sound and UMAXICA adopts it. The two halves are asymmetric for a reason:

- The abandoning button always means the same thing, "nothing happens", so its wording should
  never vary. A fixed word lets people find the safe exit without reading the dialog.
- The proceeding button means something different every time, so its wording should say what will
  happen. People act on button text more reliably than on body text, and "OK" forces them back to
  the message to learn what they are agreeing to.

Two qualifications apply.

The guideline is stricter than the common summary "the OK button may use a more specific word". A
specific verb is the preferred form, and "OK" is the exception reserved for purely informational
alerts.

The guideline is Apple platform guidance written for alerts. Applying it to web forms and dialogs
on every surface is a UMAXICA decision, not a conformance requirement; it is not a WCAG criterion.
The rules below marked "UMAXICA judgment" go beyond what the source states.

## Closed questions

A closed question is an interaction whose set of possible answers is finite and fixed by the
application: the person picks one of the offered buttons. An open question is one where free input,
such as text typed into a form field, determines what happens next. This page governs closed
questions only.

Every outcome of a closed question is one of exactly four (UMAXICA judgment). These four words are
the complete internal vocabulary; no fifth outcome and no synonym is introduced.

| Outcome | Internal name | Meaning | Label |
| --- | --- | --- | --- |
| Agree or proceed | `AFFIRMATIVE` | The question is answered and the action runs. | Rule 1 |
| Refuse | `NEGATIVE` | The question is answered and the refusal is itself a result. | Rule 1 |
| Suspend | `PAUSE` | A running process halts where it is and keeps its progress. | Rule 7 |
| Withdraw | `CANCEL` | The question is not answered, or the process is abandoned. | Rule 2 |

`CANCEL` is not a third answer. It ends the question at the point where the button is pressed:
nothing is recorded as an answer, the pending action does not run, and the system is as it was
before the question was asked. The Apple guidance for
[action sheets](https://developer.apple.com/design/human-interface-guidelines/action-sheets)
describes the same behaviour: "The button dismisses the view without taking any action." Cancel
stops; it does not pause, and there is nothing to resume.

`NEGATIVE` and `CANCEL` differ whenever a refusal has consequences. Declining consent is
`NEGATIVE`, because the refusal is stored and honoured; closing the same prompt without choosing is
`CANCEL`, because the question remains open. Many confirmation dialogs have no `NEGATIVE` at all,
only `AFFIRMATIVE` and `CANCEL`.

`PAUSE` and `CANCEL` differ in what survives. `PAUSE` keeps the work done so far and can be
resumed; `CANCEL` discards it and returns to the state before the process started. `PAUSE` exists
only where there is a process with progress worth keeping, so a plain confirmation dialog never
offers it.

## Rules

1. **Proceeding button: name the result.** Use a short verb phrase tied to the action, such as
   "Delete", "Send Code", or "Sign Out". Do not use "Yes" or "No". Use "OK" only on a single-button
   acknowledgement that changes nothing.
2. **Abandoning button: one fixed word per language.** The label is exactly `Cancel` in English and
   `キャンセル` in Japanese. The Japanese string appears here because it is the localized copy this
   rule fixes. Language decides the word and region does not, so `us/en.yml` and `jp/en.yml` carry
   `Cancel`, and `jp/ja.yml` and `us/ja.yml` carry `キャンセル`. Synonyms such as "Back", "Abort",
   "Never mind", `やめる`, `中止`, or `取り消し` are not used for this button.
3. **A button labelled Cancel has no side effect** (UMAXICA judgment). It leaves the system as it
   was before the dialog or form opened. When abandoning also does something, the label states it;
   the existing `cancel_logout` key ("キャンセルしてログアウト") is the model.
4. **When the action itself is a cancellation, keep the two buttons distinguishable** (UMAXICA
   judgment). The proceeding button names its object, for example "Cancel Subscription" or "Cancel
   Verification", and the abandoning button remains `Cancel`. In Japanese, prefer a distinct verb
   for the proceeding button, such as `解約する` or `取り消す`, so that both buttons do not read
   `キャンセル`.
5. **Close is not Cancel** (UMAXICA judgment). A view that has no pending action to abandon, such
   as a read-only panel, is dismissed with "Close" / `閉じる`.

6. **Internally, the outcomes are named `AFFIRMATIVE`, `NEGATIVE`, `PAUSE`, and `CANCEL`** (UMAXICA
   judgment). Where the outcome of a closed question is carried as a named value, such as a
   parameter value, an enumeration member, or a translation key segment, use these four words and
   no synonym: not `yes` / `no`, `ok`, `accept` / `reject`, `agree` / `disagree`, `stop`, `suspend`,
   or `abort`. The names are internal and are never
   shown; the visible label still follows rule 1. A value that is a plain boolean stays a boolean.
   `AFFIRMATIVE` and `NEGATIVE` are borrowed from radiotelephony phraseology; that origin was not
   checked against a primary aviation source when this page was written.
7. **Offer Pause when abandoning would lose progress.** When interrupting a running process has
   negative side effects, provide a pause button in addition to `Cancel`, and a way to resume. Its
   label is exactly `Pause` in English and `一時停止` in Japanese, fixed per language in the same way
   as rule 2. The bare word `停止` is not used for this button, because the Japanese bundles already
   use it for account, access, and mail suspension, which are not resumable halts of a process. A `Cancel` that discards progress
   asks for confirmation first, following the Progress indicators guidance.

## Current state

Observed on 2026-10-08 across the four locale bundles; no locale file was changed with this page.

- `cancel:` keys resolve to `Cancel` 46 times and `キャンセル` 43 times, consistent with rule 2.
- `preference.cookie.banner.cancel` resolves to `閉じる` in both Japanese bundles. Whether that
  button abandons a pending choice (rule 2) or only dismisses the banner (rule 5) has not been
  decided; the key name and the label currently disagree.
- No locale bundle contains a Pause label, and no code or locale key uses `AFFIRMATIVE` or
  `NEGATIVE` yet. Existing key names such as `accept`,
  `confirm`, and `ok` predate rule 6 and have not been renamed.

## References

All three are Apple Human Interface Guidelines pages, read on 2026-10-08.

- [Alerts](https://developer.apple.com/design/human-interface-guidelines/alerts): the fixed
  `Cancel` title, verb-phrase titles, and the limits on "OK" and "Yes" / "No". Rules 1 and 2.
- [Action sheets](https://developer.apple.com/design/human-interface-guidelines/action-sheets):
  Cancel dismisses the view without taking any action. The `CANCEL` outcome.
- [Progress indicators](https://developer.apple.com/design/human-interface-guidelines/progress-indicators):
  Pause in addition to Cancel when interruption has negative side effects, and confirmation before
  a cancellation that loses progress. Rule 7.
