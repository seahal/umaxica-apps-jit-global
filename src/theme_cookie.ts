// Applies the visitor's theme before first paint, for the surfaces that do not boot React.
//
// Rails already renders `data-theme` and the theme class on <html>, so this
// only has to keep the document in step afterwards: while the choice is "system", whenever the
// operating system setting changes, and whenever the cookie itself changes - which is what the
// theme preference screen does, through the server.
//
// The cookie read, the code-to-theme mapping and the DOM application all live in `@/lib/theme`,
// which the React theme controls use as well. Two implementations of the same mapping is how a
// surface ends up with a theme the rest of the application disagrees about.
import {
  applyTheme,
  readThemeCookie,
  themeFromDocument,
  watchSystemTheme,
  watchThemeCookie,
  type Theme,
} from "@/lib/theme";

// Both watchers outlive any single navigation - Turbo replaces the body and leaves <html>, and
// the cookie store belongs to the document - so they are registered once and never torn down.
let watching = false;

function showTheme(theme: Theme): void {
  applyTheme(theme);

  const valueElement = document.querySelector("#js-theme-cookie-value");
  if (valueElement) {
    valueElement.textContent = theme;
  }
}

async function applyThemeFromCookie(): Promise<void> {
  showTheme(await readThemeCookie());

  if (!watching) {
    watching = true;
    // A media-query change has to be answered with the theme as it stands, not a promise.
    // `showTheme` has just written that theme onto <html>, so the document is the synchronous
    // record of what the cookie last said.
    watchSystemTheme(themeFromDocument);
    watchThemeCookie(showTheme);
  }
}

// The entrypoint is a module script, so it runs before `DOMContentLoaded` - but it is no longer
// the second chance a `turbo:load` listener used to be, so a document that is already parsed by
// the time this evaluates is applied to directly rather than waited on forever.
if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", () => void applyThemeFromCookie());
} else {
  void applyThemeFromCookie();
}

export { applyThemeFromCookie };
