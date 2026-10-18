# Manual acceptance: RP `/sign` reaches the auth sign-in page

- Date: 2026-10-02
- Commit: `845f84b281663786c4d4e0f6473fcf3ab2040b74`. Uncommitted changes to `.env.example`,
  `db/seeds.rb`, and an avatars migration were present; they do not touch routing or the sign flow.
- Method: a person opened each RP `https://<rp>/sign` in a browser through the Cloudflare Tunnel
  and pressed the sign button. The chain was then read from `log/development.log`
  (`Processing by`, `Redirected to`, `Completed` lines).
- Scope: RP → base (`/oauth/authorize`) → auth (`/sign/in` rendered). Sign-in or sign-up
  completion, IdP (`/social/*`) ceremonies, and the return to `/sign/callback` are out of scope.
  `*.umaxica.dev` is out of scope.

## Pass criteria for one RP

1. `<Surface>::<Area>::Sign::EntriesController#show` renders 200 on the RP host.
2. `#create` redirects to `jump.umaxica.net`.
3. `Base::<Area>::Oauth::AuthorizationsController#show` runs on `www.umaxica.<tld>` with
   `client_id` of the RP and `redirect_uri=https://<rp>/sign/callback`.
4. `Auth::<Area>::Sign::InsController#show` renders 200 on `auth.umaxica.<tld>/sign/in`.

## Matrix

RP routes come from `config/routes/core.rb`, `config/routes/warp.rb`, and `config/routes/edit.rb`.

| RP host              | client_id  | Base                  | Auth                         | Result      |
| -------------------- | ---------- | --------------------- | ---------------------------- | ----------- |
| `jp.umaxica.app`     | `core-app` | `Base::App` (www.app) | `Auth::App::Sign::Ins` 200   | Pass        |
| `jp.umaxica.com`     | `core-com` | `Base::Com` (www.com) | `Auth::Com::Sign::Ins` 200   | Pass        |
| `jp.umaxica.org`     | `core-org` | `Base::Org` (www.org) | `Auth::Org::Sign::Ins` 200   | Pass        |
| `www-jp.umaxica.app` | `side-app` | `Base::App` (www.app) | `Auth::App::Sign::Ins` 200   | Pass        |
| `www-jp.umaxica.com` | `side-com` | `Base::Com` (www.com) | `Auth::Com::Sign::Ins` 200   | Pass        |
| `www-jp.umaxica.org` | `side-org` | `Base::Org` (www.org) | `Auth::Org::Sign::Ins` 200   | Pass        |
| `edit.umaxica.org`   | `edit-org` | `Base::Org` (www.org) | `Auth::Org::Sign::Ins` 200   | Pass (note) |

## Observations

- Core rows: every step 1–4 appeared in order for each RP, with the `redirect_uri` pointing back to
  the same RP host. The tunnel path rule recorded in
  `docs/architecture/cloudflare-request-paths.md` was in effect.
- Warp rows: steps 1–4 appeared in order for each RP, with `redirect_uri` pointing back to the same
  `www-jp` host.
- `edit.umaxica.org`: `Edit::Org::Sign::EntriesController#create` redirected directly to
  `https://www.umaxica.org/oauth/authorize` (`client_id: edit-org`,
  `redirect_uri=https://edit.umaxica.org/sign/callback`) instead of through `jump.umaxica.net`, so
  step 2 differs from the other RPs. Steps 3 and 4 passed. Whether the edit RP is meant to skip the
  jump hop was not investigated here.
- Every `auth.umaxica.<tld>/sign/in` page also accepted one `Sign::InsController#create` submission
  that redirected back to `/sign/in`; that is outside this acceptance scope.

All seven RPs in scope reached the auth sign-in page.
