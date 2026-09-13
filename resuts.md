# JavaScript / TypeScript Static Quality Gate

Record of the 2026-08-15 pass over the JavaScript/TypeScript frontend of this Rails application.
Scope was the frontend only; no Ruby, Rails, Gemfile, Sorbet/RBS/Tapioca, RuboCop, Brakeman or
Packwerk file was changed.

## Summary

The frontend source was already disciplined — no `any`, no type assertions in `src/`, no
`@ts-ignore`, React 19 idioms throughout, and no ESLint/Prettier/Biome residue. The gate meant to
protect it was not.

Three defects, each measured rather than inferred:

1. **`pnpm typecheck` checked zero files.** `tsconfig.json` is a solution file (`files: []` plus
   `references`), and `tsc --noEmit` does not build references. Measured: `tsc --noEmit --listFiles`
   listed **0** project files against **453** for `tsc -p tsconfig.app.json`. TypeScript had never
   gated CI or `pre-push`.
2. **The Inertia shared-props augmentation had never taken effect.** `src/types/globals.d.ts`
   declared `module "@inertiajs/core"`, but `@inertiajs/core` was only a transitive dependency, so
   under pnpm's strict layout the declaration created a _new ambient module_ instead of augmenting
   the real one. It also pointed at a `SharedProps` that was defined as `{}`.
3. **`dependency-cruiser` was installed with no config and no invocation** — no script, no lefthook
   job, no CI step.

All three are fixed or replaced. The gate now runs formatting → lint (including type-aware lint) → a
coverage assertion → the full type build → dead-code analysis, then tests and the production build,
and every stage was verified against a deliberately introduced violation.

## Documentation consulted

Checked against the installed packages' own published types and configuration schemas rather than
third-party articles:

- TypeScript 7.0.2 (`tsgo`) — project references and `--build` behaviour, strictness flags.
- `@inertiajs/core` 3.6.1 `types/types.d.ts` — `InertiaConfig` declaration-merging contract,
  `DefaultInertiaConfig`, `Page["props"]`, `VisitOptions`, `VisitCallbacks`, `ActiveVisit`.
- `@inertiajs/react` 3.6.1 `types/usePage.d.ts`, `types/createInertiaApp.d.ts`.
- `react-aria-components` 1.20.0 / `@react-types/shared` 3.36.1 prop types.
- `oxlint` 1.77.0 `configuration_schema.json` (`options.typeAware`, `options.typeCheck`,
  `options.denyWarnings`, `options.reportUnusedDisableDirectives`, override `files`/`excludeFiles`)
  and `oxlint --help`.
- `knip` 6.32.2 dependency manifest (confirms it parses with `oxc-parser`, not the TypeScript
  compiler).
- `dependency-cruiser` 18.1.1 runtime diagnostic on TypeScript support.
- `@hotwired/stimulus` 3.2.2 `Application` / `Controller` / `ControllerConstructor` types.

## Scope

|             |                                                                                                                                                                 |
| ----------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| In scope    | `src/`, `spec/`, `e2e/`, `tsconfig*.json`, `vite.config.ts`, `vitest.config.ts`, `.oxlintrc.json`, `.oxfmtrc.json`, `knip.json`, `package.json`, `lefthook.yml` |
| Read only   | Rails controllers and views, to establish the real shape of the Inertia error payload                                                                           |
| Not touched | all Ruby, `Gemfile*`, Sorbet/RBS/Tapioca, RuboCop, Brakeman, bundler-audit, Packwerk                                                                            |

There is no `app/frontend` or `app/javascript`; all frontend source lives in `src/`, and `spec/` is
the Vitest root (Rails Minitest lives in `test/`).

## Before

|                                  |                                            |
| -------------------------------- | ------------------------------------------ |
| TypeScript                       | 7.0.2                                      |
| React / react-dom                | 19.2.8                                     |
| `@inertiajs/react`               | 3.6.1 (`@inertiajs/core` transitive only)  |
| Vite / vite-plugin-ruby          | 8.2.0 / 5.2.2                              |
| Oxlint / oxlint-tsgolint / Oxfmt | 1.77.0 / 7.0.2001 / 0.62.0                 |
| Vitest                           | 4.1.10                                     |
| dependency-cruiser               | 18.1.1, installed, unconfigured, uninvoked |
| Knip                             | absent                                     |

Execution paths actually in use:

| Concern             | Before                                                                      |
| ------------------- | --------------------------------------------------------------------------- |
| formatter           | `oxfmt --check` over a hand-maintained file list                            |
| syntactic lint      | `oxlint .` (correctness + suspicious)                                       |
| type-aware lint     | on (`typeAware`, `typeCheck`) but with no react / jsx-a11y / vitest plugins |
| TypeScript          | **nothing** — `tsc --noEmit` on the solution file covered 0 files           |
| dependency analysis | none                                                                        |
| unit test           | `vitest run --coverage`, thresholds 98%                                     |
| build               | `vite build` in a separate CI job                                           |

Source counts before: `src` 35 `.ts`, 366 `.tsx`, **17 `.js`**, 3 `.d.ts`; `spec` 9 `.ts`, 40
`.tsx`, **17 `.js`**.

## Problems

### TypeScript

- `pnpm typecheck` covered 0 files (above).
- With every strictness flag on, **76** errors were latent in `src/` + `spec/` and **14** more in
  `e2e/`, none of which anything had ever reported. Per flag: `noUncheckedIndexedAccess` 38,
  `exactOptionalPropertyTypes` 25, `noPropertyAccessFromIndexSignature` 13,
  `noImplicitReturns`/`noImplicitOverride`/`verbatimModuleSyntax`/`noUncheckedSideEffectImports` 0
  each.
- `e2e/` sat in the Node tooling project with `lib: ["ES2023"]` only, so the Playwright
  `page.evaluate` bodies referenced DOM globals the project did not declare.
- `tsconfig.app.json` declared three path aliases; `vite.config.ts` and `vitest.config.ts` declared
  six, and the two sets disagreed.

### Inertia

- `@inertiajs/core` was not a direct dependency, so the `declare module` in `src/types/globals.d.ts`
  silently created a new module instead of augmenting the adapter's. A probe importing
  `SharedPageProps` from `@inertiajs/core` failed with TS2307.
- Two competing `SharedProps` types existed: the real contract in `src/types/inertia.ts` (`chrome`,
  `errors`) and `SharedProps = {}` in `src/types/index.ts`. The augmentation used the empty one.
- `errorValueType` was declared `string[]`, contradicting `errors: Record<string, string>` in the
  other file. The server sends `errors.to_hash(true).transform_values(&:first)`
  (`app/controllers/concerns/preference_sign_screen_actions.rb:94`,
  `app/controllers/auth/com/settings/passkeys_controller.rb:86`), i.e. one message per key — so
  `string[]` was simply wrong.
- `SharedProps` also redeclared `errors`, which the adapter already declares on `Page["props"]`.
- 14 Inertia entrypoints were byte-identical apart from a glob literal and a surface name.
- `PageProps<T>` in `src/types/inertia.ts` was exported and imported by nothing.

### Oxlint

- `react`, `jsx-a11y` and `vitest` plugins were not enabled at the top level, so no accessibility
  rule ran against 366 `.tsx` files.
- Of 1 399 `typescript/no-unsafe-*` findings available under `pedantic`, **1 304 were in `.js`
  files** — the untyped Stimulus island.
- 19 real accessibility findings once `jsx-a11y` was enabled.
- Suppression style was mixed: 12 `eslint-disable-next-line` comments alongside oxlint's own.
- Unused suppressions were not reported; warnings did not fail the run.

### React

- No React 17/18 residue: zero `forwardRef`, `PropTypes`, `defaultProps`, class components,
  `React.FC` or `ReactDOM.render` in `src/`.
- `react/react-in-jsx-scope` accounted for 2 614 of the 2 747 findings the React plugin produced — a
  rule that does not apply under `jsx: "react-jsx"`.

### dependency

- No configuration, no invocation, and — discovered during this pass — **dependency-cruiser 18.1.1
  cannot parse TypeScript 7 sources.** It requires `typescript >=2 <7`, and without it cruises **0
  modules while reporting "no dependency violations found"**: a silent pass, which
  `generic/no-silent-fallback.mdc` forbids outright.

### dead code

- Nothing detected unused files, exports, or dependencies.

### suppression

- 18 lint suppressions, several without a stated reason; no `@ts-ignore`/`@ts-expect-error`
  anywhere.

### unsafe typing

- `src/types/auth-browser-helpers.d.ts` hand-declared the module surface of the untyped
  `webauthn_utils.js`, promising `normalizePublicKeyOptions` returned
  `PublicKeyCredentialCreationOptions & PublicKeyCredentialRequestOptions`. Nothing checked that
  claim, and it was false — the implementation could not guarantee any required field. This sat on
  the WebAuthn path.
- One `as unknown as` in the whole repository (`spec/entrypoints/inertia.test.ts`), plus 17 non-null
  assertions, all in tests.

### build / tooling

- `format`/`format:check` enumerated every file by hand and had already drifted.
- `pnpm check` did not run dependency analysis or the production build.

## Changes

### Gate

- `typecheck` is now `tsc --build`, and a new `typecheck:verify` asserts the check covered the
  source tree — the exact failure that hid the original defect. Verified: the old
  `tsc --noEmit --listFiles | grep /src/` form fails the new guard.
- `check` = `format:check → lint → typecheck:verify → typecheck → deadcode`, cheapest first, and
  writes nothing. `ci` = `check → test:coverage → build`.
- `format`/`format:check` now take directories and let `.oxfmtrc.json`'s `ignorePatterns` decide.

### TypeScript

- `tsconfig.app.json` and `tsconfig.node.json`: added `noUncheckedIndexedAccess`,
  `exactOptionalPropertyTypes`, `noPropertyAccessFromIndexSignature`, `noImplicitOverride`,
  `noImplicitReturns`, `noUncheckedSideEffectImports`, `verbatimModuleSyntax`,
  `allowUnreachableCode: false`, `allowUnusedLabels: false`, `forceConsistentCasingInFileNames`;
  raised `target`/`lib` from ES2020 to ES2023.
- Split `tsconfig.e2e.json` out of the Node project so Playwright's in-browser `evaluate` bodies get
  `lib: ["ES2023", "DOM", "DOM.Iterable"]` while the Vite/Vitest configs do not.
- **Attempted and abandoned:** a `tsconfig.worker.json` to type-check
  `app/views/pwa/service-worker.js` against `lib.webworker`. It was withdrawn rather than shipped —
  see "The service worker" below.
- Collapsed the alias set to `@/*` alone after confirming `~/`, `@components`, `@controllers`,
  `@entrypoints` and `@styles` had **zero** import sites; `vite.config.ts`, `vitest.config.ts` and
  `tsconfig.app.json` now agree.
- Fixed all 90 resulting errors in source. Representative fixes, none of them a silencing:
  `for (const byte of bytes)` instead of an indexed loop; `dataset["theme"]` for index-signature
  reads; conditional spreads where an optional property must be _absent_ rather than `undefined`;
  `isDisabled={option.isDisabled ?? false}` where React Aria's absent means false.

### JavaScript → TypeScript

All 17 `.js` files in `src/` and all 17 in `spec/` moved to `.ts`. `src`, `spec` and `e2e` now
contain **zero** `.js`/`.jsx`. Along the way:

- `src/controllers/index.ts`'s glob was `./**/*_controller.js`; it now matches `.ts` and refuses,
  loudly, a module that does not default-export a `Controller` subclass — previously such a module
  would silently never register.
- `src/types/auth-browser-helpers.d.ts` was deleted (renamed to `src/types/browser-globals.d.ts`,
  keeping only the genuine `window` globals). Removing the false declaration immediately surfaced
  the gap it had hidden, which is now closed properly: `normalizeRequestOptions` and
  `normalizeCreationOptions` validate every field WebAuthn requires and name the missing one, with
  no type assertion anywhere.
- `theme_controller.ts` and `theme_cookie.ts` were deduplicated onto the already-tested
  `src/lib/theme.ts`; the cookie parsing and code↔theme mapping existed in three places.
- The passkey controllers' shared request/response handling moved to
  `src/controllers/passkey_ceremony.ts`.
- Every controller now declares the properties Stimulus creates from
  `static targets`/`static values`, so the compiler sees what the runtime does.

### Oxlint

- Plugins: added `react`, `jsx-a11y`, `vitest`.
- Categories: `correctness` and `suspicious` error; `pedantic`, `style`, `perf`, `restriction`,
  `nursery` off, with the useful `pedantic` rules adopted individually (below).
- `react/react-in-jsx-scope` off — a React 17 rule that does not apply under `jsx: "react-jsx"`.
- Adopted as errors, each verified at zero: `typescript/no-floating-promises`,
  `no-misused-promises`, `await-thenable`, `no-unsafe-assignment`, `no-unsafe-argument`,
  `no-unsafe-call`, `no-unsafe-member-access`, `no-unsafe-return`, `no-unsafe-type-assertion`,
  `no-unnecessary-type-assertion`, `no-unnecessary-condition`, `unbound-method`,
  `no-base-to-string`, `no-deprecated`, plus `import/no-cycle` and `import/no-unresolved`.
- `options.denyWarnings: true` and `options.reportUnusedDisableDirectives: "error"` — nothing stays
  a warning, and a suppression that no longer suppresses anything fails the build.
- Fixed all 19 accessibility findings in code where the rule was right: `role="status"` → `<output>`
  (2), `role="group"` → `<fieldset>` (1), and configured `label-has-associated-control` with
  `depth: 6` and `control-has-associated-label` with `th`/`td`/`tr` added to `ignoreElements` (the
  rule targets interactive controls; a blank header cell above an actions column is not one).

### Architecture boundary

`dependency-cruiser` was going to carry the surface-boundary rule. Since it cannot parse TypeScript
7 and fails _silently_, it was removed from `devDependencies` rather than left installed and unused,
and the boundary moved into oxlint, which already runs on every check:

```
overrides: files "**/src/**", excludeFiles "**/src/pages/**"
  no-restricted-imports: forbid "@/pages/**" and "**/pages/**", and "**/spec/**"
```

Each surface's Inertia entrypoint reaches its own page tree through its own `import.meta.glob`
literal, and nothing else reaches a page tree at all — which is precisely what makes one surface's
pages unreachable from another's. Confirmed first that **no** file under `src/` statically imports a
page today, so the rule locks in the current state at zero cost.

Verified in both directions: a probe file importing `@/pages/base/app/groups/index` from
`src/features/` fails the lint; the same import from inside `src/pages/base/app/` does not.

A first attempt used twenty per-surface overrides. It was discarded after testing showed oxlint
resolves a rule to **one** configuration per file, so only the last override took effect — the rule
would have looked enforced while checking almost nothing.

### Dead code

Knip 6.32.2 was added after confirming it parses with `oxc-parser`/`oxc-resolver` rather than the
TypeScript compiler, so it is not subject to the incompatibility that disqualified
dependency-cruiser. It reports unused files, unused value exports, unused and unlisted dependencies.
Verified in both directions: an orphan file and an unimported export are each reported, and removing
them returns the check to green.

### Tests

The `.js` specs mocked `@hotwired/stimulus` away and constructed controllers with
`Object.create(Controller.prototype)`. That skips Stimulus's own construction, so class field
initialisers never run and private state reads back as `undefined` instead of its declared default —
which silently changed which branch the code under test took. This was not theoretical:
`ThemeController#syncFromServer` guards on `this.selectedTheme !== null`, and under `Object.create`
that guard was always true, so three tests were asserting on a method that had returned immediately.

New shared spec support, each earning its place by removing an `any` or a `!`:

| Module                     | Purpose                                                                                                                            |
| -------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| `spec/support/stimulus.ts` | mounts a controller through a real `Application`, so targets, values and field initialisers exist as they do in the browser        |
| `spec/support/present.ts`  | narrows an indexed read and fails naming what was expected, in place of `!`                                                        |
| `spec/support/visit.ts`    | a complete, assertion-free `ActiveVisit` so router mocks can be typed from the adapter and their lifecycle callbacks still invoked |
| `spec/support/http.ts`     | queues `fetch` answers and reads back url and JSON body without a `String(...)` that would answer `"[object Object]"`              |
| `spec/support/webauthn.ts` | credentials shaped as an authenticator answers them                                                                                |
| `spec/support/matchers.ts` | names `expect.any` / `expect.objectContaining` as `unknown` so the object built around them stays checked                          |

The three passkey controller specs were rewritten against real DOM and the refactored controllers.
Router and module mocks are now typed from the real exports (`vi.fn<typeof inertiaRouter.patch>()`,
`vi.fn<typeof realGetAssertion>()`), which immediately caught two specs asserting against a
credential fixture that did not satisfy `SerializedCredential`.

`spec/setup.ts` gained a `window.matchMedia` stand-in; jsdom implements no media queries, so theme
code hit a `TypeError` rather than a meaningful failure.

## TypeScript strictness

Enabled in `tsconfig.app.json`, `tsconfig.node.json` and `tsconfig.e2e.json`:

```
strict, noUncheckedIndexedAccess, exactOptionalPropertyTypes,
noPropertyAccessFromIndexSignature, noImplicitOverride, noImplicitReturns,
noFallthroughCasesInSwitch, noUncheckedSideEffectImports, noUnusedLocals,
noUnusedParameters, allowUnreachableCode: false, allowUnusedLabels: false,
forceConsistentCasingInFileNames, verbatimModuleSyntax, isolatedModules, noEmit
```

`useUnknownInCatchVariables` is implied by `strict`. Project references are genuine, not template
residue: three projects with real boundaries — application + specs (DOM), Vite/Vitest config (Node),
and e2e (Node **and** DOM, because Playwright's `evaluate` bodies run in the browser).

## Oxlint

Final shape:

| Concern      | Setting                                                                    |
| ------------ | -------------------------------------------------------------------------- |
| categories   | `correctness`, `suspicious` = error; everything else off                   |
| type-aware   | `typeAware` + `typeCheck` on, with 16 rules adopted individually as errors |
| warnings     | `denyWarnings: true` — nothing may remain a warning                        |
| suppressions | `reportUnusedDisableDirectives: "error"`                                   |
| plugins      | import, promise, unicorn, typescript, node, oxc, react, jsx-a11y, vitest   |

`tsc --build` was **not** removed in favour of oxlint's `typeCheck`. They are not equivalent: the 76
strictness errors above are TypeScript diagnostics that oxlint's type-aware pass does not report.
Both stay.

## Inertia typing

| Area          | Before                                                                                            | After                                                                                                                                                                 |
| ------------- | ------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| shared props  | augmentation inert (`@inertiajs/core` not a direct dependency) and pointed at `SharedProps = {}`  | `@inertiajs/core@3.6.1` added as a direct dependency; one `SharedProps` (`{ chrome: SurfaceChrome }`) in `src/types/inertia.ts`; `src/types/index.ts` deleted         |
| `errors`      | declared twice, `Record<string, string>` in one place and `errorValueType: string[]` in the other | declared once by the adapter; `errorValueType: string` matches the Rails `transform_values(&:first)` payload                                                          |
| `usePage`     | two call sites passed `usePage<SharedProps>()` to compensate; two bare call sites got `{}`        | all four use bare `usePage()` and see `chrome` and `errors`                                                                                                           |
| page props    | already explicit everywhere; `PageProps<T>` exported and unused                                   | unchanged where already explicit; the dead `PageProps<T>` removed                                                                                                     |
| forms         | `useForm` inferred or explicitly generic; unchanged                                               | unchanged — no `any` was present                                                                                                                                      |
| page resolver | already assertion-free, with a real `isPageModule` type guard                                     | unchanged in design; the 14 identical entrypoints collapsed onto `bootSurfaceInertiaApp(modules, surface)`, which fixes the `nonce` boundary once instead of 14 times |
| `nonce`       | `cspNonce(): string \| undefined` passed to `nonce?: string`                                      | omitted rather than passed as `undefined` — the JSON boundary's "absent" and "null" kept distinct, as `exactOptionalPropertyTypes` requires                           |

The last row is the general rule applied throughout: `foo?: string` now means the key may be absent,
`foo: string | null` means Rails sent `null`, and `foo?: string | undefined` is written deliberately
where a component forwards an optional server prop straight through.

## Static Quality Gate

```
                     pnpm check
  ┌──────────────────────────────────────────────┐
  │  oxfmt --check          formatting            │  1.05 s
  │        ↓                                      │
  │  oxlint                 AST + type-aware      │  1.23 s
  │        ↓                                      │
  │  typecheck:verify       covers the tree?      │  0.3  s
  │        ↓                                      │
  │  tsc --build            4 projects            │  0.47 s
  │        ↓                                      │
  │  knip                   dead code             │  1.40 s
  └──────────────────────────────────────────────┘
                          ↓
                 vitest run --coverage              5.07 s
                          ↓
                 vite build --mode production       1.85 s
```

Responsibilities do not overlap: Oxfmt owns formatting and import order; Oxlint owns AST
correctness, type-dependent bugs, accessibility, import cycles and the surface boundary; TypeScript
owns the type system; Knip owns reachability; Vitest owns runtime behaviour; Vite owns build
integration.

`check` and `ci` never invoke `--fix`; `fix` is the only writing entry point, and lefthook's
pre-commit `--fix` jobs stay separate from the pre-push `pnpm ci`.

## Exceptions

| Kept                                      | Where                                     | Why                                                                                                                                                                                                                                                                                         |
| ----------------------------------------- | ----------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `skipLibCheck: true`                      | all tsconfigs                             | The only three errors it hides are upstream and unfixable locally: `@inertiajs/core/types/axiosHttpClient.d.ts` imports `axios`, which the package does not depend on, and `react-stately` references `Intl.Segmenter`, which no `lib` declares. Nothing in `src/` or `spec/` relies on it. |
| `jsx-a11y/no-redundant-roles` off         | global                                    | Tailwind's preflight removes list markers, and Safari then drops the list role from a `ul` entirely; `role="list"` restores it. The rule cannot see the stylesheet, so what it calls redundant is the fix for a real assistive-technology bug.                                              |
| `jsx-a11y/autocomplete-valid` off         | global                                    | `autocomplete="username webauthn"` is the token pair WebAuthn conditional UI defines; the rule's value table predates it.                                                                                                                                                                   |
| `jsx-a11y/no-autofocus` off               | `ConfirmDialog.tsx`, `UiGallery.tsx` only | Both move focus into a modal on open, which the dialog pattern asks for. It cannot be suppressed inline: the finding lands on a JSX _attribute_, and a JSX comment can only sit between elements. Each site states the reason next to the attribute.                                        |
| `vitest/require-mock-type-parameters` off | global                                    | A good rule — it caught two real fixture mismatches while being trialled. Left off pending the ~106 pre-existing `vi.fn()` call sites; listed under remaining issues rather than quietly dropped.                                                                                           |
| `app/views/**` in `ignorePatterns`        | oxlint                                    | Rails view templates are not part of the Vite module graph and have no TypeScript program, so type-aware rules resolve their globals to `error` types. The one real file there, the service worker, is discussed below.                                                                     |

15 lint suppressions remain, all `oxlint-disable-next-line` and all with a stated reason; unused
ones now fail the build, so the list cannot rot.

**Budget:**

|                                        |     |
| -------------------------------------- | --- |
| TypeScript errors                      | 0   |
| Oxlint warnings / errors               | 0   |
| explicit `any`                         | 0   |
| `as any`                               | 0   |
| `as unknown as X`                      | 0   |
| non-null assertions                    | 0   |
| `@ts-ignore`                           | 0   |
| `@ts-expect-error`                     | 0   |
| unused lint suppressions               | 0   |
| floating promises                      | 0   |
| `.js` / `.jsx` in `src`, `spec`, `e2e` | 0   |

## Performance

Measured on this machine, cold `--force` where applicable:

| Stage                                  | Time         |
| -------------------------------------- | ------------ |
| `oxfmt --check` (545 files)            | 1 050 ms     |
| `oxlint` incl. type-aware (`tsgolint`) | 1 232 ms     |
| `tsc --build --force` (4 projects)     | 466 ms       |
| `knip`                                 | 1 396 ms     |
| **`pnpm check` total**                 | **3 565 ms** |
| `vitest run` (754 tests)               | 5 073 ms     |
| `vite build --mode production`         | 1 846 ms     |

No TypeScript program is built twice within a stage. Oxlint's type-aware pass and `tsc --build` each
build one, which is unavoidable while they remain separate tools — and, per above, they must.

## Verification

Every command below was run in this session, in this order, from a clean tree.

| Command                                  | Result                                                                    |
| ---------------------------------------- | ------------------------------------------------------------------------- |
| `pnpm format:check`                      | pass — "All matched files use the correct format", 545 files              |
| `pnpm lint`                              | pass — 0 findings                                                         |
| `pnpm typecheck:verify`                  | pass — exit 0; the pre-fix `tsc --noEmit` form was confirmed to _fail_ it |
| `pnpm typecheck` (`tsc --build --force`) | pass — 0 errors across 4 projects                                         |
| `pnpm deadcode` (`knip`)                 | pass — 0 findings                                                         |
| `pnpm test`                              | pass — **754 passed / 754**, 65 files                                     |
| `pnpm build`                             | pass — production bundle built in 973 ms                                  |
| `pnpm test:coverage`                     | **FAILS** — see below                                                     |

Negative tests, because a check that has never failed has not been shown to work:

| Guard                | Probe                                                                        | Result                |
| -------------------- | ---------------------------------------------------------------------------- | --------------------- |
| `typecheck:verify`   | the old root-config `tsc --noEmit` form                                      | fails, as intended    |
| surface boundary     | `src/features/__boundary_probe.ts` importing `@/pages/base/app/groups/index` | reported              |
| surface boundary     | the same import from inside `src/pages/base/app/`                            | allowed               |
| `import/no-cycle`    | a two-module cycle in `src/`                                                 | both modules reported |
| `knip` unused file   | an orphan `src/lib/__dead_file.ts`                                           | reported              |
| `knip` unused export | an unimported export added to `src/lib/csrf.ts`                              | reported              |

All probe files were removed; the tree is clean.

### The one failing check

`pnpm test:coverage` fails its 98% thresholds — 83.29% statements, 74.81% branches, 83.37%
functions, 83.44% lines.

**This predates the session.** Measured on a detached worktree at `HEAD` (`8b025e7c1`), untouched by
any change here: 82.94% statements, 76.40% branches, 82.67% functions, 83.08% lines — also failing.
So `pnpm ci` and the CI `test:coverage` step were already red.

Net effect of this pass: statements +0.35pp, functions +0.70pp, lines +0.36pp, **branches −1.59pp**.
The branch dip is the honest cost of rewriting three heavily-mocked passkey specs against real DOM:
the old specs reached branches by calling controller internals that no longer exist.

The threshold was **not** lowered. Lowering a threshold to make a check pass is the kind of "fix"
this work exists to prevent. Closing the gap needs either real tests for the uncovered areas —
`src/features/auth/passkeys/*` (~25% covered), `src/features/auth/signup/*` (~23%),
`src/features/auth/turnstile/*` (0%), and a number of `src/pages/auth/**` screens — or an agreed
floor that reflects reality. That is a decision to make, not one to take silently.

## Remaining frontend issues

1. **Coverage is 83%, thresholds say 98%** (above). Pre-existing; needs a decision.
2. **`.github/workflows/ci.yml` is read-only in this environment and still needs one line.** The
   `lint-js` job runs `format:check`, `lint`, `typecheck`, `test:coverage` as separate steps, so it
   does **not** pick up the new `typecheck:verify` or `deadcode`. Add before the typecheck step:
   ```yaml
   - name: Assert the typecheck covers the source tree
     run: pnpm -s run typecheck:verify
   - name: Dead code (knip)
     run: pnpm -s run deadcode
   ```
   Until then, the guard runs only via `pnpm ci` in lefthook's pre-push hook.
3. **`vitest/require-mock-type-parameters`** — ~106 `vi.fn()` sites without a type parameter. The
   rule is configured but off. Each fix needs the right signature, not a blanket edit.
4. **`typescript/strict-boolean-expressions` (134) and `no-confusing-void-expression` (187)** are
   available and unclaimed. Both are worth adopting; both are large, meaning-bearing edits rather
   than mechanical ones.
5. **`src/features/turnstile/TurnstileWidget.tsx:95`** carries an `exhaustive-deps` suppression with
   a stated reason. It is the one remaining suppression with genuine bug potential and deserves a
   second look.
6. **dependency-cruiser cannot return** until it supports TypeScript 7 (maintainers state support
   will follow when the TS 7 API is published and stable). Its `no-orphans` role is covered by Knip
   and its cycle detection by `import/no-cycle`; what is _not_ covered is layered architecture rules
   beyond the single boundary now encoded in oxlint.
7. **Rails → TypeScript schema generation was not attempted**, as scoped. Worth proposing
   separately: the prop types in `src/types/inertia.ts` and the per-page prop types are
   hand-maintained against Ruby that nothing checks them against. Every mismatch found in this pass
   (the `errors` shape, the WebAuthn options contract) was of exactly that kind.

## Out of scope observations

Found while reading Rails code to establish the Inertia payload shape. **Nothing here was changed.**

1. **The service worker is not type-checked, and could not be made so honestly.**
   `app/views/pwa/service-worker.js` is served verbatim from `app/views`, so it can never be a
   module in the Vite graph. A `tsconfig.worker.json` with `allowJs`/`checkJs` and
   `lib: ["ES2023", "WebWorker"]` was built and then withdrawn, for two reasons worth recording:

   - With `include`, TypeScript silently dropped the `.js` from the project and reported success. A
     deliberate `const broken: number = "no"` produced **no diagnostic**. Switching to `files` made
     it real — the same silent-pass shape as the original `tsc --noEmit` defect, and the reason
     every guard in this pass was checked with a deliberate violation.
   - Once genuinely included, the file needs `self` narrowed from `WorkerGlobalScope` to
     `ServiceWorkerGlobalScope`, which TypeScript offers no way to do from a `.js` file without a
     JSDoc cast or a `declare const self` that collides with `lib.webworker` (TS2451). Both are the
     assertion-and-shim patterns this work exists to remove.

   The fix is on the Ruby side and out of scope: move the worker into `src/entrypoints/` as a `.ts`
   module and serve the built asset, at which point it joins the normal gate with no exception at
   all. `adr/pwa-offline-route-exception.md` may already bear on this. Until then the file is
   covered by its Rails regression test only, and is excluded from oxlint via `ignorePatterns`.

2. The Inertia error payload is built independently in at least two controllers
   (`app/controllers/concerns/preference_sign_screen_actions.rb:94`,
   `app/controllers/auth/com/settings/passkeys_controller.rb:86`), each spelling
   `errors.to_hash(true).transform_values(&:first)` by hand. A third caller that forgets
   `transform_values` would send `string[]` and break the now-correct `errorValueType: string` with
   no compile-time signal on either side.
3. `config/tailwind.config.js` is deleted in the working tree while `package.json` still carries
   `@tailwindcss/forms` and `@tailwindcss/typography`. Knip reports both as unimported; they are
   ignored in `knip.json` because Tailwind 4 loads plugins from CSS, and this was checked rather
   than assumed — `src/styles/surfaces/*.css` carries `@plugin "@tailwindcss/typography"` and
   `@plugin "@tailwindcss/forms"`. No action needed; recorded so the `ignoreDependencies` entries
   are not mistaken for a workaround.
