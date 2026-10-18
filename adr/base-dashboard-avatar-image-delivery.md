# Base Dashboard Avatar Image Delivery

## Status

Accepted

## Date

2026-09-26

## Context

The Base Dashboard shows the selected Persona's name but no Avatar image. Avatar images are stored
through Shrine (`AvatarImageUploader`, storage boundary `:avatar`) in a private bucket, and nothing
served them. `adr/base-dashboard-return-navigation.md` left image delivery to the storage boundary
and ruled out a public URL. The options were compared in
`plans/backlog/2026-09-25-avatar-image-and-emergency-credential-decisions.md` §1; the owner approved
option A on 2026-09-26.

Avatar capability differs by surface: app requires an Avatar, org's is optional, com has none.

## Decision

- Base app and org each serve `GET /dashboard/avatar_image` (`base_app_dashboard_avatar_image`,
  `base_org_dashboard_avatar_image`), an authenticated Rails proxy that streams the stored file of
  the Avatar in the session's current selection. com has no route.
- The identity comes only from the session selection. The whole selection (Persona, organization,
  unit, Avatar) is re-validated against the real candidates through
  `BaseSwitcherAuthority#selected_avatar`, then `AvatarPolicy#show?` is applied. The `v` query
  parameter is a cache buster and never selects anything.
- Responses carry `Cache-Control: max-age=0, private, must-revalidate` and an ETag from `Avatar#image_cache_key`
  (a digest of the Avatar public ID and stored file ID). The Dashboard renders the image URL with
  the same key as `v`, so a Persona switch changes the URL and the ETag.
- Absence and failure:
  - app: a valid selection without an Avatar is a broken invariant and raises. An Avatar without a
    stored image returns the static, non-identifying `app/assets/images/base/default_avatar.png`.
  - org: no selected Avatar, or an Avatar without a stored image, is a normal absence. The
    Dashboard omits the image element and the endpoint answers 404.
  - A selection that is no longer a candidate answers 404 on both surfaces; it never falls back to
    the default image.
  - A storage read failure or an unexpected stored MIME type raises; it is not rendered as absence.
- The image GET does not track session activity and does not issue the Preference cookie.
- Anonymous app/org image GET and HEAD use the existing private authentication
  gate and return bodyless 401 instead of an interactive Sign redirect. Headers
  claiming HTML, an image destination or a valid Inertia request do not bypass
  authentication or change this endpoint into a login document. JSON retains the
  gate's existing error representation; HEAD has no body. No admission, root
  login or image read is initiated by refusal. com still has no image endpoint.

## Consequences

- The bucket stays private and CSP `img-src` needs no bucket host.
- Image bytes pass through the application; images are capped at 5 MiB by the uploader.
- The default image is PNG rather than SVG, following the uploader guidance against active content.

## Alternatives Considered

### Short-lived presigned URL

Rejected: anyone holding the URL can fetch the image until expiry, the URL reaches browser history
and logs, and CSP must allow the bucket host.

### Public derivative bucket

Rejected: Avatar images would become world-readable by URL, contradicting the private boundary.

## 2026-10-04 response clarification

The integrated Base authentication guidance contract applies interactive Sign
navigation to protected documents, while non-document image retrieval remains a
refusal. The old app image test expected a redirect; that expectation is replaced
by 401 with no Location or image body. org's previous broad non-200 assertion is
made explicit. Authenticated delivery, missing-image/invalid-selection 404,
private storage and ETag behavior are unchanged.

AuthenticationBase supplies the response extension authentication_redirect_allowed?
to both its mode gate and explicit authentication method. The two image
controllers opt out; all other controllers retain the default. The image-specific
app authenticate_client! callback is removed because PreAccessController already
registers it in addition to the private mode gate. No gate is skipped and no
second authentication redirect concern is introduced.

The existing Inertia version check remains independent and may return its own
409 before this boundary on a mismatched version. Tests of the authentication
response use the configured version and do not disable that adapter check.
