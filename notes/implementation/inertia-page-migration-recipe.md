# Inertia page migration recipe

The canonical procedure for converting one Rails browser HTML page from ERB to an Inertia + React +
TypeScript page. Follow it per route/action; one resource or ceremony is one commit.

Design decisions behind it are recorded in
`plans/inertia-react-typescript-full-view-migration-audit.md`.

## Scope

Migrate: every browser HTML page action of the `base`, `auth`, `core`, `side` and `palm` families,
including the `layout false` root landings.

Do not touch:

- Mailer views and mailer layouts (`app/views/email/**`, `app/views/layouts/{mailer,email}/**`)
- `info`, `docs`, `news`, `help` (their landings stay ERB; content HTML belongs to the frontend
  repository)
- Non-HTML responses: `render json`, `render plain`, `head`, redirects, OAuth/OIDC callbacks, health
  probes, `robots.txt`, sitemaps, CSP violation reports, PWA engine routes
- Authentication and authorization behaviour of any kind

## Server side

1. Include the marker concern; it selects the surface Inertia layout and supplies the chrome props.

   ```ruby
   include ::SurfaceInertiaPage
   ```

   Remove any `layout "..."` and `layout false` line the controller carried: the concern owns it.

2. Render the page and give it props. `inertia: true` derives the component name from
   `controller_path` + `action_name`, which is the name the page file must match.

   ```ruby
   def show
     render inertia: true, props: show_page_props
   end
   ```

   An action with an empty body (implicit ERB render) becomes an explicit `render inertia: true`.

3. Build props in a private method. Props are the new view boundary, so everything the old ERB
   computed with a helper is computed here:
   - **Translation** stays server-side: send finished strings, never i18n keys.
   - **URLs** stay server-side: send `*_path` / `*_url` output, never path fragments React joins.
   - **Authorization** stays server-side: omit a link or an action the actor may not use rather than
     sending it with a flag for React to hide.
   - Serialize explicitly. Never pass an ActiveRecord object, a token, a session value or a secret.
     Map to a plain Hash of `public_id`, strings, booleans, ISO timestamps.
   - Include a `title:` prop. The layout renders the document title from it server-side.

4. Failure paths follow the Inertia contract: redirect back and let the errors hash carry the
   message (`always_include_errors_hash` is enabled), instead of re-rendering with 422.
   `render plain` security rejections (rate limits, cooldowns, CSRF) stay exactly as they are.

5. Delete the ERB template the action rendered, and any partial that no page renders any more.

## Client side

6. Create `src/pages/<family>/<surface>/<rest>/<action>.tsx` matching the component name exactly.
   `src/pages/base/app/identity/emails/index.tsx` answers `base/app/identity/emails/index`.

7. The page renders a `<section>`, not a page frame. The header, footer, banner and preference
   controls come from `src/layouts/SurfaceLayout.tsx`, which the resolver attaches automatically.
   **Never assign `Page.layout` in a page module.**

8. Type the props. No `any`, no `Record<string, any>`. Shared props are typed in
   `src/types/inertia.ts`.

   ```tsx
   type Props = { title: string; emails: { public_id: string; address: string }[] };

   export default function EmailsIndex({ title, emails }: Props) { ... }
   ```

9. A component used by more than one surface lives in `src/features/<area>/<Name>.tsx`, and each
   surface page re-exports it, because a surface resolver may only glob its own directory:

   ```tsx
   export { default } from "@/features/identity/EmailsIndex";
   ```

10. Forms use `useForm` from `@inertiajs/react` and keep the HTTP verb the Rails route expects
    (`patch`, `put`, `delete`). Read validation errors from the form's `errors`. Do not turn a
    destructive action into a GET.

## Tests

11. Minitest keeps testing the contract, through the page object helper (auto-included in
    integration tests, `test/support/inertia_page_object.rb`):

    ```ruby
    assert_equal "base/app/identity/emails/index", inertia_component
    assert_equal "Emails", inertia_props.fetch("title")
    ```

    Convert `assert_select` and `response.body` assertions one for one into props assertions. Never
    delete an assertion to make the migration pass, and never add a skip. Authentication,
    authorization and redirect assertions stay exactly as they are.

12. Vitest covers the markup and interaction that left Ruby, in `spec/pages/...` or
    `spec/features/...`. Coverage thresholds are 98%, so a new component needs a spec.

## Verifying one unit

```bash
bin/rails test test/path/to/affected_test.rb
pnpm test
bin/rubocop <changed ruby files>
pnpm -s typecheck
```

Commit one resource or ceremony at a time so a regression can be reverted alone.
