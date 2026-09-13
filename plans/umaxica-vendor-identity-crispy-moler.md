# Umaxica Vendor Identity Docs — Cross-Document Consistency Audit

**監査日**: 2026-06-25  
**監査対象バージョン**: rfi-draft / 2026-06-24-r4  
**WRITE_ACCESS**: OFF（ファイル変更禁止）  
**目的**: SIer / security-vendor 向け identity docs の RFI 投入前最終洗い直し

---

## 1. Executive Verdict

### 現時点で RFI に出せる状態か

**条件付き YES**。主要 4 文書（01 / 04 / 13 /
14）は rfi-draft として内容の整合性は概ね確保されている。ただし以下の必須修正を完了しないと RFI パッケージとして渡すべきでない。

### RFI に出す前の必須修正（5件）

| #   | 必須修正                                                                                                                     | 対象ドキュメント                      |
| --- | ---------------------------------------------------------------------------------------------------------------------------- | ------------------------------------- |
| M-1 | 00_readme.md の Related Documents に 13 / 14 を追加（現状リストは 00〜12 止まり）                                            | 00_readme.md                          |
| M-2 | 12_gap-risk-register.md に Round 4/5 blockers を反映（GAP-002 / GAP-NEW-001 / GAP-NEW-006/007 が一切未記載）                 | 12_gap-risk-register.md               |
| M-3 | 11_decision-register.md に Pinwheel DEC-012（null_session fail-closed）と DEC-013（audit log integrity）相当を追記           | 11_decision-register.md               |
| M-4 | 08_threat-model.md に「DRAFT / context-only / not normative」ラベルを冒頭に太字で明示                                        | 08_threat-model.md                    |
| M-5 | 15_audit-log-integrity-requirement.md の存在と現在の status を確認・整理（ファイルは存在するが監査対象に含まれていなかった） | 15_audit-log-integrity-requirement.md |

### RFP に出す前の必須修正（追加で必要）

- GAP-NEW-006/007: MFA reset
  UI を有効化するための 5 前提条件がすべて満足されること（14\_ の ACC-REC-001〜020 を完全に充足するまで RFP 提示禁止）
- GAP-002: Chronicle DB-level immutability の実装方法（DB trigger / append-only table / restricted
  role / hash chain）を決定し、Audit Log Integrity Requirement として確定すること
- GAP-NEW-001: Recovery passcode rate limit / lockout の実装方針決定
- 08_threat-model.md: owner 確定、review 完了、DRAFT → approved へ昇格
- 11_decision-register.md: 数値 namespace の混在（vendor-facing DEC vs pinwheel
  DEC）を解消するか、相互参照を明示する

### いま実装・テストに入ってよいか

**NO**。以下が未解決のまま実装に入ると後退リスクがある。

- 15_audit-log-integrity-requirement.md の status と内容確認
- Audit Log Integrity Requirement の実装候補決定
- Recovery passcode rate limit の実装判断
- Catastrophic recovery path（S-005 OPEN BLOCKER）の定義

### 最大リスク 5 件

| #   | リスク                                                                                                           | 深刻度   |
| --- | ---------------------------------------------------------------------------------------------------------------- | -------- |
| R-1 | Chronicle DB-level immutability 不在（NR-004 が満たされていない）                                                | CRITICAL |
| R-2 | 11_decision-register.md と Pinwheel の DEC 番号体系が別 namespace で混在 → SIer が誤参照する                     | HIGH     |
| R-3 | 12_gap-risk-register.md が Round 4/5 の blocker を全く反映していない → SIer が最新 risk 状況を読めない           | HIGH     |
| R-4 | 00_readme.md が 13 / 14 を未掲載 → SIer が最も重要な規範文書を見落とす                                           | HIGH     |
| R-5 | 15_audit-log-integrity-requirement.md が存在するが今回の監査対象外 → 内容次第では RFI パッケージと矛盾する可能性 | HIGH     |

---

## 2. Document Inventory

| Document                                    | Status                                  | Owner         | Maturity  | RFI Use                            | RFP Use               | Problem                                                                                                | Action                                                                       |
| ------------------------------------------- | --------------------------------------- | ------------- | --------- | ---------------------------------- | --------------------- | ------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------- |
| 00_readme.md                                | rfi-draft（実態は stale）               | TBD           | low       | context only（要更新後）           | update required       | 13/14 未記載。package map が 00〜12 止まり                                                             | Related Documents 更新必須                                                   |
| 01_responsibility_matrix.md                 | rfi-draft                               | TBD           | high      | normative（条件付き）              | RFP ready（条件付き） | DEC 番号が pinwheel と別 namespace                                                                     | namespace 整理注記を追加                                                     |
| 02_responsibility-boundary.md               | (調査外)                                | TBD           | unknown   | 要確認                             | 要確認                | 01* が capability section を supersede するが、02* の残存 scope が不明                                 | read-only 確認推奨                                                           |
| 03_route-endpoint-inventory.md              | (調査外)                                | TBD           | unknown   | context only                       | RFP ready 候補        | 内容未確認                                                                                             | read-only 確認推奨                                                           |
| 04_cookie-session-token-matrix.md           | rfi-draft                               | TBD           | high      | normative（条件付き）              | RFP ready（条件付き） | BLOCKER 記述が正確。DPoP / Palm 整合済み                                                               | そのまま使用可                                                               |
| 05_authentication-flow-inventory.md         | (調査外)                                | TBD           | unknown   | context only                       | 要確認                | 内容未確認                                                                                             | read-only 確認推奨                                                           |
| 06_failure-taxonomy.md                      | (調査外)                                | TBD           | unknown   | context only                       | 要確認                | 内容未確認                                                                                             | read-only 確認推奨                                                           |
| 07_social-linking-policy.md                 | (調査外)                                | TBD           | unknown   | normative 候補                     | 要確認                | NR-001 との整合確認が必要                                                                              | read-only 確認推奨                                                           |
| 08_threat-model.md                          | DRAFT                                   | TBD（未確定） | low       | context only（DRAFT 明示必須）     | DRAFT → approved 必要 | owner 未確定、review 未完了、冒頭 DRAFT 表示要強化                                                     | DRAFT ラベル強化。RFI には "context only / not normative" 注記付きでのみ同梱 |
| 09_acceptance-criteria.md                   | (調査外)                                | TBD           | unknown   | RFP only                           | RFP 候補              | 内容未確認                                                                                             | read-only 確認推奨                                                           |
| 10_vendor-questions.md                      | (調査外)                                | TBD           | unknown   | RFP only                           | RFP 候補              | 内容未確認                                                                                             | read-only 確認推奨                                                           |
| 11_decision-register.md                     | draft                                   | TBD           | medium    | context only（要更新）             | update required       | DEC-001〜011 のみ。Pinwheel DEC-012/013 相当なし。Namespace 混在                                       | DEC-012/013 追記。Namespace 注記追加                                         |
| 12_gap-risk-register.md                     | draft（実態は stale）                   | TBD           | low       | internal only（要更新）            | update required       | Round 4/5 の主要 blocker（GAP-002 / GAP-NEW-001/006/007）が全未記載                                    | 大幅更新必須                                                                 |
| 13_normative-baseline.md                    | rfi-draft                               | TBD           | very high | normative（最重要）                | RFP core              | 最も包括的。RFI/RFP usage warning を自己包含                                                           | そのまま使用可（owner 確定後）                                               |
| 14_account-recovery-procedure.md            | rfi-draft                               | TBD           | high      | normative（条件付き）              | RFP ready（条件付き） | S-005 catastrophic recovery が OPEN BLOCKER                                                            | そのまま使用可（blocker 明示済み）                                           |
| 15_audit-log-integrity-requirement.md       | 不明（未確認）                          | TBD           | unknown   | 不明                               | 不明                  | 今回の監査対象外。存在は確認済み                                                                       | **最優先で内容確認必須**                                                     |
| docs/authorization_guide.md                 | stable（Action Policy）                 | TBD           | high      | normative（SIer 向け認可ガイド）   | normative             | docs/spec/ の旧 Pundit 版と区別が必要                                                                  | RFI に同梱可。docs/spec/ との非互換を注記                                    |
| docs/spec/authorization_guide.md            | **存在しない**                          | —             | —         | exclude                            | exclude               | ファイル自体が存在しない                                                                               | 参照している箇所があれば修正                                                 |
| notes/oauth2-1-compliance-gap.md            | design direction（stale）               | TBD           | low       | **exclude**                        | **exclude**           | "sign.\*=AS" 等の旧 vocabulary、"AS implementation location" 矛盾あり。Pinwheel DEC-001/002 で封印指示 | RFI から完全除外。pinwheel 指示通り seal/modify                              |
| plans/umaxica-immutable-pinwheel.md         | internal audit ledger                   | TBD           | very high | **internal only**                  | internal only         | 内部 due diligence 文書。SIer に渡してはならない                                                       | internal only として管理                                                     |
| docs/security/mfa-reset-account-recovery.md | earlier version（partially superseded） | TBD           | medium    | internal only                      | 14\_ が supersede     | 14\_ と部分的に重複。どちらが source-of-truth か不明確                                                 | 14\_ が supersede することを明示                                             |
| docs/auth-ceremony/\*.md                    | evidence-only（DEC-007）                | TBD           | high      | internal only                      | internal only         | コード証跡・分析 docs。SIer 向けではない                                                               | internal only                                                                |
| docs/architecture/dpop.md                   | stable                                  | TBD           | high      | context only（RFP では normative） | normative             | DPoP opt-in / Palm 非対応が正確に記載                                                                  | RFI context only、RFP normative                                              |
| adr/\*.md (2026-06-12 以降)                 | accepted                                | TBD           | high      | internal only                      | 参照可（selected）    | 現行 ADR は 2026-06-12 以降のみ normative                                                              | RFI には直接含めない。参照は可                                               |

---

## 3. Cross-document Contradictions

| ID      | Topic                                                                                                                          | Document A                                             | Document B                                                              | Severity        | Impact                                                                                                                       | Recommended Fix                                                                               |
| ------- | ------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------ | ----------------------------------------------------------------------- | --------------- | ---------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| CON-001 | DEC 番号 namespace の混在                                                                                                      | 11_decision-register.md（DEC-001〜011：vendor-facing） | plans/umaxica-immutable-pinwheel.md（DEC-001〜013：procurement-facing） | HIGH            | "DEC-008" が両文書で別の意味を持つ。SIer が誤参照する                                                                        | 11\_ の DEC 番号に `VD-` prefix 付与、または pinwheel との相互参照マッピング表を追加          |
| CON-002 | 11_decision-register.md に Pinwheel DEC-012/013 相当なし                                                                       | 11_decision-register.md                                | plans/umaxica-immutable-pinwheel.md                                     | HIGH            | null_session fail-closed（NR-003）と audit log integrity（NR-004）が decision register 上で根拠不明になる                    | 11* に DEC-012/013 相当のエントリを追記（内容は 13* の NR-003/004 と整合させる）              |
| CON-003 | 00_readme.md のパッケージ一覧が 00〜12 止まり                                                                                  | 00_readme.md                                           | 実ファイル構成（15 files）                                              | HIGH            | SIer が 13_normative-baseline.md と 14_account-recovery-procedure.md を見落とす                                              | 00_readme.md の Related Documents と package map を 00〜15 に更新                             |
| CON-004 | 12_gap-risk-register.md が Round 4/5 blockers を含まない                                                                       | 12_gap-risk-register.md                                | plans/umaxica-immutable-pinwheel.md                                     | HIGH            | GAP-002 / GAP-NEW-001 / GAP-NEW-006/007 が存在しない。SIer が risk 状況を把握できない                                        | 12\_ を pinwheel の GAP register と整合させる大幅更新が必要                                   |
| CON-005 | 08_threat-model.md の DRAFT ステータスが 00_readme.md に反映されていない                                                       | 00_readme.md                                           | 08_threat-model.md（冒頭の status: draft 記述）                         | MEDIUM          | RFI パッケージとして配布する際 "context only / not normative" が伝わらない                                                   | 00*readme.md の 08* 項目に「DRAFT / context only」注記を追加                                  |
| CON-006 | docs/security/mfa-reset-account-recovery.md と 14_account-recovery-procedure.md の関係が不明確                                 | docs/security/mfa-reset-account-recovery.md            | 14_account-recovery-procedure.md                                        | MEDIUM          | どちらが source-of-truth か不明。14\_ の方がはるかに詳細だが、旧版が参照され続けるリスク                                     | 14\_ が supersede することを両文書に明示。docs/security/ 版を deprecated として注記           |
| CON-007 | Pinwheel DEC-001/002「notes/oauth2-1-compliance-gap.md を封印」が 11\_ に未掲載                                                | 11_decision-register.md                                | plans/umaxica-immutable-pinwheel.md（DEC-001/002）                      | MEDIUM          | 封印指示が vendor-facing document に記録されていないため、RFI 配布時に誰かが oauth2-1-compliance-gap.md を含めてしまうリスク | 11\_ に「notes/oauth2-1-compliance-gap.md は non-authoritative / exclude from RFI」として記録 |
| CON-008 | docs/auth-ceremony/AUTHORITY-MATRIX.md の「AS implementation location 不明（ADR=acme、note=sign.\*）」矛盾                     | docs/auth-ceremony/AUTHORITY-MATRIX.md                 | ADR acme-sign-core-base-port-boundary.md                                | LOW（内部のみ） | 内部の auth-ceremony 文書にのみ影響。vendor docs（13\_）には Acme=AS として統一済み                                          | auth-ceremony 文書の矛盾コメントは DEC-001 で解消済みとして内部整理。vendor docs への影響なし |
| CON-009 | GQ-07（AS implementation location）が pinwheel では「RESOLVED (DEC-001/002)」だが auth-ceremony では「未解決」として残っている | docs/auth-ceremony/OPEN-QUESTIONS.md                   | plans/umaxica-immutable-pinwheel.md                                     | LOW             | 内部 consistency のみ                                                                                                        | 内部 docs で GQ-07 を CLOSED として記録                                                       |

---

## 4. Stale / Non-authoritative Documents

| Document                                    | Why Stale                                                                                                             | Risk                                                                                                    | Required Label                                     | Include in RFI?                        | Action                                                                          |
| ------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------- | -------------------------------------------------- | -------------------------------------- | ------------------------------------------------------------------------------- |
| notes/oauth2-1-compliance-gap.md            | design-direction（not normative）。"sign.\*=AS" 等の旧 vocabulary を含む。Pinwheel DEC-001/002 で封印指示済み         | SIer が "compliance gap" と読んで OAuth 2.1 compliant への要求事項と誤解する。AS attribution を誤読する | `INTERNAL ONLY — NOT FOR DISTRIBUTION`             | **NO**                                 | RFI パッケージから除外。ファイルに internal-only ヘッダ追記（DEC-001/002 実施） |
| docs/spec/authorization_guide.md            | ファイルが存在しない（Pundit 版。Action Policy 版の docs/authorization_guide.md が正）                                | 参照残存リスク（他 docs が誤参照していないか確認が必要）                                                | N/A（存在しない）                                  | **NO**                                 | 他文書でこのパスを参照している箇所を確認し、docs/authorization_guide.md に修正  |
| 00_readme.md                                | package map が 00〜12 で停止。13/14/15 未掲載。Round 4/5 の状態を反映していない                                       | SIer が最重要 normative docs を見落とす                                                                 | 更新完了まで「[要更新]」注記推奨                   | context only（要更新後）               | Related Documents と package map を更新。15\_ の status 確認後に含める          |
| 12_gap-risk-register.md                     | Round 4/5 の主要 blockers（GAP-002 / GAP-NEW-001/006/007）が全未記載。G-001〜015 は初期 assessment 時点で止まっている | SIer が「gap は解消済み」と誤読する。最大 risk が見えない                                               | `[STALE — NOT FOR DISTRIBUTION UNTIL UPDATED]`     | **NO（更新完了まで）**                 | 大幅更新必須（pinwheel GAP register との整合）                                  |
| 11_decision-register.md                     | DEC-012/013 相当なし。DEC 番号 namespace が pinwheel と別。Pinwheel DEC-001/002 が未記録                              | SIer が null_session / audit integrity の決定根拠を追えない                                             | 更新まで「[INCOMPLETE]」                           | context only（要更新後）               | DEC-012/013 追記。Namespace 整理。oauth2-1-compliance-gap.md 封印決定を追記     |
| docs/security/mfa-reset-account-recovery.md | 14_account-recovery-procedure.md が詳細版として supersede。旧版として残存                                             | SIer や将来の agent が旧版を参照する                                                                    | `[SUPERSEDED BY 14_account-recovery-procedure.md]` | **NO**                                 | deprecated 注記追加。14\_ への参照に置き換え                                    |
| 08_threat-model.md                          | DRAFT、owner TBD、review 未完了                                                                                       | RFI 配布時に "normative" と誤読される                                                                   | `DRAFT — CONTEXT ONLY — NOT NORMATIVE`             | context only（DRAFT ラベル強化後のみ） | 冒頭 DRAFT ラベルを強調。Owner 確定を RFP 前提条件に設定                        |

---

## 5. Decision / Gap / Risk Drift

| ID                                        | Topic                                                                 | Expected State（Pinwheel 基準）                                                             | Current Docs State                                           | Drift                  | Severity                    | Action                      |
| ----------------------------------------- | --------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- | ------------------------------------------------------------ | ---------------------- | --------------------------- | --------------------------- |
| DEC-001/002                               | notes/oauth2-1-compliance-gap.md 封印                                 | 封印済み / internal-only                                                                    | 11_decision-register.md に未記録                             | YES                    | HIGH                        | 11\_ に追記                 |
| DEC-007                                   | docs/authorization_guide.md を使用（Pundit 版は非 authoritative）     | docs/spec/ は存在しないが、正式な決定が 11\_ に未記録                                       | 11_decision-register.md に未記録                             | YES                    | MEDIUM                      | 11\_ に追記                 |
| DEC-008                                   | 社会 linking は provider+uid/sub のみ（email matching 禁止）          | NR-001 として 01/04/13 に正確に反映済み                                                     | **NO drift**（実質反映済み）                                 | NO                     | —                           | —                           |
| DEC-009                                   | MFA reset UI DISABLED（5 前提条件充足まで）                           | 01/04/14 に BLOCKER として正確に反映済み                                                    | **NO drift**                                                 | NO                     | —                           | —                           |
| DEC-011                                   | TOTP same-window replay hardened（禁止）                              | NR-002 として 01/04/13 に反映済み                                                           | **NO drift**                                                 | NO                     | —                           | —                           |
| DEC-012                                   | Token endpoint null_session fail-closed                               | NR-003 として 01/04/13 に反映済み。04\_ にも記載                                            | 11_decision-register.md に未記録                             | PARTIAL                | HIGH                        | 11\_ に追記                 |
| DEC-013                                   | Audit log integrity REQUIRED（append-only / NR-004）                  | NR-004 として 01/04/13 に反映済み                                                           | 11_decision-register.md に未記録                             | PARTIAL                | HIGH                        | 11\_ に追記                 |
| NR-001                                    | Social linking: uid+provider primary key、email_verified=false reject | 01/04/13 全文掲載。07_social-linking-policy.md（未確認）との整合要確認                      | PARTIAL（07\_ 未確認）                                       | MEDIUM                 | 07\_ を確認して整合チェック |
| NR-002                                    | TOTP same-window replay 禁止                                          | 01/04/13 に正確に反映                                                                       | **NO drift**                                                 | NO                     | —                           | —                           |
| NR-003                                    | Token endpoint null_session fail-closed                               | 01/04/13 に正確に反映                                                                       | **NO drift**                                                 | NO                     | —                           | —                           |
| NR-004                                    | Audit log integrity（append-only / tamper-detectable）                | 13* 詳細記載。04* にも event binding table あり。**[BLOCKER]** DB-level immutability 未実装 | **NO drift**（blocker 明示済み）                             | NO                     | blocker 解消が前提          |
| GAP-002                                   | Chronicle DB-level immutability 不在（NR-004 blocker）                | 01/13/14 に BLOCKER として明示                                                              | 12_gap-risk-register.md に**未掲載**                         | YES                    | CRITICAL                    | 12\_ を更新                 |
| GAP-004                                   | verify_authorized after_action deferred                               | 13\_ で "deferred" として明示                                                               | 12_gap-risk-register.md に記載なし                           | YES                    | MEDIUM                      | 12\_ を更新                 |
| GAP-008                                   | Responsibility Matrix 未作成（旧 blocker）                            | 01_responsibility_matrix.md として作成済み → **解消**                                       | 12\_ に解消記録なし（G-008 が "NONE/BLOCKER" のまま）        | YES                    | MEDIUM                      | 12\_ に G-008 CLOSED を記録 |
| GAP-009                                   | Cookie/Session/Token Matrix 未作成（旧 blocker）                      | 04\_ として作成済み → **解消**                                                              | 12\_ に解消記録なし（G-009 が "NONE/BLOCKER" のまま）        | YES                    | MEDIUM                      | 12\_ に G-009 CLOSED を記録 |
| GAP-NEW-001                               | Recovery passcode rate limit / lockout なし（known gap）              | 01/04/13/14 に [KNOWN GAP] として明示                                                       | 12_gap-risk-register.md に**未掲載**                         | YES                    | HIGH                        | 12\_ を更新                 |
| GAP-NEW-006                               | MFA reset UI disabled / runbook 要件（blocker）                       | 14\_ で詳細に記録                                                                           | 12_gap-risk-register.md に**未掲載**                         | YES                    | CRITICAL                    | 12\_ を更新                 |
| GAP-NEW-007                               | Catastrophic recovery（全認証情報消失）undefined（OPEN BLOCKER）      | 14\_ の S-005 で OPEN BLOCKER として明示                                                    | 12_gap-risk-register.md に**未掲載**                         | YES                    | CRITICAL                    | 12\_ を更新                 |
| GQ-06                                     | Telephone-only AAL1                                                   | OPEN（Pinwheel 確認）                                                                       | 13* で "deferred" として分類。04* の open questions にも残存 | **OPEN（正しく残存）** | MEDIUM                      | 変化なし。継続 OPEN         |
| RSK-010                                   | DPoP-bound token rejected by Palm                                     | docs/architecture/dpop.md に明示。13* / 04* にも明示                                        | **文書化済み**                                               | NO                     | —                           | —                           |
| Recovery passcode rate limit known gap    | 曖昧解消扱いされていないか                                            | 01/04/13/14 いずれも [KNOWN GAP] として明示。解消扱いなし                                   | **正しく残存**                                               | NO                     | —                           | —                           |
| Chronicle immutability 実装済み誤読リスク | 「実装済み」と読める記述がないか                                      | 全文書で [BLOCKER] / [KNOWN GAP] として明示。実装済みと読める記述なし                       | **問題なし**                                                 | NO                     | —                           | —                           |

---

## 6. Vendor Misunderstanding Risks

| Risk                                                                        | Likely Vendor Misread                                                                                         | Impact                                                              | Preventive Wording                                                                                                                                       | Target Document                           |
| --------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------- |
| Auth0/Keycloak/generic OIDC 前提                                            | 汎用 OIDC Provider に置き換え可能と判断する                                                                   | 全認証フローが崩壊する                                              | 13\_ の Critical Framing Warning は十分。00_readme.md にも同等の警告を冒頭に追加する                                                                     | 00_readme.md                              |
| OAuth 2.1 compliant の契約上の誤読                                          | notes/oauth2-1-compliance-gap.md（タイトルに "compliance" を含む）を根拠に "OAuth 2.1 compliant" と主張される | 契約上の表明と誤認。実態は profile constraint のみ                  | notes/ を RFI から完全除外。13\_ の "Not Claimed" section を冒頭参照に追加                                                                               | 00_readme.md、13_normative-baseline.md    |
| RS256 追加可能と読める                                                      | ES384 only が ES384 preference と誤読される                                                                   | 署名検証破壊、token interop 問題                                    | 13* は明示だが、"intentionally no RS256" を 00_readme.md と 01* 冒頭にも繰り返す                                                                         | 00_readme.md、01_responsibility_matrix.md |
| Sign が AS / token authority と読める                                       | Sign も token を発行できると判断する                                                                          | Sign に token issuance を実装される                                 | 01* / 13* / docs/security/sign-in-sequence.md で明示済み。11_decision-register.md DEC-001（vendor-facing）も一致。十分だが 00_readme.md にも警告追加推奨 | 00_readme.md                              |
| Sign が session authority と読める                                          | Sign のセッションを main session として設計する                                                               | Session fixation リスク、acme session との二重管理                  | docs/security/session-token-authority.md を参照。13* / 01* でも明示                                                                                      | 00_readme.md の Related Documents に追加  |
| Social email matching を実装してよいと読める                                | email 一致で自動 link する                                                                                    | Account takeover 直結                                               | NR-001 が明示的に禁止。01 / 04 / 13 に全文掲載。07_social-linking-policy.md（未確認）との整合も要確認                                                    | 07_social-linking-policy.md（確認後）     |
| DPoP が全 client mandatory と読める                                         | 全 client に DPoP 実装を要求してくる                                                                          | 既存 client との非互換。Palm は DPoP 非対応                         | 13\_ で "Informative（Opt-in）" と明示。"Not Claimed" に "mandatory DPoP" を列挙済み                                                                     | 13_normative-baseline.md                  |
| Palm が DPoP に対応すると読める                                             | Palm に DPoP 実装提案が来る                                                                                   | Palm アーキテクチャの誤解。DPoP-bound token が拒否される            | docs/architecture/dpop.md と 13* / 04* で "bearer-only / DPoP rejected" を明示済み                                                                       | 04_cookie-session-token-matrix.md         |
| MFA reset UI を有効化してよいと読める                                       | 5 前提条件を無視して UI を ON にする提案が来る                                                                | Abuse protection なし、audit なし、state machine なしで live になる | 14* の冒頭 CRITICAL 警告と prerequisite リストは十分。01* / 04\_ にも BLOCKER として明示                                                                 | 14_account-recovery-procedure.md          |
| Audit log integrity が実装済みと読める                                      | Chronicle に "audit log はある" → immutability も達成済みと誤読する                                           | GAP-002 を blocker と認識せずに RFP 要件から外す                    | 全文書で [BLOCKER] として明示。NR-004 の "Missing" 項目も明示。問題なし                                                                                  | 13_normative-baseline.md                  |
| Recovery passcode rate limit gap が存在しないと読める                       | rate limit は "運用上対応済み" と判断する                                                                     | passcode brute-force の known risk が隠蔽される                     | 01/04/13/14 すべてで [KNOWN GAP: no rate limit] として明示。問題なし                                                                                     | —                                         |
| SIer が `/oauth/*` や token issuance に触れてよいと読める                   | token endpoint の実装変更・拡張提案が来る                                                                     | Acme の token authority を侵害する                                  | 01* Section H と 13* の "SIer MUST NOT implement" が明示。十分                                                                                           | —                                         |
| SIer が signing key / JWKS / session limit constants を変更してよいと読める | signing key rotation 提案や session limit 変更提案が来る                                                      | セキュリティ境界破壊                                                | 01* の Non-negotiable Authority Boundaries で明示。13* でも繰り返し                                                                                      | —                                         |

---

## 7. Acceptance Criteria Review

| Area                                  | Current Strength                                                                                               | Missing Evidence                                                                                                                    | Required Improvement                                                                             | RFI/RFP Priority |
| ------------------------------------- | -------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ | ---------------- |
| Account Recovery（14\_）              | ACC-REC-001〜020 の 20 criteria。actor/precondition/operation/expected result が揃っている。audit event も含む | S-005（catastrophic loss）のテスト不可（OPEN BLOCKER）。Identity verification steps が「undefined」のため AC が書けない             | S-005 / identity verification 決定後に AC を追記                                                 | RFP              |
| Social Linking（NR-001）              | 01\_ の Acceptance Evidence table にテスト方法記載。NR-001 が testable な形で記述                              | email-match auto-link の negative test の明示（"attempted but rejected" を証明するテスト）が acceptance criteria に明示されていない | Negative test: "email-match attempted → rejected → audit logged" を AC として追記                | RFI              |
| TOTP Replay（NR-002）                 | NR-002 に testable な記述あり（same credential / purpose / time-step）                                         | replay を試みたことを audit event で証明する acceptance criteria がない                                                             | Audit event evidence を AC に追加                                                                | RFI              |
| Token endpoint null_session（NR-003） | NR-003 に fail-closed behavior 記述あり                                                                        | 「正常に OAuth error を返す」の evidence（e.g., audit log entry や response code）が AC に未記載                                    | expected response format（HTTP 400 + error=invalid_request / audit event）を AC に追加           | RFI              |
| Audit Log Integrity（NR-004）         | 04* に event binding table。13* に minimum event class                                                         | DB-level immutability の "how to verify" が undefined（acceptance criteria 以前に実装方法が未決）                                   | Audit Log Integrity Requirement（15\_）確定後に AC を書く。tamper-attempt negative test を含める | RFP              |
| MFA Reset State Machine（14\_）       | 14 states / transitions の guard conditions が詳細                                                             | invalid transition の rejection を証明するテスト（"transition attempted → rejected → reason logged"）が AC に明示されていない       | State machine negative test（invalid transition）を ACC-REC 追記                                 | RFP              |
| DPoP（13* / 04*）                     | opt-in / Palm 非対応が文書化                                                                                   | DPoP 非対応 client の挙動（bearer fallback）の acceptance evidence が undefined                                                     | DPoP opt-in 挙動の acceptance criteria を docs/architecture/dpop.md または 09\_ に追加           | RFP              |
| Vendor 実装範囲の分離                 | 01* Section H で "SIer May / Must NOT" が明示。14* も SIer scope を分離                                        | "SIer 実装 → 内製側承認" の handoff 検収フローが acceptance criteria に未記載                                                       | handoff 検収フロー（e.g., "SIer submits PR → internal review → sign-off"）を 09\_ に追記         | RFP              |

---

## 8. RFI Package Proposal

### Normative documents（配布可・規範として）

- `docs/vendor/identity/01_responsibility_matrix.md`（要 owner 確定 / DEC namespace 注記追加後）
- `docs/vendor/identity/04_cookie-session-token-matrix.md`
- `docs/vendor/identity/13_normative-baseline.md`（最重要）
- `docs/vendor/identity/14_account-recovery-procedure.md`（OPEN BLOCKER 明示付き）
- `docs/authorization_guide.md`（SIer 向け認可ガイド）

### Context-only documents（配布可・注記必須）

- `docs/vendor/identity/00_readme.md`（更新完了後のみ）
- `docs/vendor/identity/08_threat-model.md`（「DRAFT / context only / not
  normative」を冒頭に太字で明示した上で）
- `docs/vendor/identity/02_responsibility-boundary.md`（未確認だが context only 候補）
- `docs/vendor/identity/05_authentication-flow-inventory.md`（未確認だが context only 候補）
- `docs/vendor/identity/06_failure-taxonomy.md`（未確認だが context only 候補）
- `docs/architecture/dpop.md`（DPoP opt-in の説明として）

### Excluded documents（配布禁止）

- `notes/oauth2-1-compliance-gap.md`（Pinwheel DEC-001/002。non-authoritative /
  stale。RFI から完全除外）
- `docs/spec/authorization_guide.md`（存在しない）
- `docs/security/mfa-reset-account-recovery.md`（14\_ が supersede。旧版）
- `plans/umaxica-immutable-pinwheel.md`（内部 due diligence。絶対に渡さない）

### Internal-only documents

- `plans/umaxica-immutable-pinwheel.md`
- `docs/auth-ceremony/*.md`（evidence-only、DEC-007）
- `adr/*.md`（内部参照用。RFI には直接含めない）
- `docs/security/observability-boundary.md`（内部運用）
- `docs/architecture/controller-lifecycle.md`（内部実装）

### Stale / archive candidate

- `docs/vendor/identity/12_gap-risk-register.md`（更新完了まで配布禁止）
- `docs/vendor/identity/11_decision-register.md`（更新完了まで context only 不可）

### RFP only（RFI 段階では配布しない）

- `docs/vendor/identity/09_acceptance-criteria.md`（内容未確認。RFP 候補）
- `docs/vendor/identity/10_vendor-questions.md`（内容未確認。RFP 候補）
- `docs/vendor/identity/15_audit-log-integrity-requirement.md`（内容確認後に判断）

### Security-vendor only

- `docs/vendor/identity/08_threat-model.md`（full version は security
  vendor のみ。RFI には abstract のみ）
- Audit Log Integrity Requirement（完成後）

---

## 9. RFP Blockers

| Blocker                                        | Why It Blocks RFP                                                                                                 | Owner | Required Output                                                                                                                            | Suggested Next Step                                                                     |
| ---------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- | ----- | ------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------- |
| GAP-002: Chronicle DB-level immutability 不在  | NR-004 が満たされない。SIer が "audit log がある = immutable" と誤読した状態で RFP に入ると後戻り不可             | TBD   | Audit Log Integrity Requirement（15\_）の確定。実装方法（DB trigger / append-only table / restricted role / hash chain）の選択             | 15\_ の現在の内容を確認し、実装方法を決定してから RFP                                   |
| GAP-NEW-006: MFA reset UI DISABLED             | 14\_ の ACC-REC-001〜020 を充足しないと UI 有効化禁止。Identity verification steps（S-004a OPEN BLOCKER）が未定義 | TBD   | Identity verification 方法の決定。S-005 catastrophic recovery path の定義。15\_ audit integrity の決定（audit event の immutability 前提） | 14\_ の OPEN BLOCKERS を順に解消                                                        |
| GAP-NEW-007: Catastrophic recovery undefined   | 全認証情報消失時の対応が undefined では SIer に発注できない                                                       | TBD   | S-005 の recovery path 定義（14\_ の更新）                                                                                                 | 14\_ の OQ-001〜003（identity verification / catastrophic loss / telephone AAL1）を決定 |
| GAP-NEW-001: Recovery passcode rate limit なし | known gap として明示されているが、RFP では SIer scope に入れるか内製対応か決める必要がある                        | TBD   | Rate limit 実装の scope 決定（SIer? 内製?）とスケジュール                                                                                  | Rate limit 実装の内製 vs SIer scope 決定                                                |
| 08_threat-model.md DRAFT                       | owner / review 未完了では RFP の security 要件根拠として使えない                                                  | TBD   | owner 確定、review 完了、approved 昇格                                                                                                     | owner を決定し review をスケジュールする                                                |
| 11_decision-register.md 不完全                 | DEC-012/013 がなく、SIer が null_session / audit integrity の決定根拠を追えない                                   | TBD   | DEC-012/013 追記。Namespace 整理                                                                                                           | 11\_ を更新する                                                                         |
| 12_gap-risk-register.md stale                  | Round 4/5 blockers が全未掲載 → SIer が risk 状況を把握できない                                                   | TBD   | 12\_ の大幅更新                                                                                                                            | pinwheel GAP register との整合更新                                                      |
| 15_audit-log-integrity-requirement.md 未確認   | 存在は確認済みだが内容が監査対象外のため、RFI パッケージとの矛盾が未チェック                                      | TBD   | 内容確認と他文書との整合チェック                                                                                                           | 最優先で内容を確認する                                                                  |
| GQ-06: Telephone-only AAL1                     | org/com の AAL1 要件が未定義では ceremony 要件が書けない                                                          | TBD   | 電話のみの AAL1 を許可するか/追加 verifier 必須かの決定                                                                                    | ビジネス要件で決定してから 14* と 13* を更新                                            |

---

## 10. Audit Log Integrity Requirement Inputs

次に作る
`15_audit-log-integrity-requirement.md`（すでに存在する可能性があるため内容確認後に使用）の入力情報。

### Critical event class（13* / 04* の NR-004 から）

| Category            | Events                                                                                                            |
| ------------------- | ----------------------------------------------------------------------------------------------------------------- |
| Token events        | Access token issuance, refresh token issuance, rotation, reuse detection（family revoke トリガー）, DPoP binding  |
| Session events      | Session create, continue, promote（restricted → active）, restrict, expire, revoke, session limit reject          |
| Credential events   | Passkey register/deregister, TOTP register/deregister, recovery passcode issue/consume/expire, social link/unlink |
| MFA events          | MFA step-up success/failure, MFA reset request/approve/reject/cancel/expire/execute                               |
| Social events       | Social sign-in（new / existing）, email-match attempted and rejected, social callback failure                     |
| Recovery events     | All 20 events in 14_account-recovery-procedure.md Section 8（ACC requirements）                                   |
| Replay events       | TOTP same-window replay attempt, auth code reuse attempt, refresh token reuse（family revoke）                    |
| Operator events     | Operator login, lock/unlock, MFA reset approval, config change                                                    |
| Audit access events | 誰が audit log を read したか（operator access logging）                                                          |

### Chronicle current controls（既存実装）

- `event_uuid` UNIQUE 制約（重複防止）
- application-level sanitization（secrets/tokens/cookies を log に含まない）
- Chronicle テーブルへの append 操作（update/delete は application layer では非推奨）

### Missing integrity controls（13\_ [BLOCKER] より）

- DB-level の UPDATE / DELETE 禁止（DB trigger または restricted DB role）
- Tamper-detection mechanism（hash chain / external sink replication）
- Operator access logging（誰が audit log を読んだかの記録）
- DB-level immutability の証明可能性（"tamper-evident" の evidence をどう提示するか）

### Implementation candidates（13\_ より）

| 候補                                                         | 特徴                                                                    | 優先度              |
| ------------------------------------------------------------ | ----------------------------------------------------------------------- | ------------------- |
| DB trigger（UPDATE/DELETE raise）                            | 最小変更、既存スキーマで対応可能                                        | FIRST OPTION        |
| Append-only table with restricted DB role                    | Chronicle テーブルへの write-only role。application role は INSERT のみ | PREFERRED LONG-TERM |
| Hash chain（event_hash = SHA256(prev_hash \|\| event_data)） | 改ざん検知可能。sequential write 前提                                   | DEFENSE-IN-DEPTH    |
| External sink replication（S3 / external DB）                | off-site immutability。高 cost                                          | FUTURE              |
| ChainSeal                                                    | **future hardening candidate のみ。production baseline ではない**       | DEFERRED            |

### SIer scope

- Audit event 送信コード（SIer 実装範囲の feature に対応する event）
- Operator review UI での audit event 送信（MFA reset ワークフロー）
- Audit event の format 遵守（NR-004 に定義された event class / field）

### Security-vendor scope

- Audit log integrity verification（DB-level immutability の独立検証）
- Tamper-attempt のシミュレーションテスト
- Operator access log の completeness 評価

### Acceptance criteria（最低限）

- Chronicle への direct UPDATE / DELETE が DB level で拒否されること（trigger または role）
- Tamper を試みた場合に detectable であること（hash chain の場合は verification コマンドの提示）
- 最低限の critical event class が全件記録されていること（09\_ の acceptance criteria と整合）
- Operator が audit log を read した場合にその access が記録されること
- Audit log 内に secrets / tokens / auth headers が含まれないこと（NR-004 loggingprohibitions）

### Open questions（Audit Log Integrity Requirement 作成前に決める）

1. DB trigger vs restricted DB role vs both：どれを選ぶか
2. Hash chain を採用するか（sequential write の performance impact）
3. External sink replication のタイムライン（短期 vs 中長期）
4. Operator access logging の実装場所（Chronicle 自身 vs 別テーブル）
5. "tamper-evident" の security vendor への提示方法（何をもって検証完了とするか）

### Relation to NR-004

NR-004 は「append-only or
tamper-detectable」を要件として定義している。15\_ は NR-004 の実装仕様として、具体的な mechanism と acceptance
criteria を定める文書になる。

### Relation to 14_account-recovery-procedure.md

14* Section 8 の 20 audit events が、15* の "critical event
class" の中に含まれる。14* は "何を記録すべきか" を定義し、15* は "その記録が改ざんされていないことを保証する mechanism" を定義する。両文書は補完関係。

### Relation to 08_threat-model.md

08* の Threat T-26（"Log leakage / Log tampering"）が 15* の threat
basis になる。08* が DRAFT のため、15* は NR-004 と 13* を直接参照すること（08* への normative 参照は approved 後まで保留）。

---

## 11. Final Grill

### このまま SIer に渡したら何を誤解されるか

**最大の誤解リスク（上位 5 件）**

1. **00_readme.md を読んで 13_normative-baseline.md と 14_account-recovery-procedure.md を見落とす**。現在の package
   map（00〜12）には両文書が載っていない。SIer は index だけ読んで提案書を書く。

2. **notes/oauth2-1-compliance-gap.md が RFI パッケージに混入した場合、"compliance
   gap" というタイトルから "OAuth 2.1
   compliant 対応が契約上要求されている" と読む**。特に国内 SIer は法的要件と読む可能性が高い。

3. **12_gap-risk-register.md を読んで "主要な gap はすでに解消済み（G-001〜015 が closed 状態）" と判断する**。GAP-002（Chronicle
   immutability BLOCKER）/ GAP-NEW-001/006/007 が一切載っていないため。

4. **11_decision-register.md の DEC 番号と pinwheel の DEC 番号を混同する**。特に "DEC-008" が "social
   linking の rejection" なのか "oauth2-1 gap note の封印" なのかで判断が分岐する。

5. **DPoP を "opt-in
   infrastructure" と読まず "推奨 / 将来必須" と読む**。特にセキュリティベンダーが "best
   practice として DPoP 全面展開を提案" してくる。Palm が DPoP-bound
   token を拒否する事実を見落とす。

### どの docs が古いまま足を引っ張るか

- `12_gap-risk-register.md`（最大）：RFI パッケージに含まれたら "gap はない" と誤読される。更新まで配布禁止。
- `00_readme.md`：index として最初に読まれる文書が最も古い状態。13/14 を見落とす直接原因。
- `11_decision-register.md`：DEC-012/013 がなく、null_session と audit integrity の決定が追跡不能。
- `notes/oauth2-1-compliance-gap.md`：RFI パッケージに混入するだけで誤解を生む。除外徹底が必要。
- `docs/security/mfa-reset-account-recovery.md`：14\_ の superseded 版として残存。参照されると情報が古い。

### どの blocker が見落とされそうか

- **GAP-NEW-007（Catastrophic recovery undefined）**：文書化されているが "OPEN
  BLOCKER" という表現が SIer には "将来検討" と読まれやすい。「MFA reset
  UI 有効化前提条件の一つ」として 5 前提条件リストに明示されているが、pinwheel や 12\_ を読まない SIer には伝わらない。
- **15_audit-log-integrity-requirement.md の未確認内容**：ファイルが存在するのに今回の監査対象外。RFI パッケージに含まれた場合に他文書と矛盾する可能性を未チェックのまま配布することになる。
- **RSK-001（after_action
  :verify_authorized 未採用）**：13\_ で "deferred" として記録されているが、SIer が authorization
  matrix を提案する際に "verify_authorized があれば全 action で authorize! を強制できる" と誤解する可能性。

### どの acceptance criteria がまだ弱いか

- **NR-001 の negative test**：email-match auto-link を "試みたが拒否された" という証跡（audit
  event）を acceptance criteria に含める必要がある。
- **NR-003 の evidence**：null_session fail-closed の expected HTTP response format が AC に未定義。
- **State machine invalid transition**：14\_ に transition 一覧はあるが、"invalid
  transition を試みたら拒否された" という negative test の AC が未記載。
- **DPoP acceptance criteria**：opt-in 挙動（DPoP あり vs
  DPoP なし bearer）の両方を検証する AC が存在しない。
- **Audit
  immutability（NR-004）**：DB-level の implementation が未決のため AC が書けない。これは 15\_ 確定後に追記が必要。

### どの文書が "normative" と言うには危ないか

- `08_threat-model.md`：DRAFT、owner TBD、review 未完了。"normative" と言ってはいけない。
- `11_decision-register.md`：DEC-012/013 欠落、namespace 混在。"complete" と言ってはいけない。
- `12_gap-risk-register.md`：Round 4/5 blockers 未記載。"current" と言ってはいけない。
- `00_readme.md`：package map が stale。"accurate index" と言ってはいけない。

### どの箇所が security-vendor に突かれるか

1. **NR-004 の "DB-level immutability absent"**：security vendor は "audit
   log がある" だけでは受理しない。tamper-evidence の mechanism を求める。
2. **Recovery passcode rate limit なし**：実装レベルの rate limit がない状態は、security
   vendor の brute-force assessment で即座に CRITICAL として出てくる。"known
   gap" として明示されているが、remediation plan がないと突かれる。
3. **after_action :verify_authorized 未採用**：ActionPolicy の "deferred" は security
   vendor には "authorization bypass
   surface" と映る。全 action で authorize! 漏れがないことの evidence を求められる。
4. **TOTP last_otp_at のみで with_lock なし（L-09 / FINDING-06）**：race condition 経由の TOTP
   replay が理論上可能。accept/fix 判断が pending のまま RFP に入ると突かれる。
5. **08_threat-model.md DRAFT / owner TBD**：security vendor は "threat
   model の owner が誰か" を最初に聞く。owner TBD のまま渡すと信頼性を疑われる。

---

## 12. Next Actions（優先順位順・docs/RFI/RFP readiness のみ）

| #   | Action                                                                                                                                                                                                              | 優先度   | 対象文書                                                     | Why                                                                                            |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | ------------------------------------------------------------ | ---------------------------------------------------------------------------------------------- |
| 1   | `15_audit-log-integrity-requirement.md` の内容を read-only で確認し、status / maturity / 他文書との整合を評価する                                                                                                   | CRITICAL | 15_audit-log-integrity-requirement.md                        | 存在するが未確認。RFI パッケージに含まれる可能性があるのに内容不明のままでは配布判断ができない |
| 2   | `12_gap-risk-register.md` を更新する（Round 4/5 blockers を反映：GAP-002 / GAP-NEW-001 / GAP-NEW-006 / GAP-NEW-007 / G-008 CLOSED / G-009 CLOSED）                                                                  | CRITICAL | 12_gap-risk-register.md                                      | 現状配布禁止。RFI パッケージとして最も危険な文書                                               |
| 3   | `00_readme.md` を更新する（13 / 14 / 15 を Related Documents と package map に追加。08\_ に DRAFT 注記追加。notes/ 除外方針を明示）                                                                                 | HIGH     | 00_readme.md                                                 | index 文書が最初に読まれる。SIer が 13/14 を見落とす直接原因                                   |
| 4   | `11_decision-register.md` を更新する（DEC-012 / DEC-013 追記。Pinwheel DEC-001/002 を "notes/ 封印" として追記。namespace 注記追加）                                                                                | HIGH     | 11_decision-register.md                                      | DEC 番号混在リスクと decision tracking の不完全性を解消                                        |
| 5   | `notes/oauth2-1-compliance-gap.md` に INTERNAL ONLY ヘッダを追記し、RFI 除外を徹底する（Pinwheel DEC-001/002 の実施）                                                                                               | HIGH     | notes/oauth2-1-compliance-gap.md                             | RFI パッケージへの混入が最大の誤解リスク                                                       |
| 6   | `docs/security/mfa-reset-account-recovery.md` に "[SUPERSEDED BY 14_account-recovery-procedure.md]" を明示する                                                                                                      | MEDIUM   | docs/security/mfa-reset-account-recovery.md                  | 旧版が参照され続けるリスク                                                                     |
| 7   | `08_threat-model.md` の冒頭に "DRAFT — CONTEXT ONLY — NOT NORMATIVE — owner TBD" を太字で追加し、owner 決定のタスクをスケジュールする                                                                               | MEDIUM   | 08_threat-model.md                                           | RFI 配布前の最低限の対策。RFP 前に approved 昇格が必要                                         |
| 8   | `07_social-linking-policy.md` を read-only で確認し、NR-001 との整合チェックを実施する                                                                                                                              | MEDIUM   | 07_social-linking-policy.md                                  | 今回未確認。Social linking の normative source として 01/13 と矛盾がないか確認必要             |
| 9   | `14_account-recovery-procedure.md` の OPEN BLOCKERS（OQ-001 identity verification / S-005 catastrophic recovery / OQ-002 recovery passcode rate limit）の決定を priority タスクとして登録し、決定後に AC を補完する | MEDIUM   | 14_account-recovery-procedure.md                             | MFA reset UI 有効化の前提条件として最後の詰め                                                  |
| 10  | DEC 番号の namespace を整理する（vendor-facing 11_decision-register.md の DEC を `VDR-` prefix に変更するか、Pinwheel DEC との相互参照マッピング表を作成する）                                                      | MEDIUM   | 11_decision-register.md、plans/umaxica-immutable-pinwheel.md | "DEC-008" が 2 つの意味を持つ状態は SIer 混乱の直接原因                                        |

---

_監査完了: 2026-06-25。WRITE_ACCESS OFF で実施。ファイル変更なし。_
