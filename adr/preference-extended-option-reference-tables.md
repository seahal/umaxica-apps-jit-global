# Preference Extended Option Reference Tables

## Status

Accepted on 2026-05-14; amended on 2026-10-31 by the owner-approved WU-P0 decision and on 2026-11-04
for the Experience redesign in `five.md` C3-C4.

## Amendment 2026-11-04: Web Push in both Experience stores

Web Push enabled/disabled remains a fixed reference-table option. The owner decided that the setting
is available in Browser Experience on APP, COM and ORG, and in Account Experience on APP and ORG; an
explicitly saved Account Experience value takes precedence over Browser Experience, while an unset
value falls through to Browser Experience and then the `disabled` default. This setting is not
browser notification permission or subscription state, and it does not authorize delivery. The
Experience redesign's persistence names and routes are not fixed by this amendment; see `five.md` C5
for the remaining shape and lifecycle decisions.

## Context

Preference values now include display, accessibility, and locale-adjacent options beyond language,
region, timezone, and theme. These values must behave consistently on the `app`, `org`, and `com`
sign surfaces while preserving each surface boundary and each preference database boundary.

## Decision

Currency, date format, time format, motion, density, and items-per-page settings are modeled as
fixed reference-table options, not booleans or unconstrained free-form values.

The shared preference records use child option records:

- `AppPreference`, `OrgPreference`, and `ComPreference`

The local preference records use the same child option records:

- `ClientPreference`
- `OperatorPreference`

The five prefixes participate in `PreferenceClassRegistry`: `AppPreference`, `OrgPreference`,
`ComPreference`, `ClientPreference`, and `OperatorPreference`. The registry lists these prefixes
statically and raises for an unsupported prefix; it does not infer model names from a controller
namespace. The `visitor_*` and `user_*`/`staff_*` prefixes are retired.

Option names are wire values carried by the realm Preference JWT and display cookies. Unknown names,
keys, and duplicate cookie names are refused; they are not aliased or replaced with defaults.

Cookie consent receipts, browser binding records, and Web Push option records live in the realm
setting database. Each has `NOT NULL` columns and a unique parent reference. Web Push uses a
reference to its registered enabled/disabled option row, not a boolean. A missing child row means
unbound or disabled; database `NULL` does not encode either state.

`adult_content_gate` remains as a model, option table, and child table, but is excluded from runtime
display/save registries, the Preference JWT, and controller paths.

Binding-method and DBSC status references, single-use token state, and refresh/DBSC child state are
removed from Preference parents.

## Option Sets

- `currency`: `usd`, `jpy`; default `jpy`
- `date_format`: `iso`, `uk`, `us`; default `iso`
- `time_format`: `hour_24`, `hour_12`; default `hour_24`
- `motion`: `standard`, `reduced`; default `standard`
- `density`: `standard`, `compact`; default `standard`
- `items_per_page`: `10`, `20`, `50`, `100`, `infinity`; default `20`

## Consequences

- New preference types must be added through the registry and reference-table path.
- Surface-specific controllers should remain thin and only declare the preference screen they
  expose.
- Foreign keys must protect every child option record from pointing at an unknown option.
