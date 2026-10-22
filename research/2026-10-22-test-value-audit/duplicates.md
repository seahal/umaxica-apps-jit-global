# Token-identical body groups

107 groups, 375 member definitions. Equality excludes comments and token-separating whitespace/newlines; it preserves literal token values and variable names. It excludes the test title, surrounding setup/teardown, imports, class bindings and loop expansions. This is a candidate index, not proof of redundant behavior.

Confirmed same-owner duplicates and the misleading visitor copy are detailed in [findings](findings.md). Separate policy classes, surfaces, imported functions and generated parameters retain their independent contracts even when their bodies match. Similar but non-identical bodies are not exhaustively identified by hashing.

<a id="dup-0001"></a>
## DUP-0001

Body token hash: `a7a5e40328fe8231a5ececa99b29bb6fc0a57a3fb9bb799a26ae1804e4a8beb4`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-13714](inventory/gait.md#t-13714) | [gait/components/chrome/theme_controls.test.tsx:141](../../gait/components/chrome/theme_controls.test.tsx#L141) | `"ThemeControls rendering"` | "starts from the theme the document was rendered with" | contextual equivalence unverified; do not remove by hash |
| [T-13718](inventory/gait.md#t-13718) | [gait/components/chrome/theme_controls.test.tsx:181](../../gait/components/chrome/theme_controls.test.tsx#L181) | `"ThemeControls mount"` | "keeps the rendered theme when the stored preference cannot be read" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0002"></a>
## DUP-0002

Body token hash: `994732634c010a68e821480ba803e20b04c457a25bef170963cc6e1011e9c7a8`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-13730](inventory/gait.md#t-13730) | [gait/components/confirm_dialog.test.tsx:55](../../gait/components/confirm_dialog.test.tsx#L55) | `"ConfirmDialog"` | "stays closed until a confirmation is pending" | contextual equivalence unverified; do not remove by hash |
| [T-13761](inventory/gait.md#t-13761) | [gait/components/ui/dialog.test.tsx:47](../../gait/components/ui/dialog.test.tsx#L47) | `"Dialog"` | "renders nothing while closed" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0003"></a>
## DUP-0003

Body token hash: `928414ec73ceb69d22d8e42b5269e474afd77c5291e3da66b7b2e9797c73abf7`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-14001](inventory/gait.md#t-14001) | [gait/entrypoints/bootstrap_entrypoints.test.ts:30](../../gait/entrypoints/bootstrap_entrypoints.test.ts#L30) | `"%s entrypoint"` | "imports the shared application bootstrap and registers the offline service worker" | LV-020 |
| [T-14002](inventory/gait.md#t-14002) | [gait/entrypoints/bootstrap_entrypoints.test.ts:43](../../gait/entrypoints/bootstrap_entrypoints.test.ts#L43) | `"%s entrypoint"` | "registers the offline service worker without pulling in the Turbo application bundle" | LV-020 |

<a id="dup-0004"></a>
## DUP-0004

Body token hash: `a67a3fbc4c86bb65d7283f1a4b3413df9491a4e85014970c3c1c653b1e5bfa2b`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-14098](inventory/gait.md#t-14098) | [gait/features/auth/passkeys/invisible_turnstile.test.ts:37](../../gait/features/auth/passkeys/invisible_turnstile.test.ts#L37) | `"solveInvisibleTurnstile"` | "refuses to run without a site key rather than answering an empty token" | retained after inspection |
| [T-14269](inventory/gait.md#t-14269) | [gait/features/auth/turnstile/invisible_token.test.ts:37](../../gait/features/auth/turnstile/invisible_token.test.ts#L37) | `"solveInvisibleTurnstile"` | "refuses to run without a site key rather than answering an empty token" | retained after inspection |

<a id="dup-0005"></a>
## DUP-0005

Body token hash: `b790dd7e5304f93693efda555cbd27e23db43fbb41b3dc6234542b706d1ac237`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-14099](inventory/gait.md#t-14099) | [gait/features/auth/passkeys/invisible_turnstile.test.ts:41](../../gait/features/auth/passkeys/invisible_turnstile.test.ts#L41) | `"solveInvisibleTurnstile"` | "rejects when the Turnstile script never arrived" | retained after inspection |
| [T-14270](inventory/gait.md#t-14270) | [gait/features/auth/turnstile/invisible_token.test.ts:41](../../gait/features/auth/turnstile/invisible_token.test.ts#L41) | `"solveInvisibleTurnstile"` | "rejects when the Turnstile script never arrived" | retained after inspection |

<a id="dup-0006"></a>
## DUP-0006

Body token hash: `7e504503d6b251e798d1c157d4635130c249f0dd9da9cff95b63b906a6832817`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-14100](inventory/gait.md#t-14100) | [gait/features/auth/passkeys/invisible_turnstile.test.ts:47](../../gait/features/auth/passkeys/invisible_turnstile.test.ts#L47) | `"solveInvisibleTurnstile"` | "resolves with the token the invisible widget reports" | retained after inspection |
| [T-14271](inventory/gait.md#t-14271) | [gait/features/auth/turnstile/invisible_token.test.ts:47](../../gait/features/auth/turnstile/invisible_token.test.ts#L47) | `"solveInvisibleTurnstile"` | "resolves with the token the invisible widget reports" | retained after inspection |

<a id="dup-0007"></a>
## DUP-0007

Body token hash: `058f76f75f8995fdc17d88ae4bbbcc435ca5e953a881fcfaf1e028ff8b5622ad`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-14101](inventory/gait.md#t-14101) | [gait/features/auth/passkeys/invisible_turnstile.test.ts:65](../../gait/features/auth/passkeys/invisible_turnstile.test.ts#L65) | `"solveInvisibleTurnstile"` | "mounts the widget inside the host the caller supplied" | retained after inspection |
| [T-14272](inventory/gait.md#t-14272) | [gait/features/auth/turnstile/invisible_token.test.ts:65](../../gait/features/auth/turnstile/invisible_token.test.ts#L65) | `"solveInvisibleTurnstile"` | "mounts the widget inside the host the caller supplied" | retained after inspection |

<a id="dup-0008"></a>
## DUP-0008

Body token hash: `2e48ffb04c7988ca559425b15fd355ccf1d676078cc8c657ba5704227c18da65`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-14102](inventory/gait.md#t-14102) | [gait/features/auth/passkeys/invisible_turnstile.test.ts:78](../../gait/features/auth/passkeys/invisible_turnstile.test.ts#L78) | `"solveInvisibleTurnstile"` | "rejects when Turnstile reports %s" | retained after inspection |
| [T-14273](inventory/gait.md#t-14273) | [gait/features/auth/turnstile/invisible_token.test.ts:78](../../gait/features/auth/turnstile/invisible_token.test.ts#L78) | `"solveInvisibleTurnstile"` | "rejects when Turnstile reports %s" | retained after inspection |

<a id="dup-0009"></a>
## DUP-0009

Body token hash: `394ae438e4d164b0878706b771b1ab532e90bf132bd719c1921fc41afca826d6`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-14103](inventory/gait.md#t-14103) | [gait/features/auth/passkeys/invisible_turnstile.test.ts:93](../../gait/features/auth/passkeys/invisible_turnstile.test.ts#L93) | `"solveInvisibleTurnstile"` | "rejects with the visitor-facing message when rendering itself throws" | retained after inspection |
| [T-14274](inventory/gait.md#t-14274) | [gait/features/auth/turnstile/invisible_token.test.ts:91](../../gait/features/auth/turnstile/invisible_token.test.ts#L91) | `"solveInvisibleTurnstile"` | "rejects with the visitor-facing message when rendering itself throws" | retained after inspection |

<a id="dup-0010"></a>
## DUP-0010

Body token hash: `c86bb50a2d4bd05d74a42eae552035f94ede20f6e2594ac23a06cc24dfc61fc2`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-14125](inventory/gait.md#t-14125) | [gait/features/auth/passkeys/passkey_panels.test.tsx:277](../../gait/features/auth/passkeys/passkey_panels.test.tsx#L277) | `"PasskeyAuthenticationPanel"` | "refuses options that carry no request options" | contextual equivalence unverified; do not remove by hash |
| [T-14141](inventory/gait.md#t-14141) | [gait/features/auth/passkeys/passkey_panels.test.tsx:482](../../gait/features/auth/passkeys/passkey_panels.test.tsx#L482) | `"PasskeyRegistrationPanel"` | "refuses options that carry no creation options" | contextual equivalence unverified; do not remove by hash |
| [T-14261](inventory/gait.md#t-14261) | [gait/features/auth/signup/signup_passkey_registration.test.tsx:197](../../gait/features/auth/signup/signup_passkey_registration.test.tsx#L197) | `"SignUpPasskeyRegistration"` | "refuses options that carry no creation options" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0011"></a>
## DUP-0011

Body token hash: `959ea15afd8a894ddbc8c6ab13290ab7cc401df28bf844eda122218d849382d3`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-14127](inventory/gait.md#t-14127) | [gait/features/auth/passkeys/passkey_panels.test.tsx:293](../../gait/features/auth/passkeys/passkey_panels.test.tsx#L293) | `"PasskeyAuthenticationPanel"` | "falls back to the ceremony message for a JSON refusal that names no reason" | contextual equivalence unverified; do not remove by hash |
| [T-14143](inventory/gait.md#t-14143) | [gait/features/auth/passkeys/passkey_panels.test.tsx:498](../../gait/features/auth/passkeys/passkey_panels.test.tsx#L498) | `"PasskeyRegistrationPanel"` | "falls back to the ceremony message for a JSON refusal that names no reason" | contextual equivalence unverified; do not remove by hash |
| [T-14263](inventory/gait.md#t-14263) | [gait/features/auth/signup/signup_passkey_registration.test.tsx:213](../../gait/features/auth/signup/signup_passkey_registration.test.tsx#L213) | `"SignUpPasskeyRegistration"` | "falls back to the ceremony message for a JSON refusal that names no reason" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0012"></a>
## DUP-0012

Body token hash: `44e89633cc73db126b0a872c241e678806a912f4326820b11b81dc448806224b`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-14128](inventory/gait.md#t-14128) | [gait/features/auth/passkeys/passkey_panels.test.tsx:301](../../gait/features/auth/passkeys/passkey_panels.test.tsx#L301) | `"PasskeyAuthenticationPanel"` | "falls back to the ceremony message for a non-JSON refusal" | contextual equivalence unverified; do not remove by hash |
| [T-14144](inventory/gait.md#t-14144) | [gait/features/auth/passkeys/passkey_panels.test.tsx:506](../../gait/features/auth/passkeys/passkey_panels.test.tsx#L506) | `"PasskeyRegistrationPanel"` | "falls back to the ceremony message for a non-JSON refusal" | contextual equivalence unverified; do not remove by hash |
| [T-14264](inventory/gait.md#t-14264) | [gait/features/auth/signup/signup_passkey_registration.test.tsx:221](../../gait/features/auth/signup/signup_passkey_registration.test.tsx#L221) | `"SignUpPasskeyRegistration"` | "falls back to the ceremony message for a non-JSON refusal" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0013"></a>
## DUP-0013

Body token hash: `0d86d39b2e774e8831757f40a031dd7d35163442c6e46e9d65a472e99e90323c`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-14129](inventory/gait.md#t-14129) | [gait/features/auth/passkeys/passkey_panels.test.tsx:309](../../gait/features/auth/passkeys/passkey_panels.test.tsx#L309) | `"PasskeyAuthenticationPanel"` | "reloads when the session is gone rather than reporting a ceremony failure" | contextual equivalence unverified; do not remove by hash |
| [T-14145](inventory/gait.md#t-14145) | [gait/features/auth/passkeys/passkey_panels.test.tsx:514](../../gait/features/auth/passkeys/passkey_panels.test.tsx#L514) | `"PasskeyRegistrationPanel"` | "reloads when the session is gone rather than reporting a ceremony failure" | contextual equivalence unverified; do not remove by hash |
| [T-14265](inventory/gait.md#t-14265) | [gait/features/auth/signup/signup_passkey_registration.test.tsx:229](../../gait/features/auth/signup/signup_passkey_registration.test.tsx#L229) | `"SignUpPasskeyRegistration"` | "reloads when the session is gone rather than reporting a ceremony failure" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0014"></a>
## DUP-0014

Body token hash: `5d1d63ba4b2e43f53b07cb40b5223246242c901352f53ce53b549244cccfe3c2`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-14132](inventory/gait.md#t-14132) | [gait/features/auth/passkeys/passkey_panels.test.tsx:344](../../gait/features/auth/passkeys/passkey_panels.test.tsx#L344) | `"PasskeyAuthenticationPanel"` | "reports a challenge that could not be presented rather than proceeding without one" | contextual equivalence unverified; do not remove by hash |
| [T-14149](inventory/gait.md#t-14149) | [gait/features/auth/passkeys/passkey_panels.test.tsx:558](../../gait/features/auth/passkeys/passkey_panels.test.tsx#L558) | `"PasskeyRegistrationPanel"` | "reports a challenge that could not be presented rather than proceeding without one" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0015"></a>
## DUP-0015

Body token hash: `14fd64e60e0354cc2d990b300e55a70ee7f3c467cc415d745275560636a1553b`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-14134](inventory/gait.md#t-14134) | [gait/features/auth/passkeys/passkey_panels.test.tsx:388](../../gait/features/auth/passkeys/passkey_panels.test.tsx#L388) | `"PasskeyRegistrationPanel"` | "refuses to start on a browser without WebAuthn" | contextual equivalence unverified; do not remove by hash |
| [T-14152](inventory/gait.md#t-14152) | [gait/features/auth/passkeys/passkey_panels.test.tsx:622](../../gait/features/auth/passkeys/passkey_panels.test.tsx#L622) | `"StepUpPasskeyForm"` | "refuses to start on a browser without WebAuthn" | contextual equivalence unverified; do not remove by hash |
| [T-14253](inventory/gait.md#t-14253) | [gait/features/auth/signup/signup_passkey_registration.test.tsx:87](../../gait/features/auth/signup/signup_passkey_registration.test.tsx#L87) | `"SignUpPasskeyRegistration"` | "refuses to start on a browser without WebAuthn" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0016"></a>
## DUP-0016

Body token hash: `89a75c8c158eca42e7e1ac8781d9dca4e7d35177920ded2f602a329549e84be5`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-14138](inventory/gait.md#t-14138) | [gait/features/auth/passkeys/passkey_panels.test.tsx:456](../../gait/features/auth/passkeys/passkey_panels.test.tsx#L456) | `"PasskeyRegistrationPanel"` | "refuses an answer the authenticator did not shape as an attestation" | contextual equivalence unverified; do not remove by hash |
| [T-14258](inventory/gait.md#t-14258) | [gait/features/auth/signup/signup_passkey_registration.test.tsx:171](../../gait/features/auth/signup/signup_passkey_registration.test.tsx#L171) | `"SignUpPasskeyRegistration"` | "refuses an answer the authenticator did not shape as an attestation" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0017"></a>
## DUP-0017

Body token hash: `6c11b014e7115cb16807e641cc2619989d35acd9ff2b23543ac63855d642c251`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-14139](inventory/gait.md#t-14139) | [gait/features/auth/passkeys/passkey_panels.test.tsx:465](../../gait/features/auth/passkeys/passkey_panels.test.tsx#L465) | `"PasskeyRegistrationPanel"` | "refuses an empty answer from the authenticator" | contextual equivalence unverified; do not remove by hash |
| [T-14259](inventory/gait.md#t-14259) | [gait/features/auth/signup/signup_passkey_registration.test.tsx:180](../../gait/features/auth/signup/signup_passkey_registration.test.tsx#L180) | `"SignUpPasskeyRegistration"` | "refuses an empty answer from the authenticator" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0018"></a>
## DUP-0018

Body token hash: `d0d732fd4801b7cf9b8a6ab940a64eab0e8e75354678b8908da4fbf501513968`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-14140](inventory/gait.md#t-14140) | [gait/features/auth/passkeys/passkey_panels.test.tsx:474](../../gait/features/auth/passkeys/passkey_panels.test.tsx#L474) | `"PasskeyRegistrationPanel"` | "refuses options that carry no challenge id" | contextual equivalence unverified; do not remove by hash |
| [T-14260](inventory/gait.md#t-14260) | [gait/features/auth/signup/signup_passkey_registration.test.tsx:189](../../gait/features/auth/signup/signup_passkey_registration.test.tsx#L189) | `"SignUpPasskeyRegistration"` | "refuses options that carry no challenge id" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0019"></a>
## DUP-0019

Body token hash: `329ef63aac874c293bc59c0f423bdf686ef3b0d35e4b9f0c5466de116eea20e0`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-14146](inventory/gait.md#t-14146) | [gait/features/auth/passkeys/passkey_panels.test.tsx:524](../../gait/features/auth/passkeys/passkey_panels.test.tsx#L524) | `"PasskeyRegistrationPanel"` | "reports a refused verification with the registration message" | contextual equivalence unverified; do not remove by hash |
| [T-14266](inventory/gait.md#t-14266) | [gait/features/auth/signup/signup_passkey_registration.test.tsx:239](../../gait/features/auth/signup/signup_passkey_registration.test.tsx#L239) | `"SignUpPasskeyRegistration"` | "reports a refused verification with the registration message" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0020"></a>
## DUP-0020

Body token hash: `17065818e733efec0ae190acae4fc8b612ac44678b1d83ca39b810f8190b879b`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-14147](inventory/gait.md#t-14147) | [gait/features/auth/passkeys/passkey_panels.test.tsx:536](../../gait/features/auth/passkeys/passkey_panels.test.tsx#L536) | `"PasskeyRegistrationPanel"` | "reloads instead of continuing when the verification session is gone" | contextual equivalence unverified; do not remove by hash |
| [T-14267](inventory/gait.md#t-14267) | [gait/features/auth/signup/signup_passkey_registration.test.tsx:251](../../gait/features/auth/signup/signup_passkey_registration.test.tsx#L251) | `"SignUpPasskeyRegistration"` | "reloads instead of continuing when the verification session is gone" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0021"></a>
## DUP-0021

Body token hash: `3b7d18b1c2203808f07b9b3cc4a45ad7c18e234cec119195b9b8ed0541dc5160`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-14148](inventory/gait.md#t-14148) | [gait/features/auth/passkeys/passkey_panels.test.tsx:549](../../gait/features/auth/passkeys/passkey_panels.test.tsx#L549) | `"PasskeyRegistrationPanel"` | "names an authenticator that already holds this passkey" | contextual equivalence unverified; do not remove by hash |
| [T-14268](inventory/gait.md#t-14268) | [gait/features/auth/signup/signup_passkey_registration.test.tsx:264](../../gait/features/auth/signup/signup_passkey_registration.test.tsx#L264) | `"SignUpPasskeyRegistration"` | "names an authenticator that already holds this passkey" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0022"></a>
## DUP-0022

Body token hash: `eb0bcea11fd17234731af2d635076bd159c054c4561aa1b63891b70ff4cc4ddf`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-14181](inventory/gait.md#t-14181) | [gait/features/auth/session/sign_out_screens.test.tsx:110](../../gait/features/auth/session/sign_out_screens.test.tsx#L110) | `"auth/app sign-out pages"` | "%s re-exports the shared component" | contextual equivalence unverified; do not remove by hash |
| [T-14182](inventory/gait.md#t-14182) | [gait/features/auth/session/sign_out_screens.test.tsx:120](../../gait/features/auth/session/sign_out_screens.test.tsx#L120) | `"palm/app sign-out pages"` | "%s re-exports the shared component" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0023"></a>
## DUP-0023

Body token hash: `4edaf7b0cc27782e78f9f6ca10911a610920801056d142d9864dd4de01709df4`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-14241](inventory/gait.md#t-14241) | [gait/features/auth/signup/csrf.test.ts:10](../../gait/features/auth/signup/csrf.test.ts#L10) | `"sign-up csrfToken"` | "reads the token the layout rendered into the meta tag" | retained after inspection |
| [T-14551](inventory/gait.md#t-14551) | [gait/lib/csrf.test.ts:10](../../gait/lib/csrf.test.ts#L10) | `"csrfToken"` | "reads the token the layout rendered into the meta tag" | retained after inspection |

<a id="dup-0024"></a>
## DUP-0024

Body token hash: `84683c20582f8306f37f3471c504968303e227e7cc1fbb3ff4a44d696cc87dd7`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-14242](inventory/gait.md#t-14242) | [gait/features/auth/signup/csrf.test.ts:16](../../gait/features/auth/signup/csrf.test.ts#L16) | `"sign-up csrfToken"` | "answers an empty string when the layout rendered no tag" | retained after inspection |
| [T-14552](inventory/gait.md#t-14552) | [gait/lib/csrf.test.ts:16](../../gait/lib/csrf.test.ts#L16) | `"csrfToken"` | "answers an empty string when the layout rendered no tag" | retained after inspection |
| [T-14558](inventory/gait.md#t-14558) | [gait/lib/request.test.ts:17](../../gait/lib/request.test.ts#L17) | `"csrfToken"` | "returns an empty string when the meta tag is absent" | retained after inspection |

<a id="dup-0025"></a>
## DUP-0025

Body token hash: `c4e2fd81e3aff30ce30c1e01cd5ec51046013b3008dc5926f33c9f5ec50dae3f`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-14448](inventory/gait.md#t-14448) | [gait/features/landing/root_landing.test.tsx:85](../../gait/features/landing/root_landing.test.tsx#L85) | `"surface root pages"` | "%s renders the shared landing" | contextual equivalence unverified; do not remove by hash |
| [T-14452](inventory/gait.md#t-14452) | [gait/features/landing/surface_root_landing.test.tsx:57](../../gait/features/landing/surface_root_landing.test.tsx#L57) | `"Core, Warp, and Palm root pages"` | "%s renders the shared landing" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0026"></a>
## DUP-0026

Body token hash: `150b6640e7c40c6666022d32aba4c152ffcbd99f4ef9182e80b7cc6762d010f0`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-00391](inventory/rails-controllers-auth.md#t-00391) | [test/controllers/auth/app/edge/v0/token/checks_controller_test.rb:106](../../test/controllers/auth/app/edge/v0/token/checks_controller_test.rb#L106) | `Auth::App::Edge::V0::Token::ChecksControllerTest` | "GET check without access token returns 401" | contextual equivalence unverified; do not remove by hash |
| [T-01126](inventory/rails-controllers-auth.md#t-01126) | [test/controllers/auth/org/edge/v0/token/checks_controller_test.rb:42](../../test/controllers/auth/org/edge/v0/token/checks_controller_test.rb#L42) | `Auth::Org::Edge::V0::Token::ChecksControllerTest` | "GET check without access token returns 401" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0027"></a>
## DUP-0027

Body token hash: `9e850c11285db24b7f5a78ce956070d42570b2b43cb0b1e0e24785c384a852bf`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-00608](inventory/rails-controllers-auth.md#t-00608) | [test/controllers/auth/app/settings_controller_test.rb:75](../../test/controllers/auth/app/settings_controller_test.rb#L75) | `Auth::App::SettingsControllerTest` | "retired credential management routes do not resolve on sign" | contextual equivalence unverified; do not remove by hash |
| [T-00959](inventory/rails-controllers-auth.md#t-00959) | [test/controllers/auth/com/settings_controller_test.rb:65](../../test/controllers/auth/com/settings_controller_test.rb#L65) | `Auth::Com::SettingsControllerTest` | "retired credential management routes do not resolve on sign" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0028"></a>
## DUP-0028

Body token hash: `35251b7b39eeaf36abc9d6810f98b2b11a46e1c983b369f5fd9141de2ba1a23e`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-00609](inventory/rails-controllers-auth.md#t-00609) | [test/controllers/auth/app/settings_controller_test.rb:85](../../test/controllers/auth/app/settings_controller_test.rb#L85) | `Auth::App::SettingsControllerTest` | "migrated identity settings routes do not resolve on sign" | contextual equivalence unverified; do not remove by hash |
| [T-00960](inventory/rails-controllers-auth.md#t-00960) | [test/controllers/auth/com/settings_controller_test.rb:75](../../test/controllers/auth/com/settings_controller_test.rb#L75) | `Auth::Com::SettingsControllerTest` | "migrated identity settings routes do not resolve on sign" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0029"></a>
## DUP-0029

Body token hash: `081c9386227a8058b7df493a4bb5d49f3f1bb123e2262ce78d1fa66c64b129e3`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-00694](inventory/rails-controllers-auth.md#t-00694) | [test/controllers/auth/app/ui_foundation_test.rb:17](../../test/controllers/auth/app/ui_foundation_test.rb#L17) | `Auth::App::UiFoundationTest` | "retired passkey settings route is absent from sign" | contextual equivalence unverified; do not remove by hash |
| [T-00695](inventory/rails-controllers-auth.md#t-00695) | [test/controllers/auth/app/ui_foundation_test.rb:23](../../test/controllers/auth/app/ui_foundation_test.rb#L23) | `Auth::App::UiFoundationTest` | "unauthenticated retired passkey settings entry cannot start a handoff" | LV-031 |

<a id="dup-0030"></a>
## DUP-0030

Body token hash: `adc0ffe390724aeed7bfbd3bd8f0a65ddb2d1246702e523266700dadad1a9637`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-00696](inventory/rails-controllers-auth.md#t-00696) | [test/controllers/auth/app/ui_foundation_test.rb:29](../../test/controllers/auth/app/ui_foundation_test.rb#L29) | `Auth::App::UiFoundationTest` | "totp settings route exists on sign" | contextual equivalence unverified; do not remove by hash |
| [T-00700](inventory/rails-controllers-auth.md#t-00700) | [test/controllers/auth/app/ui_foundation_test.rb:60](../../test/controllers/auth/app/ui_foundation_test.rb#L60) | `Auth::App::UiFoundationTest` | "TOTP registration remains scoped to credential ceremony" | LV-032 |

<a id="dup-0031"></a>
## DUP-0031

Body token hash: `703cb45bc8cfb07eec1f50eb32bbf12093e9befcfa6cbaf04db075a51c9e88f3`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-00874](inventory/rails-controllers-auth.md#t-00874) | [test/controllers/auth/com/application_controller_test.rb:31](../../test/controllers/auth/com/application_controller_test.rb#L31) | `Auth::Com::ApplicationControllerTest` | "reflects localization and theme after actor context is set" | contextual equivalence unverified; do not remove by hash |
| [T-01116](inventory/rails-controllers-auth.md#t-01116) | [test/controllers/auth/org/application_controller_test.rb:32](../../test/controllers/auth/org/application_controller_test.rb#L32) | `Auth::Org::ApplicationControllerTest` | "reflects localization and theme after actor context is set" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0032"></a>
## DUP-0032

Body token hash: `6828677629c6774515e38e65713c12dd3b7ab68c6b6b457f22529a61cf79b41c`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-00875](inventory/rails-controllers-auth.md#t-00875) | [test/controllers/auth/com/application_controller_test.rb:51](../../test/controllers/auth/com/application_controller_test.rb#L51) | `Auth::Com::ApplicationControllerTest` | "clears actor context through around lifecycle" | contextual equivalence unverified; do not remove by hash |
| [T-01117](inventory/rails-controllers-auth.md#t-01117) | [test/controllers/auth/org/application_controller_test.rb:52](../../test/controllers/auth/org/application_controller_test.rb#L52) | `Auth::Org::ApplicationControllerTest` | "clears actor context through around lifecycle" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0033"></a>
## DUP-0033

Body token hash: `db7e47e1803305d70ca2c3167f080be3b99643f497336a0967c6e688eb60418a`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-00930](inventory/rails-controllers-auth.md#t-00930) | [test/controllers/auth/com/in/guards_controller_test.rb:20](../../test/controllers/auth/com/in/guards_controller_test.rb#L20) | `Auth::Com::Sign::In::GuardsControllerTest` | "guard state redirects to check without mutating durable rows or cycle state" | contextual equivalence unverified; do not remove by hash |
| [T-01157](inventory/rails-controllers-auth.md#t-01157) | [test/controllers/auth/org/in/guards_controller_test.rb:22](../../test/controllers/auth/org/in/guards_controller_test.rb#L22) | `Auth::Org::Sign::In::GuardsControllerTest` | "guard state redirects to check without mutating durable rows or cycle state" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0034"></a>
## DUP-0034

Body token hash: `8a1a0201229b03f4fde1295f4eadb8f348fa4d0ce7f72fdf5b8c35817960cac0`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-00931](inventory/rails-controllers-auth.md#t-00931) | [test/controllers/auth/com/in/guards_controller_test.rb:33](../../test/controllers/auth/com/in/guards_controller_test.rb#L33) | `Auth::Com::Sign::In::GuardsControllerTest` | "checkpoint state redirects to check" | contextual equivalence unverified; do not remove by hash |
| [T-01158](inventory/rails-controllers-auth.md#t-01158) | [test/controllers/auth/org/in/guards_controller_test.rb:35](../../test/controllers/auth/org/in/guards_controller_test.rb#L35) | `Auth::Org::Sign::In::GuardsControllerTest` | "checkpoint state redirects to check" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0035"></a>
## DUP-0035

Body token hash: `1b596f6e58cd0b5073825eb220562caa634c5d139bef500ad57786046e0c770e`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-00932](inventory/rails-controllers-auth.md#t-00932) | [test/controllers/auth/com/in/guards_controller_test.rb:44](../../test/controllers/auth/com/in/guards_controller_test.rb#L44) | `Auth::Com::Sign::In::GuardsControllerTest` | "selector state redirects to selector sequence path" | contextual equivalence unverified; do not remove by hash |
| [T-01159](inventory/rails-controllers-auth.md#t-01159) | [test/controllers/auth/org/in/guards_controller_test.rb:46](../../test/controllers/auth/org/in/guards_controller_test.rb#L46) | `Auth::Org::Sign::In::GuardsControllerTest` | "selector state redirects to selector sequence path" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0036"></a>
## DUP-0036

Body token hash: `a5c9858696d3d5826571e2db8213a5afb5de39209522f7a022c085cc0be3fcc7`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-00933](inventory/rails-controllers-auth.md#t-00933) | [test/controllers/auth/com/in/guards_controller_test.rb:53](../../test/controllers/auth/com/in/guards_controller_test.rb#L53) | `Auth::Com::Sign::In::GuardsControllerTest` | "session issuance state redirects to welcome sequence path" | contextual equivalence unverified; do not remove by hash |
| [T-01160](inventory/rails-controllers-auth.md#t-01160) | [test/controllers/auth/org/in/guards_controller_test.rb:55](../../test/controllers/auth/org/in/guards_controller_test.rb#L55) | `Auth::Org::Sign::In::GuardsControllerTest` | "session issuance state redirects to welcome sequence path" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0037"></a>
## DUP-0037

Body token hash: `b78dcb41d783da0ea502d2bd12eb3b22b0852d6eb3b3d51b1c5a90f5c766a786`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-00934](inventory/rails-controllers-auth.md#t-00934) | [test/controllers/auth/com/in/guards_controller_test.rb:64](../../test/controllers/auth/com/in/guards_controller_test.rb#L64) | `Auth::Com::Sign::In::GuardsControllerTest` | "unsafe path target redirects to sign in entry without flash" | contextual equivalence unverified; do not remove by hash |
| [T-01161](inventory/rails-controllers-auth.md#t-01161) | [test/controllers/auth/org/in/guards_controller_test.rb:66](../../test/controllers/auth/org/in/guards_controller_test.rb#L66) | `Auth::Org::Sign::In::GuardsControllerTest` | "unsafe path target redirects to sign in entry without flash" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0038"></a>
## DUP-0038

Body token hash: `7b1c699b9b4950314774512b2aa8531bfafd7adcfdbe5d2d186dd50fd46e3ee8`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-00935](inventory/rails-controllers-auth.md#t-00935) | [test/controllers/auth/com/in/guards_controller_test.rb:74](../../test/controllers/auth/com/in/guards_controller_test.rb#L74) | `Auth::Com::Sign::In::GuardsControllerTest` | "unsafe return target redirects to sign in entry without flash" | contextual equivalence unverified; do not remove by hash |
| [T-01162](inventory/rails-controllers-auth.md#t-01162) | [test/controllers/auth/org/in/guards_controller_test.rb:76](../../test/controllers/auth/org/in/guards_controller_test.rb#L76) | `Auth::Org::Sign::In::GuardsControllerTest` | "unsafe return target redirects to sign in entry without flash" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0039"></a>
## DUP-0039

Body token hash: `bcf2e165b43e03f2d18546e7251824dd8f3402dcd24c978816b5380e1e6a936f`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-01365](inventory/rails-controllers-base.md#t-01365) | [test/controllers/base/app/application_controller_test.rb:24](../../test/controllers/base/app/application_controller_test.rb#L24) | `Base::App::ApplicationControllerTest` | test_has_preference_related_before_action_callbacks | contextual equivalence unverified; do not remove by hash |
| [T-01679](inventory/rails-controllers-base.md#t-01679) | [test/controllers/base/com/application_controller_test.rb:26](../../test/controllers/base/com/application_controller_test.rb#L26) | `Base::Com::ApplicationControllerTest` | "has preference-related before_action callbacks" | contextual equivalence unverified; do not remove by hash |
| [T-02017](inventory/rails-controllers-base.md#t-02017) | [test/controllers/base/org/application_controller_test.rb:27](../../test/controllers/base/org/application_controller_test.rb#L27) | `Base::Org::ApplicationControllerTest` | "has preference-related before_action callbacks" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0040"></a>
## DUP-0040

Body token hash: `038b58b8e561986c39606ce3fba725f0eb2b8c9e02981cbcf4be92f7fae0509a`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-01366](inventory/rails-controllers-base.md#t-01366) | [test/controllers/base/app/application_controller_test.rb:34](../../test/controllers/base/app/application_controller_test.rb#L34) | `Base::App::ApplicationControllerTest` | test_has_correct_callback_order | contextual equivalence unverified; do not remove by hash |
| [T-01680](inventory/rails-controllers-base.md#t-01680) | [test/controllers/base/com/application_controller_test.rb:36](../../test/controllers/base/com/application_controller_test.rb#L36) | `Base::Com::ApplicationControllerTest` | "has correct callback order" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0041"></a>
## DUP-0041

Body token hash: `687155321f6a1c3536df8c17f93131f26d918756c8285755dcea54c23c9cd920`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-01367](inventory/rails-controllers-base.md#t-01367) | [test/controllers/base/app/application_controller_test.rb:64](../../test/controllers/base/app/application_controller_test.rb#L64) | `Base::App::ApplicationControllerTest` | test_clears_actor_context_through_around_lifecycle | contextual equivalence unverified; do not remove by hash |
| [T-01681](inventory/rails-controllers-base.md#t-01681) | [test/controllers/base/com/application_controller_test.rb:66](../../test/controllers/base/com/application_controller_test.rb#L66) | `Base::Com::ApplicationControllerTest` | "clears actor context through around lifecycle" | contextual equivalence unverified; do not remove by hash |
| [T-02019](inventory/rails-controllers-base.md#t-02019) | [test/controllers/base/org/application_controller_test.rb:61](../../test/controllers/base/org/application_controller_test.rb#L61) | `Base::Org::ApplicationControllerTest` | "clears actor context through around lifecycle" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0042"></a>
## DUP-0042

Body token hash: `ea3c0fc3b977902f93ce87ec7fe0880a7592eddf3cb721e131c4d1d5489c54f0`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-01638](inventory/rails-controllers-base.md#t-01638) | [test/controllers/base/app/welcome_dashboard_authority_slice_1c_test.rb:522](../../test/controllers/base/app/welcome_dashboard_authority_slice_1c_test.rb#L522) | `Base::App::WelcomeDashboardAuthoritySlice1CTest` | "anonymous direct dashboard request reaches the same Base passive Sign entry" | contextual equivalence unverified; do not remove by hash |
| [T-01822](inventory/rails-controllers-base.md#t-01822) | [test/controllers/base/com/welcome_dashboard_authority_slice_1c_test.rb:514](../../test/controllers/base/com/welcome_dashboard_authority_slice_1c_test.rb#L514) | `Base::Com::WelcomeDashboardAuthoritySlice1CTest` | "anonymous direct dashboard request reaches the same Base passive Sign entry" | contextual equivalence unverified; do not remove by hash |
| [T-02276](inventory/rails-controllers-base.md#t-02276) | [test/controllers/base/org/welcome_dashboard_authority_slice_1c_test.rb:513](../../test/controllers/base/org/welcome_dashboard_authority_slice_1c_test.rb#L513) | `Base::Org::WelcomeDashboardAuthoritySlice1CTest` | "anonymous direct dashboard request reaches the same Base passive Sign entry" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0043"></a>
## DUP-0043

Body token hash: `f2e1bd31dc8bfb1bc48e1674266979c53d75933ad8ed63c729a8c75b22eed34b`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-02046](inventory/rails-controllers-base.md#t-02046) | [test/controllers/base/org/dashboard_avatar_images_controller_test.rb:1270](../../test/controllers/base/org/dashboard_avatar_images_controller_test.rb#L1270) | `Base::Org::DashboardAvatarImagesControllerTest` | "com exposes no Avatar image route" | contextual equivalence unverified; do not remove by hash |
| [T-03776](inventory/rails-integration.md#t-03776) | [test/integration/base_dashboard_image_authentication_boundary_test.rb:68](../../test/integration/base_dashboard_image_authentication_boundary_test.rb#L68) | `BaseDashboardImageAuthenticationBoundaryTest` | "com has no dashboard Avatar image endpoint" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0044"></a>
## DUP-0044

Body token hash: `12b8b05ed7137d0960068cbe779073868254dccd72abbfa1a66a8fac326a7a81`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-02425](inventory/rails-controllers-concerns.md#t-02425) | [test/controllers/concerns/auth/base_test.rb:274](../../test/controllers/concerns/auth/base_test.rb#L274) | `Auth::BaseTest` | "Token.extract_resource_type returns nil for nil payload" | contextual equivalence unverified; do not remove by hash |
| [T-02458](inventory/rails-controllers-concerns.md#t-02458) | [test/controllers/concerns/auth/base_token_test.rb:46](../../test/controllers/concerns/auth/base_token_test.rb#L46) | `Auth::BaseTokenTest` | "Token.extract_resource_type returns nil for nil payload" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0045"></a>
## DUP-0045

Body token hash: `79eae8a112bb8b427a46f29d6fc4cd41216199670dc54ff5ed55a113e5395be6`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-02484](inventory/rails-controllers-concerns.md#t-02484) | [test/controllers/concerns/auth/client_test.rb:35](../../test/controllers/concerns/auth/client_test.rb#L35) | `Auth::AuthClientConcernTest` | "am_i_owner? returns false" | contextual equivalence unverified; do not remove by hash |
| [T-02510](inventory/rails-controllers-concerns.md#t-02510) | [test/controllers/concerns/auth/operator_test.rb:35](../../test/controllers/concerns/auth/operator_test.rb#L35) | `Auth::AuthOperatorConcernTest` | "am_i_owner? returns false" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0046"></a>
## DUP-0046

Body token hash: `2be1baf3adfcfd8225b522c7cb0f7b2a45fb7d24c99884722f2c42173f1601d0`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-02587](inventory/rails-controllers-concerns.md#t-02587) | [test/controllers/concerns/authentication/client_included_do_test.rb:13](../../test/controllers/concerns/authentication/client_included_do_test.rb#L13) | `AuthenticationClientIncludedDoTest` | "included do includes AuthenticationBase module" | contextual equivalence unverified; do not remove by hash |
| [T-02668](inventory/rails-controllers-concerns.md#t-02668) | [test/controllers/concerns/authentication/operator_included_do_test.rb:13](../../test/controllers/concerns/authentication/operator_included_do_test.rb#L13) | `AuthenticationOperatorIncludedDoTest` | "included do includes AuthenticationBase module" | contextual equivalence unverified; do not remove by hash |
| [T-02744](inventory/rails-controllers-concerns.md#t-02744) | [test/controllers/concerns/authentication/visitor_included_do_test.rb:13](../../test/controllers/concerns/authentication/visitor_included_do_test.rb#L13) | `AuthenticationVisitorIncludedDoTest` | "included do includes AuthenticationBase module" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0047"></a>
## DUP-0047

Body token hash: `0a3747c68aea211a7395f8f68915bfbed062e1816dac8006cd3ad26fc895a710`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-02588](inventory/rails-controllers-concerns.md#t-02588) | [test/controllers/concerns/authentication/client_included_do_test.rb:17](../../test/controllers/concerns/authentication/client_included_do_test.rb#L17) | `AuthenticationClientIncludedDoTest` | "included do includes AuthorizationAudit module" | LV-014 |
| [T-02669](inventory/rails-controllers-concerns.md#t-02669) | [test/controllers/concerns/authentication/operator_included_do_test.rb:17](../../test/controllers/concerns/authentication/operator_included_do_test.rb#L17) | `AuthenticationOperatorIncludedDoTest` | "included do includes AuthorizationAudit module" | LV-014 |
| [T-02745](inventory/rails-controllers-concerns.md#t-02745) | [test/controllers/concerns/authentication/visitor_included_do_test.rb:17](../../test/controllers/concerns/authentication/visitor_included_do_test.rb#L17) | `AuthenticationVisitorIncludedDoTest` | "included do includes AuthorizationAudit module" | LV-014 |

<a id="dup-0048"></a>
## DUP-0048

Body token hash: `252276abd7ded1969800cc3e119ad65ca8f86e8d352bf88bbe6a3497cb0092ce`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-02729](inventory/rails-controllers-concerns.md#t-02729) | [test/controllers/concerns/authentication/token_service_test.rb:59](../../test/controllers/concerns/authentication/token_service_test.rb#L59) | `AuthenticationTokenServiceTest` | "resource_type_scope_matches? returns true for matching user" | contextual equivalence unverified; do not remove by hash |
| [T-02732](inventory/rails-controllers-concerns.md#t-02732) | [test/controllers/concerns/authentication/token_service_test.rb:77](../../test/controllers/concerns/authentication/token_service_test.rb#L77) | `AuthenticationTokenServiceTest` | "resource_type_scope_matches? returns true for matching visitor" | LV-030 |

<a id="dup-0049"></a>
## DUP-0049

Body token hash: `9b60bf2c0c590c52f0e3ed7151ca678c59e1edfa2264b5324238b76177a39d7f`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-02786](inventory/rails-controllers-concerns.md#t-02786) | [test/controllers/concerns/authorization_audit_included_do_test.rb:14](../../test/controllers/concerns/authorization_audit_included_do_test.rb#L14) | `AuthorizationAuditIncludedDoTest` | "included do includes CommonRedirect module" | contextual equivalence unverified; do not remove by hash |
| [T-03046](inventory/rails-controllers-concerns.md#t-03046) | [test/controllers/concerns/sign/error_responses_included_do_test.rb:12](../../test/controllers/concerns/sign/error_responses_included_do_test.rb#L12) | `SignErrorResponsesIncludedDoTest` | "included do includes CommonRedirect module" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0050"></a>
## DUP-0050

Body token hash: `92e4deb11dc97d080c9e7f18b977019e03c2d78a48f33d29bef87bdbca4f3bee`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-02787](inventory/rails-controllers-concerns.md#t-02787) | [test/controllers/concerns/authorization_audit_included_do_test.rb:19](../../test/controllers/concerns/authorization_audit_included_do_test.rb#L19) | `AuthorizationAuditIncludedDoTest` | "safe_redirect_back_or_to method available via included CommonRedirect" | contextual equivalence unverified; do not remove by hash |
| [T-03052](inventory/rails-controllers-concerns.md#t-03052) | [test/controllers/concerns/sign/error_responses_included_do_test.rb:47](../../test/controllers/concerns/sign/error_responses_included_do_test.rb#L47) | `SignErrorResponsesIncludedDoTest` | "safe_redirect_back_or_to method available via included CommonRedirect" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0051"></a>
## DUP-0051

Body token hash: `003189961e801c06b4aaa40ea2126c2441396c438d3da02aadc86d0bb6e6bcbf`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-02846](inventory/rails-controllers-concerns.md#t-02846) | [test/controllers/concerns/common/redirect_test.rb:41](../../test/controllers/concerns/common/redirect_test.rb#L41) | `CommonRedirectTest` | "normalize_host returns nil for blank values" | contextual equivalence unverified; do not remove by hash |
| [T-02850](inventory/rails-controllers-concerns.md#t-02850) | [test/controllers/concerns/common_redirect_test.rb:10](../../test/controllers/concerns/common_redirect_test.rb#L10) | `CommonRedirectTest` | "normalize_host returns nil for blank input" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0052"></a>
## DUP-0052

Body token hash: `adb40ba15405deee342ed58fa3d0f39d139cdff5db20ea66476e84fc4a4bf663`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-03030](inventory/rails-controllers-concerns.md#t-03030) | [test/controllers/concerns/sign/email_registrable_included_do_test.rb:18](../../test/controllers/concerns/sign/email_registrable_included_do_test.rb#L18) | `SignEmailRegistrableIncludedDoTest` | "terminal controller includes CommonRedirect explicitly" | contextual equivalence unverified; do not remove by hash |
| [T-03037](inventory/rails-controllers-concerns.md#t-03037) | [test/controllers/concerns/sign/email_registration_flow_included_do_test.rb:18](../../test/controllers/concerns/sign/email_registration_flow_included_do_test.rb#L18) | `SignEmailRegistrationFlowIncludedDoTest` | "terminal controller includes CommonRedirect explicitly" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0053"></a>
## DUP-0053

Body token hash: `f667b76459f5c0f96937aa16fa9de73441c1def20d8f6b9213a4c504474c1e6a`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-03320](inventory/rails-controllers-warp.md#t-03320) | [test/controllers/warp/app/dashboards_controller_test.rb:97](../../test/controllers/warp/app/dashboards_controller_test.rb#L97) | `Warp::App::DashboardsControllerTest` | "anonymous direct dashboard request returns 404 without redirect" | contextual equivalence unverified; do not remove by hash |
| [T-03344](inventory/rails-controllers-warp.md#t-03344) | [test/controllers/warp/com/dashboards_controller_test.rb:97](../../test/controllers/warp/com/dashboards_controller_test.rb#L97) | `Warp::Com::DashboardsControllerTest` | "anonymous direct dashboard request returns 404 without redirect" | contextual equivalence unverified; do not remove by hash |
| [T-03364](inventory/rails-controllers-warp.md#t-03364) | [test/controllers/warp/org/dashboards_controller_test.rb:97](../../test/controllers/warp/org/dashboards_controller_test.rb#L97) | `Warp::Org::DashboardsControllerTest` | "anonymous direct dashboard request returns 404 without redirect" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0054"></a>
## DUP-0054

Body token hash: `cf9fb0de014b553b3ebffdea90200f38797997239d9fc7b868b41080b2247925`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-03482](inventory/rails-forms.md#t-03482) | [test/forms/publishing/create_entry_form_test.rb:67](../../test/forms/publishing/create_entry_form_test.rb#L67) | `Publishing::CreateEntryFormTest` | "a blank title is refused" | contextual equivalence unverified; do not remove by hash |
| [T-03487](inventory/rails-forms.md#t-03487) | [test/forms/publishing/revise_entry_form_test.rb:24](../../test/forms/publishing/revise_entry_form_test.rb#L24) | `Publishing::ReviseEntryFormTest` | "a blank title is refused" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0055"></a>
## DUP-0055

Body token hash: `015064baf13d13e749b51898c7793a07210cddff367db39b395b58861d862243`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-03803](inventory/rails-integration.md#t-03803) | [test/integration/com_social_login_blocked_test.rb:34](../../test/integration/com_social_login_blocked_test.rb#L34) | `ComSocialLoginBlockedTest` | "POST /social/google on service host does not return 404" | contextual equivalence unverified; do not remove by hash |
| [T-04287](inventory/rails-integration.md#t-04287) | [test/integration/org_social_login_blocked_test.rb:260](../../test/integration/org_social_login_blocked_test.rb#L260) | `OrgSocialLoginBlockedTest` | "app social route remains available on app host" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0056"></a>
## DUP-0056

Body token hash: `744dc099398f32ab394e1132afe46855f2930ca9659554dcd30f87a16c106bed`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-04534](inventory/rails-integration.md#t-04534) | [test/integration/routes/docs_route_contract_test.rb:22](../../test/integration/routes/docs_route_contract_test.rb#L22) | `DocsRouteContractTest` | "docs private origin hosts route to the matching surface" | contextual equivalence unverified; do not remove by hash |
| [T-04549](inventory/rails-integration.md#t-04549) | [test/integration/routes/help_route_contract_test.rb:17](../../test/integration/routes/help_route_contract_test.rb#L17) | `HelpRouteContractTest` | "help private origin hosts route to the matching surface" | contextual equivalence unverified; do not remove by hash |
| [T-04571](inventory/rails-integration.md#t-04571) | [test/integration/routes/news_route_contract_test.rb:22](../../test/integration/routes/news_route_contract_test.rb#L22) | `NewsRouteContractTest` | "news private origin hosts route to the matching surface" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0057"></a>
## DUP-0057

Body token hash: `0db41e77d8f9be9f099810261037f1135285a41f3767a9fab3295cab80b7d46f`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-05481](inventory/rails-models-a.md#t-05481) | [test/models/actor/authz_test.rb:7](../../test/models/actor/authz_test.rb#L7) | `ActorAuthzConcernTest` | "NULL constant is a frozen null instance" | contextual equivalence unverified; do not remove by hash |
| [T-12894](inventory/rails-unit.md#t-12894) | [test/unit/actor/authz_test.rb:8](../../test/unit/actor/authz_test.rb#L8) | `ActorAuthzTest` | "NULL constant is a frozen null instance" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0058"></a>
## DUP-0058

Body token hash: `9b50e492c0449e804f80b34360a344c531d10a0556d8192b9d2bec8b40ca015d`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-05484](inventory/rails-models-a.md#t-05484) | [test/models/actor/authz_test.rb:26](../../test/models/actor/authz_test.rb#L26) | `ActorAuthzConcernTest` | "null? returns false when policy user is present" | contextual equivalence unverified; do not remove by hash |
| [T-12898](inventory/rails-unit.md#t-12898) | [test/unit/actor/authz_test.rb:37](../../test/unit/actor/authz_test.rb#L37) | `ActorAuthzTest` | "null? returns false when policy_user is present" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0059"></a>
## DUP-0059

Body token hash: `b3a9fffa0f1800d20c3c8b81f9a858cc1216a2791b6a5b43e2ddaf1f0a7813f9`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-05485](inventory/rails-models-a.md#t-05485) | [test/models/actor/authz_test.rb:32](../../test/models/actor/authz_test.rb#L32) | `ActorAuthzConcernTest` | "null? returns false when token claims are present" | contextual equivalence unverified; do not remove by hash |
| [T-12899](inventory/rails-unit.md#t-12899) | [test/unit/actor/authz_test.rb:43](../../test/unit/actor/authz_test.rb#L43) | `ActorAuthzTest` | "null? returns false when token_claims is present" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0060"></a>
## DUP-0060

Body token hash: `a78deae29012a994e8ed28d559b61e9e3eaf7254a685f11ca52d65cccf34bc58`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-05486](inventory/rails-models-a.md#t-05486) | [test/models/actor/authz_test.rb:38](../../test/models/actor/authz_test.rb#L38) | `ActorAuthzConcernTest` | "null? returns false when surface is present" | contextual equivalence unverified; do not remove by hash |
| [T-12900](inventory/rails-unit.md#t-12900) | [test/unit/actor/authz_test.rb:49](../../test/unit/actor/authz_test.rb#L49) | `ActorAuthzTest` | "null? returns false when surface is present" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0061"></a>
## DUP-0061

Body token hash: `c68d0c81f3acd895bad2c0a9351c35752948afccba08845a079bd9bdb2e87fb5`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-05618](inventory/rails-models-a.md#t-05618) | [test/models/app_preference_binding_method_test.rb:60](../../test/models/app_preference_binding_method_test.rb#L60) | `AppPreferenceBindingMethodTest` | "ensure_defaults! skips existing records" | contextual equivalence unverified; do not remove by hash |
| [T-05619](inventory/rails-models-a.md#t-05619) | [test/models/app_preference_binding_method_test.rb:66](../../test/models/app_preference_binding_method_test.rb#L66) | `AppPreferenceBindingMethodTest` | "ensure_defaults! does nothing when all exist" | LV-033 |

<a id="dup-0062"></a>
## DUP-0062

Body token hash: `4aeb03fade77feafdc7435ec90aab7faeb4df3f453ed483488a1cdeedff4c0fe`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-05632](inventory/rails-models-a.md#t-05632) | [test/models/app_preference_chronicle_test.rb:56](../../test/models/app_preference_chronicle_test.rb#L56) | `AppPreferenceChronicleTest` | "uses bigint primary key" | contextual equivalence unverified; do not remove by hash |
| [T-06184](inventory/rails-models-c.md#t-06184) | [test/models/client_chronicle_test.rb:61](../../test/models/client_chronicle_test.rb#L61) | `ClientChronicleTest` | "uses bigint primary key" | contextual equivalence unverified; do not remove by hash |
| [T-06726](inventory/rails-models-c.md#t-06726) | [test/models/com_preference_chronicle_test.rb:58](../../test/models/com_preference_chronicle_test.rb#L58) | `ComPreferenceChronicleTest` | "uses bigint primary key" | contextual equivalence unverified; do not remove by hash |
| [T-07691](inventory/rails-models-o.md#t-07691) | [test/models/operator_chronicle_test.rb:64](../../test/models/operator_chronicle_test.rb#L64) | `OperatorChronicleTest` | "uses bigint primary key" | contextual equivalence unverified; do not remove by hash |
| [T-08110](inventory/rails-models-o.md#t-08110) | [test/models/org_preference_chronicle_test.rb:57](../../test/models/org_preference_chronicle_test.rb#L57) | `OrgPreferenceChronicleTest` | "uses bigint primary key" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0063"></a>
## DUP-0063

Body token hash: `c55f1386a8572bc4529e7616041d9b696753d9dfe560b581c380c253916fb178`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-05637](inventory/rails-models-a.md#t-05637) | [test/models/app_preference_chronicle_test.rb:81](../../test/models/app_preference_chronicle_test.rb#L81) | `AppPreferenceChronicleTest` | "validates presence of subject_id" | contextual equivalence unverified; do not remove by hash |
| [T-06732](inventory/rails-models-c.md#t-06732) | [test/models/com_preference_chronicle_test.rb:89](../../test/models/com_preference_chronicle_test.rb#L89) | `ComPreferenceChronicleTest` | "validates presence of subject_id" | contextual equivalence unverified; do not remove by hash |
| [T-08116](inventory/rails-models-o.md#t-08116) | [test/models/org_preference_chronicle_test.rb:88](../../test/models/org_preference_chronicle_test.rb#L88) | `OrgPreferenceChronicleTest` | "validates presence of subject_id" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0064"></a>
## DUP-0064

Body token hash: `521fd6eec0cc1efcec9123e08df6378e162387a39a9782d92bce250aeb684f6b`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-05638](inventory/rails-models-a.md#t-05638) | [test/models/app_preference_chronicle_test.rb:87](../../test/models/app_preference_chronicle_test.rb#L87) | `AppPreferenceChronicleTest` | "validates presence of subject_type" | contextual equivalence unverified; do not remove by hash |
| [T-06733](inventory/rails-models-c.md#t-06733) | [test/models/com_preference_chronicle_test.rb:95](../../test/models/com_preference_chronicle_test.rb#L95) | `ComPreferenceChronicleTest` | "validates presence of subject_type" | contextual equivalence unverified; do not remove by hash |
| [T-08117](inventory/rails-models-o.md#t-08117) | [test/models/org_preference_chronicle_test.rb:94](../../test/models/org_preference_chronicle_test.rb#L94) | `OrgPreferenceChronicleTest` | "validates presence of subject_type" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0065"></a>
## DUP-0065

Body token hash: `155084da88b5bd882d68bd9a802d45230da4d172bbfbc514a6e008ac2879dd1a`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-06186](inventory/rails-models-c.md#t-06186) | [test/models/client_chronicle_test.rb:69](../../test/models/client_chronicle_test.rb#L69) | `ClientChronicleTest` | "ip_address can be stored" | contextual equivalence unverified; do not remove by hash |
| [T-07693](inventory/rails-models-o.md#t-07693) | [test/models/operator_chronicle_test.rb:72](../../test/models/operator_chronicle_test.rb#L72) | `OperatorChronicleTest` | "ip_address can be stored" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0066"></a>
## DUP-0066

Body token hash: `aaa6d2e5aae5f90eff90bf8474ece84631a3d6dde0bb7181bb372ce1acbef6c2`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-06214](inventory/rails-models-c.md#t-06214) | [test/models/client_email_test.rb:78](../../test/models/client_email_test.rb#L78) | `ClientEmailTest` | "should include Email concern" | contextual equivalence unverified; do not remove by hash |
| [T-06916](inventory/rails-models-concerns.md#t-06916) | [test/models/concerns/email_test.rb:32](../../test/models/concerns/email_test.rb#L32) | `EmailTest` | "concern can be included in a class" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0067"></a>
## DUP-0067

Body token hash: `730895745b4ff47206cc07f23179efc90700e0e399b477c087c96f1d4f093a24`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-06617](inventory/rails-models-c.md#t-06617) | [test/models/client_token_test.rb:200](../../test/models/client_token_test.rb#L200) | `ClientTokenTest` | "deleting the current token clears only its session pointer" | contextual equivalence unverified; do not remove by hash |
| [T-08035](inventory/rails-models-o.md#t-08035) | [test/models/operator_token_test.rb:160](../../test/models/operator_token_test.rb#L160) | `OperatorTokenTest` | "deleting the current token clears only its session pointer" | contextual equivalence unverified; do not remove by hash |
| [T-09230](inventory/rails-models-v.md#t-09230) | [test/models/visitor_token_test.rb:197](../../test/models/visitor_token_test.rb#L197) | `VisitorTokenTest` | "deleting the current token clears only its session pointer" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0068"></a>
## DUP-0068

Body token hash: `44a21abb134ba11a57eb457a161844db4764d5b321f150e7f426f959a5e66fe3`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-06620](inventory/rails-models-c.md#t-06620) | [test/models/client_token_test.rb:241](../../test/models/client_token_test.rb#L241) | `ClientTokenTest` | "assigns numeric id automatically" | contextual equivalence unverified; do not remove by hash |
| [T-08039](inventory/rails-models-o.md#t-08039) | [test/models/operator_token_test.rb:207](../../test/models/operator_token_test.rb#L207) | `OperatorTokenTest` | "assigns numeric id automatically" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0069"></a>
## DUP-0069

Body token hash: `89cabc5dc08d060b7293ef9a2942a9dbb54a54803f66331b0ce0ee0564a960d8`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-06621](inventory/rails-models-c.md#t-06621) | [test/models/client_token_test.rb:246](../../test/models/client_token_test.rb#L246) | `ClientTokenTest` | "has created_at timestamp" | contextual equivalence unverified; do not remove by hash |
| [T-08040](inventory/rails-models-o.md#t-08040) | [test/models/operator_token_test.rb:212](../../test/models/operator_token_test.rb#L212) | `OperatorTokenTest` | "has created_at timestamp" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0070"></a>
## DUP-0070

Body token hash: `3cb52c18fdbcccd326f137292bc86db1d0aa25fc3b0e18bcd689ddad803d6b1e`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-06622](inventory/rails-models-c.md#t-06622) | [test/models/client_token_test.rb:251](../../test/models/client_token_test.rb#L251) | `ClientTokenTest` | "has updated_at timestamp" | contextual equivalence unverified; do not remove by hash |
| [T-08041](inventory/rails-models-o.md#t-08041) | [test/models/operator_token_test.rb:217](../../test/models/operator_token_test.rb#L217) | `OperatorTokenTest` | "has updated_at timestamp" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0071"></a>
## DUP-0071

Body token hash: `ee684499aec7645f96cbf68c1b3026b49fa831a2716169dd253cf50101a54f91`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-06627](inventory/rails-models-c.md#t-06627) | [test/models/client_token_test.rb:284](../../test/models/client_token_test.rb#L284) | `ClientTokenTest` | "timestamp updates on save" | contextual equivalence unverified; do not remove by hash |
| [T-08046](inventory/rails-models-o.md#t-08046) | [test/models/operator_token_test.rb:247](../../test/models/operator_token_test.rb#L247) | `OperatorTokenTest` | "timestamp updates on save" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0072"></a>
## DUP-0072

Body token hash: `f025bccf61462a7fc9e2afcd1104db5c815288905c70478a7cf3242f57bd2c47`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-06656](inventory/rails-models-c.md#t-06656) | [test/models/client_token_test.rb:709](../../test/models/client_token_test.rb#L709) | `ClientTokenTest` | "find_from_signed_ref returns nil for invalid signature" | contextual equivalence unverified; do not remove by hash |
| [T-07130](inventory/rails-models-concerns.md#t-07130) | [test/models/concerns/signed_session_reference_test.rb:28](../../test/models/concerns/signed_session_reference_test.rb#L28) | `SignedSessionReferenceTest` | "find_from_signed_ref returns nil for invalid signature" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0073"></a>
## DUP-0073

Body token hash: `89659c637fe06ad9e4828ec23021310845c1951d6e83375461250a761c242253`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-07111](inventory/rails-models-concerns.md#t-07111) | [test/models/concerns/retainable_test.rb:142](../../test/models/concerns/retainable_test.rb#L142) | `RetainableTest` | "validates discard_at &lt;= purge_eligible_at" | contextual equivalence unverified; do not remove by hash |
| [T-07116](inventory/rails-models-concerns.md#t-07116) | [test/models/concerns/retainable_test.rb:199](../../test/models/concerns/retainable_test.rb#L199) | `RetainableTest` | "a discard_at later than purge_eligible_at is invalid" | LV-034 |

<a id="dup-0074"></a>
## DUP-0074

Body token hash: `d329fc16b974554931c6398c2d973de8b6affe52a36aac353db49e6fe393d764`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-07518](inventory/rails-models-j.md#t-07518) | [test/models/jump_link_retirement_test.rb:7](../../test/models/jump_link_retirement_test.rb#L7) | `JumpLinkRetirementTest` | "legacy DB-backed jump link models are not available" | contextual equivalence unverified; do not remove by hash |
| [T-10898](inventory/rails-security.md#t-10898) | [test/security/invariants/jump_gateway_boundary_invariant_test.rb:14](../../test/security/invariants/jump_gateway_boundary_invariant_test.rb#L14) | `JumpGatewayBoundaryInvariantTest` | "legacy DB backed jump links are not part of the app boundary" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0075"></a>
## DUP-0075

Body token hash: `e59a4dad156b310d589a02f958a4cdb7ba5a36a500f8a85d4e7c3cfa320fb167`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-07835](inventory/rails-models-o.md#t-07835) | [test/models/operator_preference_language_option_test.rb:77](../../test/models/operator_preference_language_option_test.rb#L77) | `OperatorPreferenceLanguageOptionTest` | "ensure_defaults! skips existing records" | contextual equivalence unverified; do not remove by hash |
| [T-07836](inventory/rails-models-o.md#t-07836) | [test/models/operator_preference_language_option_test.rb:83](../../test/models/operator_preference_language_option_test.rb#L83) | `OperatorPreferenceLanguageOptionTest` | "ensure_defaults! does nothing when all exist" | LV-035 |

<a id="dup-0076"></a>
## DUP-0076

Body token hash: `3acc2190168fc5daf9aedb2e8bdc3f2b6f7b3730495ad91f3e049017f81a386f`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-07977](inventory/rails-models-o.md#t-07977) | [test/models/operator_test.rb:241](../../test/models/operator_test.rb#L241) | `OperatorTest` | "boundary: length 16 is valid" | contextual equivalence unverified; do not remove by hash |
| [T-07979](inventory/rails-models-o.md#t-07979) | [test/models/operator_test.rb:258](../../test/models/operator_test.rb#L258) | `OperatorTest` | "equivalence: valid set - allowed base32 characters only (16 chars) is valid" | LV-036 |

<a id="dup-0077"></a>
## DUP-0077

Body token hash: `0e06df0dd89c0b80ffc9199db7ef4322f41506e0905e5bcbc5e60640ac9f37e8`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-08875](inventory/rails-models-s.md#t-08875) | [test/models/sign_flow_test.rb:476](../../test/models/sign_flow_test.rb#L476) | `SignFlowTest` | "sign-in cycle methods reject expired cycles" | contextual equivalence unverified; do not remove by hash |
| [T-08876](inventory/rails-models-s.md#t-08876) | [test/models/sign_flow_test.rb:489](../../test/models/sign_flow_test.rb#L489) | `SignFlowTest` | "named sign-in transitions reject expired cycles after terminalizing them" | LV-037 |

<a id="dup-0078"></a>
## DUP-0078

Body token hash: `f0aacfbe411cf62877ddbe69eacbace82df8bef545b49aa7752cb61eba8d4b2a`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-09617](inventory/rails-operations.md#t-09617) | [test/operations/identity_email_ceremony_result_issuer_test.rb:58](../../test/operations/identity_email_ceremony_result_issuer_test.rb#L58) | `IdentityEmailCeremonyResultIssuerTest` | "uses the supplied challenge id when present" | contextual equivalence unverified; do not remove by hash |
| [T-09643](inventory/rails-operations.md#t-09643) | [test/operations/identity_passkey_ceremony_result_issuer_test.rb:44](../../test/operations/identity_passkey_ceremony_result_issuer_test.rb#L44) | `IdentityPasskeyCeremonyResultIssuerTest` | "uses the supplied challenge id when present" | contextual equivalence unverified; do not remove by hash |
| [T-09673](inventory/rails-operations.md#t-09673) | [test/operations/identity_secret_credential_ceremony_result_issuer_test.rb:42](../../test/operations/identity_secret_credential_ceremony_result_issuer_test.rb#L42) | `IdentitySecretCredentialCeremonyResultIssuerTest` | "uses the supplied challenge id when present" | contextual equivalence unverified; do not remove by hash |
| [T-09762](inventory/rails-operations.md#t-09762) | [test/operations/identity_telephone_ceremony_result_issuer_test.rb:58](../../test/operations/identity_telephone_ceremony_result_issuer_test.rb#L58) | `IdentityTelephoneCeremonyResultIssuerTest` | "uses the supplied challenge id when present" | contextual equivalence unverified; do not remove by hash |
| [T-09788](inventory/rails-operations.md#t-09788) | [test/operations/identity_totp_ceremony_result_issuer_test.rb:42](../../test/operations/identity_totp_ceremony_result_issuer_test.rb#L42) | `IdentityTotpCeremonyResultIssuerTest` | "uses the supplied challenge id when present" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0079"></a>
## DUP-0079

Body token hash: `42a091f5bc31b1d555d03d8545b4a521896fee814b1f8548b15b738dbb47cfc0`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-10015](inventory/rails-policies.md#t-10015) | [test/policies/account_policy_test.rb:16](../../test/policies/account_policy_test.rb#L16) | `AccountPolicyTest` | test_index | contextual equivalence unverified; do not remove by hash |
| [T-10126](inventory/rails-policies.md#t-10126) | [test/policies/client_email_policy_test.rb:14](../../test/policies/client_email_policy_test.rb#L14) | `ClientEmailPolicyTest` | test_index | contextual equivalence unverified; do not remove by hash |
| [T-10185](inventory/rails-policies.md#t-10185) | [test/policies/client_telephone_policy_test.rb:14](../../test/policies/client_telephone_policy_test.rb#L14) | `ClientTelephonePolicyTest` | test_index | contextual equivalence unverified; do not remove by hash |
| [T-10198](inventory/rails-policies.md#t-10198) | [test/policies/client_time_based_totp_credential_policy_test.rb:14](../../test/policies/client_time_based_totp_credential_policy_test.rb#L14) | `ClientTimeBasedTotpCredentialPolicyTest` | test_index | contextual equivalence unverified; do not remove by hash |
| [T-10205](inventory/rails-policies.md#t-10205) | [test/policies/client_token_policy_test.rb:16](../../test/policies/client_token_policy_test.rb#L16) | `ClientTokenPolicyTest` | test_index | contextual equivalence unverified; do not remove by hash |
| [T-10219](inventory/rails-policies.md#t-10219) | [test/policies/client_totp_credential_policy_test.rb:14](../../test/policies/client_totp_credential_policy_test.rb#L14) | `ClientTotpCredentialPolicyTest` | test_index | contextual equivalence unverified; do not remove by hash |
| [T-10230](inventory/rails-policies.md#t-10230) | [test/policies/client_webauthn_credential_policy_test.rb:14](../../test/policies/client_webauthn_credential_policy_test.rb#L14) | `ClientWebauthnCredentialPolicyTest` | test_index | contextual equivalence unverified; do not remove by hash |
| [T-10325](inventory/rails-policies.md#t-10325) | [test/policies/organization_policy_test.rb:15](../../test/policies/organization_policy_test.rb#L15) | `OrganizationPolicyTest` | "index is denied by default" | contextual equivalence unverified; do not remove by hash |
| [T-10334](inventory/rails-policies.md#t-10334) | [test/policies/preference_policies_test.rb:17](../../test/policies/preference_policies_test.rb#L17) | `AppPreferenceCurrencyPolicyTest` | "index? is false by default" | contextual equivalence unverified; do not remove by hash |
| [T-10339](inventory/rails-policies.md#t-10339) | [test/policies/preference_policies_test.rb:45](../../test/policies/preference_policies_test.rb#L45) | `AppPreferenceLanguagePolicyTest` | "index? is false by default" | contextual equivalence unverified; do not remove by hash |
| [T-10344](inventory/rails-policies.md#t-10344) | [test/policies/preference_policies_test.rb:73](../../test/policies/preference_policies_test.rb#L73) | `AppPreferenceThemePolicyTest` | "index? is false by default" | contextual equivalence unverified; do not remove by hash |
| [T-10349](inventory/rails-policies.md#t-10349) | [test/policies/preference_policies_test.rb:101](../../test/policies/preference_policies_test.rb#L101) | `AppPreferenceTimezonePolicyTest` | "index? is false by default" | contextual equivalence unverified; do not remove by hash |
| [T-10354](inventory/rails-policies.md#t-10354) | [test/policies/preference_policies_test.rb:129](../../test/policies/preference_policies_test.rb#L129) | `AppPreferenceRegionPolicyTest` | "index? is false by default" | contextual equivalence unverified; do not remove by hash |
| [T-10449](inventory/rails-policies.md#t-10449) | [test/policies/staff_email_policy_test.rb:14](../../test/policies/staff_email_policy_test.rb#L14) | `OperatorEmailPolicyTest` | test_index | contextual equivalence unverified; do not remove by hash |
| [T-10462](inventory/rails-policies.md#t-10462) | [test/policies/staff_passkey_policy_test.rb:14](../../test/policies/staff_passkey_policy_test.rb#L14) | `OperatorPasskeyPolicyTest` | test_index | contextual equivalence unverified; do not remove by hash |
| [T-10469](inventory/rails-policies.md#t-10469) | [test/policies/staff_secret_credential_policy_test.rb:14](../../test/policies/staff_secret_credential_policy_test.rb#L14) | `OperatorSecretCredentialPolicyTest` | test_index | contextual equivalence unverified; do not remove by hash |
| [T-10482](inventory/rails-policies.md#t-10482) | [test/policies/staff_telephone_policy_test.rb:14](../../test/policies/staff_telephone_policy_test.rb#L14) | `OperatorTelephonePolicyTest` | test_index | contextual equivalence unverified; do not remove by hash |
| [T-10495](inventory/rails-policies.md#t-10495) | [test/policies/staff_time_based_totp_credential_policy_test.rb:16](../../test/policies/staff_time_based_totp_credential_policy_test.rb#L16) | `OperatorTimeBasedTotpCredentialPolicyTest` | test_index | contextual equivalence unverified; do not remove by hash |
| [T-10502](inventory/rails-policies.md#t-10502) | [test/policies/staff_token_policy_test.rb:14](../../test/policies/staff_token_policy_test.rb#L14) | `OperatorTokenPolicyTest` | test_index | contextual equivalence unverified; do not remove by hash |
| [T-10516](inventory/rails-policies.md#t-10516) | [test/policies/staff_webauthn_credential_policy_test.rb:14](../../test/policies/staff_webauthn_credential_policy_test.rb#L14) | `OperatorWebauthnCredentialPolicyTest` | test_index | contextual equivalence unverified; do not remove by hash |
| [T-10535](inventory/rails-policies.md#t-10535) | [test/policies/visitor_email_policy_test.rb:16](../../test/policies/visitor_email_policy_test.rb#L16) | `VisitorEmailPolicyTest` | test_index | contextual equivalence unverified; do not remove by hash |
| [T-10562](inventory/rails-policies.md#t-10562) | [test/policies/visitor_secret_credential_policy_test.rb:18](../../test/policies/visitor_secret_credential_policy_test.rb#L18) | `VisitorSecretCredentialPolicyTest` | test_index | contextual equivalence unverified; do not remove by hash |
| [T-10570](inventory/rails-policies.md#t-10570) | [test/policies/visitor_telephone_policy_test.rb:16](../../test/policies/visitor_telephone_policy_test.rb#L16) | `VisitorTelephonePolicyTest` | test_index | contextual equivalence unverified; do not remove by hash |
| [T-10581](inventory/rails-policies.md#t-10581) | [test/policies/visitor_token_policy_test.rb:16](../../test/policies/visitor_token_policy_test.rb#L16) | `VisitorTokenPolicyTest` | test_index | contextual equivalence unverified; do not remove by hash |

<a id="dup-0080"></a>
## DUP-0080

Body token hash: `7224c0a4354d6f47373b139972e04801693e90f7e4585a88f2b08ae7628dfca9`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-10016](inventory/rails-policies.md#t-10016) | [test/policies/account_policy_test.rb:20](../../test/policies/account_policy_test.rb#L20) | `AccountPolicyTest` | test_show | contextual equivalence unverified; do not remove by hash |
| [T-10326](inventory/rails-policies.md#t-10326) | [test/policies/organization_policy_test.rb:19](../../test/policies/organization_policy_test.rb#L19) | `OrganizationPolicyTest` | "show allows an organization with an active membership for the principal" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0081"></a>
## DUP-0081

Body token hash: `2ab92700f69ddc6019d625c4b0e2ba41e9342634243ead4b565f4ab4b75c094a`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-10020](inventory/rails-policies.md#t-10020) | [test/policies/account_policy_test.rb:44](../../test/policies/account_policy_test.rb#L44) | `AccountPolicyTest` | test_create | contextual equivalence unverified; do not remove by hash |
| [T-10130](inventory/rails-policies.md#t-10130) | [test/policies/client_email_policy_test.rb:32](../../test/policies/client_email_policy_test.rb#L32) | `ClientEmailPolicyTest` | test_create | contextual equivalence unverified; do not remove by hash |
| [T-10189](inventory/rails-policies.md#t-10189) | [test/policies/client_telephone_policy_test.rb:32](../../test/policies/client_telephone_policy_test.rb#L32) | `ClientTelephonePolicyTest` | test_create | contextual equivalence unverified; do not remove by hash |
| [T-10200](inventory/rails-policies.md#t-10200) | [test/policies/client_time_based_totp_credential_policy_test.rb:22](../../test/policies/client_time_based_totp_credential_policy_test.rb#L22) | `ClientTimeBasedTotpCredentialPolicyTest` | test_create | contextual equivalence unverified; do not remove by hash |
| [T-10214](inventory/rails-policies.md#t-10214) | [test/policies/client_token_policy_test.rb:65](../../test/policies/client_token_policy_test.rb#L65) | `ClientTokenPolicyTest` | test_create | contextual equivalence unverified; do not remove by hash |
| [T-10221](inventory/rails-policies.md#t-10221) | [test/policies/client_totp_credential_policy_test.rb:22](../../test/policies/client_totp_credential_policy_test.rb#L22) | `ClientTotpCredentialPolicyTest` | test_create | contextual equivalence unverified; do not remove by hash |
| [T-10232](inventory/rails-policies.md#t-10232) | [test/policies/client_webauthn_credential_policy_test.rb:22](../../test/policies/client_webauthn_credential_policy_test.rb#L22) | `ClientWebauthnCredentialPolicyTest` | test_create | contextual equivalence unverified; do not remove by hash |
| [T-10336](inventory/rails-policies.md#t-10336) | [test/policies/preference_policies_test.rb:25](../../test/policies/preference_policies_test.rb#L25) | `AppPreferenceCurrencyPolicyTest` | "create? is false by default" | contextual equivalence unverified; do not remove by hash |
| [T-10341](inventory/rails-policies.md#t-10341) | [test/policies/preference_policies_test.rb:53](../../test/policies/preference_policies_test.rb#L53) | `AppPreferenceLanguagePolicyTest` | "create? is false by default" | contextual equivalence unverified; do not remove by hash |
| [T-10346](inventory/rails-policies.md#t-10346) | [test/policies/preference_policies_test.rb:81](../../test/policies/preference_policies_test.rb#L81) | `AppPreferenceThemePolicyTest` | "create? is false by default" | contextual equivalence unverified; do not remove by hash |
| [T-10351](inventory/rails-policies.md#t-10351) | [test/policies/preference_policies_test.rb:109](../../test/policies/preference_policies_test.rb#L109) | `AppPreferenceTimezonePolicyTest` | "create? is false by default" | contextual equivalence unverified; do not remove by hash |
| [T-10356](inventory/rails-policies.md#t-10356) | [test/policies/preference_policies_test.rb:137](../../test/policies/preference_policies_test.rb#L137) | `AppPreferenceRegionPolicyTest` | "create? is false by default" | contextual equivalence unverified; do not remove by hash |
| [T-10453](inventory/rails-policies.md#t-10453) | [test/policies/staff_email_policy_test.rb:32](../../test/policies/staff_email_policy_test.rb#L32) | `OperatorEmailPolicyTest` | test_create | contextual equivalence unverified; do not remove by hash |
| [T-10464](inventory/rails-policies.md#t-10464) | [test/policies/staff_passkey_policy_test.rb:22](../../test/policies/staff_passkey_policy_test.rb#L22) | `OperatorPasskeyPolicyTest` | test_create | contextual equivalence unverified; do not remove by hash |
| [T-10471](inventory/rails-policies.md#t-10471) | [test/policies/staff_secret_credential_policy_test.rb:22](../../test/policies/staff_secret_credential_policy_test.rb#L22) | `OperatorSecretCredentialPolicyTest` | test_create | contextual equivalence unverified; do not remove by hash |
| [T-10486](inventory/rails-policies.md#t-10486) | [test/policies/staff_telephone_policy_test.rb:32](../../test/policies/staff_telephone_policy_test.rb#L32) | `OperatorTelephonePolicyTest` | test_create | contextual equivalence unverified; do not remove by hash |
| [T-10497](inventory/rails-policies.md#t-10497) | [test/policies/staff_time_based_totp_credential_policy_test.rb:24](../../test/policies/staff_time_based_totp_credential_policy_test.rb#L24) | `OperatorTimeBasedTotpCredentialPolicyTest` | test_create | contextual equivalence unverified; do not remove by hash |
| [T-10511](inventory/rails-policies.md#t-10511) | [test/policies/staff_token_policy_test.rb:63](../../test/policies/staff_token_policy_test.rb#L63) | `OperatorTokenPolicyTest` | test_create | contextual equivalence unverified; do not remove by hash |
| [T-10518](inventory/rails-policies.md#t-10518) | [test/policies/staff_webauthn_credential_policy_test.rb:22](../../test/policies/staff_webauthn_credential_policy_test.rb#L22) | `OperatorWebauthnCredentialPolicyTest` | test_create | contextual equivalence unverified; do not remove by hash |
| [T-10539](inventory/rails-policies.md#t-10539) | [test/policies/visitor_email_policy_test.rb:33](../../test/policies/visitor_email_policy_test.rb#L33) | `VisitorEmailPolicyTest` | test_create | contextual equivalence unverified; do not remove by hash |
| [T-10564](inventory/rails-policies.md#t-10564) | [test/policies/visitor_secret_credential_policy_test.rb:26](../../test/policies/visitor_secret_credential_policy_test.rb#L26) | `VisitorSecretCredentialPolicyTest` | test_create | contextual equivalence unverified; do not remove by hash |
| [T-10574](inventory/rails-policies.md#t-10574) | [test/policies/visitor_telephone_policy_test.rb:33](../../test/policies/visitor_telephone_policy_test.rb#L33) | `VisitorTelephonePolicyTest` | test_create | contextual equivalence unverified; do not remove by hash |
| [T-10590](inventory/rails-policies.md#t-10590) | [test/policies/visitor_token_policy_test.rb:64](../../test/policies/visitor_token_policy_test.rb#L64) | `VisitorTokenPolicyTest` | test_create | contextual equivalence unverified; do not remove by hash |

<a id="dup-0082"></a>
## DUP-0082

Body token hash: `5ebecf5e38959930c0f7bf6492a58707d9c418946fb5d5603999cad471e39f8e`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-10021](inventory/rails-policies.md#t-10021) | [test/policies/account_policy_test.rb:48](../../test/policies/account_policy_test.rb#L48) | `AccountPolicyTest` | test_new | contextual equivalence unverified; do not remove by hash |
| [T-10131](inventory/rails-policies.md#t-10131) | [test/policies/client_email_policy_test.rb:36](../../test/policies/client_email_policy_test.rb#L36) | `ClientEmailPolicyTest` | test_new | contextual equivalence unverified; do not remove by hash |
| [T-10190](inventory/rails-policies.md#t-10190) | [test/policies/client_telephone_policy_test.rb:36](../../test/policies/client_telephone_policy_test.rb#L36) | `ClientTelephonePolicyTest` | test_new | contextual equivalence unverified; do not remove by hash |
| [T-10201](inventory/rails-policies.md#t-10201) | [test/policies/client_time_based_totp_credential_policy_test.rb:26](../../test/policies/client_time_based_totp_credential_policy_test.rb#L26) | `ClientTimeBasedTotpCredentialPolicyTest` | test_new | contextual equivalence unverified; do not remove by hash |
| [T-10215](inventory/rails-policies.md#t-10215) | [test/policies/client_token_policy_test.rb:69](../../test/policies/client_token_policy_test.rb#L69) | `ClientTokenPolicyTest` | test_new | contextual equivalence unverified; do not remove by hash |
| [T-10222](inventory/rails-policies.md#t-10222) | [test/policies/client_totp_credential_policy_test.rb:26](../../test/policies/client_totp_credential_policy_test.rb#L26) | `ClientTotpCredentialPolicyTest` | test_new | contextual equivalence unverified; do not remove by hash |
| [T-10233](inventory/rails-policies.md#t-10233) | [test/policies/client_webauthn_credential_policy_test.rb:26](../../test/policies/client_webauthn_credential_policy_test.rb#L26) | `ClientWebauthnCredentialPolicyTest` | test_new | contextual equivalence unverified; do not remove by hash |
| [T-10454](inventory/rails-policies.md#t-10454) | [test/policies/staff_email_policy_test.rb:36](../../test/policies/staff_email_policy_test.rb#L36) | `OperatorEmailPolicyTest` | test_new | contextual equivalence unverified; do not remove by hash |
| [T-10465](inventory/rails-policies.md#t-10465) | [test/policies/staff_passkey_policy_test.rb:26](../../test/policies/staff_passkey_policy_test.rb#L26) | `OperatorPasskeyPolicyTest` | test_new | contextual equivalence unverified; do not remove by hash |
| [T-10472](inventory/rails-policies.md#t-10472) | [test/policies/staff_secret_credential_policy_test.rb:26](../../test/policies/staff_secret_credential_policy_test.rb#L26) | `OperatorSecretCredentialPolicyTest` | test_new | contextual equivalence unverified; do not remove by hash |
| [T-10487](inventory/rails-policies.md#t-10487) | [test/policies/staff_telephone_policy_test.rb:36](../../test/policies/staff_telephone_policy_test.rb#L36) | `OperatorTelephonePolicyTest` | test_new | contextual equivalence unverified; do not remove by hash |
| [T-10498](inventory/rails-policies.md#t-10498) | [test/policies/staff_time_based_totp_credential_policy_test.rb:28](../../test/policies/staff_time_based_totp_credential_policy_test.rb#L28) | `OperatorTimeBasedTotpCredentialPolicyTest` | test_new | contextual equivalence unverified; do not remove by hash |
| [T-10512](inventory/rails-policies.md#t-10512) | [test/policies/staff_token_policy_test.rb:67](../../test/policies/staff_token_policy_test.rb#L67) | `OperatorTokenPolicyTest` | test_new | contextual equivalence unverified; do not remove by hash |
| [T-10519](inventory/rails-policies.md#t-10519) | [test/policies/staff_webauthn_credential_policy_test.rb:26](../../test/policies/staff_webauthn_credential_policy_test.rb#L26) | `OperatorWebauthnCredentialPolicyTest` | test_new | contextual equivalence unverified; do not remove by hash |

<a id="dup-0083"></a>
## DUP-0083

Body token hash: `fa01d346d3c03f8da8780a17f25cb3319b717b96cc68ddad4b651733a19cae48`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-10022](inventory/rails-policies.md#t-10022) | [test/policies/account_policy_test.rb:52](../../test/policies/account_policy_test.rb#L52) | `AccountPolicyTest` | test_update | contextual equivalence unverified; do not remove by hash |
| [T-10132](inventory/rails-policies.md#t-10132) | [test/policies/client_email_policy_test.rb:40](../../test/policies/client_email_policy_test.rb#L40) | `ClientEmailPolicyTest` | test_update | contextual equivalence unverified; do not remove by hash |
| [T-10191](inventory/rails-policies.md#t-10191) | [test/policies/client_telephone_policy_test.rb:40](../../test/policies/client_telephone_policy_test.rb#L40) | `ClientTelephonePolicyTest` | test_update | contextual equivalence unverified; do not remove by hash |
| [T-10202](inventory/rails-policies.md#t-10202) | [test/policies/client_time_based_totp_credential_policy_test.rb:30](../../test/policies/client_time_based_totp_credential_policy_test.rb#L30) | `ClientTimeBasedTotpCredentialPolicyTest` | test_update | contextual equivalence unverified; do not remove by hash |
| [T-10216](inventory/rails-policies.md#t-10216) | [test/policies/client_token_policy_test.rb:73](../../test/policies/client_token_policy_test.rb#L73) | `ClientTokenPolicyTest` | test_update | contextual equivalence unverified; do not remove by hash |
| [T-10223](inventory/rails-policies.md#t-10223) | [test/policies/client_totp_credential_policy_test.rb:30](../../test/policies/client_totp_credential_policy_test.rb#L30) | `ClientTotpCredentialPolicyTest` | test_update | contextual equivalence unverified; do not remove by hash |
| [T-10234](inventory/rails-policies.md#t-10234) | [test/policies/client_webauthn_credential_policy_test.rb:30](../../test/policies/client_webauthn_credential_policy_test.rb#L30) | `ClientWebauthnCredentialPolicyTest` | test_update | contextual equivalence unverified; do not remove by hash |
| [T-10337](inventory/rails-policies.md#t-10337) | [test/policies/preference_policies_test.rb:29](../../test/policies/preference_policies_test.rb#L29) | `AppPreferenceCurrencyPolicyTest` | "update? is false by default" | contextual equivalence unverified; do not remove by hash |
| [T-10342](inventory/rails-policies.md#t-10342) | [test/policies/preference_policies_test.rb:57](../../test/policies/preference_policies_test.rb#L57) | `AppPreferenceLanguagePolicyTest` | "update? is false by default" | contextual equivalence unverified; do not remove by hash |
| [T-10347](inventory/rails-policies.md#t-10347) | [test/policies/preference_policies_test.rb:85](../../test/policies/preference_policies_test.rb#L85) | `AppPreferenceThemePolicyTest` | "update? is false by default" | contextual equivalence unverified; do not remove by hash |
| [T-10352](inventory/rails-policies.md#t-10352) | [test/policies/preference_policies_test.rb:113](../../test/policies/preference_policies_test.rb#L113) | `AppPreferenceTimezonePolicyTest` | "update? is false by default" | contextual equivalence unverified; do not remove by hash |
| [T-10357](inventory/rails-policies.md#t-10357) | [test/policies/preference_policies_test.rb:141](../../test/policies/preference_policies_test.rb#L141) | `AppPreferenceRegionPolicyTest` | "update? is false by default" | contextual equivalence unverified; do not remove by hash |
| [T-10455](inventory/rails-policies.md#t-10455) | [test/policies/staff_email_policy_test.rb:40](../../test/policies/staff_email_policy_test.rb#L40) | `OperatorEmailPolicyTest` | test_update | contextual equivalence unverified; do not remove by hash |
| [T-10466](inventory/rails-policies.md#t-10466) | [test/policies/staff_passkey_policy_test.rb:30](../../test/policies/staff_passkey_policy_test.rb#L30) | `OperatorPasskeyPolicyTest` | test_update | contextual equivalence unverified; do not remove by hash |
| [T-10473](inventory/rails-policies.md#t-10473) | [test/policies/staff_secret_credential_policy_test.rb:30](../../test/policies/staff_secret_credential_policy_test.rb#L30) | `OperatorSecretCredentialPolicyTest` | test_update | contextual equivalence unverified; do not remove by hash |
| [T-10488](inventory/rails-policies.md#t-10488) | [test/policies/staff_telephone_policy_test.rb:40](../../test/policies/staff_telephone_policy_test.rb#L40) | `OperatorTelephonePolicyTest` | test_update | contextual equivalence unverified; do not remove by hash |
| [T-10499](inventory/rails-policies.md#t-10499) | [test/policies/staff_time_based_totp_credential_policy_test.rb:32](../../test/policies/staff_time_based_totp_credential_policy_test.rb#L32) | `OperatorTimeBasedTotpCredentialPolicyTest` | test_update | contextual equivalence unverified; do not remove by hash |
| [T-10513](inventory/rails-policies.md#t-10513) | [test/policies/staff_token_policy_test.rb:71](../../test/policies/staff_token_policy_test.rb#L71) | `OperatorTokenPolicyTest` | test_update | contextual equivalence unverified; do not remove by hash |
| [T-10520](inventory/rails-policies.md#t-10520) | [test/policies/staff_webauthn_credential_policy_test.rb:30](../../test/policies/staff_webauthn_credential_policy_test.rb#L30) | `OperatorWebauthnCredentialPolicyTest` | test_update | contextual equivalence unverified; do not remove by hash |
| [T-10540](inventory/rails-policies.md#t-10540) | [test/policies/visitor_email_policy_test.rb:37](../../test/policies/visitor_email_policy_test.rb#L37) | `VisitorEmailPolicyTest` | test_update | contextual equivalence unverified; do not remove by hash |
| [T-10575](inventory/rails-policies.md#t-10575) | [test/policies/visitor_telephone_policy_test.rb:37](../../test/policies/visitor_telephone_policy_test.rb#L37) | `VisitorTelephonePolicyTest` | test_update | contextual equivalence unverified; do not remove by hash |
| [T-10591](inventory/rails-policies.md#t-10591) | [test/policies/visitor_token_policy_test.rb:68](../../test/policies/visitor_token_policy_test.rb#L68) | `VisitorTokenPolicyTest` | test_update | contextual equivalence unverified; do not remove by hash |

<a id="dup-0084"></a>
## DUP-0084

Body token hash: `84f6ee072bfb5b6dfd824f5719064ab7e4bc417e656a8952599e59686d8e4b18`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-10023](inventory/rails-policies.md#t-10023) | [test/policies/account_policy_test.rb:56](../../test/policies/account_policy_test.rb#L56) | `AccountPolicyTest` | test_edit | contextual equivalence unverified; do not remove by hash |
| [T-10133](inventory/rails-policies.md#t-10133) | [test/policies/client_email_policy_test.rb:44](../../test/policies/client_email_policy_test.rb#L44) | `ClientEmailPolicyTest` | test_edit | contextual equivalence unverified; do not remove by hash |
| [T-10192](inventory/rails-policies.md#t-10192) | [test/policies/client_telephone_policy_test.rb:44](../../test/policies/client_telephone_policy_test.rb#L44) | `ClientTelephonePolicyTest` | test_edit | contextual equivalence unverified; do not remove by hash |
| [T-10203](inventory/rails-policies.md#t-10203) | [test/policies/client_time_based_totp_credential_policy_test.rb:34](../../test/policies/client_time_based_totp_credential_policy_test.rb#L34) | `ClientTimeBasedTotpCredentialPolicyTest` | test_edit | contextual equivalence unverified; do not remove by hash |
| [T-10217](inventory/rails-policies.md#t-10217) | [test/policies/client_token_policy_test.rb:77](../../test/policies/client_token_policy_test.rb#L77) | `ClientTokenPolicyTest` | test_edit | contextual equivalence unverified; do not remove by hash |
| [T-10224](inventory/rails-policies.md#t-10224) | [test/policies/client_totp_credential_policy_test.rb:34](../../test/policies/client_totp_credential_policy_test.rb#L34) | `ClientTotpCredentialPolicyTest` | test_edit | contextual equivalence unverified; do not remove by hash |
| [T-10235](inventory/rails-policies.md#t-10235) | [test/policies/client_webauthn_credential_policy_test.rb:34](../../test/policies/client_webauthn_credential_policy_test.rb#L34) | `ClientWebauthnCredentialPolicyTest` | test_edit | contextual equivalence unverified; do not remove by hash |
| [T-10456](inventory/rails-policies.md#t-10456) | [test/policies/staff_email_policy_test.rb:44](../../test/policies/staff_email_policy_test.rb#L44) | `OperatorEmailPolicyTest` | test_edit | contextual equivalence unverified; do not remove by hash |
| [T-10467](inventory/rails-policies.md#t-10467) | [test/policies/staff_passkey_policy_test.rb:34](../../test/policies/staff_passkey_policy_test.rb#L34) | `OperatorPasskeyPolicyTest` | test_edit | contextual equivalence unverified; do not remove by hash |
| [T-10474](inventory/rails-policies.md#t-10474) | [test/policies/staff_secret_credential_policy_test.rb:34](../../test/policies/staff_secret_credential_policy_test.rb#L34) | `OperatorSecretCredentialPolicyTest` | test_edit | contextual equivalence unverified; do not remove by hash |
| [T-10489](inventory/rails-policies.md#t-10489) | [test/policies/staff_telephone_policy_test.rb:44](../../test/policies/staff_telephone_policy_test.rb#L44) | `OperatorTelephonePolicyTest` | test_edit | contextual equivalence unverified; do not remove by hash |
| [T-10500](inventory/rails-policies.md#t-10500) | [test/policies/staff_time_based_totp_credential_policy_test.rb:36](../../test/policies/staff_time_based_totp_credential_policy_test.rb#L36) | `OperatorTimeBasedTotpCredentialPolicyTest` | test_edit | contextual equivalence unverified; do not remove by hash |
| [T-10514](inventory/rails-policies.md#t-10514) | [test/policies/staff_token_policy_test.rb:75](../../test/policies/staff_token_policy_test.rb#L75) | `OperatorTokenPolicyTest` | test_edit | contextual equivalence unverified; do not remove by hash |
| [T-10521](inventory/rails-policies.md#t-10521) | [test/policies/staff_webauthn_credential_policy_test.rb:34](../../test/policies/staff_webauthn_credential_policy_test.rb#L34) | `OperatorWebauthnCredentialPolicyTest` | test_edit | contextual equivalence unverified; do not remove by hash |

<a id="dup-0085"></a>
## DUP-0085

Body token hash: `5fb8a70baed9866537a165b8c0d856b84e55f12ef5417b69a9fad59a6c5ef3de`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-10024](inventory/rails-policies.md#t-10024) | [test/policies/account_policy_test.rb:60](../../test/policies/account_policy_test.rb#L60) | `AccountPolicyTest` | test_destroy | contextual equivalence unverified; do not remove by hash |
| [T-10134](inventory/rails-policies.md#t-10134) | [test/policies/client_email_policy_test.rb:48](../../test/policies/client_email_policy_test.rb#L48) | `ClientEmailPolicyTest` | test_destroy | contextual equivalence unverified; do not remove by hash |
| [T-10193](inventory/rails-policies.md#t-10193) | [test/policies/client_telephone_policy_test.rb:48](../../test/policies/client_telephone_policy_test.rb#L48) | `ClientTelephonePolicyTest` | test_destroy | contextual equivalence unverified; do not remove by hash |
| [T-10204](inventory/rails-policies.md#t-10204) | [test/policies/client_time_based_totp_credential_policy_test.rb:38](../../test/policies/client_time_based_totp_credential_policy_test.rb#L38) | `ClientTimeBasedTotpCredentialPolicyTest` | test_destroy | contextual equivalence unverified; do not remove by hash |
| [T-10218](inventory/rails-policies.md#t-10218) | [test/policies/client_token_policy_test.rb:81](../../test/policies/client_token_policy_test.rb#L81) | `ClientTokenPolicyTest` | test_destroy | contextual equivalence unverified; do not remove by hash |
| [T-10225](inventory/rails-policies.md#t-10225) | [test/policies/client_totp_credential_policy_test.rb:38](../../test/policies/client_totp_credential_policy_test.rb#L38) | `ClientTotpCredentialPolicyTest` | test_destroy | contextual equivalence unverified; do not remove by hash |
| [T-10236](inventory/rails-policies.md#t-10236) | [test/policies/client_webauthn_credential_policy_test.rb:38](../../test/policies/client_webauthn_credential_policy_test.rb#L38) | `ClientWebauthnCredentialPolicyTest` | test_destroy | contextual equivalence unverified; do not remove by hash |
| [T-10338](inventory/rails-policies.md#t-10338) | [test/policies/preference_policies_test.rb:33](../../test/policies/preference_policies_test.rb#L33) | `AppPreferenceCurrencyPolicyTest` | "destroy? is false by default" | contextual equivalence unverified; do not remove by hash |
| [T-10343](inventory/rails-policies.md#t-10343) | [test/policies/preference_policies_test.rb:61](../../test/policies/preference_policies_test.rb#L61) | `AppPreferenceLanguagePolicyTest` | "destroy? is false by default" | contextual equivalence unverified; do not remove by hash |
| [T-10348](inventory/rails-policies.md#t-10348) | [test/policies/preference_policies_test.rb:89](../../test/policies/preference_policies_test.rb#L89) | `AppPreferenceThemePolicyTest` | "destroy? is false by default" | contextual equivalence unverified; do not remove by hash |
| [T-10353](inventory/rails-policies.md#t-10353) | [test/policies/preference_policies_test.rb:117](../../test/policies/preference_policies_test.rb#L117) | `AppPreferenceTimezonePolicyTest` | "destroy? is false by default" | contextual equivalence unverified; do not remove by hash |
| [T-10358](inventory/rails-policies.md#t-10358) | [test/policies/preference_policies_test.rb:145](../../test/policies/preference_policies_test.rb#L145) | `AppPreferenceRegionPolicyTest` | "destroy? is false by default" | contextual equivalence unverified; do not remove by hash |
| [T-10457](inventory/rails-policies.md#t-10457) | [test/policies/staff_email_policy_test.rb:48](../../test/policies/staff_email_policy_test.rb#L48) | `OperatorEmailPolicyTest` | test_destroy | contextual equivalence unverified; do not remove by hash |
| [T-10468](inventory/rails-policies.md#t-10468) | [test/policies/staff_passkey_policy_test.rb:38](../../test/policies/staff_passkey_policy_test.rb#L38) | `OperatorPasskeyPolicyTest` | test_destroy | contextual equivalence unverified; do not remove by hash |
| [T-10475](inventory/rails-policies.md#t-10475) | [test/policies/staff_secret_credential_policy_test.rb:38](../../test/policies/staff_secret_credential_policy_test.rb#L38) | `OperatorSecretCredentialPolicyTest` | test_destroy | contextual equivalence unverified; do not remove by hash |
| [T-10490](inventory/rails-policies.md#t-10490) | [test/policies/staff_telephone_policy_test.rb:48](../../test/policies/staff_telephone_policy_test.rb#L48) | `OperatorTelephonePolicyTest` | test_destroy | contextual equivalence unverified; do not remove by hash |
| [T-10501](inventory/rails-policies.md#t-10501) | [test/policies/staff_time_based_totp_credential_policy_test.rb:40](../../test/policies/staff_time_based_totp_credential_policy_test.rb#L40) | `OperatorTimeBasedTotpCredentialPolicyTest` | test_destroy | contextual equivalence unverified; do not remove by hash |
| [T-10515](inventory/rails-policies.md#t-10515) | [test/policies/staff_token_policy_test.rb:79](../../test/policies/staff_token_policy_test.rb#L79) | `OperatorTokenPolicyTest` | test_destroy | contextual equivalence unverified; do not remove by hash |
| [T-10522](inventory/rails-policies.md#t-10522) | [test/policies/staff_webauthn_credential_policy_test.rb:38](../../test/policies/staff_webauthn_credential_policy_test.rb#L38) | `OperatorWebauthnCredentialPolicyTest` | test_destroy | contextual equivalence unverified; do not remove by hash |
| [T-10541](inventory/rails-policies.md#t-10541) | [test/policies/visitor_email_policy_test.rb:41](../../test/policies/visitor_email_policy_test.rb#L41) | `VisitorEmailPolicyTest` | test_destroy | contextual equivalence unverified; do not remove by hash |
| [T-10565](inventory/rails-policies.md#t-10565) | [test/policies/visitor_secret_credential_policy_test.rb:30](../../test/policies/visitor_secret_credential_policy_test.rb#L30) | `VisitorSecretCredentialPolicyTest` | test_destroy | contextual equivalence unverified; do not remove by hash |
| [T-10576](inventory/rails-policies.md#t-10576) | [test/policies/visitor_telephone_policy_test.rb:41](../../test/policies/visitor_telephone_policy_test.rb#L41) | `VisitorTelephonePolicyTest` | test_destroy | contextual equivalence unverified; do not remove by hash |
| [T-10592](inventory/rails-policies.md#t-10592) | [test/policies/visitor_token_policy_test.rb:72](../../test/policies/visitor_token_policy_test.rb#L72) | `VisitorTokenPolicyTest` | test_destroy | contextual equivalence unverified; do not remove by hash |

<a id="dup-0086"></a>
## DUP-0086

Body token hash: `8aa7f8c9864bf4821ef43369ed64cfdaf6f22a22edaddf2ada7ab07616123d95`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-10080](inventory/rails-policies.md#t-10080) | [test/policies/avatar_follow_policy_test.rb:29](../../test/policies/avatar_follow_policy_test.rb#L29) | `AvatarFollowPolicyTest` | "create denies follow when target blocked actor" | contextual equivalence unverified; do not remove by hash |
| [T-10082](inventory/rails-policies.md#t-10082) | [test/policies/avatar_follow_policy_test.rb:47](../../test/policies/avatar_follow_policy_test.rb#L47) | `AvatarFollowPolicyTest` | "block precedence wins over follow" | LV-038 |

<a id="dup-0087"></a>
## DUP-0087

Body token hash: `6acc3fce05ede687062f66e316c1a27ea33816f3c06299b14f280a58dadab616`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-10125](inventory/rails-policies.md#t-10125) | [test/policies/client_chronicle_policy_test.rb:39](../../test/policies/client_chronicle_policy_test.rb#L39) | `ClientChroniclePolicyTest` | "anonymous actor may not list activity logs" | contextual equivalence unverified; do not remove by hash |
| [T-10280](inventory/rails-policies.md#t-10280) | [test/policies/operator_chronicle_policy_test.rb:39](../../test/policies/operator_chronicle_policy_test.rb#L39) | `OperatorChroniclePolicyTest` | "anonymous actor may not list activity logs" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0088"></a>
## DUP-0088

Body token hash: `167e988cbb53876379e58ea649a0c22fe058c32c40d4bda4b53d299cc109afa5`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-10129](inventory/rails-policies.md#t-10129) | [test/policies/client_email_policy_test.rb:28](../../test/policies/client_email_policy_test.rb#L28) | `ClientEmailPolicyTest` | test_show | contextual equivalence unverified; do not remove by hash |
| [T-10188](inventory/rails-policies.md#t-10188) | [test/policies/client_telephone_policy_test.rb:28](../../test/policies/client_telephone_policy_test.rb#L28) | `ClientTelephonePolicyTest` | test_show | contextual equivalence unverified; do not remove by hash |
| [T-10199](inventory/rails-policies.md#t-10199) | [test/policies/client_time_based_totp_credential_policy_test.rb:18](../../test/policies/client_time_based_totp_credential_policy_test.rb#L18) | `ClientTimeBasedTotpCredentialPolicyTest` | test_show | contextual equivalence unverified; do not remove by hash |
| [T-10213](inventory/rails-policies.md#t-10213) | [test/policies/client_token_policy_test.rb:61](../../test/policies/client_token_policy_test.rb#L61) | `ClientTokenPolicyTest` | test_show | contextual equivalence unverified; do not remove by hash |
| [T-10220](inventory/rails-policies.md#t-10220) | [test/policies/client_totp_credential_policy_test.rb:18](../../test/policies/client_totp_credential_policy_test.rb#L18) | `ClientTotpCredentialPolicyTest` | test_show | contextual equivalence unverified; do not remove by hash |
| [T-10231](inventory/rails-policies.md#t-10231) | [test/policies/client_webauthn_credential_policy_test.rb:18](../../test/policies/client_webauthn_credential_policy_test.rb#L18) | `ClientWebauthnCredentialPolicyTest` | test_show | contextual equivalence unverified; do not remove by hash |
| [T-10335](inventory/rails-policies.md#t-10335) | [test/policies/preference_policies_test.rb:21](../../test/policies/preference_policies_test.rb#L21) | `AppPreferenceCurrencyPolicyTest` | "show? is false by default" | contextual equivalence unverified; do not remove by hash |
| [T-10340](inventory/rails-policies.md#t-10340) | [test/policies/preference_policies_test.rb:49](../../test/policies/preference_policies_test.rb#L49) | `AppPreferenceLanguagePolicyTest` | "show? is false by default" | contextual equivalence unverified; do not remove by hash |
| [T-10345](inventory/rails-policies.md#t-10345) | [test/policies/preference_policies_test.rb:77](../../test/policies/preference_policies_test.rb#L77) | `AppPreferenceThemePolicyTest` | "show? is false by default" | contextual equivalence unverified; do not remove by hash |
| [T-10350](inventory/rails-policies.md#t-10350) | [test/policies/preference_policies_test.rb:105](../../test/policies/preference_policies_test.rb#L105) | `AppPreferenceTimezonePolicyTest` | "show? is false by default" | contextual equivalence unverified; do not remove by hash |
| [T-10355](inventory/rails-policies.md#t-10355) | [test/policies/preference_policies_test.rb:133](../../test/policies/preference_policies_test.rb#L133) | `AppPreferenceRegionPolicyTest` | "show? is false by default" | contextual equivalence unverified; do not remove by hash |
| [T-10452](inventory/rails-policies.md#t-10452) | [test/policies/staff_email_policy_test.rb:28](../../test/policies/staff_email_policy_test.rb#L28) | `OperatorEmailPolicyTest` | test_show | contextual equivalence unverified; do not remove by hash |
| [T-10463](inventory/rails-policies.md#t-10463) | [test/policies/staff_passkey_policy_test.rb:18](../../test/policies/staff_passkey_policy_test.rb#L18) | `OperatorPasskeyPolicyTest` | test_show | contextual equivalence unverified; do not remove by hash |
| [T-10470](inventory/rails-policies.md#t-10470) | [test/policies/staff_secret_credential_policy_test.rb:18](../../test/policies/staff_secret_credential_policy_test.rb#L18) | `OperatorSecretCredentialPolicyTest` | test_show | contextual equivalence unverified; do not remove by hash |
| [T-10485](inventory/rails-policies.md#t-10485) | [test/policies/staff_telephone_policy_test.rb:28](../../test/policies/staff_telephone_policy_test.rb#L28) | `OperatorTelephonePolicyTest` | test_show | contextual equivalence unverified; do not remove by hash |
| [T-10496](inventory/rails-policies.md#t-10496) | [test/policies/staff_time_based_totp_credential_policy_test.rb:20](../../test/policies/staff_time_based_totp_credential_policy_test.rb#L20) | `OperatorTimeBasedTotpCredentialPolicyTest` | test_show | contextual equivalence unverified; do not remove by hash |
| [T-10510](inventory/rails-policies.md#t-10510) | [test/policies/staff_token_policy_test.rb:59](../../test/policies/staff_token_policy_test.rb#L59) | `OperatorTokenPolicyTest` | test_show | contextual equivalence unverified; do not remove by hash |
| [T-10517](inventory/rails-policies.md#t-10517) | [test/policies/staff_webauthn_credential_policy_test.rb:18](../../test/policies/staff_webauthn_credential_policy_test.rb#L18) | `OperatorWebauthnCredentialPolicyTest` | test_show | contextual equivalence unverified; do not remove by hash |
| [T-10538](inventory/rails-policies.md#t-10538) | [test/policies/visitor_email_policy_test.rb:29](../../test/policies/visitor_email_policy_test.rb#L29) | `VisitorEmailPolicyTest` | test_show | contextual equivalence unverified; do not remove by hash |
| [T-10563](inventory/rails-policies.md#t-10563) | [test/policies/visitor_secret_credential_policy_test.rb:22](../../test/policies/visitor_secret_credential_policy_test.rb#L22) | `VisitorSecretCredentialPolicyTest` | test_show | contextual equivalence unverified; do not remove by hash |
| [T-10573](inventory/rails-policies.md#t-10573) | [test/policies/visitor_telephone_policy_test.rb:29](../../test/policies/visitor_telephone_policy_test.rb#L29) | `VisitorTelephonePolicyTest` | test_show | contextual equivalence unverified; do not remove by hash |
| [T-10589](inventory/rails-policies.md#t-10589) | [test/policies/visitor_token_policy_test.rb:60](../../test/policies/visitor_token_policy_test.rb#L60) | `VisitorTokenPolicyTest` | test_show | contextual equivalence unverified; do not remove by hash |

<a id="dup-0089"></a>
## DUP-0089

Body token hash: `63dafd3f9053e6fb5f5744898ce35baa8b367410f8c873e5f9a3759526a7699c`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-10612](inventory/rails-presenters.md#t-10612) | [test/presenters/sign_app_settings_activity_log_presenter_test.rb:21](../../test/presenters/sign_app_settings_activity_log_presenter_test.rb#L21) | `SignAppSettingsActivityLogPresenterTest` | "occurred_at returns occurred_at when present" | contextual equivalence unverified; do not remove by hash |
| [T-10630](inventory/rails-presenters.md#t-10630) | [test/presenters/sign_com_settings_activity_log_presenter_test.rb:21](../../test/presenters/sign_com_settings_activity_log_presenter_test.rb#L21) | `SignComSettingsActivityLogPresenterTest` | "occurred_at returns occurred_at when present" | contextual equivalence unverified; do not remove by hash |
| [T-10647](inventory/rails-presenters.md#t-10647) | [test/presenters/sign_org_settings_activity_log_presenter_test.rb:21](../../test/presenters/sign_org_settings_activity_log_presenter_test.rb#L21) | `SignOrgSettingsActivityLogPresenterTest` | "occurred_at returns occurred_at when present" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0090"></a>
## DUP-0090

Body token hash: `f917093aa1bd54170f56621cc721122923c4a67b4c845bdd65c0e3cffec68946`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-10613](inventory/rails-presenters.md#t-10613) | [test/presenters/sign_app_settings_activity_log_presenter_test.rb:28](../../test/presenters/sign_app_settings_activity_log_presenter_test.rb#L28) | `SignAppSettingsActivityLogPresenterTest` | "occurred_at does not use persistence metadata when the event time is absent" | contextual equivalence unverified; do not remove by hash |
| [T-10631](inventory/rails-presenters.md#t-10631) | [test/presenters/sign_com_settings_activity_log_presenter_test.rb:28](../../test/presenters/sign_com_settings_activity_log_presenter_test.rb#L28) | `SignComSettingsActivityLogPresenterTest` | "occurred_at does not use persistence metadata when the event time is absent" | contextual equivalence unverified; do not remove by hash |
| [T-10648](inventory/rails-presenters.md#t-10648) | [test/presenters/sign_org_settings_activity_log_presenter_test.rb:28](../../test/presenters/sign_org_settings_activity_log_presenter_test.rb#L28) | `SignOrgSettingsActivityLogPresenterTest` | "occurred_at does not use persistence metadata when the event time is absent" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0091"></a>
## DUP-0091

Body token hash: `3730dc38b0e94ea574662a952449e52f7000cb45463d5dbb00973467d1866fca`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-10614](inventory/rails-presenters.md#t-10614) | [test/presenters/sign_app_settings_activity_log_presenter_test.rb:35](../../test/presenters/sign_app_settings_activity_log_presenter_test.rb#L35) | `SignAppSettingsActivityLogPresenterTest` | "event_label translates known event" | contextual equivalence unverified; do not remove by hash |
| [T-10632](inventory/rails-presenters.md#t-10632) | [test/presenters/sign_com_settings_activity_log_presenter_test.rb:35](../../test/presenters/sign_com_settings_activity_log_presenter_test.rb#L35) | `SignComSettingsActivityLogPresenterTest` | "event_label translates known event" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0092"></a>
## DUP-0092

Body token hash: `6b4f085277137c74d5662b6d921498135af6f283518f6ef542f3b7d9a0327a39`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-10615](inventory/rails-presenters.md#t-10615) | [test/presenters/sign_app_settings_activity_log_presenter_test.rb:45](../../test/presenters/sign_app_settings_activity_log_presenter_test.rb#L45) | `SignAppSettingsActivityLogPresenterTest` | "event_label falls back for unknown event" | contextual equivalence unverified; do not remove by hash |
| [T-10633](inventory/rails-presenters.md#t-10633) | [test/presenters/sign_com_settings_activity_log_presenter_test.rb:45](../../test/presenters/sign_com_settings_activity_log_presenter_test.rb#L45) | `SignComSettingsActivityLogPresenterTest` | "event_label falls back for unknown event" | contextual equivalence unverified; do not remove by hash |
| [T-10650](inventory/rails-presenters.md#t-10650) | [test/presenters/sign_org_settings_activity_log_presenter_test.rb:45](../../test/presenters/sign_org_settings_activity_log_presenter_test.rb#L45) | `SignOrgSettingsActivityLogPresenterTest` | "event_label falls back for unknown event" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0093"></a>
## DUP-0093

Body token hash: `f2b0aee6545aa055e76ca81e718f8881a950f51fa3f1933ab763f5239cbcd199`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-10616](inventory/rails-presenters.md#t-10616) | [test/presenters/sign_app_settings_activity_log_presenter_test.rb:54](../../test/presenters/sign_app_settings_activity_log_presenter_test.rb#L54) | `SignAppSettingsActivityLogPresenterTest` | "ip_address masks IPv4" | contextual equivalence unverified; do not remove by hash |
| [T-10634](inventory/rails-presenters.md#t-10634) | [test/presenters/sign_com_settings_activity_log_presenter_test.rb:54](../../test/presenters/sign_com_settings_activity_log_presenter_test.rb#L54) | `SignComSettingsActivityLogPresenterTest` | "ip_address masks IPv4" | contextual equivalence unverified; do not remove by hash |
| [T-10651](inventory/rails-presenters.md#t-10651) | [test/presenters/sign_org_settings_activity_log_presenter_test.rb:54](../../test/presenters/sign_org_settings_activity_log_presenter_test.rb#L54) | `SignOrgSettingsActivityLogPresenterTest` | "ip_address masks IPv4" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0094"></a>
## DUP-0094

Body token hash: `3f972b7170d162c85f64a6980b60f8dea9d46f24c7a4bd18432d750d997aefde`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-10617](inventory/rails-presenters.md#t-10617) | [test/presenters/sign_app_settings_activity_log_presenter_test.rb:60](../../test/presenters/sign_app_settings_activity_log_presenter_test.rb#L60) | `SignAppSettingsActivityLogPresenterTest` | "ip_address returns dash for blank" | contextual equivalence unverified; do not remove by hash |
| [T-10635](inventory/rails-presenters.md#t-10635) | [test/presenters/sign_com_settings_activity_log_presenter_test.rb:60](../../test/presenters/sign_com_settings_activity_log_presenter_test.rb#L60) | `SignComSettingsActivityLogPresenterTest` | "ip_address returns dash for blank" | contextual equivalence unverified; do not remove by hash |
| [T-10652](inventory/rails-presenters.md#t-10652) | [test/presenters/sign_org_settings_activity_log_presenter_test.rb:60](../../test/presenters/sign_org_settings_activity_log_presenter_test.rb#L60) | `SignOrgSettingsActivityLogPresenterTest` | "ip_address returns dash for blank" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0095"></a>
## DUP-0095

Body token hash: `13514e393c2ce14e2ac41b6be6079533a396b378314177bc45d122f1777d0b35`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-10618](inventory/rails-presenters.md#t-10618) | [test/presenters/sign_app_settings_activity_log_presenter_test.rb:66](../../test/presenters/sign_app_settings_activity_log_presenter_test.rb#L66) | `SignAppSettingsActivityLogPresenterTest` | "ip_address returns raw value for non-IPv4" | contextual equivalence unverified; do not remove by hash |
| [T-10636](inventory/rails-presenters.md#t-10636) | [test/presenters/sign_com_settings_activity_log_presenter_test.rb:66](../../test/presenters/sign_com_settings_activity_log_presenter_test.rb#L66) | `SignComSettingsActivityLogPresenterTest` | "ip_address returns raw value for non-IPv4" | contextual equivalence unverified; do not remove by hash |
| [T-10653](inventory/rails-presenters.md#t-10653) | [test/presenters/sign_org_settings_activity_log_presenter_test.rb:66](../../test/presenters/sign_org_settings_activity_log_presenter_test.rb#L66) | `SignOrgSettingsActivityLogPresenterTest` | "ip_address returns raw value for non-IPv4" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0096"></a>
## DUP-0096

Body token hash: `38ffde94c168ca9903ad203be29f549660515be779555ea537c933cf42fd94ef`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-10619](inventory/rails-presenters.md#t-10619) | [test/presenters/sign_app_settings_activity_log_presenter_test.rb:72](../../test/presenters/sign_app_settings_activity_log_presenter_test.rb#L72) | `SignAppSettingsActivityLogPresenterTest` | "context_text filters sensitive keys" | contextual equivalence unverified; do not remove by hash |
| [T-10637](inventory/rails-presenters.md#t-10637) | [test/presenters/sign_com_settings_activity_log_presenter_test.rb:72](../../test/presenters/sign_com_settings_activity_log_presenter_test.rb#L72) | `SignComSettingsActivityLogPresenterTest` | "context_text filters sensitive keys" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0097"></a>
## DUP-0097

Body token hash: `8ada5fe362a38ddda3f5a31175842c03dfde119105b8407cbf9c06e65aa19758`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-10620](inventory/rails-presenters.md#t-10620) | [test/presenters/sign_app_settings_activity_log_presenter_test.rb:83](../../test/presenters/sign_app_settings_activity_log_presenter_test.rb#L83) | `SignAppSettingsActivityLogPresenterTest` | "context_text returns empty hash for non-hash context" | contextual equivalence unverified; do not remove by hash |
| [T-10638](inventory/rails-presenters.md#t-10638) | [test/presenters/sign_com_settings_activity_log_presenter_test.rb:83](../../test/presenters/sign_com_settings_activity_log_presenter_test.rb#L83) | `SignComSettingsActivityLogPresenterTest` | "context_text returns empty hash for non-hash context" | contextual equivalence unverified; do not remove by hash |
| [T-10655](inventory/rails-presenters.md#t-10655) | [test/presenters/sign_org_settings_activity_log_presenter_test.rb:83](../../test/presenters/sign_org_settings_activity_log_presenter_test.rb#L83) | `SignOrgSettingsActivityLogPresenterTest` | "context_text returns empty hash for non-hash context" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0098"></a>
## DUP-0098

Body token hash: `7c25d085cf30188b6e0dbbfca4b8236ccd8502395a0e9bbc735ec0ed0b2bc32a`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-10622](inventory/rails-presenters.md#t-10622) | [test/presenters/sign_app_settings_activity_log_presenter_test.rb:95](../../test/presenters/sign_app_settings_activity_log_presenter_test.rb#L95) | `SignAppSettingsActivityLogPresenterTest` | "user_agent_summary detects Chrome desktop" | contextual equivalence unverified; do not remove by hash |
| [T-10640](inventory/rails-presenters.md#t-10640) | [test/presenters/sign_com_settings_activity_log_presenter_test.rb:103](../../test/presenters/sign_com_settings_activity_log_presenter_test.rb#L103) | `SignComSettingsActivityLogPresenterTest` | "user_agent_summary detects Chrome desktop" | contextual equivalence unverified; do not remove by hash |
| [T-10656](inventory/rails-presenters.md#t-10656) | [test/presenters/sign_org_settings_activity_log_presenter_test.rb:89](../../test/presenters/sign_org_settings_activity_log_presenter_test.rb#L89) | `SignOrgSettingsActivityLogPresenterTest` | "user_agent_summary detects Chrome desktop" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0099"></a>
## DUP-0099

Body token hash: `02ddccdf5b6732096f6cc7dd192e79d18f7526045552ede319cc74ef62a656ae`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-10623](inventory/rails-presenters.md#t-10623) | [test/presenters/sign_app_settings_activity_log_presenter_test.rb:101](../../test/presenters/sign_app_settings_activity_log_presenter_test.rb#L101) | `SignAppSettingsActivityLogPresenterTest` | "user_agent_summary detects Firefox mobile" | contextual equivalence unverified; do not remove by hash |
| [T-10641](inventory/rails-presenters.md#t-10641) | [test/presenters/sign_com_settings_activity_log_presenter_test.rb:109](../../test/presenters/sign_com_settings_activity_log_presenter_test.rb#L109) | `SignComSettingsActivityLogPresenterTest` | "user_agent_summary detects Firefox mobile" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0100"></a>
## DUP-0100

Body token hash: `e6c4b324009cf5351d3da044e5e671d6f88ee544e9ecbb85e481799e6fac6ab4`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-10626](inventory/rails-presenters.md#t-10626) | [test/presenters/sign_app_settings_activity_log_presenter_test.rb:119](../../test/presenters/sign_app_settings_activity_log_presenter_test.rb#L119) | `SignAppSettingsActivityLogPresenterTest` | "user_agent_summary returns dash for blank" | contextual equivalence unverified; do not remove by hash |
| [T-10642](inventory/rails-presenters.md#t-10642) | [test/presenters/sign_com_settings_activity_log_presenter_test.rb:115](../../test/presenters/sign_com_settings_activity_log_presenter_test.rb#L115) | `SignComSettingsActivityLogPresenterTest` | "user_agent_summary returns dash for blank" | contextual equivalence unverified; do not remove by hash |
| [T-10658](inventory/rails-presenters.md#t-10658) | [test/presenters/sign_org_settings_activity_log_presenter_test.rb:101](../../test/presenters/sign_org_settings_activity_log_presenter_test.rb#L101) | `SignOrgSettingsActivityLogPresenterTest` | "user_agent_summary returns dash for blank" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0101"></a>
## DUP-0101

Body token hash: `d021a4ce544bba0eee5b3f0cf2b99bed4eb7242181b002d730de6bed621dd876`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-10627](inventory/rails-presenters.md#t-10627) | [test/presenters/sign_app_settings_activity_log_presenter_test.rb:125](../../test/presenters/sign_app_settings_activity_log_presenter_test.rb#L125) | `SignAppSettingsActivityLogPresenterTest` | "login_method returns method from context" | contextual equivalence unverified; do not remove by hash |
| [T-10643](inventory/rails-presenters.md#t-10643) | [test/presenters/sign_com_settings_activity_log_presenter_test.rb:121](../../test/presenters/sign_com_settings_activity_log_presenter_test.rb#L121) | `SignComSettingsActivityLogPresenterTest` | "login_method returns method from context" | contextual equivalence unverified; do not remove by hash |
| [T-10659](inventory/rails-presenters.md#t-10659) | [test/presenters/sign_org_settings_activity_log_presenter_test.rb:107](../../test/presenters/sign_org_settings_activity_log_presenter_test.rb#L107) | `SignOrgSettingsActivityLogPresenterTest` | "login_method returns method from context" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0102"></a>
## DUP-0102

Body token hash: `ac6087b7689f30b06f30d6114a8743e98bc5d535a698e08d67cb18673da10d65`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-10628](inventory/rails-presenters.md#t-10628) | [test/presenters/sign_app_settings_activity_log_presenter_test.rb:131](../../test/presenters/sign_app_settings_activity_log_presenter_test.rb#L131) | `SignAppSettingsActivityLogPresenterTest` | "login_method returns dash when blank" | contextual equivalence unverified; do not remove by hash |
| [T-10645](inventory/rails-presenters.md#t-10645) | [test/presenters/sign_com_settings_activity_log_presenter_test.rb:133](../../test/presenters/sign_com_settings_activity_log_presenter_test.rb#L133) | `SignComSettingsActivityLogPresenterTest` | "login_method returns dash when blank" | contextual equivalence unverified; do not remove by hash |
| [T-10661](inventory/rails-presenters.md#t-10661) | [test/presenters/sign_org_settings_activity_log_presenter_test.rb:119](../../test/presenters/sign_org_settings_activity_log_presenter_test.rb#L119) | `SignOrgSettingsActivityLogPresenterTest` | "login_method returns dash when blank" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0103"></a>
## DUP-0103

Body token hash: `e5225fa34013df897fb0f8edca06e3aa5d06a007b5f7672a8d231bf0f10f7c84`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-10639](inventory/rails-presenters.md#t-10639) | [test/presenters/sign_com_settings_activity_log_presenter_test.rb:89](../../test/presenters/sign_com_settings_activity_log_presenter_test.rb#L89) | `SignComSettingsActivityLogPresenterTest` | "context_text handles non-serializable context" | contextual equivalence unverified; do not remove by hash |
| [T-10662](inventory/rails-presenters.md#t-10662) | [test/presenters/sign_org_settings_activity_log_presenter_test.rb:125](../../test/presenters/sign_org_settings_activity_log_presenter_test.rb#L125) | `SignOrgSettingsActivityLogPresenterTest` | "context_text handles non-serializable context" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0104"></a>
## DUP-0104

Body token hash: `c1dec470430446963c0420f37bc9e3f1012c72a4b5acd1bfffbcad89d4a52e5f`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-10644](inventory/rails-presenters.md#t-10644) | [test/presenters/sign_com_settings_activity_log_presenter_test.rb:127](../../test/presenters/sign_com_settings_activity_log_presenter_test.rb#L127) | `SignComSettingsActivityLogPresenterTest` | "login_method falls back to method key" | contextual equivalence unverified; do not remove by hash |
| [T-10660](inventory/rails-presenters.md#t-10660) | [test/presenters/sign_org_settings_activity_log_presenter_test.rb:113](../../test/presenters/sign_org_settings_activity_log_presenter_test.rb#L113) | `SignOrgSettingsActivityLogPresenterTest` | "login_method falls back to method key" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0105"></a>
## DUP-0105

Body token hash: `c079db2f81f05836e89177574277066b12bb2086e8dddccd2f847c58e6916a1b`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-10646](inventory/rails-presenters.md#t-10646) | [test/presenters/sign_com_settings_activity_log_presenter_test.rb:139](../../test/presenters/sign_com_settings_activity_log_presenter_test.rb#L139) | `SignComSettingsActivityLogPresenterTest` | "activities returns an enumerable" | contextual equivalence unverified; do not remove by hash |
| [T-10663](inventory/rails-presenters.md#t-10663) | [test/presenters/sign_org_settings_activity_log_presenter_test.rb:139](../../test/presenters/sign_org_settings_activity_log_presenter_test.rb#L139) | `SignOrgSettingsActivityLogPresenterTest` | "activities returns an enumerable" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0106"></a>
## DUP-0106

Body token hash: `ea85f556ee26f420a477ee2d0584231e98caaa181de12cf2bce0f77d1fef5428`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-11245](inventory/rails-services-root.md#t-11245) | [test/services/branch_coverage_batch31_more_easy_arms_test.rb:26](../../test/services/branch_coverage_batch31_more_easy_arms_test.rb#L26) | `BranchCoverageBatch31MoreEasyArmsTest` | "OidcIdTokenIssuer blank nonce and inverted times" | contextual equivalence unverified; do not remove by hash |
| [T-13391](inventory/rails-values.md#t-13391) | [test/values/branch_coverage_easy_wins_test.rb:41](../../test/values/branch_coverage_easy_wins_test.rb#L41) | `BranchCoverageEasyWinsTest` | "OidcIdTokenIssuer rejects blank nonce and inverted time ordering" | contextual equivalence unverified; do not remove by hash |

<a id="dup-0107"></a>
## DUP-0107

Body token hash: `6cbdc8a7f9dbfdb099683ba6e1671bd0c790b997a58372cdbd25c3923122e3ea`.

| Definition | Source | Owner/context | Name | Disposition |
| --- | --- | --- | --- | --- |
| [T-11938](inventory/rails-services-oidc.md#t-11938) | [test/services/oidc/token_exchange_service_test.rb:994](../../test/services/oidc/token_exchange_service_test.rb#L994) | `OidcTokenExchangeCoordinatorTest` | "fails invalid_client for missing confidential client secret" | contextual equivalence unverified; do not remove by hash |
| [T-11958](inventory/rails-services-oidc.md#t-11958) | [test/services/oidc/token_exchange_service_test.rb:1416](../../test/services/oidc/token_exchange_service_test.rb#L1416) | `OidcTokenExchangeCoordinatorTest` | "confidential client cannot use public path by omitting secret" | LV-039 |
