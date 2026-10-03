# Japan SaaS Legal Triage

## Abstract (EN)

This document is a Japan-specific legal triage note for this repository. It separates legal work
into `must`, `maybe`, and `not now` based on the currently visible product scope. The main text is
written in English for repository use.

## Overview (EN)

This document is a legal arrangement based on Japanese law for this repository. Based on the
currently visible product range, `must`, `maybe`, `not now` Organize it by dividing it into The main
text will be written in English for internal use in the repository.

## Purpose

This note is a practical product-law triage for a Japan-facing SaaS.

It is not a substitute for advice from qualified Japanese counsel. Its purpose is to help the team
decide:

- which legal topics are already in scope
- which topics become relevant only when feature scope expands
- which topics do not need immediate work

## Scope Of This Note

This note is specific to Japanese law and Japanese service operation.

It does not attempt to cover:

- US law
- EU law
- China law
- country-by-country cross-border detail outside the Japan baseline

## Product Signals Confirmed In This Repository

The current repository shows these product signals:

- account registration and authentication
- email and telephone identity handling
- OTP, passkey, and social login flows
- contact and help flows
- cookie, theme, and preference handling
- documentation and news delivery surfaces
- placeholder direct message routes and a message database skeleton

Primary repository sources used for this triage:

- `docs/spec/srs.md`
- `config/routes/auth.rb`
- `config/routes/core.rb`

## Reading Rule

- `must`: already relevant to the current product scope, or very difficult to defer safely
- `maybe`: not always required, but likely to become required if the visible feature set is made
  real or expanded
- `not now`: no strong repository evidence that the topic is currently in scope

## Must

### 1. Act on the Protection of Personal Information (APPI)

This is already in scope.

Why:

- the product handles account data
- the product handles email addresses and telephone numbers
- the product handles authentication and session data
- the product handles contact intake and IP-linked service activity

Minimum work items:

- privacy policy
- purpose-of-use definition
- internal security controls
- vendor and processor management
- data subject request handling
- breach response handling

### 2. Terms of Service

This is effectively mandatory for this product.

Why:

- the service has accounts, identity flows, and contact features
- the service needs rules for suspension, deletion, misuse, and service changes
- future message capability increases the need for clear user obligations

Minimum work items:

- user obligations
- prohibited conduct
- suspension and termination
- disclaimer and limitation structure
- governing law and dispute clause

### 3. Privacy Policy

This is separate from the internal APPI program and must be visible to users.

Why:

- the product collects multiple categories of personal data
- the product uses security and authentication tooling
- the product operates multiple surfaces and support flows

Minimum work items:

- categories of collected data
- purpose of use
- third-party sharing / outsourcing explanation
- retention high-level explanation
- rights request channel

### 4. External Transmission Rules Review

This is a `must` review item for a modern website or app.

Why:

- the product operates websites and app-like surfaces
- cookie and preference handling already exists
- anti-bot, analytics, or external modules are realistic and partly visible

Minimum work items:

- inventory of external tags, SDKs, and modules
- what user-related information is sent out
- destination of transmission
- stated purpose of transmission
- user-visible disclosure path

### 5. Cookie And Tracking Disclosure Alignment

This is already in scope.

Why:

- cookie preference UI already exists
- preference and theme handling are already implemented
- legal text and runtime behavior must match

Minimum work items:

- cookie categories
- actual runtime mapping of each category
- disclosure text that matches implementation
- operational ownership for future changes

### 6. Premiums and Representations Act Review

This is already in scope for public marketing and product claims.

Why:

- the service has public-facing surfaces
- product copy, support copy, and future launch copy can create overstatement risk
- stealth marketing restrictions are relevant for testimonials, influencer campaigns, and reviews

Minimum work items:

- review product claims
- review comparison claims
- review testimonial and review usage
- review any sponsored or affiliate content labeling

### 7. Breach Response Flow

This is a `must` operations item.

Why:

- APPI duties are not only document duties
- authentication, contact, and account data make incident handling unavoidable

Minimum work items:

- incident intake and escalation path
- severity criteria
- PPC reporting decision flow
- user notice decision flow
- evidence preservation and postmortem handling

## Maybe

### 1. Telecommunications Business Act Review

This is `maybe`, but high priority.

Why:

- the repository already contains `messages` routes and a message database skeleton
- placeholder one-to-one message capability is a visible product signal
- if one-to-one direct messaging becomes a real launch feature, this can move to `must`

Current position:

- placeholder-only state: `maybe`
- production-ready direct messaging: `must`

### 2. Specified Commercial Transactions Act Review

This is `maybe`.

Why:

- it becomes important if the service sells paid plans online, especially to consumers
- current repository evidence does not yet show a strong live billing flow

Trigger examples:

- paid subscription plan
- auto-renewal
- online checkout
- cancellation and refund flow

### 3. User-Generated Content / Platform Response Work

This is `maybe`.

Why:

- docs, news, contact, and message-adjacent structures exist
- stronger post, comment, review, or open user-content features would increase this risk

Typical work items if triggered:

- takedown handling
- disclosure request handling
- preservation handling
- moderation governance

### 4. Cross-Border Transfer Review

This is `maybe`.

Why:

- many SaaS products use foreign cloud, vendors, or support tooling
- the repository alone does not confirm the final vendor map

Trigger examples:

- foreign cloud hosting
- foreign analytics or support vendors
- overseas operational access to personal data

### 5. Employment Placement / Worker Dispatch Review

This is `maybe`.

Why:

- there is no strong repository evidence that the current product is an employment placement or
  worker dispatch service
- however, if the service later matches employers and workers, mediates hiring, or arranges
  staffing, this area becomes relevant

Trigger examples:

- paid job matching
- recruitment platform with active placement involvement
- staff dispatch coordination
- candidate screening or introduction as a regulated business function

Typical laws to review if triggered:

- Employment Security Act
- Worker Dispatching Act
- related ministry guidance from MHLW

### 6. Telecom-Sector Personal Information Rules

This is `maybe`.

Why:

- it becomes more important if the product is treated as a telecommunications business in practice
- direct messaging and similar communication features increase relevance

## Not Now

### 1. Payment Services Act

This is `not now`.

Why:

- there is no strong repository evidence of wallet, stored value, prepaid balance, or remittance

### 2. Financial Regulation For Money Movement

This is `not now`.

Why:

- there is no strong repository evidence of inter-user payment, funds transfer, or equivalent
  payment intermediation

### 3. Medical / Healthcare Sector Rules

This is `not now`.

Why:

- the repository does not show a healthcare product scope

### 4. Immediate Licensing Work For Employment Placement / Worker Dispatch

This is `not now` at the current repository state.

Why:

- no clear employment placement or worker dispatch implementation is visible today
- keep the topic tracked as `maybe`, not as current mandatory licensing work

## App-Specific Priority Order

For this repository, the recommended priority order is:

1. APPI baseline program
2. Terms of Service
3. Privacy Policy
4. External transmission rules review
5. Cookie and tracking disclosure alignment
6. Premiums and Representations Act review
7. Breach response flow
8. Telecommunications Business Act review before any real DM launch

## Quick Matrix

| Topic                                  | Status  | Why                                                           |
| -------------------------------------- | ------- | ------------------------------------------------------------- |
| APPI                                   | Must    | Personal data and account data are already in scope           |
| Terms of Service                       | Must    | Account lifecycle and misuse rules are already needed         |
| Privacy Policy                         | Must    | User-visible explanation is already needed                    |
| External transmission rules            | Must    | Modern web/app operation plus cookie handling                 |
| Cookie / tracking disclosure           | Must    | Runtime preference behavior already exists                    |
| Premiums and Representations Act       | Must    | Public claims and marketing risk already exist                |
| Breach response flow                   | Must    | Incident handling is unavoidable                              |
| Telecommunications Business Act        | Maybe   | Message feature is visible but still placeholder-level        |
| Specified Commercial Transactions Act  | Maybe   | Triggered by paid online sales                                |
| UGC / platform response                | Maybe   | Triggered by stronger user content features                   |
| Cross-border transfer review           | Maybe   | Depends on actual vendor and data-flow map                    |
| Employment placement / worker dispatch | Maybe   | Track now in case the service grows into matching or staffing |
| Payment Services Act                   | Not now | No wallet or stored value signal                              |
| Money movement regulation              | Not now | No remittance or payout signal                                |
| Medical / healthcare regulation        | Not now | No healthcare scope signal                                    |

## Sources

- Personal Information Protection Commission (PPC): `https://www.ppc.go.jp/personalinfo/`
- PPC breach response page: `https://www.ppc.go.jp/personalinfo/legal/leakAction/leakAction_detail`
- Consumer Affairs Agency, Specified Commercial Transactions Act:
  `https://www.caa.go.jp/policies/policy/consumer_transaction/specified_commercial_transactions/`
- Consumer Affairs Agency, stealth marketing / Premiums and Representations Act:
  `https://www.caa.go.jp/policies/policy/representation/fair_labeling/stealth_marketing/`
- National center legal Q&A on telecom registration / notification:
  `https://security-portal.cyber.go.jp/guidance/pdf/law_handbook/law_handbook_2.pdf`
- MIC external transmission rules page:
  `https://www.soumu.go.jp/main_sosiki/joho_tsusin/d_syohi/gaibusoushin_kiritsu_00001.html`

## Next Suggested Use

This document can be used as the source for:

- a `must`-only implementation checklist
- GitHub issues for legal and operational work
- release gates for regulated feature rollout
