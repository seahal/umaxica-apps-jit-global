# Inertia Props Exposure Audit

Recorded 2026-10-20. Status: backlog. No defect has been found; this is a preventive audit.

## Background

An Inertia response embeds the whole page object, including every prop, in the HTML (the
`<script data-page="app" type="application/json">` element, enabled by
`use_script_element_for_initial_page`) or in the JSON body of an Inertia visit. A prop the page does
not display is still readable by anyone who can view the page source. With `encrypt_history`, the
same props are also stored in the tab's history until it is cleared.

## Audit scope

- Shared props (`inertia_share` and any controller-level shared data) on every surface: confirm they
  carry no personal data, internal identifiers, tokens or digests that every page does not need.
- Page props on authenticated and Step-Up pages: confirm each field is displayed or required by the
  page, and that no secret, credential reference, hash, other actor's data or internal database
  identifier is included.
- Deferred, optional or partial-reload props: confirm each one is authorized at the same level as
  the page that declares it.
- Error and validation props (`always_include_errors_hash`): confirm they do not echo submitted
  secrets.

## Expected output

An inventory of props per surface with a decision for each sensitive field, and regression tests for
any field that is removed or restricted.
