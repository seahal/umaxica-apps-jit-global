# Edit Publishing Management Surface

`edit.umaxica.org` is the staff Publishing management surface. It owns the twelve explicit
Publishing surface and audience controller cells and their Inertia page identifiers.

Base Org no longer routes or implements the Publishing management UI. Publishing persistence,
models, queries, policies, operations, and schema remain in this Global Rails application; this is
only a web-surface boundary move that prepares a later extraction.

Edit retains the current authenticated active-operator and Action Policy pipeline. It does not add
an IdP or session protocol. Its common operational endpoints are `/revision`, `/health`, the three
health probes, and the JSON health and revision variants.

## Verification

Ruby syntax validation was run for every `app/controllers/edit/**/*.rb` file. Rails test execution
was blocked before application boot because the checkout lacks the git-sourced Rails revision
required by `Gemfile.lock` under `vendor/bundle`; no dependency installation or lockfile mutation
was performed for this change.
