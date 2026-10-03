# Customer copy review for Base, app Secret, and Core

Prepared on 2026-10-03 (UTC). This is localization design material, not installed
translations or evidence of a working screen. The Japanese text below is intended
customer copy, an explicit exception to English repository prose.

Use the [accepted contract](../../adr/base-secret-core-contract-precedence.md) and
[acceptance catalog](base-secret-core-acceptance.md) when connecting copy to UI states.
Actual translation keys must follow the existing locale namespace; identifiers in
the first column are semantic labels, not proposed replacement keys.

## Issuance and confirmation

| State | Japanese customer copy | Placement and condition |
| --- | --- | --- |
| Nineteen valid Secrets, before presentation | Secret は最大20個まで保有できます。上限を超えないよう、今回は2個ではなく1個を配布します。 | Accepted limit notice; server determines A and quantity at reservation. |
| Nineteen valid Secrets, after presentation | Secret は最大20個まで保有できます。上限を超えないよう、今回は2個ではなく1個を配布しました。 | Completed presentation; do not imply confirmed activation. |
| Twenty valid Secrets | 有効な Secret が上限の20個あるため、今回は新しい Secret を配布していません。保存済みの Secret は引き続き使用できます。 | Accepted omission notice; no new-value confirmation. |
| Competing issuance | 別の Secret 発行手続きが進行中です。その手続きを完了または取り消してから、もう一度お試しください。 | Proposed conflict copy; do not disclose another session's operation or candidate values. |
| Before explicit presentation | Secret は一度だけ表示されます。保存先を準備してから表示してください。 | Proposed copy; protected explicit action, not automatic page-load presentation. |
| Awaiting storage declaration | 表示された Secret を安全な場所に保存したことを確認してください。保存を確認するまで、この Secret は使用できません。 | Proposed copy; confirm the exact server-presented set. |
| Confirmation action | 表示された Secret を保存しました | Proposed explicit action label; it is a declaration, not proof of authentication. |
| Payload unavailable | Secret を表示できませんでした。未確定の Secret は使用できません。新しい交付手続きを開始してください。 | Proposed copy; show restart only when invalidation and authorized restart are supported. |
| Issuance expired | この交付手続きの有効期限が切れました。未確定の Secret は使用できません。 | Proposed copy; the issuance expired, not every saved Secret. |
| Passkey saved, Secret delivery pending | Passkey は登録されています。Secret の交付手続きを完了してください。 | Proposed signed-in resume copy; enrollment must accurately describe pending registration completion. |
| Confirmation complete | Secret の保存確認が完了しました。 | Proposed copy; do not claim the server verified the user's actual storage. |

The 20-item notice describes Secret eligibility, not a guarantee that an account
can currently sign in. Show independent account restrictions through their existing
UI contract. A reservation conflict never uses the 20-valid-Secret notice.

## Management and authentication

| State | Proposed Japanese customer copy | Constraint |
| --- | --- | --- |
| Capacity reached for manual addition | 有効な Secret が上限の20個あるため、追加できません。 | Do not offer automatic oldest-item replacement. |
| Step-Up required | この操作を続けるには、追加の認証が必要です。 | Existing allowed-method UI supplies the actual choices; Secret is not one. |
| Step-Up freshness expired | 追加の認証の有効期限が切れました。もう一度認証してください。 | Do not silently accept stale proof or renew freshness. |
| Delete confirmation | この Secret を削除すると、今後の Sign in に使用できなくなります。 | Explain irreversible credential eligibility; do not promise a new global-session policy. |
| Secret sign-in refused | Secret を確認できませんでした。入力内容を確認するか、別の Sign in 方法をお試しください。 | Same outward credential message for unknown, claimed, consumed, revoked, or unavailable-account cases. |
| Temporary infrastructure failure | 一時的に処理できません。しばらくしてから、もう一度お試しください。 | Retry action must follow operation state; never automatically resubmit an uncertain write. |
| Core checking | 認証状態を確認しています。 | No redirect while authentication remains unconfirmed. |
| Core confirmed reauthentication | 再度 Sign in してください。 | Only after the server contract establishes that reauthentication is required. |
| Core temporary failure | 認証状態を確認できませんでした。通信状況を確認して、もう一度お試しください。 | Do not describe a network/429/5xx failure as logout. |

## Review criteria before localization integration

- Keep server-selected counts and reasons in inline props/I18n, independent of flash.
- Use distinct UI states for presentation, storage declaration, activation, normal
  omission, and interruption. Do not infer activation from successful response delivery.
- Label explicit reveal and confirmation actions accessibly. Announce notices to
  assistive technology without repeated announcements on every redraw.
- Do not warn merely because the valid count became one or zero. Do not recommend
  Secret as account recovery or Step-Up evidence.
- Do not display raw credentials, payload locators, internal error details, arbitrary
  user names, or another browser's issuance identifiers in notices or diagnostics.
- Final UI review must check Japanese wording in the actual enrollment and signed-in
  states. Except the accepted 19/20 notices, this file's copy is a proposal for that review.
