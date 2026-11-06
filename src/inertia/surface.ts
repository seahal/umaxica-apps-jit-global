import { createInertiaApp, router, type ResolvedComponent } from "@inertiajs/react";

import SurfaceLayout from "@/layouts/SurfaceLayout";
import { handleStepUpChallenge } from "@/lib/step_up_challenge";
import { applyTheme, readThemeCookie, watchThemeCookie } from "@/lib/theme";

// Shared pieces for the per-FQDN Inertia entrypoints.
//
// Every trust boundary (base/app, base/com, auth/org, ...) boots its own Inertia application from
// its own entrypoint and globs only its own page directory, so one surface can never resolve
// another surface's page component. This module holds what is genuinely identical between them;
// the glob itself stays a literal in each entrypoint because Vite can only rewrite a literal.

/**
 * Rails sends surface-qualified component names ("base/app/groups/index") so the Inertia page
 * object stays self-describing in logs and in the browser devtools, while each entrypoint globs
 * only its own directory. A name that does not carry this surface's prefix is a cross-surface
 * render and fails loudly rather than falling through to a "Page not found" that looks like a
 * missing file.
 */
// The adapter publishes its resolved-component type under this name; a page module is a module
// whose default export is one, and the surface layout is assigned to that component's `layout`.
type PageModule = { default: ResolvedComponent };
// The layout is assigned as an array, so the parameter is that array's element type.
type SurfaceLayoutComponent = Extract<
  NonNullable<ResolvedComponent["layout"]>,
  readonly unknown[]
>[number];

function isPageModule(module: unknown): module is PageModule {
  if (typeof module !== "object" || module === null || !("default" in module)) {
    return false;
  }

  const { default: component } = module;
  return typeof component === "object" || typeof component === "function";
}

/**
 * Builds the `resolve` for one surface from its own eagerly globbed page directory.
 *
 * Resolution stays eager on purpose. `vite_javascript_tag` emits `modulepreload` links by walking
 * the manifest's static `imports` only, never `dynamicImports`, so a lazily resolved page chunk is
 * discovered a full round trip after the entry script runs and the Inertia root stays empty for
 * that long. Eager resolution puts the page in the preloaded static graph instead.
 *
 * The surface layout is attached here rather than by each page module: a page that forgot to
 * declare it would otherwise render without header, footer or cookie controls, and that is not a
 * mistake a page should be able to make. It is assigned as an array because Inertia 3 no longer
 * accepts a bare arrow component as `layout`.
 */
export function surfacePageResolver(
  modules: Record<string, unknown>,
  surface: string,
  layout: SurfaceLayoutComponent,
): (name: string) => PageModule {
  const prefix = `${surface}/`;
  const pages = new Map<string, PageModule>();

  for (const [path, module] of Object.entries(modules)) {
    const name = path.replace(/^.*\/pages\//u, "").replace(/\.tsx$/u, "");

    if (!isPageModule(module)) {
      throw new Error(
        `Inertia page "${name}" in src/pages/${surface} has no default export. ` +
          "A page module must export its component as the default.",
      );
    }

    pages.set(name, module);
  }

  return (name: string) => {
    if (!name.startsWith(prefix)) {
      throw new Error(
        `Inertia page "${name}" does not belong to the "${surface}" surface. ` +
          "Rendering another surface's page component is a trust boundary violation.",
      );
    }

    const page = pages.get(name);

    if (!page) {
      throw new Error(
        `Inertia page "${name}" has no component in src/pages/${surface}. ` +
          "The controller renders a page the surface cannot resolve.",
      );
    }

    page.default.layout ??= [layout];

    return page;
  };
}

/**
 * Client defaults that are part of the Rails <-> Inertia contract rather than of any one surface:
 * `brackets` matches Rack's query parsing, and the form defaults match the server error payload.
 */
export const surfaceInertiaDefaults = {
  form: {
    forceIndicesArrayFormatInFormData: false,
    withAllErrors: true,
  },
  visitOptions: () => ({ queryStringArrayFormat: "brackets" }) as const,
} as const;

/**
 * The response CSP nonce, published by the layout as `<meta property="csp-nonce">`.
 *
 * Inertia builds its progress bar and its error dialog as `<style>` elements at runtime, and
 * `script-src`/`style-src-elem` carry a nonce with no `unsafe-inline`, so those elements are
 * refused unless they are told the nonce. Vite's dev client reads the same tag by itself.
 *
 * Returns undefined rather than throwing when the tag is absent, which is the correct behaviour
 * under a policy that does not use one. The option is then omitted rather than passed as
 * undefined, because `nonce` is declared optional and not nullable.
 */
function cspNonce(): string | undefined {
  /* v8 ignore next -- jsdom does not always expose HTMLMetaElement.nonce */
  const nonce = document.querySelector<HTMLMetaElement>("meta[property=csp-nonce]")?.nonce;
  // An empty nonce attribute is the same as no nonce at all.
  return nonce === undefined || nonce.length === 0 ? undefined : nonce;
}

/**
 * `createInertiaApp` rejects when the root element is absent, which happens when an Inertia
 * entrypoint is loaded from a non-Inertia layout. Report that as a configuration mistake instead
 * of an unhandled rejection, and rethrow anything else.
 */
export function reportInertiaBootFailure(error: unknown): void {
  if (document.querySelector("#app")) {
    throw error;
  }

  // oxlint-disable-next-line no-console
  console.error(
    "Missing Inertia root element.\n\n" +
      "This entrypoint belongs to a surface Inertia layout (app/views/layouts/<family>/<surface>/" +
      "inertia.html.erb). A non-Inertia layout must load its own entrypoint instead.",
  );
}

/**
 * Keeps `<html data-theme>` in step with the current surface's display cookie.
 *
 * Rails renders the attribute from the cookie, and every `dark:` utility and every `--ui-*` token
 * is keyed on it, so the document's colours are only ever as current as the last document load.
 * An Inertia visit is not one: the theme preference screen writes the cookie server-side and the
 * response replaces the page component underneath an `<html>` element nobody touched, so the
 * visitor saved a theme and watched nothing change.
 *
 * The cookie store reports that write directly, so this listens to the cookie rather than to the
 * navigation that happened to carry it. It needs no Inertia counterpart of the `DOMContentLoaded`
 * listener in `src/theme_cookie.ts`: both surfaces watch the same signal, from the same authority.
 */
function keepDocumentThemeInStep(): void {
  void readThemeCookie().then(applyTheme);
  watchThemeCookie(applyTheme);
}

/** The exact options every surface boots with. Exported so a test can name the shape it asserts. */
export type SurfaceInertiaAppOptions = {
  resolve: (name: string) => PageModule;
  nonce?: string;
  strictMode: true;
  defaults: typeof surfaceInertiaDefaults;
};

/**
 * Boots the Inertia application for one surface.
 *
 * Every entrypoint boots identically apart from its own page glob and surface name, so the
 * configuration lives here once: a difference between two surfaces' Inertia setup would be a
 * difference nobody chose. The glob stays a literal at the call site because Vite can only rewrite
 * a literal.
 */
export function bootSurfaceInertiaApp(
  modules: Record<string, unknown>,
  surface: string,
): Promise<unknown> {
  keepDocumentThemeInStep();

  if (surface === "base/app" || surface === "base/org") {
    router.on("httpException", (event) => {
      if (handleStepUpChallenge(event.detail.response)) {
        event.preventDefault();
        return false;
      }

      return true;
    });
  }

  const nonce = cspNonce();

  const options: SurfaceInertiaAppOptions = {
    resolve: surfacePageResolver(modules, surface, SurfaceLayout),

    // Inertia builds its progress bar as a runtime <style>; without the nonce the policy
    // refuses it.
    /* v8 ignore next -- nonce is absent unless the layout published the meta tag */
    ...(nonce === undefined ? {} : { nonce }),

    strictMode: true,

    defaults: surfaceInertiaDefaults,
  };

  return createInertiaApp(options).catch(reportInertiaBootFailure);
}
